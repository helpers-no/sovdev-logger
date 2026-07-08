# Sovdev Logger Verification Tools

This directory contains **language-agnostic verification tools** that enable automated testing and validation of sovdev-logger implementations.

## Purpose

These tools abstract away the complexity of:
- Testing thet the sovdev-logger has the expected output when developing and maintaining the code.
- Running code in the correct environment (devcontainer vs host)
- Understanding language-specific test commands
- Querying monitoring backends (Loki, Prometheus, Tempo)

**Key benefit:** One simple command works for ALL languages.

---

## Two-Level Validation Strategy

When implementing sovdev-logger in any programming language, use this approach:

### Level 1: System-Wide Health Check (TypeScript Baseline)

**ALWAYS verify TypeScript works before starting new language implementation**

TypeScript is the reference implementation that proves the observability stack is healthy.

```bash
# Verify observability stack health (Phase 0, Task 2)
cd /workspace/typescript/test/e2e/company-lookup && ./run-test.sh
cd /workspace/specification/tools && ./query-loki.sh sovdev-test-company-lookup-typescript
cd /workspace/specification/tools && ./query-prometheus.sh sovdev-test-company-lookup-typescript
cd /workspace/specification/tools && ./query-tempo.sh sovdev-test-company-lookup-typescript
```

**Result interpretation**:
- TypeScript fails → Infrastructure problem (fix Docker, Loki, Prometheus, Tempo)
- TypeScript passes → Infrastructure is healthy (new language issues are code-specific)

### Level 2: Continuous Language-Specific Validation

Validate your implementation at these checkpoints:

1. **File Format Validation** - After implementing file logging and running test
   - Run test → Check log files created → Run `validate-log-format.sh`

2. **OTLP Connectivity Test** - After implementing OTLP exporters
   - Create simple test with SDK functions → Send test data → Verify in backends

3. **Complete Backend Validation** - After E2E test runs successfully
   - Run E2E test → Wait 10s → Run `run-full-validation.sh` → Check all backends

4. **Grafana Visual Validation** - After automated validation passes
   - Open Grafana → Verify ALL panels show data

**Key Principle**: TypeScript validates the system. Your language validates its integration with the system.

**Important**: Validation tools check the OUTPUT of your implementation. Build and run your code FIRST, then validate.

**See complete workflow**: [Development loop](https://sovdev-logger.sovereignsky.no/contributor/development-loop) → "Validation-First Development" section

---

## Prerequisites

Before using these tools, ensure:

1. **Running inside devcontainer:**
   - These tools must be run from inside the devcontainer environment
   - Devcontainer provides kubectl access and required tools (curl, jq, python3)
   - Working directory should be `/workspace/specification/tools/`

2. **Language implementation follows standard structure**:
   ```
   {language}/
   └── test/e2e/company-lookup/
       ├── run-test.sh    # Entry point (REQUIRED)
       ├── company-lookup.*
       ├── .env
       └── logs/
   ```

   **For complete project structure requirements**, see [Test scenarios](https://sovdev-logger.sovereignsky.no/contributor/test-scenarios) → "Required Project Structure"

3. **Monitoring stack is running** (for Loki/Prometheus/Tempo queries):
   ```bash
   kubectl get pods -n monitoring
   # Should show: loki, prometheus, tempo, grafana, otel-collector pods
   ```

---

## 🔢 Validation Sequence (Step-by-Step)

**WHEN TO USE THIS:** After you have implemented all code and run your E2E test successfully.

**Prerequisites before validation:**
1. ✅ All code implemented (OTLP exporters, file logging, API functions)
2. ✅ E2E test created and runs without errors
3. ✅ E2E test has generated log files in `{language}/test/e2e/company-lookup/logs/`
4. ✅ Wait 10 seconds for OTLP data to propagate to backends

**CRITICAL:** These validation tools check the OUTPUT of your implementation. They won't work if you haven't implemented and run your code first.

---

### The 8-Step Validation Sequence

**You MUST follow these 8 steps in order.** Do NOT skip steps.

**Why order matters:**
- If Step 1 fails (file logs incorrect), Steps 2-7 will also fail (they validate the same data exported to backends)
- Each step validates a different layer of the same data pipeline
- Skipping to later steps wastes time debugging symptoms instead of root causes

**Rule:** If a step fails, stop and fix it before continuing.

**Option 1: Automated (Recommended)**
```bash
# Run Steps 1-7 automatically
cd /workspace/specification/tools && ./run-full-validation.sh {language}

# If exit code is 0, proceed to Step 8 (Grafana visual)
# If exit code is non-zero, fix the failing step and re-run
```

**Option 2: Manual (For troubleshooting)**
Run each step individually (documented below) to identify which step is failing.

---

### Step 1: Validate Log Files (INSTANT - 0 seconds) ⚡

**Tool:** `validate-log-format.sh`

**Purpose:** Check that log files on disk have correct format

**Command:**
```bash
cd /workspace/specification/tools && ./validate-log-format.sh {language}/test/e2e/company-lookup/logs/dev.log
```

**What it checks:**
- ✅ JSON schema compliance
- ✅ Field naming (snake_case)
- ✅ Required fields present
- ✅ Correct log entry count (17 expected)
- ✅ Correct trace ID count (13 unique expected)

**Expected result:** `✅ PASS`

**If FAIL:** Fix code issues, rebuild, run test again, then re-validate

**⛔ DO NOT PROCEED to Step 2 until this passes**

---

### Step 2: Verify Logs in Loki (OTLP → Loki) 🔄

**Tool:** `query-loki.sh`

**Purpose:** Check that logs reached Loki backend

**Three Validation Modes (choose based on your needs):**

```bash
sleep 10  # Wait for OTLP propagation

# Mode 1: Query only (basic check - data exists?)
./query-loki.sh sovdev-test-company-lookup-{language}

# Mode 2: Query + Schema validation (structure correct?)
./query-loki.sh sovdev-test-company-lookup-{language} --validate

# Mode 3: Query + Schema + Consistency (matches log file?)
./query-loki.sh sovdev-test-company-lookup-{language} --validate \
  --compare-with /workspace/{language}/test/e2e/company-lookup/logs/dev.log
```

**What each mode checks:**
- **Mode 1**: Logs exported via OTLP, Loki received logs
- **Mode 2**: Mode 1 + JSON structure, required fields, snake_case naming
- **Mode 3**: Mode 2 + field-by-field comparison with log file

**Expected result:**
- Mode 1: Returns log entries (should see 17 entries)
- Mode 2: Schema validation passes
- Mode 3: Consistency validation passes (all 17 entries match)

**Recommendation:** Use Mode 3 for complete validation, Mode 1 for quick checks

**If FAIL:**
- OTLP export not configured correctly
- Check `Host: otel.localhost` header
- Check OTLP endpoint URL

**⛔ DO NOT PROCEED to Step 3 until logs are in Loki**

---

### Step 3: Verify Metrics in Prometheus (OTLP → Prometheus) 🔄

**Tool:** `query-prometheus.sh`

**Purpose:** Check that metrics reached Prometheus backend

**Three Validation Modes (choose based on your needs):**

```bash
# Mode 1: Query only (basic check - data exists?)
./query-prometheus.sh sovdev-test-company-lookup-{language}

# Mode 2: Query + Schema validation (structure correct?)
./query-prometheus.sh sovdev-test-company-lookup-{language} --validate

# Mode 3: Query + Schema + Consistency (matches log file?)
./query-prometheus.sh sovdev-test-company-lookup-{language} --validate \
  --compare-with /workspace/{language}/test/e2e/company-lookup/logs/dev.log
```

**What each mode checks:**
- **Mode 1**: Metrics exported via OTLP, Prometheus received metrics
- **Mode 2**: Mode 1 + JSON structure, required fields, snake_case labels
- **Mode 3**: Mode 2 + metric counts match log file operation counts

**Expected result:**
- Mode 1: Returns metrics with correct labels
- Mode 2: Schema validation passes
- Mode 3: Consistency validation passes (counts match)

**CRITICAL - Check labels (Mode 1+ required):**
- ✅ `peer_service` (underscore, NOT peer.service)
- ✅ `log_type` (underscore, NOT log.type)
- ✅ `log_level` (underscore, NOT log.level)

**Recommendation:** Use Mode 3 for complete validation, Mode 1 for quick checks

**If FAIL:**
- Metrics not exported
- Check OTEL SDK metric configuration
- See [OpenTelemetry SDK guide](https://sovdev-logger.sovereignsky.no/contributor/research-otel-sdk-guide) for label issues

**⛔ DO NOT PROCEED to Step 4 until metrics are in Prometheus with correct labels**

---

### Step 4: Verify Traces in Tempo (OTLP → Tempo) 🔄

**Tool:** `query-tempo.sh`

**Purpose:** Check that traces reached Tempo backend

**Three Validation Modes (choose based on your needs):**

```bash
# Mode 1: Query only (basic check - data exists?)
./query-tempo.sh sovdev-test-company-lookup-{language}

# Mode 2: Query + Schema validation (structure correct?)
./query-tempo.sh sovdev-test-company-lookup-{language} --validate

# Mode 3: Query + Schema + Consistency (matches log file?)
./query-tempo.sh sovdev-test-company-lookup-{language} --validate \
  --compare-with /workspace/{language}/test/e2e/company-lookup/logs/dev.log
```

**What each mode checks:**
- **Mode 1**: Traces exported via OTLP, Tempo received traces
- **Mode 2**: Mode 1 + JSON structure, required fields, span details
- **Mode 3**: Mode 2 + trace IDs match log file trace IDs

**Expected result:**
- Mode 1: Returns trace data
- Mode 2: Schema validation passes
- Mode 3: Consistency validation passes (trace IDs match)

**Recommendation:** Use Mode 3 for complete validation, Mode 1 for quick checks

**If FAIL:**
- Traces not exported
- Check OTEL SDK trace configuration

**⛔ DO NOT PROCEED to Step 5 until traces are in Tempo**

---

### Step 5: Verify Grafana-Loki Connection (Grafana → Loki) 🔄

**Tool:** `query-grafana-loki.sh`

**Purpose:** Check that Grafana can query Loki (not just that Loki has data)

**Three Validation Modes (choose based on your needs):**

```bash
# Mode 1: Query only (basic check - Grafana can reach Loki?)
./query-grafana-loki.sh sovdev-test-company-lookup-{language}

# Mode 2: Query + Schema validation (Grafana returns correct structure?)
./query-grafana-loki.sh sovdev-test-company-lookup-{language} --validate

# Mode 3: Query + Schema + Consistency (Grafana data matches file?)
./query-grafana-loki.sh sovdev-test-company-lookup-{language} --validate \
  --compare-with /workspace/{language}/test/e2e/company-lookup/logs/dev.log
```

**What each mode checks:**
- **Mode 1**: Grafana datasource configured, can query Loki through proxy
- **Mode 2**: Mode 1 + JSON structure, required fields, snake_case naming
- **Mode 3**: Mode 2 + Grafana returns same data as direct Loki query

**Expected result:**
- Mode 1: Returns log entries (same as Step 2, but through Grafana)
- Mode 2: Schema validation passes
- Mode 3: Consistency validation passes (matches file)

**Recommendation:** Use Mode 3 to verify Grafana integration is correct

**If FAIL but Step 2 passed:**
- Grafana datasource misconfigured
- Check Grafana datasource settings

**⛔ DO NOT PROCEED to Step 6 until Grafana can query Loki**

---

### Step 6: Verify Grafana-Prometheus Connection (Grafana → Prometheus) 🔄

**Tool:** `query-grafana-prometheus.sh`

**Purpose:** Check that Grafana can query Prometheus (not just that Prometheus has data)

**Three Validation Modes (choose based on your needs):**

```bash
# Mode 1: Query only (basic check - Grafana can reach Prometheus?)
./query-grafana-prometheus.sh sovdev-test-company-lookup-{language}

# Mode 2: Query + Schema validation (Grafana returns correct structure?)
./query-grafana-prometheus.sh sovdev-test-company-lookup-{language} --validate

# Mode 3: Query + Schema + Consistency (Grafana data matches file?)
./query-grafana-prometheus.sh sovdev-test-company-lookup-{language} --validate \
  --compare-with /workspace/{language}/test/e2e/company-lookup/logs/dev.log
```

**What each mode checks:**
- **Mode 1**: Grafana datasource configured, can query Prometheus through proxy
- **Mode 2**: Mode 1 + JSON structure, required fields, snake_case labels
- **Mode 3**: Mode 2 + Grafana returns same data as direct Prometheus query

**Expected result:**
- Mode 1: Returns metrics (same as Step 3, but through Grafana)
- Mode 2: Schema validation passes
- Mode 3: Consistency validation passes (counts match file)

**Recommendation:** Use Mode 3 to verify Grafana integration is correct

**If FAIL but Step 3 passed:**
- Grafana datasource misconfigured
- Check Grafana datasource settings

**⛔ DO NOT PROCEED to Step 7 until Grafana can query Prometheus**

---

### Step 7: Verify Grafana-Tempo Connection (Grafana → Tempo) 🔄

**Tool:** `query-grafana-tempo.sh`

**Purpose:** Check that Grafana can query Tempo (not just that Tempo has data)

**Three Validation Modes (choose based on your needs):**

```bash
# Mode 1: Query only (basic check - Grafana can reach Tempo?)
./query-grafana-tempo.sh sovdev-test-company-lookup-{language}

# Mode 2: Query + Schema validation (Grafana returns correct structure?)
./query-grafana-tempo.sh sovdev-test-company-lookup-{language} --validate

# Mode 3: Query + Schema + Consistency (Grafana data matches file?)
./query-grafana-tempo.sh sovdev-test-company-lookup-{language} --validate \
  --compare-with /workspace/{language}/test/e2e/company-lookup/logs/dev.log
```

**What each mode checks:**
- **Mode 1**: Grafana datasource configured, can query Tempo through proxy
- **Mode 2**: Mode 1 + JSON structure, required fields, span details
- **Mode 3**: Mode 2 + Grafana returns same data as direct Tempo query

**Expected result:**
- Mode 1: Returns traces (same as Step 4, but through Grafana)
- Mode 2: Schema validation passes
- Mode 3: Consistency validation passes (trace IDs match file)

**Recommendation:** Use Mode 3 to verify Grafana integration is correct

**If FAIL but Step 4 passed:**
- Grafana datasource misconfigured
- Check Grafana datasource settings

**⛔ DO NOT PROCEED to Step 8 until Grafana can query Tempo**

---

### Step 8: Verify Grafana Dashboard (Visual Verification) 👁️

**Tool:** Manual browser check

**Prerequisites:**
- ✅ Your E2E test ran successfully
- ✅ Steps 1-7 all passed (either via `run-full-validation.sh` or manually)
- ✅ No errors in any of the previous steps

**Purpose:** Verify dashboard actually displays data correctly in the UI

**Steps:**
1. Open http://grafana.localhost
2. Navigate to: Structured Logging Testing Dashboard
3. Verify ALL 3 panels show data:
   - Panel 1: Total Operations
   - Panel 2: Error Rate
   - Panel 3: Average Operation Duration

**Expected result:** All 3 panels show data for {language} (similar to TypeScript reference)

**If ANY panel is empty:**
- Steps 1-7 didn't actually pass (even if script said they did)
- Go back and run `run-full-validation.sh {language}` again
- DO NOT claim "implementation complete"

**✅ VALIDATION COMPLETE when:**
- All Steps 1-7 passed
- ALL 3 Grafana panels show data for {language}

**Remember:** This is the FINAL step in the 8-step sequence. You cannot skip Steps 1-7 and jump here.

---

**Summary of 8-Step Validation Sequence:**
- Steps 1-7: Automated via `run-full-validation.sh` (or run manually for troubleshooting)
- Step 8: Manual visual check in Grafana (MUST do this even if Steps 1-7 pass)

---

### Step 9: Master Comparison — Does It Match TypeScript? (NEW)

**Tool:** `compare-with-master.sh`

**Prerequisites:**
- ✅ TypeScript's E2E test has been run (`typescript/test/e2e/company-lookup/run-test.sh`)
- ✅ Your candidate language's E2E test has been run

**Purpose:** Steps 1-8 confirm your implementation is internally consistent and well-formed. They do **not** confirm it matches TypeScript's actual output — the two are different questions, and only the second one is "identical output across all implementations." This step is the automated, re-runnable answer to that question, replacing what used to be a one-off hand-written comparison document.

```bash
cd specification/tools && ./compare-with-master.sh {language}
```

Compares the candidate's `logs/dev.log` against TypeScript's, field by field, for the same fixed company-lookup scenario. Per-run values (`timestamp`, `trace_id`, `span_id`, `event_id`, `session_id`), the language-specific `service_name` suffix, and `exception_stacktrace` content are excluded by design — everything else must match exactly.

**Expected result:** exit code 0, `✅ MATCH — output is identical to TypeScript's`

**If it fails:** the error output names the exact entry and field, with TypeScript's expected value and your candidate's actual value — fix the implementation, don't adjust the comparator's normalization rules to make a real mismatch disappear.

**This step, not Step 8's Grafana panels, is the authoritative check for "identical output across languages."** See `website/docs/ai-developer/plans/completed/PLAN-001-master-comparison-mode.md` for the full design rationale.

---

## Quick Reference

All scripts run inside the DevContainer at `/workspace/specification/tools/`.

| Script | Purpose | Usage |
|--------|---------|-------|
| [**run-full-validation.sh**](run-full-validation.sh) | **RECOMMENDED** - Complete E2E validation | `./run-full-validation.sh python` |
| [**compare-with-master.sh**](compare-with-master.sh) | Step 9: diff a candidate's file log against TypeScript's, field by field | `./compare-with-master.sh python` |
| [**generate-field-constants.py**](generate-field-constants.py) | Generate field-name constants from `schemas/log-entry-schema.json` (run before implementing a new language — see `implementation-guide.md` step 2) | `python3 generate-field-constants.py --lang python` |
| [**check-doc-consistency.py**](check-doc-consistency.py) | Catch doc drift: inconsistent GitHub remotes across READMEs, a Supported Languages table that doesn't match which `{language}/README.md` files exist | `python3 check-doc-consistency.py` |
| [**run-company-lookup.sh**](run-company-lookup.sh) | Quick smoke test | `./run-company-lookup.sh python` |
| [**validate-log-format.sh**](validate-log-format.sh) | Validate log file format | `./validate-log-format.sh python/test/logs/dev.log` |
| [**query-loki.sh**](query-loki.sh) | Query Loki for logs | `./query-loki.sh sovdev-test-company-lookup-python` |
| [**query-prometheus.sh**](query-prometheus.sh) | Query Prometheus for metrics | `./query-prometheus.sh sovdev-test-company-lookup-python` |
| [**query-tempo.sh**](query-tempo.sh) | Query Tempo for traces | `./query-tempo.sh sovdev-test-company-lookup-python` |
| [**validate-grafana-datasources.sh**](validate-grafana-datasources.sh) | Validate Grafana datasource config | `./validate-grafana-datasources.sh` |
| [**query-grafana-loki.sh**](query-grafana-loki.sh) | Query Loki via Grafana | `./query-grafana-loki.sh sovdev-test-company-lookup-python` |
| [**query-grafana-prometheus.sh**](query-grafana-prometheus.sh) | Query Prometheus via Grafana | `./query-grafana-prometheus.sh sovdev-test-company-lookup-python` |
| [**query-grafana-tempo.sh**](query-grafana-tempo.sh) | Query Tempo via Grafana | `./query-grafana-tempo.sh sovdev-test-company-lookup-python` |
| [**run-grafana-validation.sh**](run-grafana-validation.sh) | Validate Grafana queries only | `./run-grafana-validation.sh <service> <logfile>` |

All commands should be run from inside the DevContainer at `/workspace/`.

---

## Validation Scripts Comparison

**Which script should I use?** This table shows what each validation and query script does:

### Validation Runner Scripts

| Script | Runs App | File Log Validation | Loki Schema validation | Loki compared to log file validation | Prometheus Schema validation | Prometheus compared to log file validation | Tempo Schema validation | Tempo compared to log file validation | Grafana Proxy | Use Case |
|--------|----------|---------------------|------------------------|--------------------------------------|------------------------------|--------------------------------------------| ------------------------|---------------------------------------|---------------|----------|
| **run-company-lookup.sh** | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | Quick smoke test - file logs only |
| **run-full-validation.sh** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | **RECOMMENDED** - Complete E2E validation (6 queries via combined flags) |
| **run-grafana-validation.sh** | ❌ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | Grafana proxy validation only (3 queries via combined flags) |

**Validation Script Purposes:**
- **run-company-lookup.sh**: Quick smoke test - runs app, validates file logs only (no backend queries)
- **run-full-validation.sh**: Complete validation - file logs + all backends (direct + Grafana proxy)
  - Uses combined validation flags (--validate --compare-with) for efficiency
  - **6 total queries** (3 direct + 3 via Grafana) instead of 12 separate queries
- **run-grafana-validation.sh**: Grafana-only validation - assumes logs exist, only tests Grafana datasource queries
  - Uses combined validation flags (--validate --compare-with) for efficiency
  - **3 total queries** (one per backend) instead of 6 separate queries

### Query Scripts (Direct Backend & Grafana Proxy)

All query scripts support **three validation modes** via optional flags:

| Script | Queries Backend | Via Grafana | Validates Schema (--validate) | Compares to Log File (--compare-with) | Output Format |
|--------|----------------|-------------|-------------------------------|---------------------------------------|---------------|
| **query-loki.sh** | Loki | ❌ | ✅ Optional | ✅ Optional | JSON/Text |
| **query-prometheus.sh** | Prometheus | ❌ | ✅ Optional | ✅ Optional | JSON/Text |
| **query-tempo.sh** | Tempo | ❌ | ✅ Optional | ✅ Optional | JSON/Text |
| **query-grafana-loki.sh** | Loki | ✅ | ✅ Optional | ✅ Optional | JSON/Text |
| **query-grafana-prometheus.sh** | Prometheus | ✅ | ✅ Optional | ✅ Optional | JSON/Text |
| **query-grafana-tempo.sh** | Tempo | ✅ | ✅ Optional | ✅ Optional | JSON/Text |
| **validate-grafana-datasources.sh** | Grafana Config | ✅ | N/A | N/A | JSON/Text |

**Three Validation Modes:**

All query scripts follow the same pattern with three progressively deeper validation levels:

**Mode 1: Query Only (No Flags)**
```bash
# Returns raw data, no validation
./query-loki.sh sovdev-test-company-lookup-python
./query-grafana-loki.sh sovdev-test-company-lookup-python
```
- Returns: Human-readable summary or JSON (with --json flag)
- Validates: Only that query succeeded and returned data

**Mode 2: Query + Schema Validation (--validate)**
```bash
# Validates response structure and field types
./query-loki.sh sovdev-test-company-lookup-python --validate
./query-grafana-loki.sh sovdev-test-company-lookup-python --validate
```
- Returns: Validation results (schema compliance)
- Validates: JSON structure, required fields, field naming (snake_case)

**Mode 3: Query + Schema + Consistency Validation (--validate --compare-with)**
```bash
# Validates data matches log file content
./query-loki.sh sovdev-test-company-lookup-python --validate --compare-with logs/dev.log
./query-grafana-loki.sh sovdev-test-company-lookup-python --validate --compare-with logs/dev.log
```
- Returns: Validation results (schema + consistency)
- Validates: Schema + field-by-field comparison with log file

**Key Points:**
- **Direct query scripts** (query-loki.sh, query-prometheus.sh, query-tempo.sh): Query backends directly via kubectl
- **Grafana proxy scripts** (query-grafana-*.sh): Query backends through Grafana datasource proxy
- **validate-grafana-datasources.sh**: Validates Grafana datasource configuration only (no data query)
- **All 6 query scripts** support the same validation flags and patterns
- **Validation is optional**: Use flags only when you need validation, otherwise get raw data

**Legend:**
- **Runs App**: Installs/builds library, runs company-lookup app to generate log files
- **File Log Validation**: Validates log files (dev.log, error.log) against log-entry-schema.json
- **Schema validation**: Validates backend response structure and required fields (timestamp, service_name, etc.)
- **compared to log file validation**: Compares backend response with log file content (same entries, same values, same counts)
- **Grafana Proxy**: Queries backends through Grafana datasource proxy (tests Grafana integration)

**Validation Layers:**
1. **Layer 1 - Schema Validation** ✅ Checks structure: Is JSON valid? Are required fields present? Are field types correct?
2. **Layer 2 - compared to log file validation** ✅ Checks values: Do backend response values match log file content? Same counts?
3. **Layer 3 - Business Logic** ⏳ Checks semantics: Is duration > 0? Are error rates acceptable? (future work)

**Recommendations:**

**For Development (Most Common):**
```bash
cd /workspace/specification/tools && ./run-full-validation.sh typescript
```
Complete validation: file logs + all backends + Grafana datasources.

**For Quick Smoke Test:**
```bash
cd /workspace/specification/tools && ./run-company-lookup.sh typescript
```
Fast feedback: validates file log format only, no backend queries.

**For Grafana-Only Testing:**
```bash
cd /workspace/specification/tools && ./run-grafana-validation.sh sovdev-test-company-lookup-typescript logs/dev.log
```
Validates Grafana datasource queries only (assumes logs exist).

---

## Composable Workflows

These tools can be combined for powerful verification workflows.

**Note on Validation Approaches:**
- **Orchestration scripts** (run-full-validation.sh, run-grafana-validation.sh) use **combined flags** for efficiency
- **Manual workflows** can use either approach depending on needs:
  - **Combined approach**: `--validate --compare-with` (faster, one query per backend)
  - **Three-step approach**: Query → Schema → Consistency (better for debugging, isolates each validation layer)

### Example 1: Three-Step Validation (Manual Debugging Pattern)
```bash
# Step 1: Query only (check if data exists)
./query-loki.sh sovdev-test-company-lookup-python

# Step 2: Query + schema validation
./query-loki.sh sovdev-test-company-lookup-python --validate

# Step 3: Query + schema + consistency validation
./query-loki.sh sovdev-test-company-lookup-python --validate \
  --compare-with /workspace/python/test/e2e/company-lookup/logs/dev.log
```

### Example 2: Full Backend Validation - Combined Approach (Used by run-full-validation.sh)
```bash
# Validate all backends with combined flags (efficient - one query per backend)
LOG_FILE="/workspace/python/test/e2e/company-lookup/logs/dev.log"

./query-loki.sh sovdev-test-company-lookup-python --validate --compare-with "$LOG_FILE"
./query-prometheus.sh sovdev-test-company-lookup-python --validate --compare-with "$LOG_FILE"
./query-tempo.sh sovdev-test-company-lookup-python --validate --compare-with "$LOG_FILE"

# This is exactly what run-full-validation.sh does internally (direct backends)
# It also validates Grafana proxy queries the same way (see Example 3)
```

### Example 3: Grafana Proxy Validation - Combined Approach (Used by run-grafana-validation.sh)
```bash
# Validate Grafana can query all backends correctly (combined flags)
LOG_FILE="/workspace/typescript/test/e2e/company-lookup/logs/dev.log"

./query-grafana-loki.sh sovdev-test-company-lookup-typescript --validate --compare-with "$LOG_FILE"
./query-grafana-prometheus.sh sovdev-test-company-lookup-typescript --validate --compare-with "$LOG_FILE"
./query-grafana-tempo.sh sovdev-test-company-lookup-typescript --validate --compare-with "$LOG_FILE"

# This is exactly what run-grafana-validation.sh does internally
# Combined with Example 2, this is the complete run-full-validation.sh workflow
```

### Example 4: Collect Evidence for Verification Report
```bash
# Run test and save all validation results
./run-company-lookup.sh python

# Collect evidence from all backends (with validation)
mkdir -p evidence
./query-loki.sh sovdev-test-company-lookup-python --validate --json > evidence/loki-validated.json
./query-prometheus.sh sovdev-test-company-lookup-python --validate --json > evidence/prometheus-validated.json
./query-tempo.sh sovdev-test-company-lookup-python --validate --json > evidence/tempo-validated.json
```

### Example 5: Field Verification (Manual Extraction)
```bash
# Extract specific fields for compliance checking
./query-loki.sh sovdev-test-company-lookup-python --json | \
  jq '.data.result[0].stream | {timestamp, severity_text, service_name, session_id}'
```

### Example 6: Cross-Language Consistency Check
```bash
# Validate TypeScript and Python produce same format
mkdir -p validation-results
./validate-log-format.sh typescript/test/e2e/company-lookup/logs/dev.log --json > validation-results/typescript.json
./validate-log-format.sh python/test/e2e/company-lookup/logs/dev.log --json > validation-results/python.json

# Compare results
diff validation-results/typescript.json validation-results/python.json
```

---

## Integration with Validators

Query scripts have **built-in validation** via `--validate` and `--compare-with` flags. They automatically call Python validators when these flags are used:

```
┌─────────────────────────────────────────────────────────────────┐
│         Shell Script Tools (This Directory)                      │
│  query-loki.sh --validate --compare-with logs/dev.log           │
└─────────────┬───────────────────────────────────────────────────┘
              │
              ↓ (automatically calls validators)
┌─────────────────────────────────────────────────────────────────┐
│              Python Validators (specification/tests/)            │
│  validate-loki-response.py │ validate-loki-consistency.py       │
└─────────────┬───────────────────────────────────────────────────┘
              │
              ↓ (loads schemas)
┌─────────────────────────────────────────────────────────────────┐
│              JSON Schemas (specification/schemas/)               │
│  loki-response-schema.json │ log-entry-schema.json │ ...        │
└─────────────────────────────────────────────────────────────────┘
```

**Two Validation Approaches:**

**Approach 1: Built-in Validation (Recommended)**
```bash
# Query scripts handle everything automatically
./query-loki.sh sovdev-test-company-lookup-python --validate --compare-with logs/dev.log

# Internally this:
# 1. Queries Loki backend
# 2. Calls validate-loki-response.py (schema validation)
# 3. Calls validate-loki-consistency.py (consistency validation)
# 4. Reports results
```

**Approach 2: Manual Validation (Advanced)**
```bash
# Manual control over each step (for debugging or custom workflows)
./query-loki.sh sovdev-test-company-lookup-python --json > /tmp/loki-response.json
python3 ../tests/validate-loki-response.py /tmp/loki-response.json
python3 ../tests/validate-loki-consistency.py logs/dev.log /tmp/loki-response.json
```

**Validation workflow:**

1. **Tools query backends**: Fetch data from observability stack
2. **Tools call validators** (if --validate or --compare-with used): Pipe data to Python validators
3. **Validators load schemas**: JSON schemas define validation rules
4. **Results reported**: Validators output pass/fail with detailed error messages

**Complete pipeline example:**
```bash
# Automated: run-full-validation.sh calls query scripts with combined validation flags
./run-full-validation.sh python  # Runs ALL validation steps automatically

# Internally, this now uses combined flags for efficiency:
# - ./query-loki.sh SERVICE --validate --compare-with LOG_FILE
# - ./query-prometheus.sh SERVICE --validate --compare-with LOG_FILE
# - ./query-tempo.sh SERVICE --validate --compare-with LOG_FILE
# - ./query-grafana-loki.sh SERVICE --validate --compare-with LOG_FILE
# - ./query-grafana-prometheus.sh SERVICE --validate --compare-with LOG_FILE
# - ./query-grafana-tempo.sh SERVICE --validate --compare-with LOG_FILE
#
# This reduces total queries from 12 to 6 (50% reduction in query overhead)
```

**Related Documentation:**
- **Validators**: See `specification/tests/README.md` for Python validators that these tools call
- **Schemas**: See `specification/schemas/README.md` for JSON schemas that validators use

---


**Last Updated:** 2025-10-31
