# Investigate: "Active Clients" dashboard panel for the operator persona

A dashboard panel showing how many distinct frontends/clients (via `client_name`) are actively logging across the fleet — for the operator persona managing all APIs and all registered clients, distinct from a single API's own maintainer. First raised right after `client_name` shipped in `PLAN-context-propagation.md`; this investigation replaces an earlier informal spot-check in `1PRIORITY.md`'s Tier 5 notes that turned out to be incomplete — re-verifying it against realistic data found two real bugs the original check missed entirely.

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Backlog

**Goal**: A correct, dashboard-ready LogQL query and panel definition for "how many distinct clients are actively logging," validated against realistic data (present *and* absent `client_name`), not just a clean happy-path case.

**Last Updated**: 2026-07-13

**Why this needed re-investigating, not just re-confirming**: the original check (noted in `1PRIORITY.md`'s Tier 5) tested `count(count by (client_name) (count_over_time({service_name=~".+"}[10m])))` against test data where every single log line had `client_name` set, and called it "confirmed feasible." That's not what real data looks like — `client_name` is optional, and most log lines (system/internal logging, services that never call `sovdev_set_context()`, Python's E2E test which doesn't support the field at all yet) never set it. Once tested against this session's actual accumulated UIS data — a realistic mix of tagged and untagged log lines — the same query returned `2` instead of the correct `1`. A validation that only holds on cherry-picked data isn't a validation.

---

## What was actually tested (all against real, live UIS data — not assumed, not mocked)

### Bug 1: naive count treats "no client set" as a distinct client

`count(count by (client_name) (count_over_time({service_name=~".+"}[6h])))` against this session's real mixed data (21,648 log lines with no `client_name`, 119 with `client_name="company-lookup-e2e-client"`) returns:

```
[{"metric": {}, "value": [..., "2"]}]
```

**Wrong** — there is exactly one distinct client, not two. The inner `count by (client_name)` produces a series for the empty-label group (`client_name` absent) *and* a series for `client_name="company-lookup-e2e-client"`; the outer `count()` counts both, treating "no client" as if it were itself a client.

**Fix, verified**: filter out the empty-label case before aggregating:

```
count(count by (client_name) (count_over_time({service_name=~".+"} | client_name != "" [6h])))
```

Re-tested against the same real data: returns `1` — correct.

### Bug 2: zero real clients returns empty, not `0`

Tested against `sovdev-test-company-lookup-python` specifically — a real service that genuinely never sets `client_name` (Python doesn't support the field yet, confirmed elsewhere in this repo's `compare-log-files.py` exclusions). With Bug 1's fix applied:

```
count(count by (client_name) (count_over_time({service_name="sovdev-test-company-lookup-python"} | client_name != "" [6h])))
```

returns `"result": []` — an **empty result vector**, not `0`. In a Grafana `stat` panel, this renders as "No data" (a blank/grey state), not a clean `0` — misleading for an operator persona, since "zero clients logging right now" is a completely normal, common state for many services (most don't use `client_name` at all), not an error condition or a broken panel.

**Fix, verified**: append `or vector(0)` to force a `0` when the inner aggregation produces no series:

```
count(count by (client_name) (count_over_time({service_name="sovdev-test-company-lookup-python"} | client_name != "" [6h]))) or vector(0)
```

Re-tested: returns `0` — correct, and re-confirmed the fleet-wide non-zero case (Bug 1's fix) still correctly returns `1` with the same `or vector(0)` suffix added — the fallback doesn't corrupt the real-data case.

### Final query, both fixes composed and both cases re-verified together

```logql
count(count by (client_name) (count_over_time({service_name=~"$service_name"} | client_name != "" [$__range]))) or vector(0)
```

(`$service_name` and `$__range` are the dashboard's own existing template variable and time-picker range — not yet substituted/tested through an actual live Grafana panel render, see [Q1].)

### Panel shape, confirmed by reading the real existing panel, not guessed

`tools/dashboards/sovdev-logger-overview.json`'s "Active Integrations" panel (id `1`) is a `stat` panel: `count(count by (service_name) (sovdev_operations_total{service_name=~"$service_name"}))` on the `prometheus` datasource. A `client_name` version mirrors this exactly — same panel type, same `$service_name` template variable (already `multi: true`, `includeAll: true`, defaulting to fleet-wide `.+` — confirmed by reading `templating.list[0]` directly, no changes needed there) — just the `loki` datasource and the query above instead.

---

## What was NOT tested — stated explicitly, not rounded up to "confirmed"

- **The actual rendered panel in a live Grafana dashboard.** Every query above was run directly against Loki's HTTP API, not through an actual dashboard panel — `$service_name`/`$__range` substitution, panel color thresholds, and how the "No data" vs. `0` distinction actually looks to a viewer haven't been visually confirmed.
- **Whitespace-only or garbage `client_name` values** (e.g. a caller setting `client_name: " "`) — the `!= ""` filter only catches a truly empty string, not whitespace. Not treated as a bug to fix — the library's own zero-opinion, pass-through design (established in `PLAN-context-propagation.md`) means it never validates what callers put in `client_name`, and a caller setting garbage values is a caller problem, not something this panel should try to paper over.
- **Query cost/performance at real fleet scale.** The `service_name=~".+"` wildcard selector's cost caveat is already documented in `INVESTIGATE-context-propagation.md`'s Q8 (scans every stream in the window, not just matching ones) — not re-derived here, still applies unchanged.
- **Whether `service_principal`/`acting_user` (added since this idea was first raised) should get similar panels.** Out of scope for this investigation — `client_name` is the concrete ask that started this; the other two fields' dashboard treatment is separately tracked as its own deferred Tier 5 item.

---

## Options

### Option A: Ship the panel as designed above

Add one new `stat` panel to `sovdev-logger-overview.json`, mirroring "Active Integrations"' exact shape, using the fully-composed query above.

**Pros**: small, well-scoped, both real bugs already found and fixed before writing any panel JSON — not discovered after shipping.
**Cons**: still hasn't been visually confirmed in an actual rendered dashboard (see "not tested" above) — first real render is the actual proof, not this investigation's API-level checks alone.

### Option B: Also add a per-service breakdown (not just the fleet-wide count)

Beyond the single "how many clients total" stat, add a table/graph showing *which* clients are calling *which* services — closer to a full drill-down view.

**Pros**: more useful for an operator actually investigating something, not just glancing at a number.
**Cons**: bigger scope, no concrete ask for this yet (the original ask was specifically "how many," not "which") — better as its own follow-up once the simple count panel is live and an operator actually asks for more.

---

## Recommendation

**Option A.** Matches the original concrete ask exactly, both real bugs are already fixed, and it's small enough to implement and validate (including the still-missing live-render check) in one pass.

---

## Open Questions

1. **[Q1]** Confirm via an actual live dashboard render (UIS, then Grafana Cloud) that `$service_name`/`$__range` substitute correctly into this query and the panel displays `0`/correct-count/`No data` exactly as expected — the one thing this investigation's API-level checks couldn't cover.
2. **[Q2]** — **Resolved.** "Active Clients" — matches "Active Integrations"' naming pattern for UI consistency, and unlike "Active Integrations" (found misleading by `INVESTIGATE-terminology-review.md` — it counts `service_name`, not integrations), this title is actually accurate: `client_name` literally represents clients by design.
3. **[Q3]** — **Resolved.** Same top row as "Active Integrations." Checked the actual grid layout directly: the row is exactly full today (`Active Integrations` `w:6` + `Total Operations (cumulative)` `w:18` = 24). Fits with zero disruption elsewhere: place "Active Clients" at `x:6, w:6, y:0, h:8` (immediately right of "Active Integrations"), narrow "Total Operations (cumulative)" from `w:18` to `w:12` and shift it to `x:12` — still a plenty-wide timeseries panel. No other panel needs to move.

## Next Steps

- [x] Maintainer answers [Q2]/[Q3] — resolved 2026-07-13
- [x] Create [`PLAN-operator-dashboard-panel.md`](../active/PLAN-operator-dashboard-panel.md) — small scope: add the panel JSON, validate via [Q1]'s live render against both real backends, update `tools/dashboards/README.md` if it documents panel-by-panel purpose
