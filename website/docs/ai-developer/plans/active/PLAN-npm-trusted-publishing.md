# Plan: npm Trusted Publishing (OIDC) via GitHub Actions

Moves `sovdev-logger`'s npm publish step from manual (`npm login` + personal OTP, every release) to npm's Trusted Publishing — a GitHub Actions workflow authenticates via short-lived OIDC tokens instead of a stored npm token or a human's 2FA. Manual publishing keeps working as a fallback; this doesn't remove it.

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Active

**Goal**: A `workflow_dispatch`-triggered GitHub Actions workflow that publishes `sovdev-logger` to npm via Trusted Publishing, with the npmjs.com Trusted Publisher configuration set up to match it exactly.

**Last Updated**: 2026-07-13

**Investigation**: [INVESTIGATE-npm-trusted-publishing.md](../backlog/INVESTIGATE-npm-trusted-publishing.md) — all 5 questions resolved. Trigger: `workflow_dispatch` ([Q3]). Scope: auth mechanism only, no changelog/version-bump automation bundled in ([Q5]).

**Real constraint found during research, not assumed**: the npm CLI version required (`>=11.5.1`) isn't satisfied anywhere in this repo's current environments (host `10.2.4`, DevContainer `10.9.7`, CI's `actions/setup-node@v4`+Node 22 default is npm 10.x) — the workflow must explicitly upgrade npm as its own step.

**A step I cannot do myself**: configuring the actual Trusted Publisher on `npmjs.com/package/sovdev-logger/access` requires the maintainer's own logged-in session on npmjs.com's web UI — no CLI or API path exists for this per every source checked during the investigation. This plan creates and validates everything up to that point; the maintainer does the npmjs.com-side configuration and the first live trigger.

---

## Phase 1: Create the publish workflow

### Tasks

- [ ] 1.1 Create `.github/workflows/publish.yml`: `workflow_dispatch` trigger, `permissions: { contents: read, id-token: write }`, `actions/checkout@v7`, `actions/setup-node@v6` with `registry-url: 'https://registry.npmjs.org'` and `node-version: 22` — using current-latest Action versions for this new file rather than matching `ci.yml`/`deploy-docs.yml`'s already-known-outdated pins (tracked separately in `INVESTIGATE-dependency-upgrade-sweep.md`, not this plan's problem to fix).
- [ ] 1.2 Explicit `npm install -g npm@latest` step before anything else — the version requirement this repo's environments don't currently satisfy anywhere.
- [ ] 1.3 `npm ci`, `npm run build`, `npm run lint` inside `typescript/` (`working-directory` default) — the same gate `ci.yml` already runs on every PR, repeated here since this workflow runs independently of `ci.yml`.
- [ ] 1.4 `npm publish --access public` — `--access public` is a no-op for the already-unscoped `sovdev-logger` (confirmed during the OTel-upgrade work) but kept for clarity. Explicitly add `--provenance` too, rather than relying on npm's docs claim that it's automatic — one real-world report found it wasn't automatic in practice; safe to pass explicitly either way.
- [ ] 1.5 No E2E test step against a real backend inside this workflow — that requires live credentials this workflow shouldn't need, and `ci.yml` already gates every merge to `main` before a publish would ever be triggered from it.

### Validation

Workflow file is syntactically valid (checked via `gh workflow view` or a dry run once pushed); `npm ci`/`build`/`lint` steps match exactly what `ci.yml` already runs successfully today.

---

## Phase 2: npmjs.com configuration and first live run (maintainer-only)

### Tasks

- [ ] 2.1 **(Maintainer)** On `npmjs.com/package/sovdev-logger/access`, add a Trusted Publisher: GitHub org `helpers-no`, repo `sovdev-logger`, workflow filename `publish.yml` (exact, case-sensitive), no environment name. Select `npm publish` as an allowed action (required as of npm's May 2026 policy change).
- [ ] 2.2 **(Maintainer)** Trigger the workflow manually (`workflow_dispatch`, e.g. via `gh workflow run publish.yml` or the Actions tab) against the current `1.0.1` — or hold for the next real version bump, maintainer's call, since publishing `1.0.1` again isn't possible (already live).
- [ ] 2.3 Confirm the run succeeds end-to-end: OIDC token exchange, npm CLI upgrade step, build, and the actual `npm publish` — verified against the real registry afterward (`npm view sovdev-logger` showing the new version, matching this session's established "verify against the real registry, don't just trust the CLI's own success output" standard).
- [ ] 2.4 Confirm provenance actually shows up on the published version's npmjs.com page (a "Provenance" badge/section) — the one item research flagged as not fully confirmed to be automatic.
- [ ] 2.5 Confirm manual `npm publish` (with personal OTP) still works afterward, proving the fallback really is preserved, not just documented as preserved.

### Validation

A real version of `sovdev-logger` published via the new workflow, confirmed on the real npm registry with a provenance attestation visible, and a real manual publish afterward proving the fallback path wasn't silently closed off.

---

## Acceptance Criteria

- [ ] `.github/workflows/publish.yml` exists, `workflow_dispatch`-triggered, upgrades npm explicitly, builds/lints before publishing.
- [ ] npmjs.com Trusted Publisher configured to match the workflow exactly.
- [ ] A real publish via the workflow succeeds, verified against the live registry (not just the workflow's own "success" log line).
- [ ] Provenance attestation confirmed visible on the published version.
- [ ] Manual `npm publish` fallback confirmed still functional afterward.

## Files to Modify

- `.github/workflows/publish.yml` (new file)
- `website/docs/contributor/publishing/typescript.md` (update once the new process is validated — the OTP-every-time instructions become the fallback path, not the primary one)
