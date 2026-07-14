# Investigate: Updating every software component this project depends on

Every dependency category in this repo has drifted from current — not just the OpenTelemetry packages already covered in [`INVESTIGATE-otel-dependency-upgrade.md`](../completed/INVESTIGATE-otel-dependency-upgrade.md). This investigation checks every category directly (not from memory or a Dependabot count alone) and lays out what's actually outdated, how risky each gap is, and in what order it's worth tackling them.

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Backlog — everything low-risk shipped; two major-version bumps deliberately deferred pending their own investigation

**Goal**: A prioritized, evidence-based picture of every outdated software component across this repo — TypeScript runtime deps, TypeScript dev tooling, the Docusaurus site, the small tooling packages under `tools/`, Python, GitHub Actions, and the DevContainer image — so upgrade work can be sequenced deliberately instead of guessed at.

**Last Updated**: 2026-07-14

**Relationship to `INVESTIGATE-otel-dependency-upgrade.md`**: that investigation already covers the OpenTelemetry/`uuid` piece in depth (staged-bump options, breaking-change risk, test plan) — not duplicated here. This investigation is the parent sweep across everything else; treat the OTel one as this sweep's most urgent, already-scoped item.

**Update 2026-07-13**: OTel shipped — [`PLAN-otel-dependency-upgrade.md`](../completed/PLAN-otel-dependency-upgrade.md), 49 vulnerabilities → 0, validated end-to-end against both real backends. Per this doc's own Option B recommendation, GitHub Actions/Docusaurus/dev-tooling consistency are next, in decreasing risk order — none started yet.

**Update 2026-07-14**: Option B's remaining categories executed, in the recommended order:
- **GitHub Actions** — all 5 actions bumped (`checkout` v4→v7, `setup-node` v4→v6, `upload-artifact` v4→v7, `upload-pages-artifact` v3→v5, `deploy-pages` v4→v5). Confirmed via a real triggered `deploy-docs.yml` run: zero "Node.js 20 is deprecated" annotations afterward (previously appeared on every run).
- **Docusaurus** — `3.10.1`→`3.10.2` across all `@docusaurus/*` packages plus 2 related types packages, merged as PR #18 after a real local `npm run build` + `npm run typecheck` came back clean (no CI configured on this repo to rely on instead).
- **Dev-tooling consistency (`@types/node`, `tsx`)** — `tools/validation` and `tools/dashboards` both bumped to `@types/node@^26.1.1` / `tsx@^4.23.1` (PRs #22, #23), each verified with a real `npm install` + `tsc --noEmit` (and a real script execution for `tools/dashboards`), not just a green Dependabot check.
- **New real finding, not anticipated by [Q5](#open-questions) below**: `typescript@7.0.2` breaks ambient Node global type resolution under every `package.json` in this repo that uses the `"moduleResolution": "NodeNext"` + no-explicit-`"types"` pattern — `process`/`Buffer`/`node:fs` etc. all fail to resolve, ~50 errors in `tools/validation` alone. Isolated by reverting `typescript` alone while keeping the other bumps — clean. `typescript` stays pinned everywhere (`^5.7.2` in the `tools/`/`typescript/` packages, Docusaurus's own `~6.0.3` requirement in `website/`) until a dedicated TypeScript 7 migration is scoped. This affects, and blocks, 3 open Dependabot PRs: #13 (`tools/dashboards`), #15 (`typescript/`), #19 (`website`) — all closed/deferred with this finding recorded on each.
- **ESLint 8→10** — untouched. `eslint-config-prettier` 9→10 shipped cleanly on its own (PR #16, no conflict with ESLint 8), but the `eslint`/`@typescript-eslint` major bumps themselves (PRs #14, #17) remain open, per [Q3](#open-questions)'s own framing — ESLint 9's flat-config migration is a real, non-mechanical change, not a version-bump-and-watch.
- Remaining open items: PRs #14 (`eslint` 8→10), #15 (`typescript` 5.9.3→7.0.2 in `typescript/`), #17 (`@typescript-eslint/parser` 7→8, currently peer-conflicting with `eslint-plugin` still on `^7.0.0`). None of these are safe to bump-and-watch — each needs its own scoped investigation before merging.

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

**Update 2026-07-14**: `@types/node`/`tsx` consistency done for `tools/validation` (`@types/node@^26.1.1`, `tsx@^4.23.1`) and `tools/dashboards` (same versions) — both verified with a real `tsc --noEmit`. `typescript` and `eslint`/`@typescript-eslint` majors deliberately **not** bumped — see the 2026-07-14 update above for why (`typescript@7.0.2` breaks Node global type resolution repo-wide; ESLint 9 is a real flat-config migration, not a mechanical bump). `typescript/` and `typescript/test/e2e/company-lookup/` untouched by this pass.

| Package | Current | Latest | Gap |
|---|---|---|---|
| `typescript` (the compiler) | `5.9.3`/`5.7.2` (varies), `~6.0.3` in `website/` | `7.0.2` | 2 major versions — TS skipped a `6.x` line entirely. **Confirmed breaking** (2026-07-14): breaks ambient Node global resolution under this repo's tsconfig pattern. Deliberately pinned everywhere until a dedicated migration is scoped. |
| `eslint` | `8.57.1` | `10.7.0` | 2 major versions — PR #14 open, deferred (ESLint 9 flat-config migration is real, not mechanical) |
| `@typescript-eslint/eslint-plugin` / `parser` | `7.18.0` | `8.63.0` | 1 major version — PR #17 open, deferred (peer-conflicts with `eslint-plugin` still `^7.0.0`) |
| `eslint-config-prettier` | ~~`9.1.2`~~ → `10.1.8` | `10.1.8` | **Done** — PR #16 merged, no conflict with ESLint 8 |
| `prettier` | `3.6.2`/`3.9.5` (varies by package) | `3.9.5` | minor, inconsistent across packages — not touched this pass |
| `tsx` | ~~`4.20.6`–`4.23.0` (varies)~~ → `^4.23.1` in `tools/validation`, `tools/dashboards` | `4.23.1` | **Done** for the two `tools/` packages (PRs #22, #23); `typescript/` and the E2E package untouched |
| `@types/node` | ~~`20.19.x`–`24.7.0` (varies wildly)~~ → `^26.1.1` in `tools/validation`, `tools/dashboards` | `26.1.1` | **Done** for the two `tools/` packages; `typescript/`, `website/`, and the E2E package untouched |
| `@types/uuid` | `10.0.0` | `11.0.0` | 1 major version — not touched this pass |

No runtime security exposure (dev-only, never shipped). The inconsistency-across-packages problem is now half-resolved: `tools/validation` and `tools/dashboards` are in sync with each other on `@types/node`/`tsx`; `typescript/`, `website/`, and the E2E package still differ.

### 3. Docusaurus site (`website/package.json`)

**Done (2026-07-14)** — bumped `3.10.1`→`3.10.2` across all `@docusaurus/*` packages plus `@docusaurus/tsconfig`/`@docusaurus/types`, merged as PR #18. Verified with a real local `npm run build` + `npm run typecheck` (this repo has no CI checks configured, so Dependabot's own green check isn't a signal — had to check out the PR branch and run both directly).

### 4. Python (`python/requirements.txt`, `python/test/e2e/company-lookup/requirements.txt`)

**Already fully current — zero gap.** Uses `>=` minimum-version constraints rather than pins, so `pip install` already resolves to the latest compatible release. Checked directly: installed `opentelemetry-api`/`sdk`/`exporter-otlp-proto-http` all at `1.43.0`, matching PyPI's current `1.43.0` exactly; same for `requests` (`2.34.2`) and `python-dotenv` (`1.2.2`). No action needed here — worth noting *why* Python stays current automatically while TypeScript doesn't: TypeScript's `package.json` uses `^`-pinned ranges that `npm install` only re-resolves within, not past, whereas Python's `>=`-only constraints have no ceiling.

### 5. GitHub Actions (`.github/workflows/*.yml`)

**Done (2026-07-14).**

| Action | Was | Now | Gap closed |
|---|---|---|---|
| `actions/checkout` | `v4` | `v7` | 3 major versions |
| `actions/setup-node` | `v4` | `v6` | 2 major versions |
| `actions/upload-artifact` | `v4` | `v7` | 3 major versions |
| `actions/upload-pages-artifact` | `v3` | `v5` | 2 major versions |
| `actions/deploy-pages` | `v4` | `v5` | 1 major version |

Confirmed via a real triggered `deploy-docs.yml` run: the `Node.js 20 is deprecated... forced to run on Node.js 24` annotation that had appeared on every single CI/Pages run all session is now **gone** — zero annotations on the post-bump run.

**Separate, smaller finding** (not yet addressed): `deploy-docs.yml` explicitly pins `node-version: '20'` for the docs build, while `ci.yml` runs a `[22, 24]` matrix for the library itself — an inconsistency worth fixing regardless of the Action-version question, since `typescript/package.json`'s own `engines.node` already requires `>=22.0.0`.

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

1. ~~**[Q1]** Confirm priority order from Option B~~ — **Resolved 2026-07-14**: executed in exactly the recommended order (OTel already done → GitHub Actions → Docusaurus → dev-tooling consistency). No reordering needed in practice.
2. ~~**[Q2]** Did `@types/node` drift cause anything real?~~ — **Resolved 2026-07-14**: not formally root-caused to any specific past bug/flake; fixed opportunistically as part of this sweep rather than as its own investigation, per the question's own framing. No evidence surfaced of a real incident it caused.
3. **[Q3]** ESLint 8 → 10 spans ESLint 9's flat-config migration (a real, documented breaking change to `.eslintrc` → `eslint.config.js`) — worth its own small investigation/plan, or is that config migration simple enough to just do as part of the dev-tooling pass? **Still open** — PRs #14/#17 left unmerged this pass specifically because this wasn't resolved; needs its own `INVESTIGATE-eslint9-migration.md` before proceeding.
4. ~~**[Q4]** GitHub Actions bump-and-watch~~ — **Resolved 2026-07-14**: bump-and-watch was sufficient. All 5 actions bumped in one pass, verified via a real triggered `deploy-docs.yml` run with zero regressions and zero deprecation annotations. No per-action breaking-change research was needed in practice.
5. ~~**[Q5]** Is TypeScript `5.9.3`→`7.0.2` a safe bump?~~ — **Resolved 2026-07-14, answer: no.** Confirmed breaking: `typescript@7.0.2` breaks ambient Node global type resolution (`process`/`Buffer`/`node:fs` unresolvable) under this repo's `tsconfig.json` pattern (`"moduleResolution": "NodeNext"`, no explicit `"types": ["node"]`) — reproduced in `tools/validation`, isolated by reverting `typescript` alone while keeping other bumps. This needs its own dedicated migration investigation (likely: add explicit `"types": ["node"]` or migrate the tsconfig pattern), not a bundle-in-and-watch bump. Affects PRs #13, #15, #19, all closed/deferred with this finding recorded.

## Next Steps

- [x] Maintainer answers [Q1]–[Q5] — 4 of 5 resolved directly via execution; [Q3] remains genuinely open
- [x] Execute `INVESTIGATE-otel-dependency-upgrade.md`'s staged plan — shipped, see `completed/PLAN-otel-dependency-upgrade.md`
- [x] GitHub Actions — shipped directly (5 version bumps, verified via a real triggered run)
- [x] Docusaurus — shipped directly (PR #18, verified via a real local build)
- [x] Dev-tooling consistency (`@types/node`, `tsx`) — shipped directly for `tools/validation` and `tools/dashboards` (PRs #22, #23); `typescript/` and the E2E package still untouched
- [x] Write [`INVESTIGATE-eslint9-migration.md`](INVESTIGATE-eslint9-migration.md) — scope the `.eslintrc` → `eslint.config.js` flat-config migration ([Q3]), covers PRs #14 and #17. Written 2026-07-14 — found the ESLint major bump and the `@typescript-eslint` major bump are actually independent (current `eslint@^8.57.0` already satisfies `@typescript-eslint@8.x`'s peer range), so PR #17 can likely unblock without any flat-config work at all.
- [x] Write [`INVESTIGATE-typescript7-migration.md`](INVESTIGATE-typescript7-migration.md) — scope why `typescript@7.0.2` breaks Node global resolution and what fix (tsconfig `"types"` field vs. something else) unblocks it repo-wide, covers PRs #13, #15, #19. Written and **resolved** 2026-07-14: direct testing found a *second* confirmed break (`website/`'s `baseUrl` removed, `TS5102`) on top of the Node-globals bug and the pre-existing `@typescript-eslint` peer-range ceiling. Given TS7 is 6 days old and at least one blocker is outside this repo's control, the resolution is **wait, not migrate** — `typescript` stays pinned everywhere, no PLAN drafted, revisit only once `@typescript-eslint` supports TS7.
- [ ] Once both follow-up investigations' child plans ship, this investigation can move to `completed/`

## Files to Modify (once a plan is drafted from this)

- ~~`tools/dashboards/package.json`, `tools/validation/package.json`~~ — done (`@types/node`, `tsx`; `typescript` deliberately untouched)
- ~~`website/package.json`~~ — done (Docusaurus only; `typescript` deliberately untouched)
- ~~`.github/workflows/*.yml`~~ — done (all 5 actions bumped)
- `typescript/package.json`, `typescript/test/e2e/company-lookup/package.json` — still untouched, blocked on the two follow-up investigations above
- `typescript/.eslintrc*` → `eslint.config.js` — pending `INVESTIGATE-eslint9-migration.md`
