# Investigate: Fix the GitHub fork relationship and npm package's personal-account naming

Both `helpers-no/sovdev-logger` (this repo) and its published npm package (`@terchris/sovdev-logger`) carry a naming/ownership artifact from how the project actually started: development began on `norwegianredcross/sovdev-logger`, then moved to `helpers-no/sovdev-logger` because it was faster to work there — but the fork direction never got flipped, and the npm package was never published under anything but the maintainer's personal npm account. Same root cause, two different fixes, because GitHub forks and npm package names have very different rules for how (or whether) you can undo this.

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Backlog — Part 1 done, Part 2 still open

**Goal**: Decide (a) whether/how to sever the GitHub fork relationship so `helpers-no/sovdev-logger` stops being technically "forked from" an inactive repo, and (b) whether/how to move the npm package off the maintainer's personal account onto an org-scoped name, given npm has no in-place rename.

**Last Updated**: 2026-07-13

**Part 1 outcome**: maintainer rejected waiting on GitHub Support — went straight to Option C (DIY copy), executed same-day. See "What actually happened" under Part 1 below. Part 2 (npm) is untouched, still needs [Q3]–[Q5] answered.

**Context that simplifies this**: the maintainer (`terchris` / `terje@businessmodel.io`) manages **both** `norwegianredcross` and `helpers-no` GitHub orgs, and also owns the only known external consumer of the npm package (`terchris/ollacrm`, per [`INVESTIGATE-ollacrm-onboarding.md`](../completed/INVESTIGATE-ollacrm-onboarding.md)). There is no cross-org negotiation or third-party coordination needed for either fix — every party involved is the same person. This is the cheapest this will ever be to fix; every day it stays as-is, the risk grows that a real third-party consumer starts depending on `@terchris/sovdev-logger` and turns the npm rename into an actually-breaking change for someone else.

---

## Part 1: GitHub fork relationship

### Current state (checked directly, not assumed)

- `helpers-no/sovdev-logger` is a real GitHub fork (`isFork: true`) with parent `norwegianredcross/sovdev-logger`.
- `helpers-no/sovdev-logger` is the *only* fork of `norwegianredcross/sovdev-logger` (confirmed via the forks API) — nothing else in the fork network to break.
- `norwegianredcross/sovdev-logger` has been inactive since 2025-11-27 (`pushedAt`), has 0 stars/watchers, and exactly one open item: a harmless Dependabot PR (#2, bump `js-yaml` 4.1.0 → 4.1.1).
- Every practical piece of the project already lives on `helpers-no`: npm package's `repository`/`homepage`/`bugs` fields, all CI/CD (`CI - TypeScript`, `Deploy Documentation`), GitHub Pages (custom domain `sovdev-logger.sovereignsky.no`), and issue #23 (the production feedback issue this session's recent work stemmed from).
- GitHub does not expose fork detachment via any REST API or `gh` CLI command. The only official route is a support ticket asking GitHub to detach a fork into a standalone repository — this preserves issues, PRs, stars, Actions history, and Pages config, and does not modify `norwegianredcross/sovdev-logger` itself.

### Options

**Option A: Leave it as-is.** Zero effort, but `helpers-no/sovdev-logger`'s GitHub page keeps showing "forked from norwegianredcross/sovdev-logger" indefinitely, and the two repos stay linked in GitHub's fork network/insights graph forever.

**Option B: File a GitHub Support ticket to detach the fork.** Free, official, preserves everything on `helpers-no`'s side. Only the repo/org owner can file it (the maintainer already is both). One manual step outside any tooling here — I can draft the exact ticket text, but submitting it isn't something `gh`/API access can do.

**Option C: DIY — create a brand-new non-fork repo and migrate.** Push the full history to a fresh repo, migrate issues/PRs by hand or via API, redirect CI secrets and GitHub Pages, retire the old name. Achieves the same end state as Option B but with far more manual work and more chances to lose something (issue numbering, Actions run history) along the way. No reason to choose this over B unless GitHub Support declines the request.

**Separately, regardless of A/B/C**: what happens to `norwegianredcross/sovdev-logger` itself? It's not deleted by a fork-detach (Option B only affects `helpers-no`'s side of the relationship). Worth deciding: archive it (GitHub's native, self-service "Archive this repository," reversible) with a README note pointing to `helpers-no/sovdev-logger`, so anyone who finds it via an old link isn't misled into thinking it's current. The one open Dependabot PR there should be closed or merged first, since post-archive it'll be unmergeable.

### Recommendation

~~**Option B** for the fork relationship, plus archiving `norwegianredcross/sovdev-logger` (self-service, reversible, doable now) with a pointer to the real repo. Archiving doesn't require waiting on the support ticket and is worth doing either way.~~ **Superseded same-day**: the maintainer said "not fork, just copy it — skip waiting for GitHub," so Option C (DIY) shipped instead. Left here struck through, not deleted, so the record is honest about what was recommended vs. what was actually decided.

### What actually happened (Option C, executed 2026-07-13)

Turned out much cheaper than this doc's own Option C estimate ("far more manual work... more chances to lose something") — because the name/URL stayed identical throughout, almost nothing needed updating:

1. `gh repo rename sovdev-logger-old-fork --repo helpers-no/sovdev-logger` — freed the `sovdev-logger` name, GitHub auto-redirected it to the renamed repo in the meantime.
2. `gh repo create helpers-no/sovdev-logger --public` — a genuinely fresh repo, confirmed via API (`isFork: false`, `parent: null`).
3. `git push --mirror origin` from the local clone — carried every branch, tag, and the full commit history. **Caught a real gotcha**: `--mirror` also pushed local remote-tracking refs (`refs/remotes/origin/*`, `refs/remotes/upstream/*`) as if they were literal branches, cluttering the new repo with junk like a branch named `origin/HEAD`. Fixed by recreating `feature/docusaurus-homepage` under its proper name and deleting the five stray `refs/remotes/*` entries — verified clean via `git ls-remote` (no filter) before and after.
4. GitHub Pages: enabled on the new repo (`build_type=workflow`), manually dispatched the `Deploy Documentation` workflow (its normal trigger is a push touching `website/**`, which a mirror-push doesn't count as), then moved the `sovdev-logger.sovereignsky.no` custom domain over — had to null out the domain on the old (renamed) repo first, since GitHub blocks the same custom domain existing on two repos in one org at once.
5. **The HTTPS cert reprovisioned instantly** (`state: "approved"` on the very next API call, same expiry date as before) — no real downtime, confirmed by curling the live domain and finding real `sovdev-logger` page content, not a placeholder. Better than the "minutes to a few hours" risk flagged before starting; the maintainer had already explicitly accepted that risk via `AskUserQuestion` before this step ran.
6. Local git: removed the now-pointless `upstream` remote (was `norwegianredcross/sovdev-logger`) — `origin`'s URL string didn't need to change at all, since owner+name ended up identical to before.
7. `gh repo archive helpers-no/sovdev-logger-old-fork` — read-only now, still fully browsable, so issue #23 (heavily cross-referenced by number throughout this repo's own docs) stays live at its new URL.
8. Updated the 3 doc files that hardcoded `.../sovdev-logger/issues/23` to point at `.../sovdev-logger-old-fork/issues/23` instead — the *generic* issue-tracker links in `README.md` and `typescript/package.json`'s `bugs` field were left alone, since those correctly point at the new repo for future issues.
9. Carried over `homepage` and repo topics (`logging`, `observability`, `opentelemetry`, `sovereignsky`) from the old repo to the new one — confirmed no branch protection rules existed to replicate.

**Not done, deliberately out of scope for Part 1**: `norwegianredcross/sovdev-logger` itself was left untouched (not archived) — since the copy approach never depended on it, archiving it is now a fully independent, lower-urgency cleanup, not a blocker for anything.

---

## Part 2: npm package's personal-account naming

### Current state (checked directly)

- Published as `@terchris/sovdev-logger`, currently `1.0.2`. `_npmUser` and sole maintainer: `terchris <terje@businessmodel.io>` — a personal npm account and personal email, not an org.
- No `@helpers-no` npm org/scope exists yet (confirmed: 404 on the registry).
- **npm has no rename.** The name is permanent once published; moving to a different scope means publishing a *new* package name and (optionally) deprecating the old one via `npm deprecate` — a breaking change for anything that has `@terchris/sovdev-logger` in its `package.json`.
- Checked alternative names for availability (all free, none registered): `sovdev-logger` (unscoped), `@helpers-no/sovdev-logger`, `@sovdev/logger`, `@sovdev/sovdev-logger`, `@redcross-no/sovdev-logger`.
- The only known real consumer is `terchris/ollacrm` (private, maintainer-owned) — per the current context note above, this is as low-risk as an npm rename will ever get, since there's no independent third party to coordinate a migration with yet.

### Options

**Option A: Do nothing to the name.** Just add other org members as additional `npm owner`s of the existing `@terchris/sovdev-logger` package, so publishing doesn't depend on one person's personal npm account being available. Doesn't fix the branding/naming complaint, but removes the single-point-of-failure risk.

**Option B: Create an org-scoped name and migrate.** Register an npm org (free for public packages), publish the identical code under a new scoped name (e.g. `@helpers-no/sovdev-logger`, matching the GitHub org for consistency), bump to a new major version to signal the break, `npm deprecate` the old `@terchris/sovdev-logger` with a message pointing at the new name, update `ollacrm`'s dependency, and update every doc/README/`package.json` in this repo that references the old name.

**Option C: Keep `@terchris/sovdev-logger` as a compatibility re-export.** Publish the new scoped name as the real package, but keep publishing new `@terchris/sovdev-logger` versions too, as a thin wrapper that just re-exports the new package — avoids ever fully breaking old installs. More ongoing maintenance burden (two packages to keep in sync forever) for a problem that Option B's `npm deprecate` message already solves more simply, given there's currently exactly one consumer to migrate and the maintainer controls it.

### Recommendation

**Option B**, while the blast radius is still just one maintainer-controlled consumer. Waiting makes this strictly more expensive, never less.

---

## Open Questions

1. **[Q1]** — **Resolved, differently than recommended.** Not a GitHub Support ticket — maintainer chose Option C (DIY copy) same-day. See "What actually happened" above.
2. **[Q2]** — **Deferred, no longer urgent.** Archiving `norwegianredcross/sovdev-logger` was originally tied to the fork-detach approach; since Option C never depended on it, this is now an independent, lower-priority cleanup item (Tier 5-ish) rather than a blocking question.
3. **[Q3]** Pick the new npm scope name (Part 2, Option B) — candidates checked and available: `@helpers-no/sovdev-logger` (matches the GitHub org), `@sovdev/logger`, `sovdev-logger` (unscoped), or another name entirely.
4. **[Q4]** Any preference on version bump strategy for the npm rename — a final `@terchris/sovdev-logger` release that's just the deprecation notice, or deprecate the current `1.0.2` as-is and never publish under that name again?
5. **[Q5]** Timing relative to the still-open `INVESTIGATE-otel-dependency-upgrade.md` — bundle the npm rename with that dependency bump (one breaking-change release instead of two), or keep them fully independent?

## Next Steps

- [x] Part 1 (GitHub fork relationship) — shipped, see "What actually happened" above
- [ ] Maintainer answers [Q3]–[Q5] (Part 2, npm)
- [ ] Create `PLAN-npm-package-rename.md` once [Q3]–[Q5] are settled — covers the actual npm org creation, publish, deprecation, and updating every reference in this repo (`package.json`, README badges/install instructions, Docusaurus docs) and in `ollacrm`
- [ ] Whenever convenient, decide whether to archive `norwegianredcross/sovdev-logger` (Q2) — no longer blocking anything
