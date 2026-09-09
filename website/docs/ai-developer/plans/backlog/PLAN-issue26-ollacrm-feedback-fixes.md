# Plan: ollacrm feedback — severity, connectivity check, and the onboarding gaps

Ships the verified, no-design-ambiguity half of GitHub issue #26: the `TRACE` severity collision, the connectivity check that reads a real success response as a failure, the three onboarding-doc gaps, the auto-instrumentation import-order warning, and consumer test-setup guidance — leaving the `sovdev-logger/register` preload entry point to its own follow-up plan.

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Backlog

**Goal**: Fix the two confirmed code bugs from issue #26 and close its five documentation gaps, with the cross-language severity question decided rather than discovered later by the comparator.

**Last Updated**: 2026-09-07

**Investigation**: [INVESTIGATE-issue26-ollacrm-feedback.md](INVESTIGATE-issue26-ollacrm-feedback.md) — items 2, 3, 4 (Option 4A), 5, and 6 (Option 6A). Item 1 needs no code change, only a reply on the issue. Item 6's Option 6B (the preload entry point) is deliberately **not** in this plan; see "Explicitly out of scope".

**Source**: [Issue #26](https://github.com/helpers-no/sovdev-logger/issues/26), still open, last updated 2026-07-14.

**Priority**: High — Tier 1 of [1PRIORITY.md](1PRIORITY.md), and the connectivity bug has been known and unfixed since issue #23.

---

## Problem

Five things, all re-verified against `main` on 2026-09-07 rather than taken from the July investigation:

1. **`TRACE` collapses into `DEBUG` on export.** `typescript/src/logger.ts:203` maps `trace: SeverityNumber.DEBUG`. `SOVDEV_LOGLEVELS.TRACE` is a real, public, distinct level (`typescript/src/logLevels.ts:9`), and the OTel enum this file already imports has `TRACE = 1` (confirmed in `@opentelemetry/api-logs`'s `LogRecord.d.ts:7`). So a consumer who logs at TRACE gets DEBUG severity in the backend, and no error anywhere.

2. **`sovdev_test_otlp_connection()` reports a working endpoint as unreachable.** `typescript/src/logger.ts:1266` accepts `200` and `202`, special-cases `404` and `400`, and drops everything else — including `204 No Content`, which is what Grafana Cloud actually returns for a successful OTLP logs push — into the `else` branch as `reachable: false`. A consumer's first connectivity check fails against a backend that is in fact working.

3. **Three onboarding-doc gaps**, all still absent from `website/docs/using/onboarding/index.md` (95 lines, checked field by field): bundle size (~7 MB, which matters for any bundled or size-constrained deploy), `LOG_TO_FILE` (which matters on an ephemeral filesystem such as Cloud Run), and the ERROR/FATAL → ServiceNow-incident warning. The third exists only at `typescript/README.md:1398`, inside the Compliance section — not where someone about to send their first test log will see it.

4. **No consumer-facing testing guidance.** `sovdev_log()` throws when called before `sovdev_initialize()`. The README's only Testing section is scoped to this library's own contributors, so a consumer unit-testing a pure helper that logs internally has nothing to follow.

5. **The auto-instrumentation import-order footgun is documented only in a code comment** (`typescript/test/e2e/company-lookup/company-lookup.ts`), not in the onboarding guide or the quick-start.

### The thing the investigation did not catch

**Fixing item 1 in TypeScript alone breaks cross-language conformance.** `python/src/logger.py:480` maps `"trace": logging.DEBUG` with the comment *"Python doesn't have TRACE, map to DEBUG"*, while `python/src/log_levels.py:18` documents TRACE as *"Severity: 1 (OpenTelemetry)"* — the same contradiction between the documented table and the emitted value that TypeScript has. Python's stdlib has no TRACE level, and OTel's `LoggingHandler` derives severity from the Python level number, so this is not a one-line change on that side.

That makes item 1 a **conformance decision, not a one-line fix**: change TypeScript alone and the two implementations emit different severities for the same call, which is exactly what `tools/validation/uis/compare-with-master.sh` exists to refuse. Phase 1 decides it before any code changes.

---

## Phase 1: Decide the TRACE severity question across both languages

Do this first. It is the only part of this plan with a real decision in it, and both code changes in Phase 2 depend on the answer.

### Tasks

- [ ] 1.1 Determine how OTel's Python `LoggingHandler` maps a level number below `DEBUG` (10) to a `SeverityNumber` — read the installed `opentelemetry-sdk`, do not assume. Specifically: does a custom level registered at 5 via `logging.addLevelName()` reach the exporter as `TRACE`, or does the handler floor unknown levels?
- [ ] 1.2 Pick one of:
      **(a) Fix both** — `trace: SeverityNumber.TRACE` in TypeScript, a real TRACE level in Python. Correct in both, conformance preserved, more work on the Python side.
      **(b) Fix TypeScript, defer Python** — only if 1.1 shows the Python fix is genuinely non-trivial; requires a recorded, dated conformance exception and a follow-up plan, because an undocumented divergence is what the comparator is for.
      **(c) Neither** — reject the fix and correct both languages' *documentation* to say TRACE is an alias for DEBUG. Cheapest, and honest, but it discards a real distinction the OTel enum already gives us.
- [ ] 1.3 Answer **[Q1]** from the investigation: does the change need a consumer-facing migration note? Check the two dashboard JSONs in `tools/dashboards/` and the docs for any query or panel that filters on severity, so the answer is measured rather than assumed.
- [ ] 1.4 Record the decision and its reasoning in this plan before writing code.

### Validation

User confirms the decision. Nothing has been implemented yet, deliberately.

---

## Phase 2: The two code fixes

### Tasks

- [ ] 2.1 Item 1, per the Phase 1 decision: `typescript/src/logger.ts:203`, and the Python side if 1.2 chose (a).
- [ ] 2.2 Item 2: `typescript/src/logger.ts:1266` — treat **any 2xx** as reachable rather than allowlisting one status at a time. This answers **[Q2]** with the repo's own precedent: `tools/validation/grafana-cloud/probe-otlp-ingest.ts:35` already uses `response.ok`, i.e. any 2xx, to decide the same question. Keep the `404` and `400` branches exactly as they are — both carry a specific, useful message.
- [ ] 2.3 Add a unit test for each fix. The severity test must assert the exported `SeverityNumber`, not the Winston level name — the level name was never wrong, which is why this bug survived.
- [ ] 2.4 `npm run build && npm run lint` in `typescript/`.

### Validation

```bash
cd typescript && npm run build && npm run lint && npm test
tools/validation/uis/compare-with-master.sh python
```

The comparator must pass. If Phase 1 chose (b), it will legitimately show the severity divergence — in that case the recorded exception is what makes the run acceptable, and it must be named in the output, not silently tolerated.

---

## Phase 3: The documentation gaps

### Tasks

- [ ] 3.1 Item 3, all three, into `website/docs/using/onboarding/index.md`: bundle size, `LOG_TO_FILE` and its ephemeral-filesystem consequence, and the ERROR/FATAL → ServiceNow warning. The warning goes **before** the first "send a test log" step, since its whole value is arriving before someone opens a real incident ticket.
- [ ] 3.2 Item 5 (Option 6A): the import-order warning, in both the onboarding guide and the README quick-start, with the dynamic-`import()` pattern the E2E example already uses. State plainly that this is a workaround and that a preload entry point is the real fix, with a pointer to the follow-up plan — a documented footgun should not read as a solved problem.
- [ ] 3.3 Item 4 (Option 4A): consumer test-setup guidance. **This answers [Q3]**: a new "Testing your integration" section, not a rewrite of the existing "Testing (for Contributors)" — two audiences, two sections, and the existing one is correctly scoped for the audience it names. Document calling `sovdev_initialize()` once in test setup, and say why the throw exists, so the guidance does not read as a workaround for a bug.
- [ ] 3.4 Item 1 of the investigation: reply on [issue #26](https://github.com/helpers-no/sovdev-logger/issues/26) confirming `sovdev_generate_trace_id` was already resolved — the README section was removed, `sovdev_start_span`/`sovdev_end_span` cover the same need. Cite back the positive findings too (the esbuild bundling result, the `company-lookup.ts` example); a consumer who files feedback this good should hear which parts landed.

### Validation

```bash
cd website && npm run build
```

Docusaurus builds with no broken links. User confirms the onboarding guide reads correctly to someone who has not integrated the library before — the gap this plan closes is a first-contact gap, so a build passing is necessary but not sufficient.

---

## Phase 4: Ship and verify against a real backend

### Tasks

- [ ] 4.1 Open the PR, let CI run: `test-typescript`, `code-quality`, and `grafana-cloud-consistency`.
- [ ] 4.2 Run a real TRACE-level log end to end and read it back — `tools/validation/grafana-cloud/full-consistency-check.sh`, plus a targeted `tools/validation/uis/query-loki.sh` for the severity field. A severity change is a change to emitted data; this repo's norm is to confirm it against a live backend, not to trust a unit test.
- [ ] 4.3 Run `sovdev-selftest` against a real endpoint and confirm the connectivity check now reports reachable where it previously reported unreachable. That is the whole point of item 2, and it is the one fix a unit test cannot really prove.
- [ ] 4.4 Update `1PRIORITY.md`: strike the shipped items from the Tier 1 row, leave the investigation open for item 6's follow-up, and note what remains.

### Validation

```bash
tools/validation/grafana-cloud/full-consistency-check.sh
```

User confirms the TRACE severity is correct in the live backend and that `sovdev-selftest` passes.

---

## Acceptance Criteria

- [ ] A TRACE-level log arrives in a real backend with the severity the Phase 1 decision specifies — verified by reading it back, not by inspecting the map
- [ ] `sovdev_test_otlp_connection()` reports reachable for any 2xx, verified against a real endpoint that returns 204
- [ ] `compare-with-master.sh python` passes, or fails only on a divergence recorded and dated in this plan
- [ ] All three onboarding gaps documented, with the ServiceNow warning ahead of the first test-log step
- [ ] Import-order warning in the onboarding guide and the README quick-start, framed as a workaround
- [ ] A "Testing your integration" section exists, separate from the contributor one
- [ ] Issue #26 has a reply covering every item, including the ones that needed no change
- [ ] No regression: `npm test`, `npm run lint`, and the website build all pass
- [ ] `1PRIORITY.md` reflects what shipped and what is left

---

## Explicitly out of scope

**Item 6's Option 6B — the `sovdev-logger/register` preload entry point.** Its own plan, and closer to ready than the investigation left it: **[Q5] is answered.** `typescript/package.json` has no `type` field (so the package is CommonJS) and **no `exports` map at all**, only `main: dist/index.js`. So a `sovdev-logger/register` subpath needs an `exports` map introduced, and adding one is itself a potentially breaking change for any consumer deep-importing a path inside the package today — that risk is the reason this belongs in a separate plan with its own validation, not bolted onto a bug-fix PR.

**Item 4's Option 4C** — the test-only escape hatch. Deliberately not built until Option 4A's documentation has shipped and failed to resolve the problem. Building a new public API for a problem a paragraph might solve is the wrong order.

---

## Files to Modify

- `typescript/src/logger.ts` — severity map (line ~203), connectivity status check (line ~1266)
- `python/src/logger.py` — level mapping (line ~480), only if Phase 1 chooses (a)
- `python/src/log_levels.py` — the severity comment (line ~18), whichever way Phase 1 decides, since it is currently wrong either way
- `typescript/src/logLevels.ts` — TRACE comment, if the decision changes what the level means
- `typescript/test/` — one unit test per fix
- `website/docs/using/onboarding/index.md` — three gaps plus the import-order warning
- `typescript/README.md` — import-order warning, new "Testing your integration" section
- `website/docs/ai-developer/plans/backlog/1PRIORITY.md` — re-rank after shipping
