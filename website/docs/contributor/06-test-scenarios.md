---
title: Test scenarios
sidebar_label: Test scenarios
sidebar_position: 10
description: "Test scenarios and verification procedures."
---

# Test Scenarios for Sovdev Logger

## Overview

This document defines the **required test scenarios** that all sovdev-logger implementations MUST pass. These tests verify that implementations produce correct output across all three transports (OTLP, console, file) and that the observability stack properly receives and stores the data.

---

## ⚡ Quick Start: Testing Your Implementation

**IMPORTANT:** Use the provided tools in `tools/validation/uis/` - **DO NOT create custom validation scripts!**

### Testing Process

All sovdev-logger implementations are tested the same way, regardless of language:

**Step 1: Test log files**
```bash
# Validate log file format (fast, local-only test)
./tools/validation/uis/validate-log-format.sh {language}/test/e2e/company-lookup/logs/dev.log
```

**Step 2: Test OTLP export (exact match, not just presence)**
```bash
LOG_FILE="{language}/test/e2e/company-lookup/logs/dev.log"
./tools/validation/uis/query-loki.sh sovdev-test-company-lookup-{language} --compare-with "$LOG_FILE"
./tools/validation/uis/query-tempo.sh sovdev-test-company-lookup-{language} --compare-with "$LOG_FILE"
./tools/validation/uis/query-prometheus.sh sovdev-test-company-lookup-{language} --compare-with "$LOG_FILE"
```

**Step 3: Cross-language conformance (the completion gate)**
```bash
./tools/validation/uis/compare-with-master.sh {language}
```

### Example Workflow

```bash
# TypeScript implementation
./tools/validation/uis/validate-log-format.sh typescript/test/e2e/company-lookup/logs/dev.log
./tools/validation/uis/run-company-lookup.sh typescript
./tools/validation/uis/compare-with-master.sh typescript

# Python implementation
./tools/validation/uis/validate-log-format.sh python/test/e2e/company-lookup/logs/dev.log
./tools/validation/uis/run-company-lookup.sh python
./tools/validation/uis/compare-with-master.sh python
```

### Why Use These Tools?

- ✅ **Language-agnostic**: Works identically for all implementations
- ✅ **Comprehensive**: Tests file output, OTLP export, and backend verification
- ✅ **Automated**: No manual steps or Grafana clicking required
- ✅ **Consistent**: Same verification process for all languages

**📚 For complete tool documentation**, see **[`tools/validation/uis/README.md`](https://github.com/helpers-no/sovdev-logger/blob/main/tools/validation/uis/README.md)** (authoritative source)

**📝 For detailed company-lookup test specification**, see [`08-testprogram-company-lookup.md`](./08-testprogram-company-lookup.md)

---

## Required Project Structure

All sovdev-logger implementations **MUST** follow this standardized directory structure:

```
{language}/
├── Makefile                                # Consistent interface (optional but recommended)
├── src/                                    # Source code (implementation-specific)
├── test/
│   ├── unit/                               # Unit tests (language-specific framework)
│   ├── integration/                        # Integration tests (language-specific)
│   └── e2e/
│       └── company-lookup/        # ⚠️ REQUIRED - Used by verification tools
│           ├── run-test.sh                 # Entry point script (MUST exist)
│           ├── company-lookup.*            # E2E test implementation
│           ├── .env                        # OTLP configuration (MUST exist)
│           └── logs/                       # Test output directory
```

### Critical Requirements

**1. Standardized Path**
- All languages MUST use `test/e2e/company-lookup/` exactly
- This enables language-agnostic verification tools
- Verification scripts and templates depend on this convention

**2. run-test.sh Script (MUST EXIST)**
- **REQUIRED file** - Entry point for running the full-stack E2E test
- Loads `.env` configuration (also REQUIRED)
- Executes language-specific test command (e.g., `python3 company-lookup.py`, `npx tsx company-lookup.ts`)
- Returns exit code (0=success, non-zero=failure)

**3. company-lookup.* Test**
- Comprehensive E2E test covering all 11 test scenarios
- Uses real OTLP endpoints (sends to Loki, Prometheus, Tempo)
- Demonstrates best practices (FUNCTIONNAME constant, variable reuse, etc.)
- File extension matches language (.py, .ts, .go, .java, etc.)

**4. .env Configuration (MUST EXIST)**
- **REQUIRED file** - MUST be present in `test/e2e/company-lookup/.env`
- Contains OTLP endpoint URLs and configuration
- Format: `KEY=value` (standard shell format)
- Example:
  ```bash
  SYSTEM_ID=sovdev-test-company-lookup-{language}
  OTEL_EXPORTER_OTLP_LOGS_ENDPOINT=http://127.0.0.1/v1/logs
  OTEL_EXPORTER_OTLP_METRICS_ENDPOINT=http://127.0.0.1/v1/metrics
  OTEL_EXPORTER_OTLP_TRACES_ENDPOINT=http://127.0.0.1/v1/traces
  OTEL_EXPORTER_OTLP_HEADERS=Host=otel.localhost
  ```

**Note**: `OTEL_EXPORTER_OTLP_HEADERS` is the standard OpenTelemetry format — comma-separated `key=value` pairs, not JSON (see [`INVESTIGATE-otlp-headers-standard-compliance.md`](../ai-developer/plans/completed/INVESTIGATE-otlp-headers-standard-compliance.md)). No quoting gymnastics needed as a result, but still load `.env` with `set -a && source .env && set +a` rather than `export $(grep ... | xargs)`, which mishandles values containing spaces regardless.

**5. logs/ Directory**
- Output directory for file-based logs
- Created automatically by the test if it doesn't exist
- Contains `dev.log` (main) and `error.log` (errors only)

### Why This Structure?

**Enables automated verification:**
```bash
# Generic tool works for ALL languages
./tools/validation/uis/run-company-lookup.sh python
./tools/validation/uis/run-company-lookup.sh typescript
./tools/validation/uis/run-company-lookup.sh go

# Tool internally does:
# cd /workspace/{language}/test/e2e/company-lookup && ./run-test.sh
```

**Simplifies documentation:**
- Templates can reference `test/e2e/company-lookup/run-test.sh` for all languages
- Verification instructions are language-agnostic
- No need to document language-specific test commands

**Ensures consistency:**
- All implementations run the same test suite
- Verification process is identical across languages
- LLMs can implement new languages following the convention

### Reference Implementations

**Python:** `/workspace/python/test/e2e/company-lookup/`
**TypeScript:** `/workspace/typescript/test/e2e/company-lookup/`

Both serve as templates for implementing new languages.

---

## Verification Tools

The `tools/validation/uis/` directory provides **language-agnostic verification tools** that simplify testing and verification:

### Quick Smoke Test
```bash
./tools/validation/uis/run-company-lookup.sh python
./tools/validation/uis/run-company-lookup.sh typescript
```
- Runs application inside devcontainer
- Sends telemetry to OTLP endpoints
- Fast (seconds), no backend queries
- Use during development

### Complete E2E Test
```bash
LOG_FILE="python/test/e2e/company-lookup/logs/dev.log"
./tools/validation/uis/query-loki.sh sovdev-test-company-lookup-python --compare-with "$LOG_FILE"
./tools/validation/uis/query-tempo.sh sovdev-test-company-lookup-python --compare-with "$LOG_FILE"
./tools/validation/uis/query-prometheus.sh sovdev-test-company-lookup-python --compare-with "$LOG_FILE"
./tools/validation/uis/compare-with-master.sh python
```
- Runs against a language's E2E test output
- Exact-match comparison against the log file (`trace_id`/`event_id`), not just "found"
- `compare-with-master.sh` confirms it's field-by-field identical to TypeScript's output
- Use for official verification

### Backend Query Tools

Query individual backends for debugging or verification:

**Query Loki (Logs):**
```bash
./tools/validation/uis/query-loki.sh sovdev-test-company-lookup-python
./tools/validation/uis/query-loki.sh sovdev-test-company-lookup-python --json --limit 20
```

**Query Prometheus (Metrics):**
```bash
./tools/validation/uis/query-prometheus.sh sovdev-test-company-lookup-python
./tools/validation/uis/query-prometheus.sh sovdev-test-company-lookup-python --json
```

**Query Tempo (Traces):**
```bash
./tools/validation/uis/query-tempo.sh sovdev-test-company-lookup-python
./tools/validation/uis/query-tempo.sh sovdev-test-company-lookup-python --json --limit 10
```

**Benefits:**
- ✅ Works identically for all languages
- ✅ Abstracts devcontainer vs host complexity
- ✅ Dual output modes (human-readable + JSON)
- ✅ Composable for custom workflows

**See [`tools/validation/uis/README.md`](https://github.com/helpers-no/sovdev-logger/blob/main/tools/validation/uis/README.md) for complete documentation.**

---

## Test Categories

### 1. API Function Tests
Verify each of the 8 API functions works correctly.

### 2. Field Validation Tests
Verify all required fields are present in correct format.

### 3. Transport Tests
Verify output to all three destinations (OTLP, console, file).

### 4. Security Tests
Verify credential removal and stack trace limiting.

### 5. Integration Tests
Verify data flows through the complete stack (application → OTLP → Loki/Prometheus/Tempo → Grafana).

---

## Test Scenario 1: Basic INFO Log

**Purpose**: Verify basic logging functionality with minimum required fields.

**Test Code:**
```typescript
sovdev_log(
  SOVDEV_LOGLEVELS.INFO,
  'testFunction',
  'Test message',
  PEER_SERVICES.INTERNAL,
  { inputData: 'test' },
  { outputData: 'result' }
);
await sovdev_flush();
```

**Expected OTLP Output (Loki):**
```json
{
  "scope_name": "sovdev-test-app",
  "scope_version": "1.0.0",
  "severity_number": 9,
  "severity_text": "INFO",
  "service_name": "sovdev-test-app",
  "service_version": "1.0.0",
  "function_name": "testFunction",
  "message": "Test message",
  "peer_service": "sovdev-test-app",
  "trace_id": "<uuid>",
  "event_id": "<uuid>",
  "session_id": "<uuid>",
  "input_json": "{\"inputData\":\"test\"}",
  "response_json": "{\"outputData\":\"result\"}",
  "log_type": "transaction",
  "observed_timestamp": "<nanoseconds>"
}
```

**Expected Console Output:**
```
YYYY-MM-DD HH:mm:ss [INFO] sovdev-test-app
  Function: testFunction
  Message: Test message
  Trace ID: <uuid>
  Session ID: <uuid>
```

**Expected File Output:**
```json
{
  "timestamp": "YYYY-MM-DDTHH:mm:ss.ffffff+00:00",
  "level": "info",
  "service_name": "sovdev-test-app",
  "service_version": "1.0.0",
  "function_name": "testFunction",
  "message": "Test message",
  "trace_id": "<uuid>",
  "event_id": "<uuid>",
  "session_id": "<uuid>",
  "peer_service": "sovdev-test-app",
  "input_json": "{\"inputData\":\"test\"}",
  "response_json": "{\"outputData\":\"result\"}",
  "log_type": "transaction"
}
```

---

## Test Scenario 2: ERROR Log with Exception

**Purpose**: Verify error logging with exception processing and security cleanup.

**Test Code:**
```typescript
try {
  throw new Error('HTTP 404: Not Found');
} catch (error) {
  sovdev_log(
    SOVDEV_LOGLEVELS.ERROR,
    'lookupCompany',
    'Failed to lookup company 123456789',
    PEER_SERVICES.BRREG,
    { orgNumber: '123456789' },
    null,
    error as Error,
    traceId
  );
}
await sovdev_flush();
```

**Expected OTLP Output (Loki):**
```json
{
  "scope_name": "sovdev-test-app",
  "severity_number": 17,
  "severity_text": "ERROR",
  "function_name": "lookupCompany",
  "message": "Failed to lookup company 123456789",
  "peer_service": "SYS1234567",
  "trace_id": "<uuid>",
  "input_json": "{\"orgNumber\":\"123456789\"}",
  "response_json": "null",
  "exception_type": "Error",
  "exception_message": "HTTP 404: Not Found",
  "exception_stack": "<stack trace max 350 chars>"
}
```

**Expected Console Output:**
```
YYYY-MM-DD HH:mm:ss [ERROR] sovdev-test-app
  Function: lookupCompany
  Message: Failed to lookup company 123456789
  Trace ID: <uuid>
  Error: HTTP 404: Not Found
  Stack: <stack trace>
```

**Expected File Output:**
```json
{
  "timestamp": "YYYY-MM-DDTHH:mm:ss.ffffff+00:00",
  "level": "error",
  "service_name": "sovdev-test-app",
  "service_version": "1.0.0",
  "function_name": "lookupCompany",
  "message": "Failed to lookup company 123456789",
  "exception_type": "Error",
  "exception_message": "HTTP 404: Not Found",
  "exception_stack": "<stack trace max 350 chars>",
  "trace_id": "<uuid>",
  "peer_service": "SYS1234567",
  "input_json": "{\"orgNumber\":\"123456789\"}",
  "response_json": "null",
  "log_type": "transaction"
}
```

**Security Requirements:**
- Stack trace MUST be truncated to 350 characters maximum
- Stack trace MUST have credentials removed (auth headers, passwords, tokens)
- Exception type MUST be "Error" (not language-specific like "Exception" or "TypeError")

---

## Test Scenario 3: Job Status Log

**Purpose**: Verify batch job tracking with job status logging.

**Test Code:**
```typescript
const batchTraceId = sovdev_generate_trace_id();

sovdev_log_job_status(
  SOVDEV_LOGLEVELS.INFO,
  'batchProcess',
  'CompanyLookupBatch',
  'Started',
  PEER_SERVICES.INTERNAL,
  { totalItems: 100 },
  batchTraceId
);

// Process items...

sovdev_log_job_status(
  SOVDEV_LOGLEVELS.INFO,
  'batchProcess',
  'CompanyLookupBatch',
  'Completed',
  PEER_SERVICES.INTERNAL,
  { totalItems: 100, successCount: 98, errorCount: 2 },
  batchTraceId
);

await sovdev_flush();
```

**Expected OTLP Output (Loki) - Job Started:**
```json
{
  "severity_number": 9,
  "severity_text": "INFO",
  "function_name": "batchProcess",
  "message": "Job Started: CompanyLookupBatch",
  "peer_service": "sovdev-test-app",
  "trace_id": "<same-uuid-for-entire-batch>",
  "input_json": "{\"jobName\":\"CompanyLookupBatch\",\"jobStatus\":\"Started\",\"totalItems\":100}",
  "response_json": "null",
  "log_type": "job.status"
}
```

**Expected OTLP Output (Loki) - Job Completed:**
```json
{
  "severity_number": 9,
  "severity_text": "INFO",
  "function_name": "batchProcess",
  "message": "Job Completed: CompanyLookupBatch",
  "peer_service": "sovdev-test-app",
  "trace_id": "<same-uuid-as-started>",
  "input_json": "{\"jobName\":\"CompanyLookupBatch\",\"jobStatus\":\"Completed\",\"totalItems\":100,\"successCount\":98,\"errorCount\":2}",
  "response_json": "null",
  "log_type": "job.status"
}
```

**Requirements:**
- Both logs MUST have same trace_id
- Message format MUST be "Job {status}: {jobName}"
- log_type MUST be "job.status"
- input_json MUST contain jobName, jobStatus, and metadata

---

## Test Scenario 4: Job Progress Log

**Purpose**: Verify individual item progress tracking in batch jobs.

**Test Code:**
```typescript
for (let i = 0; i < totalItems; i++) {
  const itemId = items[i].id;

  sovdev_log_job_progress(
    SOVDEV_LOGLEVELS.INFO,
    'processItem',
    itemId,
    i + 1,
    totalItems,
    PEER_SERVICES.BRREG,
    { orgNumber: itemId },
    batchTraceId
  );

  // Process item...
}
await sovdev_flush();
```

**Expected OTLP Output (Loki):**
```json
{
  "severity_number": 9,
  "severity_text": "INFO",
  "function_name": "processItem",
  "message": "Processing 971277882 (25/100)",
  "peer_service": "SYS1234567",
  "trace_id": "<batch-trace-id>",
  "input_json": "{\"itemId\":\"971277882\",\"currentItem\":25,\"totalItems\":100,\"progressPercentage\":25,\"orgNumber\":\"971277882\"}",
  "response_json": "null",
  "log_type": "job.progress"
}
```

**Requirements:**
- trace_id MUST match job status logs
- Message format MUST be "Processing {itemId} ({current}/{total})"
- input_json MUST contain: itemId, currentItem, totalItems, progressPercentage
- progressPercentage MUST be Math.round((current / total) * 100)
- log_type MUST be "job.progress"

---

## Test Scenario 5: Null Response Handling

**Purpose**: Verify responseJSON field is always present even when null.

**Test Code:**
```typescript
sovdev_log(
  SOVDEV_LOGLEVELS.ERROR,
  'lookupCompany',
  'Company not found',
  PEER_SERVICES.BRREG,
  { orgNumber: '999999999' },
  null,  // Explicitly no response
  new Error('HTTP 404: Not Found')
);
await sovdev_flush();
```

**Expected OTLP Output (Loki):**
```json
{
  "function_name": "lookupCompany",
  "message": "Company not found",
  "input_json": "{\"orgNumber\":\"999999999\"}",
  "response_json": "null",
  "exception_type": "Error",
  "exception_message": "HTTP 404: Not Found"
}
```

**Critical Requirement:**
- response_json field MUST be present with value "null" (string, not JSON null)
- Field presence must be consistent across all log types

---

## Test Scenario 6: Credential Removal from Stack Traces

**Purpose**: Verify security cleanup removes credentials from exception stack traces.

**Test Code:**
```typescript
try {
  const response = await fetch('https://api.example.com/data', {
    headers: {
      'Authorization': 'Bearer secret-token-12345',
      'X-API-Key': 'api-key-67890'
    }
  });
} catch (error) {
  sovdev_log(
    SOVDEV_LOGLEVELS.ERROR,
    'apiCall',
    'API call failed',
    PEER_SERVICES.EXTERNAL_API,
    null,
    null,
    error as Error
  );
}
await sovdev_flush();
```

**Expected OTLP Output (Loki):**
```json
{
  "exception_type": "Error",
  "exception_message": "API call failed",
  "exception_stack": "<stack trace with credentials removed>"
}
```

**Security Requirements:**
- Stack trace MUST NOT contain "secret-token-12345"
- Stack trace MUST NOT contain "api-key-67890"
- Common credential patterns MUST be removed:
  - Authorization headers (Bearer tokens, Basic auth)
  - API keys
  - Passwords
  - JWT tokens
  - Cookie values

**Regex patterns to remove:**
```regex
/Authorization[:\s]+[^\s,}]+/gi
/password[:\s=]+[^\s,}]+/gi
/api[-_]?key[:\s=]+[^\s,}]+/gi
/Bearer\s+[A-Za-z0-9\-._~+/]+=*/gi
```

---

## Test Scenario 7: Trace Correlation Across Multiple Operations

**Purpose**: Verify traceId correlation links related operations.

**Test Code:**
```typescript
const traceId = sovdev_generate_trace_id();

sovdev_log(
  SOVDEV_LOGLEVELS.INFO,
  'startTransaction',
  'Starting transaction',
  PEER_SERVICES.INTERNAL,
  { transactionId: 'TXN-001' },
  null,
  null,
  traceId
);

sovdev_log(
  SOVDEV_LOGLEVELS.INFO,
  'callExternalAPI',
  'Calling external API',
  PEER_SERVICES.BRREG,
  { request: 'data' },
  { response: 'result' },
  null,
  traceId
);

sovdev_log(
  SOVDEV_LOGLEVELS.INFO,
  'completeTransaction',
  'Transaction completed',
  PEER_SERVICES.INTERNAL,
  { transactionId: 'TXN-001' },
  { status: 'success' },
  null,
  traceId
);

await sovdev_flush();
```

**Expected Behavior:**
- All three logs MUST have identical trace_id
- Grafana query `{service_name="sovdev-test-app"} | json | trace_id="<uuid>"` MUST return all three logs
- Logs should be linkable in Grafana UI via trace_id

---

## Test Scenario 8: Session Correlation

**Purpose**: Verify sessionId links all logs from a single execution.

**Test Code:**
```typescript
// Single execution, multiple operations
sovdev_initialize('sovdev-test-app', '1.0.0');

sovdev_log(SOVDEV_LOGLEVELS.INFO, 'operation1', 'First operation', PEER_SERVICES.INTERNAL);
sovdev_log(SOVDEV_LOGLEVELS.INFO, 'operation2', 'Second operation', PEER_SERVICES.INTERNAL);
sovdev_log(SOVDEV_LOGLEVELS.INFO, 'operation3', 'Third operation', PEER_SERVICES.INTERNAL);

await sovdev_flush();
```

**Expected Behavior:**
- All logs MUST have identical session_id
- session_id MUST be generated once at initialization
- session_id MUST be UUID v4 format (lowercase)
- Grafana query `{service_name="sovdev-test-app"} | json | session_id="<uuid>"` MUST return all logs from this execution

---

## Test Scenario 9: Metrics Generation

**Purpose**: Verify OpenTelemetry metrics are generated from log calls.

**Test Code:**
```typescript
// Log several operations
sovdev_log(SOVDEV_LOGLEVELS.INFO, 'operation1', 'Op 1', PEER_SERVICES.INTERNAL);
sovdev_log(SOVDEV_LOGLEVELS.INFO, 'operation2', 'Op 2', PEER_SERVICES.BRREG);
sovdev_log(SOVDEV_LOGLEVELS.ERROR, 'operation3', 'Failed', PEER_SERVICES.BRREG, null, null, new Error('test'));
await sovdev_flush();
```

**Expected Prometheus Metrics:**
```promql
# Query: sovdev_operations_total
sovdev_operations_total{service_name="sovdev-test-app"} >= 3

# Query: sovdev_errors_total
sovdev_errors_total{service_name="sovdev-test-app",exception_type="Error"} >= 1
```

**Verification Command:**
```bash
# Human-readable output
./tools/validation/uis/query-prometheus.sh sovdev-test-app

# JSON output for automated verification
./tools/validation/uis/query-prometheus.sh sovdev-test-app --json | \
  jq '.data.result[] | select(.metric.__name__ == "sovdev_operations_total")'
```

---

## Test Scenario 10: Trace Generation

**Purpose**: Verify OpenTelemetry spans are created for log operations.

**Test Code:**
```typescript
sovdev_log(SOVDEV_LOGLEVELS.INFO, 'testOperation', 'Test trace', PEER_SERVICES.BRREG);
await sovdev_flush();
```

**Expected Tempo Traces:**
- Trace with service.name="sovdev-test-app" should exist
- Span should have attributes matching log fields

**Verification Command:**
```bash
# Human-readable output
./tools/validation/uis/query-tempo.sh sovdev-test-app

# JSON output for automated verification
./tools/validation/uis/query-tempo.sh sovdev-test-app --json | \
  jq '.traces[] | {trace_id, rootServiceName, rootTraceName}'
```

---

## Test Scenario 11: Grafana Dashboard Verification

**Purpose**: Verify all logs appear in Grafana with correct fields.

**Test Code:**
```typescript
// Run full E2E test with multiple log types
const batchTraceId = sovdev_generate_trace_id();

sovdev_log_job_status(SOVDEV_LOGLEVELS.INFO, 'batch', 'TestBatch', 'Started', PEER_SERVICES.INTERNAL, {}, batchTraceId);
sovdev_log(SOVDEV_LOGLEVELS.INFO, 'process', 'Processing', PEER_SERVICES.BRREG);
sovdev_log(SOVDEV_LOGLEVELS.ERROR, 'process', 'Failed', PEER_SERVICES.BRREG, null, null, new Error('Test error'));
sovdev_log_job_status(SOVDEV_LOGLEVELS.INFO, 'batch', 'TestBatch', 'Completed', PEER_SERVICES.INTERNAL, {}, batchTraceId);

await sovdev_flush();
```

**Verification in Grafana:**
1. Open `http://grafana.localhost`
2. Navigate to "Structured Logging Testing Dashboard"
3. Filter: `systemId =~ /^sovdev-test-.*/`
4. Verify tables show:
   - **Transaction Logs**: INFO and ERROR logs with all fields
   - **Recent Errors**: ERROR log with exception details
   - **Job Status Tracking**: Started and Completed logs
   - **Active Sessions**: Current session_id

**Required Fields in Dashboard:**
- timestamp (human-readable)
- service_name
- function_name
- message
- peer_service
- trace_id
- log_type
- exception_type (for errors)
- exception_message (for errors)

---

## Test Validation Checklist

### ✅ Automated Verification (Use These Tools First!)

**IMPORTANT:** These tools automatically verify all test scenarios. Use them instead of manual verification.

**1. Validate log file format:**
```bash
./tools/validation/uis/validate-log-format.sh {language}/test/e2e/company-lookup/logs/dev.log
```

This tool automatically checks:
- All required fields present in correct format
- JSON serialization correct
- Field values (UUIDs, timestamps, severity)
- Stack traces within limits
- Flat snake_case structure

**2. Quick smoke test:**
```bash
./tools/validation/uis/run-company-lookup.sh {language}
```

This tool automatically:
- Runs test application in devcontainer
- Sends telemetry to OTLP endpoints
- Validates basic functionality
- Fast (5 seconds)

**3. Complete E2E validation:**
```bash
LOG_FILE="{language}/test/e2e/company-lookup/logs/dev.log"
./tools/validation/uis/query-loki.sh sovdev-test-company-lookup-{language} --compare-with "$LOG_FILE"
./tools/validation/uis/query-tempo.sh sovdev-test-company-lookup-{language} --compare-with "$LOG_FILE"
./tools/validation/uis/query-prometheus.sh sovdev-test-company-lookup-{language} --compare-with "$LOG_FILE"
./tools/validation/uis/compare-with-master.sh {language}
```

This verifies:
- ✅ OTLP export to all backends
- ✅ Logs arrived in Loki, exact match against the log file
- ✅ Metrics in Prometheus (sovdev_operations_total, sovdev_errors_total), exact match
- ✅ Traces in Tempo, exact match
- ✅ Field-by-field identical to TypeScript's reference output

**Result:** If all four tools pass, your implementation is complete! ✅

---

### 📝 Manual Verification (Optional, for Deep Debugging)

Only use manual verification if automated tools fail and you need to debug specific issues.

**OTLP Output (Loki) - Query manually:**
```bash
./tools/validation/uis/query-loki.sh {service-name}
./tools/validation/uis/query-loki.sh {service-name} --json | jq
```

Verify:
- [ ] All required fields present
- [ ] Field values in correct format (UUIDs, timestamps, severity numbers)
- [ ] JSON serialization correct (input_json, response_json)
- [ ] Exception handling correct (type, message, stack)
- [ ] Credentials removed from stack traces
- [ ] Stack traces limited to 350 characters

**Console Output - Check terminal:**
- [ ] Human-readable format
- [ ] Color coding appropriate (red for ERROR, yellow for WARN, etc.)
- [ ] Essential fields displayed (timestamp, level, service, function, message)
- [ ] Exception details shown for errors

**File Output - Inspect logs/ directory:**
- [ ] Valid JSON (one log per line)
- [ ] All required fields present
- [ ] Flat snake_case structure (service_name, function_name, etc.)
- [ ] Compact format (no pretty-printing)

**Metrics (Prometheus) - Query manually:**
```bash
./tools/validation/uis/query-prometheus.sh {service-name}
./tools/validation/uis/query-prometheus.sh {service-name} --json | jq
```

Verify:
- [ ] sovdev_operations_total increments
- [ ] sovdev_errors_total increments for errors
- [ ] Labels correct (service_name, exception_type)

**Traces (Tempo) - Query manually:**
```bash
./tools/validation/uis/query-tempo.sh {service-name}
./tools/validation/uis/query-tempo.sh {service-name} --json | jq
```

Verify:
- [ ] Spans created for operations
- [ ] Span attributes match log fields
- [ ] service.name correct

**Grafana Dashboard - Open in browser:**
1. Navigate to `http://grafana.localhost`
2. Open "Structured Logging Testing Dashboard"
3. Filter: `systemId =~ /^sovdev-test-.*/`

Verify:
- [ ] Logs appear in all relevant panels
- [ ] Fields displayed correctly
- [ ] Filtering works (by service, trace_id, session_id)
- [ ] Error logs highlighted
- [ ] Job tracking shows progress

---

## Performance Requirements

### Latency
- **Target**: < 1ms per log call (excluding network I/O)
- **Measurement**: Log 1000 operations, measure total time
- **Test**: `for i in range(1000): sovdevLog(...)`

### Memory Usage
- **Target**: < 10MB additional memory for logger initialization
- **Target**: < 1KB per log entry before batching
- **Measurement**: Monitor process memory before/after initialization

### Throughput
- **Target**: Support 1000+ logs/second without blocking
- **Test**: Generate high-volume logs, verify no application slowdown

### Batch Flushing
- **Target**: Flush completes within 30 seconds
- **Test**: Log 100 entries, call `sovdevFlush()`, measure time

---

## Error Handling Tests

### Test: Missing Required Fields
```typescript
// Should throw/return error
sovdev_log(
  null,  // Invalid: null level
  'function',
  'message',
  PEER_SERVICES.INTERNAL
);
```

**Expected**: Error or warning logged, operation continues

### Test: OpenTelemetry Export Failure
```typescript
// Configure invalid OTLP endpoint
process.env.OTEL_EXPORTER_OTLP_LOGS_ENDPOINT = 'http://invalid-host/logs';

sovdev_log(SOVDEV_LOGLEVELS.INFO, 'test', 'Test message', PEER_SERVICES.INTERNAL);
await sovdev_flush();
```

**Expected**:
- Console log shows warning about export failure
- Application continues without crashing
- Console and file outputs still work

---

## Language-Specific Test Adaptations

### TypeScript/JavaScript
- Use `Error` class for exceptions
- Use `async/await` for `sovdevFlush()`
- Use `process.env` for environment variables

### Python
- Use `Exception` class (converted to "Error" in output)
- Use async def/await for `sovdev_flush()`
- Use `os.environ` for environment variables

### Go (Future)
- Use `error` type (converted to "Error" in output)
- Use goroutines for async operations
- Use `os.Getenv()` for environment variables

---

## Success Criteria

An implementation **passes all tests** when:

1. ✅ All 11 test scenarios produce correct output in OTLP/console/file
2. ✅ All required fields present with correct types
3. ✅ Security features work (credential removal, stack limiting)
4. ✅ Metrics appear in Prometheus
5. ✅ Traces appear in Tempo
6. ✅ Logs visible in Grafana with all fields
7. ✅ Performance requirements met
8. ✅ Error handling graceful (no crashes)

---

**Document Status:** ✅ v1.0.0 COMPLETE
**Last Updated:** 2025-10-27
**Part of:** sovdev-logger specification v1.1.0
