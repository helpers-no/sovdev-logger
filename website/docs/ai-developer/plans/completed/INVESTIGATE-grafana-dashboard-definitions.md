# Investigate: Design Grafana dashboard definitions for sovdev-logger's full schema, and how to push them

Designs a Grafana dashboard that actually reflects everything sovdev-logger emits (not just metrics+basic logs, which is all the current one covers), and figures out how to push it into a Grafana instance — local UIS and/or Grafana Cloud — directly from this repo rather than depending on a separate infrastructure repo to embed it.

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Resolved — child plan shipped and confirmed

**Child plan**: [PLAN-grafana-dashboard-definitions.md](PLAN-grafana-dashboard-definitions.md) — implements and verifies everything decided below; both phases done, maintainer confirmed the live dashboard.

**Decisions**: [Q1] new UID (not overriding the provisioned one). [Q2] HTTP API push. [Q3] hand-authored JSON. [Q4] **local UIS only for now** — Grafana Cloud push deferred, no new credential created yet. [Q5] **full Phase 1 + Phase 2 scope** — service-name variable, peer_service dependency view, job-tracking panels, Tempo trace panels, and log↔trace correlation.

**Goal**: Produce a well-designed Grafana dashboard definition covering sovdev-logger's full data model (structured logs, metrics, traces, job tracking, service dependencies), owned by this repo, and a repeatable way to push it into a real Grafana instance.

**Last Updated**: 2026-07-11

---

## Current State (checked directly, not assumed)

### What sovdev-logger actually emits

- **Logs** (Loki, via OTLP): `event_id`, `service_name`, `service_version`, `function_name`, `level`, `log_type` (`transaction` | `job.status` | `job.progress`), `message`, `timestamp`, `trace_id`, `span_id`, `peer_service`, `input_json`, `response_json`, and on failure `exception_type`/`exception_message`/`exception_stacktrace`. Plus `session_id` on the resource.
- **Metrics** (Prometheus): `sovdev_operations_total`, `sovdev_errors_total` (counters), `sovdev_operation_duration_milliseconds` (histogram), `sovdev_operations_active` (gauge) — all labeled by `service_name`, `peer_service`, `log_type`, `level`.
- **Traces** (Tempo): spans named by `function_name`, correlated to logs via shared `trace_id`/`span_id`.

### The dashboard that already exists

Pulled directly from the live local UIS Grafana via its HTTP API (`/api/dashboards/uid/sovdev-metrics`) — not assumed from docs:

- Title "Sovdev Logger - Overview", UID `sovdev-metrics`, **provisioned externally** (`"provisioned": true, "provisionedExternalId": "sovdev-metrics.json"`) — it ships from UIS's own infrastructure repo (`dev-observability-stack/grafana/dashboards/`, per `website/docs/using/observability-architecture.md`), not from sovdev-logger.
- **6 panels total**, all confirmed by reading their actual queries:
  1. `Active Integrations` (stat) — `count(count by (service_name) (sovdev_operations_total))`
  2. `Total Operations (cumulative)` (timeseries) — `sum by (service_name, peer_service) (sovdev_operations_total)`
  3. `Error Rate (cumulative)` (timeseries) — errors/total ratio
  4. `Average Operation Duration (cumulative)` (timeseries) — duration histogram sum/count
  5. `Recent Errors (Detailed Logs from Loki)` (table) — `{service_name=~"..."} | exception_type!="" | log_type="transaction"`
  6. `Transaction Logs (Full Detail from Loki)` (logs panel) — `{service_name=~"..."} | log_type="transaction"`

### Real gaps found in the existing dashboard

- **Zero Tempo/trace panels** — despite distributed tracing and trace/span correlation being one of sovdev-logger's headline features ("automatic correlation," README), nothing here visualizes a trace.
- **`log_type="job.status"`/`"job.progress"` never shown** — batch-job lifecycle tracking (a distinct, named, documented log type) has no panel at all; only `log_type="transaction"` is covered.
- **No `peer_service` dependency view** — the metrics already carry a `peer_service` label (this is literally how sovdev-logger builds "service dependency maps," per its own README), but no panel aggregates or visualizes it as a dependency graph.
- **Hardcoded service-name filter** (`sovdev-test.*|company-lookup-service`) instead of a Grafana dashboard template variable — won't show any real production service with a different naming pattern without hand-editing the dashboard JSON.
- **No log-to-trace / trace-to-log correlation** configured — this is a Grafana *datasource* setting (Tempo's `tracesToLogsV2`, Loki's derived fields extracting `trace_id`), not just a dashboard one; worth doing alongside if traces get added.

### Where dashboard "push" credentials currently stand

- **Local UIS**: already have working Grafana admin credentials (`admin`/`SecretPassword1`, documented in `testing/uis.md`) — confirmed live via `GET /api/health` and `/api/search` this session. Pushing via `POST /api/dashboards/db` is technically unblocked today.
- **Grafana Cloud**: `tools/validation/grafana-cloud/.env` only has per-signal *query/ingest* tokens (`GRAFANA_CLOUD_VERIFY_TOKEN`, `GRAFANA_CLOUD_INGEST_TOKEN`) and datasource URLs — **no stack URL and no dashboard-management credential** (a Grafana Cloud Service Account token with `dashboards:write`, plus the stack's own `https://<stack>.grafana.net` URL). This is a genuinely new credential the maintainer would need to create via the portal, same pattern as the existing ingest/verify tokens.

---

## Questions to Answer

1. **[Q1]** New dashboard, or replace the UIS-provisioned one? The existing `sovdev-metrics` dashboard is provisioned from a *different* repo (UIS's own infra), so pushing to that same UID via the API risks Grafana's provisioner reverting the change on its next reload (provisioned dashboards are generally meant to be managed by their provisioning source, not edited live) — behavior not empirically tested here, would need to confirm on the actual UIS setup before relying on it. Using a **new UID owned by sovdev-logger** sidesteps the conflict entirely and cleanly separates "infra-provided" from "library-provided" dashboards. — **Leaning: new UID**, but this is a real design choice, not decided here.
2. **[Q2]** Push mechanism: Grafana HTTP API (`POST /api/dashboards/db`), or a provisioning-file approach (JSON + YAML dropped into a Grafana-watched directory)? The API approach works identically against local UIS and Grafana Cloud with just different credentials — no dependency on filesystem access to wherever Grafana's provisioning directory lives. The provisioning-file approach only makes sense if sovdev-logger had write access to UIS's own infra repo, which it doesn't. — **Leaning: HTTP API**, for both backends.
3. **[Q3]** Build the JSON by hand, or generate it from something schema-driven? Given this project's existing precedent (`tools/codegen/generate-field-constants.py` generates language constants from the JSON Schema — the same source of truth could drive dashboard panel labels/legends), a fully generated dashboard is tempting, but Grafana dashboard JSON is deeply nested and panel layout/design is inherently a manual, visual judgment call — a code generator would add real complexity for a payoff limited to keeping field *names* in sync, which schema drift here is a much smaller risk than in a hand-typed language binding. — **Leaning: hand-author the dashboard JSON**, informed by the schema but not generated from it; revisit only if sovdev-logger ends up shipping many dashboards, not just one.
4. **[Q4]** Grafana Cloud now, or local UIS first and Grafana Cloud later? Local UIS is fully unblocked today (credentials already exist); Grafana Cloud needs a new credential the maintainer has to create via the portal first (same as the ingest/verify token pattern already used this session) — not a technical blocker, just a sequencing one. — **Open, maintainer call.**
5. **[Q5]** Scope of new panels — all of the gaps found above (traces, job tracking, dependency view, template variable, log-trace correlation), or a smaller first cut? — **Open**, see Recommendation for a suggested phased scope.

---

## Options

### Option A: Hand-author dashboard JSON directly in this repo, push via Grafana HTTP API

Write a new dashboard JSON (new UID, e.g. `sovdev-logger-full`) under a new `tools/dashboards/` directory (mirroring the `tools/validation/`-by-backend precedent), plus a small TypeScript script (matching this project's "new tooling is TypeScript" rule) that POSTs it to a target Grafana instance's `/api/dashboards/db`, parameterized by URL + credentials so the same script works against local UIS and Grafana Cloud.

**Pros:**
- Full design control — dashboard layout/thresholds/panel choice are inherently a visual judgment call, not something worth automating away
- Reuses this project's established patterns exactly: TypeScript for new tooling, backend-parameterized like the existing `tools/validation/grafana-cloud/` client
- No dependency on any other repo

**Cons:**
- One more artifact to keep in sync by hand if the schema changes (mitigated: the schema is stable — 4 metrics, ~17 log fields, unchanged all session)

### Option B: Contribute back to UIS's own infra repo (`dev-observability-stack`)

Improve the existing provisioned dashboard in place, in whatever repo actually owns `dev-observability-stack/grafana/dashboards/sovdev-metrics.json`.

**Pros:** single dashboard, no duplication; matches "infra owns dashboards" if that's the intended model.
**Cons:** that repo isn't this one — no access/authorization to modify it from here, and it conflates sovdev-logger's release cycle with UIS's. Rejected for this investigation's scope (the user asked to push *from* sovdev-logger).

### Option C: Dashboard-as-code SDK (e.g. Grafana Foundation SDK / grafonnet)

Use a typed builder library to construct the dashboard programmatically instead of hand-writing JSON.

**Pros:** less raw JSON to hand-maintain, typed panel construction.
**Cons:** a new dependency and a whole new authoring paradigm for what is, right now, one dashboard. Worth reconsidering only if this grows into several dashboards across languages/backends. Rejected for now, revisit at scale.

---

## Recommendation

**[Q1]** new UID, **[Q2]** HTTP API push, **[Q3]** hand-authored JSON — i.e. **Option A**. Suggested phased panel scope for **[Q5]**, cheapest/highest-signal first:

- **Phase 1** (extends the existing 6 panels' coverage, all data already flowing): add a `service_name` template variable (replacing the hardcoded regex), a `peer_service` dependency table/bar chart (data already exists in the metrics labels — no new instrumentation needed), and job lifecycle panels for `log_type="job.status"`/`"job.progress"`.
- **Phase 2**: Tempo trace panels (trace list + a single trace's waterfall), plus the log↔trace correlation datasource config (`tracesToLogsV2` on Tempo, a derived field on Loki) so clicking a `trace_id` in a log line jumps straight to its trace.
- **[Q4]**: build and verify against **local UIS first** (credentials already work, zero new setup), defer Grafana Cloud until the maintainer creates a dashboard-management Service Account token there — same pattern as the existing ingest/verify tokens.

---

## Next Steps

- [x] Maintainer decided [Q1]/[Q4]/[Q5] — see Decisions above
- [ ] Draft `PLAN-grafana-dashboard-definitions.md` scoped to Phase 1 + Phase 2, local UIS only
- [ ] Grafana Cloud push (needs a new dashboard-write credential) — deferred, revisit later
