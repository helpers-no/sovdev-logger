# Investigate: Migrating ESLint and `@typescript-eslint` past their current majors

Whether to bump `eslint` (8→10) and `@typescript-eslint/parser`+`eslint-plugin` (7→8) in `typescript/`, given ESLint 9's mandatory flat-config migration — and a real finding that the two upgrades are less coupled than the open Dependabot PRs assume.

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Backlog

**Goal**: Determine whether `@typescript-eslint` can be bumped to 8.x without also forcing an ESLint major bump, and separately, whether/when to migrate off `.eslintrc.json` to flat config — spun off from [`INVESTIGATE-dependency-upgrade-sweep.md`](INVESTIGATE-dependency-upgrade-sweep.md)'s own [Q3].

**Last Updated**: 2026-07-14

**Relationship to the parent sweep**: `INVESTIGATE-dependency-upgrade-sweep.md` left 3 Dependabot PRs open specifically because of this: #14 (`eslint` 8.57.1→10.7.0), #17 (`@typescript-eslint/parser` 7.18.0→8.64.0, currently failing on a peer-dependency conflict). `eslint-config-prettier`'s own major bump (9→10) already shipped cleanly on its own as PR #16 — no conflict, not discussed further here.

**Only `typescript/` is in scope.** Checked directly: `website/`, `tools/dashboards/`, and `tools/validation/` have no ESLint config or `eslint` dependency at all — this is purely a `typescript/package.json` + `typescript/.eslintrc.json` question.

---

## Background — why PR #17 actually fails (checked directly via `npm view`, not assumed)

`typescript/package.json` currently pins:
```json
"@typescript-eslint/eslint-plugin": "^7.0.0",
"@typescript-eslint/parser": "^7.0.0",
"eslint": "^8.57.0"
```

Dependabot's PR #17 bumps `@typescript-eslint/parser` alone to `8.64.0`, leaving `eslint-plugin` at `7.18.0`. That's the actual break: `@typescript-eslint/eslint-plugin@7.18.0`'s own `peerDependencies` require `"@typescript-eslint/parser": "^7.0.0"` — bumping the parser alone violates the plugin's peer constraint on it. **The two packages must be bumped together, in lockstep** — this is a known pattern for the `@typescript-eslint` monorepo (plugin and parser are versioned and released together), not specific to this repo.

**The real finding, not anticipated by the parent sweep's [Q3]**: checking what the *paired* upgrade actually requires —

```
@typescript-eslint/eslint-plugin@8.64.0 peerDependencies:
  eslint: "^8.57.0 || ^9.0.0 || ^10.0.0"
  typescript: ">=4.8.4 <6.1.0"
  "@typescript-eslint/parser": "^8.64.0"
```

`eslint: "^8.57.0 || ^9.0.0 || ^10.0.0"` — **this repo's current `eslint@^8.57.0` already satisfies that range.** Bumping `@typescript-eslint/eslint-plugin` + `@typescript-eslint/parser` together to `8.64.0` requires **no ESLint version change at all** and therefore **no flat-config migration** to unblock PR #17. The two upgrades (`@typescript-eslint` 7→8, and `eslint` 8→10) are independent, not sequential — the parent sweep's framing of "ESLint 9 migration blocks the `@typescript-eslint` bump" was an assumption, not a confirmed fact; it doesn't hold up.

(Cross-reference: the same peer-dependency check found `@typescript-eslint/eslint-plugin@8.64.0` caps `typescript` at `<6.1.0` — relevant to `INVESTIGATE-typescript7-migration.md`'s own finding that `typescript/` can't adopt TS7 until `@typescript-eslint` supports it.)

## Current State

**`typescript/.eslintrc.json`** (the only ESLint config in the repo, checked directly):
```json
{
  "parser": "@typescript-eslint/parser",
  "extends": [
    "eslint:recommended",
    "plugin:@typescript-eslint/recommended",
    "prettier"
  ],
  "parserOptions": { "ecmaVersion": 2020, "sourceType": "module" },
  "rules": {
    "@typescript-eslint/explicit-function-return-type": "error",
    "@typescript-eslint/explicit-module-boundary-types": "off",
    "@typescript-eslint/no-explicit-any": "warn",
    "@typescript-eslint/no-unused-vars": ["error", { "argsIgnorePattern": "^_", "varsIgnorePattern": "^_", "destructuredArrayIgnorePattern": "^_" }],
    "complexity": ["error", 20],
    "max-lines-per-function": ["warn", 200],
    "no-console": "off"
  }
}
```
These custom rules (especially `no-unused-vars`'s ignore patterns and the LLM-dead-code-prevention philosophy documented in the file's own comments) are load-bearing for this project specifically — any migration must reproduce them exactly, not just "migrate to a reasonable flat config."

**ESLint 9/10's mandatory flat config** (confirmed via web research — [ESLint's own migration guide](https://eslint.org/docs/latest/use/configure/migration-guide), [ESLint 9 Flat Config: The Migration Guide for Teams Who Have Put It Off](https://blog.codercops.com/blog/eslint-9-flat-config-migration-2026)): starting at ESLint 9, `.eslintrc.*` files are no longer read by default — a single `eslint.config.js`/`.mjs` at the project root replaces them, with plugins imported as JS objects (not string references) and `env`/`globals`/`parserOptions` consolidated under one `languageOptions` key. ESLint itself ships an official migrator, `npx @eslint/migrate-config .eslintrc.json`, but **its own docs say it doesn't handle `.eslintrc.js` well** (only evaluated output, no functions/conditionals) — not directly relevant here since this repo's config is already `.eslintrc.json` (pure JSON, no logic), so the automated migrator should work cleanly, but this needs to be verified on a real run, not assumed from the docs alone. `typescript-eslint`'s own package provides a `tseslint.config(...)` helper and a `tseslint.configs.recommended` array that bundles the parser + recommended rules, simplifying the flat-config equivalent of this repo's current `"extends"` array. `eslint-config-prettier` has supported flat config since its own v9 (already what this repo has, via PR #16) — the flat-config rule is that the Prettier config array entry must come **last**, after every other config, since it works by disabling rules.

---

## Options

### Option A: Bump `@typescript-eslint` to 8.x now, defer ESLint/flat-config separately

Update `typescript/package.json`'s `@typescript-eslint/eslint-plugin` and `@typescript-eslint/parser` together to `^8.64.0`, leave `eslint` at `^8.57.0` untouched. No `.eslintrc.json` changes needed — flat config is only mandatory once ESLint itself moves to 9+.

**Pros**: unblocks PR #17 immediately, using confirmed-compatible peer ranges, zero config migration risk. Fully separable from the ESLint major-version question.
**Cons**: `@typescript-eslint/eslint-plugin@8.x`'s recommended rule set has changed since 7.x (new rules added, some renamed/removed) — needs a real `npm run lint` pass against `src/**/*.ts` to catch anything that now fails or newly warns, not just a version-bump-and-assume.

### Option B: Do the full migration in one pass — ESLint 8→10, flat config, and `@typescript-eslint` 7→8 together

**Pros**: one migration event instead of two; avoids leaving ESLint on an older major indefinitely.
**Cons**: bundles a real, non-mechanical config rewrite (flat config) with a dependency bump — directly contradicts this sweep's own established pattern of isolating risk (see `INVESTIGATE-dependency-upgrade-sweep.md`'s Option B rationale, and how OTel was deliberately kept separate from routine bumps). Makes it harder to isolate which change caused a regression if `npm run lint` behaves differently afterward.

### Option C: Leave everything as-is indefinitely

**Pros**: zero effort, zero risk — `eslint`/`@typescript-eslint` are dev-only, no runtime/security exposure.
**Cons**: PR #17 stays open and un-mergeable forever for a reason (the peer conflict) that Option A resolves cheaply; the eventual ESLint 9/10 migration only gets more distant if never scheduled.

---

## Recommendation

**Option A**, matching the same risk-isolation principle the parent sweep itself already established. The `@typescript-eslint` bump is confirmed peer-compatible with the current ESLint version and requires no config rewrite — it's a normal, low-risk dependency bump masquerading as a harder problem because Dependabot happened to open the parser-only half of it first. Do this alone, verify with a real `npm run lint` (not just `tsc --noEmit`, since rule changes are the actual risk here, not type errors), and ship it.

Treat the ESLint 8→10 + flat-config migration (PR #14) as its own, later, deliberate piece of work — not blocking, not urgent (no security exposure, dev-only), but real enough to need its own care reproducing the exact custom rule set above rather than accepting whatever a generic migration guide produces.

---

## Open Questions

1. **[Q1]** Confirm Option A's peer-compatibility finding is still current at implementation time — `npm view @typescript-eslint/eslint-plugin@latest peerDependencies` again, since these ranges can change with new releases.
2. **[Q2]** After bumping `@typescript-eslint` to 8.x, does `npm run lint` against `src/**/*.ts` pass clean, or does the 8.x recommended rule set surface new violations? If new violations appear, are they real problems worth fixing, or rules worth explicitly disabling to preserve this repo's current, deliberately-tuned rule set?
3. **[Q3]** For the eventual flat-config migration: run `npx @eslint/migrate-config .eslintrc.json` for real and diff the output against a hand-written flat config using `tseslint.config(...)` — which is more faithful to the current custom rules (the dead-code-prevention `no-unused-vars` config, `complexity`, `max-lines-per-function`)? Don't assume the automated migrator's output is correct without a real lint run comparing before/after on the actual `src/` tree.
4. **[Q4]** Does this repo want to move `lint`/`lint:fix`'s glob (`src/**/*.ts`) into the flat config's own `files` property, or keep it as an npm-script-level glob the way it is today? Flat config conventionally centralizes this, but it's not required.
5. **[Q5]** Timing — is there any reason to prioritize the ESLint 9/10 migration soon (e.g. ESLint 8 approaching its own EOL/security-support cutoff), or is "no urgency signal" still accurate? Worth a direct check of ESLint's own support-policy page before marking this permanently low-priority.

## Next Steps

- [ ] Maintainer answers [Q1]–[Q5]
- [ ] Draft `PLAN-typescript-eslint-8-bump.md` for Option A — the low-risk half, ready to scope now
- [ ] Re-verify PR #17 either merges cleanly after the paired bump, or gets superseded by a manual commit (matching the pattern already used for PRs #10/#12/#22 in `tools/validation`)
- [ ] Separately, once there's appetite: draft `INVESTIGATE`-level detail (or go straight to a `PLAN-*.md`, if Option A's answers make the flat-config path clear enough) for the ESLint 8→10 migration itself
- [ ] Close PR #14 with an accurate comment either way — deferred pending the above, not silently ignored

## Files to Modify (once a plan is drafted from this)

- `typescript/package.json` — `@typescript-eslint/eslint-plugin` and `@typescript-eslint/parser` bumped together to `^8.64.0` (Option A); `eslint` left untouched for now
- `typescript/.eslintrc.json` → `eslint.config.js`/`.mjs` — only once the separate ESLint 9/10 migration is scoped and approved
