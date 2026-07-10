# Consolidate validation tooling under `tools/`, removing confirmed-dead scripts

Moves the live parts of `specification/tools|tests|schemas` into a new `tools/validation/` tree organized by OTLP backend, renames `tools/validation/grafana/` to `grafana-cloud/` for symmetry, and deletes the confirmed-dead scripts found in the companion investigation.

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Completed

**Investigation**: [INVESTIGATE-specification-tools-dead-code-audit.md](INVESTIGATE-specification-tools-dead-code-audit.md) — the audit that found what's dead vs. live.

**Goal**: Reorganize `specification/tools|tests|schemas` into `tools/validation/` (by backend), delete confirmed-dead scripts, and update every real reference across the repo without breaking anything.

**Completed**: 2026-07-11

---

## Problem Summary

`specification/tools/`, `specification/tests/`, `specification/schemas/` accumulated dead code alongside live tooling as the validation approach evolved (bash `kubectl exec` → disposable curl pods, direct backend queries superseding a Grafana-datasource-proxy layer, `compare-with-master.sh` superseding an 8-step orchestration script). Nobody had gone back to remove what the newer approach made obsolete. Separately, `specification/` no longer contains any prose (migrated to the Docusaurus site in PLAN-006), so keeping functional code nested under a documentation-named folder no longer made sense.

---

## Phase 1: Move live tooling, remove dead scripts — DONE

### Tasks

- [x] 1.1 Created `tools/validation/{schemas,validators,uis}/`, `tools/codegen/`, `tools/repo-maintenance/`
- [x] 1.2 `git mv`'d all 4 schemas + their README to `tools/validation/schemas/`
- [x] 1.3 `git mv`'d all 8 Python validators + `compare-log-files.py` + their README to `tools/validation/validators/`
- [x] 1.4 `git mv`'d the 6 live bash tools (`query-loki.sh`, `query-tempo.sh`, `query-prometheus.sh`, `compare-with-master.sh`, `run-company-lookup.sh`, `validate-log-format.sh`) to `tools/validation/uis/`
- [x] 1.5 `git mv`'d `generate-field-constants.py` to `tools/codegen/`, `check-doc-consistency.py` to `tools/repo-maintenance/`
- [x] 1.6 `git mv`'d `tools/validation/grafana/` → `tools/validation/grafana-cloud/` (TypeScript, Grafana Cloud tooling — renamed for symmetry with the new `uis/`)
- [x] 1.7 `git rm`'d the 7 confirmed-dead scripts: `verify-kubectl-setup.sh`, `query-grafana-loki.sh`, `query-grafana-prometheus.sh`, `query-grafana-tempo.sh`, `run-grafana-validation.sh`, `validate-grafana-datasources.sh`, `run-full-validation.sh`
- [x] 1.8 `git rm`'d the now-orphaned `specification/tools/README.md` (content rewritten into the new locations); removed the leftover `specification/tests/__pycache__/`
- [x] 1.9 `specification/` initially left with only `README.md` (rewritten to point at `tools/`) and `llm-work-templates-archive/` — later fully deleted in Phase 4 below, once the maintainer confirmed neither was still needed

### Validation

- [x] `git status` after the moves showed clean renames (`R`), not delete+add pairs, confirming git tracked history through the move

---

## Phase 2: Fix every real path reference — DONE

### Tasks

- [x] 2.1 Fixed relative-path resolution in the moved scripts: `query-loki.sh`/`query-tempo.sh`/`query-prometheus.sh`'s `$SCRIPT_DIR/../tests/` → `../validators/`; confirmed the Python validators' own `script_dir.parent / 'schemas'` computations needed **no code change** (same sibling-directory depth preserved by design)
- [x] 2.2 Fixed `compare-with-master.sh`, `validate-log-format.sh`, `run-company-lookup.sh`'s header comments and the one absolute `/workspace/specification/tests/...` path each of the first two hardcoded
- [x] 2.3 Fixed `tools/codegen/generate-field-constants.py`'s `SCHEMA_PATH`/`GENERATOR_REL_PATH`/`SCHEMA_REL_PATH` constants; regenerated `python/src/field_names.py` rather than hand-editing the generated file — field constants themselves came out byte-identical, only the header comment changed
- [x] 2.4 Fixed `tools/validation/grafana-cloud/lib/consistency-check.ts`'s `SPECIFICATION_TESTS_DIR` (renamed `VALIDATORS_DIR`, now `../../validators` instead of `../../../../specification/tests`) and the comment-only path mentions in `query-loki.ts`/`query-tempo.ts`/`query-prometheus.ts`
- [x] 2.5 Fixed `typescript/test/e2e/company-lookup/run-test.sh`'s real `VALIDATOR_SCRIPT` path (both devcontainer and host branches) and `company-lookup.ts`'s comments
- [x] 2.6 Fixed `python/src/logger.py`'s comment referencing the codegen tool
- [x] 2.7 Discovered and fixed a **real gap** while doing this: `python/` had no `.gitignore` at all — the root `.gitignore` only covers `.env`/`.env.local`/`.env.*.local`, not arbitrary `.env.*` names, so nothing stopped a generated Grafana Cloud credential file from being accidentally committed. Not part of this plan's original scope but fixed in passing since it was found here. *(Carried over from the prior session's Python/Grafana-Cloud work — noted here because the fix touched the same area, not reintroduced by this plan.)*

### Validation

- [x] Re-ran the full TypeScript E2E test (`bash run-test.sh`) — clean, all validations pass, including the moved `validate-log-format.sh`
- [x] Re-ran `query-loki.sh`/`query-tempo.sh` with `--compare-with` from the new `tools/validation/uis/` location — exact match
- [x] Re-ran `compare-with-master.sh python` from the new location — clean match against TypeScript
- [x] `npx tsc --noEmit` on `tools/validation/` — clean
- [x] Re-ran the Grafana Cloud TypeScript unit tests (`node --test` via `tsx`) — 12/12 pass
- [x] Re-ran a live Grafana Cloud query (`query-loki.ts --compare-with`) through the renamed `grafana-cloud/` directory and the fixed `consistency-check.ts` path — 17/17 exact match, confirming the Python validator invocation resolves correctly post-rename
- [x] `python3 tools/codegen/generate-field-constants.py --lang python` — output identical except the header comment

---

## Phase 3: Update documentation — DONE

### Tasks

- [x] 3.1 Rewrote `tools/README.md` (new) — top-level overview, explains the by-backend structure and how to add a new backend
- [x] 3.2 Rewrote `tools/validation/uis/README.md` (new, replacing the deleted `specification/tools/README.md`) — stripped of all dead-tool documentation, describes only the actually-verified workflow
- [x] 3.3 Rewrote `tools/validation/validators/README.md` — same treatment
- [x] 3.4 Fixed `tools/validation/schemas/README.md`'s remaining path/diagram references
- [x] 3.5 Rewrote `specification/README.md` to point at the new `tools/` location
- [x] 3.6 Substantially rewrote `website/docs/contributor/09-development-loop.md` — this had the most dead-tool content (the entire "8-step validation sequence" built around the now-deleted Grafana-proxy scripts and `run-full-validation.sh`). Replaced with the actual verified 4-step flow (file format → backend queries with `--compare-with` → cross-language conformance)
- [x] 3.7 Fixed path/dead-tool references in `03-implementation-patterns.md`, `05-environment-configuration.md`, `06-test-scenarios.md`, `07-anti-patterns.md` (row 15's advice pointed at a now-dead script), `08-testprogram-company-lookup.md`, `implementation-guide.md`, `index.md`, `research-otel-sdk-guide.md`, `using/observability-architecture.md` (also fixed a reference to a script name — `run-company-lookup-validate.sh` — that never actually existed), `README.md` (root), `python/README.md`
- [x] 3.8 Fixed `.github/workflows/ci.yml`'s comment-only references
- [x] 3.9 Added an update note to `INVESTIGATE-grafana-cloud-validator.md`'s Q1, since its original decision text ("the existing scripts are not moved") is superseded by this plan
- [x] 3.10 Left historical/completed docs alone: `python/llm-work/llm-checklist-python.md`, all `plans/completed/*.md` — these describe what was true at the time and aren't live guidance

### Validation

- [x] `npm run build` (Docusaurus) — clean, no broken links/anchors
- [x] Full repo grep for the dead scripts' names and old paths — zero remaining live references (only historical/archived docs, left intentionally)

---

## Phase 4: Delete `specification/` entirely — DONE

After Phase 1-3 left `specification/` holding only `README.md` (a redundant pointer to `tools/`) and `llm-work-templates-archive/`, the maintainer asked whether to remove the folder entirely. `llm-work-templates-archive/` was flagged as a deliberate keep from PLAN-003 (a safety net "in case something in it turns out to still be load-bearing for a future language implementation"), not oversight — so this was confirmed explicitly rather than assumed, since deleting it reverses that earlier decision. Maintainer confirmed: delete everything. Its content remains recoverable from git history if a future language implementation ever needs it.

### Tasks

- [x] 4.1 `git rm -r specification/` — removed `README.md` and the entire `llm-work-templates-archive/` tree
- [x] 4.2 Fixed the one real (non-historical) reference: `implementation-guide.md`'s link to the now-deleted archive path
- [x] 4.3 Fixed `project-sovdev-logger.md`'s directory tree, which was already stale from Phase 1 (still showed `specification/schemas|tests|tools`) — updated to the real current tree, and fixed a prose reference to "`specification/`" as the contract to point at the Contributor docs instead
- [x] 4.4 Left historical mentions of `specification/`/`llm-work-templates-archive/` in completed PLANs and the backlog `INVESTIGATE-multi-language-conformance.md` alone — they describe what was true at the time, not current guidance

### Validation

- [x] `npm run build` (Docusaurus) — clean
- [x] Full repo grep for `specification/` — zero remaining live references outside historical completed-plan docs

---

## Acceptance Criteria

- [x] All 7 confirmed-dead scripts removed
- [x] All live tooling moved to `tools/validation/` (by backend), `tools/codegen/`, `tools/repo-maintenance/`, with git history preserved through renames
- [x] Every functional reference (scripts, code, CI) updated and re-verified working, not just grepped-and-assumed
- [x] `python/src/field_names.py` regenerated (not hand-edited) — confirmed byte-identical field constants
- [x] Documentation updated to match — no doc recommends a deleted script or an old path as current guidance
- [x] `python/.gitignore` gap fixed (found while working in this area)
- [x] Docusaurus build clean
- [x] `specification/` deleted entirely (Phase 4), after explicit confirmation that the archived scaffolding was safe to remove rather than assumed

## Files Modified

Moved (see Phase 1) — plus:
- `tools/README.md` (new)
- `tools/validation/uis/README.md` (new)
- `tools/validation/validators/README.md`, `tools/validation/schemas/README.md`
- `specification/README.md` (deleted in Phase 4)
- `website/docs/ai-developer/project-sovdev-logger.md` (directory tree + contract reference)
- `website/docs/contributor/09-development-loop.md` (substantial rewrite)
- `website/docs/contributor/03-implementation-patterns.md`, `05-environment-configuration.md`, `06-test-scenarios.md`, `07-anti-patterns.md`, `08-testprogram-company-lookup.md`, `implementation-guide.md`, `index.md`, `research-otel-sdk-guide.md`
- `website/docs/using/observability-architecture.md`
- `website/docs/ai-developer/plans/completed/INVESTIGATE-grafana-cloud-validator.md`
- `README.md`, `python/README.md`
- `.github/workflows/ci.yml`
- `python/src/logger.py`, `python/src/field_names.py` (regenerated)
- `typescript/test/e2e/company-lookup/run-test.sh`, `company-lookup.ts`
- `tools/validation/grafana-cloud/lib/consistency-check.ts`, `query-loki.ts`, `query-tempo.ts`, `query-prometheus.ts`
