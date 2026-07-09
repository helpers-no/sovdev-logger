# Fix sovdev-logger's OTEL_EXPORTER_OTLP_HEADERS to follow the actual OpenTelemetry standard

Removes sovdev-logger's custom JSON-based `OTEL_EXPORTER_OTLP_HEADERS` handling (both languages) in favor of the actual OTel spec format, fixing a real bug where the current format collides with the OTel SDK's own native env-var parsing and silently drops telemetry for any Basic-Auth-style header.

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Active — Phase 1 and 2 done; Phase 3 (version bump + republish) remains

**Investigation**: [INVESTIGATE-otlp-headers-standard-compliance.md](../backlog/INVESTIGATE-otlp-headers-standard-compliance.md) — full root-cause diagnosis, traced through the actual installed OTel SDK source, not assumed.

**Goal**: Bring `OTEL_EXPORTER_OTLP_HEADERS` handling into line with the OTel spec (comma-separated `key=value` pairs, the W3C Baggage HTTP header format) across the contract doc and both language implementations, and verify the fix against both local UIS (regression) and Grafana Cloud (the case that surfaced the bug).

**Last Updated**: 2026-07-10

---

## Problem Summary

`website/docs/contributor/01-api-contract.md` mandates `OTEL_EXPORTER_OTLP_HEADERS` be JSON. Both `typescript/src/logger.ts` and `python/src/logger.py` correctly implemented that (wrong) contract. The underlying `@opentelemetry/otlp-exporter-base` package independently reads this same, reserved env var name expecting the real spec format — confirmed by reading its actual source. When a header value contains `=` (any Basic Auth token, since base64 padding uses `=`), the SDK's native parser produces a garbage header key that survives an additive merge with the application's explicitly-passed headers, and the HTTP transport throws `ERR_INVALID_HTTP_TOKEN` when trying to set it — caught and logged as a non-fatal warning, silently dropping that flush's telemetry. Reproduced live against Grafana Cloud; local UIS never hit it by coincidence (its `Host` header value has no `=`).

Already published: `@terchris/sovdev-logger@1.0.0` is live on npm with this bug present.

---

## Phase 1: Fix the contract doc and TypeScript (reference implementation)

### Tasks

- [x] 1.1 Fix `website/docs/contributor/01-api-contract.md` — correct the documented format from "must be JSON format" to the real OTel spec (`key1=value1,key2=value2`)
- [x] 1.2 Remove the 3 `JSON.parse(process.env.OTEL_EXPORTER_OTLP_HEADERS)` call sites in `typescript/src/logger.ts` (metrics/traces/logs exporter config) — stop passing an explicit `headers` object, let the SDK's native env-var parsing handle it
- [x] 1.3 Remove the UIS-specific `.includes('Host')` assumption from `sovdev_validate_config` — what headers are actually needed is backend-specific, this check only confirms the variable exists
- [x] 1.4 Add a spec-compliant `parseOtlpHeaders()` helper (comma-separated `key=value`, first-`=`-only split) for this module's own diagnostics (`sovdev_test_otlp_connection`'s `testEndpoint`), which needs *some* parsed representation of the header value but must not use `JSON.parse`
- [x] 1.5 Updated `typescript/test/e2e/company-lookup/.env` and `.env.example` to the new format. `.env.grafana-cloud` fixed directly on disk too. `generate-e2e-env.ts` (on `feat/grafana-cloud-validation`) also fixed and committed there — same header-format bug existed in its generated output.
- [x] 1.6 Updated `uis.md` — removed the "single quotes are load-bearing" explanation for TypeScript (step 4) and added a Troubleshooting entry explaining the historical bug. Python's section (step 6) deliberately left untouched — its code still expects JSON until Phase 2 lands, so documenting the new format there now would describe behavior that doesn't exist yet.
- [x] 1.7 Type-checked clean (`npx tsc --noEmit`). Ran `npx eslint src/logger.ts` too: 1 pre-existing error (`'data' is assigned a value but never used`, unrelated to this change — confirmed via `git stash`/re-lint comparison, same error existed before this fix, just at a different line number) and 27 pre-existing `no-explicit-any` warnings. Not part of this fix's scope.
- [x] Also fixed `05-environment-configuration.md` and `06-test-scenarios.md`'s header examples and single-quote guidance now, ahead of the original Phase 2 scheduling (task 2.4 originally covered this, but these docs are language-agnostic, not Python-specific — no reason to wait)

### Validation

- [x] Re-ran TypeScript's E2E test against local UIS (`dct-exec bash -c "cd /workspace/typescript/test/e2e/company-lookup && bash run-test.sh --skip-validation"`) — **passes, all three flush steps succeed** (regression confirmed)
- [x] Re-ran against Grafana Cloud (`bash run-test.sh --skip-validation --env-file .env.grafana-cloud`) — **the header-format bug is fixed**: no more `ERR_INVALID_HTTP_TOKEN`, flush completes cleanly, confirmed clean across multiple runs (`grep -iE "unauthorized|401|OTLPExporterError"` on full output: no matches). This is the acceptance bar for *this* plan, and it's met.
- [x] The transient `401 Unauthorized` seen mid-investigation was resolved by regenerating the `sovdev-logger-ingest` token (the original one was stale/bad for reasons not fully root-caused — policy scopes were always correct) — confirmed via direct probe (`probe-otlp-ingest.ts`): all three signals return 2xx with the new token.
- [x] User confirms Phase 1 complete — header-format bug fixed and verified; a **separate, deeper mystery** was found while verifying end-to-end (real app telemetry produces zero queryable data in Grafana Cloud despite clean flush + working auth), spun into its own investigation, and now fully resolved — see [`INVESTIGATE-grafana-cloud-otlp-data-loss.md`](../completed/INVESTIGATE-grafana-cloud-otlp-data-loss.md) and its child [`PLAN-fix-grafana-cloud-otlp-data-loss.md`](../completed/PLAN-fix-grafana-cloud-otlp-data-loss.md).

---

## Phase 2: Port to Python and re-verify conformance — DONE

### Tasks

- [x] 2.1 Confirmed empirically whether Python's OTel SDK has the same independent-env-read behavior as the JS SDK — **it does not**. Read the installed `opentelemetry-exporter-otlp-proto-http` source directly (`trace_exporter`, `_log_exporter`, `metric_exporter`, all three `__init__.py`): each does `self._headers = headers or parse_env_headers(environ.get(OTEL_EXPORTER_OTLP_HEADERS, ""), liberal=True)` — an **override**, not JS's additive merge. If an explicit `headers` dict is passed to the constructor, the env var is ignored entirely; `parse_env_headers()` (real spec format) is only ever consulted as a fallback. This means the JS bug's specific mechanism (merge producing a garbage header key, crashing with `ERR_INVALID_HTTP_TOKEN`) **cannot** reproduce in Python — Python never had that live incident.
  - The real motivation for this phase turned out to be different: since Phase 1 corrected `01-api-contract.md` to the real spec format, any contributor who updates their Python `.env` to match (as the corrected doc now instructs) would hit `json.loads()` throwing on a non-JSON string — caught by the surrounding broad `except Exception`, silently disabling all telemetry (metrics/traces/logs) with just a printed warning. This phase closes that latent trap before anyone hits it, rather than fixing an active bug.
- [x] 2.2 Removed the 2 `json.loads(os.environ.get("OTEL_EXPORTER_OTLP_HEADERS", "{}"))` call sites in `python/src/logger.py` (`configure_metrics` line ~688, `configure_opentelemetry` line ~736 — shared between its trace and log exporters). No explicit `headers` dict is passed to any of the three exporters (`OTLPMetricExporter`, `OTLPSpanExporter`, `OTLPLogExporter`) anymore — letting the SDK's own `parse_env_headers()` handle the raw env var, matching the "let the SDK parse it natively" pattern used in the TypeScript fix. (Python has no `sovdev_validate_config`/diagnostic-connection-test equivalent to TypeScript's `testEndpoint()`, so no separate `parseOtlpHeaders()` helper was needed here.)
- [x] 2.3 Updated `python/test/e2e/company-lookup/.env` and `.env.example` from `OTEL_EXPORTER_OTLP_HEADERS={"Host":"otel.localhost"}` to `OTEL_EXPORTER_OTLP_HEADERS=Host=otel.localhost`; updated `.env.example`'s comment block to explain the real-spec format instead of the old JSON-vs-python-dotenv-quoting explanation. (2.4 — `05-environment-configuration.md`/`06-test-scenarios.md` — already done in Phase 1, ahead of schedule.)
- [x] Updated `website/docs/contributor/testing/uis.md` step 6 — header value shown changed to the new format; explanation reframed as "quoting is never load-bearing for Python either way" (was: "this JSON value happens to survive python-dotenv unquoted") since the value is no longer JSON at all.
- [x] Extra (not originally scoped, added at the user's request): verified Python against Grafana Cloud too, not just local UIS. Needed the Grafana Cloud tooling from `feat/grafana-cloud-validation` (not yet merged) — brought `tools/validation/` onto this branch via `git checkout feat/grafana-cloud-validation -- tools/` (working-tree only, not committed here yet — see note below). Found and fixed two gaps along the way:
  - **`python/test/e2e/company-lookup/run-test.sh` had no `--env-file` flag** (TypeScript's got one on the other branch, to point at `.env.grafana-cloud` without overwriting `.env`). Added the same flag; Python's `run-test.sh` sources the chosen file into real shell env vars before invoking `python3`, and since `company-lookup.py`'s `load_dotenv()` defaults to `override=False`, the already-exported vars win — no changes needed to `company-lookup.py` itself.
  - **`python/` had no `.gitignore`** — root `.gitignore` only covers `.env`/`.env.local`/`.env.*.local`, not `.env.grafana-cloud`-style names (TypeScript is covered by its own `typescript/.gitignore`'s `.env.*` pattern). This meant the generated credential-bearing `.env.grafana-cloud` was untracked but **not actually ignored** — a real gap, fixed by adding `python/.gitignore` mirroring TypeScript's pattern before anything got staged.
  - `tools/validation/grafana/generate-e2e-env.ts` needed no changes — it's already language-agnostic (output path + service name are CLI args), and the quoted `Authorization=Basic <token>` value it writes works fine under `python-dotenv` too (which handles quoted values, unlike bash's `source` where quoting was load-bearing).

### Validation

- [x] Re-ran Python's E2E test against local UIS (`dct-exec bash -c "cd /workspace/python/test/e2e/company-lookup && bash run-test.sh"`) — **passes**, all three flushes succeed, 17/17 log entries, correct 3-success/1-failure pattern
- [x] Ran `dct-exec bash -c "cd /workspace/specification/tools && bash compare-with-master.sh python"` — **clean match**, all 17 entries identical to TypeScript's output
- [x] Re-ran `query-loki.sh`/`query-tempo.sh`/`query-prometheus.sh` with `--compare-with` against this run's real output (not relying on a stale pre-fix run) — **17/17 logs, 4/4 traces, 5/5 metric groups**, exact match
- [x] `mypy src/logger.py` — same 4 pre-existing errors as before this change (confirmed via `git stash`/re-run comparison, all four are unrelated `LogRecord` attribute-typing issues elsewhere in the file), zero new errors introduced
- [x] Ran Python's E2E test against Grafana Cloud (`bash run-test.sh --env-file .env.grafana-cloud`) — clean flush, no auth errors
- [x] Re-ran `query-loki.ts`/`query-tempo.ts`/`query-prometheus.ts` (the Grafana Cloud tooling) with `--compare-with` against this run's real output — **17/17 logs, 4/4 traces (after one retry — Tempo indexing lag, same known behavior as TypeScript), 5/5 metric groups**, exact match. Python now verified equivalent to TypeScript on both backends.
- [x] User confirms Phase 2 complete

**Note on cross-branch state**: this Grafana Cloud verification needed `tools/validation/` from `feat/grafana-cloud-validation`, pulled into this branch's working tree but not committed here — that directory's real home is the other branch. `python/test/e2e/company-lookup/run-test.sh`'s new `--env-file` flag and the new `python/.gitignore`, however, are genuine fixes that belong wherever Python's E2E tests live, regardless of branch. Whether/how to reconcile this before either branch merges is an open question, not yet decided.

---

## Phase 3: Version bump and republish — IN PROGRESS

Python has no published package (no PyPI, no `[project]` version in `pyproject.toml`) — this phase is TypeScript-only, matching its original scope.

### Tasks

- [x] 3.1 Version: `1.0.1` — patch, no public API surface change, per [INVESTIGATE-otlp-headers-standard-compliance.md](../backlog/INVESTIGATE-otlp-headers-standard-compliance.md)'s [Q3]
- [x] 3.2 Bumped `typescript/package.json` (and regenerated `package-lock.json` via `npm install --package-lock-only` to keep it in sync) to `1.0.1`; `npx tsc --noEmit` clean
- [ ] 3.3 `npm publish` (maintainer runs this themselves — requires a live npm OTP, same as the original publish)

### Validation

- [ ] `npm view @terchris/sovdev-logger` shows the new version
- [ ] User confirms Phase 3 complete

---

## Acceptance Criteria

- [x] `OTEL_EXPORTER_OTLP_HEADERS` follows the real OTel spec in both TypeScript and Python, and the contract/shared docs
- [x] No `JSON.parse`/`json.loads` remains anywhere this env var is read in either language
- [x] TypeScript E2E test passes against both local UIS and Grafana Cloud (no header-format crash; auth confirmed working via direct probes and the real app run)
- [x] Python E2E test passes against local UIS; `compare-with-master.sh python` reports a clean match; live-verified against Loki/Tempo/Prometheus too (17/17, 4/4, 5/5)
- [x] `INVESTIGATE-grafana-cloud-validator.md`'s ingestion step is unblocked *for auth*, and the separate real-telemetry data-loss issue found during verification is now also resolved — see [`INVESTIGATE-grafana-cloud-otlp-data-loss.md`](../completed/INVESTIGATE-grafana-cloud-otlp-data-loss.md) and its child [`PLAN-fix-grafana-cloud-otlp-data-loss.md`](../completed/PLAN-fix-grafana-cloud-otlp-data-loss.md)

## Files to Modify

- `website/docs/contributor/01-api-contract.md`
- `website/docs/contributor/05-environment-configuration.md`
- `website/docs/contributor/06-test-scenarios.md`
- `website/docs/contributor/testing/uis.md`
- `typescript/src/logger.ts`
- `typescript/test/e2e/company-lookup/.env`, `.env.example`
- `tools/validation/grafana/generate-e2e-env.ts`
- `python/src/logger.py`
- `python/test/e2e/company-lookup/.env`, `.env.example`
- `typescript/package.json` (version bump)
