/**
 * Sovdev Logger - TypeScript Implementation
 *
 * Structured logging library implementing Winston best practices:
 * - Multiple simultaneous transports (console + file + OTLP)
 * - OpenTelemetry auto-instrumentation (no manual trace injection)
 * - Proper transport separation and formatting
 * - Enhanced OTLP log exporter configuration
 *
 * Implements "Loggeloven av 2025" requirements with the new standardized API
 * that is consistent across all programming languages (TypeScript, C#, PHP, Python).
 *
 * Features:
 * - Structured JSON logging with required fields
 * - Full OpenTelemetry integration (traces AND logs)
 * - Security-aware error handling (removes auth credentials)
 * - Consistent field naming (camelCase)
 * - Simple function-based API identical across languages
 * - Winston best practices implementation
 */

import winston from 'winston';
import TransportStream from 'winston-transport';
import { AsyncLocalStorage } from 'async_hooks';
import { NodeSDK } from '@opentelemetry/sdk-node';
import { Resource } from '@opentelemetry/resources';
import { ATTR_SERVICE_NAME, ATTR_SERVICE_VERSION } from '@opentelemetry/semantic-conventions';
import { SEMRESATTRS_DEPLOYMENT_ENVIRONMENT } from '@opentelemetry/semantic-conventions';
import { OTLPTraceExporter } from '@opentelemetry/exporter-trace-otlp-http';
import { OTLPLogExporter } from '@opentelemetry/exporter-logs-otlp-http';
import { OTLPMetricExporter } from '@opentelemetry/exporter-metrics-otlp-http';
import { getNodeAutoInstrumentations } from '@opentelemetry/auto-instrumentations-node';
import { BatchLogRecordProcessor, LoggerProvider } from '@opentelemetry/sdk-logs';
import { PeriodicExportingMetricReader, MeterProvider } from '@opentelemetry/sdk-metrics';
import { BatchSpanProcessor, BasicTracerProvider } from '@opentelemetry/sdk-trace-base';
import { metrics, Counter, Histogram, UpDownCounter } from '@opentelemetry/api';
import { trace, Span, SpanStatusCode, context } from '@opentelemetry/api';
import { logs, SeverityNumber } from '@opentelemetry/api-logs';
import { v4 as uuidv4 } from 'uuid';
import { readFileSync } from 'fs';
import { join } from 'path';

// Import log levels from separate module
import { sovdev_log_level } from './logLevels';

// =============================================================================
// SPAN CONTEXT STORAGE
// =============================================================================

/**
 * AsyncLocalStorage for maintaining active span across async operations
 * This allows our lifecycle-based API (start/end) to work with async code
 */
const spanStorage = new AsyncLocalStorage<Span>();

/**
 * Set of ended spans - tracks spans that have been explicitly ended
 * Used to prevent ended spans from bleeding into subsequent log entries
 */
const endedSpans = new WeakSet<Span>();

// =============================================================================
// TYPE DEFINITIONS
// =============================================================================

// =============================================================================
// OPENTELEMETRY METRICS CONFIGURATION
// =============================================================================

/**
 * Global metrics instances - automatically track operations
 */
interface sovdev_metrics {
  operationCounter: Counter; // Total operations by service, peer, level
  errorCounter: Counter; // Total errors by service, peer, exception type
  operationDuration: Histogram; // Operation duration distribution
  activeOperations: UpDownCounter; // Currently active operations
}

let globalMetrics: sovdev_metrics | null = null;
let globalMeterProvider: MeterProvider | null = null;
let globalTracerProvider: BasicTracerProvider | null = null;

/**
 * Auto-detect service version from environment or package.json
 */
function getServiceVersion(): string {
  // Try environment variables first (from CI/deployment)
  if (process.env.SERVICE_VERSION) {
    return process.env.SERVICE_VERSION;
  }

  if (process.env.npm_package_version) {
    return process.env.npm_package_version;
  }

  // Try reading package.json
  try {
    const packageJson = JSON.parse(readFileSync(join(process.cwd(), 'package.json'), 'utf8'));
    return packageJson.version || 'unknown';
  } catch {
    return 'unknown';
  }
}

/**
 * Complete structured log entry format - complies with "Loggeloven av 2025"
 * Uses snake_case field names for consistency across all languages
 */
interface structured_log_entry {
  // Required fields
  timestamp: string;
  level?: string; // Optional - Winston will set this based on .log(level, entry)

  // Service identification fields (standard names without dots)
  service_name: string; // Service identifier
  service_version: string; // Service version
  peer_service: string; // Target system/service

  function_name: string;
  message: string;

  // Correlation fields (snake_case for consistency)
  trace_id: string; // Business transaction identifier (links related operations)
  span_id?: string; // OpenTelemetry span identifier (16-char hex, links to specific operation)
  event_id: string; // Unique identifier for this log entry

  // Log classification
  log_type: string; // Type of log: "transaction", "job.status", "job.progress"

  // Context fields
  input_json?: any;
  response_json?: any;

  // Exception fields (snake_case - project standard)
  exception_type?: string;
  exception_message?: string;
  exception_stacktrace?: string;
}

// =============================================================================
// WINSTON TRANSPORT CONFIGURATION (BEST PRACTICES)
// =============================================================================

/**
 * Custom Winston transport that sends logs to OpenTelemetry OTLP
 */
class open_telemetry_winston_transport extends TransportStream {
  private otelLogger: any;

  constructor(options: any = {}) {
    super(options);
    // Get OpenTelemetry logger instance using the serviceName from options
    this.otelLogger = logs.getLogger(options.serviceName || 'default', '1.0.0');
  }

  log(info: any, callback: () => void): void {
    // Map log levels to OpenTelemetry severity (lowercase to match SOVDEV_LOGLEVELS)
    const severity_map: { [key: string]: SeverityNumber } = {
      trace: SeverityNumber.DEBUG,
      debug: SeverityNumber.DEBUG,
      info: SeverityNumber.INFO,
      warn: SeverityNumber.WARN,
      error: SeverityNumber.ERROR,
      fatal: SeverityNumber.FATAL,
    };

    try {
      // Winston now correctly maps levels with toLowerCase() - use level directly
      const log_level = info.level;

      // Build attributes object with snake_case fields
      const attributes: any = {
        service_name: info.service_name,
        service_version: info.service_version,
        peer_service: info.peer_service,
        function_name: info.function_name,
        timestamp: info.timestamp,
      };

      // Add correlation fields (snake_case for consistency)
      if (info.trace_id) {
        attributes.trace_id = info.trace_id;
      }
      if (info.span_id) {
        attributes.span_id = info.span_id;
      }
      if (info.event_id) {
        attributes.event_id = info.event_id;
      }

      // Add log classification
      if (info.log_type) {
        attributes.log_type = info.log_type;
      }

      // Serialize input_json and response_json as JSON strings for OTLP
      if (info.input_json !== undefined) {
        attributes.input_json = JSON.stringify(info.input_json);
      }

      if (info.response_json !== undefined) {
        attributes.response_json = JSON.stringify(info.response_json);
      }

      // Add exception details if present (snake_case - project standard)
      if (info.exception_type) {
        attributes.exception_type = info.exception_type;
      }
      if (info.exception_message) {
        attributes.exception_message = info.exception_message;
      }
      if (info.exception_stacktrace) {
        attributes.exception_stacktrace = info.exception_stacktrace;
      }

      // Emit log record to OpenTelemetry using original level
      this.otelLogger.emit({
        severityNumber: severity_map[log_level] || SeverityNumber.INFO,
        severityText: log_level.toUpperCase(), // Use uppercase for consistency
        body: info.message,
        attributes,
      });
    } catch (err) {
      // Don't fail Winston if OTLP fails
      console.error('❌ OpenTelemetry Winston transport failed:', err);
    }

    // Call callback to indicate transport is done
    if (callback) {
      callback();
    }
  }
}

/**
 * Create Winston transports following best practices
 * - Console: Smart default (auto-enabled if no OTLP), or explicit via LOG_TO_CONSOLE
 * - File: Smart default (enabled), or explicit via LOG_TO_FILE
 * - OpenTelemetry: OTLP transport for centralized logging (always enabled)
 * - Multiple simultaneous transports (not either/or)
 */
function createTransports(serviceName?: string): winston.transport[] {
  const transports: winston.transport[] = [];

  // 1. CONSOLE TRANSPORT: Optional, controlled by LOG_TO_CONSOLE environment variable
  //    Smart default: enabled if no OTLP endpoint configured (fallback), otherwise disabled
  const isDevelopment = process.env.NODE_ENV !== 'production';
  const hasOtlpEndpoint = !!process.env.OTEL_EXPORTER_OTLP_LOGS_ENDPOINT;
  const logToConsole =
    process.env.LOG_TO_CONSOLE !== undefined
      ? process.env.LOG_TO_CONSOLE === 'true'
      : !hasOtlpEndpoint; // Auto-enable if no OTLP configured

  if (logToConsole) {
    // Colored output for human readability (development mode)
    if (isDevelopment) {
      transports.push(
        new winston.transports.Console({
          format: winston.format.combine(
            winston.format.colorize({ all: true }),
            winston.format.timestamp({ format: 'HH:mm:ss' }),
            winston.format.printf((info) => {
              const service_name = info.service_name || 'unknown';
              return `${info.timestamp} [${info.level}] ${service_name}:${info.function_name} - ${info.message}`;
            })
          ),
        })
      );
    } else {
      // JSON output for production (no colors, structured)
      transports.push(
        new winston.transports.Console({
          format: winston.format.combine(winston.format.timestamp(), winston.format.json()),
        })
      );
    }
  }

  // 2. FILE TRANSPORT: Smart default (enabled unless explicitly disabled)
  const logToFile =
    process.env.LOG_TO_FILE !== undefined ? process.env.LOG_TO_FILE === 'true' : true; // Default: enabled

  if (logToFile) {
    const logFilePath = process.env.LOG_FILE_PATH || './logs/dev.log';

    transports.push(
      new winston.transports.File({
        filename: logFilePath,
        format: winston.format.combine(winston.format.timestamp(), winston.format.json()),
        maxsize: 50 * 1024 * 1024, // 50MB max file size
        maxFiles: 5, // Keep 5 rotated files
        tailable: true, // Use rotating file names
      })
    );

    console.log(`📝 File logging enabled: ${logFilePath}`);
  }

  // 3. ERROR FILE TRANSPORT: Separate file for errors only (best practice)
  if (logToFile) {
    const errorLogPath = process.env.ERROR_LOG_PATH || './logs/error.log';

    transports.push(
      new winston.transports.File({
        filename: errorLogPath,
        level: 'error',
        format: winston.format.combine(winston.format.timestamp(), winston.format.json()),
        maxsize: 10 * 1024 * 1024, // 10MB max file size
        maxFiles: 3, // Keep 3 rotated error files
      })
    );
  }

  // 4. OPENTELEMETRY TRANSPORT: Always enabled for centralized logging
  if (serviceName) {
    transports.push(
      new open_telemetry_winston_transport({
        serviceName: serviceName,
        level: 'silly', // Include all levels
      })
    );
    console.log('📡 OpenTelemetry Winston transport configured');
  }

  return transports;
}

/**
 * Winston logger configuration for structured output
 * Uses multiple simultaneous transports following best practices
 */
let baseLogger: winston.Logger;

/**
 * Initialize Winston logger with serviceName for OpenTelemetry transport
 */
function initializeWinstonLogger(serviceName: string): void {
  baseLogger = winston.createLogger({
    level: 'silly', // Include all levels (silly = trace)
    transports: createTransports(serviceName),
    exitOnError: false, // Don't exit on handled exceptions
  });
}

// =============================================================================
// INTERNAL LOGGER IMPLEMENTATION
// =============================================================================

/**
 * Internal logger class - handles all complexity, hidden from developers
 * IMPROVED: No manual trace injection - relies on OpenTelemetry auto-instrumentation
 */
class internal_sovdev_logger {
  private readonly service_name: string;
  private readonly service_version: string;
  private readonly system_ids_mapping: Record<string, string>;

  constructor(
    service_name: string,
    service_version: string,
    system_ids: Record<string, string> = {}
  ) {
    this.service_name = service_name;
    this.service_version = service_version;
    this.system_ids_mapping = system_ids;
  }

  /**
   * Resolve friendly name to CMDB ID or service name for internal operations
   */
  private resolve_peer_service(friendly_name?: string): string {
    // Default to INTERNAL if no peer service provided
    const effective_name = friendly_name || 'INTERNAL';

    // If INTERNAL, use the service's own name
    if (effective_name === 'INTERNAL') {
      return this.service_name;
    }

    // Try to resolve from mapping
    const resolved_id = this.system_ids_mapping[effective_name];
    if (!resolved_id) {
      console.warn(
        `⚠️ Unknown peer service: ${effective_name}. Available: ${Object.keys(this.system_ids_mapping).join(', ')} or INTERNAL`
      );
      return effective_name; // Use as-is if not found
    }
    return resolved_id;
  }

  /**
   * Create a complete structured log entry with all required fields
   * Uses snake_case field names for consistency across all languages
   */
  private create_log_entry(
    level: sovdev_log_level,
    function_name: string,
    message: string,
    peer_service?: string,
    exception_object?: any,
    input_json?: any,
    response_json?: any,
    log_type?: string
  ): structured_log_entry {
    // Generate unique event ID for this log entry
    const event_id = uuidv4();

    // Generate temporary trace_id - will be overridden by write_log if active span exists
    // If no active span, this provides a fallback trace_id for the log entry
    const temp_trace_id = uuidv4().replace(/-/g, '');

    // Resolve friendly name to CMDB ID (defaults to service_name for INTERNAL)
    const resolved_peer_service = this.resolve_peer_service(peer_service);

    // Process exception object if provided (returns flat fields with dot notation)
    const processed_exception = this.process_exception(exception_object);

    // Create the complete log entry with snake_case fields
    // NOTE: Do NOT include 'level' field here - Winston will add it based on .log(level, entry)
    const log_entry: structured_log_entry = {
      timestamp: new Date().toISOString(),
      // level field omitted - Winston will set it
      service_name: this.service_name,
      service_version: this.service_version,
      peer_service: resolved_peer_service,
      function_name,
      message,
      trace_id: temp_trace_id,
      // span_id will be populated by write_log if active span exists (optional field)
      event_id: event_id,
      log_type: log_type || 'transaction', // Default to transaction if not specified
      input_json,
      response_json,
      // Spread exception fields at top level (exception_type, exception_message, exception_stacktrace)
      ...processed_exception,
    };

    // Remove undefined fields for cleaner JSON
    return this.remove_undefined_fields(log_entry);
  }

  /**
   * Process exception objects with security cleanup and standardization
   * Returns flat fields using snake_case (exception_type, exception_message, exception_stacktrace)
   */
  private process_exception(
    exception_object: any
  ):
    | { exception_type: string; exception_message: string; exception_stacktrace?: string }
    | undefined {
    if (!exception_object) {
      return undefined;
    }

    let clean_exception = exception_object;

    // Security: Remove sensitive data from axios errors
    if (typeof exception_object === 'object' && exception_object !== null) {
      if (exception_object.config?.auth) {
        clean_exception = { ...exception_object };
        delete clean_exception.config.auth;
      }
      if (exception_object.config?.headers?.Authorization) {
        clean_exception = { ...clean_exception };
        delete clean_exception.config.headers.Authorization;
      }
    }

    // Extract exception information
    if (typeof clean_exception === 'object' && clean_exception !== null) {
      let stack_trace = clean_exception.stack || '';

      // Limit stack trace to 350 characters
      if (stack_trace.length > 350) {
        stack_trace = stack_trace.substring(0, 350);
      }

      // Return flat fields with snake_case (project standard)
      return {
        exception_type: clean_exception.constructor?.name || clean_exception.name || 'Error',
        exception_message: clean_exception.message || String(clean_exception),
        exception_stacktrace: stack_trace,
      };
    } else {
      // For non-object exceptions (strings, numbers, etc.)
      return {
        exception_type: 'Unknown',
        exception_message: String(clean_exception),
      };
    }
  }

  /**
   * Remove undefined fields for cleaner JSON output
   */
  private remove_undefined_fields(obj: any): any {
    return Object.fromEntries(Object.entries(obj).filter(([_, value]) => value !== undefined));
  }

  /**
   * Write log entry using Winston (multiple transports including OTLP)
   * IMPROVED: Automatically emit metrics for complete observability
   */
  private write_log(level: string, log_entry: structured_log_entry): void {
    const start_time = Date.now();

    try {
      // Extract trace ID and span ID from active span (stored in AsyncLocalStorage)
      // This links logs to traces automatically without creating new spans
      // IMPORTANT: Only use span if it hasn't been ended yet (prevents bleed-through)
      const active_span = spanStorage.getStore();
      if (active_span && !endedSpans.has(active_span)) {
        const span_context = active_span.spanContext();
        if (span_context.traceId) {
          // Override log trace_id with the active span's trace ID
          // This ensures logs and traces are correlated properly
          log_entry.trace_id = span_context.traceId;
        }
        if (span_context.spanId) {
          // Extract span ID for operation-level correlation
          log_entry.span_id = span_context.spanId;
        }
      }

      // Emit metrics automatically (zero developer effort)
      if (globalMetrics) {
        const attributes = {
          service_name: log_entry.service_name,
          service_version: log_entry.service_version,
          peer_service: log_entry.peer_service,
          log_level: level,
          log_type: log_entry.log_type,
        };

        // Increment active operations
        globalMetrics.activeOperations.add(1, attributes);

        // Increment operation counter
        globalMetrics.operationCounter.add(1, attributes);

        // Track errors separately
        if (level === 'ERROR' || level === 'FATAL' || log_entry.exception_type) {
          const error_attributes = {
            ...attributes,
            exception_type: log_entry.exception_type || 'Unknown',
          };
          globalMetrics.errorCounter.add(1, error_attributes);
        }
      }

      // Send to Winston - Winston will handle all transports including OTLP
      baseLogger.log(this.map_to_winston_level(level), log_entry);

      // Record operation duration and decrement active operations
      if (globalMetrics) {
        const duration = Date.now() - start_time;
        const attributes = {
          service_name: log_entry.service_name,
          service_version: log_entry.service_version,
          peer_service: log_entry.peer_service,
          log_level: level,
          log_type: log_entry.log_type,
        };
        globalMetrics.operationDuration.record(duration, attributes);
        globalMetrics.activeOperations.add(-1, attributes);
      }
    } catch (err) {
      // Fallback - logging should never break the application
      console.error('Sovdev Logger failed:', err);
      console.log(JSON.stringify(log_entry));

      // Decrement active operations on error
      if (globalMetrics) {
        const attributes = {
          service_name: log_entry.service_name,
          service_version: log_entry.service_version,
          peer_service: log_entry.peer_service,
          log_level: level,
          log_type: log_entry.log_type,
        };
        globalMetrics.activeOperations.add(-1, attributes);
      }
    }
  }

  /**
   * Map custom log levels to Winston levels
   * FIXED: Accept lowercase levels from SOVDEV_LOGLEVELS constants
   */
  private map_to_winston_level(level: string): string {
    switch (level.toLowerCase()) {
      case 'trace':
        return 'debug'; // Winston doesn't have trace, map to debug
      case 'debug':
        return 'debug';
      case 'info':
        return 'info';
      case 'warn':
        return 'warn';
      case 'error':
        return 'error';
      case 'fatal':
        return 'error'; // Winston doesn't have fatal, map to error
      default:
        return 'info';
    }
  }

  /**
   * Main logging method - for transaction/request-response logs
   */
  public log(
    level: sovdev_log_level,
    function_name: string,
    message: string,
    peer_service: string,
    input_json?: any,
    response_json?: any,
    exception_object?: any
  ): void {
    const log_entry = this.create_log_entry(
      level,
      function_name,
      message,
      peer_service,
      exception_object,
      input_json,
      response_json,
      'transaction'
    );
    this.write_log(level, log_entry);
  }

  /**
   * Job status logging - for batch job start/complete/failed events
   */
  public log_job_status(
    level: sovdev_log_level,
    function_name: string,
    job_name: string,
    status: string,
    peer_service: string,
    input_json?: any
  ): void {
    const message = `Job ${status}: ${job_name}`;
    const context_input = {
      job_name,
      job_status: status,
      ...input_json,
    };

    const log_entry = this.create_log_entry(
      level,
      function_name,
      message,
      peer_service,
      null,
      context_input,
      null,
      'job.status'
    );
    this.write_log(level, log_entry);
  }

  /**
   * Job progress logging - for tracking batch processing progress (X of Y)
   */
  public log_job_progress(
    level: sovdev_log_level,
    function_name: string,
    job_name: string,
    item_id: string,
    current: number,
    total: number,
    peer_service: string,
    input_json?: any
  ): void {
    const message = `Processing ${item_id} (${current}/${total})`;
    const context_input = {
      job_name,
      item_id,
      current_item: current,
      total_items: total,
      progress_percentage: Math.round((current / total) * 100),
      ...input_json,
    };

    const log_entry = this.create_log_entry(
      level,
      function_name,
      message,
      peer_service,
      null,
      context_input,
      null,
      'job.progress'
    );
    this.write_log(level, log_entry);
  }
}

// =============================================================================
// OPENTELEMETRY CONFIGURATION (IMPROVED)
// =============================================================================

/**
 * Configure OpenTelemetry Metrics
 * Creates automatic metrics for operations, errors, duration, and active operations
 */
function configure_metrics(
  service_name: string,
  service_version: string,
  session_id: string
): MeterProvider | null {
  try {
    const resource = new Resource({
      [ATTR_SERVICE_NAME]: service_name,
      [ATTR_SERVICE_VERSION]: service_version,
      [SEMRESATTRS_DEPLOYMENT_ENVIRONMENT]: process.env.NODE_ENV || 'development',
      session_id: session_id, // Session grouping for execution tracking
    });

    // Configure metric exporter with cumulative temporality for Prometheus compatibility.
    // No explicit `headers` here — OTEL_EXPORTER_OTLP_HEADERS is a standard OTel env
    // var (key1=value1,key2=value2 format); the exporter reads it natively.
    const metric_exporter = new OTLPMetricExporter({
      url: process.env.OTEL_EXPORTER_OTLP_METRICS_ENDPOINT || 'http://localhost:4318/v1/metrics',
      temporalityPreference: 1, // 1 = CUMULATIVE (Prometheus compatible)
    });

    // Create periodic metric reader (export every 10 seconds)
    const metric_reader = new PeriodicExportingMetricReader({
      exporter: metric_exporter,
      exportIntervalMillis: 10000, // 10 seconds
    });

    // Create MeterProvider
    const meter_provider = new MeterProvider({
      resource,
      readers: [metric_reader],
    });

    // Set global meter provider
    metrics.setGlobalMeterProvider(meter_provider);

    // Create meter and metrics
    const meter = meter_provider.getMeter(service_name, service_version);

    globalMetrics = {
      operationCounter: meter.createCounter('sovdev.operations.total', {
        description: 'Total number of operations by service, peer service, and log level',
        unit: '1',
      }),

      errorCounter: meter.createCounter('sovdev.errors.total', {
        description: 'Total number of errors by service, peer service, and exception type',
        unit: '1',
      }),

      operationDuration: meter.createHistogram('sovdev.operation.duration', {
        description: 'Duration of operations in milliseconds',
        unit: 'ms',
      }),

      activeOperations: meter.createUpDownCounter('sovdev.operations.active', {
        description: 'Number of currently active operations',
        unit: '1',
      }),
    };

    console.log(
      '📊 OTLP Metrics configured for:',
      process.env.OTEL_EXPORTER_OTLP_METRICS_ENDPOINT || 'http://localhost:4318/v1/metrics'
    );
    console.log(
      '📊 Metrics: operations.total, errors.total, operation.duration, operations.active'
    );
    console.log('📊 Temporality: CUMULATIVE (Prometheus compatible)');

    return meter_provider;
  } catch (error) {
    console.warn('⚠️  Metrics configuration failed:', error);
    return null;
  }
}

/**
 * Configure OpenTelemetry with both trace AND log exporters
 * IMPROVED: Full OTLP integration for complete observability
 */
function configure_opentelemetry(
  service_name: string,
  service_version: string,
  session_id: string
): {
  sdk: NodeSDK | null;
  loggerProvider: LoggerProvider | null;
  tracerProvider: BasicTracerProvider | null;
} {
  try {
    const resource = new Resource({
      [ATTR_SERVICE_NAME]: service_name,
      [ATTR_SERVICE_VERSION]: service_version,
      [SEMRESATTRS_DEPLOYMENT_ENVIRONMENT]: process.env.NODE_ENV || 'development',
      session_id: session_id, // Session grouping for execution tracking
    });

    // Configure exporters based on environment
    const environment = process.env.NODE_ENV || 'development';

    // TRACE EXPORTER AND PROVIDER
    // CRITICAL: Must create and register TracerProvider BEFORE SDK initialization
    // The SDK's auto-instrumentation needs an active TracerProvider to work
    const trace_endpoint =
      process.env.OTEL_EXPORTER_OTLP_TRACES_ENDPOINT ||
      process.env.OTEL_EXPORTER_OTLP_ENDPOINT ||
      'http://localhost:4318/v1/traces';

    // No explicit `headers` here — OTEL_EXPORTER_OTLP_HEADERS is a standard OTel env
    // var (key1=value1,key2=value2 format); the exporter reads it natively.
    const trace_exporter = new OTLPTraceExporter({
      url: trace_endpoint,
    });

    const tracer_provider = new BasicTracerProvider({ resource });
    // Configure BatchSpanProcessor for short-lived applications
    // Default scheduledDelayMillis=5000ms is too long for tests/short apps
    tracer_provider.addSpanProcessor(
      new BatchSpanProcessor(trace_exporter, {
        maxQueueSize: 2048, // Default: keep large queue
        scheduledDelayMillis: 1000, // Export every 1s (vs default 5s)
        exportTimeoutMillis: 30000, // Default: 30s timeout
        maxExportBatchSize: 512, // Default: batch size
      })
    );

    // CRITICAL: Set global BEFORE SDK initialization
    trace.setGlobalTracerProvider(tracer_provider);

    console.log('🔍 OTLP Trace exporter configured for:', trace_endpoint);
    console.log('✅ Global TracerProvider set (before SDK)');

    // LOG EXPORTER (NEW - IMPROVED)
    let logger_provider: LoggerProvider | null = null;
    const log_endpoint = process.env.OTEL_EXPORTER_OTLP_LOGS_ENDPOINT;

    if (log_endpoint || environment === 'development') {
      // No explicit `headers` here — OTEL_EXPORTER_OTLP_HEADERS is a standard OTel env
      // var (key1=value1,key2=value2 format); the exporter reads it natively.
      const log_exporter = new OTLPLogExporter({
        url: log_endpoint || 'http://localhost:4318/v1/logs',
      });

      const log_record_processor = new BatchLogRecordProcessor(log_exporter);
      logger_provider = new LoggerProvider({
        resource,
      });
      logger_provider.addLogRecordProcessor(log_record_processor);
      console.log(
        '📡 OTLP Log exporter configured for:',
        log_endpoint || 'http://localhost:4318/v1/logs'
      );
      console.log('📡 BatchLogRecordProcessor added to LoggerProvider');
    }

    // NODE SDK CONFIGURATION (auto-instrumentation)
    // NOTE: TracerProvider is already set globally above, SDK will use it
    const sdk = new NodeSDK({
      resource,
      instrumentations: [
        getNodeAutoInstrumentations({
          // Enable Winston instrumentation for automatic trace context injection
          '@opentelemetry/instrumentation-winston': { enabled: true },
          // Enable HTTP instrumentation for automatic span creation on http/https calls
          '@opentelemetry/instrumentation-http': { enabled: true },
          // Disable verbose instrumentations for development
          '@opentelemetry/instrumentation-fs': { enabled: false },
          '@opentelemetry/instrumentation-dns': { enabled: false },
        }),
      ],
    });

    console.log('🔗 OpenTelemetry SDK initialized for', service_name);
    console.log('🔍 Auto-instrumentation includes Winston and HTTP integration');

    return { sdk, loggerProvider: logger_provider, tracerProvider: tracer_provider };
  } catch (error) {
    console.warn('⚠️  OpenTelemetry SDK configuration failed:', error);
    return { sdk: null, loggerProvider: null, tracerProvider: null };
  }
}

// =============================================================================
// GLOBAL LOGGER INSTANCE MANAGEMENT
// =============================================================================

/**
 * Global logger instance - initialized once per application
 */
let globalLogger: internal_sovdev_logger | null = null;

/**
 * Global OpenTelemetry SDK instance
 */
let otelSDK: NodeSDK | null = null;

/**
 * Global OpenTelemetry LoggerProvider instance for flushing
 */
let globalLoggerProvider: LoggerProvider | null = null;

/**
 * Global session ID - generated once per application execution
 * Groups all logs, metrics, and traces from this run
 * TODO: Currently unused - implement session tracking in future
 */
// let globalSessionId: string | null = null;

// =============================================================================
// CONFIGURATION VALIDATION FUNCTIONS
// =============================================================================

/**
 * Validate environment configuration for OTLP exporters
 *
 * Returns validation results without throwing errors or exiting.
 * Useful for:
 * - Debugging why OTLP data isn't appearing in Loki/Prometheus/Tempo
 * - Verifying .env file is loaded correctly
 * - Pre-flight checks in test programs
 *
 * NOTE: File logging works without OTLP config, so missing variables
 * are warnings, not errors.
 *
 * @returns Validation results object
 *
 * @example
 * ```typescript
 * const validation = sovdev_validate_config();
 *
 * if (!validation.valid) {
 *   console.warn('⚠️  OTLP configuration incomplete:');
 *   validation.missing.forEach(v => console.warn(`  - ${v}`));
 *   console.warn('File logging will work, but OTLP export disabled.');
 * }
 * ```
 */
export function sovdev_validate_config(): {
  valid: boolean;
  missing: string[];
  warnings: string[];
  config: {
    serviceName: string | undefined;
    logsEndpoint: string | undefined;
    metricsEndpoint: string | undefined;
    tracesEndpoint: string | undefined;
    headers: string | undefined;
    protocol: string | undefined;
  };
} {
  const missing: string[] = [];
  const warnings: string[] = [];

  // Read environment variables
  const serviceName = process.env.OTEL_SERVICE_NAME;
  const logsEndpoint = process.env.OTEL_EXPORTER_OTLP_LOGS_ENDPOINT;
  const metricsEndpoint = process.env.OTEL_EXPORTER_OTLP_METRICS_ENDPOINT;
  const tracesEndpoint = process.env.OTEL_EXPORTER_OTLP_TRACES_ENDPOINT;
  const headers = process.env.OTEL_EXPORTER_OTLP_HEADERS;
  const protocol = process.env.OTEL_EXPORTER_OTLP_PROTOCOL;

  // Check required variables
  if (!serviceName) missing.push('OTEL_SERVICE_NAME');
  if (!logsEndpoint) missing.push('OTEL_EXPORTER_OTLP_LOGS_ENDPOINT');
  if (!metricsEndpoint) missing.push('OTEL_EXPORTER_OTLP_METRICS_ENDPOINT');
  if (!tracesEndpoint) missing.push('OTEL_EXPORTER_OTLP_TRACES_ENDPOINT');

  // Check headers are set. What headers are actually needed is backend-specific
  // (a Host header for Traefik-routed local setups, an Authorization header for
  // token-authenticated cloud backends, none at all for a bare local collector) —
  // this check only confirms the variable exists, not its contents.
  if (!headers) {
    missing.push('OTEL_EXPORTER_OTLP_HEADERS');
  }

  // Check protocol (optional but recommended)
  if (!protocol) {
    warnings.push('OTEL_EXPORTER_OTLP_PROTOCOL not set (default: grpc, recommended: http/protobuf)');
  }

  return {
    valid: missing.length === 0,
    missing,
    warnings,
    config: {
      serviceName,
      logsEndpoint,
      metricsEndpoint,
      tracesEndpoint,
      headers,
      protocol
    }
  };
}

/**
 * Generate minimal valid OTLP logs payload
 */
function generateOtlpLogsPayload(): string {
  const now = Date.now() * 1000000; // Convert to nanoseconds
  return JSON.stringify({
    resourceLogs: [
      {
        resource: {
          attributes: [{ key: 'service.name', value: { stringValue: 'connectivity-test' } }]
        },
        scopeLogs: [
          {
            scope: { name: 'connectivity-test' },
            logRecords: [
              {
                timeUnixNano: now.toString(),
                severityNumber: 9,
                severityText: 'INFO',
                body: { stringValue: 'OTLP connectivity test' }
              }
            ]
          }
        ]
      }
    ]
  });
}

/**
 * Generate minimal valid OTLP metrics payload
 */
function generateOtlpMetricsPayload(): string {
  const now = Date.now() * 1000000; // Convert to nanoseconds
  return JSON.stringify({
    resourceMetrics: [
      {
        resource: {
          attributes: [{ key: 'service.name', value: { stringValue: 'connectivity-test' } }]
        },
        scopeMetrics: [
          {
            scope: { name: 'connectivity-test' },
            metrics: [
              {
                name: 'connectivity.test',
                sum: {
                  dataPoints: [
                    {
                      asInt: '1',
                      timeUnixNano: now.toString()
                    }
                  ],
                  aggregationTemporality: 2,
                  isMonotonic: true
                }
              }
            ]
          }
        ]
      }
    ]
  });
}

/**
 * Generate minimal valid OTLP traces payload
 */
function generateOtlpTracesPayload(): string {
  const now = Date.now() * 1000000; // Convert to nanoseconds
  const traceId = '0123456789abcdef0123456789abcdef';
  const spanId = '0123456789abcdef';

  return JSON.stringify({
    resourceSpans: [
      {
        resource: {
          attributes: [{ key: 'service.name', value: { stringValue: 'connectivity-test' } }]
        },
        scopeSpans: [
          {
            scope: { name: 'connectivity-test' },
            spans: [
              {
                traceId: traceId,
                spanId: spanId,
                name: 'connectivity-test',
                kind: 1,
                startTimeUnixNano: now.toString(),
                endTimeUnixNano: (now + 1000000).toString(),
                status: { code: 1 }
              }
            ]
          }
        ]
      }
    ]
  });
}

/**
 * Parse OTEL_EXPORTER_OTLP_HEADERS per the actual OpenTelemetry spec (the W3C
 * Baggage HTTP header format): comma-separated key=value pairs, e.g.
 * "Authorization=Basic dXNlcjpwYXNz,X-Custom=foo". NOT JSON — this is the
 * same format the OTel SDK's own exporters read natively from this env var,
 * so this parser exists only for this module's own diagnostics (config
 * validation, connectivity testing), not for configuring the exporters
 * themselves (see configure_opentelemetry — no headers passed explicitly,
 * the SDK reads the env var on its own).
 */
function parseOtlpHeaders(raw: string): Record<string, string> {
  const headers: Record<string, string> = {};
  for (const pair of raw.split(',')) {
    const [keyValuePart] = pair.split(';'); // strip baggage metadata, if any
    const trimmed = keyValuePart.trim();
    if (!trimmed) continue;
    const separatorIndex = trimmed.indexOf('=');
    if (separatorIndex <= 0) continue;
    const key = trimmed.substring(0, separatorIndex).trim();
    const value = trimmed.substring(separatorIndex + 1).trim();
    if (key && value) headers[key] = value;
  }
  return headers;
}

/**
 * Helper function to test a single OTLP endpoint
 * Sends minimal valid OTLP payload to verify endpoint is reachable
 *
 * NOTE: Uses Node.js http/https module instead of fetch() because
 * fetch() doesn't allow setting the Host header (restricted header)
 */
async function testEndpoint(
  endpoint: string,
  headers: string,
  timeout: number
): Promise<{ reachable: boolean; error?: string }> {
  return new Promise((resolve) => {
    try {
      const headerObj = parseOtlpHeaders(headers);

      // Determine payload type based on endpoint URL
      let payload: string;
      if (endpoint.includes('/v1/logs')) {
        payload = generateOtlpLogsPayload();
      } else if (endpoint.includes('/v1/metrics')) {
        payload = generateOtlpMetricsPayload();
      } else if (endpoint.includes('/v1/traces')) {
        payload = generateOtlpTracesPayload();
      } else {
        payload = '{}';
      }

      // Parse URL
      const url = new URL(endpoint);
      const isHttps = url.protocol === 'https:';
      const httpModule = isHttps ? require('https') : require('http');

      // Prepare request options
      const options = {
        hostname: url.hostname,
        port: url.port || (isHttps ? 443 : 80),
        path: url.pathname,
        method: 'POST',
        headers: {
          ...headerObj,
          'Content-Type': 'application/json',
          'Content-Length': Buffer.byteLength(payload)
        },
        timeout: timeout
      };

      const req = httpModule.request(options, (res: any) => {
        let data = '';
        res.on('data', (chunk: any) => {
          data += chunk;
        });

        res.on('end', () => {
          if (res.statusCode === 200 || res.statusCode === 202) {
            resolve({ reachable: true });
          } else if (res.statusCode === 404) {
            resolve({
              reachable: false,
              error: '404 Not Found - Check Host header in OTEL_EXPORTER_OTLP_HEADERS'
            });
          } else if (res.statusCode === 400) {
            // 400 might mean endpoint is reachable but payload format issue
            resolve({ reachable: true });
          } else {
            resolve({
              reachable: false,
              error: `HTTP ${res.statusCode}: ${res.statusMessage || 'Unknown error'}`
            });
          }
        });
      });

      req.on('error', (error: any) => {
        resolve({
          reachable: false,
          error: error.message || 'Connection failed'
        });
      });

      req.on('timeout', () => {
        req.destroy();
        resolve({
          reachable: false,
          error: `Connection timeout after ${timeout}ms`
        });
      });

      // Send payload
      req.write(payload);
      req.end();
    } catch (error: any) {
      resolve({
        reachable: false,
        error: error.message || 'Connection failed'
      });
    }
  });
}

/**
 * Test connectivity to OTLP collector endpoints
 *
 * OPTIONAL: Only call this if you want to verify OTLP endpoints are reachable.
 *
 * Sends minimal test requests to each OTLP endpoint to verify:
 * - Endpoint URLs are correct
 * - Network connectivity works
 * - Traefik routing (Host header) is configured correctly
 *
 * Useful for debugging "why isn't data appearing in Grafana?"
 *
 * @param timeout - Timeout in milliseconds (default: 5000)
 * @returns Connectivity test results for all three endpoints
 *
 * @example
 * ```typescript
 * const connectivity = await sovdev_test_otlp_connection();
 *
 * if (!connectivity.success) {
 *   console.warn('⚠️  OTLP endpoints not reachable:');
 *   if (!connectivity.logs.reachable) {
 *     console.warn(`  Logs: ${connectivity.logs.error}`);
 *   }
 *   console.warn('Proceeding with file logging only...');
 * }
 * ```
 */
export async function sovdev_test_otlp_connection(
  timeout: number = 5000
): Promise<{
  success: boolean;
  logs: { reachable: boolean; error?: string };
  metrics: { reachable: boolean; error?: string };
  traces: { reachable: boolean; error?: string };
}> {
  const config = sovdev_validate_config();

  // If config is invalid, return early with config errors
  if (!config.valid) {
    const configError = `Missing config: ${config.missing.join(', ')}`;
    return {
      success: false,
      logs: { reachable: false, error: configError },
      metrics: { reachable: false, error: configError },
      traces: { reachable: false, error: configError }
    };
  }

  // Test each endpoint in parallel
  const [logs, metrics, traces] = await Promise.all([
    testEndpoint(config.config.logsEndpoint!, config.config.headers!, timeout),
    testEndpoint(config.config.metricsEndpoint!, config.config.headers!, timeout),
    testEndpoint(config.config.tracesEndpoint!, config.config.headers!, timeout)
  ]);

  return {
    success: logs.reachable && metrics.reachable && traces.reachable,
    logs,
    metrics,
    traces
  };
}

// =============================================================================
// INITIALIZATION FUNCTION
// =============================================================================

/**
 * Initialize the Sovdev logger with system identifier and OpenTelemetry SDK
 * Must be called once at application startup
 *
 * @param service_name Service name (e.g., "company-lookup-integration")
 * @param service_version Service version (optional, auto-detected from package.json)
 * @param peer_services Mapping of peer service names to system IDs (use PEER_SERVICES.mappings)
 */
function initialize_sovdev_logger(
  service_name: string,
  service_version?: string,
  peer_services: Record<string, string> = {}
): void {
  const effective_service_name = service_name;
  const effective_service_version = service_version || getServiceVersion();

  // Automatically add INTERNAL peer service pointing to this service
  const effective_system_ids = {
    INTERNAL: service_name, // Always auto-generated
    ...peer_services,
  };

  if (!effective_service_name || effective_service_name.trim() === '') {
    throw new Error(
      'Sovdev Logger: service_name is required. ' +
        'Example: initialize_sovdev_logger("company-lookup-integration", "1.2.3", {...})'
    );
  }

  // Generate session ID once for this execution
  // This automatically groups all logs, metrics, and traces from this run
  const session_id = uuidv4();
  console.log(`🔑 Session ID: ${session_id}`);

  // Initialize OpenTelemetry Metrics FIRST (before SDK)
  if (!globalMeterProvider) {
    globalMeterProvider = configure_metrics(
      effective_service_name,
      effective_service_version,
      session_id
    );
  }

  // Initialize OpenTelemetry SDK with full configuration
  if (!otelSDK) {
    const { sdk, loggerProvider, tracerProvider } = configure_opentelemetry(
      effective_service_name,
      effective_service_version,
      session_id
    );
    otelSDK = sdk;
    globalLoggerProvider = loggerProvider;
    globalTracerProvider = tracerProvider;

    // CRITICAL: Set global logs provider BEFORE starting SDK and creating Winston logger
    // This ensures Winston's OpenTelemetryTransport gets the correct LoggerProvider
    if (loggerProvider) {
      logs.setGlobalLoggerProvider(loggerProvider);
      console.log('✅ Global LoggerProvider set');
    }

    if (otelSDK) {
      try {
        otelSDK.start();
        console.log('✅ OpenTelemetry SDK started successfully');
      } catch (error) {
        console.warn('⚠️  OpenTelemetry SDK start failed:', error);
        // Continue - logging should work without OTEL
      }
    }
  }

  // Initialize Winston logger with service_name for OpenTelemetry transport
  // This must happen AFTER global LoggerProvider is set
  initializeWinstonLogger(effective_service_name.trim());

  globalLogger = new internal_sovdev_logger(
    effective_service_name.trim(),
    effective_service_version,
    effective_system_ids
  );

  const is_development = process.env.NODE_ENV !== 'production';
  const has_otlp_endpoint = !!process.env.OTEL_EXPORTER_OTLP_LOGS_ENDPOINT;
  const log_to_console =
    process.env.LOG_TO_CONSOLE !== undefined
      ? process.env.LOG_TO_CONSOLE === 'true'
      : !has_otlp_endpoint;
  const log_to_file =
    process.env.LOG_TO_FILE !== undefined ? process.env.LOG_TO_FILE === 'true' : true;

  console.log('🚀 Sovdev Logger initialized:');
  console.log(`   ├── Service: ${effective_service_name}`);
  console.log(`   ├── Version: ${effective_service_version}`);
  console.log(
    `   ├── Systems: ${Object.keys(effective_system_ids).join(', ') || 'None configured'}`
  );
  console.log(
    `   ├── Console: ${log_to_console ? (is_development ? 'Colored (dev)' : 'JSON (prod)') : 'Disabled'}`
  );
  console.log(`   ├── File: ${log_to_file ? 'Enabled' : 'Disabled'}`);
  console.log(
    `   └── OTLP: ${has_otlp_endpoint ? 'Configured' : '⚠️  Not configured (using localhost:4318)'}`
  );

  if (!has_otlp_endpoint && !log_to_console && !log_to_file) {
    console.warn('⚠️  WARNING: All logging outputs are disabled!');
    console.warn(
      '   Set OTEL_EXPORTER_OTLP_LOGS_ENDPOINT, LOG_TO_CONSOLE=true, or LOG_TO_FILE=true'
    );
  }
}

/**
 * Ensure logger is initialized before use
 */
function ensure_logger(): internal_sovdev_logger {
  if (!globalLogger) {
    throw new Error(
      'Sovdev Logger not initialized. Call sovdev_initialize(service_name) at application startup.'
    );
  }
  return globalLogger;
}

// =============================================================================
// PUBLIC API - IDENTICAL ACROSS ALL LANGUAGES
// =============================================================================

/**
 * General purpose logging function
 *
 * @param level Log level from SOVDEV_LOGLEVELS constants
 * @param function_name Name of the function where logging occurs
 * @param message Human-readable description of what happened
 * @param peer_service Peer service identifier (use PEER_SERVICES.INTERNAL for internal operations)
 * @param input_json Valid JSON object containing function input parameters (optional)
 * @param response_json Valid JSON object containing function output/response data (optional)
 * @param exception_object Exception/error object (optional, null if no exception)
 */
export function sovdev_log(
  level: sovdev_log_level,
  function_name: string,
  message: string,
  peer_service: string,
  input_json?: any,
  response_json?: any,
  exception_object?: any
): void {
  ensure_logger().log(
    level,
    function_name,
    message,
    peer_service,
    input_json,
    response_json,
    exception_object
  );
}

/**
 * Log job lifecycle events (start, completion, failure)
 *
 * @param level Log level from SOVDEV_LOGLEVELS constants
 * @param function_name Name of the function managing the job
 * @param job_name Name of the job being tracked
 * @param status Job status (e.g., "Started", "Completed", "Failed")
 * @param input_json Additional job context variables (optional)
 */
export function sovdev_log_job_status(
  level: sovdev_log_level,
  function_name: string,
  job_name: string,
  status: string,
  peer_service: string,
  input_json?: any
): void {
  ensure_logger().log_job_status(level, function_name, job_name, status, peer_service, input_json);
}

/**
 * Log processing progress for batch operations
 *
 * @param level Log level from SOVDEV_LOGLEVELS constants
 * @param function_name Name of the function doing the processing
 * @param item_id Identifier for the item being processed
 * @param current Current item number (1-based)
 * @param total Total number of items to process
 * @param input_json Additional context variables for this item (optional)
 */
export function sovdev_log_job_progress(
  level: sovdev_log_level,
  function_name: string,
  item_id: string,
  current: number,
  total: number,
  peer_service: string,
  input_json?: any
): void {
  ensure_logger().log_job_progress(
    level,
    function_name,
    'BatchProcessing',
    item_id,
    current,
    total,
    peer_service,
    input_json
  );
}

/**
 * Start a new span to track an operation's timing and hierarchy.
 *
 * Creates an OpenTelemetry span that automatically:
 * - Generates or inherits trace_id (from parent span or creates new)
 * - Generates unique span_id for this operation
 * - Records start time
 * - Sets span as "active" so logs automatically get trace_id and span_id
 * - Exports to Tempo via OTLP when ended
 *
 * @param operation_name - Name of the operation (e.g., "lookupCompany", "processPayment")
 * @param attributes - Optional metadata to make traces searchable in Grafana
 *                     Recommended: Pass input data like { userId: "123", orderId: "456" }
 *                     Optional: Omit for simple operations where timing alone is sufficient
 * @returns Span - Opaque handle that must be passed to sovdev_end_span()
 *
 * @example With attributes (recommended for production):
 * ```typescript
 * const FUNCTIONNAME = 'lookupCompany';
 * const input = { organisasjonsnummer: '971277882' };
 * const span = sovdev_start_span(FUNCTIONNAME, input);
 * try {
 *   sovdev_log(SOVDEV_LOGLEVELS.INFO, FUNCTIONNAME, 'Looking up company', PEER_SERVICES.BRREG, input);
 *   const data = await fetchCompanyData(orgNumber);
 *   sovdev_end_span(span);
 *   return data;
 * } catch (error) {
 *   sovdev_end_span(span, error);
 *   throw error;
 * }
 * ```
 *
 * @example Without attributes (simpler):
 * ```typescript
 * const FUNCTIONNAME = 'calculateTotal';
 * const span = sovdev_start_span(FUNCTIONNAME);
 * try {
 *   const total = calculateTotal();
 *   sovdev_end_span(span);
 *   return total;
 * } catch (error) {
 *   sovdev_end_span(span, error);
 *   throw error;
 * }
 * ```
 *
 * How trace_id is determined:
 * - If nested inside active parent span → Inherits parent's trace_id
 * - Otherwise → Generates new trace_id (creates new trace)
 *
 * Child spans automatically inherit parent's trace_id - no manual work needed!
 */
export function sovdev_start_span(operation_name: string, attributes?: Record<string, any>): Span {
  // Get tracer from global tracer provider
  if (!globalTracerProvider) {
    throw new Error(
      'Sovdev Logger: TracerProvider not initialized. Call sovdev_initialize() first.'
    );
  }

  const tracer = globalTracerProvider.getTracer('sovdev-logger', '1.0.0');

  // Create span with OpenTelemetry API
  // Span automatically:
  // - Generates trace_id if this is root span
  // - Inherits trace_id from parent if nested
  // - Generates unique span_id
  // - Records start time
  const span = tracer.startSpan(operation_name);

  // Set attributes on span if provided (makes traces searchable in Grafana)
  if (attributes) {
    for (const [key, value] of Object.entries(attributes)) {
      // Convert values to strings for OpenTelemetry compatibility
      if (value !== null && value !== undefined) {
        span.setAttribute(key, typeof value === 'object' ? JSON.stringify(value) : String(value));
      }
    }
  }

  // Store span in AsyncLocalStorage so logs can access it
  // enterWith() sets the value for the current execution context and all subsequent async operations
  // This makes the span "active" for all sovdev_log() calls that follow
  spanStorage.enterWith(span);

  return span;
}

/**
 * End a span, recording completion and calculating duration.
 *
 * This function:
 * - Records end timestamp
 * - Calculates duration (end - start)
 * - Sets span status (OK or ERROR)
 * - Records exception details if error provided
 * - Exports span to Tempo via OTLP
 * - Removes span from "active" context
 *
 * @param span - The span handle returned from sovdev_start_span()
 * @param error - Optional error if operation failed (marks span as failed)
 *
 * @example Success:
 * ```typescript
 * sovdev_end_span(span);
 * ```
 *
 * @example Error:
 * ```typescript
 * catch (error) {
 *   sovdev_end_span(span, error);
 *   throw error;
 * }
 * ```
 *
 * IMPORTANT: Always end spans, even on error! Memory leak if you forget.
 */
export function sovdev_end_span(span: Span, error?: Error): void {
  if (!span) {
    console.warn('⚠️  sovdev_end_span called with null/undefined span');
    return;
  }

  try {
    if (error) {
      // Set span status to ERROR and record exception
      span.setStatus({
        code: SpanStatusCode.ERROR,
        message: error.message || 'Operation failed',
      });

      // Record exception details on the span
      span.recordException(error);
    } else {
      // Set span status to OK
      span.setStatus({ code: SpanStatusCode.OK });
    }

    // End the span (records end time, calculates duration)
    // Span automatically exported to Tempo via OTLP BatchSpanProcessor
    span.end();

    // Mark span as ended so subsequent logs know not to use it
    endedSpans.add(span);

    // Clear the span from AsyncLocalStorage if it's the currently active one
    const currentSpan = spanStorage.getStore();
    if (currentSpan === span) {
      // @ts-expect-error - TypeScript doesn't like undefined but it works fine
      spanStorage.enterWith(undefined);
    }
  } catch (err) {
    console.error('❌ sovdev_end_span failed:', err);
    // Still try to end the span to avoid memory leak
    try {
      span.end();
    } catch {
      // Ignore - we tried
    }
  }
}

// Export types for TypeScript consumers
export type { sovdev_log_level, structured_log_entry };

/**
 * ARCHITECTURE SUMMARY:
 *
 * 1. Multiple Simultaneous Transports:
 *    ├── Console: Smart default (auto if no OTLP) or explicit via LOG_TO_CONSOLE
 *    ├── File: Smart default (on) or explicit via LOG_TO_FILE
 *    └── Error File: Separate file for errors only (when file enabled)
 *
 * 2. OpenTelemetry Full Integration:
 *    ├── Traces: OTLPTraceExporter → OTLP Endpoint
 *    ├── Logs: OTLPLogExporter → OTLP Endpoint
 *    └── Auto-Instrumentation: Winston integration
 *
 * 3. No Manual Trace Injection:
 *    ├── Removed manual trace.getActiveSpan() logic
 *    └── OpenTelemetry auto-instrumentation handles everything
 *
 * 4. Best Practices Implementation:
 *    ├── Winston native features (no custom file I/O)
 *    ├── Proper transport separation and formatting
 *    ├── Error handling and graceful degradation
 *    └── Environment-based configuration
 *
 * Usage:
 *    initializeSovdevLogger("your-system-id");
 *    sovdevLog(SOVDEV_LOGLEVELS.INFO, "MyFunction", "Message", null, input, response);
 */

// =============================================================================
// OPENTELEMETRY LOG FLUSHING
// =============================================================================

/**
 * Flush OpenTelemetry logs, metrics, and traces to ensure they are sent to OTLP collector
 * Call this before application exit to ensure all telemetry is exported
 */
async function flush_sovdev_logs(): Promise<void> {
  try {
    // Flush all providers we created
    if (globalTracerProvider) {
      console.log('🔄 Flushing OpenTelemetry traces...');
      await globalTracerProvider.forceFlush();
      console.log('✅ OpenTelemetry traces flushed successfully');
    }

    if (globalMeterProvider) {
      console.log('🔄 Flushing OpenTelemetry metrics...');
      await globalMeterProvider.forceFlush();
      console.log('✅ OpenTelemetry metrics flushed successfully');
    }

    if (globalLoggerProvider) {
      console.log('🔄 Flushing OpenTelemetry logs...');
      await globalLoggerProvider.forceFlush();
      console.log('✅ OpenTelemetry logs flushed successfully');
    }

    // Shutdown the SDK and providers
    if (otelSDK) {
      console.log('🔄 Shutting down OpenTelemetry SDK...');
      await otelSDK.shutdown();
      console.log('✅ OpenTelemetry SDK shutdown complete');
    }

    if (globalTracerProvider) {
      console.log('🔄 Shutting down TracerProvider...');
      await globalTracerProvider.shutdown();
      console.log('✅ TracerProvider shutdown complete');
    }

    if (globalMeterProvider) {
      console.log('🔄 Shutting down MeterProvider...');
      await globalMeterProvider.shutdown();
      console.log('✅ MeterProvider shutdown complete');
    }
  } catch (error) {
    console.warn('⚠️  OpenTelemetry flush/shutdown failed:', error);
  }
}

// =============================================================================
// EXPORT ALIASES FOR CONSISTENCY
// =============================================================================

/**
 * Initialize the Sovdev logger with service name, version, and system ID mappings
 * Must be called once at application startup
 *
 * @param service_name Service name (e.g., "company-lookup-integration")
 * @param service_version Service version (optional, auto-detected from package.json)
 * @param system_ids Mapping of friendly names to CMDB IDs (optional)
 *
 * @example
 * ```typescript
 * import { sovdev_initialize } from '@sovdev/logger';
 *
 * sovdev_initialize('company-lookup', '1.0.0', {
 *   'BRREG': process.env.BRREG_SYSTEM_ID,
 *   'CRM': process.env.CRM_SYSTEM_ID
 * });
 * ```
 */
export const sovdev_initialize = initialize_sovdev_logger;

/**
 * Flush all OpenTelemetry telemetry (logs, metrics, traces) before app exit
 * Call this to ensure all buffered telemetry is sent to OTLP endpoints
 *
 * @example
 * ```typescript
 * import { sovdev_flush } from '@sovdev/logger';
 *
 * async function main() {
 *   // ... your application code ...
 *   await sovdev_flush();
 * }
 * ```
 */
export const sovdev_flush = flush_sovdev_logs;
