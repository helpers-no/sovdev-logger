# Investigate: Updating every software component this project depends on

Every dependency category in this repo has drifted from current — not just the OpenTelemetry packages already covered in [`INVESTIGATE-otel-dependency-upgrade.md`](../completed/INVESTIGATE-otel-dependency-upgrade.md). This investigation checks every category directly (not from memory or a Dependabot count alone) and lays out what's actually outdated, how risky each gap is, and in what order it's worth tackling them.

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Backlog — OTel (the highest-priority item) shipped, the rest still open

**Goal**: A prioritized, evidence-based picture of every outdated software component across this repo — TypeScript runtime deps, TypeScript dev tooling, the Docusaurus site, the small tooling packages under `tools/`, Python, GitHub Actions, and the DevContainer image — so upgrade work can be sequenced deliberately instead of guessed at.

**Last Updated**: 2026-07-13

**Relationship to `INVESTIGATE-otel-dependency-upgrade.md`**: that investigation already covers the OpenTelemetry/`uuid` piece in depth (staged-bump options, breaking-change risk, test plan) — not duplicated here. This investigation is the parent sweep across everything else; treat the OTel one as this sweep's most urgent, already-scoped item.

**Update 2026-07-13**: OTel shipped — [`PLAN-otel-dependency-upgrade.md`](../completed/PLAN-otel-dependency-upgrade.md), 49 vulnerabilities → 0, validated end-to-end against both real backends. Per this doc's own Option B recommendation, GitHub Actions/Docusaurus/dev-tooling consistency are next, in decreasing risk order — none started yet.

---

## Current State (checked directly — `npm outdated`, `npm audit`, `pip list` + PyPI, `gh api` for Action releases — not assumed from any prior count)

### 1. TypeScript library runtime dependencies (`typescript/package.json`) — the real risk

| Package | Current | Latest | Gap |
|---|---|---|---|
| `@opentelemetry/sdk-node` | `0.55.0` | `0.220.0` | ~165 minor versions |
| `@opentelemetry/auto-instrumentations-node` | `0.51.0` | `0.78.0` | ~27 minor versions |
| `@opentelemetry/api-logs`, `sdk-logs`, `exporter-*-otlp-http` | `0.55.0` | `0.220.0` | same family, versioned in lockstep |
| `@opentelemetry/resources`, `sdk-metrics`, `sdk-trace-base` | `1.30.1` | `2.9.0` | 1 major version |
| `@opentelemetry/semantic-conventions` | `1.37.0` | `1.43.0` | minor |
| `@opentelemetry/api` | `1.9.0` | `1.9.1` | patch only |
| `winston` | `3.18.3` | `3.19.0` | minor |
| `uuid` (transitive only — see below) | `9.0.1` | `14.0.1` | direct-dependency gap, not just version |

**Re-confirmed today, not just cited from the older investigation**: `npm audit --omit=dev` reports **49 vulnerabilities (45 moderate, 3 high, 1 critical)** in the current dependency tree — the 1 critical is arbitrary code execution in `protobufjs`, a transitive dependency of the OTel exporter packages. Full detail, staged-bump options, and breaking-change analysis already exist in [`INVESTIGATE-otel-dependency-upgrade.md`](../completed/INVESTIGATE-otel-dependency-upgrade.md) — this is the single highest-priority item in this whole sweep.

### 2. TypeScript dev-only tooling (`typescript/package.json` devDependencies, and the same pattern repeats in `website/`, `tools/dashboards/`, `tools/validation/`, `typescript/test/e2e/company-lookup/`)

| Package | Current | Latest | Gap |
|---|---|---|---|
| `typescript` (the compiler) | `5.9.3` | `7.0.2` | 2 major versions — TS skipped a `6.x` line entirely |
| `eslint` | `8.57.1` | `10.7.0` | 2 major versions |
| `@typescript-eslint/eslint-plugin` / `parser` | `7.18.0` | `8.63.0` | 1 major version |
| `eslint-config-prettier` | `9.1.2` | `10.1.8` | 1 major version |
| `prettier` | `3.6.2`/`3.9.5` (varies by package) | `3.9.5` | minor, inconsistent across packages |
| `tsx` | `4.20.6`–`4.23.0` (varies) | `4.23.1` | patch, inconsistent across packages |
| `@types/node` | `20.19.x`–`24.7.0` (varies wildly across packages) | `26.1.1` | up to 2 major versions, wildly inconsistent |
| `@types/uuid` | `10.0.0` | `11.0.0` | 1 major version |

No runtime security exposure (dev-only, never shipped), but the **inconsistency across packages** (`@types/node` ranges from `20.x` to `24.x` depending on which of the 5 `package.json` files you look at) is its own real problem — nothing enforces they stay in sync, so behavior can subtly differ between `typescript/`, `website/`, `tools/dashboards/`, `tools/validation/`, and the E2E test package.

### 3. Docusaurus site (`website/package.json`)

All `@docusaurus/*` packages at `3.10.1`, latest is `3.10.2` — a single patch release behind, seen in this session's own build output every single time (`Update available 3.10.1 → 3.10.2`). Lowest-risk, easiest win in this entire sweep.

### 4. Python (`python/requirements.txt`, `python/test/e2e/company-lookup/requirements.txt`)

**Already fully current — zero gap.** Uses `>=` minimum-version constraints rather than pins, so `pip install` already resolves to the latest compatible release. Checked directly: installed `opentelemetry-api`/`sdk`/`exporter-otlp-proto-http` all at `1.43.0`, matching PyPI's current `1.43.0` exactly; same for `requests` (`2.34.2`) and `python-dotenv` (`1.2.2`). No action needed here — worth noting *why* Python stays current automatically while TypeScript doesn't: TypeScript's `package.json` uses `^`-pinned ranges that `npm install` only re-resolves within, not past, whereas Python's `>=`-only constraints have no ceiling.

### 5. GitHub Actions (`.github/workflows/*.yml`)

| Action | Current | Latest | Gap |
|---|---|---|---|
| `actions/checkout` | `v4` | `v7.0.0` | 3 major versions |
| `actions/setup-node` | `v4` | `v6.4.0` | 2 major versions |
| `actions/upload-artifact` | `v4` | `v7.0.1` | 3 major versions |
| `actions/upload-pages-artifact` | `v3` | `v5.0.0` | 2 major versions |
| `actions/deploy-pages` | `v4` | `v5.0.0` | 1 major version |

This directly explains the `Node.js 20 is deprecated... forced to run on Node.js 24` annotation that has appeared on **every single CI/Pages run this entire session** — the pinned major versions' underlying JS runtime targets Node 20, which GitHub's runners now silently override. Not broken today, but not a warning that goes away on its own either.

**Separate, smaller finding**: `deploy-docs.yml` explicitly pins `node-version: '20'` for the docs build, while `ci.yml` runs a `[22, 24]` matrix for the library itself — an inconsistency worth fixing regardless of the Action-version question, since `typescript/package.json`'s own `engines.node` already requires `>=22.0.0`.

### 6. DevContainer image (`.devcontainer/devcontainer.json`)

Already on `ghcr.io/helpers-no/devcontainer-toolbox:latest` — a rolling tag, plus the file itself is explicitly marked `"managed": "This file is managed by dev-update. Do not edit — changes will be overwritten."` So this one isn't a dependency to schedule an upgrade for; it's externally managed and already tracks latest by design. No action item here, listed for completeness of the sweep.

---

## Options

### Option A: One big sweep, everything at once

Bump every category above in a single pass: OTel (per the existing investigation's chosen strategy), all dev tooling, Docusaurus, GitHub Actions.

**Pros**: done once, no lingering "which category haven't we gotten to yet" tracking.
**Cons**: conflates a critical-severity runtime security fix (OTel/protobufjs) with a dozen low-risk dev-tooling bumps in one review — if anything breaks, much harder to isolate which of ~15 package upgrades caused it. Also directly contradicts `INVESTIGATE-otel-dependency-upgrade.md`'s own conclusion that OTel needs a *careful, staged, isolated* bump given the `0.x` breaking-change risk.

### Option B: Priority-ordered, separate passes

1. **OTel + `uuid`** (critical severity, real security exposure) — execute `INVESTIGATE-otel-dependency-upgrade.md`'s own staged plan first, on its own.
2. **GitHub Actions major-version bumps** — low functional risk (these are CI-only, easy to revert, and the whole repo's CI is exercised on every push regardless), but worth doing to retire the recurring Node-20 deprecation warning and stop drifting further behind.
3. **Docusaurus patch bump** — trivial, single patch version, do any time.
4. **Dev tooling consistency pass** — pin `@types/node`, `tsx`, `prettier` etc. to the *same* version across all 5 `package.json` files (not necessarily latest, just consistent), then bump the shared version. `typescript`/`eslint`'s major-version jumps deserve their own look at breaking changes (ESLint 9's flat-config migration in particular is a known, real breaking change, not just a version bump) before committing to latest.
5. **Python** — nothing to do.

**Pros**: risk-isolated, each pass independently revertible, matches the severity ordering (critical security fix first, cosmetic/consistency last).
**Cons**: more individual PRs/reviews than Option A — but each one is small and easy to reason about.

### Option C: Security-relevant only, defer the rest

Do only #1 (OTel) from Option B's list; leave GitHub Actions, dev tooling, and Docusaurus as-is indefinitely.

**Pros**: least total effort, addresses the only category with actual runtime/security exposure.
**Cons**: the Node-20 deprecation warning keeps appearing on every CI run forever (GitHub Actions will eventually stop supporting it, not a hypothetical); dev-tooling drift keeps growing, making a future catch-up pass larger and riskier than doing it now in smaller increments.

---

## Recommendation

**Option B.** The OTel/security piece is genuinely different in kind (breaking-change risk, security exposure) from everything else in this list (mechanical version bumps with no runtime impact) — bundling them works against the careful staging `INVESTIGATE-otel-dependency-upgrade.md` already calls for. Do OTel first and alone, then work down the rest in decreasing order of effort-to-value.

---

## Open Questions

1. **[Q1]** Confirm priority order from Option B — OTel first, then GitHub Actions, then Docusaurus, then dev-tooling consistency? Or reorder (e.g. Docusaurus/Actions are near-zero-risk, could go first as quick wins while OTel's staged bump is still being planned)?
2. **[Q2]** For the dev-tooling consistency pass: is drifting `@types/node` versions across the 5 `package.json` files actually caused anything real (a bug, a CI flake), or is this purely a hygiene concern worth fixing opportunistically rather than as its own scheduled work?
3. **[Q3]** ESLint 8 → 10 spans ESLint 9's flat-config migration (a real, documented breaking change to `.eslintrc` → `eslint.config.js`) — worth its own small investigation/plan, or is that config migration simple enough to just do as part of the dev-tooling pass?
4. **[Q4]** GitHub Actions major-version bumps (`checkout` v4→v7, etc.) — any known breaking changes worth checking per-action before bumping, or is a bump-and-watch-CI approach acceptable here since CI itself is the test?
5. **[Q5]** TypeScript compiler `5.9.3` → `7.0.2` (skipping a `6.x` line) — does anything in `src/` or the build config rely on TS 5-specific behavior, or is this a safe bump to bundle into the dev-tooling pass?

## Next Steps

- [ ] Maintainer answers [Q1]–[Q5]
- [ ] Execute `INVESTIGATE-otel-dependency-upgrade.md`'s staged plan first (already fully scoped, just needs a `PLAN-*.md` drafted from it)
- [ ] Create follow-up `PLAN-*.md`(s) for whichever of GitHub Actions / Docusaurus / dev-tooling consistency the maintainer wants to prioritize next

## Files to Modify (once a plan is drafted from this)

- `typescript/package.json`, `website/package.json`, `tools/dashboards/package.json`, `tools/validation/package.json`, `typescript/test/e2e/company-lookup/package.json`
- `.github/workflows/ci.yml`, `.github/workflows/deploy-docs.yml`
- Possibly `typescript/.eslintrc*` → `eslint.config.js` if the ESLint 9 flat-config migration is bundled in
