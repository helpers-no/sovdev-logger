# Investigate: npm Trusted Publishing (OIDC) for sovdev-logger

Spun off from [`INVESTIGATE-library-best-practices.md`](../completed/INVESTIGATE-library-best-practices.md)'s [Q5]: whether to move `sovdev-logger`'s publish process from a manual, personal-OTP-gated DevContainer step to npm's Trusted Publishing (OIDC via GitHub Actions) — removing the dependency on the maintainer's personal npm account/token at publish time, and adding cryptographic build provenance. Directly follows on from `INVESTIGATE-repo-and-package-ownership.md`'s findings about the package's personal-account history.

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Backlog

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

**Not yet confirmed, needs hands-on verification before committing to this**:
- Whether Trusted Publishing works retroactively on a package that's already been published manually (like `sovdev-logger`), or only packages published for the first time via Trusted Publishing. Neither source found during research states this explicitly either way.
- Whether configuring Trusted Publishing removes the ability to *also* publish manually with a personal account/OTP as a fallback, or the two coexist.

---

## Current state (this repo)

- Publishing today is entirely manual: `contributor/publishing/typescript.md` documents running `npm login` + `npm publish --access public` from a real interactive terminal (this session confirmed it works from the host Mac directly, correcting that doc's earlier claim it required the DevContainer) — always needs a live OTP from the maintainer's authenticator app, every single publish.
- `typescript/package.json`'s `repository.url` already points at `helpers-no/sovdev-logger` — no metadata blocker.
- No release/publish GitHub Actions workflow exists today — `ci.yml` and `deploy-docs.yml` are the only two workflows, neither touches npm.
- `sovdev-logger` was published for the first time under its current (unscoped) name on 2026-07-13, manually. Whether Trusted Publishing can attach to that existing package or needs to have been the *original* publish method is the single biggest unresolved question before committing effort here (see above).

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

Not yet — this needs [Q1]–[Q3] answered first, particularly whether Trusted Publishing can attach to an already-published package, before recommending Option A outright. Leaning toward Option A once that's confirmed, given it directly closes a concern this session's own npm-rename work already flagged as only partially resolved.

---

## Open Questions

1. **[Q1]** Does Trusted Publishing work for a package (`sovdev-logger`) that was already published manually, or does npm require the *first-ever* publish of a package name to go through Trusted Publishing? Needs a direct test or a direct read of npm's support docs/forum, not inference from the two sources checked so far.
2. **[Q2]** Does configuring a Trusted Publisher on `sovdev-logger` remove the maintainer's ability to also `npm publish` manually as a fallback (e.g. if GitHub Actions is down), or can both coexist?
3. **[Q3]** What should trigger the publish workflow — a GitHub Release being created, a version tag push (`v*`), or `workflow_dispatch` (manual button, closest to today's process but still removing the OTP step)? Each implies a different amount of process change beyond just the auth mechanism.
4. **[Q4]** Does the current npm CLI version in the DevContainer/CI actually satisfy the `>=11.5.1` requirement, or does the workflow need an explicit upgrade step?
5. **[Q5]** Should this also cover a `CHANGELOG.md`/version-bump automation step (e.g. `changesets` or `semantic-release`), given a real publish workflow is being built anyway — or keep this scoped strictly to the auth mechanism and leave versioning as-is (manual `package.json` bumps, as today)?

## Next Steps

- [ ] Answer [Q1]/[Q2] directly — check npm's own support documentation/forum for explicit confirmation, since neither source checked during this investigation states it either way
- [ ] Maintainer answers [Q3]–[Q5]
- [ ] Create `PLAN-npm-trusted-publishing.md` once the above are resolved

## Sources checked

- [Trusted publishing for npm packages — npm Docs](https://docs.npmjs.com/trusted-publishers/)
- [Things you need to do for npm trusted publishing to work — philna.sh](https://philna.sh/blog/2026/01/28/trusted-publishing-npm/)
- [npm trusted publishing with OIDC is generally available — GitHub Changelog](https://github.blog/changelog/2025-07-31-npm-trusted-publishing-with-oidc-is-generally-available/)
- [Generating provenance statements — npm Docs](https://docs.npmjs.com/generating-provenance-statements/)
