# Task 12: Backend Validation

**Parent task**: ROADMAP.md - Phase 3, Task 12
**Prerequisites**: Task 11 complete (file validation passes)

---

## Purpose

Verify that telemetry data reaches all three backends (Loki, Prometheus, Tempo) AND appears correctly in Grafana dashboard.

**Critical**: This is the PROOF that your implementation works end-to-end.

**Complete validation documentation**: See `specification/tools/README.md` for detailed troubleshooting.

---

## Prerequisites Check

Before starting, verify:
- [ ] Task 11 complete (validate-log-format.sh passes)
- [ ] E2E test runs successfully
- [ ] Monitoring stack is accessible

**If ANY prerequisite missing → Go back and complete it first**

---

## Subtasks

### 12.1 Run E2E Test

Before validating backends, ensure fresh test data exists.

**Command**:
```bash
\1
```

**Expected**:
- [ ] Test exits successfully (exit code 0)
- [ ] Wait 10 seconds (allow OTLP data to propagate to backends)

**If test fails → Fix test before validating backends**

---

### 12.2 Run Automated Validation (Steps 1-7)

Run the complete automated validation sequence.

**Command**:
```bash
cd /workspace/specification/tools && ./run-full-validation.sh [LANGUAGE]
```

**Expected output**:
```
✅ Step 1: File validation PASS
✅ Step 2: Logs in Loki PASS (17 entries)
✅ Step 3: Metrics in Prometheus PASS (4 data points)
✅ Step 4: Traces in Tempo PASS (2 spans)
✅ Step 5: Grafana-Loki connection PASS
✅ Step 6: Grafana-Prometheus connection PASS
✅ Step 7: Grafana-Tempo connection PASS
```

**Checklist**:
- [ ] All 7 steps pass
- [ ] No errors in output
- [ ] Found 17 log entries
- [ ] Found 4 metrics
- [ ] Found 2 spans
- [ ] Labels use underscores (NOT dots)

**If any step fails**: See `specification/tools/README.md` → Complete 8-step validation sequence for detailed troubleshooting

**Common issues**:
- Missing `Host: otel.localhost` header → Step 2, 3, or 4 fails
- Dots in labels → Metrics validation warns about it
- OTLP exporter misconfigured → Backend steps fail

---

### 12.3 Manual Grafana Dashboard Verification (Step 8)

**CRITICAL**: Step 8 cannot be automated. You MUST visually verify Grafana dashboard.

**Open Grafana**:
- [ ] Navigate to: http://grafana.localhost
- [ ] Open dashboard: "Structured Logging Testing Dashboard"

**Verify ALL 3 Panels Show Data**:

**Panel 1: Total Operations**
- [ ] TypeScript shows values
- [ ] [LANGUAGE] shows values

**Panel 2: Error Rate**
- [ ] TypeScript shows ~11-12%
- [ ] [LANGUAGE] shows ~11-12%

**Panel 3: Average Operation Duration**
- [ ] TypeScript shows entries for all peer services
- [ ] [LANGUAGE] shows entries for all peer services
- [ ] Values are in milliseconds (e.g., 0.538 ms, NOT 0.000538)

**Test label filtering** (CRITICAL):
- [ ] Filter by `peer_service="cache"` → Should work
- [ ] Filter by `peer.service="cache"` → Should NOT work (dots fail)

**If any panel is empty**: See `specification/tools/README.md` → "Step 8: Verify Grafana Dashboard"

**If filtering doesn't work**: Labels have dots instead of underscores → Fix immediately

---

## Success Criteria

**This task is complete when**:

- [ ] All 3 subtasks checked off
- [ ] E2E test runs successfully (12.1)
- [ ] Automated validation passes all 7 steps (12.2)
- [ ] Grafana dashboard shows [LANGUAGE] data in ALL 3 panels (12.3)
- [ ] Label filtering works with underscores (12.3)
- [ ] No errors in any validation step

**Do NOT mark complete if**:
- ❌ Any of the 7 automated validation steps fails
- ❌ Grafana dashboard shows no data for [LANGUAGE]
- ❌ Metric filtering doesn't work (dots in labels)
- ❌ Missing logs, metrics, or traces in Grafana

---

## Common Pitfalls

### Pitfall 1: Not Waiting for Data
**Problem**: Running validation immediately after E2E test
**Impact**: Data hasn't propagated to backends yet (false negatives)
**Solution**: Wait 10 seconds after E2E test before running validation

### Pitfall 2: Dots in Labels
**Problem**: Labels use dots (peer.service) instead of underscores (peer_service)
**Impact**: Grafana filtering completely broken
**Solution**: Test filtering in step 12.3 - if fails, fix labels and re-run

### Pitfall 3: Skipping Grafana Visual Verification
**Problem**: Automated validation passes, assume Grafana works
**Impact**: Dashboard might not show data correctly
**Solution**: MUST complete step 12.3 manual verification

### Pitfall 4: Ignoring Failed Validation Steps
**Problem**: One validation step fails, but marking task complete anyway
**Impact**: Incomplete implementation
**Solution**: ALL 7 automated steps + Grafana verification must pass

---

## Validation

**Before marking complete, run**:

```bash
# Run complete automated validation
cd /workspace/specification/tools && ./run-full-validation.sh [LANGUAGE]
# Should show: All 7 steps pass ✅

# Verify Grafana is accessible
curl -s http://grafana.localhost/api/health | grep "ok"
# Should find "ok"
```

**Manual verification in Grafana**:
- [ ] All 3 panels show [LANGUAGE] data
- [ ] peer_service filter works (underscores)
- [ ] Dots in filter don't work (confirms underscores used)

**All checks must pass before claiming completion.**

---

## Troubleshooting

**For detailed troubleshooting**, see `specification/tools/README.md` → "Complete 8-Step Validation Sequence"

**Quick fixes for common issues**:

**Step 2 fails (Logs not in Loki)**:
- Check `Host: otel.localhost` header in OTLP logs exporter
- Check endpoint: `http://otel-collector:4318/v1/logs`

**Step 3 fails (Metrics not in Prometheus)**:
- Check `Host: otel.localhost` header in OTLP metrics exporter
- Verify labels use underscores (NOT dots)

**Step 4 fails (Traces not in Tempo)**:
- Check `Host: otel.localhost` header in OTLP traces exporter
- Verify startSpan() and endSpan() both called

**Grafana shows no data**:
- Wait 30 seconds, refresh Grafana
- Check time range set to "Last 1 hour"
- Re-run E2E test

---

## Reference Documents

**For detailed validation and troubleshooting**:
- **specification/tools/README.md**: Complete validation tool documentation (CRITICAL)
- **specification/llm-work-templates/validation-sequence.md**: 8-step validation sequence explained

**Supporting docs**:
- **specification/09-success-criteria.md**: Complete definition of success
- **specification/07-grafana-dashboard.md**: Dashboard structure and panels

---

## Next Steps

After completing this task:
- Implementation complete if all validations pass
- Update ROADMAP.md with completion status

**Parent task**: Return to ROADMAP.md when complete
