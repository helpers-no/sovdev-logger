# Task 2: Verify TypeScript Baseline (and Environment)

**Parent task**: ROADMAP.md - Phase 0, Task 2
**Prerequisites**: Task 1 complete

---

## Purpose

**⚠️ CRITICAL:** Before implementing a new language, verify that:
1. You understand the working directory and network endpoints
2. The monitoring stack is operational
3. TypeScript reference implementation works

**Why this matters:** This prevents wasting time investigating SDK problems when the real issue is the monitoring stack or environment misconfiguration.

---

## Part A: Environment Understanding (MANDATORY)

### A.1 Understand DevContainer Architecture

Read and confirm your understanding:

- [ ] **Working directory:** `/workspace/`
- [ ] **OTLP endpoints:**
  - [ ] `http://host.docker.internal/v1/{logs,metrics,traces}` - OTLP export destination
  - [ ] Required header: `Host: otel.localhost` - For Traefik routing
- [ ] **Grafana access:**
  - [ ] `http://grafana.localhost` - Dashboard UI

**⛔ CRITICAL:** If you skip this understanding:
- OTLP exports will fail
- Network connectivity issues

**Checkpoint questions:**
1. What is your working directory? **/workspace/**
2. What Host header is required for OTLP? **otel.localhost**
3. What endpoint for OTLP exports? **host.docker.internal**

**If you cannot answer these correctly → Re-read specification/05-environment-configuration.md**

---

### A.2 Verify Understanding

- [ ] Read `specification/05-environment-configuration.md` completely
  - [ ] Understand environment setup
  - [ ] Understand network endpoints
  - [ ] Understand OTLP configuration
- [ ] Read `specification/tools/README.md` → Prerequisites section
  - [ ] Understand monitoring stack architecture
  - [ ] Understand validation tools

---

## Part B: Verify Monitoring Stack Works

### B.0 Understand TypeScript Reference Structure

**Purpose:** Understand the TypeScript implementation structure you'll replicate in Task 5.

**Key files to review:**
- [ ] `typescript/Makefile` - Standard targets (lint, lint-fix, build, test)
- [ ] `typescript/test/e2e/company-lookup/run-test.sh` - Runs E2E test
- [ ] `specification/tools/run-full-validation.sh` - Runs 7 automated validation steps

**Quick check:**
```bash
# View Makefile targets
cat typescript/Makefile
# See: lint, lint-fix, build, test

# View test script
cat typescript/test/e2e/company-lookup/run-test.sh
# See: Cleans logs/, runs npm start

# View validation script
cat specification/tools/run-full-validation.sh
# See: Runs 7-step validation sequence
```

**Why this matters:** In Task 5, you'll create the same structure for your language (Makefile with lint/build/test targets, run-test.sh script).

---

### B.1 Run TypeScript E2E Test

**Purpose:** Verify TypeScript reference implementation works

**Command:**
```bash
\1
```

**Expected result:**
- [ ] Test ran without errors
- [ ] Exit code 0
- [ ] Log files created in `typescript/test/e2e/company-lookup/logs/`

**Verification:**
```bash
# Check log file exists and has 17 entries
ls typescript/test/e2e/company-lookup/logs/dev.log
wc -l typescript/test/e2e/company-lookup/logs/dev.log
# Should show: 17
```

**If test fails:**
- ❌ TypeScript implementation broken → Report issue
- ❌ Node.js not available → Check environment setup
- ❌ Test script not found → Verify file exists and is executable

**Checklist:**
- [ ] TypeScript test ran successfully
- [ ] 17 log entries created
- [ ] No errors in output

---

### B.2 Run TypeScript Full Validation

**Purpose:** Verify monitoring stack (Loki, Prometheus, Tempo, Grafana) is operational

**Command:**
```bash
\1
```

**Expected result:** All 7 automated steps pass ✅

**Verify each step:**
- [ ] **Step 1:** File validation ✅ PASS
- [ ] **Step 2:** Logs in Loki ✅ PASS
- [ ] **Step 3:** Metrics in Prometheus ✅ PASS
- [ ] **Step 4:** Traces in Tempo ✅ PASS
- [ ] **Step 5:** Grafana-Loki connection ✅ PASS
- [ ] **Step 6:** Grafana-Prometheus connection ✅ PASS
- [ ] **Step 7:** Grafana-Tempo connection ✅ PASS

**If any step fails:**
- ❌ Monitoring stack not running → Check k3d cluster
- ❌ kubectl not configured → Use Grafana-based queries instead
- ❌ OTLP exports failing → Check Traefik routing

**Validation output:**
```
[Paste validation output showing all steps passing]
```

---

### B.3 Verify Grafana Dashboard (Step 8 - Manual)

**Purpose:** Visual verification that TypeScript data appears in dashboard

**Steps:**
1. [ ] Open browser to: http://grafana.localhost
2. [ ] Navigate to: Structured Logging Testing Dashboard
3. [ ] Verify **ALL 3 panels** show TypeScript data:

**Panel 1: Total Operations**
- [ ] TypeScript shows "Last" value (should be > 0)
- [ ] TypeScript shows "Max" value (should be > 0)

**Panel 2: Error Rate**
- [ ] TypeScript shows "Last %" value (should be ~11-12%)
- [ ] TypeScript shows "Max %" value (should be ~11-12%)

**Panel 3: Average Operation Duration**
- [ ] TypeScript shows entries for multiple peer services
- [ ] Values are in milliseconds (e.g., 0.538 ms, NOT 0.000538)

**Screenshot/Notes:**
```
[Describe what you see in the dashboard]
```

**If dashboard is empty:**
- Wait 30 seconds for data to appear
- Re-run TypeScript test
- Check that Grafana datasources are configured

**Checklist:**
- [ ] Grafana dashboard opened successfully
- [ ] ALL 3 panels show TypeScript data
- [ ] No panels are empty or showing errors

---

## Part C: Verify Validation Tools Understanding

### C.1 Understand Validation Sequence

- [ ] Read `specification/llm-work-templates/validation-sequence.md` completely
  - [ ] Understand 8-step validation sequence
  - [ ] Understand blocking points between steps
  - [ ] Understand why file validation comes FIRST (fast feedback)
  - [ ] Understand why OTLP validation comes SECOND (slow, infrastructure)
- [ ] Understand tool choice:
  - [ ] `query-loki.sh` - Direct access to Loki (kubectl required)
  - [ ] `query-grafana-loki.sh` - Access via Grafana API (always works)
  - [ ] Either tool is fine - use whichever is available

**Checkpoint questions:**
1. What's the first validation step? **File validation (instant)**
2. What's the last validation step? **Grafana dashboard (manual)**
3. Can you skip steps? **NO - blocking points**

---

## Success Criteria

**This task is complete when:**

- [ ] ✅ Part A: Environment understanding verified (endpoints, OTLP configuration)
- [ ] ✅ Part B.1: TypeScript E2E test passed (17 log entries)
- [ ] ✅ Part B.2: TypeScript full validation passed (all 7 steps)
- [ ] ✅ Part B.3: Grafana dashboard shows TypeScript data (all 3 panels)
- [ ] ✅ Part C: Validation sequence understood (8 steps, blocking points)

**Do NOT mark complete if:**
- ❌ TypeScript validation fails (fix monitoring stack first!)
- ❌ Grafana dashboard is empty (wait for data or re-run test)
- ❌ You don't understand environment configuration (read 05-environment-configuration.md)

---

## Common Issues

### Issue 1: "Command not found" when running test
**Cause:** Test script not found or not executable
**Solution:** Execute the test command:
```bash
cd /workspace/typescript/test/e2e/company-lookup && ./run-test.sh
```
If still failing, check that the test script exists and is executable.

### Issue 2: "Connection refused" to OTLP endpoint
**Cause:** Using wrong endpoint or missing Host header
**Solution:**
- Endpoint: `http://host.docker.internal/v1/logs`
- Header: `Host: otel.localhost` (required for Traefik routing)

### Issue 3: Grafana dashboard is empty
**Cause:** Data not yet propagated or test didn't run
**Solution:**
1. Wait 30 seconds for OTLP propagation
2. Re-run TypeScript test: `\1`
3. Refresh Grafana dashboard

### Issue 4: kubectl not working
**Cause:** kubectl not configured
**Solution:** Use Grafana-based validation tools instead:
- `query-grafana-loki.sh` instead of `query-loki.sh`
- `query-grafana-prometheus.sh` instead of `query-prometheus.sh`
- Both approaches are valid!

---

## Why This Task Matters

**If TypeScript validation fails:**
- ❌ Problem is with the **environment** (monitoring stack, network configuration)
- ❌ NOT a problem with your language implementation (you haven't started yet!)

**If you skip this task:**
- You might spend hours debugging OTLP exports in your language
- Only to discover the monitoring stack wasn't running
- This task saves you from that wasted time

**Bottom line:** Verify the infrastructure works BEFORE you write any code.

---

**Parent task**: Return to ROADMAP.md when complete
**Next task**: Task 3 - Research OTEL SDK for [LANGUAGE]
