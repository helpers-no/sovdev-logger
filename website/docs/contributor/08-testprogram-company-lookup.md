---
title: "Test program: company lookup"
sidebar_label: "Test program: company lookup"
sidebar_position: 12
description: "E2E test specification (MUST implement)."
---

# Test Program: Company-Lookup E2E Application

## Overview

The **company-lookup** application is the **primary E2E test and reference implementation** for sovdev-logger across all programming languages. It demonstrates all 8 core API functions in a realistic batch processing scenario that queries the Norwegian Brønnøysund Registry (BRREG) for company information.

**Status**: Production-Ready Reference Implementation
**Reference**: `typescript/test/e2e/company-lookup/company-lookup.ts`

---

## Purpose and Role

### Primary Purposes

1. **Reference Implementation**: The TypeScript version serves as the exemplary implementation that all other languages learn from
2. **Cross-Language Validation**: Enables automated verification that all language implementations produce equivalent output
3. **API Demonstration**: Shows correct usage of all 8 sovdev-logger functions in realistic scenarios
4. **Integration Testing**: Validates the complete telemetry pipeline (application → OTLP → Loki/Prometheus/Tempo → Grafana)

### Why Company Lookup?

This scenario was chosen because it:
- **Realistic**: Simulates actual business use case (batch processing external API calls)
- **Comprehensive**: Requires all 8 API functions (initialization, logging, job tracking, trace generation, flush)
- **Observable**: Demonstrates transaction correlation, job progress tracking, and error handling
- **Stable**: Uses public Norwegian company registry (real data, no privacy concerns)
- **Testable**: Predictable behavior with known-good and known-bad organization numbers

---

## Test Scenario Flow

### High-Level Narrative

The company-lookup application simulates a **batch company information service** that:

1. **Initializes** the sovdev-logger with service identity and peer service mappings
2. **Logs application start** to mark service lifecycle
3. **Starts a batch job** to process 4 Norwegian companies
4. **Tracks progress** as each company is processed
5. **Looks up each company** via external BRREG API:
   - Logs transaction start (before API call)
   - Makes HTTP request to BRREG
   - Logs transaction success/failure (after API call)
   - Uses explicit `trace_id` for transaction correlation
6. **Handles errors gracefully** - one company intentionally fails to demonstrate error logging
7. **Completes the batch job** with summary statistics
8. **Logs application finish** to mark service completion
9. **Flushes telemetry** to ensure all batched data is exported

### Step-by-Step Execution

#### Step 1: Logger Initialization
```typescript
sovdev_initialize(
  "sovdev-test-company-lookup-typescript",  // service_name (with language suffix)
  "1.0.0",                                   // service_version
  PEER_SERVICES.mappings                     // peer service validation
);
```

**Service Name Naming Convention**:
- Format: `sovdev-test-company-lookup-{language}`
- The `-{language}` suffix (e.g., `-typescript`, `-python`, `-go`) indicates which programming language implementation is running
- This enables:
  - Easy identification in logs and dashboards (which language generated these logs?)
  - Language-specific filtering in Grafana
  - Cross-language comparison and validation
  - Debugging multi-language deployments

**What happens**:
- Generates unique `session_id` (UUID) for this execution
- Configures triple output: Console + File + OTLP
- Initializes OpenTelemetry providers (logs, metrics, traces)
- Sets up peer service validation

**Log output**: None (initialization only)

#### Step 2: Application Start
```typescript
sovdev_log(
  SOVDEV_LOGLEVELS.INFO,
  'main',
  'Company Lookup Service started',
  PEER_SERVICES.INTERNAL
);
```

**Log output**: 1 entry (transaction, INFO, internal operation)

#### Step 3: Batch Job Started
```typescript
sovdev_log_job_status(
  SOVDEV_LOGLEVELS.INFO,
  'batchLookup',
  'CompanyLookupBatch',
  'Started',
  PEER_SERVICES.INTERNAL,
  { totalCompanies: 4 }
);
```

**Log output**: 1 entry (job.status, INFO, batch started)

#### Step 4: Batch Processing Loop

**For each company (4 iterations)**:

**4a. Progress Tracking**
```typescript
sovdev_log_job_progress(
  SOVDEV_LOGLEVELS.INFO,
  'batchLookup',
  orgNumber,              // Item being processed
  i + 1,                  // Current position (1-based)
  4,                      // Total items
  PEER_SERVICES.BRREG,
  { organisasjonsnummer: orgNumber }
);
```

**Log output**: 4 entries (job.progress, one per company)

**4b. Company Lookup (per company)**

**Transaction Start**:
```typescript
const trace_id = sovdev_generate_trace_id();

sovdev_log(
  SOVDEV_LOGLEVELS.INFO,
  'lookupCompany',
  `Looking up company ${orgNumber}`,
  PEER_SERVICES.BRREG,
  { organisasjonsnummer: orgNumber },
  null,      // No response yet
  null,      // No exception
  trace_id   // For correlation
);
```

**External API Call** (not logged):
```typescript
const companyData = await fetchCompanyData(orgNumber);
```

**Transaction Success** (for valid companies: 3 of 4):
```typescript
sovdev_log(
  SOVDEV_LOGLEVELS.INFO,
  'lookupCompany',
  `Company found: ${companyData.navn}`,
  PEER_SERVICES.BRREG,
  { organisasjonsnummer: orgNumber },
  { navn: companyData.navn, organisasjonsform: companyData.organisasjonsform?.beskrivelse },
  null,
  trace_id   // SAME trace_id as start
);
```

**Transaction Error** (for invalid company: 1 of 4):
```typescript
sovdev_log(
  SOVDEV_LOGLEVELS.ERROR,
  'lookupCompany',
  `Failed to lookup company ${orgNumber}`,
  PEER_SERVICES.BRREG,
  { organisasjonsnummer: orgNumber },
  null,      // No successful response
  error,     // Exception object
  trace_id   // SAME trace_id as start
);
```

**Batch Item Error** (after lookup error):
```typescript
sovdev_log(
  SOVDEV_LOGLEVELS.ERROR,
  'batchLookup',
  `Batch item ${i + 1} failed`,
  PEER_SERVICES.BRREG,
  { organisasjonsnummer: orgNumber, itemNumber: i + 1 },
  null,
  error
  // No trace_id - batch-level context, not lookup transaction
);
```

**Log output** per company:
- Valid companies (3): 2 logs (start + success) = 6 total
- Invalid company (1): 3 logs (start + error + batch error) = 3 total
- **Total transaction logs**: 9

#### Step 5: Batch Job Completed
```typescript
sovdev_log_job_status(
  SOVDEV_LOGLEVELS.INFO,
  'batchLookup',
  'CompanyLookupBatch',
  'Completed',
  PEER_SERVICES.INTERNAL,
  { totalCompanies: 4, successful: 3, failed: 1, successRate: "75%" }
);
```

**Log output**: 1 entry (job.status, INFO, batch completed)

#### Step 6: Application Finish
```typescript
sovdev_log(
  SOVDEV_LOGLEVELS.INFO,
  'main',
  'Company Lookup Service finished',
  PEER_SERVICES.INTERNAL
);
```

**Log output**: 1 entry (transaction, INFO, internal operation)

#### Step 7: Flush Telemetry
```typescript
await sovdev_flush();
```

**Critical**: Forces immediate export of all batched telemetry data. Without this, short-lived applications lose the last batch of logs/metrics/traces.

**Log output**: None (system operation)

---

## Expected Log Output

### Total Log Entry Count

| Log Source | Count | Details |
|------------|-------|---------|
| Application start | 1 | Service lifecycle (transaction) |
| Job status started | 1 | Batch job began (job.status) |
| Job progress | 4 | One per company (job.progress) |
| Transaction starts | 4 | One per company lookup (transaction) |
| Transaction success | 3 | Companies 1, 2, 4 (transaction) |
| Transaction error | 1 | Company 3 invalid (transaction) |
| Batch item error | 1 | Company 3 batch error (transaction) |
| Job status completed | 1 | Batch job finished (job.status) |
| Application finish | 1 | Service lifecycle (transaction) |
| **TOTAL** | **17** | **All log entries** |

**Verification**: Every language implementation MUST generate exactly 17 log entries.

### Log Type Distribution

| log_type | Count | Usage |
|----------|-------|-------|
| `transaction` | 11 | General operations, API calls, errors |
| `job.status` | 2 | Job started + completed |
| `job.progress` | 4 | Progress tracking per item |

### Peer Service Distribution

| peer_service | Count | Type |
|--------------|-------|------|
| `sovdev-test-company-lookup-{language}` | 5 | Internal operations |
| `SYS1234567` | 12 | BRREG external API |

### Level Distribution

| level | Count | Type |
|-------|-------|------|
| `info` | 15 | Normal operations |
| `error` | 2 | Failed operations |

### Trace ID Correlation

**Total unique trace_ids**: 13

**Correlated sets** (examples from actual test run):
- Lines 4 & 5: `trace_id="cc2321d758a44215b63493dbea89937f"` - Company 1 request + response
- Lines 7 & 8: `trace_id="b722ee3a2e5442fa89cfbb49164e9f9b"` - Company 2 request + response
- Lines 10 & 11: `trace_id="f8fb1e132efd4c09b4a430d79266e05c"` - Company 3 request + error

**Pattern**: Each company lookup generates ONE trace_id that links start log with success/error log.

---

## Test Data Specification

### Required Organization Numbers

**CRITICAL**: All language implementations MUST use these exact numbers in this exact order:

```typescript
const companies = [
  '971277882', // Company 1: DIREKTORATET FOR UTVIKLINGSSAMARBEID (NORAD) - Valid
  '915933149', // Company 2: DIREKTORATET FOR E-HELSE MELDT TIL OPPHØR - Valid
  '974652846', // Company 3: INVALID - Will fail with HTTP 404 (intentional)
  '916201478'  // Company 4: KVISTADMANNEN AS - Valid
];
```

### Why These Numbers?

1. **Real Organizations**: Norwegian public agencies and companies (no privacy concerns)
2. **Predictable Behavior**: Known-good (1, 2, 4) and known-bad (3) for consistent test results
3. **Stable Data**: Public registry data won't change or disappear
4. **Error Demonstration**: Company 3 intentionally fails to show error handling

### Expected API Behavior

| Company # | Org Number | Expected Result | HTTP Status |
|-----------|------------|-----------------|-------------|
| 1 | 971277882 | SUCCESS | 200 |
| 2 | 915933149 | SUCCESS | 200 |
| 3 | 974652846 | **FAILURE** | 404 |
| 4 | 916201478 | SUCCESS | 200 |

---

## Cross-Language Equivalence Requirements

### Requirement 1: Identical Service Identity

**MUST use environment variable**:
```bash
OTEL_SERVICE_NAME="sovdev-test-company-lookup-{language}"
```

**Naming Convention**:
- Format: `sovdev-test-company-lookup-{language}`
- The `-{language}` suffix indicates which programming language implementation is running
- Examples:
  - TypeScript: `sovdev-test-company-lookup-typescript`
  - Python: `sovdev-test-company-lookup-python`
  - Go: `sovdev-test-company-lookup-go`

**Why This Pattern?**
- Enables easy identification in logs and dashboards
- Allows language-specific filtering in Grafana
- Facilitates cross-language comparison and validation
- Helps debugging multi-language deployments

**Service version**: `"1.0.0"` (all languages)

### Requirement 2: Identical Peer Service Mapping

**MUST use**:
```typescript
const PEER_SERVICES = create_peer_services({
  BRREG: 'SYS1234567'  // Norwegian company registry
  // INTERNAL auto-generated: sovdev-test-company-lookup-{language}
});
```

### Requirement 3: Identical Test Data

See "Test Data Specification" above - exact organization numbers in exact order.

### Requirement 4: Identical Log Entry Count

**MUST generate exactly 17 log entries** with this distribution:
- 11 transaction logs
- 2 job.status logs
- 4 job.progress logs

### Requirement 5: Identical Log Entry Order

**MUST generate logs in this exact sequence**:

1. Application started (transaction)
2. Job started (job.status)
3. Progress company 1 (job.progress)
4. Lookup 1 start (transaction)
5. Lookup 1 success (transaction)
6. Progress company 2 (job.progress)
7. Lookup 2 start (transaction)
8. Lookup 2 success (transaction)
9. Progress company 3 (job.progress)
10. Lookup 3 start (transaction)
11. Lookup 3 error (transaction)
12. Batch item 3 error (transaction)
13. Progress company 4 (job.progress)
14. Lookup 4 start (transaction)
15. Lookup 4 success (transaction)
16. Job completed (job.status)
17. Application finished (transaction)




### Requirement 6: All 8 API Functions

**MUST demonstrate all 8 sovdev-logger functions**:

1. `sovdev_initialize()` - Once at startup
2. `sovdev_log()` - 11 times (various scenarios)
3. `sovdev_log_job_status()` - 2 times (started + completed)
4. `sovdev_log_job_progress()` - 4 times (one per company)
5. `sovdev_flush()` - Once at end
6. `sovdev_generate_trace_id()` - 4 times (one per lookup)
7. `SOVDEV_LOGLEVELS` - Use INFO (15 times) and ERROR (2 times)
8. `create_peer_services()` - Once at module initialization

---

## API Function Usage Patterns

### Pattern 1: Application Lifecycle (2 calls)

**Usage**: Mark service start/finish
```typescript
sovdev_log(
  SOVDEV_LOGLEVELS.INFO,
  'main',
  'Company Lookup Service started/finished',
  PEER_SERVICES.INTERNAL
  // input_json, response_json, exception, trace_id omitted (defaults to undefined)
);
```

**Fields present**:
- All standard fields
- No `input_json`, `response_json`, `trace_id`

### Pattern 2: Transaction Start (4 calls)

**Usage**: Log before external API call
```typescript
const trace_id = sovdev_generate_trace_id();

sovdev_log(
  SOVDEV_LOGLEVELS.INFO,
  'lookupCompany',
  `Looking up company ${orgNumber}`,
  PEER_SERVICES.BRREG,
  { organisasjonsnummer: orgNumber },
  null,      // No response yet
  null,      // No exception
  trace_id   // For correlation
);
```

**Fields present**:
- All standard fields
- `input_json`: Request parameters
- `response_json`: null (not available yet)
- `trace_id`: Generated once per transaction

### Pattern 3: Transaction Success (3 calls)

**Usage**: Log after successful API call
```typescript
sovdev_log(
  SOVDEV_LOGLEVELS.INFO,
  'lookupCompany',
  `Company found: ${companyName}`,
  PEER_SERVICES.BRREG,
  { organisasjonsnummer: orgNumber },
  { navn: "...", organisasjonsform: "..." },
  null,
  trace_id   // SAME as transaction start
);
```

**Fields present**:
- All standard fields
- `input_json`: Same as start log
- `response_json`: API response data
- `trace_id`: SAME as transaction start (correlation!)

### Pattern 4: Transaction Error (1 call)

**Usage**: Log after failed API call
```typescript
sovdev_log(
  SOVDEV_LOGLEVELS.ERROR,
  'lookupCompany',
  `Failed to lookup company ${orgNumber}`,
  PEER_SERVICES.BRREG,
  { organisasjonsnummer: orgNumber },
  null,      // No successful response
  error,     // Exception object
  trace_id   // SAME as transaction start
);
```

**Fields present**:
- All standard fields
- `input_json`: Same as start log
- `response_json`: null (no successful response)
- `exception_type`, `exception_message`, `exception_stacktrace`
- `trace_id`: SAME as transaction start (correlation!)

### Pattern 5: Batch Item Error (1 call)

**Usage**: Log batch-level error after lookup failure
```typescript
sovdev_log(
  SOVDEV_LOGLEVELS.ERROR,
  'batchLookup',
  `Batch item ${itemNumber} failed`,
  PEER_SERVICES.BRREG,
  { organisasjonsnummer: orgNumber, itemNumber: 3 },
  null,
  error
  // No trace_id - batch context, not transaction
);
```

**Fields present**:
- All standard fields
- `input_json`: Batch context (org number + item number)
- `response_json`: null
- `exception_type`, `exception_message`, `exception_stacktrace`
- No `trace_id` (batch-level, not part of lookup transaction)

### Pattern 6: Job Status (2 calls)

**Usage**: Track batch job lifecycle
```typescript
sovdev_log_job_status(
  SOVDEV_LOGLEVELS.INFO,
  'batchLookup',
  'CompanyLookupBatch',
  'Started' | 'Completed',
  PEER_SERVICES.INTERNAL,
  { totalCompanies: 4, successful: 3, failed: 1, successRate: "75%" }
);
```

**Fields present**:
- All standard fields
- `log_type`: `job.status` (auto-set)
- `input_json`: Job metadata with auto-added `job_name`, `job_status`
- No `response_json`, `trace_id`

### Pattern 7: Job Progress (4 calls)

**Usage**: Track progress through batch items
```typescript
sovdev_log_job_progress(
  SOVDEV_LOGLEVELS.INFO,
  'batchLookup',
  orgNumber,              // Item being processed
  i + 1,                  // Current position (1-based)
  4,                      // Total items
  PEER_SERVICES.BRREG,
  { organisasjonsnummer: orgNumber }
);
```

**Fields present**:
- All standard fields
- `log_type`: `job.progress` (auto-set)
- `input_json`: Item context with auto-added `item_id`, `current_item`, `total_items`, `progress_percentage`, `job_name`
- No `response_json`, `trace_id`

---

## Transaction Correlation Strategy

### Core Concept

**Explicit Trace ID Propagation**: Generate a `trace_id` once using `sovdev_generate_trace_id()`, then pass the SAME `trace_id` to all related log calls.

### Pattern

```typescript
// STEP 1: Generate trace_id ONCE per transaction
const trace_id = sovdev_generate_trace_id();

// STEP 2: Pass SAME trace_id to all related logs
sovdev_log(SOVDEV_LOGLEVELS.INFO, 'lookupCompany', 'Starting...',
           PEER_SERVICES.BRREG, input, null, null, trace_id);

// ... do work ...

sovdev_log(SOVDEV_LOGLEVELS.INFO, 'lookupCompany', 'Success!',
           PEER_SERVICES.BRREG, input, response, null, trace_id);
```

### Why This Works

1. **Simple**: No OTEL context management required
2. **Explicit**: Developer controls correlation scope
3. **Cross-language**: All languages can generate UUIDs
4. **No magic**: Clear cause-and-effect relationship
5. **No OTEL imports**: Complete abstraction maintained

### When to Use trace_id

✅ **Use when correlating related logs in a transaction**:
- Request + Response logs
- Operation start + operation end
- Multi-step operations within single business transaction

❌ **Don't use when logs are independent**:
- Application lifecycle events (start/finish)
- Job status logs (use `job_name` correlation instead)
- Independent batch item errors

### Real Example from Test

**Company 1 lookup** (lines 4-5 in log output):

```json
// Line 4: Transaction start
{
  "message": "Looking up company 971277882",
  "trace_id": "cc2321d758a44215b63493dbea89937f",
  "input_json": {"organisasjonsnummer": "971277882"},
  "response_json": null
}

// Line 5: Transaction success (SAME trace_id!)
{
  "message": "Company found: DIREKTORATET FOR UTVIKLINGSSAMARBEID (NORAD)",
  "trace_id": "cc2321d758a44215b63493dbea89937f",
  "input_json": {"organisasjonsnummer": "971277882"},
  "response_json": {"navn": "DIREKTORATET FOR...", "organisasjonsform": "Organisasjonsledd"}
}
```

**Result**: Both logs share `trace_id="cc2321d758a44215b63493dbea89937f"` → correlated transaction!

**Grafana Query**: `{service_name="sovdev-test-company-lookup-typescript"} | json | trace_id="cc2321d758a44215b63493dbea89937f"` returns both logs.

---

## Validation Tool Integration

### Required Project Structure

Every language implementation MUST follow the standardized directory structure documented in `06-test-scenarios.md`.

**⚠️ CRITICAL FILES REQUIRED:**
- `run-test.sh` - Entry point script (MUST exist)
- `.env` - OTLP configuration (MUST exist)

These files are NOT optional. Without them, validation tools will fail.

**Quick reference**:
```
{language}/
├── Makefile                              # Consistent interface (optional but recommended)
├── test/
│   └── e2e/
│       └── company-lookup/               # ⚠️ REQUIRED - Standardized path
│           ├── run-test.sh               # Entry point (MUST exist)
│           ├── company-lookup.*          # Test implementation (.ts, .py, .go, etc.)
│           ├── .env                      # OTLP configuration (MUST exist)
│           └── logs/                     # Output directory
│               ├── dev.log               # All logs
│               └── error.log             # Errors only
```

**For complete requirements**, see:
- **Project structure**: `06-test-scenarios.md` - "Required Project Structure" section
- **run-test.sh requirements**: `06-test-scenarios.md` - "Critical Requirements" section
- **.env configuration**: `06-test-scenarios.md` - "Critical Requirements" section

### Validation Tools

**How to validate this test:**

**📚 Primary documentation** (AUTHORITATIVE):
- **Complete tool reference**: [`tools/validation/uis/README.md`](https://github.com/helpers-no/sovdev-logger/blob/main/tools/validation/uis/README.md)
- **Quick start guide**: [`06-test-scenarios.md`](./06-test-scenarios.md) - "Quick Start: Testing Your Implementation"

**👨‍💻 For LLM implementers**:
- **End-to-end process**: [`implementation-guide.md`](./implementation-guide.md)

**Quick validation workflow for company-lookup**:

```bash
# Step 1: Validate log file format (fast, local)
./tools/validation/uis/validate-log-format.sh {language}/test/e2e/company-lookup/logs/dev.log

# Step 2: Quick smoke test (5 seconds, no backend queries)
./tools/validation/uis/run-company-lookup.sh {language}

# Step 3: Complete E2E validation (queries all backends, exact match)
LOG_FILE="{language}/test/e2e/company-lookup/logs/dev.log"
./tools/validation/uis/query-loki.sh sovdev-test-company-lookup-{language} --compare-with "$LOG_FILE"
./tools/validation/uis/query-tempo.sh sovdev-test-company-lookup-{language} --compare-with "$LOG_FILE"
./tools/validation/uis/query-prometheus.sh sovdev-test-company-lookup-{language} --compare-with "$LOG_FILE"

# Step 4: Cross-language conformance (the completion gate)
./tools/validation/uis/compare-with-master.sh {language}
```

**Expected result for company-lookup**:
- ✅ 17 log entries validated
- ✅ 13 unique trace IDs found
- ✅ All logs in Loki, exact match
- ✅ Metrics in Prometheus, exact match
- ✅ Traces in Tempo, exact match
- ✅ Field-by-field identical to TypeScript's output

**For debugging**: Use `query-loki.sh`, `query-prometheus.sh`, and `query-tempo.sh` without `--compare-with` for raw queries — see [`tools/validation/uis/README.md`](https://github.com/helpers-no/sovdev-logger/blob/main/tools/validation/uis/README.md)

---

## Implementation Checklist

Use this checklist when implementing company-lookup in a new language:

### Project Structure
- [ ] Created `{language}/test/e2e/company-lookup/` directory
- [ ] Created `run-test.sh` entry point script (**REQUIRED - MUST exist**)
- [ ] Created `.env` configuration file (**REQUIRED - MUST exist**)
- [ ] Created `logs/` output directory

### Test Data
- [ ] Using exact organization numbers: `971277882`, `915933149`, `974652846`, `916201478`
- [ ] Using exact peer service mapping: `BRREG` → `SYS1234567`
- [ ] Using correct service name: `sovdev-test-company-lookup-{language}`
- [ ] Using service version: `"1.0.0"`

### API Function Usage
- [ ] Called `sovdev_initialize()` once at startup
- [ ] Called `sovdev_log()` 11 times (2 lifecycle, 4 starts, 3 success, 2 errors)
- [ ] Called `sovdev_log_job_status()` 2 times (started + completed)
- [ ] Called `sovdev_log_job_progress()` 4 times (one per company)
- [ ] Called `sovdev_generate_trace_id()` 4 times (one per lookup)
- [ ] Used `SOVDEV_LOGLEVELS.INFO` 15 times
- [ ] Used `SOVDEV_LOGLEVELS.ERROR` 2 times
- [ ] Called `create_peer_services()` once at module init
- [ ] Called `sovdev_flush()` once before exit

### Transaction Correlation
- [ ] Generated `trace_id` once per company lookup
- [ ] Passed same `trace_id` to transaction start and success/error logs
- [ ] Verified correlation in log output (same `trace_id` on related entries)

### Expected Output
- [ ] Generates exactly 17 log entries
- [ ] Log type distribution: 11 transaction, 2 job.status, 4 job.progress
- [ ] Level distribution: 15 info, 2 error
- [ ] Peer service distribution: 5 internal, 12 BRREG
- [ ] Company 3 (974652846) fails with HTTP 404
- [ ] Companies 1, 2, 4 succeed
- [ ] All fields use snake_case naming
- [ ] Trace IDs are 32 lowercase hex characters

### Validation
- [ ] `validate-log-format.sh` passes (17 entries validated)
- [ ] `run-company-lookup.sh` passes (smoke test)
- [ ] `query-loki.sh`/`query-tempo.sh`/`query-prometheus.sh --compare-with` all pass (exact match)
- [ ] `compare-with-master.sh` passes (matches TypeScript field-by-field)
- [ ] Grafana dashboard shows all data

---

## Reference Implementation

**Source of Truth**: `typescript/test/e2e/company-lookup/company-lookup.ts`

### Key Features to Learn From

1. **Comprehensive inline documentation**: Every function call explained with "why" not just "what"
2. **Transaction correlation pattern**: Explicit `trace_id` generation and propagation
3. **No OTEL imports**: Complete abstraction - only sovdev-logger imports
4. **Error handling**: Demonstrates try/catch with error logging
5. **Batch processing**: Shows job status + progress tracking
6. **Code organization**: Clear sections with descriptive headers
7. **Best practices**: FUNCTIONNAME constants, input object reuse, descriptive messages

---

## Success Criteria

An implementation is **complete and correct** when:

1. ✅ Follows standardized project structure
2. ✅ Uses exact test data (4 organization numbers)
3. ✅ Demonstrates all 8 API functions
4. ✅ Generates exactly 17 log entries in correct order
5. ✅ Uses snake_case field naming
6. ✅ Implements transaction correlation with explicit trace_id
7. ✅ Passes `validate-log-format.sh` validation
8. ✅ Passes `run-company-lookup.sh` smoke test
9. ✅ Passes `compare-with-master.sh` — field-by-field identical to TypeScript's output
10. ✅ All data visible in Grafana dashboards

**Validation Commands**:
```bash
LOG_FILE="{language}/test/e2e/company-lookup/logs/dev.log"
./tools/validation/uis/query-loki.sh sovdev-test-company-lookup-{language} --compare-with "$LOG_FILE"
./tools/validation/uis/query-tempo.sh sovdev-test-company-lookup-{language} --compare-with "$LOG_FILE"
./tools/validation/uis/query-prometheus.sh sovdev-test-company-lookup-{language} --compare-with "$LOG_FILE"
./tools/validation/uis/compare-with-master.sh {language}
```

**Expected output**:
```
✅ All 17 log entries match schema
✅ Found 13 unique trace IDs
✅ VALIDATION PASSED
✅ Test PASSED for {language}
```

---

**Document Status:** ✅ v1.0.0 COMPLETE
**Last Updated:** 2025-10-27
**Part of:** sovdev-logger specification v1.1.0
**Reference Implementation:** `typescript/test/e2e/company-lookup/company-lookup.ts`
