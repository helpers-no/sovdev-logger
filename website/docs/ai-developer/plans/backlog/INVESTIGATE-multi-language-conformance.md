# Investigate: What it actually takes to ship a second sovdev-logger language

Why a year of TypeScript-plus-specification work never produced a second shipped language implementation, and what to do differently now that the model doing the implementation work is far more capable than the one that started this project.

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Backlog — recommendation accepted, drafting child PLANs next

**Goal**: Decide how sovdev-logger actually reaches "identical output across languages" — using Python as the first real test case, since it already exists, was once self-declared complete, and has been sitting untouched for over eight months.

**Last Updated**: 2026-07-08 (maintainer answered all questions below and accepted the recommendation — see "Decisions" section)

---

## Questions to Answer

1. **[Q1]** Why did the Python implementation, which its own working notes declared "complete, validated, production-ready" with "no outstanding issues," never get promoted to `README.md`'s "✅ Available" status the way TypeScript did? — **Decided:** not worth root-causing further. "Let's do Python again" — take the existing implementation and get it actually verified and shipped this time, rather than continue diagnosing why it stalled.
2. **[Q2]** Why did the Go and C# attempts leave essentially no trace — Go was demoted to `terchris/implementation-tests/go/` before Python was even started, and C# left no code anywhere, only a commit message referencing lessons learned? — **Decided:** the model available a year ago simply couldn't translate to these languages reliably. (Note: this doesn't conflict with the recommendation below — whether the root cause was model capability or a missing verification gate, adding an automated comparison mode and a real promotion step fixes the outcome either way.)
3. **[Q3]** Is writing documentation (patch the implementation, add a warning paragraph to the spec) actually preventing bug recurrence, or just recording it? — **Decided: doesn't matter now.** Given Q2's answer (the real blocker was model capability, now resolved by a better model), this question is moot going forward — the plan is to verify with automated comparison regardless of what the documentation does or doesn't prevent.
4. **[Q4]** The specification has grown to 56 files, ~15,459 lines of prose plus 7,203 lines of validation code (~22,662 lines total) — is the size itself now a source of missed requirements? — **Decided:** it was early days and experimentation, not a fundamental problem. Still worth trimming the now-redundant parts (Option D), but not treated as evidence of a deeper process failure.
5. **[Q5]** Is there really no automated check that two implementations produce the same output? — **Confirmed by the maintainer** ("I think there are scripts and code that validates the output") **and by direct code inspection** — see "What the validation code actually does" below. The scripts exist and are substantial (7,203 lines); what's missing is narrower than originally assumed.
6. **[Q6]** What does "done" actually mean for a language implementation? — **Decided:** done means it produces the same output as TypeScript, and the validation scripts/code prove it — not an LLM's self-declared verdict in a file nobody checks. This is now the project's definition of "done," not just this investigation's recommendation.
7. **[Q7]** Should Python be fixed and finished before any new language is attempted? — **Decided: yes.** Python must pass before Go, C#, Rust, or PHP are attempted (or re-attempted).
8. **[Q8]** — **Resolved, see "What the validation code actually does" below.** Given `specification/schemas/`, `specification/tests/`, and `specification/tools/` already total 7,203 lines of real, working validation code, is the missing piece really "build a conformance harness from scratch" (as originally framed in Option B), or something much narrower already sitting on top of infrastructure that mostly exists? **Answer: the latter** — see below.

---

## Decisions

All open questions above are now resolved by the maintainer. In summary:

- **Redo Python** (don't keep diagnosing why it stalled) — reuse the existing `python/src/logger.py`, fix it forward rather than rewrite from scratch, since it's already ~90% there per its own (unverified) notes.
- **"Done" is redefined, project-wide:** an implementation is done when its output matches TypeScript's and the validation scripts/code prove it — not when an LLM says so.
- **Python is the gate:** no other language (Go, C#, Rust, PHP) starts or restarts until Python passes under this new definition of done.
- Spec bloat and the Go/C# false starts are attributed to early-stage experimentation and prior model limitations respectively — noted, not treated as requiring deep process changes beyond Option D's scoped trim.

This confirms the recommendation below as accepted. Proceeding to draft the child PLANs.

---

## Current State

### What exists and what doesn't

| Language | State | Evidence |
|---|---|---|
| TypeScript | Shipped, **master implementation** — the authority every other language must match, not one peer among equals | `typescript/src/logger.ts` (1,778 lines), listed "✅ Available" in `README.md`, 23 commits |
| Python | Implemented once (Oct 15–30, 2025), self-declared complete, **never shipped** | `python/src/logger.py` — 1,079 lines at its initial commit (Oct 28), 1,103 lines currently after one further edit for lint compliance two days later (Oct 30, its last touch, 8+ months ago) — plus 5 `llm-work/*.md` docs claiming success; still listed "📅 Planned" in `README.md`; 7 commits total. Note: the Oct 30 edit changed the file *after* it was declared "complete, validated" on Oct 28, and was never itself re-validated. |
| Go | Attempted, then archived before Python even started | Added in commit `d0e643b`, moved wholesale to `terchris/implementation-tests/go/` six days later (`ff12276`, "moved go and python") |
| C# | Attempted, zero surviving artifacts | Only evidence is commit `d32fd41`, "Improve LLM implementation process based on C# sessions 3 & 4 learnings" — no `csharp/` folder ever existed in this repo |
| Rust, PHP | Never attempted | — |

### The specification grew faster than any implementation

- `specification/`: 37 commits, 56 files. **15,459 lines are markdown/prose**; a further **7,203 lines are functional code** (schemas + tests + tools — see the precise breakdown two sections below) that the markdown figure doesn't include. Total across both: ~22,662 lines, vs. **1,885 lines across all of `typescript/src/`'s 4 files** (of which 1,778 are `logger.ts` alone — the figure quoted in the table above, which covers just that one file).
- `specification/llm-work-templates/` alone (the ROADMAP/task-template/enforcement scaffolding): 17 files, ~6,596 lines (765 of them shell scripts, the remaining 5,831 markdown) — and it didn't exist until **three days after** Python's "complete" declaration (created 2025-10-31, Python declared done 2025-10-28). It was built partly *in response to* the Python attempt's problems, then never applied back to Python.
- Version stamps inside the specification are inconsistent: `specification/README.md` claims "Specification Status: v2.0.0 COMPLETE" (2025-11-08), but 8 of the 9 numbered documents that carry an explicit "Document Status" footer at all (`00-design-principles.md`, `02-`, `03-`, `04-`, `05-`, `06-`, `07-anti-patterns.md`, `08-`) are individually stamped "v1.0.0 COMPLETE, 2025-10-27" — only `01-api-contract.md` was bumped ("v1.1.0, 2025-11-12"). Two further numbered docs, `09-development-loop.md` and `10-code-quality.md`, have **no "Document Status" footer at all** — not merely un-bumped, but never stamped in the first place. Nobody reconciled any of this when the top-level version moved to v2.0.0.

### The recurring-bug pattern

All three concretely-documented Python bugs share a shape: **a language-specific gotcha that produces syntactically valid but semantically wrong output**, invisible until someone looks at Grafana:

- `sovdev.operations.total` (dots) vs `sovdev_operations_total` (underscores) — metric silently doesn't appear in Prometheus
- `str(SOVDEV_LOGLEVELS.ERROR)` → `"SOVDEV_LOGLEVELS.ERROR"` vs `.value` → `"error"` — error logs silently appear as INFO severity
- Missing `timestamp` field sent to OTLP — Grafana table column silently empty

Each was caught only because a human (or the AI) happened to check the specific Grafana panel affected. None of them would show up in `python/test/e2e/company-lookup`'s own console output as a failure — the test "passed" while producing wrong data.

**Checked precisely against today's schemas, not assumed:** `specification/schemas/log-entry-schema.json` restricts the file log's `level` field to a strict enum (`trace/debug/info/warn/error/fatal`) — so if a bad value like `"SOVDEV_LOGLEVELS.ERROR"` ever reached the *file* log, `validate-log-format.py` would already reject it today. But the bug as actually documented (`ISSUES_AND_FIXES.md`, `python/src/logger.py:874,901,929`) was in the OTLP severity mapping specifically, not necessarily the file log — and `specification/schemas/loki-response-schema.json` **does not constrain `severity_text` or `severity_number` at all** (confirmed by inspecting the schema — no such properties are defined). So this specific bug's actual failure path has a real, still-open validation gap today, not just a historical one already closed by existing schemas.

### What the validation code actually does (verified by reading it, not assumed)

This turned out to be more substantial than the first pass of this investigation gave it credit for. Breaking `specification/` down by what's prose vs what's functional code:

| Category | Files | Lines | Nature |
|---|---|---|---|
| Numbered spec docs (`00`–`10` + `README.md`) | 12 | 8,475 | Prose — design philosophy, API contract, field definitions, anti-patterns |
| `llm-work-templates/` | 17 | 6,596 (765 `.sh` + 5,831 `.md`) | Mostly prose — ROADMAP template, 13 per-task instruction files, "enforcement" checklists |
| `schemas/` | 5 | 826 (617 JSON + 209 README) | **Functional** — JSON Schema Draft 7 contracts |
| `tests/` | 8 | 2,955 (2,742 Python + 213 README) | **Functional** — schema + business-rule validators |
| `tools/` | 14 | 4,575 (3,844 Bash + 731 README) | **Functional** — an 8-step validation sequence: file-log validation → OTLP-to-backend consistency (Loki/Prometheus/Tempo) → Grafana-datasource-proxy consistency → visual dashboard check, each with 3 modes (query-only / +schema / +consistency) |

**The `schemas` + `tests` + `tools` total — 7,203 lines — is real, working validation code**, not aspirational documentation. It rigorously checks that a *single* implementation's output is well-formed and internally consistent all the way through the pipeline (file → OTLP → Loki/Prometheus/Tempo → Grafana). Read closely: `query-loki.sh --compare-with logs/dev.log` and its Prometheus/Tempo siblings already do exactly this — compare what a backend received against what the implementation's own file log recorded. This is a serious, working answer to "did *this* implementation export what it logged."

**What it does not do, confirmed by reading `tools/README.md`'s own description of its strategy:** TypeScript is used there only as an infrastructure health check ("ALWAYS verify TypeScript works before starting new language implementation... TypeScript fails → infrastructure problem; TypeScript passes → infrastructure is healthy"). Nothing runs TypeScript and a candidate language side by side and diffs their actual field values against each other. That comparison happened exactly once, by hand: `FINAL_COMPARISON.md`. It's a markdown table, not a script — produced once, never re-run, already 8+ months stale.

**So the real gap is narrow, not "build a harness from scratch":** add one new comparison mode — call it `--compare-with-master` or similar — to the existing tools, that runs TypeScript and the candidate through the same fixed E2E scenario in one session and diffs the candidate's captured output against TypeScript's, field by field, the same way `--compare-with` already diffs a backend against a file. This reuses essentially all 7,203 lines of existing validation code and schemas; it does not replace them.

### TypeScript is the master, not a peer reference

Confirmed: TypeScript isn't "a reference implementation" in the sense of one interchangeable example among several — it's the master. Every other language conforms to *it*, not to an independently-maintained spec-only ideal, and not to a stored fixture that could itself drift out of sync with what TypeScript actually does today. This matters for how any conformance mechanism should work (see Option B): the comparison target should always be TypeScript's live, actual output for the same run — never a separately-maintained "golden file" that has to be remembered and kept in sync by hand.

---

## External Research: How Others Have Solved This

Requested explicitly: it's been over a year since this project started, and worth checking whether the wider field has moved. It has, in ways directly useful here.

### OpenTelemetry itself already solved the "consistent field names across N language SDKs" problem — and not by writing more prose

**[Weaver](https://github.com/open-telemetry/weaver)**, the OpenTelemetry project's own tool, exists for exactly the class of bug this investigation keeps finding (dots vs underscores in metric names, mismatched field names between languages). Weaver takes semantic conventions defined **once**, in YAML, and generates the language-specific constants/code for every SDK from that single schema — "every supported OpenTelemetry SDK benefits from auto-generated constants and code in their native language, ensuring no typos or inconsistencies" ([OpenTelemetry blog](https://opentelemetry.io/blog/2025/otel-weaver/)).

This is a materially stronger fix than anything in this investigation's options so far. Options B/C so far only *detect* a field-name mismatch after an implementer hand-types it wrong. Weaver's approach makes that class of bug **structurally impossible**: the field name constants (`sovdev_operations_total`, `service_name`, `trace_id`, etc.) would be generated from `specification/schemas/*.json` (which already exist and already encode the exact snake_case names required) rather than retyped by hand — in prose, by an LLM, in a new language — every time. Precisely one of the three concretely-documented Python bugs — dots-in-metric-names — is exactly this failure mode, and would be prevented outright rather than merely caught. (The other two, enum-to-string conversion and a silently omitted field, are *value* and *completeness* bugs, not naming bugs — generated constants wouldn't have prevented either; they still need Option B's comparison to catch. See "What this changes in this investigation," below, and Option E's cons.)

### "Golden Master" / "Characterization" testing is the established name for what Option B already proposed

This is a decades-old, named technique (coined by Michael Feathers): capture a system's actual output for given inputs as the "golden master," then diff future runs (or, in porting scenarios, a *different implementation's* runs) against it ([Wikipedia](https://en.wikipedia.org/wiki/Characterization_test); [understandlegacycode.com](https://understandlegacycode.com/blog/characterization-tests-or-approval-tests/)). The `ApprovalTests` framework family has ports to a wide range of languages specifically because this pattern comes up constantly in porting work. This validates Option B's shape as a well-trodden path, not a novel invention — and confirms the standard caveat already reflected in this investigation's design: "volatile and non-deterministic values need to be masked or removed" (exactly why timestamps/trace-IDs/event-IDs must be normalized before comparison).

### Very recent (Dec 2025) academic work: multi-agent translate → test → refine loops

**[BabelCoder](https://arxiv.org/abs/2512.06902)** (arXiv, Dec 2025) is a three-agent system — a Translation Agent, a **Test Agent** that generates inputs and derives correctness oracles from the *source* implementation, and a Refinement Agent that repairs bugs the Test Agent finds. It reports 94% average accuracy, beating prior methods by 0.5–13.5%. The structurally relevant idea: don't rely on one fixed, hand-written E2E scenario (`08-testprogram-company-lookup.md`'s single company-lookup case) — have the harness (or an agent) generate a broader range of test inputs and derive expected outputs from TypeScript automatically, the same way BabelCoder's Test Agent derives oracles from source code. This would catch edge cases a single fixed scenario can't (e.g., error paths, batch/job logging, missing-response cases) — several of which sovdev-logger's own field-definitions already call out as required behavior (`response_json` must always be present as `"null"`, never omitted) but which the current single E2E scenario may not exercise.

### PLDI 2025 / Amazon Science: chunked translation + I/O-equivalence + explicit "feature mapping" tables

**["Scalable, Validated Code Translation of Entire Projects using Large Language Models"](https://dl.acm.org/doi/10.1145/3729315)** (PLDI 2025; tool: Oxidizer, Go→Rust) addresses the same "how do we know the translation is actually correct" problem at the whole-project scale, and lands on two ideas directly applicable here:

1. **Fragment/function-level I/O-equivalence checks**, not just whole-program E2E comparison — translate and validate one function at a time by running the same inputs through both and comparing outputs, which scales better and localizes failures faster than a single end-to-end scenario. Relevant if `typescript/src/logger.ts` (1,778 lines) keeps growing.
2. **"Feature mapping"** — a structured, explicit table of known per-language translation gotchas, fed into the translation process as a first-class artifact rather than prose scattered across multiple documents. This is exactly the *technical content* already in `07-anti-patterns.md`'s "Implementation Process Pitfalls" (dots-vs-underscores, `str(enum)` vs `.value`, missing Grafana fields) — validating that this content is worth keeping, just in a tighter, table-driven form rather than narrated examples repeated across `ISSUES_AND_FIXES.md`, `FINAL_COMPARISON.md`, and `07-anti-patterns.md` independently.

### What this changes in this investigation

- **Adds a new, stronger option (E, below)**: generate field-name/schema constants for each language directly from `specification/schemas/*.json`, Weaver-style, instead of relying on prose + hand-typing. This prevents a whole bug class rather than detecting it after the fact.
- **Refines Option B**: the comparison shouldn't be limited to the single fixed company-lookup scenario — broaden it with generated or additional test cases covering error paths and edge cases the field definitions require (informed by BabelCoder's oracle-generation idea), and consider function-level checks in addition to full-E2E (informed by Oxidizer).
- **Softens Option D's scope on `07-anti-patterns.md` specifically**: its *technical content* (the actual gotcha-to-fix mappings) is validated as the right kind of artifact by the "feature mapping" research — it should survive as a tight, structured table, not be cut wholesale. What should still go is the narrative repetition of the same three bugs across three separate files, and the `llm-work-templates/` process scaffolding, which the research doesn't validate at all — none of the four sources above involve a 13-task human-readable checklist; they all rely on automated checks and structured (not narrative) rule tables.

---

## Options

### Option A: Try Python again, same process, better model

Re-run the existing `implement-language` skill / ROADMAP process against Python (or a new language) as-is, trusting that a more capable model avoids the mistakes a less capable one made.

**Pros:**
- Zero new infrastructure — everything needed already exists
- Directly tests the hypothesis in the maintainer's own framing: "the model wasn't good enough before" — and per the Decisions section, the maintainer's answer to **[Q2]** confirms exactly this for Go and C#

**Cons — why confirming the hypothesis doesn't make Option A sufficient on its own:**
- Even granting that a better model avoids Go/C#'s translation failures, it doesn't explain why Python specifically — which *did* get implemented — stalled *after* being declared complete. That failure wasn't "the model wrote wrong code," it was "nobody/nothing checked the self-declared verdict, so it never got promoted." A better model doesn't fix a missing acceptance step by itself.
- Nothing stops the *next* language from finding a fourth undiscovered gotcha, documenting it, patching the one implementation, and also stalling before promotion — same shape as Go, Python, and C# every time, regardless of model quality.
- ~22,600 combined lines of spec + tooling docs is a lot to reliably apply even for a stronger model; without Option B, there's still no way to know if it worked except the same manual Grafana-eyeball process that already missed things once.
- **This is why the accepted recommendation is B+C, not standalone A**: it keeps A's premise (a better model can do the implementation work) but adds the one thing A alone doesn't provide — an automated, re-runnable answer to whether the output actually matches, so a repeat of "declared complete, never promoted" isn't possible even if history repeats on the modeling side.

### Option B: Add a master-comparison mode to the existing validation tools

Not a new harness — an extension of what's already there. `specification/tools/` already runs an 8-step validation sequence per implementation and already supports `--compare-with FILE` to diff a backend's data against a file log. Add the missing comparison: run TypeScript and a candidate implementation through the same fixed E2E scenario (`08-testprogram-company-lookup.md`) in the same session, capture each one's actual output, and diff the candidate's fields against TypeScript's own live output (excluding known-variable fields like timestamps, trace IDs, event IDs). No stored fixture to maintain — TypeScript's current, real output *is* the answer key, every time it runs.

**Pros:**
- Converts "identical output across languages" from a documented convention (currently checked by reading a Grafana dashboard, once, by hand) into a mechanically-checked, re-runnable fact
- Would have caught the enum-conversion bug automatically, immediately, without anyone needing to know to check that specific Grafana panel. **Correction, added after `PLAN-001` actually built and tested this** (this line originally claimed "all three known Python bugs" — that was wrong, not just optimistic): only the enum-conversion bug is file-log-visible. The metric-naming bug and the OTLP-only-timestamp bug are structurally invisible to any file-log comparison, confirmed both empirically and by reading the code (metrics and the OTLP `extra` dict never touch `dev.log` at all). File-log comparison is still worth having for what it does catch; it was never going to be a complete answer to all three, and the plan documents that honestly rather than the investigation's original overclaim.
- Small, scoped addition — extends `query-loki.sh`/`query-prometheus.sh`/`query-tempo.sh`'s existing `--compare-with` pattern rather than inventing new infrastructure; reuses the 7,203 lines of schemas/tests/tools that already work
- Reusable for every future language — Go, C#, Rust, PHP all get the same check for free, always against whatever TypeScript currently does
- Gives a real, objective answer to **[Q6]**: "done" means "the comparison mode passes against TypeScript," not "the LLM said so"

**Cons:**
- Still upfront work before any language reaches "shipped," even though it's now known to be small — need to decide the comparison boundary (file-log JSON is the simplest and reuses the most existing code; OTLP wire payloads or Grafana query results are more thorough but heavier to add)
- Doesn't by itself explain *why* three separate implementation attempts stalled at the finish line rather than shipping — it fixes the verification gap, not necessarily the promotion gap

### Option C: Use Python as the pilot to validate the process itself

Rather than starting a new language from a blank slate, take the existing (allegedly 90%-done) Python implementation, run it through the current (v2.0.0-era) spec and skills, and — critically — define and execute the step that's never existed: what has to be true for `README.md` to actually say "✅ Available" for Python.

**Pros:**
- Cheapest possible next step — no new code from zero, a real historical implementation with known, well-documented bugs to re-check
- Tests whether "a better model + the now-much-heavier spec" actually converges to *shipped*, using the one case where the ground truth of what went wrong is already fully documented
- Forces **[Q6]** to get answered concretely instead of staying abstract

**Cons:**
- If the missing piece was never "the model" but "nobody defined what promotion means," this alone doesn't guarantee a different outcome — it just repeats the experiment with a better model, same as Option A, unless combined with something that changes the acceptance criteria itself (Option B)
- Risks becoming a fourth round of "declared complete, still not merged" if promotion isn't made a hard, checkable gate this time

### Option D: Cut the process scaffolding that the validation code now makes redundant

Not "simplify everything" — specifically target `llm-work-templates/` (5,831 lines of ROADMAP template, 13 per-task instruction files, and "enforcement" checklists) and the parts of the numbered docs that just restate what the validation code already catches mechanically (e.g., much of `07-anti-patterns.md`'s "Implementation Process Pitfalls" section overlaps with what schema validation and the consistency checks already enforce — though not all of it: the enum-conversion bug's actual failure path, `severity_text`/`severity_number` in the Loki response, has no schema check today at all — see "The recurring-bug pattern," above. That specific gap should be closed as part of Option B's work, not assumed away).

**Why this is no longer speculative:** `llm-work-templates/` exists almost entirely to compensate for *not* having automated cross-implementation verification — it's a checklist to stop a weaker model from skipping validation steps or claiming "done" without checking. Once Option B's comparison mode exists, "did you complete step 7 of 13" and "did you remember to check Grafana panel 4" both become moot — the question is just "does the comparison pass." The evidence for this isn't a hunch: `llm-work-templates/` didn't exist when Python was declared "done," was built three days later specifically in response to that experience, and was never applied back to Python — which is exactly what "this scaffolding doesn't actually solve the promotion problem" looks like.

**What should stay from the numbered docs:** the parts a model can't derive from TypeScript's code and the validation tools alone — `01-api-contract.md`'s exact function signatures, the field definitions, environment/config specifics, and the *reasoning* behind non-obvious cross-language decisions (e.g., "always `Error` for `exceptionType`," "always include `response_json` as `null`, never omit it") that TypeScript's code doesn't make self-evident by itself. Per the external research above, `07-anti-patterns.md`'s gotcha-to-fix content specifically should be *kept but compressed* into one structured table (a "feature mapping," in Oxidizer's terms) instead of narrated prose repeated across three files — the pattern itself is validated as correct, the format isn't.

**Pros:**
- Directly targets the size/inconsistency finding in **[Q4]**, justified by **[Q8]**'s finding that the validation code already substantially covers what the checklist scaffolding exists to compensate for — this is evidence, not a general instinct to tidy up
- Spec growth (37 commits) has already outpaced every implementation's growth (7 commits for Python, 0 for anything else) — cutting the redundant portion stops that gap from widening as more languages are added
- A model given "read TypeScript + the API contract + field definitions, then run the comparison mode until it passes" needs far less prose than one given a 13-task checklist designed to prevent it from lying

**Cons:**
- Still process work rather than shipped code on its own — needs to happen alongside (not instead of) Option B/C, or it repeats the exact pattern (a year of spec/tooling investment, no second language shipped) this investigation exists to break
- Risk of cutting something load-bearing that isn't obviously redundant until a future language implementation trips over its absence — mitigate by keeping the cut content in git history / `completed/` rather than deleting outright

### Option E: Generate field-name constants from the schemas, Weaver-style, instead of hand-typing them

Informed directly by OpenTelemetry's own Weaver tool (see External Research, above). `specification/schemas/log-entry-schema.json` already encodes every required field name in its correct snake_case form. Instead of an LLM reading a prose spec and *retyping* `service_name`, `trace_id`, `sovdev_operations_total`, etc. by hand in each new language — the exact step where the dots-vs-underscores Python bug originated — generate a small constants file/module per language directly from the schema as part of each implementation's build, the same way OpenTelemetry SDKs generate their semantic-convention constants from a single YAML source today.

**Pros:**
- Structurally prevents the field-*naming* bug class (wrong field names, dots-vs-underscores, camelCase slips) rather than detecting it after the fact — stronger than Option B for this specific failure mode
- Schemas already exist (`specification/schemas/*.json`) — this is a code-generation script reading data that's already correct, not new spec-writing
- Directly precedented by OpenTelemetry's own solution to the same category of problem, in the same ecosystem this library wraps

**Cons:**
- **Narrower fix than it first sounds — precisely one of the three documented bugs is a naming bug.** It does not cover the enum-to-string conversion bug (a value bug: `str(enum)` returns the wrong string regardless of what the field is named) or the missing-field bug (a completeness bug: the field was never added to the output at all, which correct naming doesn't force). Both remain squarely Option B's job.
- New tooling to build and maintain (a generator + per-language templates), though likely smaller than Option B's comparison mode since the schemas are already the single source of truth
- Best introduced *after* Option B proves out on Python, so the generator's output can be validated against the same comparison mechanism rather than trusted blindly

---

## Recommendation

**B, then C and D together, with E as a fast-follow once B exists — D is no longer conditional, since the evidence for it is now concrete rather than speculative.**

1. Add the master-comparison mode (**Option B**) to the existing tools — this is a small, scoped extension of the `--compare-with` pattern already working in `query-loki.sh`/`query-prometheus.sh`/`query-tempo.sh`, not a new harness. Reuses the 7,203 lines of schemas/tests/tools that already validate single-implementation correctness; adds the one missing piece, a candidate-vs-TypeScript diff for the same run. Per the BabelCoder finding, this should cover the edge cases the field definitions require (error paths, missing-response "null" handling, batch/job logging) — checked directly while drafting `PLAN-001`: the existing `company-lookup.ts`/`.py` scenario already exercises all of these, so no scenario-expansion work is needed, just the comparator itself. While in this code, also close the confirmed schema gap: add `severity_text`/`severity_number` enum constraints to `loki-response-schema.json`, since today nothing schema-checks them.
2. Use that comparison mode to validate — and where it fails, fix — the existing Python implementation (**Option C**), rather than starting Go, C#, Rust, or PHP from scratch. This is the cheapest path to an actual *second shipped language*, and it directly answers whether the accumulated spec + skills + a stronger model actually converges to "done" on a case where the ground truth is already known.
3. As part of step 2, explicitly define and execute the promotion step that's never existed: what turns a validated implementation into a `README.md` "✅ Available" row. This is the actual gap that let Python, Go, and C# all stall — not (only) code correctness.
4. In parallel, cut `llm-work-templates/`'s ROADMAP/task-file/enforcement scaffolding (**Option D**) down to whatever a model actually still needs once step 1 exists — likely just a short "read the API contract and field definitions, study TypeScript, implement, run the comparison mode until it passes" pointer, not a 13-task checklist. Compress `07-anti-patterns.md`'s gotcha content into one structured table rather than cutting it — the "feature mapping" research validates that pattern specifically. Keep the removed content in `completed/` rather than deleting it outright, in case something in it turns out to be load-bearing.
5. Once step 1 is proven on Python, add schema-driven field-name generation (**Option E**) so future languages get correct field names by construction rather than by careful hand-typing — validate the generator's own output through the same comparison mode from step 1.

This ordering means the very first deliverable is something that can be pointed at and re-run — "here is proof Python's output matches TypeScript's, field for field, for the same input" — rather than another self-declared "complete" markdown file or another round of prose.

---

## Next Steps

- [x] Get sign-off on the recommendation above — **accepted by maintainer 2026-07-08**, see "Decisions"
- [x] Create [`PLAN-001-master-comparison-mode.md`](../completed/PLAN-001-master-comparison-mode.md) scoped to Option B — **completed 2026-07-08** on branch `feature/master-comparison-mode` (not yet merged). Built and verified against the real devcontainer: `compare-with-master.sh`/`compare-log-files.py` exist, TS-vs-TS sanity check passes, the Loki severity-schema gap is closed. Found and fixed a real comparator bug (`peer_service` false positives on `INTERNAL`-resolved entries) during the first real cross-language run. **Also found and corrected an overclaim in this investigation**: file-log comparison only catches 1 of the 3 historically-documented bugs (enum conversion) — the other two (metric-naming, OTLP-only-timestamp) are structurally invisible to it, confirmed empirically. Surfaced two real, previously-unknown bugs in the current Python implementation (`response_json` dropped on most entries, `exception_message` whitespace difference) for `PLAN-002` to fix.
- [x] Create [`PLAN-002-python-conformance.md`](../completed/PLAN-002-python-conformance.md) scoped to Option C — **completed 2026-07-08** on branch `feature/python-conformance` (stacked on `feature/master-comparison-mode`, neither merged yet). Fixed both real bugs `PLAN-001` found — `response_json`/`input_json` (deeper than expected: needed a `_NOT_PROVIDED` sentinel since Python's `None` can't distinguish "omitted" from "explicitly null" the way JS distinguishes `undefined`/`null`) and `exception_message` (a test-script inconsistency, not a library bug). `compare-with-master.sh python` now passes with **zero mismatches** — the first automated, re-runnable proof of cross-language conformance this project has had. Promotion executed: `python/README.md` written and its examples verified against the real implementation, `README.md`'s 7 stale "Planned" mentions flipped to "Available". Found (not fixed, out of scope, pre-existing and affects TypeScript identically): a stale field-name bug in `validate-log-format.py --error-log`.
- [x] Create [`PLAN-003-spec-scaffolding-cleanup.md`](../completed/PLAN-003-spec-scaffolding-cleanup.md) scoped to Option D — **completed 2026-07-08.** `07-anti-patterns.md` compressed 786 → 51 lines (one table row per pattern, technical content verified against current code, not carried forward stale). `specification/llm-work-templates/` replaced entirely by `specification/implementation-guide.md`; the removed 13-task ROADMAP/CLAUDE/enforcement scaffolding archived (not deleted) at `specification/llm-work-templates-archive/` via `git mv`. Scope grew mid-plan by maintainer decision: `.claude/skills/` (automatically-invoked routers built for an earlier, weaker model) was deleted outright rather than patched or archived, since it's fully redundant now that `compare-with-master.sh` is the completion gate. All downstream cross-references fixed repo-wide; Docusaurus rebuild confirmed clean. Also surfaced two real, previously-undocumented discrepancies while re-verifying the anti-patterns table against current code (not fixed here, doc-only plan): TypeScript's credential redaction is narrower than Python's, and TypeScript's `exception_type` isn't fully hardcoded to `"Error"` the way Python's is.
- [x] Create [`PLAN-004-schema-driven-field-generation.md`](../completed/PLAN-004-schema-driven-field-generation.md) scoped to Option E — **completed 2026-07-08.** Scope narrowed after checking the actual code (not assumed from the one-line backlog description): TypeScript writes field names as bare object-literal keys, which are already syntax-error-proof against the dots/typo bug class this option targets, so only Python — which uses string dict-literal keys — adopts the generated constants. `specification/tools/generate-field-constants.py` reads the 17 fields in `log-entry-schema.json` and generates a per-language module; `python/src/logger.py`'s 72 hand-typed field-name literals now reference it, verified byte-identical output before/after and zero `compare-with-master.sh` regressions. Wired into `specification/implementation-guide.md` as step 2 for any future language, with the TypeScript decision documented inline rather than silently absent.
- [ ] Only after PLAN-002 ships: decide whether Go/C#/Rust/PHP restart from scratch or from their archived `terchris/implementation-tests/` state
