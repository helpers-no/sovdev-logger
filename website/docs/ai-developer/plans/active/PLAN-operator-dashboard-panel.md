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

### Tasks — DONE, with one honest limitation stated below

- [x] 2.1 Pushed `sovdev-logger-overview.json` to real UIS via `push-dashboard.ts` — from the host Mac, not the DevContainer (`GRAFANA_URL=http://grafana.localhost` resolves natively there; from inside the DevContainer this script has no way to send the `Host: grafana.localhost` header it needs, and 404s). Also hit and fixed the same esbuild-platform-mismatch bug seen elsewhere this session (`tools/dashboards/node_modules` had been installed for the wrong platform) — clean reinstall fixed it.
- [x] 2.2 Generated fresh real log data (`company-lookup` E2E test) and queried the panel's *exact* query through the *same datasource-proxy endpoint a rendered panel actually calls* (`/api/datasources/proxy/uid/loki/loki/api/v1/query`), with `$service_name`→`.+` and `$__range`→`15m` substituted to match the dashboard's real default time range (checked directly from the JSON's `time` field, not assumed). Result: `1` — correct.
- [x] 2.3 Confirmed `0` (not empty) for a service with zero tagged clients, through the same real proxy endpoint.
- [x] 2.4 Grafana Cloud is different, confirmed directly: `tools/dashboards/README.md` describes deployment there as a manual UI import (Dashboards → New → Import), and no Grafana Cloud *Grafana* API token exists anywhere in this repo's env files (only Loki/Prometheus/Tempo query tokens and an OTLP ingest token) — there's no credential this plan could use to push the dashboard itself. What I *could* and did verify: the query itself against real Grafana Cloud Loki data, using the existing `grafanaCloudQuery` helper. Caught my own mistake mid-check: my first zero-clients test on Grafana Cloud returned `0` from a service with *no data at all* in the window, not "real traffic, zero tagged" — not a genuine test of the same condition as UIS's. Fixed by actually running Python's Grafana Cloud E2E test to generate confirmed-real traffic first, then re-querying — genuinely confirmed `0` afterward, same as UIS.
- [x] 2.5 Confirmed `$service_name` narrows correctly — queried the exact TypeScript service name directly (not the `.+` wildcard) and got the same correct `1`.

- [x] 2.6 **(Maintainer)** Visually confirmed on the real, live UIS dashboard: "Active Clients" renders `1`, positioned exactly as designed — immediately right of "Active Integrations" (also `1`) on the top row, with "Total Operations (cumulative)" correctly narrowed alongside them. Closes the one gap this plan couldn't check itself (no browser access).

**Still open**: the Grafana Cloud variant hasn't been imported anywhere yet — no credential exists in this repo to do it programmatically, it's a manual UI import (Dashboards → New → Import) only the maintainer can do.

### Validation

Real query results through the actual rendering path on both real backends (UIS via datasource-proxy, Grafana Cloud via its own Loki query API), both conditions (clients present → `1`, zero tagged clients with confirmed-real underlying traffic → `0`), `$service_name` narrowing confirmed, **and now a real maintainer-confirmed visual check on the live UIS dashboard** — the panel looks exactly as designed. Only the Grafana Cloud import itself remains.

---

## Phase 3: Final checks

### Tasks

- [x] 3.1 Done in Phase 1 — `tools/dashboards/README.md` does document panels individually (a "Metrics" list), added "Active Clients" to it there rather than deferring.
- [x] 3.2 Confirmed no regression at the query-execution level: re-ran "Active Integrations"' own query through the same real datasource-proxy path after the dashboard edit — still returns a correct, sensible value (`1`, matching current test data), unaffected by the new panel's addition. **Not done**: an actual visual check of every panel rendered in a browser — no browser access; the `git diff` review (Phase 1) already confirmed no other panel's JSON changed at all, which is the strongest check available without one.

### Validation

Diff scoped to exactly: two dashboard JSON files (one new panel + one `gridPos` resize each) and `tools/dashboards/README.md`. Confirmed via `git diff` review, not just described.

---

## Acceptance Criteria

- [x] "Active Clients" panel exists on both dashboard variants, correct query, correct datasource UID per file.
- [x] Confirmed correct on both real backends — both the non-zero and zero-client cases — via the real query-execution path each backend actually uses (UIS's datasource-proxy, Grafana Cloud's own Loki query API). Not a literal browser screenshot; see Phase 2's stated limitation.
- [x] `$service_name` filtering confirmed working for this panel specifically.
- [x] No disruption to any existing panel — confirmed via `git diff` (nothing else changed) and a live re-check of "Active Integrations"' own query.

## Files to Modify

- `tools/dashboards/sovdev-logger-overview.json`
- `tools/dashboards/sovdev-logger-overview-grafana-cloud.json`
- `tools/dashboards/README.md` (if applicable, per 3.1)
