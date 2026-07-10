# Cut the process scaffolding the comparison mode makes redundant

Shrinks `specification/llm-work-templates/` from a 6,596-line, 13-task ROADMAP/CLAUDE/enforcement system down to a short pointer doc (`specification/implementation-guide.md`) now that `compare-with-master.sh` is the actual "done" gate, archives the removed scaffolding rather than deleting it, deletes the now-redundant `.claude/skills/` directory outright (a separate maintainer call made mid-plan), compresses `07-anti-patterns.md`'s narrative gotcha-to-fix content into one structured table, and updates every downstream reference (spec docs, both READMEs, the ai-developer docs) so nothing is left dangling or contradictory.

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Completed

**Completed**: 2026-07-08

**Investigation**: [INVESTIGATE-multi-language-conformance.md](INVESTIGATE-multi-language-conformance.md) — Option D, accepted 2026-07-08 as part of the combined B→C+D recommendation

**Prerequisite**: [PLAN-001-master-comparison-mode.md](PLAN-001-master-comparison-mode.md) — completed and merged; `compare-with-master.sh` is what makes this scaffolding redundant, not just an opinion that it's too big

**Goal**: `llm-work-templates/` is reduced to what a model still needs once `compare-with-master.sh` exists — a short pointer, not a 13-task checklist — with the removed scaffolding archived (not deleted); `.claude/skills/` deleted outright (a later, separate maintainer call); `07-anti-patterns.md` survives as one structured table instead of narrated prose repeated across files; every reference to what moved, shrank, or disappeared is updated, with zero dangling links left in the repo.

**Last Updated**: 2026-07-08

---

## Problem

Confirmed by direct measurement while drafting this plan (`wc -l`, `grep -rn`), not assumed from the investigation alone:

### `specification/llm-work-templates/` is 6,596 lines built to compensate for a gate that didn't exist yet

17 files: 2 shell scripts (765 lines: `enforcement/check-progress.sh`, `enforcement/init-language-workspace.sh`) + 15 markdown files (5,831 lines: `README.md`, `CLAUDE-template.md`, `ROADMAP-template.md`, `research-otel-sdk-guide.md`, `validation-sequence.md`, `task-05-setup-project.md`, and 9 `task-templates/task-NN-*.md` files). It scaffolds a per-language `{language}/llm-work/ROADMAP.md` (13 tasks, 4 phases) that a model must check off, enforced by a script that blocks progress if checkboxes aren't updated.

Per the investigation's timeline finding: this didn't exist when Python was declared "done" (2025-10-28); it was built three days later (2025-10-31) specifically in response to that failure, and was never applied back to Python. It exists to stop a model from skipping validation steps or claiming "done" without checking — exactly the problem `compare-with-master.sh` (PLAN-001) now solves directly and automatically, without requiring anyone to trust that 13 checkboxes were honestly ticked.

One file doesn't fit that description: `research-otel-sdk-guide.md` (210 lines) is genuine technical reference content (OTel SDK differences across languages), not process scaffolding. It needs a real destination, not deletion or archival alongside the rest.

### The blast radius is wider than the templates directory itself

`grep -rn llm-work-templates` across the whole repo, confirmed line-by-line, turns up substantive dependents (would leave dangling instructions if the directory just vanished) beyond the two files the investigation named:

- `README.md:99-103` — Quick Start steps 3-4 point implementers straight at `research-otel-sdk-guide.md` and `ROADMAP-template.md`.
- `specification/README.md` — flags `llm-work-templates/` `⚠️ CRITICAL` twice in the required-reading table, and references it in the skills section (see below).
- `.claude/skills/implement-language/SKILL.md` — this is the deepest dependency, not a passing link: its entire Step 1/Step 2 flow is "run `init-language-workspace.sh` to create `{language}/llm-work/ROADMAP.md` and `CLAUDE.md`, then read and update them before doing any work." This skill *is* the 13-task-checklist workflow.
- `.claude/skills/_SHARED.md`, `.claude/skills/development-loop/SKILL.md`, `.claude/skills/validate-implementation/SKILL.md`, `.claude/skills/validation-tools/SKILL.md`, `.claude/skills/README.md` — reference the templates or the ROADMAP flow as required reading or as commands to run.

**Revised mid-plan, after Phase 2 (maintainer decision, 2026-07-08):** rather than rewriting `implement-language/SKILL.md` piece by piece, archive the entire `.claude/skills/` directory. These are hand-holding routers built for an earlier, weaker model — mandatory checkpoints, "execute commands don't describe them" reminders, enforced ROADMAP checkbox updates. A capable model doesn't need an automatically-invoked workflow to avoid skipping steps; it reads `specification/implementation-guide.md` directly. Same treatment as `llm-work-templates/`: `git mv` into `.claude/skills-archive/` with a historical banner, not deleted.
- `specification/03-implementation-patterns.md:7`, `specification/09-development-loop.md:307`, `specification/10-code-quality.md:554`, `specification/08-testprogram-company-lookup.md:670-671`, `specification/tools/README.md:240` — cross-links from other numbered spec docs.
- `docs/README-observability-architecture.md:342-344` — links into it.

Passing mentions only (no dependency, just discussing the cleanup or the directory tree): `website/docs/ai-developer/project-sovdev-logger.md:24`, `1PRIORITY.md`, `INVESTIGATE-multi-language-conformance.md` itself.

### `07-anti-patterns.md` (786 lines) is real content in the wrong format

11 code anti-patterns + 4 "Implementation Process Pitfalls" = 15 total, each following `### Problem` (prose) → `### {Lang} Bad Example` (code) → `### {Lang} Correct Example` (code) → `### Why This Matters` (prose), several duplicating the same pattern in both Python and TypeScript. The document's own closing `## ✅ Summary` (lines 757-780) already proves every one of the 15 compresses to a single sentence. The investigation's external research (Oxidizer's "feature mapping" pattern) validates this specific gotcha-to-fix content as the right kind of artifact — the fix is format, not deletion.

---

## Phase 1: Compress `07-anti-patterns.md` into a structured table

### Tasks

- [x] 1.1 Table schema: pattern | don't | do instead | current status (verified against code, not carried forward). Supporting non-prose sections (credential-redaction patterns, file-rotation size table, required-libraries table) kept below the table rather than squeezed into cells.
- [x] 1.2 Rewrote `07-anti-patterns.md`: short intro, 11-row code-anti-patterns table, 4-row process-pitfalls table, both original supporting tables kept intact.
- [x] 1.3 Re-verified every pattern against current `python/src/logger.py` and `typescript/src/logger.ts`, not assumed. **Found two real, previously-undocumented discrepancies** while doing this (not fixed here — doc-only plan, flagged for a future plan): TypeScript's credential redaction is narrower than Python's (only strips axios-specific `config.auth`/`Authorization`, no generic regex redaction of Bearer/API-key/password/JWT/session-ID patterns the way Python does) and TypeScript's `exception_type` isn't fully hardcoded to `"Error"` (falls back to `constructor.name` for non-generic exceptions, unlike Python's unconditional `"Error"`). Also found the "dots in metric names" pitfall doesn't hold today — TypeScript still emits dot-separated names at the SDK level, but the OTel Collector's Prometheus exporter sanitizes them automatically (confirmed via `query-prometheus.sh`'s own underscore-form default metric name) — noted as a clarification, not a live bug.
- [x] 1.4 Measured: 786 → 51 lines (93.5% cut — well past the 150-250 estimate, since a GFM table row is one physical line regardless of cell width; all technical content preserved, confirmed by mapping every one of the original 15 `##`/`###` pattern headers onto exactly one table row).

### Validation

```bash
wc -l specification/07-anti-patterns.md
grep -c "^###" specification/07-anti-patterns.md   # sanity: no orphaned sub-headers from the old structure
```
**Phase 1: DONE.** `grep -c "^###" specification/07-anti-patterns.md` → 0 (no orphaned sub-headers); `grep -c "^| [0-9]"` → 15 (one row per pattern, confirmed).

---

## Phase 2: Shrink `llm-work-templates/` to a pointer, archive the rest

### Tasks

- [x] 2.1 Created `specification/llm-work-templates-archive/` with a historical banner in its `README.md`: superseded 2026-07-08 by `compare-with-master.sh` + this plan, kept for reference, not maintained.
- [x] 2.2 Moved `CLAUDE-template.md`, `ROADMAP-template.md`, `validation-sequence.md`, `task-05-setup-project.md`, `task-templates/` (9 files), `enforcement/` (both scripts), and the old `README.md` into the archive via `git mv` — history preserved (confirmed staged as renames, not add+delete).
- [x] 2.3 Relocated `research-otel-sdk-guide.md` to `specification/research-otel-sdk-guide.md` (top level, alongside the numbered docs).
- [x] 2.4 Wrote `specification/implementation-guide.md` as the new short pointer, replacing `specification/llm-work-templates/` entirely (the old directory no longer exists — nothing was left behind to rename). Points at the API contract, field definitions, the compressed anti-patterns table, `typescript/src/`, and `compare-with-master.sh {language}` as the completion gate.
- [x] 2.5 Confirmed via grep: `.claude/skills/implement-language/SKILL.md` and `specification/README.md` (×2) still called the old `init-language-workspace.sh` path as a live step at that point — handled in Phase 3 (skill deleted) and Phase 4 (`specification/README.md` rewritten).

### Validation

```bash
ls specification/ | grep llm-work   # only llm-work-templates-archive/ remains
find specification/llm-work-templates-archive -type f | sort   # everything moved, 16 files
```
**Phase 2: DONE.** `specification/llm-work-templates/` no longer exists as a directory at all — replaced by the single `specification/implementation-guide.md` file. All 16 files confirmed present in the archive with git history intact (staged as `R`enames, not delete+add).

---

## Phase 3: Delete `.claude/skills/` entirely

Revised scope, twice (see the note under "The blast radius" above): first from "rewrite `implement-language/SKILL.md`" to "archive the whole directory," then — maintainer decision, 2026-07-08 — from archive to outright deletion. Unlike `llm-work-templates/`, nothing here was judged worth keeping even as a historical reference; git history already preserves it if ever needed, so a separate `-archive/` copy in the working tree was redundant.

### Tasks

- [x] 3.1 Deleted all six files (`README.md`, `_SHARED.md`, `development-loop/SKILL.md`, `implement-language/SKILL.md`, `validate-implementation/SKILL.md`, `validation-tools/SKILL.md`) via `git rm -r`. (An intermediate `git mv` into `.claude/skills-archive/` was tried first per the original archive plan, then removed per the maintainer's follow-up call — the end state is a clean deletion, recoverable from git history if ever needed, not an archive directory in the working tree.)
- [x] 3.2 Confirmed `.claude/skills/` and `.claude/skills-archive/` both no longer exist in the working tree.

### Validation

```bash
ls .claude/   # only settings.local.json should remain
git status --short | grep skills   # all six files show as deleted (D), nothing left staged as added
```

---

## Phase 4: Fix every remaining cross-reference and validate the repo is link-clean

### Tasks

- [x] 4.1 `specification/README.md` substantially rewritten (not just link-patched): removed the "Using Claude Code Skills" section and the `llm-work-templates/` `⚠️ CRITICAL` required-reading rows, replaced the ROADMAP-based Quick Start/Implementation Workflow/Key Resources/Key Principles sections with pointers to `implementation-guide.md` and `compare-with-master.sh` as the completion gate. Version bumped to v2.1.0 with a changelog note.
- [x] 4.2 Root `README.md` Quick Start steps 3-5 updated to point at `implementation-guide.md` and `research-otel-sdk-guide.md`'s new location, and `compare-with-master.sh` as the gate (no more ROADMAP-template step).
- [x] 4.3 Fixed `specification/03-implementation-patterns.md`, `specification/09-development-loop.md` (removed the ROADMAP task-tracking section entirely, replaced with a note that there's no per-language checklist anymore), `specification/10-code-quality.md`, `specification/08-testprogram-company-lookup.md`, `specification/tools/README.md`, `docs/README-observability-architecture.md` (also fixed an adjacent stale "Python README (coming soon)" found while editing this exact section — Python has been available since PLAN-002). Also fixed `website/docs/ai-developer/project-sovdev-logger.md` — the directory tree comment, the stale "Go, Python, C#, Rust, PHP planned or in progress" line, and the skills table/description, none of which were in the original grep since they referenced `.claude/skills` by name or described the tree rather than linking the `llm-work-templates` path directly.
- [x] 4.4 Full-repo sweep: zero unexpected `llm-work-templates` or `.claude/skills` hits outside the archive, this plan, and the (correctly historical) mentions in `specification/README.md`'s changelog note and `project-sovdev-logger.md`'s "there used to be" paragraph.
- [x] 4.5 Docusaurus build: **first attempt failed** — a relative Markdown link (`[...](../../../specification/implementation-guide.md)` in `project-sovdev-logger.md`) pointed outside the docs plugin's content root, which Docusaurus's broken-link checker correctly rejects (unlike the repo's established convention of using a GitHub blob URL or plain unlinked backtick text for out-of-tree spec references, as the rest of that file already does). Fixed by switching to plain backtick text, matching the surrounding style. Rebuild succeeded.

### Validation

```bash
grep -rn "llm-work-templates" --include="*.md" --include="*.sh" . | grep -v "plans/backlog/PLAN-003\|plans/backlog/INVESTIGATE-multi-language-conformance\|llm-work-templates-archive\|plans/completed/PLAN-001\|plans/backlog/1PRIORITY\|specification/README.md\|specification/implementation-guide.md\|project-sovdev-logger.md"
cd website && npm run build
```
**Phase 4: DONE.** Sweep returns zero unexpected hits; `npm run build` → `[SUCCESS] Generated static files in "build"`.

---

## Acceptance Criteria

- [x] `specification/llm-work-templates/` no longer exists; replaced by `specification/implementation-guide.md`, not the 13-task ROADMAP/CLAUDE/enforcement system
- [x] All removed `llm-work-templates/` scaffolding is preserved in `specification/llm-work-templates-archive/` with a clear historical banner, moved via `git mv` so history is intact — nothing deleted outright (note: `.claude/skills/` was a separate, later maintainer decision to delete outright rather than archive — see Phase 3)
- [x] `research-otel-sdk-guide.md` has a real home at `specification/research-otel-sdk-guide.md`, not stranded in the archive
- [x] `07-anti-patterns.md` is one structured table (+ the handful of sections that were already tables/lists) covering all 15 currently-documented patterns, with no technical content silently lost — confirmed by mapping every original header onto exactly one row
- [x] `.claude/skills/` is deleted in full (not just `implement-language/SKILL.md` patched) — recoverable from git history, not kept as a working-tree archive
- [x] Zero dangling references to the old `llm-work-templates/` or `.claude/skills/` structure anywhere in the repo (grep-confirmed)
- [x] `website/docs/` builds cleanly after all doc edits (one broken link found and fixed during this check)

---

## Files to Modify

- `specification/07-anti-patterns.md` (compressed into a table, in place)
- `specification/llm-work-templates/` (shrunk to a pointer; exact final name/location decided in Phase 2)
- `specification/llm-work-templates-archive/` (new — houses the removed scaffolding, name TBD in Phase 2)
- `specification/research-otel-sdk-guide.md` or similar (relocated from the templates dir)
- `.claude/skills/` (deleted in full via `git rm -r`, recoverable from git history)
- `specification/README.md`, `README.md` (root), `specification/03-implementation-patterns.md`, `specification/09-development-loop.md`, `specification/10-code-quality.md`, `specification/08-testprogram-company-lookup.md`, `specification/tools/README.md`, `docs/README-observability-architecture.md`, `website/docs/ai-developer/project-sovdev-logger.md` (cross-reference fixes — `specification/README.md` additionally needs its "Using Claude Code Skills" section removed or replaced, since it recommends skills that no longer exist)
