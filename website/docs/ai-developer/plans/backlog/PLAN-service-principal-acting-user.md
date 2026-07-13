# Plan: Add `service_principal` and `acting_user` context fields

Extends `sovdev_set_context()` with two more request-scoped fields — `service_principal` (the database credential an API used to query) and `acting_user` (the human the query was scoped to, when a customer-facing JWT is involved) — plus a one-time privacy warning when `acting_user` is set against a Grafana Cloud backend.

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Backlog

**Goal**: Ship `service_principal`/`acting_user` in `sovdev_set_context()`, wired correctly into both the file-log path and the OTLP export path (the exact place `client_name` was missed the first time), plus the Grafana Cloud privacy warning, validated end-to-end against both real backends.

**Last Updated**: 2026-07-13

**Investigation**: [INVESTIGATE-service-principal-acting-user.md](INVESTIGATE-service-principal-acting-user.md) — all questions resolved. The merge-vs-replace correctness fix it also surfaced already shipped separately as [`PLAN-context-merge-semantics.md`](../completed/PLAN-context-merge-semantics.md); this plan only adds the two new fields and the warning.

**Decisions confirmed just before drafting this plan**:
- Field name: `acting_user` (not `acting_user_id`).
- Grafana Cloud detection happens once, at `sovdev_initialize()` time (checking `process.env.OTEL_EXPORTER_OTLP_LOGS_ENDPOINT` for a `grafana.net` hostname), cached — not re-checked on every `sovdev_set_context()` call.

**Scope**: TypeScript only, same as `PLAN-context-propagation.md`. Dashboard treatment (a "Service Principal"/"Acting User" column, following the `client_name`/`peer_service` precedent) is explicitly deferred per the investigation's Q5 — a follow-up once there's real data to look at, not part of this plan.

---

## Design recap (from the investigation)

- **Mechanism**: both fields go on the same `SovdevRequestContext` object `sovdev_set_context()` already accepts — no new plumbing, reuses the (already-fixed) merge-based `AsyncLocalStorage` from `PLAN-context-merge-semantics.md`.
- **Semantics**: `service_principal` is expected whenever an API queries its database at all; `acting_user` only when a real end-user is behind the call (absent for service-to-service/batch calls). Neither is enforced by the library — both are optional at the schema/type level, same as `client_name`.
- **Zero library-side opinion on the value**: pure pass-through, exactly like `client_name`. The calling application decides whether `acting_user` holds a raw JWT claim, a hash, or an internal pseudonymous ID.
- **Privacy warning**: when `acting_user` is set (this field only, not `service_principal`) and the configured OTLP logs endpoint looks like Grafana Cloud, print a one-time warning per process that this value is headed to a third-party service and may contain personal data. Warn, never block or silently strip.

---

## Phase 1: Schema and core implementation

### Tasks

- [ ] 1.1 Add `service_principal` and `acting_user` to the shared schema (`tools/validation/schemas/log-entry-schema.json`), both optional (not in `required`), following `client_name`'s exact style.
- [ ] 1.2 Add both fields to the `SovdevRequestContext` interface and the `structured_log_entry` interface in `typescript/src/logger.ts`.
- [ ] 1.3 Update `write_log()` to read both new fields from `requestContextStorage.getStore()` and merge them into the log entry when present — same pattern as the existing `client_name` block.
- [ ] 1.4 **Critical, learned from `PLAN-context-propagation.md`'s Phase 3 bug**: `write_log()` building the `structured_log_entry` is *not* the same code path that exports to OTLP. `open_telemetry_winston_transport.log()` has its own separate, hardcoded attribute list (`logger.ts`, the `attributes` object built from `info.*`) that must *also* get explicit `if (info.service_principal) {...}` / `if (info.acting_user) {...}` blocks, or these fields will silently reach the file log but never reach Grafana Cloud/UIS — exactly what happened to `client_name` the first time. Do not skip this.

### Validation

```bash
cd typescript && npx tsc --noEmit && npm run lint && npm run build
```

A throwaway script proves both fields survive to a real backend from the start (not repeating the mistake of only checking the local file log): `sovdev_set_context({ service_principal: '...', acting_user: '...' })`, `sovdev_log(...)`, query the real backend directly for both fields — do this in Phase 1, not deferred to a later "end-to-end" phase, specifically because that's where the `client_name` bug was found last time (too late, after the file-log-only check looked fine).

---

## Phase 2: Grafana Cloud privacy warning

### Tasks

- [ ] 2.1 At `sovdev_initialize()`, check `process.env.OTEL_EXPORTER_OTLP_LOGS_ENDPOINT` for a `grafana.net` substring; cache the result in a module-level flag (e.g. `isGrafanaCloudBackend`).
- [ ] 2.2 In `sovdev_set_context()` (or `write_log()`, wherever it's cleanest to check without adding per-call overhead), if `acting_user` is present in the context and `isGrafanaCloudBackend` is true, print a one-time warning (module-level "already warned" flag, not per-call) via `console.warn()`, matching the library's existing diagnostic-warning style.
- [ ] 2.3 Confirm the exact wording is clear and specific — states what's happening (this value is going to Grafana Cloud) and why it matters (may contain personal data), not vague.

### Validation

Real test against Grafana Cloud: set `acting_user`, confirm the warning fires exactly once even across multiple `sovdev_log()` calls in the same process. Real test against UIS: confirm the warning does *not* fire (self-hosted, not the risk case).

---

## Phase 3: Documentation

### Tasks

- [ ] 3.1 Extend the README's "Setting Request-Scoped Context" section (added in `PLAN-context-propagation.md`) to cover `service_principal`/`acting_user` — the customer-facing-JWT vs. service-account scenarios, and the privacy note.
- [ ] 3.2 Document the Grafana Cloud warning explicitly, and the recommendation to use a pseudonymous/internal ID for `acting_user` regardless of backend.

### Validation

User reviews the new README content reads clearly.

---

## Phase 4: End-to-end validation against real backends

### Tasks

- [ ] 4.1 Extend `company-lookup.ts`'s `sovdev_set_context()` call to include `service_principal` (and optionally `acting_user`, noting the same `compare-log-files.py` `EXCLUDED_FIELDS` consideration `client_name` needed).
- [ ] 4.2 Run the E2E test against real Grafana Cloud — confirm both fields present and queryable via LogQL structured metadata, and confirm the privacy warning fires once.
- [ ] 4.3 Run the same against real UIS — confirm both fields present, and confirm the warning does *not* fire.
- [ ] 4.4 Confirm existing schema validation and cross-language comparison exclusions still pass.

### Validation

Real query output for both fields on both backends, matching the standard every prior phase in this feature area has used.

---

## Phase 5: Final checks

### Tasks

- [ ] 5.1 `npx tsc --noEmit`, `npm run lint`, `npm run build` all clean.
- [ ] 5.2 Confirm no regression to `client_name` (still works, still merges correctly alongside the two new fields — a real test of 3+ fields set across multiple calls, extending `PLAN-context-merge-semantics.md`'s 2-field test).
- [ ] 5.3 Rebuild the Docusaurus site.

### Validation

User confirms the diff matches this plan's scope — no unrelated changes, and dashboard work genuinely deferred, not half-started.

---

## Acceptance Criteria

- [ ] `service_principal` and `acting_user` both work via `sovdev_set_context()`, confirmed present in real log entries on both Grafana Cloud and UIS.
- [ ] Both fields are optional/additive — no impact on existing `client_name`-only integrators.
- [ ] The Grafana Cloud privacy warning fires exactly once per process when `acting_user` is set against that backend, and never fires against UIS.
- [ ] `client_name`, `service_principal`, and `acting_user` all correctly coexist via the merge mechanism (extends, doesn't regress, `PLAN-context-merge-semantics.md`).
- [ ] Both fields reach the *actual OTLP-exported* log entry, verified directly against a real backend in Phase 1 — not assumed from the file log alone.

---

## Files to Modify

- `tools/validation/schemas/log-entry-schema.json`
- `typescript/src/logger.ts`
- `typescript/README.md`
- `typescript/test/e2e/company-lookup/company-lookup.ts`
- `tools/validation/validators/compare-log-files.py` (exclude the new fields from cross-language diffing, same as `client_name`)
