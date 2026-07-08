# sovdev-logger (Python)

**One log call. Complete observability.**

Stop writing separate code for logs, metrics, and traces. Write one log entry and automatically get:
- ✅ **Structured logs** (Azure Log Analytics, Loki, or local files)
- ✅ **Metrics dashboards** (Azure Monitor, Prometheus, Grafana)
- ✅ **Distributed traces** (Azure Application Insights, Tempo)
- ✅ **Service dependency maps** (automatic correlation)

Output is field-for-field identical to the [TypeScript implementation](../typescript/README.md) — verified automatically by `specification/tools/compare-with-master.sh python`, not just documented.

---

## Who Do You Write Logs For?

You write code for yourself during development. But **you write logs for the operations engineer staring at a screen at 7 PM on Friday.**

Picture this: your application just crashed in production. Everyone on your team has left for the weekend. The ops engineer who got the alert doesn't know your codebase, doesn't know your business logic, and definitely doesn't want to be there right now.

**Make their job easy.** Good logging is the difference between "some exception occurred somewhere" and "user authentication failed for email 'x@y.com' — invalid password attempt #3, account locked." One takes 3 hours to debug; the other takes 5 minutes.

---

## The Problem: Traditional Observability is Complex

```python
# Traditional approach: separate code per signal
logger.info('Payment processed', extra={'order_id': '123'})
payment_counter.inc()
payment_duration.observe(duration)
with tracer.start_as_current_span('processPayment') as span:
    span.set_attribute('order_id', '123')
# ... manually correlate logs, metrics, traces
```

## The Solution: Zero-Effort Observability

```python
# sovdev-logger: 1 call, complete observability
FUNCTIONNAME = 'process_payment'
input_json = {'order_id': '123', 'amount': 99.99}
output_json = {'transaction_id': 'tx-456', 'status': 'approved'}

sovdev_log(SOVDEV_LOGLEVELS.INFO, FUNCTIONNAME, 'Payment processed',
           PEER_SERVICES.PAYMENT_GATEWAY, input_json, output_json)
# ↑ Automatic logs + metrics + traces + correlation
```

---

## Quick Start (60 Seconds)

### 1. Install

```bash
pip install -r requirements.txt  # opentelemetry-api, opentelemetry-sdk, and the OTLP HTTP exporters
```

(Not yet published to PyPI as a standalone package — install from this repo's `python/` directory for now.)

### 2. Basic Usage (Console + File Logging)

Create `test.py`:

```python
import sys
sys.path.insert(0, 'src')  # or however you've placed the package on your path

from logger import (
    sovdev_initialize, sovdev_log, sovdev_flush,
    SOVDEV_LOGLEVELS, create_peer_services,
)

# INTERNAL is auto-generated — pass an empty dict if you have no external systems
PEER_SERVICES = create_peer_services({})

def main():
    FUNCTIONNAME = 'main'

    sovdev_initialize('my-app')

    input_json = {'user_id': '123', 'action': 'process_order'}
    output_json = {'order_id': '456', 'status': 'success'}

    sovdev_log(
        SOVDEV_LOGLEVELS.INFO,
        FUNCTIONNAME,
        'Order processed successfully',
        PEER_SERVICES.INTERNAL,
        input_json,
        output_json,
    )

    sovdev_flush()  # CRITICAL — see "Common Mistakes" below

if __name__ == '__main__':
    main()
```

### 3. Run

```bash
python3 test.py
```

### 4. See Results

- ✅ **Console**: human-readable colored output
- ✅ **File**: structured JSON in `./logs/dev.log`
- 📊 **Want Grafana dashboards?** → see [Configuration](#configuration)

---

## Log Structure (snake_case Fields)

Identical structure to every other language implementation — same field names, same `snake_case` convention, verified by the same schema (`specification/schemas/log-entry-schema.json`) and the automated master-comparison check. See the [TypeScript README's Log Structure section](../typescript/README.md#log-structure-snake_case-fields) for the full field-by-field examples (basic entry, error entry, job status, job progress) — they apply identically here.

**One thing worth calling out explicitly**: `input_json`/`response_json` are *omitted entirely* when you don't pass them at all, and present as `null` when you explicitly pass `None` — matching how the field-omission behaves in every language. Don't rely on Python's `None`-default alone to mean "omit"; if you want the field present as `null`, pass `None` explicitly rather than leaving the argument out (both currently produce the same practical result for most call sites, but the distinction matters if you're writing code that inspects raw log output).

---

## Common Logging Patterns

### Pattern 1: Single Transaction (API Call, Database Query)

```python
# Define peer services once, near the top of your module
PEER_SERVICES = create_peer_services({
    'PAYMENT_GATEWAY': 'SYS2034567',  # External payment system (system ID)
    # INTERNAL is auto-generated — no need to declare it
})

def process_payment(order_id: str, amount: float):
    FUNCTIONNAME = 'process_payment'  # BEST PRACTICE: one constant per function

    input_json = {'order_id': order_id, 'amount': amount, 'currency': 'USD'}

    try:
        result = payment_gateway.charge(order_id, amount)
        output_json = {'transaction_id': result.id, 'status': 'approved'}

        sovdev_log(
            SOVDEV_LOGLEVELS.INFO,
            FUNCTIONNAME,
            'Payment processed successfully',
            PEER_SERVICES.PAYMENT_GATEWAY,  # Track external dependency
            input_json,
            output_json,
        )
        return result
    except Exception as error:
        output_json = {'status': 'failed', 'reason': str(error)}

        sovdev_log(
            SOVDEV_LOGLEVELS.ERROR,
            FUNCTIONNAME,
            'Payment failed',
            PEER_SERVICES.PAYMENT_GATEWAY,  # Still track peer service on error
            input_json,
            output_json,
            error,  # Exception object for stack trace
        )
        raise
```

**Key Points**:
- ✅ One `FUNCTIONNAME` constant per function — no typo-prone string literals
- ✅ Explicit `input_json`/`output_json` variables — reused across success/error logs, not redefined inline
- ✅ Track peer service even on errors — builds service dependency graphs
- ✅ Log both input AND output — complete audit trail

---

### Batch Job Pattern

```python
def import_users(users):
    FUNCTIONNAME = 'import_users'

    # 1. Log job START
    sovdev_log_job_status(
        SOVDEV_LOGLEVELS.INFO, FUNCTIONNAME, 'UserImportJob', 'Started',
        PEER_SERVICES.INTERNAL,  # Batch jobs are internal, not external calls
        {'total_users': len(users), 'source': 'CSV'},
    )

    success_count = 0
    failure_count = 0

    # 2. Process each item and log PROGRESS
    for i, user in enumerate(users):
        try:
            create_user(user)
            success_count += 1

            # BEST PRACTICE: log progress every N items, not every single one
            if (i + 1) % 10 == 0 or i == len(users) - 1:
                sovdev_log_job_progress(
                    SOVDEV_LOGLEVELS.INFO, FUNCTIONNAME, user.id,
                    i + 1, len(users), PEER_SERVICES.INTERNAL,
                    {'success_count': success_count, 'failure_count': failure_count},
                )
        except Exception as error:
            failure_count += 1

            # IMPORTANT: always log individual failures, don't skip errors
            sovdev_log_job_progress(
                SOVDEV_LOGLEVELS.ERROR, FUNCTIONNAME, user.id,
                i + 1, len(users), PEER_SERVICES.INTERNAL,
                {'email': user.email, 'error': str(error)},
            )

    # 3. Log job COMPLETION with final statistics
    sovdev_log_job_status(
        SOVDEV_LOGLEVELS.INFO, FUNCTIONNAME, 'UserImportJob', 'Completed',
        PEER_SERVICES.INTERNAL,
        {'total_users': len(users), 'success_count': success_count, 'failure_count': failure_count},
    )
```

**Result in Grafana**: query `{job_name="UserImportJob"}` to see the job lifecycle (Started → Progress → Completed); filter by ERROR level to see which specific users failed.

---

## Common Mistakes

### ❌ Forgetting to Flush

```python
def main():
    sovdev_log(SOVDEV_LOGLEVELS.INFO, FUNCTIONNAME, 'Test', PEER_SERVICES.INTERNAL, input_json)
    # Missing: sovdev_flush()
# Result: last logs lost!
```

**Fix**: always call `sovdev_flush()` before exit — note it's **synchronous** in Python, unlike TypeScript's `await sovdev_flush()`.

```python
def main():
    try:
        sovdev_log(SOVDEV_LOGLEVELS.INFO, FUNCTIONNAME, 'Test', PEER_SERVICES.INTERNAL, input_json)
    finally:
        sovdev_flush()  # ✅ Runs even if the try block raises
```

### ❌ Not Using a FUNCTIONNAME Constant

Same rationale as every other language implementation: prevents typos, makes refactoring safer, keeps logs filterable by function name. See the [TypeScript README's version of this section](../typescript/README.md#-not-using-functionname-constant) — identical guidance applies here with Python syntax.

### ❌ Hardcoding Peer Service Names

Use `create_peer_services()` constants instead of raw string literals like `'SYS1234567'` — same reasoning as TypeScript: single source of truth, easy to update, and it's what makes automatic service-dependency maps in Grafana possible.

---

## API Reference

**Naming convention**: Python uses the same `snake_case` function and field names as every other language implementation (`sovdev_log`, `sovdev_initialize`, `create_peer_services`) — this is a deliberate cross-language consistency choice, not incidental overlap with Python's own naming conventions.

### sovdev_initialize

```python
def sovdev_initialize(
    service_name: str,
    service_version: Optional[str] = None,
    peer_services: Optional[Dict[str, str]] = None,
) -> None
```

Initialize the logger with service information and peer system mappings. **Must be called once at application startup**, before any logging.

- **`service_name`** (required) — unique identifier for your service
- **`service_version`** (optional) — auto-detected from `SERVICE_VERSION`/`PYTHON_VERSION` env vars if omitted, falls back to `"1.0.0"`
- **`peer_services`** — pass `PEER_SERVICES.mappings` from `create_peer_services()`; enables service dependency maps in Grafana

### sovdev_log

```python
def sovdev_log(
    level: SovdevLogLevel,
    function_name: str,
    message: str,
    peer_service: str,
    input_json: Any = None,
    response_json: Any = None,
    exception: Optional[BaseException] = None,
) -> None
```

General purpose logging function. `input_json`/`response_json`: omit entirely for "no data" (field absent from output); pass `None` explicitly for "field present, value null". `exception`: pass the caught exception object to capture type/message/stacktrace automatically (credentials are stripped, stack limited to 350 characters).

**Note**: unlike TypeScript's `sovdev_log`, there is currently no manual `trace_id` override parameter — trace correlation is handled entirely through `sovdev_start_span()`/`sovdev_end_span()`.

### sovdev_log_job_status

```python
def sovdev_log_job_status(
    level: SovdevLogLevel,
    function_name: str,
    job_name: str,
    status: str,
    peer_service: str,
    input_json: Any = None,
) -> None
```

Track job lifecycle events. `status`: e.g. `'Started'`, `'Completed'`, `'Failed'`. `job_name`: a stable identifier for filtering in Grafana (e.g. `'UserSyncJob'`).

### sovdev_log_job_progress

```python
def sovdev_log_job_progress(
    level: SovdevLogLevel,
    function_name: str,
    item_id: str,
    current: int,
    total: int,
    peer_service: str,
    input_json: Any = None,
) -> None
```

Progress logging for batch/array processing — produces "Processing item 45 of 100" style logs. `current` is 1-based.

### sovdev_start_span / sovdev_end_span

```python
def sovdev_start_span(operation_name: str, attributes: Optional[Dict[str, Any]] = None) -> Span
def sovdev_end_span(span: Span, error: Optional[BaseException] = None) -> None
```

Wrap an operation in a span for distributed tracing — logs made between `sovdev_start_span()` and `sovdev_end_span()` automatically inherit the span's `trace_id`/`span_id`.

```python
span = sovdev_start_span('lookup_company', {'org_number': org_number})
try:
    result = lookup(org_number)
    sovdev_log(SOVDEV_LOGLEVELS.INFO, FUNCTIONNAME, 'Lookup complete',
               PEER_SERVICES.BRREG, {'org_number': org_number}, result)
except Exception as error:
    sovdev_end_span(span, error)
    raise
else:
    sovdev_end_span(span)
```

### sovdev_flush

```python
def sovdev_flush() -> None
```

Flush all pending logs, metrics, and traces before exit. **Synchronous** (no `await` — unlike TypeScript's `async sovdev_flush()`). Blocks up to 30 seconds. Safe to call from `finally` blocks and signal handlers.

---

### Not yet available in this implementation

Two optional diagnostic functions exist in the TypeScript implementation but not yet here — flagged explicitly rather than left for you to discover by a confusing `ImportError`:

- `sovdev_validate_config()` — validates required OTLP environment variables are set before initialization
- `sovdev_test_otlp_connection()` — tests connectivity to the OTLP logs/metrics/traces endpoints

Neither is required for normal operation (both are development/debugging aids). If you need them, check [TypeScript's implementation](../typescript/src/logger.ts) for the reference behavior to port.

---

## Configuration

**Local development**: no configuration needed — just install and run. Logs to console (colored) and `./logs/dev.log` (JSON) by default.

**Production / OTLP backends** (Azure Monitor, Grafana/Loki/Prometheus/Tempo): configure via environment variables — the same `OTEL_EXPORTER_OTLP_{LOGS,METRICS,TRACES}_ENDPOINT` and `OTEL_EXPORTER_OTLP_HEADERS` variables used by every language implementation, since this library sits on the standard OpenTelemetry Python SDK. See the [TypeScript README's Configuration section](../typescript/README.md#configuration) for the exact endpoint values and header requirements for each deployment scenario (local Traefik routing, in-cluster Kubernetes DNS, Azure Application Insights, Grafana Cloud) — they're environment-variable-driven and apply identically regardless of language.

Environment variables specific to file logging:

```bash
LOG_TO_FILE=true
LOG_FILE_PATH=./logs/dev.log       # optional, custom path
ERROR_LOG_PATH=./logs/error.log    # optional, custom error-only path
LOG_TO_CONSOLE=true                # optional, defaults based on whether OTLP is configured
```

---

## Compliance

Implements the same "Loggeloven av 2025" requirements as every other language implementation:

- ✅ Structured JSON format with a consistent, schema-validated shape
- ✅ Required fields on every log: `service_name`, `function_name`, `timestamp`, `trace_id`, `event_id`
- ✅ `snake_case` field naming throughout (no camelCase, no dotted notation)
- ✅ Flat exception fields (`exception_type`, `exception_message`, `exception_stacktrace`) — never nested
- ✅ Security: credentials automatically stripped from exception stack traces before truncation
- ✅ Distributed tracing via OpenTelemetry span/trace correlation

---

## Contributing to sovdev-logger

> This section is for **library contributors**. If you're a **library user**, you don't need it.

### Setup for Contributors

```bash
git clone https://github.com/helpers-no/sovdev-logger.git
cd sovdev-logger/python
pip install -r requirements.txt
```

### Testing (for Contributors)

```bash
cd test/e2e/company-lookup
./run-test.sh                 # E2E test + file-log validation
```

**Cross-language conformance** — the check that actually matters for "does this match TypeScript":

```bash
cd specification/tools
./compare-with-master.sh python
```

See [`specification/tools/README.md`](../specification/tools/README.md) for the complete validation sequence, and [`website/docs/ai-developer/plans/completed/PLAN-001-master-comparison-mode.md`](../website/docs/ai-developer/plans/completed/PLAN-001-master-comparison-mode.md) for how this conformance check works and what it does/doesn't cover.

### Contributing Workflow

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run `./compare-with-master.sh python` — it must pass with zero mismatches
5. Commit, push, open a pull request

---

## License

MIT

---

## Repository

[https://github.com/helpers-no/sovdev-logger](https://github.com/helpers-no/sovdev-logger)
