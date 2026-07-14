# Investigate: Migrating to TypeScript 7

Whether and how to move this repo's 5 `package.json` files off `typescript@^5.7.2`/`~6.0.3` and onto `7.0.2`, given a confirmed regression that breaks ambient Node global type resolution.

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Backlog

**Goal**: Determine whether TypeScript 7.0.2 can be adopted safely across this repo, what would need to change first, and in what order — spun off from [`INVESTIGATE-dependency-upgrade-sweep.md`](INVESTIGATE-dependency-upgrade-sweep.md)'s own [Q5], which found the naive bump-and-watch approach doesn't work here.

**Last Updated**: 2026-07-14

**Relationship to the parent sweep**: `INVESTIGATE-dependency-upgrade-sweep.md` deferred 3 Dependabot PRs (#13 `tools/dashboards`, #15 `typescript/`, #19 `website`) rather than merge them blind, after finding `typescript@7.0.2` breaks the build in `tools/validation`. This investigation exists to actually scope the fix, rather than leave those PRs closed indefinitely with no path forward.

---

## Background — the trigger finding (2026-07-14, confirmed directly)

While bumping `@types/node` and `tsx` in `tools/validation` (see `completed/PLAN-otel-dependency-upgrade.md`'s sibling work), applying `typescript@7.0.2` on top produced ~50 errors across every file in `tools/validation/grafana-cloud/` — `Cannot find name 'process'`, `Cannot find name 'Buffer'`, `Cannot find module 'node:fs'`, etc. Isolated by reverting `typescript` alone back to `^5.7.2` while keeping `@types/node@26.1.1` and `tsx@4.23.1` — clean. This is a real, reproduced regression, not a hypothesis.

**Root cause, per TypeScript's own documented behavior change** (confirmed via web research, not just the blog below — verify against TypeScript's own release notes before implementing): starting at TypeScript 6.0, the compiler stopped auto-discovering all `@types/*` packages in `node_modules` for ambient globals. A project relying on `process`/`Buffer`/`node:*` being globally available (as Node code typically does) must now explicitly list `"types": ["node"]` in `tsconfig.json`'s `compilerOptions`. `tools/validation/tsconfig.json` and `tools/dashboards/tsconfig.json` both lack this field — they never needed it while auto-discovery still worked under 5.x, and the failure was latent until the compiler major-version bump actually removed the fallback.

Sources: [Preparing for TypeScript 7.0: Breaking Changes and Migration Steps](https://www.webhani.com/blog/typescript-7-breaking-changes), [The TypeScript 6.0 Migration Recipe](https://medium.com/@alexandre.mokni/the-typescript-6-0-migration-recipe-upgrading-without-breaking-your-app-417b8b58805f) — both third-party summaries, not Microsoft's own release notes; **re-verify against the actual TypeScript 7.0 changelog before drafting a PLAN**, since exact version boundaries in third-party blog posts are sometimes off by a minor version.

Per the same research, TypeScript 7.0 has **more** breaking changes than just this one:

1. **[Q1]** `"moduleResolution": "node"` (the classic, pre-Node16 resolution strategy) is deprecated and reportedly removed in 7.0 — projects need `"node16"`/`"nodenext"` (for Node-targeted code) or `"bundler"` (for bundler-targeted code) instead.
2. **[Q2]** `"target": "es5"` and `"baseUrl"` without a matching `"paths"` setup are also reportedly deprecated/removed — not currently used anywhere in this repo's tsconfigs (checked directly, none set `target: es5`), so likely not a real blocker here, but worth a final grep before implementing.
3. **[Q3]** `--strict` is reportedly enabled by default in 7.0. Every tsconfig in this repo already sets `"strict": true` explicitly except `website/tsconfig.json` (which extends `@docusaurus/tsconfig` — its effective strictness needs checking, not assumed).

## Current State — every tsconfig and package.json, checked directly

| Package | `typescript` version pin | `moduleResolution` | Explicit `"types"` field | Has the Node-globals bug reproduced? |
|---|---|---|---|---|
| `typescript/` (the published library) | `^5.7.2` (resolves to `5.9.3`) | `"node"` (classic, not NodeNext) | Not set | **Not yet tested** — different `tsconfig` shape than `tools/validation`, may or may not reproduce; must test directly, not assumed |
| `tools/validation/` | `^5.7.2` (pinned back 2026-07-14, was going to be `7.0.2`) | `"NodeNext"` | Not set | **Yes, confirmed** — the original trigger finding |
| `tools/dashboards/` | `^5.7.2` (same pin) | `"NodeNext"` | Not set | **Not yet tested directly, but same tsconfig shape as `tools/validation` — likely reproduces** |
| `website/` | `~6.0.3` (Docusaurus's own peer requirement, not this repo's choice) | Inherits from `@docusaurus/tsconfig` | Inherits, not checked | **Not yet tested** — Docusaurus itself may already handle this; check Docusaurus's own TS7 support status before assuming it's this repo's problem to fix |
| `typescript/test/e2e/company-lookup/` | `^5.7.2` | Not set (no local tsconfig found — runs via `tsx` directly, no `tsc --noEmit` step) | N/A | **Likely doesn't matter** — this package has no type-check step in its own `run-test.sh`, only `tsx` execution, so a compiler-version bug here may never surface as a build failure (though it could still affect `tsx`'s internal transpilation — not yet tested) |

**A second, separate blocker found while researching this** (2026-07-14, confirmed via `npm view`): `@typescript-eslint/eslint-plugin@8.64.0` (the latest version, and the only one that pairs with `@typescript-eslint/parser@8.64.0` — see `INVESTIGATE-eslint9-migration.md`) declares a peer dependency of `"typescript": ">=4.8.4 <6.1.0"`. **This caps out below TypeScript 7 entirely.** Even once the Node-globals bug is fixed, `typescript/` (the only package that actually uses `@typescript-eslint` — checked, `tools/` and `website/` don't lint with it) cannot adopt `typescript@7.0.2` until `@typescript-eslint` itself ships support for it — a second, independent reason `typescript/` specifically can't move yet, on top of the untested Node-globals question.

---

## Options

### Option A: Fix the Node-globals issue in `tools/`, defer `typescript/` and `website/` indefinitely

Add `"types": ["node"]` to `tools/validation/tsconfig.json` and `tools/dashboards/tsconfig.json`, re-test with `typescript@7.0.2`, and if clean, bump just those two packages. Leave `typescript/` (blocked by `@typescript-eslint`'s peer range) and `website/` (blocked by Docusaurus's own `~6.0.3` pin, not this repo's call to override) exactly where they are.

**Pros**: unblocks 2 of 3 deferred PRs (#13, and partially informs #15) with a small, well-understood, low-risk change. Doesn't touch the published library's compiler version, which is the highest-blast-radius package to get wrong.
**Cons**: `typescript/` — the actual product — stays on TS 5 indefinitely, which will keep drifting further behind. Splits this into yet another partial state to track.

### Option B: Also migrate `moduleResolution` repo-wide from `"node"`/leave-as-`"NodeNext"` and fully commit to a TS7-ready tsconfig shape now, even before `typescript@7.0.2` itself is adopted

Update `typescript/tsconfig.json`'s `"moduleResolution": "node"` → `"nodenext"` (matching what `tools/` already uses) as prep work, independent of the compiler version bump, so the eventual TS7 bump is a smaller, isolated step later.

**Pros**: de-risks the eventual bump; `moduleResolution` changes can be validated under TS 5.9.3 today, without needing TS 7 at all — fully separable, fully testable now.
**Cons**: `"moduleResolution": "node"` → `"nodenext"` can itself change module resolution behavior (e.g. requiring explicit file extensions in relative imports under `NodeNext` + ESM) — this is not risk-free just because it's "prep," and needs its own real build+test pass, not a rubber-stamp.

### Option C: Wait for `@typescript-eslint` to support TypeScript 7, then do a single repo-wide bump

Do nothing until `@typescript-eslint`'s peer range moves past `<6.1.0`. Revisit this investigation once that happens.

**Pros**: avoids splitting `typescript/`'s lint tooling and compiler version into two separate migration events.
**Cons**: fully blocks all progress, including the low-risk `tools/` fix, on an external project's release timeline that has no committed date.

---

## Recommendation

**Option A first, Option B as explicit follow-up prep — not bundled together.** The `tools/validation`/`tools/dashboards` fix is small, isolated, and already has a reproduced failure to test against (revert-and-confirm, the same rigor already used to find the bug). Do that alone, verify with a real `tsc --noEmit` plus each package's actual runtime scripts (matching the standard this repo now holds itself to — see `feedback_validation_must_test_realistic_conditions` in the assistant's memory), and ship it as its own PR.

Do **not** attempt `typescript/`'s bump in the same pass — it's blocked by `@typescript-eslint`'s peer range regardless of what's done to the Node-globals issue, so there is no way to "finish" it right now. Track it as blocked (Tier 3-style) rather than open-ended Tier 2 work, and revisit once `INVESTIGATE-eslint9-migration.md`'s own recommendation lands (which itself doesn't require an ESLint major bump — see that doc — but does clarify the `@typescript-eslint` upgrade path that TS7 support depends on).

---

## Open Questions

1. **[Q1]** Confirm `"moduleResolution": "node"` is actually deprecated/removed in 7.0 (re-verify against TypeScript's own changelog, not just the blog cited above) — if confirmed, does `typescript/tsconfig.json` need the `"nodenext"` migration (Option B) before or independent of the compiler bump itself?
2. **[Q2]** Deprecated `"target": "es5"`/bare `"baseUrl"` — confirmed not present in any of this repo's tsconfigs today; does this need any action at all, or is it a non-issue here?
3. **[Q3]** `--strict` defaulting to on in 7.0 — every tsconfig here already sets it explicitly except `website/`'s (inherited from `@docusaurus/tsconfig`); check what Docusaurus's own tsconfig actually sets before assuming this is a gap.
4. **[Q4]** Does `website/`'s `typescript: "~6.0.3"` pin come from Docusaurus's own `peerDependencies`, or is it just this repo's current choice that happens to match? If the former, `website/` may be blocked on Docusaurus's own TS7 support, not on anything fixable in this repo — needs a direct check (`npm view @docusaurus/core@3.10.2 peerDependencies`) before drafting a plan for it.
5. **[Q5]** Should `typescript/test/e2e/company-lookup/`'s `typescript` pin be bumped independent of the others, given it has no `tsc --noEmit` step in its own test script and may not even exercise the compiler in a way that surfaces this bug? Worth confirming directly (does `tsx` itself invoke `typescript` for anything relevant) rather than assuming it's safe by default.

## Next Steps

- [ ] Maintainer answers [Q1]–[Q5]
- [ ] Test the `"types": ["node"]` fix directly in `tools/validation` and `tools/dashboards` against `typescript@7.0.2` — confirm it actually resolves the reproduced failure before drafting a PLAN
- [ ] If clean: draft `PLAN-typescript7-tools-migration.md` scoped to just `tools/validation` + `tools/dashboards`
- [ ] Separately, monitor `@typescript-eslint`'s releases for TypeScript 7 peer-range support — re-open the `typescript/` question once that lands
- [ ] Re-close PRs #13/#15/#19 for real (merge or keep closed with an updated comment) once the above PLAN ships or a final decision is made

## Files to Modify (once a plan is drafted from this)

- `tools/validation/tsconfig.json`, `tools/dashboards/tsconfig.json` — add `"types": ["node"]`
- `tools/validation/package.json`, `tools/dashboards/package.json` — bump `typescript` to `^7.0.2` (pending the test above)
- `typescript/tsconfig.json` — possible `moduleResolution` migration (Option B), tracked separately from the compiler version bump
- `typescript/package.json`, `website/package.json`, `typescript/test/e2e/company-lookup/package.json` — not touched until their respective blockers ([Q4], `@typescript-eslint` peer support) are resolved
