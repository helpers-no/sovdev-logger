# Migrate the specification's and docs/'s remaining prose into the Docusaurus site

PLAN-005 built `website/docs/general/`, `using/`, and `contributor/` and populated the one acute gap (the OTLP rationale). `using/` and `contributor/` are still labeled `**Stub.**` — this plan does the actual migration: `specification/`'s prose (`00-design-principles.md` through `10-code-quality.md`, `implementation-guide.md`, `research-otel-sdk-guide.md`) moves into `contributor/`, and the remaining `docs/*.md` files (configuration, logging concepts, observability architecture, Loggeloven) move into `using/`. Per-language package READMEs (`typescript/README.md`, `python/README.md`) are explicitly **not** duplicated into the site — they stay the canonical, externally-distributed source `using/index.md` links to, per [Q2]'s decision in the parent investigation.

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Completed

**Completed**: 2026-07-08

**Investigation**: [INVESTIGATE-documentation-strategy.md](INVESTIGATE-documentation-strategy.md) — Option C, the explicitly-scoped follow-up to [PLAN-005-documentation-restructure.md](PLAN-005-documentation-restructure.md)

**Goal**: `website/docs/contributor/` contains the specification's design rationale, API contract, field definitions, and process docs — moved, not duplicated, from `specification/*.md`. `website/docs/using/` contains the configuration, log-structure, observability, and compliance docs — moved from `docs/*.md`. Both repo-root locations become short pointers to their new home (matching how `docs/README-microsoft-opentelemetry.md` was already handled in PLAN-005), not second copies. `typescript/README.md`/`python/README.md` are untouched — they're not in scope for migration, only for linking.

**Last Updated**: 2026-07-08

---

## Problem

### The scale is real — this isn't a small follow-up

Measured directly: `specification/*.md` (excluding `README.md`, already handled) is 8,418 lines across 13 files; the remaining `docs/*.md` (excluding the already-migrated Azure doc) is 2,690 lines across 5 files. Roughly 80 internal cross-references exist between the numbered `specification/` docs alone (`grep` count, e.g. `05-environment-configuration.md` references 14 sibling docs). This is why PLAN-005 scoped it out as a separate plan rather than attempting it in the same pass as the information architecture.

### The duplication trap this plan must not fall into

The whole point of PLAN-005 (and the investigation behind it) was ending the pattern where the same content exists in two places and drifts. Naively "adding" the specification's content to `contributor/` while leaving the originals in `specification/` would recreate exactly that. **Decision made before scoping tasks, not left implicit**: `specification/*.md` prose *moves* to `contributor/` — the repo-root files become pointers, the same treatment already given to `docs/README-microsoft-opentelemetry.md` in PLAN-005. `specification/schemas/`, `specification/tests/`, `specification/tools/` are unaffected — they're functional code, not documentation, and were never in scope for either plan.

### Package READMEs are a different case and should not be moved

`typescript/README.md` and `python/README.md` are what actually ships and renders on GitHub/npm/PyPI — they can't become pointers to the Docusaurus site without leaving GitHub/package-registry visitors with a degraded page. Per [Q2] (already decided), TypeScript's README stays canonical and other languages diff against it. This plan's `using/` migration is scoped to content that has no such external-distribution constraint (configuration, log structure, observability, compliance) — the quickstart content in the package READMEs stays exactly where it is, linked from `using/index.md`, not copied.

---

## Phase 1: Move `specification/`'s prose into `contributor/`

### Tasks

- [x] 1.1 `git mv` all 13 files into `website/docs/contributor/`, added frontmatter (title/sidebar_label/sidebar_position/description), ordered per `specification/README.md`'s existing "Core Documents (Read in Order)" list (`implementation-guide.md` first, then design-principles/research-otel-sdk-guide/api-contract/development-loop, then the remaining numbered docs) rather than plain numeric filename order.
- [x] 1.2 Fixed cross-references — but **the real work here was different from what this task assumed**. Most of the ~80 same-folder references (`01-api-contract.md`, `07-anti-patterns.md`, etc.) needed no change at all — Docusaurus resolves bare relative `.md` links within the same folder automatically. The actual broken links (found only by building, not by the earlier grep count) were the ~10 references to content that did **not** move — `specification/tools/`, `specification/schemas/`, `llm-work-templates-archive/`, `typescript/README.md`, `python/README.md`, and two links to PLAN-003/PLAN-004 whose relative path from the new location was simply wrong. Fixed by converting the former to GitHub blob/tree URLs (matching the pattern already used in `using/azure-integration.md`) and the latter to the correct `../ai-developer/plans/completed/...` relative paths.
- [x] 1.3 Rewrote `contributor/index.md` into a real "Start here" / "Core documents" / "Supporting documents" page list (13 links), plus a "Functional code (not migrated)" section pointing at `specification/schemas/`/`tests/`/`tools/` on GitHub, since those explicitly stay in the repo.
- [x] 1.4 Rewrote `specification/README.md`: a two-paragraph pointer to `contributor/` for the prose, plus what's still actually in the directory (`schemas/`, `tests/`, `tools/`, `llm-work-templates-archive/`) since — unlike `docs/README-microsoft-opentelemetry.md`, which had nothing left behind — this file still has a real job describing the functional code that didn't move.
- [x] **Two real build-breaking bugs found and fixed, neither anticipated by the task list:**
  - **YAML frontmatter bug**: `title: Test program: company lookup` — the colon inside an unquoted YAML scalar broke frontmatter parsing entirely. Fixed by quoting the value. A one-file mistake, but worth noting since it's the kind of thing that will recur if titles are ever machine-generated from headers containing colons.
  - **MDX/CommonMark bug, much bigger**: 8,400 lines of legacy specification prose is full of bare `<placeholder>` tokens (`<error>`, `<language>`, `<uuid>`, etc.) and JSON snippets in table cells (`{"key":"value"}`). Docusaurus's actual default (confirmed by reading `@docusaurus/core`'s `configValidation.js`) is `format: 'mdx'` for **every** file regardless of extension — not, as assumed, plain CommonMark for `.md` files. MDX tries to parse bare `<word>` as an unclosed JSX tag and bare `{...}` as a JS expression, and both failed to parse. Fixed at the site level, not per-file: `docusaurus.config.ts`'s `markdown.format` set to `'detect'`, so `.md` files get plain CommonMark (matching what this legacy content actually assumes) and `.mdx` files (none yet, but the option stays open) get full MDX. Checked first that no existing content relies on real MDX features (JSX imports/components) before making this site-wide change — confirmed by grep, the only `import` matches were inside code-block examples (TypeScript/Python/Go/Java snippets), not real MDX imports.

### Validation

```bash
cd website && npm run build
```
Confirm zero broken links from the ~80 fixed cross-references, and spot-check 3-4 of the moved pages render with correct sidebar position/labels.

**Phase 1: DONE.** `npm run build` → `[SUCCESS] Generated static files in "build"`. `specification/` now contains only `README.md` (pointer) plus `schemas/`, `tests/`, `tools/`, `llm-work-templates-archive/` — confirmed via `ls`, no stray `.md` prose left behind.

---

## Phase 2: Fix external references to the old `specification/*.md` paths

### Tasks

- [x] 2.1 Fixed live references in `README.md`, `python/src/logger.py` (a code comment), `typescript/build-sovdevlogger.sh` (a build-script comment), `website/docs/ai-developer/project-sovdev-logger.md` (including its repo-tree diagram), `docs/README-observability-architecture.md` (4 links), `specification/tools/README.md` (3 links), `specification/tools/run-company-lookup.sh` (2 echo statements), and `specification/schemas/README.md` (2 links) — all converted to the new site URLs.
- [x] 2.2 Left historical mentions in `plans/completed/*.md` and the INVESTIGATE files alone, as planned.
- [x] 2.3 Checked `specification/tools/*.sh` and `specification/tests/*.py` for same-directory-relative references (a pattern the `specification/`-prefixed grep wouldn't catch) — zero hits.
- [x] **Found and fixed a much bigger, previously-invisible bug while doing this sweep**: every site URL written throughout PLAN-005 and this plan's Phase 1 (e.g. `https://sovdev-logger.sovereignsky.no/general/why-otlp`) was missing a `/docs/` path segment — Docusaurus's actual configured route base path is `docs` (the classic preset default), so the real URL was `/docs/general/why-otlp`, and none of this was ever caught by the build's broken-link checker because fully-qualified `https://` URLs are treated as external and never validated. Root-caused (not just patched): the site's docs plugin was using the default `routeBasePath: 'docs'` while `docs/index.md`'s own `slug: /` frontmatter clearly intended the docs content to *be* the site root — a latent mismatch between intent and configuration that predates this plan. Fixed the mismatch itself rather than adding `/docs/` to every link already written: set `routeBasePath: '/'` on the docs plugin (and the search plugin's `docsRouteBasePath`), which required removing the generic, never-customized Docusaurus template homepage (`src/pages/index.tsx` + its `HomepageFeatures` component, confirmed unused elsewhere) since Docusaurus won't allow two things claiming route `/`. Verified by checking the actual built HTML titles at `build/general/why-otlp/index.html` etc. — all render at the intended root-level paths now. This retroactively makes every link from PLAN-005 correct too, not just this plan's new ones.
- [x] Also fixed a handful of unlinked (not broken-link-checker-visible, but factually stale) plain-text mentions of `specification/09-development-loop.md` etc. inside the moved `contributor/*.md` files themselves, for accuracy.

### Validation

```bash
grep -rn "specification/0[0-9]-\|specification/1[0-9]-\|specification/implementation-guide.md\|specification/research-otel-sdk-guide.md" --include="*.md" --include="*.sh" --include="*.py" . | grep -v "plans/completed\|plans/backlog/INVESTIGATE"
cd website && npm run build
```
**Phase 2: DONE.** Zero unexpected hits outside historical plan/investigation mentions and the frozen `llm-work-templates-archive/`. Build clean. Spot-checked `build/general/why-otlp/index.html`, `build/contributor/implementation-guide/index.html`, `build/using/azure-integration/index.html` — all present at the correct root-level routes.

---

## Phase 3: Move the remaining `docs/*.md` into `using/`

### Tasks

- [x] 3.1 `git mv`'d all 5 files into `website/docs/using/`, dropping the `README-` prefix (not a Docusaurus convention, just a repo-markdown one — `README-configuration.md` → `configuration.md`), added frontmatter continuing from `azure-integration.md`'s position 1.
- [x] 3.2 Fixed cross-references: `observability-architecture.md` had 5 broken links to sibling files under their old filenames and to `typescript/README.md`/`python/README.md`/`go/README.md` (outside the docs plugin) — fixed the former to the new sibling filenames, the latter to GitHub URLs (Go's link removed entirely, unlinked "coming soon" text, since there's no Go README to link to). Checked the other 4 moved files for the same pattern — none had it. Fixed the root `README.md`'s Documentation section (4 links) to point at the site instead of the old `docs/` paths. Checked `typescript/README.md`/`python/README.md` for `docs/` references — only one hit, already correct (a `specification/tools/README.md` link, unaffected by this migration).
- [x] 3.3 Rewrote `using/index.md`: a "Quickstart per language" section explicitly explaining why the package READMEs aren't duplicated here (linking [Q2] in the investigation), plus a full "Pages" list for all 6 migrated docs (Azure integration + the 5 from this phase).
- [x] 3.4 Left individual short pointers at each old `docs/` path (matching `docs/README-microsoft-opentelemetry.md`'s existing precedent from PLAN-005) rather than one consolidated index — consistency with what's already there won over consolidation.

### Validation

```bash
cd website && npm run build
```
**Phase 3: DONE.** Zero broken links; `README.md`'s Documentation section now points at the site instead of `docs/*.md`; `docs/` contains only the 6 pointer files and `images/` (unreferenced, left alone — out of scope).

---

## Phase 4: Final validation

### Tasks

- [x] 4.1 Full-repo grep sweep — zero unexpected hits outside historical narrative in this plan's own Phase 1/2 notes.
- [x] 4.2 Re-ran `specification/tools/check-doc-consistency.py` — still passes. Not extended to check specification/docs internal links: no concrete, recurring gap surfaced during this migration that a check like that would have caught (every issue found was caught by the Docusaurus build itself, which already re-runs on every relevant change).
- [x] 4.3 Full Docusaurus build — clean.
- [x] 4.4 Updated the parent investigation's Next Steps and Status to reflect this plan's completion, closing out the investigation (see `INVESTIGATE-documentation-strategy.md`).

### Validation

```bash
grep -rn "specification/0[0-9]-\|specification/1[0-9]-\|docs/README-configuration.md\|docs/README-loggeloven.md\|docs/README-logging-concepts.md\|docs/logging-data.md" --include="*.md" . | grep -v "plans/completed\|plans/backlog/INVESTIGATE"
python3 specification/tools/check-doc-consistency.py
cd website && npm run build
```
**Phase 4: DONE.** Zero unexpected hits, consistency check passes, build clean.

---

## Acceptance Criteria

- [x] `website/docs/contributor/` contains the full specification's prose, moved (not duplicated) from `specification/*.md`
- [x] `website/docs/using/` contains the remaining `docs/*.md` content, moved (not duplicated)
- [x] `typescript/README.md`/`python/README.md` are untouched — linked from `using/index.md`, not migrated
- [x] `specification/README.md` and `docs/` are short pointers to their content's new home, not dangling or duplicated
- [x] Zero broken cross-references (internal to the moved docs, or from anywhere else in the repo) — confirmed by grep sweep and a clean Docusaurus build
- [x] The parent investigation's Next Steps reflect this plan's completion
- [x] **Not originally scoped, found and fixed along the way**: every site link written in this plan and PLAN-005 was missing a `/docs/` path segment, root-caused to a docs-plugin routing misconfiguration and fixed by setting `routeBasePath: '/'` — verified against the real, live GitHub Pages site (`https://sovdev-logger.sovereignsky.no`), which was also fully set up and deployed during this plan (Pages hadn't been enabled at all before; every prior deploy had been silently failing)

---

## Files to Modify

- `website/docs/contributor/` (13 files moved in from `specification/`, `index.md` rewritten)
- `website/docs/using/` (5 files moved in from `docs/`, `index.md` rewritten)
- `specification/README.md` (shrunk to a pointer)
- `docs/` (remaining files become pointers or a single index pointer)
- Any file found in Phase 2/4's sweeps referencing the old paths
