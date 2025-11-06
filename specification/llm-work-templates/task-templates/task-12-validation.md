# Task 12: Backend Validation

**Parent task**: ROADMAP.md - Phase 3, Task 12
**Estimated time**: 30 minutes
**Prerequisites**: Task 11 complete (file validation passes)

---

## Purpose

Verify that telemetry data reaches all three backends:
- **Loki**: Logs
- **Prometheus**: Metrics
- **Tempo**: Traces

AND verify data appears correctly in Grafana dashboard.

**Critical**: This is the PROOF that your implementation works end-to-end.

---

## Prerequisites Check

Before starting, verify:
- [ ] Task 11 complete (validate-log-format.sh passes)
- [ ] E2E test runs successfully
- [ ] DevContainer environment is running
- [ ] You have access to validation tools

**If ANY prerequisite missing → Go back and complete it first**

---

## Validation Tools

**Do NOT use kubectl directly**. Use provided validation tools:

```bash
./specification/tools/check-otel-backend.sh       # Backend checks
./specification/tools/validate-grafana.sh         # Grafana validation
./specification/tools/in-devcontainer.sh          # DevContainer wrapper
```

---

## Subtasks

### 12.1 Verify E2E Test Ran Recently

Before validating backends, ensure test data exists.

- [ ] Run E2E test: `./specification/tools/in-devcontainer.sh -e "cd /workspace/[LANGUAGE]/test/e2e/company-lookup && ./run-test.sh"`
- [ ] Verify test exits successfully (exit code 0)
- [ ] Wait 10 seconds (allow data to reach backends)

**Why**: Backends can only show data if test generated it

**Validation**:
```bash
# Test should exit 0
echo $?  # Should print: 0
```

**If test fails → Fix test before validating backends**

---

### 12.2 Check Logs in Loki

Verify logs reached Loki backend.

**Tool**: `check-otel-backend.sh` (runs inside DevContainer)

**Execution**:
```bash
./specification/tools/in-devcontainer.sh -e "./specification/tools/check-otel-backend.sh logs [LANGUAGE]"
```

**Expected output**:
```
✓ Loki is reachable
✓ Found logs for [LANGUAGE]-logger
✓ Found 17 log entries
✓ Log levels: INFO, WARN
✓ Service name: [LANGUAGE]-logger
```

**Checklist**:
- [ ] Run check-otel-backend.sh logs [LANGUAGE]
- [ ] All checks pass (✓ symbols)
- [ ] Found 17 log entries (matches E2E test)
- [ ] No errors reported

**If check fails**:
1. Check OTLP logs exporter configuration
2. Verify `Host: otel.localhost` header present
3. Check otel-collector logs: `kubectl logs -n otel deploy/otel-collector`
4. Check Loki logs: `kubectl logs -n loki deploy/loki`
5. Fix issues and re-run E2E test

**Common issues**:
- Missing `Host` header → Traefik routing fails
- Wrong endpoint URL → Exporter sends to wrong place
- Network issues → Check DevContainer networking

---

### 12.3 Check Metrics in Prometheus

Verify metrics reached Prometheus backend.

**Tool**: `check-otel-backend.sh` (runs inside DevContainer)

**Execution**:
```bash
./specification/tools/in-devcontainer.sh -e "./specification/tools/check-otel-backend.sh metrics [LANGUAGE]"
```

**Expected output**:
```
✓ Prometheus is reachable
✓ Found metric: peer_service_duration
✓ Found labels: peer_service, operation_name
✓ Label values use underscores (not dots)
✓ Found 4 data points
  - peer_service=cache, operation_name=lookup (15ms)
  - peer_service=cache, operation_name=update (5ms)
  - peer_service=database, operation_name=query (45ms)
  - peer_service=analytics, operation_name=event (10ms)
✓ Service name: [LANGUAGE]-logger
```

**Checklist**:
- [ ] Run check-otel-backend.sh metrics [LANGUAGE]
- [ ] All checks pass (✓ symbols)
- [ ] Found peer_service_duration metric
- [ ] Found 4 data points (cache:lookup, cache:update, db:query, analytics:event)
- [ ] Labels use underscores (peer_service, operation_name)
- [ ] No dots in label names

**If check fails**:
1. Check OTLP metrics exporter configuration
2. Verify `Host: otel.localhost` header present
3. Verify recordPeerService() uses underscores
4. Check metric name: "peer_service_duration"
5. Check otel-collector logs
6. Fix issues and re-run E2E test

**Common issues**:
- Dots in labels → Grafana filtering breaks
- Wrong metric name → Prometheus can't find it
- Missing header → Routing fails
- No recordPeerService() calls → No data

**CRITICAL**: If labels have dots → Fix immediately. This breaks Grafana.

---

### 12.4 Check Traces in Tempo

Verify traces reached Tempo backend.

**Tool**: `check-otel-backend.sh` (runs inside DevContainer)

**Execution**:
```bash
./specification/tools/in-devcontainer.sh -e "./specification/tools/check-otel-backend.sh traces [LANGUAGE]"
```

**Expected output**:
```
✓ Tempo is reachable
✓ Found traces for [LANGUAGE]-logger
✓ Found 2 spans:
  - cache_lookup (peer_service=cache)
  - db_query (peer_service=database)
✓ Span attributes use underscores
✓ Service name: [LANGUAGE]-logger
```

**Checklist**:
- [ ] Run check-otel-backend.sh traces [LANGUAGE]
- [ ] All checks pass (✓ symbols)
- [ ] Found 2 spans (cache_lookup, db_query)
- [ ] Span attributes use underscores

**If check fails**:
1. Check OTLP traces exporter configuration
2. Verify `Host: otel.localhost` header present
3. Verify startSpan() and endSpan() called
4. Check span names: "cache_lookup", "db_query"
5. Check otel-collector logs
6. Fix issues and re-run E2E test

**Common issues**:
- Missing header → Routing fails
- startSpan() without endSpan() → Incomplete traces
- Wrong span names → Can't find expected spans
- Dots in attributes → Breaks Grafana

---

### 12.5 Open Grafana Dashboard

Access Grafana UI to visually verify data.

**URL**: http://grafana.localhost

**Steps**:
- [ ] Open browser to http://grafana.localhost
- [ ] Navigate to Dashboards
- [ ] Open "sovdev-logger Multi-Language Dashboard"
- [ ] Confirm dashboard loads without errors

**If dashboard doesn't load**:
- Check DevContainer is running
- Check Grafana is deployed: `kubectl get pods -n grafana`
- Check Traefik routing: `kubectl get ingressroute -A`

---

### 12.6 Verify Logs Panel (Grafana)

Check that logs panel shows [LANGUAGE] data.

**Panel**: "Application Logs by Language"

**Steps**:
- [ ] Find "Application Logs by Language" panel
- [ ] Select language filter: [LANGUAGE]
- [ ] Verify logs appear
- [ ] Verify 17 log entries visible
- [ ] Check log levels (INFO, WARN)
- [ ] Check service name: [LANGUAGE]-logger

**Expected**:
- Log entries match E2E test output
- Timestamps are recent (within last hour)
- Filtering by language works

**If no logs**:
- Re-run E2E test
- Wait 30 seconds
- Refresh Grafana
- Check Loki data source connection

---

### 12.7 Verify Metrics Panel (Grafana)

Check that metrics panel shows [LANGUAGE] data.

**Panel**: "Peer Service Duration by Language"

**Steps**:
- [ ] Find "Peer Service Duration by Language" panel
- [ ] Select language filter: [LANGUAGE]
- [ ] Verify metric data appears
- [ ] Check peer_service labels:
  - cache
  - database
  - analytics
- [ ] Check operation_name labels:
  - lookup
  - update
  - query
  - event
- [ ] Verify label filtering works

**Expected**:
- 4 distinct metric time series
- Durations match E2E test (15ms, 5ms, 45ms, 10ms)
- Filtering by peer_service works
- Filtering by operation_name works

**If no metrics**:
- Check Prometheus has data (step 12.3)
- Verify labels use underscores (not dots)
- Check Prometheus data source connection
- Re-run E2E test if needed

**CRITICAL TEST**: Try filtering by `peer_service="cache"`
- If filter works → Labels correct (underscores)
- If filter fails → Labels wrong (dots) → FIX IMMEDIATELY

---

### 12.8 Verify Traces Panel (Grafana)

Check that traces panel shows [LANGUAGE] data.

**Panel**: "Service Traces by Language"

**Steps**:
- [ ] Find "Service Traces by Language" panel
- [ ] Select language filter: [LANGUAGE]
- [ ] Verify traces appear
- [ ] Check 2 spans visible:
  - cache_lookup
  - db_query
- [ ] Click on a trace to view details
- [ ] Verify span attributes include:
  - peer_service
  - operation_name
- [ ] Verify attributes use underscores

**Expected**:
- 2 spans visible in trace timeline
- Spans have correct names
- Attributes use underscores
- Durations match expectations

**If no traces**:
- Check Tempo has data (step 12.4)
- Check Tempo data source connection
- Re-run E2E test if needed

---

### 12.9 Compare with TypeScript Reference

Validate that [LANGUAGE] data matches TypeScript (the reference implementation).

**Steps**:
- [ ] Run TypeScript E2E test: `./specification/tools/in-devcontainer.sh -e "cd /workspace/typescript/test/e2e/company-lookup && ./run-test.sh"`
- [ ] Wait 10 seconds
- [ ] In Grafana, select both TypeScript and [LANGUAGE] in language filter
- [ ] Compare logs panel: Same messages?
- [ ] Compare metrics panel: Same peer services?
- [ ] Compare traces panel: Same span structure?

**Expected**:
- Both show 17 log entries
- Both show 4 metrics (cache:lookup, cache:update, database:query, analytics:event)
- Both show 2 spans (cache_lookup, db_query)
- Data structure is identical (only language label differs)

**If different**:
- [LANGUAGE] is wrong (TypeScript is the reference)
- Check if [LANGUAGE] is missing data
- Check if log messages differ
- Check if metric/span names differ
- Fix [LANGUAGE] to match TypeScript

---

### 12.10 Test Metric Label Filtering

**Critical test**: Verify underscore labels enable filtering.

**Steps in Grafana**:
- [ ] Go to "Explore" tab
- [ ] Select Prometheus data source
- [ ] Query: `peer_service_duration{peer_service="cache"}`
- [ ] Run query
- [ ] Verify results found

**Then test with dots** (should fail):
- [ ] Query: `peer_service_duration{peer.service="cache"}`
- [ ] Run query
- [ ] Verify NO results (dots don't work)

**Expected**:
- Underscores work: Results found
- Dots don't work: No results

**If underscores don't work**:
- Your labels still have dots
- Fix recordPeerService() implementation
- Fix startSpan() attributes
- Re-run E2E test
- Validate again

**This is CRITICAL**: Grafana filtering depends on underscores.

---

## Success Criteria

**This task is complete when**:

- [ ] All 10 subtasks checked off
- [ ] E2E test runs successfully
- [ ] check-otel-backend.sh passes for logs
- [ ] check-otel-backend.sh passes for metrics
- [ ] check-otel-backend.sh passes for traces
- [ ] Grafana dashboard shows [LANGUAGE] data in ALL panels:
  - [ ] Logs panel
  - [ ] Metrics panel
  - [ ] Traces panel
- [ ] Metric label filtering works (underscores)
- [ ] Comparison with TypeScript reference shows identical output
- [ ] No errors in any validation step

**Do NOT mark complete if**:
- ❌ Any backend check fails
- ❌ Grafana dashboard shows no data
- ❌ Metric filtering doesn't work (dots problem)
- ❌ Data doesn't match TypeScript reference
- ❌ Missing logs, metrics, or traces

---

## Common Pitfalls

### Pitfall 1: Skipping Validation Tools
**Problem**: Using kubectl instead of check-otel-backend.sh
**Impact**: Missing validation steps, false confidence
**Solution**: ALWAYS use provided validation tools

### Pitfall 2: Not Waiting for Data
**Problem**: Checking backends immediately after test
**Impact**: Data hasn't propagated yet, false negatives
**Solution**: Wait 10 seconds after E2E test before validating

### Pitfall 3: Dots in Labels (Still!)
**Problem**: Even after warnings, labels still have dots
**Impact**: Grafana filtering completely broken
**Solution**: Test filtering explicitly (step 12.10), fix if fails

### Pitfall 4: Claiming Success Without Grafana Check
**Problem**: Backend checks pass, but Grafana doesn't show data
**Impact**: Integration incomplete
**Solution**: MUST verify Grafana dashboard (steps 12.6-12.8)

### Pitfall 5: Not Comparing with TypeScript
**Problem**: Don't know if [LANGUAGE] behaves same as reference
**Impact**: Subtle differences go unnoticed
**Solution**: Side-by-side comparison is mandatory (step 12.9)

### Pitfall 6: Ignoring Failed Checks
**Problem**: One check fails, but moving on anyway
**Impact**: Incomplete implementation
**Solution**: ALL checks must pass before claiming complete

---

## Validation

**Before marking complete, verify**:

```bash
# All backend checks pass (run inside DevContainer)
./specification/tools/in-devcontainer.sh -e "./specification/tools/check-otel-backend.sh logs [LANGUAGE]"
# Should exit 0

./specification/tools/in-devcontainer.sh -e "./specification/tools/check-otel-backend.sh metrics [LANGUAGE]"
# Should exit 0

./specification/tools/in-devcontainer.sh -e "./specification/tools/check-otel-backend.sh traces [LANGUAGE]"
# Should exit 0

# Grafana is accessible
curl -s http://grafana.localhost/api/health | grep -q "ok"
# Should find "ok"
```

**Manual checks in Grafana**:
- [ ] All 3 panels show [LANGUAGE] data
- [ ] Language filter works
- [ ] peer_service filter works
- [ ] operation_name filter works

**All checks must pass before claiming completion.**

---

## Troubleshooting Guide

### Issue: No Logs in Loki

**Symptoms**: check-otel-backend.sh logs fails

**Debug steps**:
1. Check OTLP logs exporter has `Host: otel.localhost` header
2. Run: `kubectl logs -n otel deploy/otel-collector | grep error`
3. Check endpoint: Should be `http://otel-collector:4318/v1/logs`
4. Verify E2E test actually ran
5. Check logs directory locally: `ls logs/`

**Fix**: Update exporter config, re-run test

---

### Issue: No Metrics in Prometheus

**Symptoms**: check-otel-backend.sh metrics fails

**Debug steps**:
1. Check OTLP metrics exporter has `Host: otel.localhost` header
2. Verify recordPeerService() was called 4 times
3. Check metric name: "peer_service_duration"
4. Run: `kubectl logs -n otel deploy/otel-collector | grep metrics`
5. Check Prometheus: `curl http://prometheus.localhost/api/v1/query?query=peer_service_duration`

**Fix**: Update exporter config, fix recordPeerService calls, re-run test

---

### Issue: No Traces in Tempo

**Symptoms**: check-otel-backend.sh traces fails

**Debug steps**:
1. Check OTLP traces exporter has `Host: otel.localhost` header
2. Verify startSpan() and endSpan() were called
3. Check span names: "cache_lookup", "db_query"
4. Run: `kubectl logs -n otel deploy/otel-collector | grep trace`

**Fix**: Update exporter config, fix span creation, re-run test

---

### Issue: Grafana Shows No Data

**Symptoms**: Backend checks pass, but Grafana panels empty

**Debug steps**:
1. Check data source connections in Grafana
2. Verify time range is recent (last 1 hour)
3. Check language filter is set correctly
4. Try "Explore" tab with manual query
5. Check browser console for errors

**Fix**: Refresh Grafana, adjust time range, check data sources

---

### Issue: Metric Filtering Doesn't Work

**Symptoms**: Can't filter by peer_service="cache"

**Debug steps**:
1. Check if labels have dots instead of underscores
2. Run: `grep -r "peer\.service" [LANGUAGE]/`
3. Check recordPeerService() implementation
4. Check startSpan() attributes

**Fix**: Change dots to underscores, re-run test, validate again

**This is the #1 bug from C# implementation - don't repeat it!**

---

## Reference Documents

- **specification/09-success-criteria.md**: Complete definition of success
- **specification/06-otel-backend-config.md**: Backend endpoints and configuration
- **specification/07-grafana-dashboard.md**: Dashboard structure and panels

---

## Time Estimate

- Subtask 12.1: 2 minutes (run E2E test)
- Subtask 12.2: 3 minutes (check Loki)
- Subtask 12.3: 3 minutes (check Prometheus)
- Subtask 12.4: 3 minutes (check Tempo)
- Subtask 12.5: 2 minutes (open Grafana)
- Subtask 12.6: 3 minutes (verify logs panel)
- Subtask 12.7: 5 minutes (verify metrics panel)
- Subtask 12.8: 3 minutes (verify traces panel)
- Subtask 12.9: 5 minutes (compare with TypeScript)
- Subtask 12.10: 3 minutes (test filtering)

**Total**: ~30 minutes (if everything works)

**If issues found**: +1-2 hours debugging

---

## Next Steps

After completing this task:
- Task 13: Grafana visual verification (final check)
- Claim implementation complete if all validations pass

**Parent task**: Return to ROADMAP.md when complete
