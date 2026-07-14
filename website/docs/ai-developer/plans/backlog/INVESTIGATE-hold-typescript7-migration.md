# Investigate: Migrating to TypeScript 7

Whether and how to move this repo's 5 `package.json` files off `typescript@^5.7.2`/`~6.0.3` and onto `7.0.2`, given a confirmed regression that breaks ambient Node global type resolution.

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Backlog — [Q1]–[Q5] answered 2026-07-14; recommendation is now **wait**, not migrate

**Goal**: Determine whether TypeScript 7.0.2 can be adopted safely across this repo, what would need to change first, and in what order — spun off from [`INVESTIGATE-hold-dependency-upgrade-sweep.md`](INVESTIGATE-hold-dependency-upgrade-sweep.md)'s own [Q5], which found the naive bump-and-watch approach doesn't work here.

**Last Updated**: 2026-07-14

**Relationship to the parent sweep**: `INVESTIGATE-hold-dependency-upgrade-sweep.md` deferred 3 Dependabot PRs (#13 `tools/dashboards`, #15 `typescript/`, #19 `website`) rather than merge them blind, after finding `typescript@7.0.2` breaks the build in `tools/validation`. This investigation exists to actually scope the fix, rather than leave those PRs closed indefinitely with no path forward.

**Update 2026-07-14 — maintainer pushback, correct and decisive**: TypeScript 7.0.2 was published **6 days ago** (`2026-07-08`, confirmed via `npm view typescript time`) — this is a brand-new major release. The maintainer's objection: a lot of the tooling this repo depends on doesn't control its own TS7 support timeline, so there's no reason to absorb migration pain now for a version the ecosystem hasn't caught up to yet. Direct testing below **supports this** — two independent, confirmed hard blockers exist beyond the original Node-globals finding, one of them (`@typescript-eslint`'s peer range) entirely outside this repo's control. **The recommendation below changed from "fix `tools/` now" to "wait and monitor" as a direct result.**

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

| Package | `typescript` version pin | `moduleResolution` | Explicit `"types"` field | Has a TS7 break been reproduced? |
|---|---|---|---|---|
| `typescript/` (the published library) | `^5.7.2` (resolves to `5.9.3`) | `"node"` (classic, not NodeNext) | Not set | Not directly tested (moot — see `@typescript-eslint` blocker below, which hard-blocks this package regardless) |
| `tools/validation/` | `^5.7.2` (pinned back 2026-07-14, was going to be `7.0.2`) | `"NodeNext"` | Not set | **Yes, confirmed** — the original trigger finding (Node-globals: `process`/`Buffer`/`node:*` unresolvable) |
| `tools/dashboards/` | `^5.7.2` (same pin) | `"NodeNext"` | Not set | Not directly tested, but identical tsconfig shape to `tools/validation` — same bug near-certain |
| `website/` | `~6.0.3` (**this repo's own choice — not inherited from Docusaurus**, see [Q4] below) | `"bundler"` (inherited from `@docusaurus/tsconfig`, already TS7-friendly) | Not set | **Yes, confirmed directly** (2026-07-14): installed `typescript@7.0.2` in isolation and ran `npm run typecheck` — failed immediately with `tsconfig.json(4,5): error TS5102: Option 'baseUrl' has been removed`. `website/tsconfig.json` sets `"baseUrl": "."` itself (not inherited) — a **second, distinct** TS7 break from the Node-globals one, and it fails before the Node-globals question is even reached (`docusaurus.config.ts` uses `process.env`, backed only by a *transitive* `@types/node` today, not a declared dependency — would also break once `baseUrl` is fixed, not yet tested since the harder error came first) |
| `typescript/test/e2e/company-lookup/` | `^5.7.2` | Not set (no local tsconfig found — runs via `tsx` directly, no `tsc --noEmit` step) | N/A | Not tested — deprioritized along with everything else, see recommendation below |

**A second, separate blocker, independent of anything in this repo** (2026-07-14, confirmed via `npm view`): `@typescript-eslint/eslint-plugin@8.64.0` (the latest version, and the only one that pairs with `@typescript-eslint/parser@8.64.0` — see `INVESTIGATE-hold-eslint9-migration.md`) declares a peer dependency of `"typescript": ">=4.8.4 <6.1.0"`. **This caps out below TypeScript 7 entirely — not a bug in this repo, a hard ceiling in someone else's package.** `typescript/` (the only package that lints with `@typescript-eslint`) cannot adopt `typescript@7.0.2` until that project itself ships TS7 support, with no committed date. This confirms the maintainer's framing directly: at least one real blocker here has nothing to do with this repo's own code and can't be worked around by fixing tsconfigs.

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

### Option D: Wait entirely — don't fix anything yet, not even `tools/` — and just monitor

Do nothing at all across all 5 packages. Keep `typescript` pinned everywhere it already is (`^5.7.2` in `tools/`/`typescript/`, `~6.0.3` in `website/`). Leave PRs #13/#15/#19 closed with the findings already recorded on each (done). Revisit this investigation later — either when `@typescript-eslint` ships TS7 support (unblocks `typescript/`), or opportunistically whenever someone is already touching `tools/validation`/`tools/dashboards`/`website` for an unrelated reason.

**Pros**: TypeScript 7.0.2 is 6 days old at the time of this investigation. Fixing `tools/`'s Node-globals issue and `website`'s `baseUrl` removal today buys nothing real — `typescript` isn't being used for anything TS7-specific yet, there's no security exposure (dev-only compiler), and the ecosystem (confirmed: `@typescript-eslint`, and `website`'s own `docusaurus.config.ts` relying on a transitive-only `@types/node`) hasn't caught up. Doing the `tools/` fix now is optional effort spent for a version this repo can't fully adopt anyway (since `typescript/` is hard-blocked regardless) — better to wait until adopting TS7 is actually possible everywhere, then do one coordinated pass instead of a partial one now and a second pass later.
**Cons**: `tools/validation`/`tools/dashboards` stay one version further behind than they technically need to (their own blocker is fixable today, unlike `typescript/`'s). If TS7 becomes urgent later (e.g. a security fix only ships for 7.x), this defers work that could have been done incrementally.

---

## Recommendation

**Option D.** Reversed from this investigation's first draft (which recommended Option A) after direct testing surfaced a second real TS7 break in `website/` (`baseUrl` removed — `TS5102`, confirmed by installing `typescript@7.0.2` in isolation and running the real `typecheck` script) on top of the already-confirmed Node-globals bug and the `@typescript-eslint` peer-range ceiling. Three independent breaks across three different packages, one of them (`@typescript-eslint`) entirely outside this repo's control, for a compiler release that shipped 6 days ago — this is exactly the "tooling I don't control needs to move first" situation. Doing the `tools/` half now would only produce a partial, asymmetric upgrade (`tools/` on 7.x, `typescript/` stuck on 5.x indefinitely) for no real benefit today.

**Action taken as a result of this recommendation**: nothing further to fix right now. `typescript` stays pinned exactly where it already is, everywhere. PRs #13/#15/#19 stay closed (already done, no change needed). This investigation stays in `backlog/` as a monitoring placeholder — re-open when `@typescript-eslint` ships TS7 support, not on a schedule.

---

## Open Questions — all resolved 2026-07-14

1. ~~**[Q1]** Is `"moduleResolution": "node"` deprecated/removed in 7.0?~~ **Resolved — moot.** Not independently tested (direct testing hit `website/`'s `baseUrl` error first, and `typescript/` is separately hard-blocked by `@typescript-eslint`'s peer range regardless of its `moduleResolution` setting). Given the recommendation is now to wait, not migrate, this doesn't need resolving today — revisit only once a real migration is scheduled.
2. ~~**[Q2]** Deprecated `"target": "es5"`/bare `"baseUrl"` — not present in any tsconfig?~~ **Resolved — the original claim was wrong, corrected.** `website/tsconfig.json` **does** set `"baseUrl": "."` explicitly (line 4) — confirmed via direct test: installing `typescript@7.0.2` in `website/` and running `npm run typecheck` fails immediately with `TS5102: Option 'baseUrl' has been removed`. This is a real, confirmed second break, not a non-issue as first assumed.
3. ~~**[Q3]** Does `--strict` default to on in 7.0, and does `website/`'s inherited strictness gap matter?~~ **Resolved — moot for now.** Testing didn't reach this far (`baseUrl` failed first, before any type-checking of actual code happened). Not worth resolving further while the recommendation is to wait rather than migrate.
4. ~~**[Q4]** Does `website/`'s `typescript: "~6.0.3"` pin come from Docusaurus's own peer requirement?~~ **Resolved — no.** Confirmed via `npm view @docusaurus/core@3.10.2 peerDependencies`: no `typescript` entry at all. The `~6.0.3` pin is this repo's own choice, not inherited — free to change independently of Docusaurus. Docusaurus's own shared `@docusaurus/tsconfig` base already uses `"moduleResolution": "bundler"` (TS7-friendly) and doesn't set `baseUrl` itself — the `baseUrl` that breaks under TS7 was added on top by this repo's own `website/tsconfig.json`, not inherited.
5. ~~**[Q5]** Should the E2E company-lookup package's `typescript` pin move independently?~~ **Resolved — no, deprioritized along with everything else.** Not tested; not worth resolving while the overall recommendation is to wait. `tsx` transpiles per-file without invoking `tsc`'s full type-checker, so this package is likely the least affected of the five regardless — lowest priority if/when this is revisited.

## Next Steps

- [x] Maintainer answers [Q1]–[Q5] — done 2026-07-14, all resolved as "moot for now" given the wait recommendation
- [x] Test `website/` directly against `typescript@7.0.2` — done, found the `baseUrl` break, reverted cleanly (`git checkout -- package.json package-lock.json && rm -rf node_modules && npm install`), no lasting change
- [ ] ~~Test the `"types": ["node"]` fix in `tools/validation`/`tools/dashboards`~~ — deprioritized; not worth doing until there's a real reason to adopt TS7, per Option D
- [ ] Monitor `@typescript-eslint`'s releases for TypeScript 7 peer-range support (`npm view @typescript-eslint/eslint-plugin@latest peerDependencies` — watch for the `typescript` cap moving past `<6.1.0`) — this is the actual trigger to re-open this investigation, not a calendar date
- [x] PRs #13/#15/#19 stay closed with accurate comments — already done, no further action

## Files to Modify

**None right now** — this investigation's outcome is "wait," not "implement." Revisit this section once `@typescript-eslint` ships TS7 support and a real migration is scheduled. At that point, expect:
- `tools/validation/tsconfig.json`, `tools/dashboards/tsconfig.json` — add `"types": ["node"]`
- `website/tsconfig.json` — replace `"baseUrl": "."` with the `"paths": {"*": ["./*"]}` form TS7's own error message recommends
- `tools/validation/package.json`, `tools/dashboards/package.json`, `website/package.json` — bump `typescript` to `7.x`
- `typescript/package.json`, `typescript/test/e2e/company-lookup/package.json` — only once `@typescript-eslint` unblocks `typescript/` specifically
