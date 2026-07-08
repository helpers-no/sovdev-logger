# Fix: Python conformance — close the two real gaps PLAN-001 found, then promote

Fixes the two genuine, currently-existing discrepancies `PLAN-001`'s master-comparison mode found between Python and TypeScript, re-validates until `compare-with-master.sh python` passes cleanly, then executes the promotion step that's never happened: flipping Python from "📅 Planned" to "✅ Available" in `README.md`, with its own quickstart doc.

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Completed

**Completed**: 2026-07-08

**Investigation**: [INVESTIGATE-multi-language-conformance.md](../backlog/INVESTIGATE-multi-language-conformance.md) — Option C, accepted 2026-07-08

**Prerequisite**: [PLAN-001-master-comparison-mode.md](../completed/PLAN-001-master-comparison-mode.md) — completed, found these bugs

**Goal**: `compare-with-master.sh python` passes with zero mismatches, and `README.md`/`python/README.md` accurately reflect that Python is a real, available implementation — not an LLM's self-declared verdict in a file nobody checks (per the investigation's **[Q6]** decision).

**Last Updated**: 2026-07-08

---

## Problem

`PLAN-001` ran the real, current Python implementation against TypeScript and found two genuine bugs (not the three historical ones — those are already fixed). Both root-caused precisely before writing this plan, not assumed:

### Bug 1: `response_json` dropped entirely on most entries (real library bug)

`python/src/logger.py`'s `JSONFormatter.format()` (line ~172) correctly sets `log_entry["response_json"] = record.response_json`, which is legitimately `None` on most log calls (job status, job progress, errors, and the initial "starting lookup" entries all have no response yet). But line 181 then unconditionally calls:

```python
def remove_undefined_fields(obj: Dict[str, Any]) -> Dict[str, Any]:
    """Remove None fields for cleaner JSON output."""
    return {k: v for k, v in obj.items() if v is not None}
```

This strips **every** `None`-valued key, including the intentionally-`null` `response_json` — this is exactly the anti-pattern `07-anti-patterns.md` already documents ("DON'T: Conditionally add responseJSON field ... Always add responseJSON, value `null` when no response exists"). Confirmed empirically: entries with an actual response value keep the field; entries with `None` lose it entirely.

### Bug 2: `exception_message` trailing-space difference (test script bug, not the library)

Not a `logger.py` bug — the two E2E test *programs* construct their error messages differently:

```typescript
// typescript/test/e2e/company-lookup/company-lookup.ts:151
reject(new Error(`HTTP ${res.statusCode}: ${data}`));
```
```python
# python/test/e2e/company-lookup/company-lookup.py:77
raise Exception(f'HTTP {response.status_code}:')
```

TypeScript includes the raw response body (`data`) after the status code — for this test's 404 response, `data` is an empty string, so the message ends up `"HTTP 404: "` (trailing space, then nothing). Python's version never includes the response body at all, and has no trailing space either. This is a test-scenario inconsistency, not a logger library defect — the fix belongs in `company-lookup.py`, not `logger.py`.

---

## Phase 1: Fix the real library bug (`response_json`)

### Tasks

- [x] 1.1 Removed the `remove_undefined_fields()` call (and the now-dead helper function itself — its only call site) from `JSONFormatter.format()`. Confirmed no other field reaching that dict construction can legitimately be "present but should be null-stripped" — `span_id` and the exception fields are only ever added when they have a real value, so the call was doing nothing correct for anything except wrongly stripping `response_json`.
- [x] 1.2 **Found a deeper issue while auditing `input_json`, not just confirming one**: entries 1 and 17 (the lifecycle-only "Company Lookup Service started/finished" logs) started failing *after* the 1.1 fix — TypeScript's test script calls `sovdev_log(...)` with only 4 positional args for these two calls (no `input_json`/`response_json` at all), and `typescript/src/logger.ts`'s own `remove_undefined_fields` (`value !== undefined`, confirmed by reading it) preserves explicit `null` but omits truly-`undefined` fields. Python's plain `None`-default parameters can't distinguish "caller omitted the argument" from "caller explicitly passed `None`" — both collapse to the same value. Fixed properly with a `_NOT_PROVIDED` sentinel (module-level, documented inline): `sovdev_log()`'s and `.log()`'s `input_json`/`response_json` defaults changed from `None` to `_NOT_PROVIDED`; `create_log_entry()` now only adds the key to `log_entry` when the value isn't the sentinel — omitted when not passed, `null` when explicitly passed as `None`, exactly matching TypeScript's actual (not just documented) behavior. Scoped narrowly to `sovdev_log()` — `sovdev_log_job_status`/`sovdev_log_job_progress` always synthesize a real `input_json` dict internally and have no `response_json` parameter at all, so they were never exposed to this.
- [x] 1.3 Confirmed no regression: `write_log()`'s `if "input_json"/"response_json" in log_entry` checks (unchanged) already correctly handle the new conditional-omission — a key genuinely absent from `log_entry` was always going to be skipped there. `span_id` and exception fields are unaffected (they were never using `_NOT_PROVIDED` and were already only added when a real value existed).

### Validation

```bash
cd /workspace/python/test/e2e/company-lookup && ./run-test.sh --skip-validation
cd /workspace/specification/tools && ./compare-with-master.sh python
```
**Done, against the real devcontainer** (built once for `PLAN-001`, still running): `response_json`/`input_json` mismatches fully gone. `compare-with-master.sh python` now reports only the 2 `exception_message` errors that are Phase 2's scope — confirming this fix is complete and didn't regress anything else.

**Phase 1: DONE.**
`response_json`-related mismatches gone from the output; no new mismatches introduced (e.g., a wrongly-added `span_id: null` on entries that shouldn't have one).

---

## Phase 2: Fix the test-script inconsistency (`exception_message`)

### Tasks

- [x] 2.1 Confirmed empirically before changing anything: made the exact same live request Python's test makes (`GET https://data.brreg.no/enhetsregisteret/api/enheter/974652846`) and checked `response.text` directly — `''` (empty string), matching TypeScript's accumulated `data` for the same request. Updated `company-lookup.py`'s error-raising to `raise Exception(f'HTTP {response.status_code}: {response.text}')`, matching `company-lookup.ts`'s `` `HTTP ${res.statusCode}: ${data}` `` exactly.

### Validation

```bash
cd /workspace/python/test/e2e/company-lookup && ./run-test.sh --skip-validation
cd /workspace/specification/tools && ./compare-with-master.sh python
```
**Done, against the real devcontainer: zero mismatches.** `compare-with-master.sh python` now reports `✅ All 17 entries match TypeScript's output` — the first automated, re-runnable proof of "identical output" this project has ever had.

**Phase 2: DONE.**

---

## Phase 3: Full conformance validation

### Tasks

- [x] 3.1 `compare-with-master.sh python` (via direct comparator invocation, real devcontainer): **zero mismatches**, confirmed at the end of Phase 2 already.
- [x] 3.2 Ran what this environment allows: `run-full-validation.sh python` fails immediately at its `kubectl` cluster check (no Kubernetes/monitoring stack reachable from this session) — expected and out of scope to fix here. Ran the file-log-only validator directly instead: `validate-log-format.py` on `dev.log` passes cleanly (17/17 entries, schema-valid). **Found a real but pre-existing, universal bug while running `--error-log` mode**: `_validate_error_log()` checks `log.get("severity") != "ERROR"`, but the current schema uses `level`/lowercase, not `severity`/uppercase — it fails on *every* log, not just Python's. Confirmed by running the identical check against TypeScript's `error.log`: fails identically. This is a bug in `validate-log-format.py` itself, unrelated to this plan's scope (it doesn't discriminate between implementations — it's broken for the already-"✅ Available" master too) — noted for a future fix, not blocking this plan or casting doubt on Python's conformance. OTLP/Loki/Prometheus/Tempo/Grafana steps were not run (require the Kubernetes stack, unavailable from this session).
- [x] 3.3 Re-confirmed by direct code read (not full re-investigation): metric names still use underscores (`sovdev_operations_total` etc.), enum conversion still uses `.value` not `str()`, and the OTLP `extra` dict still includes `timestamp`. All three historically-documented bugs remain fixed.

### Validation

`compare-with-master.sh python` exit code 0 — **confirmed**. This is the actual, automated "done" signal per the investigation's **[Q6]** decision — not a self-written summary in `python/llm-work/`.

**Phase 3: DONE**, with the caveat noted above: OTLP-backend/Grafana validation wasn't possible from this host-only session (no Kubernetes cluster reachable). File-log conformance — the thing this plan is actually about — is fully verified.

---

## Phase 4: The promotion step (the thing that's never actually happened)

### Tasks

- [x] 4.1 Wrote `python/README.md`, porting `typescript/README.md`'s structure — checked Python's actual public API (`python/src/__init__.py`'s `__all__`) against every code example before writing it, not assumed. **Found two more real, honest-to-document gaps this way**: Python has no `sovdev_validate_config()`/`sovdev_test_otlp_connection()` (TypeScript has both — flagged explicitly in a "Not yet available" section rather than silently omitted or, worse, documented as if they existed), and `sovdev_log()` has no manual `trace_id` override parameter (noted inline). Also caught that `sovdev_flush()` is synchronous in Python, unlike TypeScript's `async` version — every example uses it correctly. **Verified the Quick Start example actually runs**, not just read for plausibility: ran it against the real devcontainer, confirmed console output and the exact JSON file content it produces.
- [x] 4.2 Updated all 7 "Python...Planned" mentions in `README.md` (found by grep, not assumed complete): tagline, Supported Languages table, Choose Your Path list, Quick Start section (added a real Python subsection with install/link, matching TypeScript's), Documentation section, Repository Status. Also fixed an unrelated stale reference found while editing this exact area: `README.md` pointed at a script, `run-company-lookup-validate.sh`, that has never existed in `specification/tools/` — corrected to the real `run-full-validation.sh`/`compare-with-master.sh`. And updated Repository Status's spec version (`v1.1.0` → `v2.0.0`, matching `specification/README.md`'s own current footer) since it was directly adjacent and already stale.
- [x] 4.3 `python/README.md` linked from `README.md` in the same 3 places `typescript/README.md` is (Supported Languages table, Choose Your Path, Documentation section).

### Validation

Re-ran `compare-with-master.sh python` (via direct comparator invocation) one final time after all Phase 4 edits, immediately before considering this done: **zero mismatches, unchanged from Phase 2/3**. Phase 4 only touched docs, not `python/src/`, so this was a sanity check that nothing drifted, not an expectation of new findings.

**Phase 4: DONE. All phases complete.**

---

## Acceptance Criteria

- [x] `compare-with-master.sh python` passes with zero mismatches — confirmed multiple times, most recently after all Phase 4 doc edits
- [x] `python/src/logger.py`'s `response_json`/`input_json` fix doesn't regress genuinely-optional fields — `span_id` and exception fields were never touched by the sentinel change, confirmed by code read
- [x] `python/test/e2e/company-lookup/company-lookup.py`'s exception message construction matches TypeScript's approach (includes response body) — confirmed via a live request that the two now produce byte-identical messages
- [x] `python/README.md` exists and is a real quickstart doc, not a stub — every code example checked against real function signatures, Quick Start example actually run against the real implementation
- [x] `README.md` accurately shows Python as "✅ Available" everywhere it currently said "📅 Planned" — all 7 mentions found by grep, all updated
- [x] The three historically-documented bugs (metric-naming, enum-conversion, OTLP-timestamp) are re-confirmed still fixed

---

## Files to Modify

- `python/src/logger.py` (fix `response_json`/`input_json` handling — removed `remove_undefined_fields()`, added `_NOT_PROVIDED` sentinel)
- `python/test/e2e/company-lookup/company-lookup.py` (fix exception message construction)
- `python/README.md` (new)
- `README.md` (promotion: flipped Python's status in 7 places, plus one unrelated stale-script-name fix found nearby)
