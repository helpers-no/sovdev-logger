# Implementation Patterns for Sovdev Logger

## Overview

This document defines **required implementation patterns** that all sovdev-logger implementations MUST follow. These patterns ensure consistency across programming languages and guarantee that all implementations produce identical log output.

**📚 For language-specific OTEL SDK differences**, see [`llm-work-templates/research-otel-sdk-guide.md`](./llm-work-templates/research-otel-sdk-guide.md) - Read this **BEFORE implementing** to understand SDK quirks (HTTP headers, attribute naming, duration units, etc.)

---

## Code Style Convention

**All sovdev-logger implementations MUST use snake_case naming:**

### Naming Rules

1. **Variables**: `session_id`, `peer_service`, `function_name`, `input_json`
2. **Function parameters**: `function_name`, `input_json`, `response_json`, `exception_object`
3. **Class properties**: `service_name`, `service_version`, `system_ids_mapping`
4. **Method names**: `create_log_entry()`, `process_exception()`, `resolve_peer_service()`
5. **Interface/Type fields**: All fields use snake_case to match log output

### Rationale

- **Cross-language consistency**: Python, Go, Rust, PHP all use snake_case
- **Code-to-log alignment**: Variable names match log field names exactly
- **Copy-paste friendly**: No mental translation needed between code and logs
- **Future-proof**: Easy to add new languages without naming conflicts

### Examples

**TypeScript** (correct):
```typescript
function create_log_entry(
  function_name: string,
  input_json?: any,
  response_json?: any
): StructuredLogEntry {
  const event_id = uuidv4();
  const trace_id = get_trace_id();

  return {
    service_name: this.service_name,
    function_name,
    trace_id,
    event_id,
    input_json,
    response_json
  };
}
```

**Python** (correct):
```python
def create_log_entry(
    self,
    function_name: str,
    input_json: Optional[dict] = None,
    response_json: Optional[dict] = None
) -> dict:
    event_id = str(uuid.uuid4())
    trace_id = self.get_trace_id()

    return {
        "service_name": self.service_name,
        "function_name": function_name,
        "trace_id": trace_id,
        "event_id": event_id,
        "input_json": input_json,
        "response_json": response_json
    }
```

---

## Required Directory Structure

### Overview

**ALL language implementations MUST follow this exact directory structure** to work with cross-language validation tools in `specification/tools/`.

### Standard Structure

```
<language>/                  # Language directory (typescript, python, php, go, rust, etc.)
├── build-sovdevlogger.sh    # REQUIRED: Language-specific build script
├── <package>/               # Main package/library code
│   ├── (source files)       # Implementation files
│   └── ...
├── test/                    # Test directory (singular, not "tests")
│   └── e2e/                 # E2E tests
│       └── company-lookup/  # REQUIRED: Standard E2E test application
│           ├── .env                 # REQUIRED: Environment configuration
│           ├── company-lookup.<ext> # REQUIRED: Main test script (e.g., .ts, .py, .php, .go)
│           ├── package.*            # REQUIRED: Dependencies (package.json, requirements.txt, go.mod, etc.)
│           ├── run-test.sh          # REQUIRED: Execution script
│           └── logs/                # REQUIRED: Log output directory (created by test)
└── (other files)            # README, build config, etc.
```

### Critical Requirements

1. **Build script**: MUST include `build-sovdevlogger.sh` at language root
2. **Directory name**: MUST be `test/` (singular), NOT `tests/` (plural)
3. **E2E directory**: MUST be `test/e2e/`
4. **Standard test app**: MUST be `test/e2e/company-lookup/` directory
5. **Environment file**: MUST include `.env` with OTLP configuration
6. **Test script name**: MUST be `company-lookup.<ext>` matching the language
7. **Run script**: MUST include `run-test.sh` for validation tools
8. **Logs directory**: MUST include `logs/` subdirectory for output

### Why This Matters

The validation tools in `specification/tools/` expect this exact structure:

- `run-full-validation.sh` - Executes tests and validates output
- `validate-log-format.sh` - Validates JSON log format
- `query-loki.sh` - Queries logs from observability stack
- `run-full-validation.sh` - Runs complete validation suite

**If the directory structure doesn't match, validation tools will fail.**

### Purpose of company-lookup

The `company-lookup` application is a **standardized E2E test** that:

1. Tests the entire logging pipeline (console + file + OTLP)
2. Demonstrates all 8 API functions
3. Produces consistent output across all languages
4. Enables cross-language validation

Every language implementation should produce functionally identical logs when running `company-lookup`.

**For complete specification**, see:
- **Test program specification**: `specification/08-testprogram-company-lookup.md` - Complete documentation of the company-lookup E2E test including expected behavior, log output, cross-language requirements, and validation procedures

---

## Required File: .env

The `.env` file configures OTLP endpoints and environment variables for the test application. This file MUST be present in the `test/e2e/company-lookup/` directory.

**Reference Implementation**: `typescript/test/e2e/company-lookup/.env` (73 lines, fully documented)

**Critical Requirement**: Service name MUST follow pattern `sovdev-test-company-lookup-<language>` (e.g., `sovdev-test-company-lookup-python`)

---

## Required File: run-test.sh

### Purpose

The `run-test.sh` script is the **standardized execution wrapper** for the E2E test. All validation tools in `specification/tools/` execute this script, expecting consistent behavior across all languages.

### Required Behavior

The script MUST perform these steps in order:

1. **Clean old logs**: Remove `logs/*.log` files to ensure fresh test data
2. **Load environment**: Source `.env` file to set OTLP configuration
3. **Execute test**: Run the `company-lookup.<ext>` script with language-specific command
4. **Validate logs**: Call `validate-log-format.sh` on generated log files (unless `--skip-validation` flag set)
5. **Return exit code**: 0 for success, non-zero for failure

### Reference Implementation

**Reference Implementation**: `typescript/test/e2e/company-lookup/run-test.sh` (135 lines, fully documented)

---

## Required File: build-sovdevlogger.sh

### Purpose

The `build-sovdevlogger.sh` script is the **standardized build wrapper** for the library implementation. Each language provides its own build script that handles compilation, dependency management, and packaging in a consistent way.

### Location

MUST be placed at the root of the language directory: `<language>/build-sovdevlogger.sh`

### Required Behavior

1. **Default (no arguments)**: Build the library and install dependencies
2. **Optional arguments**: Language-specific build modes (clean, watch, test, etc.)
3. **Exit codes**: Return 0 for success, non-zero for failure
4. **Executable**: Script must be executable (`chmod +x build-sovdevlogger.sh`)

### Reference Implementations

Each script is self-documented with comments explaining its purpose and usage:

- **TypeScript**: `typescript/build-sovdevlogger.sh` - TypeScript compilation (tsc)
- **Python**: `python/build-sovdevlogger.sh` - Editable install and wheel building
- **Go**: `go/build-sovdevlogger.sh` - Dependency management and build verification

**Usage in development workflow**: See `specification/09-development-loop.md` for how these scripts integrate with the development loop.

---

## Logging Library Selection

### Overview

Choosing the right logging library for each language is critical for successful implementation. This section provides **recommended libraries** and **rationale** for each supported language.

### Selection Criteria

When choosing a logging library, prioritize libraries that:

1. **Support structured logging** - JSON output, field-based filtering
2. **Support multiple transports** - Console, file, custom transports
3. **Support log levels** - Trace, Debug, Info, Warn, Error, Fatal
4. **Support formatters** - Customize output format per transport
5. **Support extensions** - Custom transports for OTLP integration
6. **Are production-ready** - Widely adopted, actively maintained
7. **Have good documentation** - Clear examples, active community

### TypeScript/JavaScript

**Recommended Library**: [Winston](https://github.com/winstonjs/winston)

**Rationale**:
- ✅ **Mature and stable**: 20k+ GitHub stars, used by major companies
- ✅ **Multiple transports**: Console, File, HTTP, Stream, custom transports
- ✅ **Format flexibility**: JSON, pretty-print, custom formatters per transport
- ✅ **Log levels**: Supports custom levels (map to SOVDEV_LOGLEVELS)
- ✅ **TypeScript support**: Full type definitions included
- ✅ **Transport isolation**: Each transport can have its own format and level
- ✅ **Custom transport API**: Easy to create OTLP transport

**Key Features Used**:
```typescript
import winston from 'winston';
import TransportStream from 'winston-transport';

// Multiple transports with different formats
const logger = winston.createLogger({
  level: 'silly',  // Include all levels
  transports: [
    // Console: Human-readable with colors
    new winston.transports.Console({
      format: winston.format.combine(
        winston.format.colorize(),
        winston.format.printf(...)
      )
    }),
    // File: JSON format
    new winston.transports.File({
      filename: 'logs/dev.log',
      format: winston.format.json()
    }),
    // Custom OTLP transport
    new OpenTelemetryWinstonTransport({
      serviceName: 'my-service'
    })
  ]
});
```

**Alternatives**:
- **Pino**: Faster, but less flexible for multiple transport formats
- **Bunyan**: Good structured logging, but less active maintenance
- **Node.js console**: Too basic, no transport support

---

### Python

**Recommended Library**: [Python stdlib logging](https://docs.python.org/3/library/logging.html) with custom handlers

**Rationale**:
- ✅ **Built-in**: No external dependencies, always available
- ✅ **Flexible handlers**: Console, File, custom handlers for OTLP
- ✅ **Log levels**: Built-in levels (map to SOVDEV_LOGLEVELS)
- ✅ **Formatters**: Support for JSON and custom formatters
- ✅ **Production-proven**: Used by thousands of Python applications
- ✅ **Handler per output**: Each handler can have its own formatter

**Key Features Used**:
```python
import logging
import json
from logging.handlers import RotatingFileHandler

# Custom JSON formatter
class JsonFormatter(logging.Formatter):
    def format(self, record):
        log_entry = {
            "timestamp": record.created,
            "level": record.levelname.lower(),
            "service_name": record.service_name,
            # ... all sovdev fields
        }
        return json.dumps(log_entry)

# Configure logger with multiple handlers
logger = logging.getLogger('sovdev')
logger.setLevel(logging.DEBUG)

# Console handler: Human-readable
console_handler = logging.StreamHandler()
console_handler.setFormatter(
    logging.Formatter('%(asctime)s [%(levelname)s] %(message)s')
)
logger.addHandler(console_handler)

# File handler: JSON format
file_handler = RotatingFileHandler('logs/dev.log', maxBytes=50*1024*1024, backupCount=5)
file_handler.setFormatter(JsonFormatter())
logger.addHandler(file_handler)

# Custom OTLP handler
logger.addHandler(OtelLogHandler(service_name='my-service'))
```

**Alternatives**:
- **structlog**: Excellent structured logging, but adds dependency
- **loguru**: Modern API, but not stdlib (adds dependency)
- **python-json-logger**: Good for JSON, but stdlib logging is sufficient

**Why stdlib?**
- Reduces dependencies (critical for library packages)
- Every Python developer already knows it
- Full control over formatting and handlers
- Easy to extend with custom handlers

**Import pattern**:
```python
# In __init__.py - expose public API
from .logger import (
    sovdev_initialize,
    sovdev_log,
    sovdev_log_job_status,
    sovdev_log_job_progress,
    sovdev_flush,
    sovdev_generate_trace_id,
    create_peer_services
)
from .types import SOVDEV_LOGLEVELS

__all__ = [
    'sovdev_initialize',
    'sovdev_log',
    'sovdev_log_job_status',
    'sovdev_log_job_progress',
    'sovdev_flush',
    'sovdev_generate_trace_id',
    'create_peer_services',
    'SOVDEV_LOGLEVELS'
]
```

**Usage**:
```python
from sovdev_logger import sovdev_initialize, sovdev_log, SOVDEV_LOGLEVELS

sovdev_initialize('my-service', '1.0.0', {})
sovdev_log(SOVDEV_LOGLEVELS.INFO, 'test', 'Hello', 'internal')
```

---

### Go

**Recommended Library**: [slog (Go 1.21+)](https://pkg.go.dev/log/slog) or [zap](https://github.com/uber-go/zap)

**Rationale for slog** (Preferred for Go 1.21+):
- ✅ **Built-in**: Part of Go standard library (Go 1.21+)
- ✅ **Structured logging**: Key-value pairs, JSON output
- ✅ **Multiple handlers**: Console, File, custom handlers
- ✅ **Type-safe**: Strong typing for log attributes
- ✅ **Performance**: Optimized for high-throughput

**Key Features Used**:
```go
import (
    "log/slog"
    "os"
)

// Create logger with JSON handler
logger := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
    Level: slog.LevelDebug,
}))

// Log with structured fields
logger.Info("Company lookup",
    slog.String("service_name", "company-lookup"),
    slog.String("function_name", "lookupCompany"),
    slog.String("trace_id", traceID),
)
```

**Rationale for zap** (Alternative for Go < 1.21 or high performance needs):
- ✅ **High performance**: Zero-allocation logging
- ✅ **Structured logging**: Strongly-typed fields
- ✅ **Multiple outputs**: Console, File, custom
- ✅ **Production-proven**: Used by Uber and many others

**Key Features Used**:
```go
import "go.uber.org/zap"

logger, _ := zap.NewProduction()
defer logger.Sync()

logger.Info("Company lookup",
    zap.String("service_name", "company-lookup"),
    zap.String("function_name", "lookupCompany"),
    zap.String("trace_id", traceID),
)
```

**Alternatives**:
- **logrus**: Popular, but slower than slog/zap
- **zerolog**: Very fast, but less ergonomic API

---

### PHP

**Recommended Library**: [Monolog](https://github.com/Seldaek/monolog)

**Rationale**:
- ✅ **PSR-3 compliant**: Follows PHP-FIG logging standard
- ✅ **Multiple handlers**: Console, File, Stream, custom handlers
- ✅ **Formatters**: JSON, Line, custom formatters
- ✅ **Processors**: Add extra fields to log records
- ✅ **Production-proven**: Used by Symfony, Laravel, Drupal
- ✅ **Flexible architecture**: Easy to create custom handlers

**Key Features Used**:
```php
use Monolog\Logger;
use Monolog\Handler\StreamHandler;
use Monolog\Handler\RotatingFileHandler;
use Monolog\Formatter\JsonFormatter;

// Create logger with multiple handlers
$logger = new Logger('sovdev');

// Console handler: Human-readable
$consoleHandler = new StreamHandler('php://stdout', Logger::DEBUG);
$consoleHandler->setFormatter(new LineFormatter());
$logger->pushHandler($consoleHandler);

// File handler: JSON format
$fileHandler = new RotatingFileHandler('logs/dev.log', 5, Logger::DEBUG);
$fileHandler->setFormatter(new JsonFormatter());
$logger->pushHandler($fileHandler);

// Custom OTLP handler
$logger->pushHandler(new OtelLogHandler('my-service'));
```

**Alternatives**:
- **KLogger**: Simple, but lacks advanced features
- **PHP error_log**: Too basic, no structured logging

---

### C#

**Recommended Library**: [Serilog](https://serilog.net/)

**Rationale**:
- ✅ **Structured logging**: First-class support for structured data
- ✅ **Multiple sinks**: Console, File, Seq, custom sinks
- ✅ **Flexible formatting**: JSON, text, custom formatters per sink
- ✅ **Production-proven**: Used by Microsoft and .NET community
- ✅ **Easy enrichment**: Add properties to all log events
- ✅ **Async support**: Non-blocking logging

**Key Features Used**:
```csharp
using Serilog;
using Serilog.Formatting.Json;

// Create logger with multiple sinks
Log.Logger = new LoggerConfiguration()
    .MinimumLevel.Debug()
    // Console sink: Human-readable
    .WriteTo.Console(
        outputTemplate: "{Timestamp:yyyy-MM-dd HH:mm:ss} [{Level}] {Message}{NewLine}"
    )
    // File sink: JSON format
    .WriteTo.File(
        new JsonFormatter(),
        "logs/dev.log",
        rollingInterval: RollingInterval.Day
    )
    // Custom OTLP sink
    .WriteTo.OtelLog(serviceName: "my-service")
    .CreateLogger();

// Log with structured properties
Log.Information("Company lookup",
    "service_name", "company-lookup",
    "function_name", "LookupCompany",
    "trace_id", traceId
);
```

**Alternatives**:
- **NLog**: Good alternative, similar features
- **Microsoft.Extensions.Logging**: Built-in, but less flexible than Serilog

---

### Rust

**Recommended Library**: [tracing](https://github.com/tokio-rs/tracing)

**Rationale**:
- ✅ **Modern structured logging**: Built for async Rust
- ✅ **Spans and events**: Native OpenTelemetry-like concepts
- ✅ **Multiple subscribers**: Console, File, OTLP, custom
- ✅ **Compile-time performance**: Zero-cost abstractions
- ✅ **Production-proven**: Used by Tokio ecosystem

**Key Features Used**:
```rust
use tracing::{info, subscriber};
use tracing_subscriber::fmt;

// Set up subscriber with JSON format
subscriber::set_global_default(
    fmt()
        .json()
        .with_current_span(false)
        .finish()
).expect("setting default subscriber failed");

// Log with structured fields
info!(
    service_name = "company-lookup",
    function_name = "lookup_company",
    trace_id = %trace_id,
    "Company lookup"
);
```

**Alternatives**:
- **log + env_logger**: Simpler, but less structured
- **slog**: Good alternative, different API style

---

### Java

**Recommended Library**: [Logback](https://logback.qos.ch/) with [SLF4J](https://www.slf4j.org/)

**Rationale**:
- ✅ **SLF4J API**: Standard logging facade for Java
- ✅ **Flexible configuration**: XML-based appender config
- ✅ **Multiple appenders**: Console, File, Async, custom
- ✅ **Pattern layouts**: Flexible output formatting
- ✅ **Production-proven**: Successor to log4j, widely used
- ✅ **MDC support**: Thread-local context for structured fields

**Key Features Used**:
```java
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.slf4j.MDC;

Logger logger = LoggerFactory.getLogger(CompanyLookup.class);

// Add structured fields via MDC
MDC.put("service_name", "company-lookup");
MDC.put("function_name", "lookupCompany");
MDC.put("trace_id", traceId);

// Log message (fields from MDC will be included)
logger.info("Company lookup: {}", companyName);

// Clear MDC when done
MDC.clear();
```

**Configuration** (logback.xml):
```xml
<appender name="FILE" class="ch.qos.logback.core.FileAppender">
  <file>logs/dev.log</file>
  <encoder class="net.logstash.logback.encoder.LogstashEncoder">
    <!-- JSON output with MDC fields -->
  </encoder>
</appender>
```

**Alternatives**:
- **Log4j2**: Similar features, different API
- **JUL (java.util.logging)**: Built-in, but less flexible

---

### Summary Table

| Language | Recommended Library | Rationale | Built-in? |
|----------|---------------------|-----------|-----------|
| **TypeScript** | Winston | Multiple transports, custom format per transport, mature | No (npm) |
| **Python** | stdlib logging | No dependencies, flexible handlers, widely known | ✅ Yes |
| **Go** | slog (1.21+) or zap | Built-in structured logging, high performance | ✅ Yes (1.21+) |
| **PHP** | Monolog | PSR-3 standard, production-proven, flexible | No (Composer) |
| **C#** | Serilog | First-class structured logging, multiple sinks | No (NuGet) |
| **Rust** | tracing | Modern async support, OpenTelemetry-like concepts | No (Cargo) |
| **Java** | Logback + SLF4J | Standard Java logging, MDC support, widely used | No (Maven/Gradle) |

### Key Takeaway

**Choose libraries that support**:
1. Multiple output targets (console + file + custom)
2. Different formatters per output
3. Structured logging (key-value pairs)
4. Custom handlers/transports for OTLP integration

**Avoid libraries that**:
1. Only support single output format
2. Require same formatter for all outputs
3. Don't support custom transports/handlers
4. Are unmaintained or experimental

---

## Triple Output Architecture

### Overview

Sovdev-logger implements a **three-way output architecture** where logs are sent **simultaneously** to three destinations:

1. **Console** (stdout) - Human-readable output for local development
2. **File** (JSON Lines) - JSON log files for archival and debugging
3. **OTLP** (OpenTelemetry Protocol) - Structured telemetry for production monitoring

**IMPORTANT**: This is **NOT an either/or configuration**. All three outputs work simultaneously and independently.

### Purpose of Each Output

| Output | Purpose | Format | Use Case |
|--------|---------|--------|----------|
| **Console** | Developer experience during coding | Human-readable with colors | Local debugging, reading logs while coding |
| **File** | Historical archive and offline analysis | JSON Lines (one entry per line) | Post-mortem debugging, compliance, log analysis tools |
| **OTLP** | Production observability and monitoring | OpenTelemetry structured data | Grafana dashboards, alerting, distributed tracing |

### Why All Three?

- **Console**: Developers need readable logs while running code locally
- **File**: Required for compliance (Loggeloven av 2025), debugging production issues offline
- **OTLP**: Required for production monitoring, alerting, and distributed tracing in Grafana

### Configuration

Each output is independently enabled via environment variables:

```bash
# Console output
LOG_TO_CONSOLE=true              # Enable/disable console logging

# File output
LOG_TO_FILE=true                 # Enable/disable file logging
LOG_FILE_PATH=./logs/dev.log     # Main log file path
ERROR_LOG_PATH=./logs/error.log  # Error-only log file path

# OTLP output (always enabled by default)
OTEL_EXPORTER_OTLP_LOGS_ENDPOINT=http://localhost:4318/v1/logs
```

### Implementation Pattern

All three outputs are configured at initialization:

```typescript
// TypeScript example using Winston
const logger = winston.createLogger({
  transports: [
    // 1. Console transport (human-readable)
    new winston.transports.Console({
      format: winston.format.combine(
        winston.format.colorize(),
        winston.format.printf(info => `${info.timestamp} [${info.level}] ${info.message}`)
      )
    }),
    // 2. File transport (JSON)
    new winston.transports.File({
      filename: 'logs/dev.log',
      format: winston.format.json()
    }),
    // 3. OTLP transport (OpenTelemetry)
    new OpenTelemetryWinstonTransport({
      serviceName: 'my-service'
    })
  ]
});
```

### Graceful Degradation

If one output fails, the others continue working:

- **OTLP collector unreachable**: Console and File still work
- **Disk full**: Console and OTLP still work
- **Console closed**: File and OTLP still work

See `04-error-handling.md` for detailed graceful degradation patterns.

---

## OpenTelemetry Batch Processing

### Overview

**CRITICAL**: OpenTelemetry uses **batch processing by default** for efficiency. Logs, traces, and metrics are **accumulated in memory** and sent in **batches**, not immediately.

**Without `sovdev_flush()`** before application exit, the **last batch is lost** (never sent to OTLP collector).

### Default Batch Behavior

| Telemetry | Processor | Trigger | Default |
|-----------|-----------|---------|---------|
| **Logs** | BatchLogRecordProcessor | 512 records OR 5 seconds | [Docs](https://opentelemetry.io/docs/specs/otel/logs/sdk/#batching-processor) |
| **Traces** | BatchSpanProcessor | 512 spans OR 5 seconds | [Docs](https://opentelemetry.io/docs/specs/otel/trace/sdk/#batching-processor) |
| **Metrics** | PeriodicExportingMetricReader | 60 seconds (periodic) | [Docs](https://opentelemetry.io/docs/specs/otel/metrics/sdk/#periodic-exporting-metricreader) |

### Why Batching Matters

Short-lived applications (tests, CLI tools, jobs) often run **< 5 seconds**:

```
App runs 2 seconds → Creates 10 logs → Exits → ❌ 10 logs LOST (batch still in memory)
App runs 2 seconds → Creates 10 logs → sovdev_flush() → ✅ 10 logs SENT
```

### Implementation Requirements

All implementations MUST:

1. **Use batch processors** (not simple/synchronous processors)
2. **Implement `sovdev_flush()`** that:
   - Calls `forceFlush()` on all three providers (Logs, Traces, Metrics)
   - Blocks until export completes OR 30s timeout
3. **Document flush requirement** in examples

### Language-Specific Flush

| Language | Type | Returns |
|----------|------|---------|
| TypeScript | async | `Promise<void>` |
| Python | sync | `None` |
| Go | sync | `error` |
| Java | sync | `void` |
| C# | async | `Task` |
| Rust | sync | `Result<(), Error>` |
| PHP | sync | `void` |

### Configuration (Optional)

Tune batch behavior via environment variables:

```bash
OTEL_BLRP_MAX_EXPORT_BATCH_SIZE=512    # Logs: batch size
OTEL_BLRP_SCHEDULE_DELAY=5000          # Logs: export interval (ms)
OTEL_BSP_MAX_EXPORT_BATCH_SIZE=512     # Traces: batch size
OTEL_BSP_SCHEDULE_DELAY=5000           # Traces: export interval (ms)
OTEL_METRIC_EXPORT_INTERVAL=60000      # Metrics: export interval (ms)
```

See [OpenTelemetry Environment Variables](https://opentelemetry.io/docs/specs/otel/configuration/sdk-environment-variables/)

### Key Takeaway

**If logs don't appear in Loki/Grafana**: Check if `sovdev_flush()` is called before application exit.

**See Also**:
- **API Contract**: `01-api-contract.md` → Function 5: sovdev_flush
- **Error Handling**: `04-error-handling.md` → Error Handling in sovdev_flush()
- **Further Reading**: [OpenTelemetry Specification](https://opentelemetry.io/docs/specs/otel/)

---

## Field Naming Convention

### Standard Fields

All log outputs (console, file, OTLP) MUST use snake_case field naming:

- `service_name` - Service identifier
- `service_version` - Service version
- `session_id` - Session grouping ID (UUID for entire execution)
- `peer_service` - Target system identifier
- `function_name` - Function/method name
- `log_type` - Log classification (transaction, session, error, etc.)
- `trace_id` - Transaction correlation ID (UUID)
- `event_id` - Unique log entry ID (UUID)
- `input_json` - Input parameters (JSON serialized)
- `response_json` - Output data (JSON serialized)
- `exception_type` - Exception type (always "Error")
- `exception_message` - Exception message
- `exception_stack` - Exception stack trace (max 350 chars)

### Consistency Across Outputs

The same field names MUST be used in:
1. **Code variables** - `const trace_id = uuidv4()`
2. **Console logs** - `Trace ID: ${trace_id}`
3. **File logs** - `{"trace_id": "..."}`
4. **OTLP export** - `{"trace_id": "..."}`
5. **Backend storage** - Loki stores as `trace_id`

**No transformations** are applied - field names remain unchanged throughout the entire logging pipeline.

---

## Session ID Generation

### Purpose

The `session_id` field groups all logs, metrics, and traces from a single execution/run of the application. This enables correlation of all telemetry data from one session.

### Generation Rules

1. **Generate once** at initialization (in `sovdev_initialize()`)
2. **Use UUID v4** format (lowercase, e.g., `"18df09dd-c321-43d8-aa24-19dd7c149a56"`)
3. **Store in instance** for reuse across all log calls
4. **Include in all logs** - Every log entry MUST have the same `session_id`

### Example Implementation

**TypeScript**:
```typescript
class SovdevLogger {
  private session_id: string;

  constructor(service_name: string, service_version: string) {
    this.session_id = uuidv4(); // Generate once at initialization
  }

  log(function_name: string, message: string, ...args: any[]) {
    // Include session_id in every log
    const log_entry = {
      session_id: this.session_id,  // Same for all logs in this execution
      function_name,
      message,
      // ...
    };
  }
}
```

**Python**:
```python
class SovdevLogger:
    def __init__(self, service_name: str, service_version: str):
        self.session_id = str(uuid.uuid4())  # Generate once at initialization

    def log(self, function_name: str, message: str, **kwargs):
        # Include session_id in every log
        log_entry = {
            "session_id": self.session_id,  # Same for all logs in this execution
            "function_name": function_name,
            "message": message,
            # ...
        }
```

### Verification

Query all logs from a session in Grafana/Loki:
```logql
{service_name="sovdev-test-app"} | json | session_id="18df09dd-c321-43d8-aa24-19dd7c149a56"
```

---

## Trace ID Correlation

### Purpose

The `trace_id` field correlates related operations within a business transaction. Multiple log entries can share the same `trace_id` to track a transaction across services and operations.

### Generation Rules

1. **Generate per transaction** - Create new `trace_id` for each business transaction
2. **Use UUID v4** format (lowercase)
3. **Reuse across operations** - Pass the same `trace_id` to all related log calls
4. **Auto-generate if missing** - If `trace_id` not provided, generate new UUID

### Example Implementation

**Single Transaction with Multiple Operations**:
```typescript
// Generate trace_id for the entire transaction
const trace_id = sovdev_generate_trace_id();

// Log start of transaction
sovdev_log(
  SOVDEV_LOGLEVELS.INFO,
  'startTransaction',
  'Starting order processing',
  PEER_SERVICES.INTERNAL,
  { order_id: 'ORD-123' },
  null,
  null,
  trace_id  // Same trace_id
);

// Log external API call
sovdev_log(
  SOVDEV_LOGLEVELS.INFO,
  'callPaymentAPI',
  'Processing payment',
  PEER_SERVICES.PAYMENT_GATEWAY,
  { amount: 99.99 },
  { status: 'approved' },
  null,
  trace_id  // Same trace_id
);

// Log completion
sovdev_log(
  SOVDEV_LOGLEVELS.INFO,
  'completeTransaction',
  'Order processing completed',
  PEER_SERVICES.INTERNAL,
  { order_id: 'ORD-123' },
  { status: 'success' },
  null,
  trace_id  // Same trace_id
);
```

### Verification

Query all logs from a transaction in Grafana/Loki:
```logql
{service_name="sovdev-test-app"} | json | trace_id="<uuid>"
```

---

## Peer Service Identification

### Purpose

The `peer_service` field identifies the target system/service being called or interacted with. This enables tracking which external systems are involved in operations.

### Best Practices

1. **Use createPeerServices()** helper to define peer services
2. **Use INTERNAL** for internal operations (auto-generated)
3. **Use system IDs** for external services (e.g., `SYS1234567`)
4. **Type-safe constants** - Define all peer services upfront

### Example Implementation

```typescript
// Define peer services at application startup
const PEER_SERVICES = createPeerServices({
  BRREG: 'SYS1234567',      // External: Norwegian company registry
  ALTINN: 'SYS7654321',     // External: Government portal
  PAYMENT_GATEWAY: 'SYS9999999'  // External: Payment provider
});

// Initialize logger
sovdev_initialize(
  'company-lookup-service',
  '2.1.0',
  PEER_SERVICES.mappings
);

// Use type-safe constants in logging
sovdev_log(
  SOVDEV_LOGLEVELS.INFO,
  'lookupCompany',
  'Looking up company',
  PEER_SERVICES.BRREG,  // Type-safe, validated peer service
  { org_number: '123456789' },
  { name: 'Acme Corp' }
);

sovdev_log(
  SOVDEV_LOGLEVELS.INFO,
  'processInternally',
  'Processing data',
  PEER_SERVICES.INTERNAL,  // Internal operation
  { data: 'value' },
  { result: 'success' }
);
```

### Resolution Mechanism

The `create_peer_services()` function generates two outputs:

1. **Constants object** - Type-safe constants for each peer service (BRREG, ALTINN, etc.)
2. **Mappings object** - Map of constant names to system IDs for validation

**How it works**:
```typescript
// Input: Mapping of names to system IDs
const input = {
  BRREG: 'SYS1234567',
  ALTINN: 'SYS7654321'
};

// Output: Constants object + mappings
const PEER_SERVICES = {
  INTERNAL: 'internal',           // Auto-generated constant
  BRREG: 'SYS1234567',            // Passed through as constant
  ALTINN: 'SYS7654321',           // Passed through as constant
  mappings: {                     // Validation map
    'internal': 'internal',
    'SYS1234567': 'SYS1234567',
    'SYS7654321': 'SYS7654321'
  }
};
```

**Validation**: When logging, the library checks if the `peer_service` value exists in `mappings`. Invalid values log a warning and use "unknown" as fallback.

---

## JSON Serialization

### Purpose

The `input_json` and `response_json` fields store request/response data as JSON strings for analysis and debugging.

### Serialization Rules

1. **Always serialize to string** - Convert objects to JSON strings
2. **Always include response_json** - Even if `null`, field must be present with value `"null"` (string)
3. **Compact format** - No pretty-printing, single-line JSON
4. **Handle circular references** - Detect and break circular object references
5. **Handle errors gracefully** - If serialization fails, use `"[Serialization Error]"`

### Example Implementation

**TypeScript**:
```typescript
function serialize_json(obj: any): string {
  if (obj === null || obj === undefined) {
    return "null";  // String "null", not JSON null
  }

  try {
    return JSON.stringify(obj);  // Compact serialization
  } catch (error) {
    return "[Serialization Error]";  // Graceful fallback
  }
}

// Usage
const input_json = serialize_json({ org_number: '123456789' });
const response_json = serialize_json(null);  // Returns "null" (string)

const log_entry = {
  input_json: input_json,      // Always string
  response_json: response_json  // Always present, even if "null"
};
```

**Python**:
```python
def serialize_json(obj: Any) -> str:
    if obj is None:
        return "null"  # String "null", not JSON null

    try:
        return json.dumps(obj, ensure_ascii=False)  # Compact serialization
    except Exception:
        return "[Serialization Error]"  # Graceful fallback

# Usage
input_json = serialize_json({"org_number": "123456789"})
response_json = serialize_json(None)  # Returns "null" (string)

log_entry = {
    "input_json": input_json,      # Always string
    "response_json": response_json  # Always present, even if "null"
}
```

---

## Exception Processing

### Purpose

Standardize exception handling to ensure consistent error logging with security and size constraints.

### Processing Rules

1. **Standardize type** - Always use `"Error"` (not language-specific like `"Exception"`, `"TypeError"`)
2. **Remove credentials** - Strip auth headers, passwords, API keys from stack traces
3. **Limit stack size** - Truncate stack traces to 350 characters maximum
4. **Extract details** - Separate type, message, and stack into individual fields

### Example Implementation

**TypeScript**:
```typescript
function process_exception(error: Error): ExceptionDetails {
  return {
    exception_type: "Error",  // Always "Error"
    exception_message: error.message,
    exception_stack: clean_stack_trace(error.stack || "")
  };
}

function clean_stack_trace(stack: string): string {
  // Remove credentials
  let cleaned = stack
    .replace(/Authorization[:\s]+[^\s,}]+/gi, 'Authorization: [REDACTED]')
    .replace(/password[:\s=]+[^\s,}]+/gi, 'password=[REDACTED]')
    .replace(/api[-_]?key[:\s=]+[^\s,}]+/gi, 'api_key=[REDACTED]')
    .replace(/Bearer\s+[A-Za-z0-9\-._~+/]+=*/gi, 'Bearer [REDACTED]');

  // Limit to 350 characters
  return cleaned.substring(0, 350);
}
```

---

## Output Format Consistency

### Purpose

Ensure all outputs use identical field names for consistency and ease of querying.

### Format Examples

**Console Output** (human-readable):
```
2025-10-08 12:34:56 [INFO] company-lookup-service
  Function: lookupCompany
  Message: Looking up company 123456789
  Trace ID: 50ba0e1d-c46d-4dee-98d3-a0d3913f74ee
  Session ID: 18df09dd-c321-43d8-aa24-19dd7c149a56
```

**File Output** (JSON, one per line):
```json
{"timestamp":"2025-10-08T12:34:56.123456+00:00","level":"info","service_name":"company-lookup-service","service_version":"1.0.0","session_id":"18df09dd-c321-43d8-aa24-19dd7c149a56","peer_service":"SYS1234567","function_name":"lookupCompany","log_type":"transaction","message":"Looking up company 123456789","trace_id":"50ba0e1d-c46d-4dee-98d3-a0d3913f74ee","event_id":"cf115688-513e-48fe-8049-538a515f608d","input_json":"{\"org_number\":\"123456789\"}","response_json":"{\"name\":\"Acme Corp\"}"}
```

**OTLP Output** (sent to collector):
```json
{
  "scope_name": "company-lookup-service",
  "scope_version": "1.0.0",
  "observed_timestamp": "1759823543622190848",
  "severity_number": 9,
  "severity_text": "INFO",
  "service_name": "company-lookup-service",
  "service_version": "1.0.0",
  "session_id": "18df09dd-c321-43d8-aa24-19dd7c149a56",
  "peer_service": "SYS1234567",
  "function_name": "lookupCompany",
  "log_type": "transaction",
  "trace_id": "50ba0e1d-c46d-4dee-98d3-a0d3913f74ee",
  "event_id": "cf115688-513e-48fe-8049-538a515f608d",
  "input_json": "{\"org_number\":\"123456789\"}",
  "response_json": "{\"name\":\"Acme Corp\"}",
  "telemetry_sdk_language": "typescript",
  "telemetry_sdk_version": "1.37.0"
}
```

### Key Requirements

1. **Identical field names** - Same names in all outputs
2. **Snake_case everywhere** - No dots, no camelCase
3. **No transformations** - OTLP collector passes through unchanged
4. **All fields present** - Even optional fields like `response_json` must be present with value `"null"`

---

## Best Practices

### FUNCTIONNAME Constant

Define function name as a constant at the top of each function to avoid typos:

```typescript
async function lookupCompany(org_number: string): Promise<Company> {
  const FUNCTIONNAME = 'lookupCompany';  // Define once

  sovdev_log(
    SOVDEV_LOGLEVELS.INFO,
    FUNCTIONNAME,  // Reuse constant
    'Starting company lookup',
    PEER_SERVICES.BRREG,
    { org_number },
    null
  );

  try {
    const company = await fetchCompany(org_number);

    sovdev_log(
      SOVDEV_LOGLEVELS.INFO,
      FUNCTIONNAME,  // Same constant
      'Company lookup successful',
      PEER_SERVICES.BRREG,
      { org_number },
      company
    );

    return company;
  } catch (error) {
    sovdev_log(
      SOVDEV_LOGLEVELS.ERROR,
      FUNCTIONNAME,  // Same constant
      'Company lookup failed',
      PEER_SERVICES.BRREG,
      { org_number },
      null,
      error as Error
    );
    throw error;
  }
}
```

### Variable Reuse

Reuse input/response variables in logging to avoid duplication:

```typescript
async function processOrder(order_data: OrderData): Promise<OrderResult> {
  const FUNCTIONNAME = 'processOrder';
  const input_data = { order_id: order_data.id, amount: order_data.amount };

  sovdev_log(
    SOVDEV_LOGLEVELS.INFO,
    FUNCTIONNAME,
    'Processing order',
    PEER_SERVICES.INTERNAL,
    input_data,  // Reuse variable
    null
  );

  const result = await executeOrder(order_data);

  sovdev_log(
    SOVDEV_LOGLEVELS.INFO,
    FUNCTIONNAME,
    'Order processed',
    PEER_SERVICES.INTERNAL,
    input_data,  // Reuse same variable
    result       // Response variable
  );

  return result;
}
```

---

**Document Status:** ✅ v1.0.0 COMPLETE
**Last Updated:** 2025-10-27
**Part of:** sovdev-logger specification v1.1.0
