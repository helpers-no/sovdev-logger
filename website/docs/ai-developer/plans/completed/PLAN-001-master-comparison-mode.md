# Feature: Master-Comparison Mode for Cross-Language Conformance

Adds an automated diff between a candidate language's E2E test output and TypeScript's (the master implementation's) output for the same run, closing the one real gap identified in the multi-language conformance investigation.

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Completed

**Completed**: 2026-07-08

**Investigation**: [INVESTIGATE-multi-language-conformance.md](INVESTIGATE-multi-language-conformance.md) — Option B, accepted 2026-07-08

**Goal**: A re-runnable command that proves (or disproves) "candidate language X produces the same output as TypeScript for the same input," reusing the existing schema/test/tool infrastructure rather than replacing it.

**Last Updated**: 2026-07-08

---

## Problem Summary

`specification/tools/` already validates that a *single* implementation's output is well-formed and internally consistent (file → OTLP → Loki/Prometheus/Tempo → Grafana). Nothing compares two implementations' outputs against each other. The one time this comparison happened, it was manual and one-off (`python/llm-work/FINAL_COMPARISON.md`, 2025-10-28) — a hand-written table, never re-run, now 8+ months stale. This let three real bugs (metric-naming, enum-conversion, missing-field) ship undetected until someone happened to check the right Grafana panel.

This plan builds the missing piece: a script that runs TypeScript's and a candidate language's fixed E2E scenario (`08-testprogram-company-lookup.md`), captures both file logs, and diffs them field-by-field — with TypeScript's live output as the permanent answer key, never a stored fixture.

**Explicitly out of scope for this plan** (deferred to `PLAN-002-python-conformance.md`): actually running this against Python and fixing what it finds. This plan only builds and proves the tool works.

---

## Phase 1: Design — comparison boundary, matching strategy, normalization rules

### Tasks

- [x] 1.1 Confirm the comparison boundary is file-log JSON only (`logs/dev.log` / `logs/error.log`, both languages already write these — confirmed present for both TypeScript and Python). Do not add OTLP-wire or Grafana-API comparison in this plan; note it as a possible future extension if file-log comparison proves insufficient. **Confirmed sufficient — see 1.2.**
- [x] 1.2 Reconstruct the historical enum-conversion bug's exact code path. **Confirmed by reading current `python/src/logger.py`:** `level_str = level.value if isinstance(level, SOVDEV_LOGLEVELS) else str(level)` is computed **once**, at each public API entry point (`sovdev_log`, `sovdev_log_job_status`, etc., lines 890/916/944), then passed down into `write_log(level, log_entry)`, which uses that **same string** both to set `log_entry["level"]` (the file log) and to compute `map_to_python_level(level)` (the OTLP severity mapping). One shared conversion feeds both outputs — the historical bug would have corrupted both simultaneously. **File-log-only comparison is sufficient for this bug class**, independently confirmed by the fact that `log-entry-schema.json`'s strict `level` enum would also reject a bad value like `"SOVDEV_LOGLEVELS.ERROR"` outright. The Loki-severity schema gap (Phase 3) remains worth closing as defense-in-depth for the OTLP path specifically, but it is not the only thing that would have caught this bug.
- [x] 1.3 Entry-matching strategy: **position-based**, confirmed sound — `company-lookup.ts`/`.py` execute the same fixed, deterministic sequence of log calls (verified: transaction logs with/without response, one with an exception, `job.status` start/complete, 4× `job.progress`). If entry *counts* differ between the two files, report that as a top-level mismatch before attempting per-entry comparison.
- [x] 1.4 Normalization rules, finalized against the actual schema (`specification/schemas/log-entry-schema.json`'s full field list) and the actual test scripts:
  - **Excluded from comparison** (legitimately/expectedly different per run or per language, not compared at all): `timestamp`, `trace_id`, `span_id`, `event_id`, `session_id` (all per-run values); `service_name` (differs by design — confirmed both test scripts default `OTEL_SERVICE_NAME` to `sovdev-test-company-lookup-{typescript,python}`, a language-specific suffix); `exception_stacktrace` (language-specific formatting/file-paths/frame text will never literally match across languages — check *presence* only: non-empty when `exception_type` is set, not content equality)
  - **Must match exactly**: `level`, `message`, `service_version` (confirmed hardcoded `"1.0.0"` in both test scripts — legitimately comparable, unlike `service_name`), `function_name`, `log_type`, `input_json`, `response_json`, `exception_type`, `exception_message`
  - **`peer_service` — conditionally excluded, refined during Phase 4's real run** (this file's original version had it as a flat "must match exactly" field; that produced false positives the moment real data was compared — see Phase 4.2's peer_service note): `PEER_SERVICES.INTERNAL` resolves at runtime to that same log entry's own `service_name` in both languages, so it inherits `service_name`'s legitimate per-language difference. Only compare `peer_service` when it's *not* self-referential (i.e., a real external ID like `"SYS1234567"`, confirmed to match exactly for those entries) — skip the comparison when both sides show `peer_service == service_name` on their own side, and flag an INTERNAL-resolution mismatch if only one side does.
- [x] 1.5 Name and place the new files: `specification/tests/compare-log-files.py` (the comparison logic, alongside the existing `validate-*.py` validators) and `specification/tools/compare-with-master.sh` (a thin bash wrapper matching the existing `query-*.sh` / `validate-log-format.sh` conventions).

### Validation

User confirms the design decisions above (especially 1.2's finding and 1.3's matching strategy) before implementation starts.

**Phase 1: DONE** — all design decisions confirmed against actual code/schema, not assumed.

---

## Phase 2: Implement the comparator

### Tasks

- [x] 2.1 Wrote `specification/tests/compare-log-files.py`: loads two NDJSON log files, applies the Phase 1 normalization rules, position-matches entries, reports every field-level mismatch (entry index, field name, TypeScript's expected value, candidate's actual value), plus a top-level entry-count-mismatch check. `py_compile` clean.
- [x] 2.2 `--json` output implemented, matching `validate-log-format.py`'s convention exactly (same `Colors`/`print_*` helper shape).
- [x] 2.3 Wrote `specification/tools/compare-with-master.sh <candidate-language>`: locates both log files, verifies both exist with a clear error naming the missing `run-test.sh` step, and invokes `compare-log-files.py` — via `dct-exec` when run from the host (not the legacy hardcoded-container-name pattern the three older scripts still use), directly when already inside the devcontainer. `bash -n` clean; `shellcheck` clean except two infos/warnings that exactly match the pre-existing convention already used by `validate-log-format.sh` (unquoted `${options}` word-splitting, `options="$@"`) — left consistent with the codebase rather than "fixed" into an inconsistent one-off style.
- [x] 2.4 Added **Step 9: Master Comparison** to `specification/tools/README.md`'s validation sequence, explaining why it's the authoritative "identical output" check (Steps 1-8 confirm internal consistency, not cross-language match). Updated `specification/README.md`'s Success Criteria: criterion 5 now requires `compare-with-master.sh {language}` to pass, replacing the old unverifiable "output structure identical to TypeScript reference" bullet.

**Verified against synthetic fixtures before any real devcontainer run** (Phase 4 does the real-implementation run): confirmed the comparator (a) passes when only the excluded/normalized fields differ, (b) catches the historical enum-conversion bug pattern with a precise diagnosis, (c) catches a dropped required field the same way, and (d) reports an entry-count mismatch cleanly rather than crashing or comparing misaligned entries. All four in both human-readable and `--json` modes.

### Validation

```bash
cd /workspace/typescript/test/e2e/company-lookup && ./run-test.sh
cd /workspace/python/test/e2e/company-lookup && ./run-test.sh
cd /workspace/specification/tools && ./compare-with-master.sh python
```
User confirms the command runs and produces readable output (pass or fail) against the current, real Python implementation. **This real-devcontainer run is Phase 4's job** (this session only has host access; Phase 4 requires the actual E2E tests, which need the OTel toolchain and DevContainer-only dependencies).

**Phase 2: DONE** — code written and verified against synthetic fixtures; real-implementation run deferred to Phase 4 as planned.

---

## Phase 3: Close the confirmed Loki severity-validation gap

### Tasks

- [x] 3.1 Added `severity_text` and `severity_number` constraints to `specification/schemas/loki-response-schema.json`'s `stream` definition (the same place `service_name`/`service_version` are already constrained — confirmed via `validate-loki-response.py` that severity fields are checked as *stream labels*, not inside the parsed `log_entry` body). Values grounded in evidence, not guessed:
  - `severity_text`: enum `["TRACE","DEBUG","INFO","WARN","ERROR","FATAL"]` — uppercase, per `specification/02-field-definitions.md`'s documented examples and every JSON example across `03-implementation-patterns.md`/`06-test-scenarios.md`
  - `severity_number`: **typed as a string** matching `^([1-9]|1[0-9]|2[0-4])$` (1-24, OTel's `SeverityNumber` range), **not** a native integer — caught this myself during testing: Loki stream labels are always strings (`map[string]string`), matching this same schema's existing `patternProperties` convention that types every other label as `string`. My first draft used `"type": "integer"`, which would have been a real bug (false negatives on any correctly-typed real Loki response) had it shipped untested.
- [x] 3.2 Verified empirically, no code changes needed: `validate-loki-response.py`'s `Draft7Validator` runs against the whole response (Step 1, before the presence-only check in Step 2), and the schema's `data.result[].items` already `$ref`s the `stream` definition — so the new constraints are picked up automatically.

**Verified against synthetic Loki-response fixtures**: a bad `severity_text` (`"SOVDEV_LOGLEVELS.ERROR"`) is now rejected with a precise diagnosis; a realistic, correctly-typed valid response passes; an out-of-range `severity_number` (`"99"`) is rejected. Schema re-validated as well-formed JSON after editing.

**Phase 3: DONE.**

### Validation

Run `validate-loki-response.py` against a captured Loki response containing a deliberately-wrong `severity_text` (e.g., manually edit a captured JSON fixture to say `"SOVDEV_LOGLEVELS.ERROR"`) and confirm it now fails where it previously would have passed. **Done above, with synthetic fixtures** (no real Loki access from this host session); should be spot-checked once more against a real captured response during Phase 4/`PLAN-002`, but the schema-level behavior is already proven correct.

---

## Phase 4: Prove the comparator actually catches regressions

### Tasks

- [x] 4.1 Sanity check, real devcontainer: built TypeScript (`build-sovdevlogger.sh`) and installed Python's `requirements.txt`, ran TypeScript's E2E test twice independently, compared run 1 against run 2 — **zero mismatches**. No false positives from run-to-run variance.
- [x] 4.1a *(unplanned, discovered during first real cross-language run)* First real TypeScript-vs-Python comparison produced spurious `peer_service` mismatches on every `INTERNAL`-type entry. Root-caused (not just patched around): `PEER_SERVICES.INTERNAL` resolves at runtime to that entry's own `service_name`, confirmed by inspecting raw log entries from both languages. Fixed `compare-log-files.py`'s `peer_service` handling per the updated Phase 1.4 rule above; re-ran and confirmed the false positives were gone while real `peer_service` values (e.g. `SYS1234567`) still compared correctly.
- [x] 4.2 Synthetic regression test, all three historically-documented bugs, each reintroduced in isolation (backed up the real `python/src/logger.py`, swapped in a one-line-modified copy, ran the real E2E test, compared, then restored and verified `diff` showed the file identical again before moving to the next bug — never left the real file mutated). **Result: mixed, and more precise than Phase 1 assumed — see "Correction" below.**
  - **Enum conversion** (`str(level)` instead of `.value`): **caught immediately** — `Entry 11, field 'level': expected 'error' (TypeScript), got 'info'`. Confirms Phase 1.2's finding: this bug's shared code path does hit the file log.
  - **Dots in metric names**: **not observable** in file-log comparison, and was never going to be — metrics are a separate OTel signal that never touches `dev.log`. Confirmed empirically (zero new diffs after reintroducing) and by design (there is no metric data anywhere in a log file).
  - **Missing timestamp in OTLP export**: **not observable** in file-log comparison either, and for the same class of reason — confirmed by reading `write_log()`: the file log is serialized from `log_entry` directly (`JSONFileHandler`, a completely separate code path from the `extra` dict this bug affected, which only ever fed the OTLP/Loki export).
- [x] 4.3 All scratch files and backups removed; `git status` on `python/src/logger.py` confirmed clean (and `diff` against the pre-edit backup confirmed byte-identical) after each of the two real-file swaps, and again at the end. No implementation code changes survive this plan.

### Validation

**Two of the three historically-documented bugs are structurally invisible to file-log comparison — this needed correcting, not just confirming.** Phase 1 and the parent investigation both said file-log comparison "would have caught all three known Python bugs" (see `INVESTIGATE-multi-language-conformance.md`, Option B's pros, and this plan's own original Phase 1.2 framing). That's wrong for two of the three: metric-naming and the OTLP-only timestamp bug never touch a log file at all, by construction — no amount of file-log diffing was ever going to catch them. Only the enum-conversion bug is genuinely file-log-visible (which Phase 1.2's actual code-tracing was correct about, specifically). **Corrected the overclaim in `INVESTIGATE-multi-language-conformance.md`** (see that file's own revision note) rather than let it stand now that it's been empirically tested rather than assumed. File-log comparison remains valuable and worth having — it's just not the complete answer to "identical output," and a future extension to OTLP-payload or metrics comparison (noted as out-of-scope in Phase 1.1) would be needed to close that specific gap.

**Bonus finding, not scratch/synthetic — this is the real, current Python implementation**: comparing today's actual `python/src/logger.py` output against TypeScript's surfaced genuine, previously-undocumented discrepancies (none of the three historical bugs — those are legitimately fixed):
- `response_json` is **completely missing** (not even `null`) on 13 of 17 entries where TypeScript includes it as `null` — a live violation of the documented "always include `response_json`, never omit it" design principle (`00-design-principles.md` decision, `07-anti-patterns.md`'s "DON'T: Conditionally add responseJSON field")
- `exception_message` has a trailing-space difference on both error entries: TypeScript's `"HTTP 404: "` vs. Python's `"HTTP 404:"` (missing space before the empty `statusText`)

These are real findings for `PLAN-002` to fix — not discarded, unlike the synthetic regressions.

---

## Acceptance Criteria

- [x] `specification/tools/compare-with-master.sh <language>` exists, is documented in `specification/tools/README.md`, and runs from inside the devcontainer per the existing tool conventions
- [x] Comparing TypeScript against itself produces zero mismatches
- [x] Of the three historically-documented bug patterns, the one that's actually observable in a file log (enum conversion) is caught with a correct, specific diagnosis when synthetically reintroduced; the other two (metric naming, OTLP-only timestamp) are confirmed — empirically, not assumed — to be outside file-log comparison's reach by construction, and this limitation is now documented rather than silently missed
- [x] `specification/schemas/loki-response-schema.json` constrains `severity_text`/`severity_number`, closing the gap confirmed during the investigation
- [x] No changes made to `python/src/logger.py`, `typescript/src/logger.ts`, or any other implementation code — verified via `git status` and byte-for-byte `diff` after every real-file swap during Phase 4's synthetic testing

**Phase 4: DONE. All phases complete.**

---

## Implementation Notes

- TypeScript is the master, not a stored fixture — the comparator always runs TypeScript's test fresh and diffs against that run's actual output, never a checked-in "golden" log file. This avoids the exact staleness problem `FINAL_COMPARISON.md` had.
- Keep `compare-log-files.py` independent of any single language pair — its interface should be "two log file paths in, mismatch report out," so `compare-with-master.sh go` or `compare-with-master.sh csharp` work identically once those implementations exist, with no changes to the comparator itself.

---

## Files to Modify

- `specification/tests/compare-log-files.py` (new)
- `specification/tools/compare-with-master.sh` (new)
- `specification/tools/README.md` (add new step to validation sequence)
- `specification/README.md` (update Success Criteria)
- `specification/schemas/loki-response-schema.json` (add `severity_text`/`severity_number` constraints)
