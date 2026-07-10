# Split sovdev_flush() into a repeatable flush and a one-time shutdown

Fixes a confirmed cross-language divergence and a silent metrics-loss bug: TypeScript's `sovdev_flush()` shuts down the OTel SDK permanently on first call (Python's doesn't), so any repeat call silently stops recording metrics with no error. Adds `sovdev_shutdown()` to both languages as the explicit terminal call, leaving `sovdev_flush()` safe to call repeatedly.

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Completed

**Investigation**: [INVESTIGATE-long-running-server-flush.md](INVESTIGATE-long-running-server-flush.md) — the empirical finding (logs survive a repeat flush, metrics silently don't) and the design decision (split flush/shutdown rather than patch one language in place).

**Goal**: `sovdev_flush()` force-exports only, safe to call any number of times, in both TypeScript and Python. A new `sovdev_shutdown()` does the one-time SDK teardown, called exactly once at true process end. No regressions to either language's E2E test.

**Last Updated**: 2026-07-10

---

## Problem Summary

TypeScript's `sovdev_flush()` calls `.forceFlush()` then `.shutdown()` on every OTel provider — confirmed empirically that after that shutdown, a second `sovdev_log()` call still reaches Loki, but the metric it should increment never reaches Prometheus (verified: raw counter value stays at `1` after two log calls, no error, no warning). Python's `sovdev_flush()` never shuts anything down, so it doesn't have this problem — a real, silent cross-language divergence in what "the same function name" means. Fix: make `sovdev_flush()` force-flush-only in TypeScript (matching Python), and add a new `sovdev_shutdown()` in both languages for the terminal case — TypeScript's own E2E test needs this, since its success path currently relies on `sovdev_flush()`'s `.shutdown()` clearing background timers so Node can exit naturally; removing that without a replacement would make the test hang forever.

---

## Phase 1: TypeScript — split the function, update the E2E test, verify — DONE

### Tasks

- [x] 1.1 In `typescript/src/logger.ts`: removed the `.shutdown()` calls from `flush_sovdev_logs()` (`sovdev_flush`), keeping only the three `.forceFlush()` calls
- [x] 1.2 Added `shutdown_sovdev_logger()`: calls `flush_sovdev_logs()` first (defensive), then `.shutdown()` on the SDK and all three providers
- [x] 1.3 Exported `sovdev_shutdown` from `typescript/src/index.ts` alongside the existing exports
- [x] 1.4 Updated `typescript/test/e2e/company-lookup/company-lookup.ts`: both the success path and the `main().catch()` failure path now call `sovdev_shutdown()`; `DEMONSTRATES` comments and the 9-function list at the top updated to describe the new two-function contract
- [x] 1.5 Rebuilt (`npm run build` in `typescript/`) — clean
- [x] 1.6 Re-ran the double-flush check (now 3 log/flush cycles + a final `sovdev_shutdown()`) against local UIS — Loki shows all 3 markers, Prometheus shows `"value": [..., "3"]` (was stuck at `"1"` before the fix)
- [x] 1.7 Ran the E2E test fresh (`run-test.sh --skip-validation`) — completed in ~4.2s, no hang, exited cleanly via `sovdev_shutdown()`. `compare-with-master.sh typescript` — 17/17 entries match, zero mismatches

### Validation

- [x] Double-flush test shows all 3 log markers AND all 3 metric increments reaching the backend
- [x] `compare-with-master.sh typescript` passes clean
- [x] E2E test's success path still exits naturally (no hang) after switching to `sovdev_shutdown()`

---

## Phase 2: Python — add the mirrored `sovdev_shutdown()`, update the E2E test — DONE

### Tasks

- [x] 2.1 Added `sovdev_shutdown()` to `python/src/logger.py` — force-flushes (calls `sovdev_flush()`), then calls `.shutdown()` on tracer/meter/logger providers. `sovdev_flush()` itself unchanged — it already behaved the way TypeScript's now does.
- [x] 2.2 Exported `sovdev_shutdown` from both `python/src/__init__.py` and `logger.py`'s own `__all__`
- [x] 2.3 Updated `python/test/e2e/company-lookup/company-lookup.py`'s three call sites (success path, `KeyboardInterrupt` handler, general exception handler) from `sovdev_flush()` to `sovdev_shutdown()`, matching TypeScript's updated example
- [x] 2.4 Ran `compare-with-master.sh python` — 17/17 entries match, zero mismatches

### Validation

- [x] `compare-with-master.sh python` passes clean
- [x] Python's E2E test still exits normally — fresh run completed in ~1.8s, `PASS: Expected 17 log entries, got 17`

---

## Phase 3: Documentation — DONE

### Tasks

- [x] 3.1 `typescript/README.md`: documented `sovdev_flush()` (safe, repeatable, non-terminal) vs `sovdev_shutdown()` (call once, at true process end); updated every script-shaped example to use `sovdev_shutdown()` as the terminal call. Left the persistent Azure App Service example on `sovdev_flush()` deliberately (that snippet isn't the true process end), with a clarifying comment added.
- [x] 3.2 `python/README.md`: same update, mirrored
- [x] 3.3 `website/docs/using/onboarding/index.md`: checked — this page never mentions flush/shutdown at all (it's scoped to Grafana Cloud credentials/env vars only), nothing to change
- [x] 3.4 `website/docs/using/onboarding/ollacrm/index.md`: fixed its worked `SIGTERM` example to use `sovdev_shutdown()`, with a note on why `sovdev_flush()` would be wrong there
- [x] 3.5 **Scope expansion, not in the original task list**: swept `website/docs/contributor/*.md` (the actual API contract and spec docs future language ports read) — found and fixed substantive references in `01-api-contract.md` (added a full new numbered section for `sovdev_shutdown`, renumbered sections 6→9), `04-error-handling.md`, `03-implementation-patterns.md`, `07-anti-patterns.md`, `00-design-principles.md`, `05-environment-configuration.md`, `06-test-scenarios.md`, `08-testprogram-company-lookup.md`. Necessary: leaving the spec stale would mean a future Go/C#/Rust/PHP port reads the old, buggy contract.

### Validation

- [x] `npm run build` in `website/` is clean
- [x] No remaining reference anywhere in docs to `sovdev_flush()` as a terminal/shutdown call — final repo-wide grep confirms every remaining mention is intentional (either describing `sovdev_flush()`'s real repeatable behavior, or contrasting it with `sovdev_shutdown()`)

---

## Post-completion validation (maintainer asked directly: was write+read to UIS/Grafana validated for both languages?)

Phase 1/2's validation used `compare-with-master.sh`, which only compares local file logs between languages — it never queries Loki/Prometheus/Tempo, and Python's double-flush safety had only been confirmed by reading the code (it never had the shutdown-coupling bug to begin with), not by running an equivalent empirical test the way TypeScript's fix was verified. Closed both gaps directly:

- **Python double-flush test, mirroring TypeScript's**: 3 log/flush cycles + a final `sovdev_shutdown()`, run against local UIS. Loki: all 3 markers (`MARKER-PY-1/2/3`) present. Prometheus: `sovdev_operations_total` = `"3"`, matching TypeScript's fixed result exactly.
- **Fresh full E2E runs, both languages, queried immediately against all three backends** (not just Loki, which is what earlier spot-checks happened to use): TypeScript and Python each re-run, then Loki/Prometheus/Tempo all queried right after. All three backends show correct data for both languages.
- **Real finding, not a bug**: querying the *original* (much earlier) E2E test runs' Prometheus data returned empty even with a 1-hour range — re-running fresh and querying immediately resolved it. This local OTLP→Prometheus pipeline appears to age out a short-lived process's metrics after some minutes (consistent with the OpenTelemetry Collector's Prometheus exporter default `metric_expiration` behavior) — Loki/Tempo data doesn't show the same aging within the same window. Operationally: validate immediately after a run in this environment, don't rely on data from much earlier in a long session.

---

## Phase 4: Close out — DONE

### Tasks

- [x] 4.1 Updated `INVESTIGATE-long-running-server-flush.md`: Status → Resolved, summary of what shipped, moved to `completed/`
- [x] 4.2 Updated `1PRIORITY.md`
- [x] 4.3 Final `npm run build` (website) clean; final repo-wide grep confirms no stale `sovdev_flush()`-as-terminal-call references remain

---

## Acceptance Criteria

- [x] `sovdev_flush()` is safe to call any number of times, in both languages, with no data loss (verified empirically for TypeScript — 3 log/flush cycles, all 3 markers and all 3 metric increments confirmed reaching Loki/Prometheus)
- [x] `sovdev_shutdown()` exists in both languages, is the documented terminal call, and both E2E tests pass through it without hanging or regressing
- [x] `compare-with-master.sh` passes clean for both languages
- [x] All documentation (both READMEs, both onboarding docs, and the full `contributor/` spec) reflects the new two-function contract — no stale examples showing `sovdev_flush()` as the last call in a script

## Files to Modify

- `typescript/src/logger.ts`, `typescript/src/index.ts`
- `typescript/test/e2e/company-lookup/company-lookup.ts`
- `typescript/README.md`
- `python/src/logger.py`, `python/src/__init__.py`
- `python/test/e2e/company-lookup/company-lookup.py`
- `python/README.md`
- `website/docs/using/onboarding/ollacrm/index.md`
- `website/docs/contributor/01-api-contract.md`, `04-error-handling.md`, `03-implementation-patterns.md`, `07-anti-patterns.md`, `00-design-principles.md`, `05-environment-configuration.md`, `06-test-scenarios.md`, `08-testprogram-company-lookup.md`
- `website/docs/ai-developer/plans/backlog/INVESTIGATE-long-running-server-flush.md` (→ `completed/`)
- `website/docs/ai-developer/plans/backlog/1PRIORITY.md`
