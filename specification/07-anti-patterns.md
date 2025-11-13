# Anti-Patterns

## Purpose

This document lists common mistakes and anti-patterns discovered during sovdev-logger development. Following these guidelines ensures consistent behavior across all language implementations.

---

## ❌ DON'T: Use Module Name for scope_name

### Problem

Using the internal module name (like `__name__` in Python or `module.exports` path) instead of the service name results in confusing log entries that expose internal implementation details.

### Python Bad Example

```python
# ❌ WRONG - Uses module path
logger = _logs.get_logger(__name__, "1.0.0")
# __name__ = "sovdev_logger.logger"
```

### Python Correct Example

```python
# ✅ CORRECT - Uses service name from initialization
logger = _logs.get_logger(service_name, "1.0.0")
# service_name = "sovdev-test-company-lookup-python"
```

### Why This Matters

**Operator Impact:** Operators monitoring Grafana dashboards need to see the actual service name (e.g., "payment-service", "user-api") to identify which system is having issues. Seeing "sovdev_logger.logger" or "src.utils.logging" provides no actionable information.

**Service Identification:** The `scope_name` field is used for filtering, alerting, and correlation. Using module names breaks these capabilities.

---

## ❌ DON'T: Use Language-Specific Exception Type Names

### Problem

Different languages use different exception type names (Python: "Exception", TypeScript: "Error", Java: "Exception", Go: "error"). This inconsistency breaks cross-language alerting and makes Grafana dashboards language-dependent.

### Python Bad Example

```python
# ❌ WRONG - Uses Python's native type name
except Exception as e:
    exception_type = type(e).__name__  # Returns "HTTPError", "ValueError", etc.
```

### Python Correct Example

```python
# ✅ CORRECT - Standardizes to "Error"
except Exception as e:
    exception_type = "Error"  # Always "Error" regardless of Python type
```

### Why This Matters

**Consistent Alerting:** Alert rules in Grafana check for `exceptionType = "Error"`. Using "HTTPError", "ValueError", "Exception" would require per-language alert configurations.

**Cross-Language Analysis:** Operators comparing error rates between Python and TypeScript services need identical field values. The actual exception details are preserved in `exceptionMessage` and `exceptionStack`.

---

## ❌ DON'T: Use Nested Objects in Log Entries

### Problem

All log entry fields MUST be at the root level with no nesting. OpenTelemetry OTLP protocol requires flat structure for proper ingestion into Loki, Prometheus, and Tempo. Nested objects cause validation errors and prevent fields from being queryable.

### Python Bad Example

```python
# ❌ WRONG - Nested exception object
log_entry['exception'] = {
    'type': 'Error',
    'message': 'HTTP 404: Not found',
    'stacktrace': 'Traceback (most recent call last)...'
}

# ❌ WRONG - Nested custom fields
log_entry['http'] = {
    'status_code': 404,
    'method': 'GET',
    'url': '/api/company'
}
```

### Python Correct Example

```python
# ✅ CORRECT - Flat structure with prefixed field names
log_entry['exception_type'] = 'Error'
log_entry['exception_message'] = 'HTTP 404: Not found'
log_entry['exception_stacktrace'] = 'Traceback (most recent call last)...'

# ✅ CORRECT - Flat structure for custom fields
log_entry['http_status_code'] = 404
log_entry['http_method'] = 'GET'
log_entry['http_url'] = '/api/company'
```

### TypeScript Bad Example

```typescript
// ❌ WRONG - Nested objects
const logEntry = {
  timestamp: new Date().toISOString(),
  level: 'ERROR',
  message: 'Request failed',
  exception: {  // Nested - will cause validation error
    type: 'Error',
    message: 'Connection timeout',
    stack: 'Error: Connection timeout\n  at fetch...'
  },
  request: {  // Nested - fields not queryable
    method: 'POST',
    url: '/api/submit',
    headers: { 'Content-Type': 'application/json' }
  }
};
```

### TypeScript Correct Example

```typescript
// ✅ CORRECT - All fields at root level
const logEntry = {
  timestamp: new Date().toISOString(),
  level: 'ERROR',
  message: 'Request failed',
  exceptionType: 'Error',  // Flat structure
  exceptionMessage: 'Connection timeout',
  exceptionStack: 'Error: Connection timeout\n  at fetch...',
  requestMethod: 'POST',  // Flat structure with prefixes
  requestUrl: '/api/submit',
  requestContentType: 'application/json'
};
```

### Validation Error Example

When using nested objects, JSON schema validation will fail:

```
❌ Additional properties are not allowed ('exception' was unexpected)
❌ Additional properties are not allowed ('request' was unexpected)
```

Even if validation passes locally, OTLP backends will reject nested structures.

### Why This Matters

**OTLP Protocol Requirement**: OpenTelemetry OTLP format requires flat structure. Nested objects are not supported and will be rejected by Loki, Prometheus, and Tempo.

**Field Queryability**: Grafana and Loki query languages expect flat fields:
```logql
# ✅ Works with flat structure:
{service_name="payment-api"} | json | exception_type = "Error"

# ❌ Fails with nested structure:
{service_name="payment-api"} | json | exception.type = "Error"
```

**Consistency Across Outputs**: All three output destinations (console, file, OTLP) must have identical field structure. Nested objects break this consistency.

**This Applies to ALL Fields**: The flat structure requirement is not specific to exceptions. ALL custom fields, metadata, and structured data must follow this pattern:
- ✅ `http_status_code`, `http_method`, `http_url`
- ✅ `db_query_time`, `db_connection_pool`
- ✅ `cache_hit`, `cache_ttl`
- ❌ Never `http: { status_code, method, url }`
- ❌ Never `database: { query_time, pool }`
- ❌ Never `cache: { hit, ttl }`

---

## ❌ DON'T: Include Credentials in Stack Traces

### Problem

Stack traces often capture function arguments and HTTP headers, which may contain passwords, API keys, or authorization tokens. Sending these to OTLP exposes secrets in logs.

### Bad Example

```
Error: Login failed
  at authenticate(user="admin", password="secret123", apiKey="sk_live_abc123xyz")
  at handleRequest(headers={Authorization: "Bearer eyJhbGc..."})
```

### Correct Example

```
Error: Login failed
  at authenticate(user="admin", password=[REDACTED], apiKey=[REDACTED])
  at handleRequest(headers={Authorization: [REDACTED]})
```

### Implementation Requirements

All implementations MUST apply credential removal regex patterns **before** truncating stack traces to 350 characters. See `04-error-handling.md` for complete regex patterns.

**Required Patterns to Remove:**
- `Authorization` headers (case-insensitive)
- `Bearer` tokens
- API keys (patterns: `api_key`, `apiKey`, `x-api-key`)
- Passwords (patterns: `password`, `pwd`, `pass`)
- JWT tokens (base64 patterns)
- Session IDs (`sessionid`, `JSESSIONID`, `PHPSESSID`)
- Cookie values

---

## ❌ DON'T: Truncate Stack Traces Before Credential Removal

### Problem

If you truncate the stack trace first, you might keep the credential portion and remove the safe portion.

### Bad Example

```python
# ❌ WRONG - Truncates first, credentials might remain
stack = str(error)[:350]
stack = remove_credentials(stack)
```

### Correct Example

```python
# ✅ CORRECT - Removes credentials first, then truncates
stack = str(error)
stack = remove_credentials(stack)
stack = stack[:350] + ('... (truncated)' if len(stack) > 350 else '')
```

---

## ❌ DON'T: Generate New traceId for Related Logs

### Problem

Each call to `sovdev_log()` for the same logical operation (request/response/error) should use the SAME `traceId`. Generating a new one breaks correlation.

### Bad Example

```typescript
// ❌ WRONG - Generates new traceId for each log
sovdev_log(INFO, 'lookupCompany', 'Starting lookup', PEER_SERVICES.BRREG,
  input, null, null, sovdev_generate_trace_id());  // New ID

const response = await fetchData();

sovdev_log(INFO, 'lookupCompany', 'Lookup complete', PEER_SERVICES.BRREG,
  input, response, null, sovdev_generate_trace_id());  // Different ID - breaks correlation!
```

### Correct Example

```typescript
// ✅ CORRECT - Same traceId for all logs in transaction
const txnTraceId = sovdev_generate_trace_id();  // Generate ONCE

sovdev_log(INFO, 'lookupCompany', 'Starting lookup', PEER_SERVICES.BRREG,
  input, null, null, txnTraceId);  // Same ID

const response = await fetchData();

sovdev_log(INFO, 'lookupCompany', 'Lookup complete', PEER_SERVICES.BRREG,
  input, response, null, txnTraceId);  // Same ID - enables correlation
```

### Why This Matters

**Trace Correlation:** The entire point of `traceId` is to link request → response → error logs for a single transaction. Using different IDs makes this impossible.

**Grafana Queries:** Operators filter by `traceId` to see all logs for a specific request. Using different IDs prevents this analysis.

---

## ❌ DON'T: Forget to Call sovdev_flush() Before Exit

### Problem

OpenTelemetry batches logs for performance. The final batch is only sent when explicitly flushed. Without flushing, the last logs (often including job completion status or final errors) are lost.

### Bad Example

```typescript
// ❌ WRONG - Exits without flushing
async function main() {
  sovdev_log(INFO, 'main', 'Job started', PEER_SERVICES.INTERNAL);
  await processData();
  sovdev_log(INFO, 'main', 'Job complete', PEER_SERVICES.INTERNAL);
  // No flush - "Job complete" log likely lost!
}

main();
```

### Correct Example

```typescript
// ✅ CORRECT - Always flush before exit
async function main() {
  sovdev_log(INFO, 'main', 'Job started', PEER_SERVICES.INTERNAL);
  await processData();
  sovdev_log(INFO, 'main', 'Job complete', PEER_SERVICES.INTERNAL);

  await sovdev_flush();  // Ensures all logs are sent
}

main().catch(async (error) => {
  console.error('Fatal error:', error);
  await sovdev_flush();  // CRITICAL: Flush even on error!
  process.exit(1);
});
```

### Signal Handler Example

```typescript
// ✅ CORRECT - Flush on SIGINT/SIGTERM
process.on('SIGINT', async () => {
  sovdev_log(INFO, 'shutdown', 'Received SIGINT, shutting down gracefully',
    PEER_SERVICES.INTERNAL);
  await sovdev_flush();
  process.exit(0);
});

process.on('SIGTERM', async () => {
  sovdev_log(INFO, 'shutdown', 'Received SIGTERM, shutting down gracefully',
    PEER_SERVICES.INTERNAL);
  await sovdev_flush();
  process.exit(0);
});
```

---

## ❌ DON'T: Mix Different sessionId Values in Same Execution

### Problem

The `sessionId` (generated at `sovdev_initialize()`) should remain constant for the entire application lifecycle. Generating new session IDs breaks session correlation.

### Bad Example

```python
# ❌ WRONG - Generates new session ID per function call
def lookup_company(org_number):
    session_id = str(uuid.uuid4())  # New session per call - breaks correlation
    sovdev_log(INFO, 'lookupCompany', f'Lookup {org_number}', ...)
```

### Correct Example

```python
# ✅ CORRECT - Session ID generated ONCE at initialization
# In sovdev_initialize():
_session_id = str(uuid.uuid4())  # Generated once at startup

def lookup_company(org_number):
    # Uses global _session_id set at initialization
    sovdev_log(INFO, 'lookupCompany', f'Lookup {org_number}', ...)
```

### Why This Matters

**Session Correlation:** All logs from a single application execution should share the same `sessionId`. This enables:
- Tracking a batch job from start to finish
- Correlating multiple API calls made during one execution
- Debugging by filtering all logs from a specific run

---

## ❌ DON'T: Define Input/Response Objects Inline

### Problem

Using inline object literals in `sovdev_log()` calls reduces code maintainability and prevents reuse. Changes require updating multiple log statements.

### Bad Example

```typescript
// ❌ WRONG - Inline object definition
sovdev_log(INFO, 'lookupCompany', 'Starting lookup', PEER_SERVICES.BRREG,
  { organisasjonsnummer: orgNumber },  // Inline input
  null, null, traceId);

const response = await fetchData();

sovdev_log(INFO, 'lookupCompany', 'Lookup complete', PEER_SERVICES.BRREG,
  { organisasjonsnummer: orgNumber },  // Duplicated inline - hard to maintain
  { navn: response.navn }, null, traceId);
```

### Correct Example

```typescript
// ✅ CORRECT - Define variables once, reuse
const FUNCTIONNAME = 'lookupCompany';
const input = { organisasjonsnummer: orgNumber };

sovdev_log(INFO, FUNCTIONNAME, 'Starting lookup', PEER_SERVICES.BRREG,
  input,  // Reuse input variable
  null, null, traceId);

const companyData = await fetchData();
const response = {
  navn: companyData.navn,
  organisasjonsform: companyData.organisasjonsform?.beskrivelse
};

sovdev_log(INFO, FUNCTIONNAME, 'Lookup complete', PEER_SERVICES.BRREG,
  input,  // Reuse same input
  response,  // Use response variable
  null, traceId);
```

### Why This Matters

**Maintainability:** If the input structure changes (e.g., add `companyType` field), you only update one place.

**Consistency:** Using the SAME `input` object for request/response/error logs guarantees identical values in all logs.

**Type Safety:** Variables can be type-checked; inline objects are harder to validate.

---

## ❌ DON'T: Hardcode Function Names in Log Calls

### Problem

Using string literals for function names makes refactoring difficult and prone to typos.

### Bad Example

```typescript
// ❌ WRONG - Hardcoded string
function lookupCompany(orgNumber: string) {
  sovdev_log(INFO, 'lookupCompany', 'Starting lookup', ...);

  try {
    // ... code ...
    sovdev_log(INFO, 'lookupCompany', 'Success', ...);
  } catch (error) {
    sovdev_log(ERROR, 'lookupCompnay', 'Failed', ...);  // TYPO! Hard to spot
  }
}
```

### Correct Example

```typescript
// ✅ CORRECT - Define constant once
function lookupCompany(orgNumber: string) {
  const FUNCTIONNAME = 'lookupCompany';

  sovdev_log(INFO, FUNCTIONNAME, 'Starting lookup', ...);

  try {
    // ... code ...
    sovdev_log(INFO, FUNCTIONNAME, 'Success', ...);
  } catch (error) {
    sovdev_log(ERROR, FUNCTIONNAME, 'Failed', ...);  // No typo possible
  }
}
```

### Why This Matters

**Refactoring Safety:** If you rename the function, you only update one place.

**Typo Prevention:** Constant reuse eliminates spelling mistakes.

**Consistency:** All logs from the function use identical function names, enabling reliable filtering.

---

## ❌ DON'T: Skip File Rotation Configuration

### Problem

Without file rotation, log files grow unbounded and fill disk space, causing production outages.

### Bad Example

```python
# ❌ WRONG - No rotation, unlimited file growth
file_handler = logging.FileHandler(log_path)
logger.addHandler(file_handler)
```

### Correct Example

```python
# ✅ CORRECT - Rotation with max size and file count
from logging.handlers import RotatingFileHandler

file_handler = RotatingFileHandler(
    log_path,
    maxBytes=50 * 1024 * 1024,  # 50 MB per file
    backupCount=5,  # Keep 5 rotated files (250 MB total)
)
logger.addHandler(file_handler)
```

### Implementation Requirements

All implementations MUST configure rotation to prevent disk exhaustion:

| Log Type | Max Size | Max Files | Total Disk Usage |
|----------|----------|-----------|------------------|
| Main log | 50 MB | 5 files | ~250 MB max |
| Error log | 10 MB | 3 files | ~30 MB max |
| **Total** | - | - | **~280 MB max** |

See `05-environment-configuration.md` for language-specific examples.

---

---

## ❌ DON'T: Implement Custom File Writing and Rotation

### Problem

Implementing file writing and rotation from scratch introduces bugs and maintenance burden. Mature logging libraries already solve these problems.

### Bad Example

```typescript
// ❌ WRONG - Custom file writing
import fs from 'fs';

function sovdev_log(level, functionName, message, ...) {
  const logEntry = JSON.stringify({ timestamp: new Date(), level, ... });

  // Manual file writing
  fs.appendFileSync('dev.log', logEntry + '\n');

  // Manual rotation
  const stats = fs.statSync('dev.log');
  if (stats.size > 50 * 1024 * 1024) {
    fs.renameSync('dev.log', 'dev.log.1');
    if (fs.existsSync('dev.log.1')) {
      fs.renameSync('dev.log.1', 'dev.log.2');
    }
    // ... manual rotation logic
  }
}
```

### Correct Example

```typescript
// ✅ CORRECT - Use Winston for file handling
import winston from 'winston';

const logger = winston.createLogger({
  transports: [
    new winston.transports.File({
      filename: 'dev.log',
      maxsize: 50 * 1024 * 1024,  // Winston handles rotation
      maxFiles: 5,
      tailable: true
    })
  ]
});

function sovdev_log(level, functionName, message, ...) {
  const logEntry = { timestamp: new Date(), level, functionName, message, ... };

  // Winston handles file writing, buffering, rotation
  logger.log(level, logEntry);

  // Our focus: OpenTelemetry integration
  otlpLogger.emit(logEntry);
}
```

### Why This Matters

**Problems with Custom Implementation:**
- **File locking**: Windows requires careful file handle management
- **Race conditions**: Multiple threads writing simultaneously
- **Buffer management**: Poor performance without proper buffering
- **Rotation atomicity**: Rotation while writing causes data loss
- **Missing features**: Compression, async I/O, error handling

**Benefits of Using Established Libraries:**
- **Battle-tested**: Handles edge cases discovered by thousands of users
- **Performance**: Optimized buffering and async I/O
- **Maintenance**: Community maintains the library, not your team
- **Features**: Rotation, compression, remote sinks already implemented

### Required Libraries by Language

| Language | Library | Purpose |
|----------|---------|---------|
| TypeScript | **Winston** | Structured logging, file rotation, transports |
| Python | **logging** (stdlib) + **RotatingFileHandler** | Standard library with rotation |
| Go | **zap** or **logrus** + **lumberjack** | High-performance logging + rotation |
| Java | **SLF4J** + **Logback** or **Log4j2** | Industry-standard Java logging |
| C# | **Serilog** or **NLog** | .NET structured logging |
| PHP | **Monolog** | PSR-3 compliant logging |
| Rust | **tracing** or **log** + **env_logger** | Rust ecosystem standard |

**Our Library's Role**: Wrap established logging libraries to standardize output structure and add OpenTelemetry integration. NOT to reinvent logging infrastructure.

See `specification/00-design-principles.md` section 10 for complete implementation patterns.

---

## Implementation Process Pitfalls

These pitfalls occur during the implementation process, not in the code itself. Discovered during Python implementation.

### ❌ DON'T: Use Dots in Metric Names

**Problem:** Prometheus requires underscores in metric names. Using dots causes metrics to not appear in Prometheus or Grafana.

**Bad Example:**
```
sovdev.operations.total  # Won't appear in Prometheus
sovdev.errors.total
sovdev.operation.duration
```

**Correct Example:**
```
sovdev_operations_total  # Prometheus compatible
sovdev_errors_total
sovdev_operation_duration
```

**Validation Check:** If Grafana metric panels (1-3) are empty, verify metric names use underscores.

**Impact:** 30 minutes debugging in Python implementation. Metrics exported but invisible in Grafana.

---

### ❌ DON'T: Use str(enum) for Enum Conversion

**Problem:** In Python, Java, C#, and other languages, converting enum to string using `str()` or `.toString()` returns the enum NAME, not the VALUE.

**Bad Example (Python):**
```python
# ❌ WRONG - Returns "SOVDEV_LOGLEVELS.ERROR"
level = str(SOVDEV_LOGLEVELS.ERROR)
# Results in log: { "level": "SOVDEV_LOGLEVELS.ERROR" }
```

**Correct Example (Python):**
```python
# ✅ CORRECT - Returns "error"
level = SOVDEV_LOGLEVELS.ERROR.value
# Results in log: { "level": "error" }
```

**Validation Check:**
- File validation catches this: `validate-log-format.sh` reports "Invalid log level 'SOVDEV_LOGLEVELS.ERROR'"
- Grafana check: If "Recent Errors" panel is empty despite errors, check enum conversion

**Impact:** Critical bug - errors invisible in Grafana until fixed. Caught by enhanced validation (Task 1.1.2).

---

### ❌ DON'T: Omit Required Fields for Grafana Panels

**Problem:** Grafana Panel 4 (Recent Errors) requires specific fields. Missing any of these causes empty panels or missing columns.

**Required Fields:**
- `timestamp` (ISO 8601 string, NOT just observed_timestamp)
- `severity_text` (must be "error" not "SOVDEV_LOGLEVELS.ERROR")
- `severity_number` (must be 17 for ERROR level)
- `span_id` (when in span/transaction context)
- `function_name`
- `message`

**Common Issue:**
```python
# ❌ WRONG - Only exports observed_timestamp
log_record = {
    "observed_timestamp": datetime.now().timestamp(),  # Unix timestamp
    "severity_text": str(level),  # Wrong conversion
    # Missing severity_number and timestamp
}
```

**Correct Example:**
```python
# ✅ CORRECT - All required fields
log_record = {
    "timestamp": datetime.now(timezone.utc).isoformat(),  # ISO 8601 string
    "severity_text": level.value,  # Enum value
    "severity_number": level.severity_number,  # OTEL severity number
    "span_id": current_span.span_id if current_span else None,
    "function_name": function_name,
    "message": message
}
```

**Validation Check:**
- Step 2 validation (query-loki.sh) now catches missing severity fields early
- Grafana Panel 4 will show empty table if fields missing

**Impact:** 20 minutes debugging in Python implementation. Caught by enhanced validation (Task 1.1.3).

---

### ❌ DON'T: Rely on kubectl - Use Grafana Instead

**Problem:** kubectl is optional. If kubectl commands fail, use Grafana-based queries instead of trying to fix kubectl access.

**Symptom:**
```
❌ kubectl cannot connect to Kubernetes cluster
```

**Wrong Response:**
```bash
# ❌ WRONG - Spending time debugging kubectl
export KUBECONFIG=/some/path
kubectl get nodes
# ... wasting time troubleshooting kubectl configuration ...
```

**Correct Response:**
```bash
# ✅ CORRECT - Use Grafana-based queries (always work)
cd /workspace/specification/tools && ./query-grafana-loki.sh python
cd /workspace/specification/tools && ./query-grafana-prometheus.sh python
cd /workspace/specification/tools && ./query-grafana-tempo.sh python
```

**Why This Matters:**
- **Grafana is the authoritative validation source** - Not kubectl
- kubectl access is optional (some environments don't configure it)
- Grafana-based query scripts (`query-grafana-*.sh`) work via Grafana API and are always available
- Time spent debugging kubectl is wasted - Grafana queries provide the same information

**Available Tools:**
- `query-loki.sh` - Direct kubectl access (optional, faster if kubectl works)
- `query-grafana-loki.sh` - Grafana API access (always works, use this if kubectl fails)
- Same pattern for Prometheus and Tempo

**Impact:** Wasted time debugging optional tool instead of using authoritative validation method.

---

## ✅ Summary: Key Principles

### Code Anti-Patterns (Avoid in Your Implementation)

1. **Always use service name for `scope_name`** - Never module/package names
2. **Always standardize `exceptionType` to "Error"** - Never language-specific types
3. **Always use flat structure for ALL fields** - Never nested objects (OTLP requirement)
4. **Always remove credentials before truncating** - Security over stack trace completeness
5. **Always reuse same `traceId` for related logs** - Enable trace correlation
6. **Always call `sovdev_flush()` before exit** - Prevent log loss
7. **Always use single `sessionId` per execution** - Enable session correlation
8. **Always define `FUNCTIONNAME` constant** - Prevent typos and enable refactoring
9. **Always define `input`/`response` variables** - Improve maintainability
10. **Always configure file rotation** - Prevent disk exhaustion
11. **Always use established logging libraries** - Never implement custom file writing/rotation

### Implementation Process Pitfalls (Avoid During Implementation)

1. **Always use underscores in metric names** - Never dots (Prometheus requirement)
2. **Always use `.value` for enum conversion** - Never `str(enum)` or `.toString()`
3. **Always include Grafana-required fields** - timestamp, severity_text, severity_number
4. **Always use Grafana for validation** - kubectl is optional, Grafana is authoritative

Following these patterns ensures consistent, secure, and maintainable logging across all language implementations.

---

**Document Status:** ✅ v1.0.0 COMPLETE
**Last Updated:** 2025-10-27
**Part of:** sovdev-logger specification v1.1.0
