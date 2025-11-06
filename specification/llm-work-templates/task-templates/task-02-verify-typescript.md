# Task 2: Verify TypeScript Baseline (and Environment)

**Parent task**: ROADMAP.md - Phase 0, Task 2
**Estimated time**: 10 minutes
**Prerequisites**: Task 1 complete

---

## Purpose

**⚠️ CRITICAL:** Before implementing a new language, verify that:
1. You understand the DevContainer environment
2. The monitoring stack is operational
3. TypeScript reference implementation works

**Why this matters:** This prevents wasting time investigating SDK problems when the real issue is the monitoring stack or environment misconfiguration.

---

## Part A: Environment Understanding (MANDATORY)

### A.1 Understand DevContainer Architecture

Read and confirm your understanding:

- [ ] **You are running inside a container** (not on your host machine)
- [ ] **All commands must use `in-devcontainer.sh` wrapper**
  - Correct: `./specification/tools/in-devcontainer.sh -e "command"`
  - Wrong: Running commands directly on host
- [ ] **Available endpoints:**
  - [ ] `host.docker.internal` - For OTLP exports from inside container
  - [ ] `otel.localhost` - Host header required for Traefik routing
  - [ ] `grafana.localhost` - Grafana UI access
- [ ] **Network architecture:**
  - [ ] DevContainer → host.docker.internal:80 → Traefik → Loki/Prometheus/Tempo
  - [ ] Browser → grafana.localhost → Grafana UI

**⛔ CRITICAL:** If you skip this understanding:
- You will encounter "command not found" errors
- You will encounter "connection refused" errors
- OTLP exports will fail

**Checkpoint questions:**
1. Can you run commands directly on your host? **NO**
2. What wrapper must you use? **in-devcontainer.sh**
3. What Host header is required for OTLP? **otel.localhost**

**If you cannot answer these correctly → Re-read specification/05-environment-configuration.md**

---

### A.2 Verify Understanding

- [ ] Read `specification/05-environment-configuration.md` completely
  - [ ] Understand Section 1: DevContainer Environment
  - [ ] Understand Section 2: Network Endpoints
  - [ ] Understand Section 3: Command Execution
- [ ] Read `specification/tools/README.md` → Prerequisites section
  - [ ] Understand DevContainer requirement
  - [ ] Understand monitoring stack architecture
- [ ] Confirmed: All test commands will use `in-devcontainer.sh -e "..."`

---

## Part B: Verify Monitoring Stack Works

### B.1 Run TypeScript E2E Test

**Purpose:** Verify TypeScript reference implementation works

**Command:**
```bash
./specification/tools/in-devcontainer.sh -e "cd /workspace/typescript/test/e2e/company-lookup && ./run-test.sh"
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
- ❌ DevContainer not running → Start DevContainer
- ❌ Node.js not installed → Check DevContainer setup

**Checklist:**
- [ ] TypeScript test ran successfully
- [ ] 17 log entries created
- [ ] No errors in output

---

### B.2 Run TypeScript Full Validation

**Purpose:** Verify monitoring stack (Loki, Prometheus, Tempo, Grafana) is operational

**Command:**
```bash
./specification/tools/in-devcontainer.sh -e "cd /workspace/specification/tools && ./run-full-validation.sh typescript"
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

- [ ] ✅ Part A: Environment understanding verified (DevContainer, endpoints, command wrapper)
- [ ] ✅ Part B.1: TypeScript E2E test passed (17 log entries)
- [ ] ✅ Part B.2: TypeScript full validation passed (all 7 steps)
- [ ] ✅ Part B.3: Grafana dashboard shows TypeScript data (all 3 panels)
- [ ] ✅ Part C: Validation sequence understood (8 steps, blocking points)

**Do NOT mark complete if:**
- ❌ TypeScript validation fails (fix monitoring stack first!)
- ❌ Grafana dashboard is empty (wait for data or re-run test)
- ❌ You don't understand DevContainer environment (read 05-environment-configuration.md)

---

## Common Issues

### Issue 1: "Command not found" when running test
**Cause:** Running command directly on host instead of in DevContainer
**Solution:** Always use `./specification/tools/in-devcontainer.sh -e "command"`

### Issue 2: "Connection refused" to OTLP endpoint
**Cause:** Using wrong endpoint or missing Host header
**Solution:**
- Endpoint: `http://host.docker.internal/v1/logs` (from inside container)
- Header: `Host: otel.localhost` (for Traefik routing)

### Issue 3: Grafana dashboard is empty
**Cause:** Data not yet propagated or test didn't run
**Solution:**
1. Wait 30 seconds for OTLP propagation
2. Re-run TypeScript test: `./specification/tools/in-devcontainer.sh -e "cd /workspace/typescript/test/e2e/company-lookup && ./run-test.sh"`
3. Refresh Grafana dashboard

### Issue 4: kubectl not working
**Cause:** kubectl not configured in DevContainer
**Solution:** Use Grafana-based validation tools instead:
- `query-grafana-loki.sh` instead of `query-loki.sh`
- `query-grafana-prometheus.sh` instead of `query-prometheus.sh`
- Both approaches are valid!

---

## Why This Task Matters

**If TypeScript validation fails:**
- ❌ Problem is with the **environment** (monitoring stack, DevContainer, network)
- ❌ NOT a problem with your language implementation (you haven't started yet!)

**If you skip this task:**
- You might spend hours debugging OTLP exports in your language
- Only to discover the monitoring stack wasn't running
- This task saves you from that wasted time

**Bottom line:** Verify the infrastructure works BEFORE you write any code.

---

## Time Estimate

- Part A: 3 minutes (read and understand)
- Part B.1: 2 minutes (run TypeScript test)
- Part B.2: 3 minutes (run validation)
- Part B.3: 2 minutes (check Grafana)
- Part C: 2 minutes (read validation sequence)

**Total**: ~10 minutes (could be longer if monitoring stack has issues)

---

**Parent task**: Return to ROADMAP.md when complete
**Next task**: Task 3 - Research OTEL SDK for [LANGUAGE]
