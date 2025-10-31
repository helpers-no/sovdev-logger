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
./in-devcontainer.sh -e "cd /workspace/typescript/test/e2e/company-lookup && ./run-test.sh"
./in-devcontainer.sh -e "cd /workspace/specification/tools && ./query-loki.sh sovdev-test-company-lookup-typescript"
./in-devcontainer.sh -e "cd /workspace/specification/tools && ./query-prometheus.sh sovdev-test-company-lookup-typescript"
./in-devcontainer.sh -e "cd /workspace/specification/tools && ./query-tempo.sh sovdev-test-company-lookup-typescript"
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

**See complete workflow**: `specification/09-development-loop.md` → "Validation-First Development" section

---

## Prerequisites

Before using these tools, ensure:

1. **DevContainer Toolbox is running:**
   ```bash
   docker ps | grep devcontainer-toolbox
   # Should show: devcontainer-toolbox
   ```

2. **Language implementation follows standard structure**:
   ```
   {language}/
   └── test/e2e/company-lookup/
       ├── run-test.sh    # Entry point (REQUIRED)
       ├── company-lookup.*
       ├── .env
       └── logs/
   ```

   **For complete project structure requirements**, see [`specification/06-test-scenarios.md`](../06-test-scenarios.md) → "Required Project Structure"

3. **Monitoring stack is running** (for Loki/Prometheus/Tempo queries):
   ```bash
   kubectl get pods -n monitoring
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

**You MUST follow these 8 steps in order.** Do NOT skip steps. Do NOT jump to Grafana (Step 8) unless Steps 1-7 all pass.

**Option 1: Automated (Recommended)**
```bash
# Run Steps 1-7 automatically
./in-devcontainer.sh run-full-validation {language}

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
./in-devcontainer.sh validate-log-format {language}/test/e2e/company-lookup/logs/dev.log
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

**Command:**
```bash
sleep 10  # Wait for OTLP propagation
./in-devcontainer.sh query-loki sovdev-test-company-lookup-{language} --json
```

**What it checks:**
- ✅ Logs exported via OTLP
- ✅ Loki received the logs
- ✅ Log count matches file logs

**Expected result:** Returns log entries (should see 17 entries)

**If FAIL:** 
- OTLP export not configured correctly
- Check `Host: otel.localhost` header
- Check OTLP endpoint URL

**⛔ DO NOT PROCEED to Step 3 until logs are in Loki**

---

### Step 3: Verify Metrics in Prometheus (OTLP → Prometheus) 🔄

**Tool:** `query-prometheus.sh`

**Purpose:** Check that metrics reached Prometheus backend

**Command:**
```bash
./in-devcontainer.sh query-prometheus 'sovdev_operations_total{service_name=~".*{language}.*"}' --json
```

**What it checks:**
- ✅ Metrics exported via OTLP
- ✅ Prometheus received the metrics
- ✅ Metric labels are correct (CRITICAL)

**Expected result:** Returns metrics with correct labels

**CRITICAL - Check labels:**
- ✅ `peer_service` (underscore, NOT peer.service)
- ✅ `log_type` (underscore, NOT log.type)
- ✅ `log_level` (underscore, NOT log.level)

**If FAIL:**
- Metrics not exported
- Check OTEL SDK metric configuration
- See `specification/llm-work-templates/research-otel-sdk-guide.md` for label issues

**⛔ DO NOT PROCEED to Step 4 until metrics are in Prometheus with correct labels**

---

### Step 4: Verify Traces in Tempo (OTLP → Tempo) 🔄

**Tool:** `query-tempo.sh`

**Purpose:** Check that traces reached Tempo backend

**Command:**
```bash
./in-devcontainer.sh query-tempo sovdev-test-company-lookup-{language} --json
```

**What it checks:**
- ✅ Traces exported via OTLP
- ✅ Tempo received the traces

**Expected result:** Returns trace data

**If FAIL:**
- Traces not exported
- Check OTEL SDK trace configuration

**⛔ DO NOT PROCEED to Step 5 until traces are in Tempo**

---

### Step 5: Verify Grafana-Loki Connection (Grafana → Loki) 🔄

**Tool:** `query-grafana-loki.sh`

**Purpose:** Check that Grafana can query Loki (not just that Loki has data)

**Command:**
```bash
./in-devcontainer.sh query-grafana-loki sovdev-test-company-lookup-{language} --json
```

**What it checks:**
- ✅ Grafana datasource configured for Loki
- ✅ Grafana can query Loki through proxy
- ✅ Same data returned as Step 2

**Expected result:** Returns log entries (same as Step 2, but through Grafana)

**If FAIL but Step 2 passed:**
- Grafana datasource misconfigured
- Check Grafana datasource settings

**⛔ DO NOT PROCEED to Step 6 until Grafana can query Loki**

---

### Step 6: Verify Grafana-Prometheus Connection (Grafana → Prometheus) 🔄

**Tool:** `query-grafana-prometheus.sh`

**Purpose:** Check that Grafana can query Prometheus (not just that Prometheus has data)

**Command:**
```bash
./in-devcontainer.sh query-grafana-prometheus 'sovdev_operations_total{service_name=~".*{language}.*"}' --json
```

**What it checks:**
- ✅ Grafana datasource configured for Prometheus
- ✅ Grafana can query Prometheus through proxy
- ✅ Same data returned as Step 3

**Expected result:** Returns metrics (same as Step 3, but through Grafana)

**If FAIL but Step 3 passed:**
- Grafana datasource misconfigured
- Check Grafana datasource settings

**⛔ DO NOT PROCEED to Step 7 until Grafana can query Prometheus**

---

### Step 7: Verify Grafana-Tempo Connection (Grafana → Tempo) 🔄

**Tool:** `query-grafana-tempo.sh`

**Purpose:** Check that Grafana can query Tempo (not just that Tempo has data)

**Command:**
```bash
./in-devcontainer.sh query-grafana-tempo sovdev-test-company-lookup-{language} --json
```

**What it checks:**
- ✅ Grafana datasource configured for Tempo
- ✅ Grafana can query Tempo through proxy
- ✅ Same data returned as Step 4

**Expected result:** Returns traces (same as Step 4, but through Grafana)

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
3. Verify ALL 3 panels show data

**What to check:**
- [ ] **Panel 1: Total Operations**
  - TypeScript shows "Last" and "Max" values
  - {language} shows "Last" and "Max" values

- [ ] **Panel 2: Error Rate**
  - TypeScript shows "Last %" and "Max %" values
  - {language} shows "Last %" and "Max %" values

- [ ] **Panel 3: Average Operation Duration**
  - TypeScript shows entries for all peer services
  - {language} shows entries for all peer services
  - Values in milliseconds (e.g., 0.538 ms, NOT 0.000538)

**If ANY panel is empty:**
- ⛔ Steps 1-7 didn't actually pass (even if script said they did)
- ⛔ Go back and run `run-full-validation.sh {language}` again
- ⛔ Manually verify each step if automated script passed but Grafana is empty
- ⛔ DO NOT claim "implementation complete"

**✅ VALIDATION COMPLETE when:**
1. All Steps 1-7 passed
2. ALL 3 Grafana panels show data for {language}
3. Data looks similar to TypeScript reference implementation

**Remember:** This is the FINAL step in the 8-step sequence. You cannot skip Steps 1-7 and jump here.

---

**Summary of 8-Step Validation Sequence:**
- Steps 1-7: Automated via `run-full-validation.sh` (or run manually for troubleshooting)
- Step 8: Manual visual check in Grafana (MUST do this even if Steps 1-7 pass)

---

## Quick Reference

**Core Principle:** All scripts run INSIDE the devcontainer (which has kubectl, language runtimes, and all tools).

Complete table of all verification tools:

| Script | Purpose | Inside Container | From Host | Where It Runs |
|--------|---------|------------------|-----------|---------------|
| [**run-company-lookup.sh**](run-company-lookup.sh) | Quick smoke test - run app and send to OTLP | `./run-company-lookup.sh python` | `./in-devcontainer.sh run-company-lookup python` | Devcontainer |
| [**run-full-validation.sh**](run-full-validation.sh) | **RECOMMENDED** - Complete E2E validation | `./run-full-validation.sh python` | `./in-devcontainer.sh run-full-validation python` | Devcontainer |
| [**run-grafana-validation.sh**](run-grafana-validation.sh) | Validate Grafana datasource queries only | `./run-grafana-validation.sh <service> <logfile>` | `./in-devcontainer.sh run-grafana-validation <service> <logfile>` | Devcontainer |
| [**query-loki.sh**](query-loki.sh) | Query Loki directly for service logs | `./query-loki.sh sovdev-test-company-lookup-python` | `./in-devcontainer.sh query-loki sovdev-test-company-lookup-python` | Devcontainer |
| [**query-prometheus.sh**](query-prometheus.sh) | Query Prometheus directly for service metrics | `./query-prometheus.sh sovdev-test-company-lookup-python` | `./in-devcontainer.sh query-prometheus sovdev-test-company-lookup-python` | Devcontainer |
| [**query-tempo.sh**](query-tempo.sh) | Query Tempo directly for service traces | `./query-tempo.sh sovdev-test-company-lookup-python` | `./in-devcontainer.sh query-tempo sovdev-test-company-lookup-python` | Devcontainer |
| [**query-grafana.sh**](query-grafana.sh) | Check Grafana datasource configuration | `./query-grafana.sh` | `./in-devcontainer.sh query-grafana` | Devcontainer |
| [**query-grafana-loki.sh**](query-grafana-loki.sh) | Query Loki THROUGH Grafana proxy | `./query-grafana-loki.sh sovdev-test-company-lookup-python` | `./in-devcontainer.sh query-grafana-loki sovdev-test-company-lookup-python` | Devcontainer |
| [**query-grafana-prometheus.sh**](query-grafana-prometheus.sh) | Query Prometheus THROUGH Grafana proxy | `./query-grafana-prometheus.sh sovdev-test-company-lookup-python` | `./in-devcontainer.sh query-grafana-prometheus sovdev-test-company-lookup-python` | Devcontainer |
| [**query-grafana-tempo.sh**](query-grafana-tempo.sh) | Query Tempo THROUGH Grafana proxy | `./query-grafana-tempo.sh sovdev-test-company-lookup-python` | `./in-devcontainer.sh query-grafana-tempo sovdev-test-company-lookup-python` | Devcontainer |
| [**validate-log-format.sh**](validate-log-format.sh) | Validate log file format against schema | `./validate-log-format.sh python/test/logs/dev.log` | `./in-devcontainer.sh validate-log-format python/test/logs/dev.log` | Devcontainer |
| [**in-devcontainer.sh**](in-devcontainer.sh) | Universal wrapper to run scripts from host | N/A | `./in-devcontainer.sh <script> [args]` | Host → Devcontainer |

**Aliases (shortcuts with in-devcontainer.sh):**
- `loki` → `query-loki.sh`
- `prometheus` / `prom` → `query-prometheus.sh`
- `tempo` → `query-tempo.sh`
- `grafana` → `query-grafana.sh`
- `validate` → `run-full-validation.sh`
- `validate-logs` → `validate-log-format.sh`
- `company-lookup` → `run-company-lookup.sh`

**Usage Examples:**

```bash
# From host machine (most common)
./in-devcontainer.sh validate python                         # Complete verification (alias)
./in-devcontainer.sh run-full-validation python              # Complete verification
./in-devcontainer.sh loki sovdev-test-company-lookup-python  # Query Loki (using alias)
./in-devcontainer.sh validate-logs python/test/logs/dev.log  # Validate logs (using alias)

# Inside devcontainer (if you're already in there)
./run-full-validation.sh python
./query-loki.sh sovdev-test-company-lookup-python
./validate-log-format.sh python/test/logs/dev.log

# Common workflow from host
./in-devcontainer.sh run-company-lookup python && \
./in-devcontainer.sh loki sovdev-test-company-lookup-python --json
```

---

## Validation Scripts Comparison

**Which script should I use?** This table shows what each validation and query script does:

### Validation Runner Scripts

| Script | Runs App | File Log Validation | Loki Schema validation | Loki compared to log file validation | Prometheus Schema validation | Prometheus compared to log file validation | Tempo Schema validation | Tempo compared to log file validation | Grafana Proxy | Use Case |
|--------|----------|---------------------|------------------------|--------------------------------------|------------------------------|--------------------------------------------| ------------------------|---------------------------------------|---------------|----------|
| **run-company-lookup.sh** | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | Quick smoke test - file logs only |
| **run-full-validation.sh** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | **RECOMMENDED** - Complete E2E validation |
| **run-grafana-validation.sh** | ❌ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | Grafana proxy validation only (logs must exist) |

**Validation Script Purposes:**
- **run-company-lookup.sh**: Quick smoke test - runs app, validates file logs only (no backend queries)
- **run-full-validation.sh**: Complete validation - file logs + all backends (direct + Grafana proxy)
- **run-grafana-validation.sh**: Grafana-only validation - assumes logs exist, only tests Grafana datasource queries

### Query Scripts (Direct Backend Access)

| Script | Queries Loki | Queries Prometheus | Queries Tempo | Queries Grafana | Validates Schema | Compares to Log File | Output Format | Use Case |
|--------|--------------|-------------------|---------------|-----------------|------------------|----------------------|---------------|----------|
| **query-loki.sh** | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | JSON/Text | Query Loki directly - returns raw response |
| **query-prometheus.sh** | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ | JSON/Text | Query Prometheus directly - returns raw response |
| **query-tempo.sh** | ❌ | ❌ | ✅ | ❌ | ❌ | ❌ | JSON/Text | Query Tempo directly - returns raw response |
| **query-grafana.sh** | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ | JSON/Text | Check Grafana datasource config |
| **query-grafana-loki.sh** | ✅ via Grafana | ❌ | ❌ | ✅ | ❌ | ❌ | JSON/Text | Query Loki through Grafana - returns raw response |
| **query-grafana-prometheus.sh** | ❌ | ✅ via Grafana | ❌ | ✅ | ❌ | ❌ | JSON/Text | Query Prometheus through Grafana - returns raw response |
| **query-grafana-tempo.sh** | ❌ | ❌ | ✅ via Grafana | ✅ | ❌ | ❌ | JSON/Text | Query Tempo through Grafana - returns raw response |

**Query Script Purposes:**
- **Query scripts DO NOT validate** - they only query backends and return raw responses
- **To validate responses**: Pipe query output to Python validators in `specification/tests/`
- **Direct query scripts** (query-loki.sh, query-prometheus.sh, query-tempo.sh): Query backends directly using kubectl port-forward
- **Grafana proxy scripts** (query-grafana-*.sh): Query backends through Grafana datasource proxy (tests Grafana integration)
- **query-grafana.sh**: Checks Grafana datasource configuration without querying data
- **Use `--json` flag** for JSON output (pipeable to validators or jq)

**Example - Manual Validation:**
```bash
# 1. Query Loki (returns raw response)
./query-loki.sh sovdev-test-company-lookup-python --json > /tmp/loki.json

# 2. Validate schema (manually pipe to validator)
python3 ../tests/validate-loki-response.py /tmp/loki.json

# 3. Compare to log file (manually pipe to validator)
python3 ../tests/validate-log-consistency.py logs/dev.log /tmp/loki.json
```

**Validation scripts DO this automatically** - `run-full-validation.sh` calls query scripts AND validators together

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

**For Development (Most Common - Use This!):**
```bash
# Use run-full-validation.sh or the "validate" alias
./in-devcontainer.sh validate typescript
# or
./in-devcontainer.sh run-full-validation typescript
```
- ✅ Validates file logs + all backends (Loki, Prometheus, Tempo)
- ✅ Schema + consistency validation (compares backend with log files)
- ✅ Validates Grafana datasource configuration
- ✅ Catches all implementation issues
- **This is what you want for complete validation**

**For Quick Smoke Test:**
```bash
# Use run-company-lookup.sh - just run the app
./in-devcontainer.sh run-company-lookup typescript
```
- No backend queries
- Just validates file log format
- Use when testing code changes locally (fast feedback)

**For Grafana-Only Testing:**
```bash
# Use run-grafana-validation.sh - validates Grafana queries only
./in-devcontainer.sh run-grafana-validation sovdev-test-company-lookup-typescript logs/dev.log
```
- Assumes app already ran and logs exist
- Only validates Grafana datasource queries
- Use when testing Grafana dashboard changes

---

## Composable Workflows

These tools can be combined for powerful verification workflows:

### Example 1: Quick end-to-end verification
```bash
# Run test, then verify all backends
./run-company-lookup.sh python && \
  ./query-loki.sh sovdev-test-company-lookup-python && \
  ./query-prometheus.sh sovdev-test-company-lookup-python && \
  ./query-tempo.sh sovdev-test-company-lookup-python
```

### Example 2: Collect evidence for verification report
```bash
# Run test and save all output
./run-company-lookup.sh python

# Collect evidence from all backends
mkdir -p evidence
./query-loki.sh sovdev-test-company-lookup-python --json > evidence/loki.json
./query-prometheus.sh sovdev-test-company-lookup-python --json > evidence/prometheus.json
./query-tempo.sh sovdev-test-company-lookup-python --json > evidence/tempo.json
```

### Example 3: Field verification
```bash
# Extract specific fields for compliance checking
./query-loki.sh sovdev-test-company-lookup-python --json | \
  jq '.data.result[0].stream | {timestamp, severity_text, service_name, session_id}'
```

### Example 4: Complete validation workflow
```bash
# Run test, validate log files, query backends
./run-company-lookup.sh python && \
  ./validate-log-format.sh python/test/e2e/company-lookup/logs/dev.log && \
  ./validate-log-format.sh python/test/e2e/company-lookup/logs/error.log --error-log && \
  ./query-loki.sh sovdev-test-company-lookup-python
```

### Example 5: Cross-language consistency check
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

These tools orchestrate the complete validation pipeline by calling validators and querying backends:

```
┌─────────────────────────────────────────────────────────────────┐
│         Shell Script Tools (This Directory)                      │
│  run-full-validation.sh │ query-loki.sh │ ...                   │
└─────────────┬───────────────────────────────────────────────────┘
              │
              ↓ (calls validators)
┌─────────────────────────────────────────────────────────────────┐
│              Python Validators (specification/tests/)            │
│  validate-log-format.py │ validate-loki-response.py │ ...       │
└─────────────┬───────────────────────────────────────────────────┘
              │
              ↓ (loads schemas)
┌─────────────────────────────────────────────────────────────────┐
│              JSON Schemas (specification/schemas/)               │
│  log-entry-schema.json │ loki-response-schema.json │ ...        │
└─────────────────────────────────────────────────────────────────┘
```

**Validation workflow:**

1. **Tools query backends**: `query-loki.sh`, `query-prometheus.sh`, `query-tempo.sh` fetch data from observability stack
2. **Tools call validators**: Response data piped to Python validators in `specification/tests/`
3. **Validators load schemas**: JSON schemas from `specification/schemas/` define validation rules
4. **Results reported**: Validators output pass/fail with detailed error messages

**Example: Full validation pipeline**
```bash
# 1. Tool runs test
./run-company-lookup.sh python

# 2. Tool queries Loki backend
./query-loki.sh sovdev-test-company-lookup-python --json > /tmp/loki-response.json

# 3. Tool calls validator (which loads schema)
python3 ../tests/validate-loki-response.py /tmp/loki-response.json

# All orchestrated by run-full-validation.sh
./run-full-validation.sh python  # Runs all steps automatically
```

**Related Documentation:**
- **Validators**: See `specification/tests/README.md` for Python validators that these tools call
- **Schemas**: See `specification/schemas/README.md` for JSON schemas that validators use

---


**Last Updated:** 2025-10-31
