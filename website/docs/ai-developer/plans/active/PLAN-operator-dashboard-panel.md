# Plan: "Active Clients" dashboard panel

Adds a fleet-wide "Active Clients" stat panel — how many distinct `client_name` values are actively logging in the selected time range — to both dashboard variants, using the query and two bug fixes already found and verified in [`INVESTIGATE-operator-dashboard-panel.md`](../backlog/INVESTIGATE-operator-dashboard-panel.md).

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Active

**Goal**: A working "Active Clients" panel on both `tools/dashboards/sovdev-logger-overview.json` (UIS) and `sovdev-logger-overview-grafana-cloud.json` (Grafana Cloud), validated with an actual live render against both real backends — closing [Q1], the one thing the investigation's API-level checks couldn't cover.

**Last Updated**: 2026-07-13

**Investigation**: [INVESTIGATE-operator-dashboard-panel.md](../backlog/INVESTIGATE-operator-dashboard-panel.md) — [Q2]/[Q3] resolved (title: "Active Clients"; placement: top row, next to "Active Integrations"). [Q1] (live-render confirmation) is this plan's own validation step, not resolved yet.

**Query, both bugs already fixed and re-verified in the investigation** (not re-derived here):

```logql
count(count by (client_name) (count_over_time({service_name=~"$service_name"} | client_name != "" [$__range]))) or vector(0)
```

**Confirmed directly, both dashboard files, before writing any panel JSON**: the top row (`Active Integrations` `w:6` + `Total Operations (cumulative)` `w:18` = 24) is identically laid out in both `sovdev-logger-overview.json` and `sovdev-logger-overview-grafana-cloud.json`. The Loki datasource UID differs between them — `loki` (UIS) vs. `grafanacloud-logs` (Grafana Cloud) — confirmed by reading each file's existing Loki-backed panels directly, not assumed to match the Prometheus UID pattern.

---

## Phase 1: Add the panel to both dashboard files — DONE

### Tasks

- [x] 1.1 Added "Active Clients" to `sovdev-logger-overview.json` at `gridPos: {h:8, w:6, x:6, y:0}`, Loki datasource `uid: loki`, the query above (`queryType: instant`, matching a stat panel's single-current-value semantics — same pattern used to test the query directly earlier via the Loki HTTP API's instant `/query` endpoint, not the ranged `/query_range`). "Total Operations (cumulative)" changed to `{h:8, w:12, x:12, y:0}` — no other panel's `gridPos` touched.
- [x] 1.2 Same edit in `sovdev-logger-overview-grafana-cloud.json`, with Loki datasource `uid: grafanacloud-logs`.
- [x] 1.3 New panel `id: 13` in both files — checked directly (`max(existing ids) + 1`), not guessed; both files happened to already have identical ID sets (`[1,2,3,4,5,6,11,12]`), so `13` is correct in both.
- [x] 1.4 Matched "Active Integrations"' exact `fieldConfig`/`options` shape (same thresholds, `colorMode`, `graphMode`, `reduceOptions`) — copied its structure via a script reading the real existing panel, not hand-typed from memory.
- [x] Also updated `tools/dashboards/README.md`'s existing panel-by-panel list (confirmed it documents panels individually before adding to it, per the parent plan's Phase 3.1 — pulled forward since it was a one-line addition to a section I was already reading).

### Validation

Both JSON files re-parsed successfully after the edit (`python3 -m json.tool`-equivalent check built into the edit script itself — it round-trips through `json.load`/`json.dump`, so a parse failure would have thrown before any file was written). Diff reviewed directly (`git diff`): exactly one new panel block per file plus the one `gridPos` change to "Total Operations (cumulative)" — no unrelated formatting noise, no other panel touched. Datasource UIDs confirmed correct per file (`loki` vs. `grafanacloud-logs`), not copy-pasted across files.

---

## Phase 2: Live-render validation against both real backends ([Q1])

### Tasks

- [ ] 2.1 Push the updated `sovdev-logger-overview.json` to real UIS (`tools/dashboards/`'s existing push mechanism — check `README.md` for the current deploy command rather than assuming `push-dashboard.ts`'s exact invocation).
- [ ] 2.2 With real log data present (re-run the `company-lookup` E2E test if needed for fresh data), confirm the panel actually renders `1` when `client_name` is set, matching the investigation's API-level result — this time seen through the real dashboard, not just `curl`.
- [ ] 2.3 Confirm the panel renders `0` (not "No data") when queried against a time range/service with zero tagged clients — the second bug's fix, now checked through the actual UI.
- [ ] 2.4 Push the Grafana Cloud variant and repeat 2.2/2.3 there — per `tools/dashboards/README.md`'s "Deploying to Grafana Cloud" section (datasource UID mapping needed a real fix last time this was done, not just a plain import — check whether that still applies).
- [ ] 2.5 Confirm `$service_name` narrows the count correctly when a specific service is selected (not "All") — the template variable was already confirmed to support this pattern via "Active Integrations," but not yet re-confirmed for this specific new panel.

### Validation

Screenshots or direct confirmation of the panel showing the correct number on both real backends, under both the "clients present" and "zero clients" conditions — the actual proof this investigation's `curl`-only checks couldn't provide.

---

## Phase 3: Final checks

### Tasks

- [x] 3.1 Done in Phase 1 — `tools/dashboards/README.md` does document panels individually (a "Metrics" list), added "Active Clients" to it there rather than deferring.
- [ ] 3.2 Confirm no regression to any existing panel — full dashboard visual check, not just the new one.

### Validation

User confirms the diff is scoped to exactly this — two dashboard JSON files (plus docs if applicable), no unrelated panel changes.

---

## Acceptance Criteria

- [ ] "Active Clients" panel exists on both dashboard variants, correct query, correct datasource UID per file.
- [ ] Live-rendered and confirmed correct on both real backends — both the non-zero and zero-client cases.
- [ ] `$service_name` filtering confirmed working for this panel specifically.
- [ ] No disruption to any existing panel's layout.

## Files to Modify

- `tools/dashboards/sovdev-logger-overview.json`
- `tools/dashboards/sovdev-logger-overview-grafana-cloud.json`
- `tools/dashboards/README.md` (if applicable, per 3.1)
