# Sovdev Logger Design Principles

## Core Philosophy

**Zero-effort observability**: Single log call automatically generates logs, metrics, and traces without additional developer effort.

## Key Design Goals

### 1. Language-Agnostic Consistency
All implementations across programming languages MUST produce identical output structure. This ensures:
- **Grafana Compatibility**: Same queries work across all language implementations
- **Correlation**: Trace IDs and event IDs work seamlessly across microservices in different languages
- **Unified Alerting**: Operators can create alert rules that work regardless of service language
- **Compliance**: Loggeloven av 2025 requirements met consistently across the entire stack

### 2. Multiple Simultaneous Transports
The library outputs to multiple destinations simultaneously (NOT either/or):
- **Console**: Human-readable output for local development
- **File**: JSON log files for archival and debugging
- **Error File**: Separate error-level log file for quick error review
- **OTLP**: OpenTelemetry Protocol for production observability (Loki, Prometheus, Tempo)

**Smart Defaults**:
- Console: Auto-enabled if no OTLP endpoint configured
- File: Always enabled for local debugging
- Error File: Always enabled, contains ERROR and FATAL only
- OTLP: Enabled when endpoint environment variables are set

### 3. Structured Logging
Every log entry is a structured JSON object with standardized fields:
- **Service Context**: service_name, service_version, peer_service
- **Correlation**: trace_id (business transaction), event_id (unique log entry), session_id (execution grouping)
- **Business Context**: function_name, message, log_type (transaction, job.status, job.progress)
- **Data**: input_json, response_json (serialized as JSON strings)
- **Exceptions**: exception_type, exception_message, exception_stacktrace (with security cleanup)
- **Metadata**: timestamp, level, severity_number, severity_text

### 4. Security-Aware by Default
- **Credential Removal**: Automatic cleanup of auth headers, passwords, tokens from exception stack traces
- **Stack Trace Limiting**: Truncated to 350 characters maximum to prevent log flooding
- **Graceful Degradation**: System continues working if OpenTelemetry export fails

### 5. OpenTelemetry Integration

See [Why OTLP](https://sovdev-logger.sovereignsky.no/general/why-otlp) for why this project is built on OpenTelemetry/OTLP specifically, including the real costs — this section covers what the integration provides, not why it was chosen.

Full OpenTelemetry SDK integration providing:
- **Logs**: OTLP log export with semantic conventions
- **Metrics**: Automatic counters and histograms from log calls
  - `sovdev_operations_total`: Counter for all operations
  - `sovdev_errors_total`: Counter for errors by type
  - `sovdev_operation_duration`: Histogram for operation timings
  - `sovdev_operations_active`: UpDownCounter for active operations
- **Traces**: Automatic span creation for every log call with proper attributes
- **Session Grouping**: UUID-based session ID correlates all telemetry from a single execution

### 6. Loggeloven av 2025 Compliance
Norwegian logging law compliance built-in with required fields:
- **timestamp**: ISO 8601 format - when the log entry was created
- **level**: Log severity (info, error, etc.)
- **service_name**: Service identifier - which application logged this
- **service_version**: Service version - which version of the application
- **peer_service**: Target system/service - which external system was involved
- **function_name**: Function where logging occurs - which function/operation
- **message**: Human-readable description - what happened
- **trace_id**: Business transaction identifier - correlate all logs for one business operation
- **event_id**: Unique identifier for this log entry - unique ID for this specific log
- **log_type**: Type of log (transaction, job.status, job.progress) - categorize the log
- **input_json**: Request/input data - what was sent/requested (audit trail)
- **response_json**: Response/output data - what was received/returned (audit trail)

**Audit Trail Purpose**: The input_json and response_json fields provide complete audit trail showing what data was processed, which is critical for compliance investigations and debugging. These fields MUST always be present (value "null" when no data exists) to ensure consistent query patterns in Grafana.

### 7. Peer Service Identification with CMDB System IDs

**Architectural Principle**: Every external system and service has a unique identifier in the organization's Configuration Management Database (CMDB). Logs MUST use these standardized system IDs instead of URLs, hostnames, or service names.

**Why System IDs Matter**:
- **Stable Identifier**: URLs and hostnames change, system IDs don't
- **Environment-Agnostic**: Same system ID works across dev/test/prod
- **Cross-Service Correlation**: All services use the same ID for the same external system
- **CMDB Integration**: Operators can look up system details in CMDB using the ID
- **Dependency Mapping**: Visualize which services depend on which systems

**Peer Service Types**:
1. **External Systems**: Third-party APIs, databases, partner systems (use CMDB system IDs like `SYS1234567`)
2. **INTERNAL**: The service itself (auto-generated, equals service name)

**Implementation**: Use `create_peer_services()` for type-safe peer service mapping. See `03-implementation-patterns.md` → **Peer Service Identification** for detailed implementation patterns, examples, and resolution mechanism.

### 8. Batch Job Support
Purpose-built functions for tracking batch operations:
- **Job Status**: Start, completion, failure tracking
- **Job Progress**: Item-by-item progress logging
- **Correlation**: Single traceId links all job-related logs

### 9. Environment-Based Configuration
Configuration through environment variables:
- **Service**: SERVICE_NAME, SERVICE_VERSION
- **Logging**: LOG_TO_CONSOLE, LOG_TO_FILE, LOG_FILE_PATH
- **OpenTelemetry**: OTEL_EXPORTER_OTLP_LOGS_ENDPOINT, OTEL_EXPORTER_OTLP_METRICS_ENDPOINT, OTEL_EXPORTER_OTLP_TRACES_ENDPOINT, OTEL_EXPORTER_OTLP_HEADERS

### 10. Use Established Logging Libraries (DO NOT Reinvent)

**Critical Architectural Decision**: Implementations MUST use mature, established logging libraries for structured logging and file management. DO NOT create custom logging implementations from scratch.

**Why This Matters**:
- **Battle-Tested**: Established libraries handle edge cases (file permissions, rotation, thread safety, performance)
- **Maintenance**: Libraries are maintained by communities, not our small team
- **Features**: File rotation, buffering, formatting are complex - use existing solutions
- **Focus**: Our library is a **wrapper** that standardizes output, not a logging engine

**Recommended Libraries by Language**: See `03-implementation-patterns.md` → **Logging Library Selection** for detailed recommendations, rationale, and implementation examples for TypeScript, Python, Go, Java, C#, PHP, and Rust.

**Our Library's Responsibility**:
1. ✅ Provide 8 API functions (sovdev_log, sovdev_initialize, sovdev_flush, sovdev_start_span, sovdev_end_span, etc.)
2. ✅ Standardize field names and structure
3. ✅ Handle OpenTelemetry integration
4. ✅ Remove credentials from stack traces
5. ✅ Enforce "Error" exception type
6. ❌ NOT implement file writing/rotation (use library)
7. ❌ NOT implement console formatting (use library)

### 11. Distributed Tracing with OpenTelemetry Spans

**Architectural Decision (October 2025)**: Use OpenTelemetry span-based distributed tracing for correlated operations.

**Usage Pattern**:
```typescript
// ✅ OpenTelemetry spans for distributed tracing
sovdev_start_span('operationName');
try {
  sovdev_log(...);  // trace_id and span_id added automatically
} finally {
  sovdev_end_span();  // Always end span, even on error
}
```

**Benefits**:
1. **Proper Distributed Tracing**: OpenTelemetry spans provide real distributed tracing, not just correlation
2. **Automatic Propagation**: trace_id and span_id automatically inherited from active span
3. **Simpler API**: No need to manually pass trace_id to every log call
4. **Tempo Integration**: Spans appear as hierarchical traces in Grafana Tempo
5. **Standards Compliance**: Follows OpenTelemetry best practices

**Span Behavior**:
- **Logs WITH active span**: Get trace_id + span_id → Sent to Tempo as traces
- **Logs WITHOUT active span**: Get fallback UUID trace_id (correlation only) → Only sent to Loki

**When to Use Spans**:
- ✅ HTTP/API requests, database queries, external service calls, batch operations
- ❌ Every log (creates overhead), simple calculations, validation functions

### 12. Developer Experience
- **Simple API**: 8 core functions cover all logging needs
- **Type Safety**: Language-specific type systems ensure correct usage
- **Peer Service Mapping**: Type-safe peer service ID mapping with INTERNAL auto-generation
- **Self-Documenting**: Function names and parameters are self-explanatory

### 13. Production-Ready Performance
- **Batch Processing**: OTLP exports use batch processors for efficiency
- **Async Logging**: Non-blocking logging operations
- **Minimal Overhead**: Target < 1ms per log call
- **Resource Limits**: File size limits (50MB main log, 10MB error log) with rotation

## Anti-Patterns to Avoid

### ❌ DON'T: Use module/class name for scope_name
**Bad**: `get_logger(__name__)` → "sovdev_logger.logger"
**Good**: `get_logger(service_name)` → "sovdev-test-app"
**Why**: Operators need to see service name, not internal module structure

### ❌ DON'T: Use language-specific exception types
**Bad**: Python "Exception", TypeScript "Error", Java "Throwable"
**Good**: Always use "Error" for `exceptionType` field
**Why**: Consistent alerting across languages requires consistent exception type names

### ❌ DON'T: Conditionally add responseJSON field
**Bad**: Only add responseJSON when response exists
**Good**: Always add responseJSON (value "null" when no response)
**Why**: Grafana queries break when field presence varies

### ❌ DON'T: Forget to flush on application exit
**Bad**: Exit without calling `sovdev_flush()`
**Good**: Always flush before exit (including error exits)
**Why**: OTLP batches final logs; without flushing they're lost

### ❌ DON'T: Log sensitive data directly
**Bad**: Log raw exceptions with credentials
**Good**: Automatic credential cleanup from stack traces
**Why**: Security and compliance requirements

### ❌ DON'T: Create multiple logger instances
**Bad**: New logger per module/class
**Good**: Single global logger instance
**Why**: OpenTelemetry SDK requires singleton pattern for proper instrumentation

## Success Criteria

A sovdev-logger implementation is correct when:
1. ✅ **JSON Output**: Identical structure to reference implementation (TypeScript)
2. ✅ **All Transports**: Console, file, error file, and OTLP all work simultaneously
3. ✅ **Field Parity**: All required fields present in all log types
4. ✅ **API Consistency**: All 8 API functions with identical signatures (adapted to language idioms)
5. ✅ **E2E Tests Pass**: Logs/metrics/traces reach backends with correct structure
6. ✅ **Security**: Credential removal and stack trace limiting work
7. ✅ **Performance**: Logging overhead < 1ms per call
8. ✅ **Graceful Degradation**: System continues working if OpenTelemetry export fails

## Specification Success Metrics

**Goal**: Specification is complete enough for LLM-assisted implementation without human clarification.

Target Metrics:
1. **Time to New Language Implementation**: < 4 hours from spec to passing tests
2. **Behavioral Consistency**: 100% field parity in Grafana across all languages
3. **Maintenance Velocity**: New features propagated to all languages in < 2 hours
4. **Documentation Quality**: LLM generates correct implementation without clarification questions

## Versioning Strategy

### Specification Versioning

The specification itself has a version number following semantic versioning:
- **Major version**: Breaking changes to API contract or field definitions (e.g., v1.0.0 → v2.0.0)
- **Minor version**: New fields, new functions, backward-compatible additions (e.g., v1.0.0 → v1.1.0)
- **Patch version**: Documentation updates, clarifications, examples (e.g., v1.0.0 → v1.0.1)

**Current Specification Version**: v1.0.0

### Implementation Compatibility

Each language implementation MUST declare which specification version it implements:
- Python: `__spec_version__ = "1.0.0"`
- TypeScript: `export const SPEC_VERSION = "1.0.0"`
- Go: `const SpecVersion = "1.0.0"`

### Backward Compatibility Requirements

**Patch version changes** (1.0.0 → 1.0.1):
- No changes to implementations required
- Documentation and examples only

**Minor version changes** (1.0.0 → 1.1.0):
- New fields are additive (old code continues working)
- New functions are optional (implementations can adopt incrementally)
- All existing tests must still pass

**Major version changes** (1.0.0 → 2.0.0):
- Breaking changes allowed
- Migration guide required
- All implementations must update simultaneously

### Version Declaration in Logs

The `scope_version` field in logs reflects the **library version** (hardcoded "1.0.0"), NOT the specification version. This field identifies which version of the library generated the log, which is useful for debugging library behavior.

## Key Design Decisions

### Decision: Use "Error" for All Exception Types

**Context:** Different languages use different exception type names:
- Python: "Exception"
- TypeScript: "Error"
- Java: "Exception" or "Throwable"
- Go: "error"

**Decision:** Standardize on "Error" for the `exceptionType` field across all languages.

**Rationale:**
1. **Consistent Alerting**: Operators need to create alert rules that work across languages. Using language-specific types (Python "Exception", TypeScript "Error") would require per-language alert configurations.
2. **Universal Understanding**: "Error" is universally understood across programming communities.
3. **Detail Preserved**: Language-specific exception details are still available in `exceptionStack` field for debugging.

**Alternatives Considered:**
- **Keep language-specific types**: Rejected because it makes cross-language alerting impossible.
- **Use "Exception" for all**: Rejected because JavaScript/TypeScript developers expect "Error".

**Impact:** All implementations must map their native exception types to the string "Error" before logging.

### Decision: Always Include responseJSON Field

**Context:** Should `responseJSON` field only be present when a response exists, or always present with value "null" when no response?

**Decision:** Always include `responseJSON` field (value "null" as string when no response exists).

**Rationale:**
1. **Grafana Query Consistency**: Grafana queries break when field presence varies. `{responseJSON!="null"}` works reliably; checking for field existence is harder.
2. **Audit Trail Completeness**: Loggeloven av 2025 compliance requires showing what data was processed. An explicit "null" indicates "no response" rather than "missing data".
3. **Type Safety**: Consistent field presence enables type-safe parsing in downstream systems.

**Alternatives Considered:**
- **Conditional field presence**: Rejected because it breaks Grafana queries.
- **Empty string instead of "null"**: Rejected because "null" is valid JSON and clearer semantically.

**Impact:** All implementations must serialize `null`/`None`/`nil` as the string "null" (not JSON null) when no response exists.

### Decision: Separate Main and Error Log Files

**Context:** Should errors be logged to the same file as other logs, or to a separate file?

**Decision:** Use separate error log file with different rotation limits.

**Rationale:**
1. **Quick Error Review**: Developers can quickly scan error-only file without filtering through INFO logs.
2. **Smaller Error Log**: Errors are less frequent, so smaller file size (10MB vs 50MB) is sufficient.
3. **Performance**: Error logs don't impact main log rotation as frequently.

**Configuration:**
- Main log: 50MB per file, 5 files (~250MB total)
- Error log: 10MB per file, 3 files (~30MB total)

**Impact:** All implementations must configure two file transports with different rotation settings.

---

**Document Status:** ✅ v1.0.0 COMPLETE
**Last Updated:** 2025-10-27
**Part of:** sovdev-logger specification v1.1.0
