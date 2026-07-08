# Implementing sovdev-logger in a New Language

The short version, now that [`compare-with-master.sh`](tools/compare-with-master.sh) exists: read the contract, study TypeScript, implement, run the comparison until it passes. No ROADMAP file to generate, no checkboxes to maintain — the comparison script is the completion gate, not a human- or model-reported checklist.

This replaces the old `llm-work-templates/` 13-task system (archived at [`llm-work-templates-archive/`](llm-work-templates-archive/) — see [PLAN-003](../website/docs/ai-developer/plans/backlog/PLAN-003-spec-scaffolding-cleanup.md) for why).

## The process

1. **Read the contract, not just the prose.** [`01-api-contract.md`](01-api-contract.md) has the exact function signatures; [`02-field-definitions.md`](02-field-definitions.md) has every log field and its type. These are the parts a model can't derive from TypeScript's code alone — the reasoning behind non-obvious cross-language decisions (e.g., "always `Error` for `exceptionType`," "always include `response_json` as `null`, never omit it") lives here.
2. **Generate your field-name constants before writing any log-emitting code:**
   ```bash
   python3 specification/tools/generate-field-constants.py --lang {language}
   ```
   This reads the 17 field names straight from [`schemas/log-entry-schema.json`](schemas/log-entry-schema.json) — the same source of truth `01-api-contract.md`/`02-field-definitions.md` describe in prose — and emits a constants module, so a typo or a stray dot in a field name becomes a compile-time/reference error instead of a silently-wrong string in the file log. If `--lang {language}` isn't implemented yet in the generator, add an output renderer for it first (see the existing `render_python`/`render_typescript` functions for the pattern) rather than hand-typing the 17 names — that's the exact failure mode this step exists to prevent. **Exception:** if your language's object/struct-literal syntax makes field names bare identifiers rather than strings (as TypeScript's does), a stray dot is already a syntax error and generated constants add less value — see [PLAN-004](../website/docs/ai-developer/plans/completed/PLAN-004-schema-driven-field-generation.md) for why TypeScript itself doesn't consume them. Use judgment; don't skip the step without a reason as concrete as that one.
3. **Study the reference implementation.** `typescript/src/` is the master — not "a" reference, *the* reference. When the spec and the code seem to disagree, or the spec is silent, the code wins.
4. **Check [`07-anti-patterns.md`](07-anti-patterns.md)** for the mistakes every prior implementation attempt has actually made. It's a table now, not a narrative — five minutes to read.
5. **Set up your environment.** [`05-environment-configuration.md`](05-environment-configuration.md) covers install/config; `.devcontainer/additions/install-dev-{language}.sh` installs the toolchain inside the devcontainer if it isn't preinstalled.
6. **Implement**, using the generated field-name constants from step 2 instead of hand-typed field-name strings. Follow the development loop in [`09-development-loop.md`](09-development-loop.md): edit → lint → build → run → validate logs (fast, local) → validate OTLP (slower, needs the backend) → iterate. Validate frequently in small increments, not once at the end.
7. **Run the comparison mode until it passes:**
   ```bash
   cd specification/tools && ./compare-with-master.sh {language}
   ```
   This diffs your implementation's file-log output against TypeScript's live output for the same fixed E2E scenario (`test/e2e/company-lookup/`). Zero mismatches is the actual "done" signal — not a self-written summary. See [`tools/README.md`](tools/README.md) for the full 9-step validation sequence (this is step 9; steps 1-8 cover OTLP/Loki/Prometheus/Tempo/Grafana consistency, which the comparison mode doesn't reach — see PLAN-001's findings on what file-log comparison can and can't catch). Note that this mode catches value/completeness bugs (wrong content, missing fields) but not the field-*naming* bug class step 2 already prevents by construction — the two are complementary, not redundant.
8. **Write `{language}/README.md`** once the comparison passes, then update the root `README.md`'s status table to reflect the new "✅ Available" language — this promotion step is a required part of the language being done, not an afterthought. Diff against [`typescript/README.md`](../typescript/README.md) rather than duplicating its content — write only what's actually different for this language, the way [`python/README.md`](../python/README.md) does, not a second full copy of the shared essay/diagrams. Verify every code example in the new README against the actual public API before publishing it; run the quickstart example for real.

## Known blind spots

`compare-with-master.sh` only covers file-log JSON for one fixed scenario. It does not check OTLP wire payloads, metrics, or Grafana rendering — confirmed empirically that 2 of the 3 historically-documented Python bugs (metric naming, OTLP-only timestamp) never touch the file log at all and would not be caught by this alone. For those, use `specification/tools/query-grafana-*.sh` against the live backend (Grafana API, always available — prefer it over `query-*.sh`'s direct `kubectl` access, which is optional and not always configured).
