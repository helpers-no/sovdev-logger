# Investigate: npm Trusted Publishing (OIDC) for sovdev-logger

Spun off from [`INVESTIGATE-library-best-practices.md`](../completed/INVESTIGATE-library-best-practices.md)'s [Q5]: whether to move `sovdev-logger`'s publish process from a manual, personal-OTP-gated DevContainer step to npm's Trusted Publishing (OIDC via GitHub Actions) — removing the dependency on the maintainer's personal npm account/token at publish time, and adding cryptographic build provenance. Directly follows on from `INVESTIGATE-repo-and-package-ownership.md`'s findings about the package's personal-account history.

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Backlog — all questions resolved, ready for a PLAN

**Goal**: Decide whether to move to Trusted Publishing, and if so, design the GitHub Actions release workflow and the exact npmjs.com configuration.

**Last Updated**: 2026-07-13

---

## What Trusted Publishing actually is (researched, not assumed — sources at bottom)

OIDC-based publishing: GitHub Actions generates a short-lived identity token proving "this run, from this exact repo/workflow, is who it claims to be," and npm trusts that instead of a long-lived `_authToken` stored anywhere. No npm token to leak, rotate, or scope — and no personal OTP needed at publish time, since the *workflow run* is the credential, not a person's account.

**Concretely, this requires**:
- npmjs.com side: on the package's own settings page (`npmjs.com/package/sovdev-logger/access` — not the general packages list, a real first-time gotcha per the research), configure a "Trusted Publisher": GitHub org/user, repo, and the *exact* workflow filename (e.g. `publish.yml`) — case-sensitive, must match exactly. Each package can have only **one** trusted publisher configured at a time.
- GitHub Actions side: the publish job needs `permissions: id-token: write` (plus `contents: read`), npm CLI **v11.5.1+** (may need an explicit `npm install -g npm@latest` step — the DevContainer/CI's current npm version hasn't been checked yet, see [Q1]), and `actions/setup-node` configured with `registry-url: 'https://registry.npmjs.org'`.
- `package.json`'s `repository.url` must exactly match the GitHub repo Trusted Publishing is configured against — already true for `sovdev-logger` (points at `helpers-no/sovdev-logger`, confirmed during the npm rename work).
- Provenance attestations are supposed to generate automatically once Trusted Publishing is active and the repo is public — but one real-world report found `--provenance` still needed to be passed explicitly despite the docs saying otherwise. Worth verifying hands-on rather than trusting either source blindly.
- As of May 2026, new Trusted Publisher configurations require explicitly selecting which actions are allowed (`npm publish`, `npm stage publish`, or both) — at least one must be selected.
- Only cloud-hosted GitHub-provided runners are supported today; self-hosted runners aren't yet.

**Resolved via direct research (2026-07-13), no longer blockers**:
- **Retroactive setup on an already-published package is the *normal*, documented path — not an edge case.** Confirmed via a tracked `npm/cli` GitHub issue (#8544, still open as of this check): *"The main problem is that the UI on npmjs.com requires a package to exist before you can edit its settings and enable OIDC publishing."* That issue is about the opposite ask — wanting OIDC for a package's very first-ever publish, which currently isn't possible. `sovdev-logger` already exists (published manually 2026-07-13), so it's squarely in the supported case.
- **Manual publishing is not disabled by configuring Trusted Publishing.** Straight from npm's own docs, fetched directly (not summarized secondhand): *"When you configure a trusted publisher for your package, npm will accept publishes from the specific workflow you've authorized, in addition to traditional authentication methods like npm tokens and manual publishes."* There's an optional "Require two-factor authentication and disallow tokens" setting that *would* disable token auth if explicitly turned on — opt-in, not automatic, and OIDC/trusted-publisher access keeps working even with it enabled.
- **[Q4] resolved too, while checking**: the current npm CLI version satisfies `>=11.5.1` **nowhere** in this repo's actual environments — host Mac (`10.2.4`), DevContainer (`10.9.7`), and CI's default via `actions/setup-node@v4` + Node 22 (ships npm 10.x, not 11.x). Any publish workflow needs an explicit `npm install -g npm@latest` step; this isn't optional.

---

## Current state (this repo)

- Publishing today is entirely manual: `contributor/publishing/typescript.md` documents running `npm login` + `npm publish --access public` from a real interactive terminal (this session confirmed it works from the host Mac directly, correcting that doc's earlier claim it required the DevContainer) — always needs a live OTP from the maintainer's authenticator app, every single publish.
- `typescript/package.json`'s `repository.url` already points at `helpers-no/sovdev-logger` — no metadata blocker.
- No release/publish GitHub Actions workflow exists today — `ci.yml` and `deploy-docs.yml` are the only two workflows, neither touches npm.
- `sovdev-logger` was published for the first time under its current (unscoped) name on 2026-07-13, manually — now confirmed to be the *supported* starting point for Trusted Publishing, not a blocker.

---

## Options

### Option A: Adopt Trusted Publishing now

Design a `publish.yml` GitHub Actions workflow (likely `workflow_dispatch`-triggered, or triggered by a version tag), configure the npmjs.com Trusted Publisher settings, remove the dependency on a personal OTP for routine releases.

**Pros**: closes the "personal npm account" concern from `INVESTIGATE-repo-and-package-ownership.md` more completely than the rename alone did — the rename fixed the *name*, this would fix *who/what can publish*. Adds provenance attestation as a side effect. No more "maintainer needs to be at their laptop with 2FA in hand" for every release.

**Cons**: real setup work, plus the two unconfirmed items above could turn into blockers discovered mid-implementation, not before.

### Option B: Keep manual publishing, revisit later

**Pros**: zero effort now; publishing already works, if with friction.
**Cons**: the friction (personal OTP every time) and the underlying "one person's account gates every release" concern persist indefinitely.

### Option C: Add `--provenance` to the existing manual publish flow, defer full Trusted Publishing

A smaller, in-between step: manual `npm publish --provenance` still uses a personal account/token, but *can* generate provenance attestations without the full OIDC/GitHub-Actions migration — worth checking whether `--provenance` works at all outside a CI/OIDC context, since some npm provenance features are documented as CI-only.

**Pros**: might get some of the attestation benefit without the full workflow-migration effort.
**Cons**: doesn't address the actual friction (OTP-gated manual publish) or the "one person's account" concern at all — provenance without removing the manual-token dependency is a partial fix at best, and needs verifying `--provenance` even works manually before treating this as a real option.

---

## Recommendation

**Option A**, now that [Q1]/[Q2]/[Q4] are resolved and none of them block it. Directly closes a concern this session's own npm-rename work already flagged as only partially resolved — the rename fixed the package's *name*, this fixes *who/what can publish*, without giving up the manual fallback.

---

## Open Questions

1. **[Q1]** — **Resolved.** Trusted Publishing works retroactively on an already-manually-published package like `sovdev-logger` — confirmed this is the standard, documented path, not an edge case. See `npm/cli` issue #8544 above.
2. **[Q2]** — **Resolved.** Manual `npm publish` (with personal OTP) keeps working as a fallback after configuring a Trusted Publisher — confirmed directly from npm's own docs, not inferred.
3. **[Q3]** — **Resolved.** `workflow_dispatch` (manual button) — closest to today's process, least process change, still removes the OTP step.
4. **[Q4]** — **Resolved.** No, the current npm CLI version satisfies `>=11.5.1` nowhere in this repo (host `10.2.4`, DevContainer `10.9.7`, CI's `actions/setup-node@v4`+Node 22 default is npm 10.x) — the workflow needs an explicit `npm install -g npm@latest` step.
5. **[Q5]** — **Resolved.** No — keep this scoped strictly to the auth mechanism. Manual `package.json` version bumps stay as-is; `changesets`/`semantic-release` stays a separate, smaller-scoped future idea rather than bundled here.

## Next Steps

- [x] Answer [Q1]/[Q2]/[Q4] directly — all resolved 2026-07-13 via npm's own docs and a tracked `npm/cli` issue, not inference
- [x] Maintainer answers [Q3] and [Q5] — resolved 2026-07-13
- [x] Create [`PLAN-npm-trusted-publishing.md`](../active/PLAN-npm-trusted-publishing.md)

## Sources checked

- [Trusted publishing for npm packages — npm Docs](https://docs.npmjs.com/trusted-publishers/) — fetched directly for the manual-publish-coexistence and disallow-tokens wording
- [Allow publishing initial version with OIDC — npm/cli issue #8544](https://github.com/npm/cli/issues/8544) — confirmed still open, confirms retroactive setup on an existing package is the supported path
- [Things you need to do for npm trusted publishing to work — philna.sh](https://philna.sh/blog/2026/01/28/trusted-publishing-npm/)
- [npm trusted publishing with OIDC is generally available — GitHub Changelog](https://github.blog/changelog/2025-07-31-npm-trusted-publishing-with-oidc-is-generally-available/)
- [Generating provenance statements — npm Docs](https://docs.npmjs.com/generating-provenance-statements/)
