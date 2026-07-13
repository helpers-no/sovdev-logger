# Plan: Fix peerDependency, LICENSE, and add dependabot.yml

Closes the two real bugs from [`INVESTIGATE-library-best-practices.md`](INVESTIGATE-library-best-practices.md) — `@opentelemetry/api` should be a `peerDependency`, and the published tarball has never included a LICENSE file — plus adds automated dependency-update PRs (`dependabot.yml`) to prevent a repeat of the OTel drift that reached 49 vulnerabilities before anyone noticed.

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Backlog

**Goal**: `@opentelemetry/api` declared as a `peerDependency` (`^1.9.1`), a real LICENSE file in the published tarball, and `.github/dependabot.yml` opening automated version-update PRs going forward.

**Last Updated**: 2026-07-13

**Investigation**: [INVESTIGATE-library-best-practices.md](INVESTIGATE-library-best-practices.md) — [Q1]–[Q4] all resolved. [Q2] confirmed no live diamond-dependency risk exists today (`ollacrm` doesn't depend on `sovdev-logger` yet at all); [Q3] confirmed empirically that npm's `files` field can't reference a path outside the package directory, so the LICENSE fix must copy the file, not reference it.

---

## Phase 1: peerDependency + LICENSE fixes

### Tasks

- [ ] 1.1 Move `@opentelemetry/api` from `dependencies` to `peerDependencies` in `typescript/package.json`, pinned to `^1.9.1` (the exact version already installed and tested against, per [Q1]'s decision — not a wider conventional peer range).
- [ ] 1.2 Add a `peerDependenciesMeta` entry if needed to confirm it's not accidentally marked optional (check npm's default behavior first — peer deps are non-optional by default, this may not need an explicit entry at all).
- [ ] 1.3 Copy the root `/LICENSE` into `typescript/LICENSE`.
- [ ] 1.4 Verify via `npm pack --dry-run --json` that the resulting tarball's file list actually includes `LICENSE` this time — the same verification method that caught the bug in the first place.
- [ ] 1.5 `npm install` to confirm the peerDependency change doesn't break the existing install (peer deps still get auto-installed by npm 7+ unless explicitly opted out) — run `tsc`/`lint`/`build` after.

### Validation

Real `npm pack --dry-run --json` output showing `LICENSE` in the file list. `tsc`/`lint`/`build` clean after the `peerDependencies` change. Full E2E test against at least one real backend to confirm the dependency reshuffling didn't break anything at runtime (not just at install time).

---

## Phase 2: Automated dependency updates

### Tasks

- [ ] 2.1 Create `.github/dependabot.yml` covering the `typescript/`, `website/`, `tools/dashboards/`, `tools/validation/`, and `typescript/test/e2e/company-lookup/` npm ecosystems (matching `INVESTIGATE-dependency-upgrade-sweep.md`'s finding that all 5 `package.json` files drift independently today).
- [ ] 2.2 Decide update grouping/schedule — group minor/patch updates to reduce PR noise, but keep major version bumps (especially OTel's `0.x` packages, which can break on a minor per semver) as individual PRs requiring manual review, not auto-mergeable.
- [ ] 2.3 Confirm Dependabot actually opens a test PR after merging (or trigger a manual check) — verifying the config is syntactically valid and actually active, not just "looks right."

### Validation

A real Dependabot PR (or confirmed dashboard entry under the repo's Insights → Dependency graph → Dependabot) shows the config is live, not just committed.

---

## Acceptance Criteria

- [ ] `@opentelemetry/api` is a `peerDependency`, not a regular dependency.
- [ ] The published tarball (verified via `npm pack --dry-run`) includes a real `LICENSE` file.
- [ ] `.github/dependabot.yml` exists and is confirmed active.
- [ ] No regression — full E2E test against at least real UIS passes after the `package.json` changes.

## Files to Modify

- `typescript/package.json`
- `typescript/LICENSE` (new file, copied from repo root)
- `.github/dependabot.yml` (new file)
