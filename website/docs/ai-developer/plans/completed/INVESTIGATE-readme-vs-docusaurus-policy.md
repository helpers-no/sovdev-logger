# Investigate: When does a README point into Docusaurus, and when does it stay self-contained?

Triggered by a real link in the new dashboard-walkthrough page pointing out to GitHub for `tools/dashboards/README.md` — decides a general rule for every README in the repo: which ones must stay self-contained (and Docusaurus links out to them), and which ones should instead be thin pointers into Docusaurus, with the substantive content living on the site.

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Resolved — rule confirmed and applied

**Goal**: A clear, repo-wide rule for README-vs-Docusaurus content placement, so this decision doesn't get re-litigated one link at a time.

**Last Updated**: 2026-07-10

**Outcome**: Maintainer confirmed the rule. Before applying it, audited every other Docusaurus page linking to a `tools/**/README.md` (six links across `05-environment-configuration.md`, `09-development-loop.md` x2, `08-testprogram-company-lookup.md` x2, `06-test-scenarios.md` x2, plus the `index.md` reference) — all of them already inline the essential command and link out only for "complete/authoritative" reference. `dashboard-walkthrough/index.md` was the sole outlier (a bare link, no inlined command); fixed by adding the `push-dashboard.ts` invocation directly to its "See also" section. Also swept every other `.md` file in the repo (73 total) for anything else needing the same treatment: the root `docs/*.md` pointer files are a different, already-completed case (PLAN-005/006); `.devcontainer.extend/`, `.devcontainer.secrets/`, `python/llm-work/`, `terchris/refactoring-plan/` READMEs aren't linked from Docusaurus at all; `plans/talk/README.md` is a trivial self-contained note. Nothing else needed changing. `npm run build` clean after the fix.

---

## This isn't a new question — it's an extension of an existing decision

`INVESTIGATE-documentation-strategy.md` (completed) already decided part of this, in [Q2] and its Option C: `typescript/README.md` stays **canonical** — Python's README diffs against it rather than duplicating it, and neither gets copied into Docusaurus. Separately, that investigation decided `specification/schemas/`, `specification/tests/`, `specification/tools/` (now `tools/`) "stay exactly where they are — they're functional code..., not documentation to migrate."

What that investigation didn't address: **why** those two categories get different treatment, and what that implies for a case like `tools/dashboards/README.md` — a tool README, being linked to from a Docusaurus *narrative* page for the first time.

## The actual distinguishing factor: does it have an audience Docusaurus can't reach?

Checked every README in the repo directly:

| README | Published where Docusaurus isn't rendered? | Current treatment |
|---|---|---|
| `README.md` (root) | Yes — GitHub's own repo-landing-page render | Stays self-contained (already decided — Option C item 5: shrinks to a pitch, but still standalone) |
| `typescript/README.md` | Yes — npm package page | Canonical, not duplicated (decided, [Q2]) |
| `python/README.md` | Yes — PyPI, if/when published | Diffs against TypeScript's, not duplicated (decided) |
| `tools/README.md`, `tools/dashboards/README.md`, `tools/validation/{schemas,uis,validators}/README.md` | **No** — only ever viewed on GitHub by someone already browsing the repo, or reading the file directly | **Not decided until now** |

The root/TypeScript/Python READMEs have a real, external, Docusaurus-blind audience (npm, PyPI, GitHub's own landing page) — that's *why* they must stay self-contained, not because READMEs are inherently special. The `tools/**/README.md` files have no such audience. Nobody encounters `tools/dashboards/README.md` by visiting a package registry; the only ways to see it are already-inside-the-repo contexts (GitHub file browser, an editor, a clone) — contexts where a link to the Docusaurus site works exactly as well as a link to another repo file.

This is the same logic Diátaxis (already invoked in the prior investigation) uses to separate **reference** from **explanation**: reference material lives right next to the thing it describes (a tool's README, terse, command-and-flags), while explanation — the narrative that connects several pieces of reference material into a story — belongs somewhere a reader browses by topic, which is what Docusaurus is for. A tool README doesn't need to *also* be the explanation.

## Recommendation

**Tool READMEs (`tools/**/README.md`) stay in place as terse reference** — commands, flags, file layout — exactly as they are today. Nothing changes there; they're correctly scoped already (confirmed by re-reading all 4 during this investigation — none of them are trying to be narrative explanation, they're already command references).

**Docusaurus pages that need to point at a tool don't jump to GitHub for information the reader needs immediately.** Concretely, for `dashboard-walkthrough/index.md`'s link to `tools/dashboards/README.md`:
- **Inline** the one command a reader actually needs at that point (`npx tsx push-dashboard.ts` with its env vars) directly in the Docusaurus page — no GitHub trip required for something this small.
- **Link out** only for the *full* reference (all flags, the file layout, the correlation script) — a reader who wants to actually build or modify the tool, not just understand what produced a panel, is the one who should end up on GitHub.

This isn't "never link to GitHub" — it's "don't make a reader leave Docusaurus for information short enough to just include." The same rule that already governs `typescript/README.md`/`python/README.md` links (link out because the *canonical* content lives there) applies in reverse here: link out only for content that *has* to live in the tool's own README (because it's edited alongside the code), inline anything small enough not to force a context switch.

## Next Steps

- [x] Maintainer confirms this rule (tool READMEs = terse reference, stay in place; Docusaurus pages inline small essentials, link out only for full reference)
- [x] Apply it to `dashboard-walkthrough/index.md`'s `tools/dashboards/README.md` link — inline the push command
- [x] No other repo READMEs need to change — confirmed via a full repo-wide `.md` sweep, not just the 4 `tools/**/README.md` files
