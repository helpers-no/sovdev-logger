# Plan: Fix peerDependency, LICENSE, and add dependabot.yml

Closes the two real bugs from [`INVESTIGATE-library-best-practices.md`](INVESTIGATE-library-best-practices.md) — `@opentelemetry/api` should be a `peerDependency`, and the published tarball has never included a LICENSE file — plus adds automated dependency-update PRs (`dependabot.yml`) to prevent a repeat of the OTel drift that reached 49 vulnerabilities before anyone noticed.

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Completed

**Goal**: `@opentelemetry/api` declared as a `peerDependency` (`^1.9.1`), a real LICENSE file in the published tarball, and `.github/dependabot.yml` opening automated version-update PRs going forward.

**Last Updated**: 2026-07-13

**Investigation**: [INVESTIGATE-library-best-practices.md](INVESTIGATE-library-best-practices.md) — [Q1]–[Q4] all resolved. [Q2] confirmed no live diamond-dependency risk exists today (`ollacrm` doesn't depend on `sovdev-logger` yet at all); [Q3] confirmed empirically that npm's `files` field can't reference a path outside the package directory, so the LICENSE fix must copy the file, not reference it.

---

## Phase 1: peerDependency + LICENSE fixes — DONE

### Tasks

- [x] 1.1 Moved `@opentelemetry/api` from `dependencies` to `peerDependencies` in `typescript/package.json`, pinned to `^1.9.1`.
- [x] 1.2 No `peerDependenciesMeta` entry needed — confirmed npm 7+ auto-installs peer dependencies by default (verified: `npm install` pulled it in with zero warnings). **Also added `@opentelemetry/api@^1.9.1` to `devDependencies`** (beyond the original task list) — a common pattern in the OTel ecosystem itself, so this repo's own build/test always has a concrete resolved version regardless of npm's peer-auto-install default, rather than depending on that default holding across future npm/package-manager versions.
- [x] 1.3 Copied the root `/LICENSE` into `typescript/LICENSE`. Confirmed not gitignored (`git check-ignore` exit 1).
- [x] 1.4 Verified via `npm pack --dry-run --json` inside the DevContainer: tarball file count went from 54 → 55, `LICENSE` present in the file list — the exact same verification method that caught the original bug.
- [x] 1.5 Clean `node_modules`/`package-lock.json` reinstall inside the DevContainer — zero peer-dependency warnings. `tsc --noEmit`, `lint`, `build` all clean.

### Validation

Real `npm pack --dry-run --json` output confirmed `LICENSE` present (55 files, up from 54). `tsc`/`lint`/`build` all clean after the `peerDependencies` change. Ran the full E2E test against real UIS — schema-valid (17+2 entries), then queried Loki directly and confirmed 17 streams landed — the dependency reshuffling caused no runtime regression.

---

## Phase 2: Automated dependency updates

### Tasks

- [x] 2.1 Created `.github/dependabot.yml` covering all 5 npm-ecosystem directories (`typescript/`, `website/`, `tools/dashboards/`, `tools/validation/`, `typescript/test/e2e/company-lookup/`), per `INVESTIGATE-dependency-upgrade-sweep.md`'s finding that all 5 `package.json` files drift independently. **Also added a `github-actions` ecosystem entry** (beyond the original task list) — the same sweep investigation found GitHub Actions 1-3 major versions behind too; same purpose, same file, low-risk to include now rather than as yet another follow-up.
- [x] 2.2 Grouping: minor/patch updates grouped per directory to cut PR noise (OTel packages get their own group within `typescript/`, kept separate from other minor/patch bumps). Major version bumps are never grouped — Dependabot only groups within the `update-types` a group explicitly lists, and majors were deliberately left out of every group here, so they always land as individual PRs. Nothing auto-merges — Dependabot alone never does; that would need a separate, not-set-up auto-merge workflow.
- [x] 2.3 Validated YAML syntax locally (`python3 -c "import yaml; ..."`) before pushing. Real activation confirmation (a live Dependabot dashboard entry, not just syntax validity) needs the file on `main` — pending Phase 3's push/merge.

### Validation

YAML syntax confirmed valid locally. **Genuinely active, not just committed**: within minutes of merging to `main`, Dependabot opened real PRs — `github-actions` bumps (`actions/upload-artifact` 4→7) and `npm` bumps across multiple directories. Confirms the design working exactly as intended: an `eslint-config-prettier` minor/patch-range bump passed CI cleanly, while three major-version bumps (`typescript` 5.9.3→7.0.2, `eslint` 8.57.1→10.7.0, `@typescript-eslint/parser` 7→8.64.0) correctly failed CI on real peer-dependency conflicts (e.g. `parser@8.64.0` vs. `eslint-plugin@7.18.0`'s `peer @typescript-eslint/parser@^7.0.0` requirement) — exactly the "majors need individual review, never auto-merge" behavior this config was designed for, not a config bug.

---

## Acceptance Criteria

- [x] `@opentelemetry/api` is a `peerDependency`, not a regular dependency.
- [x] The published tarball (verified via `npm pack --dry-run`) includes a real `LICENSE` file.
- [x] `.github/dependabot.yml` exists — active-in-GitHub confirmation pending push to `main`.
- [x] No regression — full E2E test against real UIS passes after the `package.json` changes.

## Files to Modify

- `typescript/package.json`
- `typescript/LICENSE` (new file, copied from repo root)
- `.github/dependabot.yml` (new file)
