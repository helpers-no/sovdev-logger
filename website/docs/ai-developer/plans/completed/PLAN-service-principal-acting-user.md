# Plan: Add `service_principal` and `acting_user` context fields

Extends `sovdev_set_context()` with two more request-scoped fields — `service_principal` (the database credential an API used to query) and `acting_user` (the human the query was scoped to, when a customer-facing JWT is involved) — plus a one-time privacy warning when `acting_user` is set against a Grafana Cloud backend.

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Completed

**Goal**: Ship `service_principal`/`acting_user` in `sovdev_set_context()`, wired correctly into both the file-log path and the OTLP export path (the exact place `client_name` was missed the first time), plus the Grafana Cloud privacy warning, validated end-to-end against both real backends.

**Shipped**: All 5 phases complete, verified against both real Grafana Cloud and real UIS throughout, including a 3-field merge regression test and a clean cross-language comparator run against Python.

**Last Updated**: 2026-07-13

**Investigation**: [INVESTIGATE-service-principal-acting-user.md](INVESTIGATE-service-principal-acting-user.md) — all questions resolved. The merge-vs-replace correctness fix it also surfaced already shipped separately as [`PLAN-context-merge-semantics.md`](PLAN-context-merge-semantics.md); this plan only adds the two new fields and the warning.

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

## Phase 1: Schema and core implementation — DONE

### Tasks

- [x] 1.1 Added `service_principal` and `acting_user` to the shared schema (`tools/validation/schemas/log-entry-schema.json`), both optional, following `client_name`'s exact style.
- [x] 1.2 Added both fields to the `SovdevRequestContext` interface and the `structured_log_entry` interface in `typescript/src/logger.ts`.
- [x] 1.3 Updated `write_log()` to read both new fields from `requestContextStorage.getStore()` and merge them into the log entry when present.
- [x] 1.4 **Critical, learned from `PLAN-context-propagation.md`'s Phase 3 bug**: also added explicit `if (info.service_principal) {...}` / `if (info.acting_user) {...}` blocks to `open_telemetry_winston_transport.log()`'s separate attribute list — the actual OTLP export path, distinct from `write_log()`'s file-log path. This is exactly where `client_name` was silently dropped from OTLP the first time; not repeated here.

### Validation

```bash
cd typescript && npx tsc --noEmit && npm run lint && npm run build
```

All three clean. Proved both fields survive to a **real backend**, in this phase, not deferred: a throwaway script (`sovdev_set_context({ client_name, service_principal, acting_user })` → `sovdev_log(...)` → query directly) run against **both** real UIS and real Grafana Cloud. Identical result on both:

```
client_name: test-client
service_principal: test-db-svc
acting_user: test-acting-user
```

All three fields present via the real OTLP export path on both backends — confirms Phase 1.4's fix actually works, not just that the code compiles.

---

## Phase 2: Grafana Cloud privacy warning — DONE

### Tasks

- [x] 2.1 At `sovdev_initialize()`, check `process.env.OTEL_EXPORTER_OTLP_LOGS_ENDPOINT` for a `grafana.net` substring; cache the result in a module-level flag (`isGrafanaCloudBackend`).
- [x] 2.2 In `sovdev_set_context()`, if `acting_user` is present in the passed-in context and `isGrafanaCloudBackend` is true, print a one-time warning (module-level `hasWarnedAboutActingUser` flag, reset on each `sovdev_initialize()` call) via `console.warn()`, matching the library's existing diagnostic-warning style. Checked in `sovdev_set_context()` rather than `write_log()` — the warning is about the act of setting a potentially-sensitive value, not about each individual log line, and it avoids adding a per-log-call check.
- [x] 2.3 Wording states what's happening (acting_user is set and logs are exported to Grafana Cloud, a third-party service) and why it matters (may contain personal data), plus a concrete recommendation (use a pseudonymous/internal identifier instead).

### Validation

Real test against Grafana Cloud (throwaway script, two `sovdev_set_context({ acting_user })` calls plus one `sovdev_set_context({ client_name })`-only call, in the same process): warning printed exactly once, on the first `acting_user` call only — not on the second `acting_user` call, and not on the `client_name`-only call. Real test against UIS with the identical script: no warning printed at all.

---

## Phase 3: Documentation — DONE

### Tasks

- [x] 3.1 Added a new README section, "Setting `service_principal` and `acting_user` for Database-Backed APIs", right after the existing `client_name` section — covers the service-account vs. customer-facing-JWT scenarios, the zero-opinion pass-through scope boundary, and a "Next Steps" table row pointing to it.
- [x] 3.2 Documented the Grafana Cloud warning explicitly (what triggers it, that it never fires against UIS), and the recommendation to use a pseudonymous/internal ID for `acting_user` regardless of backend.

### Validation

README section added; content matches the design recap above and the shipped Phase 1/2 behavior exactly (field names, optionality, warning trigger condition).

---

## Phase 4: End-to-end validation against real backends — DONE

### Tasks

- [x] 4.1 Extended `company-lookup.ts`'s `sovdev_set_context()` call to include `service_principal` and `acting_user`, and added both to `compare-log-files.py`'s `EXCLUDED_FIELDS`, matching `client_name`'s existing pattern/comment style exactly.
- [x] 4.2 Ran the E2E test against real Grafana Cloud — both fields present in the actual OTLP-exported log entry (queried directly via `tools/validation/grafana-cloud/query-loki.ts`), and the privacy warning fired exactly once in the test run's own output.
- [x] 4.3 Ran the same against real UIS — both fields present (queried directly via `tools/validation/uis/query-loki.sh`), and the warning did *not* fire.
- [x] 4.4 Confirmed schema validation (`run-test.sh`'s built-in validation step) passes on both backend runs, and the cross-language comparator (`compare-with-master.sh python`) still reports a clean match against Python's E2E output with the three TypeScript-only fields excluded.

### Validation

Real query output, both fields, both backends:

```
client_name: company-lookup-e2e-client
service_principal: company-lookup-db-svc
acting_user: company-lookup-e2e-user
```

Grafana Cloud run additionally printed the Phase 2 privacy warning once; UIS run did not print it at all. `compare-with-master.sh python` reported `✅ MATCH — output is identical to TypeScript's` across all 17 log entries, confirming the exclusions work and no unrelated field drifted.

---

## Phase 5: Final checks — DONE

### Tasks

- [x] 5.1 `npx tsc --noEmit`, `npm run lint`, `npm run build` all clean.
- [x] 5.2 Confirmed no regression to `client_name` — real throwaway script, 3 separate `sovdev_set_context()` calls each setting exactly one of the three fields, run against real UIS, extending `PLAN-context-merge-semantics.md`'s 2-field proof to 3.
- [x] 5.3 Rebuilt the Docusaurus site.

### Validation

All three checks clean.

**Caught and fixed a real gap in the validation itself, not just the code**: the first run of the 3-field merge test was executed directly on the host Mac using `test/e2e/company-lookup/.env`, whose `OTEL_EXPORTER_OTLP_LOGS_ENDPOINT=http://host.docker.internal/...` only resolves *inside* the devcontainer. The SDK reported "flushed successfully" regardless — a false positive, the OTLP batch exporter swallows the DNS failure internally rather than surfacing it through `sovdev_shutdown()`. The file log looked correct (all three fields present) even though nothing reached UIS. Confirmed the gap directly: `curl` to `host.docker.internal` from the host Mac returns `Could not resolve host`. Re-ran the identical script via `dct-exec` (inside the devcontainer, where the hostname resolves), then queried real UIS Loki directly — only then confirmed the data actually landed:

```
client_name: merge-test-client
service_principal: merge-test-db-svc
acting_user: merge-test-user
```

Lesson for future validation in this repo: a script's own "success" log lines are not proof of delivery — the wrong network context can make OTLP export silently no-op. Only a direct query against the real backend counts as verified.

---

## Acceptance Criteria

- [x] `service_principal` and `acting_user` both work via `sovdev_set_context()`, confirmed present in real log entries on both Grafana Cloud and UIS.
- [x] Both fields are optional/additive — no impact on existing `client_name`-only integrators.
- [x] The Grafana Cloud privacy warning fires exactly once per process when `acting_user` is set against that backend, and never fires against UIS.
- [x] `client_name`, `service_principal`, and `acting_user` all correctly coexist via the merge mechanism (extends, doesn't regress, `PLAN-context-merge-semantics.md`).
- [x] Both fields reach the *actual OTLP-exported* log entry, verified directly against a real backend in Phase 1 — not assumed from the file log alone.

---

## Files to Modify

- `tools/validation/schemas/log-entry-schema.json`
- `typescript/src/logger.ts`
- `typescript/README.md`
- `typescript/test/e2e/company-lookup/company-lookup.ts`
- `tools/validation/validators/compare-log-files.py` (exclude the new fields from cross-language diffing, same as `client_name`)
