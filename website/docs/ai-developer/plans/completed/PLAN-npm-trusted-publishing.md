# Plan: npm Trusted Publishing (OIDC) via GitHub Actions

Moves `sovdev-logger`'s npm publish step from manual (`npm login` + personal OTP, every release) to npm's Trusted Publishing — a GitHub Actions workflow authenticates via short-lived OIDC tokens instead of a stored npm token or a human's 2FA. Manual publishing keeps working as a fallback; this doesn't remove it.

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Completed

**Goal**: A `workflow_dispatch`-triggered GitHub Actions workflow that publishes `sovdev-logger` to npm via Trusted Publishing, with the npmjs.com Trusted Publisher configuration set up to match it exactly.

**Last Updated**: 2026-07-13

**Investigation**: [INVESTIGATE-npm-trusted-publishing.md](INVESTIGATE-npm-trusted-publishing.md) — all 5 questions resolved. Trigger: `workflow_dispatch` ([Q3]). Scope: auth mechanism only, no changelog/version-bump automation bundled in ([Q5]).

**Real constraint found during research, not assumed**: the npm CLI version required (`>=11.5.1`) isn't satisfied anywhere in this repo's current environments (host `10.2.4`, DevContainer `10.9.7`, CI's `actions/setup-node@v4`+Node 22 default is npm 10.x) — the workflow must explicitly upgrade npm as its own step.

**A step I cannot do myself**: configuring the actual Trusted Publisher on `npmjs.com/package/sovdev-logger/access` requires the maintainer's own logged-in session on npmjs.com's web UI — no CLI or API path exists for this per every source checked during the investigation. This plan creates and validates everything up to that point; the maintainer does the npmjs.com-side configuration and the first live trigger.

---

## Phase 1: Create the publish workflow — DONE

### Tasks

- [x] 1.1 Created `.github/workflows/publish.yml`: `workflow_dispatch` trigger, `permissions: { contents: read, id-token: write }`, `actions/checkout@v7`, `actions/setup-node@v6` with `registry-url: 'https://registry.npmjs.org'` and `node-version: 22`.
- [x] 1.2 Explicit `npm install -g npm@latest` step before anything else.
- [x] 1.3 `npm ci`, `npm run build`, `npm run lint` inside `typescript/` (`working-directory` default).
- [x] 1.4 `npm publish --access public --provenance`.
- [x] 1.5 No E2E test step — confirmed unnecessary, per plan.

### Validation

**A real dispatched run, not just syntax checking.** Confirmed GitHub requires a `workflow_dispatch` workflow to exist on the default branch before it's dispatchable at all — tried dispatching from the feature branch first, got a clean `404 workflow not found on the default branch`, confirming this constraint directly rather than assuming it. Merged to `main`, then dispatched a real run: **every step through `Verify package.json metadata` passed** (checkout, npm upgrade, install, build, lint) — the log itself doesn't print the resulting npm version, but the subsequent successful OIDC token exchange and provenance signing (below) wouldn't have worked at all on the pre-upgrade npm `10.x`, confirming the upgrade step did what it needed to. The final `Publish to npm` step failed exactly as expected — `404 Not Found ... could not be found or you do not have permission to access it` — because no Trusted Publisher is configured yet on npmjs.com (Phase 2, not done).

**Unexpected, useful finding**: provenance attestation actually worked *before* any Trusted Publisher was configured — the run's log shows `npm notice publish Signed provenance statement with source and build information from GitHub Actions` and a real Sigstore transparency-log entry (`https://search.sigstore.dev/?logIndex=2165055851`), even though the subsequent publish itself failed on authorization. Provenance signing (GitHub's generic OIDC/Sigstore mechanism) and npm's Trusted Publisher access grant (who's authorized to publish this specific package) are evidently independent — the former doesn't require the latter to be configured. Worth confirming this holds once Phase 2 makes the actual publish succeed, but it de-risks acceptance criterion "provenance attestation confirmed visible" considerably.

---

## Phase 2: npmjs.com configuration and first live run (maintainer-only)

### Tasks — DONE

- [x] 2.1 **(Maintainer)** Added the Trusted Publisher on `npmjs.com/package/sovdev-logger/access`: GitHub org `helpers-no`, repo `sovdev-logger`, workflow filename `publish.yml`, no environment name, `npm publish` selected as the allowed action.
- [x] 2.2 Triggered the workflow (`gh workflow run publish.yml`) — published `1.0.1` for real (it existed in `package.json` since the OTel-upgrade work but had never actually been published; this was its genuine first publish, not a re-publish).
- [x] 2.3 Full run succeeded end-to-end — OIDC token exchange, npm upgrade, build, lint, and the actual `npm publish` all green. Verified independently against the real registry: `npm view sovdev-logger version` → `1.0.1`, `npm view sovdev-logger dist.tarball` → a real, resolvable tarball URL.
- [x] 2.4 Provenance confirmed via the registry's own API, not just the workflow log: `npm view sovdev-logger@1.0.1 --json`'s `dist.attestations` shows a real SLSA provenance attestation (`predicateType: https://slsa.dev/provenance/v1`) with its own attestations URL. Also a real, distinct Sigstore transparency-log entry (`logIndex=2165078709`) — different from the earlier failed-publish attempt's entry, confirming this one is genuinely tied to the successful publish, not a stale artifact.
- [x] 2.5 Manual-publish fallback confirmed via direct, package-specific evidence rather than a redundant real test: the npmjs.com settings page itself states *"All publishing access options above are compatible with OIDC trusted publishers... they will continue to work regardless of which option you select"* — for this exact package, not generic docs. No "disallow tokens" restriction was enabled on `sovdev-logger`'s settings. Not verified via an actual duplicate manual publish, since that would need another version bump and OTP for no additional confidence beyond this direct confirmation.

### Validation

`1.0.1` published via the new workflow, confirmed on the real npm registry (version, tarball URL, and a real SLSA provenance attestation with a distinct Sigstore log entry) — not just the workflow's own "success" log line.

---

## Acceptance Criteria

- [x] `.github/workflows/publish.yml` exists, `workflow_dispatch`-triggered, upgrades npm explicitly, builds/lints before publishing.
- [x] npmjs.com Trusted Publisher configured to match the workflow exactly.
- [x] A real publish via the workflow succeeds, verified against the live registry (not just the workflow's own "success" log line).
- [x] Provenance attestation confirmed visible on the published version.
- [x] Manual `npm publish` fallback confirmed still functional afterward (via direct, package-specific settings-page evidence, not a redundant real test).

## Files to Modify

- `.github/workflows/publish.yml` (new file) — done
- `website/docs/contributor/publishing/typescript.md` — done, restructured into "Publish (recommended: GitHub Actions)" as the primary path and "Publish manually (fallback)" for the old OTP-gated process
