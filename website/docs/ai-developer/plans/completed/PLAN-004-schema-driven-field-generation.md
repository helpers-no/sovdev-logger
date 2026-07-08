# Generate field-name constants from the schema instead of hand-typing them

Builds a generator that reads `specification/schemas/log-entry-schema.json` (the single source of truth for field names) and emits a per-language constants module, so a new language implementation gets correct, typo-proof field names by construction — the exact step where the historical dots-vs-underscores-style bugs originate — rather than an LLM retyping `service_name`, `trace_id`, etc. by hand from prose. Scope is narrower than the original one-line backlog description once verified against the actual code: see "Problem" for why this isn't a blind refactor of both existing implementations.

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Completed

**Completed**: 2026-07-08

**Investigation**: [INVESTIGATE-multi-language-conformance.md](../backlog/INVESTIGATE-multi-language-conformance.md) — Option E, accepted 2026-07-08 as a fast-follow once PLAN-001 exists

**Prerequisite**: [PLAN-001-master-comparison-mode.md](PLAN-001-master-comparison-mode.md) — completed; `compare-with-master.sh` is what lets any adoption of generated constants be verified rather than trusted blindly

**Goal**: A generator exists that turns `specification/schemas/log-entry-schema.json` into a per-language field-name constants module. It's validated against both current implementations (schema↔code parity, not a forced refactor). Python — where hand-typed string dict keys are a real bug vector — adopts the generated constants, verified with zero regression via `compare-with-master.sh`. TypeScript does not, for a documented reason, not a silent omission. `specification/implementation-guide.md` is updated so any future language (Go, C#, Rust, PHP) runs the generator as its first implementation step.

**Last Updated**: 2026-07-08

---

## Problem

Confirmed by reading the actual code before scoping this plan, not assumed from the investigation's one-line description:

### The investigation's own framing already flags this as narrower than it sounds

Option E's own "Cons" section says it plainly: "precisely one of the three documented bugs is a naming bug" — it doesn't cover the enum-to-string conversion bug (a value bug) or the missing-field bug (a completeness bug). Both stay squarely `compare-with-master.sh`'s job. This plan only targets the naming-bug class.

### `log-entry-schema.json` has 17 field properties — that's the actual generation surface

`specification/schemas/log-entry-schema.json` defines exactly 17 properties (`timestamp`, `level`, `message`, `service_name`, `service_version`, `peer_service`, `session_id`, `function_name`, `log_type`, `trace_id`, `span_id`, `event_id`, `input_json`, `response_json`, `exception_type`, `exception_message`, `exception_stacktrace`). This is the only schema with field *names* to generate from — `prometheus-response-schema.json`/`loki-response-schema.json`/`tempo-response-schema.json` validate response *structure*, not implementation-side field names.

**Metric names are explicitly out of scope**: `sovdev_operations_total` etc. don't appear in any schema today — generating them would mean writing a new schema first, which is new spec-writing, not "reading data that's already correct" (Option E's own stated approach). Separately, [PLAN-003](PLAN-003-spec-scaffolding-cleanup.md) already found the "dots in metric names" concern doesn't hold in practice — the OTel Collector's Prometheus exporter sanitizes them regardless of what the SDK emits — so there's no live bug here to prevent.

### TypeScript's field names are unquoted object-literal keys — the target bug class can't occur there the way it can in Python

Checked directly: `typescript/src/logger.ts` writes field names as bare object keys (`service_name: value`, 81 occurrences via `grep -cE '\b(service_name|...)\s*[:=]'`) — valid JS identifier syntax, which means a stray dot (`service.name`) is a **syntax error**, not a silently-wrong string. `python/src/logger.py`, by contrast, writes them as **string literals** (`log_entry["service_name"]`, 75 occurrences via grep) — exactly the kind of value where a typo or a dot silently produces a wrong-but-valid string, which is the actual failure mode this plan exists to prevent.

This means generating constants and forcing TypeScript to use them (e.g., via computed property syntax, `[FIELDS.SERVICE_NAME]: value`) would trade a currently-safe, idiomatic pattern for a less-readable one, for a bug class the language's own grammar already rules out. Refactoring Python's field-name string literals into generated constants has real value; doing the same to TypeScript's bare keys does not, once checked against the actual code rather than assumed to apply symmetrically.

**Revised scope, before implementation starts, based on this**: build the generator once, targeting any language's syntax; validate it (schema↔code parity) against both current implementations without forcing a refactor of either; adopt it for real in Python only, where the risk it addresses is real; document, not silently skip, the TypeScript decision; make the generator a required first step for genuinely new languages (Go, C#, Rust, PHP), which is where the investigation's own stated benefit — "future languages get correct field names by construction" — actually lives.

---

## Phase 1: Build the generator

### Tasks

- [x] 1.1 Wrote `specification/tools/generate-field-constants.py`: reads the schema's `properties` keys via `json.load` (dict order = declaration order, confirmed), renders either a Python `class FieldNames:` (`python/src/field_names.py`) or a TypeScript `export const FieldNames = {...} as const;` (`typescript/src/fieldNames.ts`).
- [x] 1.2 Naming convention is `field_name.upper()` — one line, applied uniformly, no per-field table.
- [x] 1.3 `--check` mode implemented: reads the existing output file, renders what it would currently produce, compares as strings, exits 1 with a `STALE:`/`MISSING:` message on mismatch, 0 with an `OK:` message (including the field count) otherwise. Writes nothing in `--check` mode.

### Validation

```bash
python3 specification/tools/generate-field-constants.py --lang python --check
python3 specification/tools/generate-field-constants.py --lang typescript --check
```
**Phase 1: DONE.** Both generate exactly 17 constants (`timestamp` through `exception_stacktrace`, matching the schema's `properties` count exactly — verified with a standalone `json.load` count first, since an earlier draft of this plan said 18 before that was checked and corrected here). Confirmed the generator runs with no devcontainer/OTLP dependency. Confirmed `--check` actually detects drift, not just always passing: appended a stray line to the generated TypeScript file, `--check` correctly reported `STALE` (exit 1), then passed again (exit 0) after regenerating.

---

## Phase 2: Validate the generator against both current implementations (no refactor yet)

### Tasks

- [x] 2.1 Schema↔code parity for Python, checked at both write sites (`create_log_entry()`, which builds the dict passed via `extra=`, and `JSONFormatter.format()`, which independently reconstructs the same 17 fields from the `LogRecord` to serialize `dev.log`): all 17 accounted for — 10 unconditional (`timestamp`, `level`, `message`, `service_name`, `service_version`, `peer_service`, `function_name`, `log_type`, `trace_id`, `event_id`), 5 conditional-but-present (`span_id`, `input_json`, `response_json`, `exception_type`, `exception_message`, `exception_stacktrace` — via `hasattr`/`_NOT_PROVIDED` checks), and `session_id` legitimately absent from every file-log entry by design (only ever appears in the OTel `Resource` construction, matching the schema's own `"comment"` field verbatim). No extra field name used in either write site that isn't one of the 17.
- [x] 2.2 Same check for TypeScript's `create_log_entry()` (line 396) — the same 17-field pattern: `level` is deliberately omitted from this object (Winston adds it at `.log(level, entry)`), `span_id` added later in `write_log()`, `input_json`/`response_json` dropped when `undefined` via `remove_undefined_fields()` (matches PLAN-002's finding of TS's own `undefined`-vs-`null` semantics), exception fields spread conditionally, `session_id` resource-only (identical pattern to Python, same schema comment). Full parity confirmed.
- [x] 2.3 No parity gap found in either direction. This is also independently corroborated: `validate-log-format.py`'s schema check (`additionalProperties: false`) already passes for both languages (confirmed in PLAN-001/002), which rules out either implementation silently writing a field name absent from the schema — Phase 2 additionally confirms the reverse direction (no schema field silently unused by either implementation).

### Validation

Cross-checked both write sites per language against the schema's `required` list (10 fields) vs. optional fields (`session_id`, `span_id`, `input_json`, `response_json`, `exception_*`) — every "optional" field's absence on some code paths is legitimate (e.g. `exception_type` only on ERROR/FATAL paths, `session_id` never in file logs by design), not a bug. **Phase 2: DONE**, zero gaps found — both implementations already have correct field-name coverage; this phase validates the generator would have nothing to fix, not that it found something broken.

---

## Phase 3: Adopt generated constants in Python (the language where it matters)

### Tasks

- [x] 3.1 Refactored all 72 field-name string-literal occurrences in `python/src/logger.py` to `FieldNames.CONSTANT` (imported from the new generated `field_names.py`), one field at a time via exact-string `replace_all` per constant (17 passes) rather than a blanket regex — each pass grep-verified beforehand to confirm every occurrence of that exact quoted token was a genuine field-name usage (dict key or `getattr`/`hasattr`/`in` check), not a false positive. Two docstring lines describing the JSON *output* (not code) were reworded first so the mechanical replace wouldn't turn readable prose into `FieldNames.INPUT_JSON: null`-style text. Correctly left untouched: `self.service_name`/`self.service_version` (object attributes, not string literals) and `"log_level"` (a Prometheus metric label name — not one of the 17 schema fields, confirmed distinct from `"level"`).
- [x] 3.2 Ran the Python E2E test before and after the refactor (real devcontainer), diffed all 17 entries field-by-field excluding the fields that legitimately vary per run (`timestamp`, `trace_id`, `span_id`, `event_id`) — **0 mismatches**. The refactor is byte-for-byte behaviorally invisible.
- [x] 3.3 Ran `compare-with-master.sh python` against a fresh TypeScript run — **0 errors, 0 warnings, all 17 entries match**.

### Validation

```bash
python3 -m py_compile python/src/logger.py   # confirmed clean
# before/after E2E diff (excluding timestamp/trace_id/span_id/event_id): 0 mismatches across 17 entries
cd specification/tools && ./compare-with-master.sh python
```
**Phase 3: DONE.** `compare-with-master.sh python` — `✅ MATCH — output is identical to TypeScript's`, `Errors: 0`, `Warnings: 0`. The refactor is invisible from the outside; only the source changed.

---

## Phase 4: Wire the generator into the implementation process for future languages

### Tasks

- [x] 4.1 Added the generator as new step 2 in `specification/implementation-guide.md` (renumbering the rest 3-8), before "study TypeScript" — reads the 17 field names straight from the schema, with guidance to add a new renderer to the generator itself (not hand-type) if the target language isn't supported yet.
- [x] 4.2 Documented the TypeScript non-adoption decision inline in step 2 itself (not a separate, easy-to-miss note): bare object-literal keys already make a stray dot a syntax error, so generated constants add less value there, with a link to this plan for the full reasoning. Also updated step 7 (the comparison-mode step) to note it's complementary to, not redundant with, this step — the two catch different bug classes.
- [x] 4.3 Added `compare-with-master.sh` (missing from the Quick Reference table since PLAN-001 shipped it — fixed as an adjacent stale-doc finding, not new scope) and `generate-field-constants.py` to `specification/tools/README.md`'s Quick Reference table. Also fixed a stale link found in the same section: Step 9's "see PLAN-001" pointed at `plans/active/`, which no longer exists — PLAN-001 has been in `plans/completed/` since it merged.
- [x] 4.4 **Mid-phase finding**: Phase 1's generated `typescript/src/fieldNames.ts` was still sitting in the actual master implementation's source tree, unimported, since TypeScript doesn't adopt it (Phase 3 scope). Shipping unused generated code into `typescript/src/` — as opposed to a doc-only demonstration — would be dead code in the one implementation everything else is verified against. Deleted it; the generator's ability to render TypeScript syntax was already proven by Phase 1's `--check` cycle (deliberately-corrupted-then-regenerated test) and doesn't require a persisted, unused artifact to remain true. Re-ran `compare-with-master.sh python` (still 0 errors/warnings, all 17 match) and the Docusaurus build (clean) after all doc edits.

### Validation

```bash
cd specification/tools && ./compare-with-master.sh python
cd website && npm run build
```
**Phase 4: DONE.** `compare-with-master.sh python` — `✅ MATCH`, 0 errors, 0 warnings. `npm run build` — `[SUCCESS] Generated static files in "build"`.

---

## Acceptance Criteria

- [x] `specification/tools/generate-field-constants.py` exists, generates all 17 field-name constants (Python proven and shipped; TypeScript proven capable via `--check` but not persisted, since it's unused — see Phase 4.4), and has a `--check` mode
- [x] Schema↔code parity confirmed for both current implementations — zero gaps found in either direction
- [x] `python/src/logger.py` uses generated constants instead of hand-typed field-name string literals, verified byte-identical output before/after and zero `compare-with-master.sh` regressions
- [x] The TypeScript non-adoption decision is documented, not silently skipped (`implementation-guide.md` step 2)
- [x] `specification/implementation-guide.md` requires running the generator as an early step for any new language
- [x] `website/docs/` builds cleanly after all doc edits

---

## Files to Modify

- `specification/tools/generate-field-constants.py` (new)
- `python/src/logger.py` (refactored to use generated constants, 72 occurrences)
- `python/src/field_names.py` (new, generated)
- `specification/implementation-guide.md` (generator step added as step 2, TypeScript decision documented, step 7 cross-referenced)
- `specification/tools/README.md` (tool reference entries for `compare-with-master.sh` and `generate-field-constants.py`, stale PLAN-001 path fixed)
