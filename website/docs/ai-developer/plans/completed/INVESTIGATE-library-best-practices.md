# Investigate: npm library best practices sovdev-logger isn't following

Prompted by a direct question after the OTel dependency upgrade shipped: "as this is a library, what best practices am I not following that I should?" Checked concretely against the actual `package.json`, the actual published tarball, and OpenTelemetry's own library-author guidance — not a generic best-practices checklist. Two of the findings are real bugs already shipped in `1.0.0`/`1.0.1`, not just style preferences.

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Backlog — all decisions made, implementation not started

**Goal**: Decide which of these gaps to close and in what order — two are real bugs in the already-published package, the rest are genuine improvements but not urgent.

**Last Updated**: 2026-07-13

---

## Findings (checked directly, not assumed)

### 1. `@opentelemetry/api` is a regular `dependency`, should be a `peerDependency` — highest priority, OTel-specific

Confirmed in `typescript/package.json`: `"@opentelemetry/api": "^1.9.1"` sits under `"dependencies"`, alongside the SDK/exporter packages.

**Why this matters specifically for an OTel-wrapping library**: OpenTelemetry's own guidance for library authors is that `@opentelemetry/api` should be a peer dependency with a wide range (not the implementation packages — those are fine as regular deps). If a consuming app *also* uses OpenTelemetry directly — plausible for any app instrumenting itself beyond what sovdev-logger covers — npm can end up installing two separate copies of `@opentelemetry/api`. The API package's global registration (tracer/logger/meter providers, context propagation) is instance-specific: two copies means sovdev-logger's spans and the app's own spans may not share the same context, silently breaking trace correlation with no error, warning, or type mismatch — it would just look like a `sovdev_log()` call's span sometimes doesn't have the app's parent trace attached.

Not yet checked: whether `ollacrm` (the one known real consumer) uses `@opentelemetry/api` directly today — if not, this bug has no observed impact yet, same shape as the OTel Dependabot alerts' "no exploitable path in *our* deployment, but that's deployment-specific luck" framing.

### 2. The published tarball has zero LICENSE files — a real bug, not a style gap

`typescript/package.json`'s `"files"` array lists `"LICENSE"`, and `"license": "MIT"` is declared. But the actual `LICENSE` file lives at the repo root (`/LICENSE`), not inside `typescript/`. `npm publish` doesn't error on a missing listed file — it silently omits it.

Confirmed by downloading the real published tarball (`npm pack sovdev-logger`) and listing its contents: 54 files, none named `LICENSE`. Every install of `sovdev-logger` to date (`1.0.0` unscoped, and every `@terchris/sovdev-logger` version before it) has claimed MIT licensing in its metadata while shipping no actual license text.

### 3. No automated dependency-update mechanism (no `.github/dependabot.yml`)

This is the actual root cause of how the OTel gap reached 49 vulnerabilities (1 critical) before anyone noticed — there's no automated PR/alert cadence pushing updates, only ad-hoc manual checks. GitHub's native Dependabot *security* alerts don't require a config file, but automated *version-update* PRs (the kind that would have caught `sdk-node` drifting ~165 minor versions incrementally, a few at a time, instead of all at once) do.

### 4. No `sideEffects: false`

Not declared in `package.json`. Given the issue's own bundle-size comment (~7.5 MB before the OTel upgrade, ~4.7 MB after), this is a cheap additional lever — it tells bundlers (esbuild, webpack, Rollup) which exports are safe to tree-shake away when a consumer only imports a subset of `sovdev-logger`'s exports.

### 5. No `npm publish --provenance`, no Trusted Publishing

Directly relevant given the `INVESTIGATE-repo-and-package-ownership.md` conversation about the package's personal-account history: provenance cryptographically attests a published version was built from a specific, inspectable GitHub Actions run — not just "trust whoever ran `npm publish` from their laptop with a personal OTP." npm's Trusted Publishing (OIDC-based, no long-lived npm token stored anywhere) would also remove the current manual-OTP-every-publish friction documented in `contributor/publishing/typescript.md` — but it requires publishing to move from a local/DevContainer manual step to a GitHub Actions workflow, which is a real process change, not a one-line fix.

### 6. No `exports` field

`package.json` relies on bare `"main"`/`"types"` fields rather than an explicit `exports` map. Lower priority than the above — matters mainly if there's ever a reason to restrict deep imports (`sovdev-logger/internal/...`) or ship a dual ESM/CJS build. Confirmed the current build is CommonJS-only (`tsconfig.json`'s `"module": "commonjs"`, `dist/index.js` starts with `"use strict"`) — not broken, esbuild already bundles it fine per the issue's own report, just worth knowing this is a real constraint if it ever needs to change.

### Checked and already fine — not gaps

- TypeScript `strict` mode is already on.
- The `"files"` allowlist approach (vs. a blacklist `.npmignore`) is already the modern-correct pattern — the LICENSE bug (#2) is a path mistake within that pattern, not a reason to abandon it.
- `.d.ts.map` source maps are already included in the published tarball.

---

## Options

### Option A: Fix the two real bugs now (#1, #2), defer the rest

`@opentelemetry/api` → peerDependency, and fix the LICENSE path — both small, mechanical, low-risk changes with no ambiguity about whether they're correct. Everything else (#3–#6) genuinely is "nice to have, not urgent."

**Pros**: closes the only two items that are actually *wrong* today (not just "could be better"), minimal scope, fast.
**Cons**: doesn't address the process gap (#3) that let the OTel drift happen in the first place — the next dependency drift will be just as invisible.

### Option B: Fix everything in this investigation in one pass

**Pros**: one release cycle instead of several; the "publishing infrastructure" items (#5, #6) naturally cluster with #3 (dependabot) since they're all about the release/maintenance pipeline, not the library's runtime behavior.
**Cons**: mixes a real-bug fix (peerDependency change is arguably a breaking change for anyone with an unusually old/incompatible `@opentelemetry/api` already installed) with pure process/tooling changes that have nothing to do with runtime correctness — harder to review, harder to isolate if something regresses.

### Option C: Bugs now, dependabot next, publishing infra (provenance/Trusted Publishing) as its own separate investigation later

Recognizes that #5 in particular (moving publish from a manual DevContainer step to a GitHub Actions OIDC flow) is a meaningfully bigger process change than the others — worth its own dedicated investigation rather than a bullet point here.

**Pros**: right-sizes each piece of work; doesn't let a genuinely bigger publishing-infrastructure change block or get diluted by two small bug fixes.
**Cons**: more total investigations/plans to track.

---

## Recommendation

**Option C.** Fix #1 and #2 as a small, fast `PLAN-*.md` — they're real bugs with no design ambiguity. Add `.github/dependabot.yml` (#3) as a quick follow-up, since it's also low-risk and directly prevents a repeat of the OTel situation. Spin off #5 (provenance/Trusted Publishing) as its own investigation given the real process change involved. Treat #4 (`sideEffects`) and #6 (`exports`) as small opportunistic additions to whichever of the above PRs touches `package.json` next, rather than their own work items.

---

## Open Questions

1. **[Q1]** — **Resolved.** `^1.9.1` — matches the exact version already installed and tested against, over a wider conventional peer range, to avoid claiming compatibility with older `1.x` versions that were never actually tested.
2. **[Q2]** — **Resolved, checked directly.** `ollacrm/services/api/package.json` has no `@opentelemetry/*` dependency, and no `sovdev-logger` dependency at all yet — the onboarding guide was written, but the actual integration into `ollacrm`'s own code hasn't happened. **No live diamond-dependency risk exists anywhere today.** Still worth fixing sovdev-logger's own declaration proactively; there's just zero urgency behind it.
3. **[Q3]** — **Resolved, tested empirically.** Copy the root `LICENSE` into `typescript/LICENSE` — the only option. Directly tested `"../LICENSE"` in a scratch package's `files` array: `npm pack --dry-run --json` confirms npm silently drops anything outside the package root being published, no error, no warning. Two copies to keep in sync is a real, if minor, ongoing cost.
4. **[Q4]** — **Resolved.** Bundle `.github/dependabot.yml` with the #1/#2 bugfix PR — one release cycle, all three are small, low-risk, `package.json`-adjacent changes.
5. **[Q5]** — **Resolved.** Start a separate investigation now, while the npm-ownership context from `INVESTIGATE-repo-and-package-ownership.md` is still fresh — see [`INVESTIGATE-npm-trusted-publishing.md`](../backlog/INVESTIGATE-npm-trusted-publishing.md).

## Next Steps

- [x] Maintainer answers [Q1]–[Q5] — all resolved 2026-07-13
- [ ] Create `PLAN-library-best-practices-bugfix.md` for #1 (peerDependency), #2 (LICENSE), and #3 (dependabot.yml) — small, fast, no remaining design ambiguity
- [x] Spin off [`INVESTIGATE-npm-trusted-publishing.md`](../backlog/INVESTIGATE-npm-trusted-publishing.md) for #5
