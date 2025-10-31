# Complete Validation Sequence for sovdev-logger

**Version:** 2.0.0
**Last Updated:** 2025-10-31
**Status:** Authoritative validation guide for all language implementations

---

## Purpose

This document defines the **8-step validation sequence** for verifying that a sovdev-logger implementation is complete and correct. This sequence ensures progressive confidence building with clear blocking points between steps.

**Target Audience:**
- LLM assistants implementing sovdev-logger
- Human developers validating implementations
- Anyone running validation tools

---

## Key Principles

1. **Follow the sequence exactly** - Don't skip steps or jump ahead
2. **Validate files FIRST** (instant feedback) - Then backends (slower)
3. **Stop at failures** - Fix issues before proceeding to next step
4. **Grafana is authoritative** - Step 8 is MANDATORY and cannot be automated

---

## Prerequisites

Before starting validation:

- ✅ Implementation complete (all 8 API functions implemented)
- ✅ E2E test created (company-lookup)
- ✅ Test has been run successfully
- ✅ DevContainer environment running
- ✅ Monitoring stack accessible (Loki, Prometheus, Tempo, Grafana)

**Read first:** `specification/tools/README.md` → "🔢 Validation Sequence (Step-by-Step)"

---

## The 8-Step Validation Sequence

**CRITICAL:** Follow these steps in order. Do NOT skip ahead. Each step validates a different layer of the telemetry pipeline.

### Step 1: Validate Log Files (INSTANT - 0 seconds) ⚡

**Purpose:** Check that log files on disk have correct format

**Tool:** `validate-log-format.sh`

**Command:**
```bash
./specification/tools/in-devcontainer.sh -e "cd /workspace/specification/tools && ./validate-log-format.sh {language}/test/e2e/company-lookup/logs/dev.log"
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

**Checklist:**
- [ ] Ran: `validate-log-format.sh {language}/test/e2e/company-lookup/logs/dev.log`
- [ ] Result: ✅ PASS / ❌ FAIL
- [ ] If FAIL: Issues fixed and re-validated

---

### Step 2: Verify Logs in Loki (OTLP → Loki) 🔄

**Purpose:** Check that logs reached Loki backend via OTLP

**Tool:** `query-loki.sh`

**Command:**
```bash
sleep 10  # Wait for OTLP propagation
./specification/tools/in-devcontainer.sh -e "cd /workspace/specification/tools && ./query-loki.sh sovdev-test-company-lookup-{language} --json"
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

**Checklist:**
- [ ] Ran: `query-loki.sh sovdev-test-company-lookup-{language}`
- [ ] Result: ✅ PASS (17 logs) / ❌ FAIL
- [ ] If FAIL: OTLP configuration fixed and re-validated

---

### Step 3: Verify Metrics in Prometheus (OTLP → Prometheus) 🔄

**Purpose:** Check that metrics reached Prometheus backend via OTLP

**Tool:** `query-prometheus.sh`

**Command:**
```bash
./specification/tools/in-devcontainer.sh -e "cd /workspace/specification/tools && ./query-prometheus.sh 'sovdev_operations_total{service_name=~\".*{language}.*\"}'"
```

**What it checks:**
- ✅ Metrics exported via OTLP
- ✅ Prometheus received the metrics
- ✅ Metric labels use underscores (NOT dots)
  - ✅ `peer_service` (underscore, NOT peer.service)
  - ✅ `log_type` (underscore, NOT log.type)
  - ✅ `log_level` (underscore, NOT log.level)

**Expected result:** Returns metric data with correct labels

**If FAIL:**
- Metrics not exported
- Check OTEL SDK metric configuration
- See `specification/llm-work-templates/research-otel-sdk-guide.md` for label issues

**⛔ DO NOT PROCEED to Step 4 until metrics are in Prometheus with correct labels**

**Checklist:**
- [ ] Ran: `query-prometheus.sh 'sovdev_operations_total{service_name=~".*{language}.*"}'`
- [ ] Result: ✅ PASS / ❌ FAIL
- [ ] Verified labels use underscores: ✅ YES / ❌ NO
- [ ] If FAIL: Metric configuration fixed and re-validated

---

### Step 4: Verify Traces in Tempo (OTLP → Tempo) 🔄

**Purpose:** Check that traces reached Tempo backend via OTLP

**Tool:** `query-tempo.sh`

**Command:**
```bash
./specification/tools/in-devcontainer.sh -e "cd /workspace/specification/tools && ./query-tempo.sh sovdev-test-company-lookup-{language}"
```

**What it checks:**
- ✅ Traces exported via OTLP
- ✅ Tempo received the traces
- ✅ Span data is present

**Expected result:** Returns trace/span data

**If FAIL:**
- Traces not exported
- Check OTEL SDK trace configuration

**⛔ DO NOT PROCEED to Step 5 until traces are in Tempo**

**Checklist:**
- [ ] Ran: `query-tempo.sh sovdev-test-company-lookup-{language}`
- [ ] Result: ✅ PASS / ❌ FAIL
- [ ] If FAIL: Trace configuration fixed and re-validated

---

### Step 5: Verify Grafana-Loki Connection (Grafana → Loki) 🔄

**Purpose:** Check that Grafana can query Loki datasource

**Tool:** `query-grafana-loki.sh`

**Command:**
```bash
./specification/tools/in-devcontainer.sh -e "cd /workspace/specification/tools && ./query-grafana-loki.sh sovdev-test-company-lookup-{language}"
```

**What it checks:**
- ✅ Grafana → Loki connection works
- ✅ Data flows from Loki to Grafana

**Expected result:** Returns log entries via Grafana API

**If FAIL:**
- Grafana datasource misconfigured
- Check Grafana datasource settings

**⛔ DO NOT PROCEED to Step 6 until Grafana can query Loki**

**Checklist:**
- [ ] Ran: `query-grafana-loki.sh sovdev-test-company-lookup-{language}`
- [ ] Result: ✅ PASS / ❌ FAIL
- [ ] If FAIL: Grafana-Loki connection fixed and re-validated

---

### Step 6: Verify Grafana-Prometheus Connection (Grafana → Prometheus) 🔄

**Purpose:** Check that Grafana can query Prometheus datasource

**Tool:** `query-grafana-prometheus.sh`

**Command:**
```bash
./specification/tools/in-devcontainer.sh -e "cd /workspace/specification/tools && ./query-grafana-prometheus.sh 'sovdev_operations_total{service_name=~\".*{language}.*\"}'"
```

**What it checks:**
- ✅ Grafana → Prometheus connection works
- ✅ Data flows from Prometheus to Grafana

**Expected result:** Returns metric data via Grafana API

**If FAIL:**
- Grafana datasource misconfigured
- Check Grafana datasource settings

**⛔ DO NOT PROCEED to Step 7 until Grafana can query Prometheus**

**Checklist:**
- [ ] Ran: `query-grafana-prometheus.sh 'sovdev_operations_total{...}'`
- [ ] Result: ✅ PASS / ❌ FAIL
- [ ] If FAIL: Grafana-Prometheus connection fixed and re-validated

---

### Step 7: Verify Grafana-Tempo Connection (Grafana → Tempo) 🔄

**Purpose:** Check that Grafana can query Tempo datasource

**Tool:** `query-grafana-tempo.sh`

**Command:**
```bash
./specification/tools/in-devcontainer.sh -e "cd /workspace/specification/tools && ./query-grafana-tempo.sh sovdev-test-company-lookup-{language}"
```

**What it checks:**
- ✅ Grafana → Tempo connection works
- ✅ Data flows from Tempo to Grafana

**Expected result:** Returns trace/span data via Grafana API

**If FAIL:**
- Grafana datasource misconfigured
- Check Grafana datasource settings

**⛔ DO NOT PROCEED to Step 8 until Grafana can query Tempo**

**Checklist:**
- [ ] Ran: `query-grafana-tempo.sh sovdev-test-company-lookup-{language}`
- [ ] Result: ✅ PASS / ❌ FAIL
- [ ] If FAIL: Grafana-Tempo connection fixed and re-validated

---

### Step 8: Verify Grafana Dashboard (Visual Verification) 👁️

**Purpose:** Visually verify that ALL data appears correctly in Grafana dashboard

**⚠️ THIS STEP CANNOT BE AUTOMATED - YOU MUST VERIFY VISUALLY**

**Manual Steps:**

1. **Open Grafana:**
   - Navigate to: http://grafana.localhost

2. **Open Dashboard:**
   - Navigate to: Structured Logging Testing Dashboard

3. **Verify ALL 3 Panels:**

**Panel 1: Total Operations**
- [ ] TypeScript shows "Last" value
- [ ] {LANGUAGE} shows "Last" value
- [ ] TypeScript shows "Max" value
- [ ] {LANGUAGE} shows "Max" value

**Panel 2: Error Rate**
- [ ] TypeScript shows "Last %" value
- [ ] {LANGUAGE} shows "Last %" value
- [ ] TypeScript shows "Max %" value
- [ ] {LANGUAGE} shows "Max %" value

**Panel 3: Average Operation Duration**
- [ ] TypeScript shows entries for all peer services
- [ ] {LANGUAGE} shows entries for all peer services
- [ ] Values are in milliseconds (e.g., 0.538 ms, NOT 0.000538)

**Result:**
- [ ] ✅ ALL panels show data for both languages
- [ ] ❌ Missing data in: [specify which panels/languages]

**Screenshot/Notes:**
```
[Describe what you see in the dashboard or attach screenshot]
```

**If FAIL:**
- Check that all previous steps passed
- Re-run test to generate fresh data
- Wait 30 seconds for dashboard to refresh
- Check metric labels (underscores vs dots)

**⛔ CANNOT CLAIM COMPLETE until ALL 3 panels show data for your language**

---

## Quick Validation (Automated Steps 1-7)

For convenience, you can run Steps 1-7 automatically:

**Command:**
```bash
./specification/tools/in-devcontainer.sh -e "cd /workspace/specification/tools && ./run-full-validation.sh {language}"
```

**This automates:**
- Step 1: File validation
- Steps 2-7: Backend and Grafana connection checks

**What it does NOT automate:**
- Step 8: Manual Grafana dashboard verification (REQUIRED!)

**Checklist:**
- [ ] Ran: `run-full-validation.sh {language}`
- [ ] All automated steps (1-7) passed: ✅ YES / ❌ NO

**Validation output:**
```
[Paste validation output from run-full-validation.sh]
```

---

## Metric Label Verification (Part of Step 3)

**Purpose:** Ensure metric labels match TypeScript exactly (underscores, not dots)

**Commands:**
```bash
# Query TypeScript metrics
./specification/tools/in-devcontainer.sh -e "cd /workspace/specification/tools && ./query-prometheus.sh 'sovdev_operations_total{service_name=~\".*typescript.*\"}' > ts.txt"

# Query language metrics
./specification/tools/in-devcontainer.sh -e "cd /workspace/specification/tools && ./query-prometheus.sh 'sovdev_operations_total{service_name=~\".*{language}.*\"}' > lang.txt"

# Compare
diff ts.txt lang.txt
```

**Expected labels:**
- ✅ `peer_service` (underscore)
- ✅ `log_type` (underscore)
- ✅ `log_level` (underscore)
- ✅ `service_name`
- ✅ `service_version`

**Checklist:**
- [ ] Queried TypeScript metrics
- [ ] Queried language metrics
- [ ] Compared labels
- [ ] Result: Labels IDENTICAL ✅ / Labels DIFFERENT ❌

**Label comparison result:**
```
[Paste diff output or confirm identical labels]
```

---

## Success Criteria

An implementation is **validated and complete** when:

1. ✅ **ALL 8 steps pass** (Steps 1-8 complete)
2. ✅ **Grafana dashboard shows data in ALL 3 panels** (Step 8 critical!)
3. ✅ **Metric labels match TypeScript exactly** (underscores, not dots)
4. ✅ **No errors or warnings in validation output**

**DO NOT claim complete until:**
- ALL checkboxes in all 8 steps are checked
- Grafana dashboard verification (Step 8) is complete with screenshot/notes
- Metric label comparison shows IDENTICAL results

---

## Common Issues

### Issue 1: Logs in Files but Not in Loki (Step 2 Fails)
**Symptom:** Step 1 passes, Step 2 fails
**Cause:** OTLP export not configured
**Fix:** Check `Host: otel.localhost` header in OTLP exporter config

### Issue 2: Metrics in Prometheus but Wrong Labels (Step 3 Fails)
**Symptom:** Metrics present but use dots instead of underscores
**Cause:** OTEL SDK using semantic conventions defaults
**Fix:** Explicitly set attribute names with underscores

### Issue 3: Grafana Dashboard Shows TypeScript but Not New Language (Step 8 Fails)
**Symptom:** Only TypeScript appears in dashboard panels
**Cause:** Service name mismatch or no data exported
**Fix:** Verify service name follows pattern `sovdev-test-company-lookup-{language}`

### Issue 4: Duration Values Wrong in Panel 3 (Step 8 Fails)
**Symptom:** Values show 0.000538 instead of 0.538 ms
**Cause:** Histogram unit not specified as "ms"
**Fix:** Set histogram unit to "ms" in OTEL SDK metric creation

---

## References

**Complete tool documentation:**
- **Primary guide:** `specification/tools/README.md`
- **Tool usage examples:** See "🔢 Validation Sequence" section
- **Debugging workflows:** See "Common Debugging Scenarios" section

**Related documentation:**
- **Development loop:** `specification/09-development-loop.md`
- **OTEL SDK issues:** `specification/llm-work-templates/research-otel-sdk-guide.md`
- **API requirements:** `specification/01-api-contract.md`

---

**Document Status:** ✅ v2.0.0 AUTHORITATIVE
**Last Updated:** 2025-10-31
**Part of:** sovdev-logger v2.0 systematic implementation system
