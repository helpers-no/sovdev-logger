# Build and push a sovdev-logger-owned Grafana dashboard covering the full schema

Hand-authors a new Grafana dashboard (own UID) covering metrics, logs, job tracking, service dependencies, and traces, plus a TypeScript push script and log↔trace datasource correlation, verified against local UIS.

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Completed

**Investigation**: [INVESTIGATE-grafana-dashboard-definitions.md](../completed/INVESTIGATE-grafana-dashboard-definitions.md) — full audit of the existing UIS-provisioned dashboard's gaps, and the options/decisions behind this plan's scope.

**Goal**: Ship a new, sovdev-logger-owned Grafana dashboard (new UID, not overriding the UIS-provisioned one) covering the full data model, pushed to local UIS via a reusable TypeScript script, with Phase 2 adding trace panels and log↔trace correlation.

**Last Updated**: 2026-07-11
**Completed**: 2026-07-11

---

## Post-completion fix: Peer Service Dependencies panel was empty

Found via the maintainer's own screenshot review (not caught by my own validation, which only checked queries via the raw Prometheus REST API and `/api/ds/query` for the Tempo panel — not this panel's specific instant-query mode). **Root cause, confirmed empirically**: `instant: true` on a Prometheus query returns a genuinely empty result through Grafana's real query pipeline (`/api/ds/query`) in this setup, even though the identical PromQL works correctly both as a plain range query and hit directly against Prometheus's raw REST API. Tried several parameter variants (`range: false`, `queryType: "instant"`, explicit `datasourceId`, epoch-ms timestamps) — all empty; this looks like a genuine bug/misconfiguration specific to this Grafana build's Prometheus datasource plugin instant-query handling, not a mistake in the request shape.

**Fix**: replaced the single instant-query-based table (4 queries merged via a `merge` transform) with 4 separate Stat panels ("Operations by Peer Service", "Errors by Peer Service", "Error Rate by Peer Service", "Avg Duration by Peer Service"), each a plain range query (the one pattern already proven working throughout this dashboard) with `reduceOptions.values: true` — Grafana's native, transform-free way to show one number per series. Re-verified all 4 queries return correct real data through `/api/ds/query` (Operations: SYS1234567=13, self=4; Errors: SYS1234567=2, self correctly absent rather than zero; Error Rate: 15.4%; Avg Duration: 1ms both).

**Caveat carried forward**: Grafana transformations (the `merge`/`organize` pattern the original design used) run client-side and can't be verified via `curl` from this environment at all — only raw query correctness can. This fix deliberately avoids needing any transform, sidestepping that verification gap entirely rather than trying to debug an unverifiable transform further.

### Second bug, same section: duplicate rows instead of one-per-series

Found via the maintainer's next round of screenshots — the 4 new panels each showed many duplicate rows for the same `peer_service` (e.g. "sovdev-test-company-lookup-typescript" repeated 6+ times, all showing the same value). **Root cause**: a plain range query returns one data point per scrape step (roughly 60 points over a 15-minute window at the default step), and a Stat panel with `reduceOptions.values: true` renders **one row per data point**, not one row per series, unless the query is constrained to return exactly one point per series. Since the underlying metric is a flat cumulative counter, every duplicate point had the identical value, which is what made the rows look like harmless repeats rather than an obvious bug at first glance in the raw query check.

**Fix**: added `maxDataPoints: 1` to both the panel and its target query — confirmed via `/api/ds/query` that this makes Prometheus return exactly one point per series, server-side and fully verifiable (no client-side transform involved, unlike the first bug). Re-verified all 4 panels' queries return exactly 1-2 rows (matching the real number of `peer_service` values), each with the correct value.

---

## Problem Summary

The existing `sovdev-metrics` dashboard (provisioned externally from UIS's own infra repo) covers only 4 Prometheus metric panels and 2 basic Loki panels. It has zero trace visualization, no job-lifecycle panels, no service-dependency view, and a hardcoded service-name filter instead of a template variable — despite all of this data already flowing through OTLP today. This plan builds a new dashboard sovdev-logger owns and can push itself, verified against real data pulled from the live local UIS stack (not assumed).

**Verified facts this plan relies on** (checked directly against the live local UIS Grafana, 2026-07-11):
- Datasource UIDs: `loki`, `prometheus`, `tempo` (simple names, confirmed via `GET /api/datasources`)
- Loki labels on every log line: `service_name`, `service_version`, `function_name`, `log_type`, `peer_service`, `trace_id`, `session_id`, `event_id`, `severity_text`, plus `exception_type`/`exception_message`/`exception_stacktrace` when present. `input_json`/`response_json` are labels whose *values* are stringified JSON (not flattened sub-labels) — extracting a field like `progress_percentage` needs a LogQL parsing stage, exact syntax to confirm during Phase 1 implementation, not assumed here.
- Tempo's service-name tag is `service.name` (OTel dot-notation convention, confirmed via `GET .../api/search/tags`); TraceQL filters accordingly (`{resource.service.name=~"..."}`, to confirm the exact scoping prefix works during Phase 2).
- Grafana version: 12.3.1.

---

## Phase 1: New dashboard — variable, dependency view, job tracking — DONE

### Tasks

- [x] 1.1 Created `tools/dashboards/` with `sovdev-logger-overview.json` — hand-authored (via a one-off local Python authoring script, not a repo-tracked generator — Q3 stays "hand-authored," the script was just a typing aid), new UID `sovdev-logger-full`, distinct from `sovdev-metrics`
- [x] 1.2 Added the `service_name` template variable (multi-value, "All" default) — every panel uses `$service_name` instead of the old hardcoded regex
- [x] 1.3 Ported the existing 6 panels, parameterized by the variable
- [x] 1.4 Added "Peer Service Dependencies" table — 4 Prometheus queries (total ops, errors, error rate, avg duration by `peer_service`) merged via a `merge` transform into one table
- [x] 1.5 **Simplified from the original task description**: instead of separate Job Status/Progress panels needing fragile `input_json` JSON-string parsing, built one **"Job Lifecycle" logs panel** (`log_type=~"job.status|job.progress"`, ascending order) — the human-readable `message` field already contains everything needed ("Job Started: X" → "Processing 1/4" → ... → "Job Completed: X"), reads as a natural timeline with zero query fragility. The `input_json` extraction concern flagged in the original task never had to be resolved.
- [x] 1.6 Wrote `tools/dashboards/push-dashboard.ts` — supports both `GRAFANA_TOKEN` (bearer) and `GRAFANA_USER`/`GRAFANA_PASSWORD` (basic), same dual-auth pattern as the existing Grafana Cloud tooling
- [x] 1.7 Wrote `tools/dashboards/README.md`

### Validation

- [x] Pushed to local UIS — confirmed via `GET /api/search?query=sovdev` showing **two distinct dashboards** (`sovdev-logger-full` and `sovdev-metrics`), no conflict
- [x] **Found and fixed a real bug during validation**: LogQL rejects `service_name=~".*"` outright ("queries require at least one regexp or equality matcher that does not have an empty-compatible value") — this is exactly what "All" selected on the template variable would produce by default. Fixed by setting the variable's `allValue: ".+"` explicitly (confirmed `.+` satisfies LogQL's requirement, `.*` does not), rather than relying on Grafana's implicit all-options-expansion behavior which would be fragile as services are added/removed.
- [x] Ran the TypeScript E2E test fresh, confirmed every panel against real data pulled directly from the datasources (not just visually assumed): Active Integrations → `1`; Peer Service Dependencies → `SYS1234567`: 13 ops/2 errors/0.77ms avg, self: 4 ops/1.25ms avg; Job Lifecycle → correct chronological "Started → Processing 1/4..4/4 → Completed" sequence; Recent Errors → 4 entries; Transaction Logs → 22 entries (two test runs' worth)
- [x] User confirms Phase 1 complete

---

## Phase 2: Traces and log↔trace correlation — DONE

### Tasks

- [x] 2.1 Added a "Recent Traces" table panel — `resource.service.name=~"$service_name"` TraceQL scoping confirmed working (both `resource.service.name` and unscoped `.service.name` returned identical results; used the explicit `resource.` form). Verified through Grafana's real query pipeline (`POST /api/ds/query`), not just the raw Tempo REST API — confirmed the Tempo datasource plugin auto-generates a Trace ID column with a working internal data link to the full waterfall view, and an expandable per-span "nested" frame with its own Span ID links.
- [x] 2.2 **Revised during implementation**: `derivedFields` can't reach `trace_id` at all, because it's a Loki **label**, not text embedded in the log line — `derivedFields`' regex only matches against line content. Used Grafana's **Correlations API** instead (`POST /api/datasources/uid/loki/correlations`), which links a named field (label or line content) directly to a Tempo TraceQL query. Took some empirical trial-and-error to find the correct request shape — Grafana's own error message ("bad request data") wasn't informative; the real cause (`type` must be a top-level field, not nested inside `config`) only surfaced by reading the Grafana pod's own logs (`invalid correlation type: ""`).
- [x] 2.3 Configured Tempo→Loki via `tracesToLogsV2` in the `tempo` datasource's `jsonData` (as originally planned) — `datasourceUid: loki`, tag mapping `service.name` → `service_name`.
- [x] 2.4 Wrote `configure-trace-correlation.ts` covering both directions. **Found and fixed a real idempotency bug**: the Correlations API has no upsert — POSTing the same correlation twice created two duplicates, confirmed by re-running the script and checking `/api/datasources/correlations`' count go from 1 to 2. Fixed by having the script look up and delete any correlation it previously created (matching source/target/field) before creating a fresh one; re-verified running it twice in a row now stays at exactly 1.

### Validation

- [x] Ran the TypeScript E2E test fresh, confirmed via the real Grafana query pipeline (`/api/ds/query`, not the raw Tempo REST API) that the Tempo panel shows real traces with correct service name, span name (`lookupCompany`), and durations (38-41ms) — same known Tempo indexing-lag gotcha as elsewhere this session (empty immediately after the run, real data after ~35s)
- [x] Confirmed the Loki→Tempo correlation is stored correctly via `GET /api/datasources/correlations` (field `trace_id`, target Tempo, TraceQL `${__value.raw}`)
- [x] Confirmed the Tempo→Loki `tracesToLogsV2` config persisted via `GET /api/datasources/uid/tempo`
- [x] **Caveat, stated plainly**: both correlations are configured and confirmed correct at the API/config level. The actual click-through behavior (expanding a log line's trace_id label and clicking through, or viewing a trace and clicking "logs for this span") renders client-side in Grafana's UI — not something verifiable via `curl` from this environment. Configuration correctness is verified; the interactive click-through itself was not visually confirmed in a browser.
- [x] User confirms Phase 2 complete — confirmed the dashboard directly (checked which dashboards were pre-existing vs. new via the API, then visually reviewed it in the browser)

---

## Acceptance Criteria

- [x] New dashboard exists on local UIS under its own UID (`sovdev-logger-full`), confirmed coexisting with the UIS-provisioned `sovdev-metrics` (both returned by `/api/search?query=sovdev`)
- [x] Every panel uses the `$service_name` variable, none use a hardcoded regex
- [x] `peer_service` (service dependency), `job.status`/`job.progress` (job tracking), and Tempo traces are all visualized — the three gaps identified in the investigation
- [x] Log↔trace correlation configured both directions (log → trace via Correlations API, trace → logs via `tracesToLogsV2`) — configuration verified at the API level; interactive click-through not visually confirmed in a browser (see Phase 2 caveat)
- [x] `push-dashboard.ts` and `configure-trace-correlation.ts` are reusable against any Grafana instance given URL + credentials (verified locally; Grafana Cloud deferred per the investigation's [Q4] decision)
- [x] Docusaurus build clean (`tools/README.md` was touched)

## Files to Modify

- `tools/dashboards/sovdev-logger-overview.json` (new)
- `tools/dashboards/push-dashboard.ts` (new)
- `tools/dashboards/configure-trace-correlation.ts` (new — not in the original scope, added for Phase 2.4)
- `tools/dashboards/package.json`, `tsconfig.json` (new — self-contained TS tooling, matching `tools/validation/`'s pattern)
- `tools/dashboards/README.md` (new)
- `tools/README.md` (added `dashboards/` to the structure overview)
