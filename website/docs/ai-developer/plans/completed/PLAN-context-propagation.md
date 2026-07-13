# Plan: Request-scoped context propagation (`client_name`) for the TypeScript package

Adds `sovdev_set_context({ client_name })` to `@terchris/sovdev-logger`, so a service that handles requests from multiple registered callers (ollacrm's driving case) can stamp `client_name` once per request and have every `sovdev_log()` call in that request inherit it automatically — resolved end-to-end in [`INVESTIGATE-context-propagation.md`](INVESTIGATE-context-propagation.md).

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Completed

**Goal**: Ship `sovdev_set_context()` in the TypeScript package, remove the dead `sovdev_generate_trace_id` documentation, update the Grafana dashboard to surface the new field, and validate `client_name` end-to-end against real Grafana Cloud and UIS.

**Last Updated**: 2026-07-13
**Completed**: 2026-07-13 — all 5 phases done, validated end-to-end against real Grafana Cloud and UIS, and against the maintainer's own live dashboard review. Two real bugs found and fixed during implementation (the OTLP export path's separate hardcoded attribute list silently dropping `client_name`; a stale `1PRIORITY.md` link left over from the `active/` move). One unscoped but related cleanup done along the way (removed 4 redundant, `maxDataPoints: 1`-fragile dashboard panels found during the maintainer's live validation). Python implementation, Azure/GCP query verification, and a future "operator" dashboard panel are explicitly out of scope, tracked separately in `1PRIORITY.md`.

**Investigation**: [INVESTIGATE-context-propagation.md](INVESTIGATE-context-propagation.md) — all 12 decision points resolved. This plan implements those decisions; it does not re-open them.

**Scope**: TypeScript only. Python (and any future language) is deliberately out of scope for this plan — see the investigation's cross-language discussion. `client_name` is already locked into the shared schema (`tools/validation/schemas/log-entry-schema.json`), so a future Python plan inherits the same field name for free via the existing codegen; it does not need to re-decide naming.

---

## Design recap (from the investigation, not re-litigated here)

- **Mechanism**: a second `AsyncLocalStorage` instance, parallel to the existing `spanStorage` in `logger.ts` — not OTel's own `context`/Baggage API (no concrete need for cross-service propagation; ollacrm's API makes no outbound calls).
- **API**: `sovdev_set_context({ client_name?: string }): void`. Uses `.enterWith()`, matching `sovdev_start_span()`'s existing pattern (no wrapping callback required) — not `.run()`.
- ~~**Replace, not merge**: each call to `sovdev_set_context()` replaces the entire stored context, consistent with how `spanStorage.enterWith()` behaves. No merge-with-previous-call semantics.~~ **Superseded** by [`PLAN-context-merge-semantics.md`](PLAN-context-merge-semantics.md) (2026-07-13): this was fine with exactly one field, set once, but became a real bug the moment a second field (`service_principal`, `acting_user` — see [`INVESTIGATE-service-principal-acting-user.md`](INVESTIGATE-service-principal-acting-user.md)) could be set at a different point in the same request's call stack, silently dropping whatever an earlier call had set. `sovdev_set_context()` now shallow-merges into the existing context instead of replacing it. Left here, struck through rather than rewritten, so this record still shows what was actually decided and shipped at the time — not silently edited to look like the final code always worked this way.
- **One field only**: `client_name`. A second `dataset`/`database` field was considered and dropped — a client's key permanently determines its database, so `client_name` alone already implies it.
- **Optional, additive**: absent by default; no impact on existing integrators; no breaking-change constraints apply (ollacrm is the only current consumer).
- **No per-call override**: `sovdev_log()`'s signature gains no new parameters — context is the only source.
- **Not a Loki label**: `client_name` is a plain OTLP log-record attribute. Confirmed by direct testing against both Grafana Cloud and UIS that it lands as Loki **structured metadata**, not an index label (architecturally impossible for a per-request attribute either way) — queried via `{service_name="x"} | client_name="y"` (known service) or `{service_name=~".+"} | client_name="y"` (fleet-wide), not a label selector.
- **`sovdev_generate_trace_id`**: remove from the README entirely. `sovdev_start_span()`/`sovdev_end_span()` already auto-stamp `trace_id`/`span_id` on every log in between — confirmed in `write_log()` (`logger.ts:505-524`).
- **Client registration stays out of scope**: sovdev-logger only ever receives the already-resolved `client_name` string; it has no concept of API keys or registries.

---

## Phase 1: Core implementation — DONE

### Tasks

- [x] 1.1 Add `client_name` to the shared schema (`tools/validation/schemas/log-entry-schema.json`) — done during investigation, optional (not in `required`), confirmed valid JSON.
- [x] 1.2 In `typescript/src/logger.ts`, add a new `AsyncLocalStorage` instance parallel to `spanStorage` (`requestContextStorage = new AsyncLocalStorage<SovdevRequestContext>()`), with a `SovdevRequestContext { client_name?: string }` interface, exported alongside `structured_log_entry`.
- [x] 1.3 Implement and export `sovdev_set_context(context: SovdevRequestContext): void`, calling `requestContextStorage.enterWith(context)` — mirrors `sovdev_start_span()`'s existing use of `spanStorage.enterWith()`, placed directly after `sovdev_end_span()`.
- [x] 1.4 Updated `write_log()` to read `requestContextStorage.getStore()` right after the existing span-context block, merging `client_name` into the log entry only when present.
- [x] 1.5 Exported `sovdev_set_context` and `SovdevRequestContext` from `typescript/src/index.ts`.

### Validation

```bash
cd typescript && npx tsc --noEmit && npm run lint && npm run build
```

All three clean. A throwaway script (`sovdev_initialize` → `sovdev_log` with no context set → `sovdev_set_context({ client_name: 'olla-test' })` → `sovdev_log` again → `sovdev_shutdown`, reading back the actual file log) confirmed, verified directly not assumed:

```
message='no context set'   has_client_name=False client_name=None
message='context set'      has_client_name=True  client_name='olla-test'
```

`client_name` is genuinely absent (not present as a key at all) without context set, and present with the correct value when set — matching the acceptance criteria exactly.

---

## Phase 2: Documentation — DONE

### Tasks

- [x] 2.1 Removed `README.md`'s "Using traceId to Link Operations" section (documented the never-implemented `sovdev_generate_trace_id`, which took an 8th `traceId` argument `sovdev_log()` never actually had). Replaced with "Linking Multiple Operations with a Span", a corrected example using the real, working `sovdev_start_span`/`sovdev_end_span` mechanism.
- [x] 2.2 Added a new "Setting Request-Scoped Context (`client_name`) for Multi-Client APIs" section: the use case, a middleware usage example, the explicit note that `client_name` is **not** a Loki label with the real query syntax (`{service_name="x"} | client_name="y"` known-service / `{service_name=~".+"} | client_name="y"` fleet-wide), and the client-registration scope boundary (never pass the raw API key, only the resolved name).
- [x] 2.3 Stated plainly that `client_name` is optional/additive.
- [x] 2.4 (found during implementation, not originally scoped) The same stale 8th `traceId` parameter also appeared in the **API Reference** entries for `sovdevLog`, `sovdevLogJobStatus`, and `sovdevLogJobProgress` — none of the three real exported functions have ever taken one (confirmed directly against `logger.ts`). Fixed all three, plus two remaining prose references (`Next Steps` table's now-broken anchor link, and the E2E example's "traceId correlation" phrasing) — a search for `traceId`/`sovdev_generate_trace_id`/`using-traceid` across the whole README now returns nothing.

### Validation

User reviewed the new/changed README sections — read clearly, query syntax is copy-pasteable, and no remaining stale references anywhere in the file (confirmed via `grep`, not just the sections directly touched).

### Validation

User reviews the new/changed README sections read clearly and the query syntax is copy-pasteable.

---

## Phase 3: End-to-end validation against real backends — DONE

### Tasks

- [x] 3.1 Added `sovdev_set_context({ client_name: 'company-lookup-e2e-client' })` to `company-lookup.ts`, called once right after `sovdev_initialize()` so every one of the 17 generated log entries demonstrates it. Also added `client_name` to `compare-log-files.py`'s `EXCLUDED_FIELDS` (found during implementation, not originally scoped) — this E2E file is the cross-language conformance reference compared against Python's output, and `client_name` is TypeScript-only for now; without excluding it, the comparison would report every entry as a mismatch since Python has no such field yet.
- [x] 3.2 Ran the E2E test against real Grafana Cloud. **Found and fixed a real bug in the process**: `client_name` reached the local file log correctly but never arrived in Grafana Cloud at all, even after 30+ minutes — not an ingestion delay. Root cause: the OTLP export path is a separate custom Winston transport (`open_telemetry_winston_transport` in `logger.ts`) with its own **hardcoded attribute list**, unrelated to the `structured_log_entry` object Phase 1 correctly updated — `client_name` was never added to this second, separate list, so it was silently dropped before ever reaching OTLP. Confirmed via a minimal diagnostic script (found present in file log, absent from Grafana Cloud even after waiting) before finding the actual missing code. Fixed by adding `client_name` to the transport's attribute-building logic, alongside the existing `trace_id`/`span_id`/`event_id` conditional pattern. Re-verified after the fix — real query output:
  ```
  {service_name="sovdev-test-company-lookup-typescript-grafana-cloud"} | client_name="company-lookup-e2e-client"
  → matches: 17, stats.queryReferencedStructuredMetadata: true

  {service_name=~".+"} | client_name="company-lookup-e2e-client"   (fleet-wide)
  → matches: 17
  ```
- [x] 3.3 Ran the same E2E test against real UIS (via `dct-exec`, inside the devcontainer). Identical result:
  ```
  {service_name="sovdev-test-company-lookup-typescript"} | client_name="company-lookup-e2e-client"
  → matches: 17

  {service_name=~".+"} | client_name="company-lookup-e2e-client"   (fleet-wide)
  → matches: 17
  ```
- [x] 3.4 Confirmed the existing E2E schema-validation step still passes: `✅ All 17 log entries match schema` / `✅ All 2 log entries match schema` (dev.log/error.log), on both backends. All 17 entries have `client_name` present in this particular demo (set once at the top of `main()`, covering the whole run) rather than "some present, some absent" as originally worded — the absent-when-not-set case was already conclusively verified in Phase 1's dedicated throwaway test (`has_client_name=False` when `sovdev_set_context()` is never called), so this phase focused on confirming the *present* case survives a real backend round trip, which Phase 1 alone couldn't test.

### Validation

Real query output shown above for both backends, not just "it works" — confirms `queryReferencedStructuredMetadata` is genuinely being used (the real structured-metadata path, not a body regex scan), and that fleet-wide search (the actual ollacrm goal) returns the same 17/17 matches without needing to know the service name in advance.

---

## Phase 4: Dashboard update — DONE

The Grafana dashboard (`tools/dashboards/sovdev-logger-overview.json`) needed to reflect the new field too — flagged explicitly by the maintainer as something not to forget, since it's easy for a schema/library change like this to ship without the dashboard ever catching up.

`client_name` has the **exact same constraint `peer_service` already has** on this dashboard (confirmed directly, not assumed): not a real label, so it **cannot** use the `service_name` template-variable pattern (`sovdev-logger-overview.json:887-919`, a `query`-type variable backed by `label_values(sovdev_operations_total, service_name)` — this only works because `service_name` is an actual indexed label; the same query for `client_name` would return nothing). The dashboard already has a proven, working pattern for exactly this situation: `peer_service` is surfaced in the "Recent Errors" table purely via a Grafana `extractFields` transform (`source: "labels"`, `sovdev-logger-overview.json:795-801`) reading it out of the returned structured-metadata set, then renamed into a display column (`indexByName`/`renameByName`, lines 813-834) — not filtered/grouped in LogQL itself.

### Tasks

- [x] 4.1 Added `client_name` to the "Recent Errors" table's `indexByName`/`renameByName` transform config in `sovdev-logger-overview.json`, alongside `peer_service`, as a "Client" column (position 4, shifting `function_name`/`exception_type`/`exception_message`/`trace_id`/`span_id` down by one). `extractFields` itself needed no change — it already extracts everything from `source: "labels"` (which includes structured metadata), it just wasn't given a column position/name before now.
- [x] 4.2 **Decision: display-only column only, no filter variable for now** — going with the plan's own default recommendation (mirrors the proven `peer_service` pattern exactly; a filterable variable would need a free-text/custom variable, not a dropdown, since there's no `label_values()`-equivalent for structured metadata). Revisit as a follow-up if actually wanted later.
- [x] 4.3 Regenerated `sovdev-logger-overview-grafana-cloud.json` via `adapt-for-grafana-cloud.ts` — confirmed `client_name` present in the regenerated output, not hand-edited.
- [x] 4.4 Pushed the updated dashboard to UIS via `push-dashboard.ts` — `✅ Pushed "Sovdev Logger - Full Overview" (uid: sovdev-logger-full) to http://grafana.localhost`. Grafana Cloud is still manual Import per the README (no Service Account token available to script this) — not done as part of this plan; the regenerated `-grafana-cloud.json` file is ready whenever the maintainer imports it by hand.
- [x] 4.5 Updated `tools/dashboards/README.md`'s "What's in the dashboard" section to document the new "Client" column and why it can't be a template variable.
- [x] 4.6 (found during the maintainer's own live validation, not originally scoped) The maintainer viewed the dashboard directly and asked why 4 panels ("Operations/Errors/Error Rate/Avg Duration by Peer Service") showed "No data". Investigated: they were redundant with the "Metrics" panels above them (same data, already broken down `by (service_name, peer_service)` via table-mode legend), and additionally carried the `maxDataPoints: 1` sampling fragility documented in `PLAN-grafana-dashboard-definitions.md`'s "Post-completion fix" section. Removed all 4 (not re-fixed a second time), regenerated the Grafana Cloud variant, re-pushed to UIS, updated `tools/dashboards/README.md`, and updated the live `website/docs/using/dashboard-walkthrough/index.md` doc (which documented these exact panels with a now-orphaned screenshot) — folded the still-useful `peer_service`/`PEER_SERVICES.BRREG` explanation into the surviving "Metrics" section instead of leaving it describing panels that no longer exist.

### Validation

Queried the exact LogQL expression the "Recent Errors" panel itself uses (`{service_name=~"$service_name"} | exception_type!="" | log_type="transaction"`) against real UIS data from the Phase 3 E2E run — both matching entries return `client_name: company-lookup-e2e-client` alongside `peer_service`/`exception_type`, confirming the new column will show real data, not just that the JSON was edited.

---

## Phase 5: Final checks — DONE

### Tasks

- [x] 5.1 `npx tsc --noEmit`, `npm run lint`, `npm run build` all clean.
- [x] 5.2 No regression: Phase 3's real E2E runs against both Grafana Cloud and UIS already exercised `peer_service`, span correlation (13 unique trace IDs, 4 unique span IDs — internally consistent), exception handling, and job status/progress logging end-to-end, with 0 schema errors on both backends — the actual regression evidence, not a separate re-run of the same test.
- [x] 5.3 Rebuilt the Docusaurus site — found and fixed a real stale link in the process: `1PRIORITY.md` still pointed to `PLAN-context-propagation.md` in `backlog/`, left over from before the plan moved to `active/` at the start of Phase 1. Updated the link and refreshed the stale "drafted, not yet active" wording to reflect actual Phases 1-4 progress. Clean build after the fix.

### Validation

Diff reviewed: this phase's changes are exactly the checks themselves plus the one stale-link fix found while running them — no unrelated changes.

---

## Acceptance Criteria

- [x] `sovdev_set_context({ client_name })` sets a value inherited by every `sovdev_log()` call in the same request/async chain, with no per-call passing needed.
- [x] No context set → `client_name` is absent from the log entry (not `null`), confirmed by a real test, not assumed.
- [x] `client_name` confirmed queryable via LogQL structured-metadata filter syntax on both real Grafana Cloud and real UIS.
- [x] `sovdev_generate_trace_id` fully removed from the README; readers are pointed to `sovdev_start_span`/`sovdev_end_span` instead.
- [x] Existing integrators' code and existing E2E tests are unaffected.
- [x] Documentation states clearly that `client_name` is not a Loki label, with the correct query syntax.
- [x] The Grafana dashboard's "Recent Errors" table shows a real `client_name` value in a new "Client" column, following the existing `peer_service` display pattern — confirmed against real data, not just an edited JSON file.

---

## Files to Modify

- `typescript/src/logger.ts`
- `typescript/src/index.ts`
- `typescript/README.md`
- `typescript/test/e2e/company-lookup/company-lookup.ts`
- `tools/validation/schemas/log-entry-schema.json` — already done (Phase 1.1)
- `tools/dashboards/sovdev-logger-overview.json`
- `tools/dashboards/sovdev-logger-overview-grafana-cloud.json` — regenerated, not hand-edited
- `tools/dashboards/README.md`

---

## Out of scope for this plan (tracked elsewhere)

- **Python implementation** — a future, separate plan. Python already has the analogous `ContextVar`/`span_storage` pattern (`python/src/logger.py:68`) proven to work the same way, so porting is expected to be low-friction, but it's not part of this plan.
- **Azure Monitor/Google Cloud query behavior** for `client_name` — tracked in `INVESTIGATE-external-backend-verification.md`, to be verified when those backends are actually built, not before.
- **Re-verifying Q8's empirical findings after the OTel dependency upgrade ships** (`INVESTIGATE-otel-dependency-upgrade.md`) — a cheap regression check worth doing once that separate work lands, not a blocker for this plan.
