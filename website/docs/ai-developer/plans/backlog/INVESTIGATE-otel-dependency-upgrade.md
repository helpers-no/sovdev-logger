# Investigate: Upgrading sovdev-logger's OpenTelemetry dependencies

Explores how to safely close the gap between sovdev-logger's currently pinned OpenTelemetry/uuid dependency ranges and their patched, current versions — flagged by 4 Dependabot alerts (2 high, 2 moderate) — given that OTel's own Node SDK packages are still pre-1.0 and jumping many minor versions at once carries real breaking-change risk, not just a routine bump.

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Backlog

**Goal**: Determine a safe upgrade path (and testing strategy) for `@opentelemetry/sdk-node`, `@opentelemetry/auto-instrumentations-node`, `@opentelemetry/core`, and `uuid`, closing the Dependabot alerts without silently breaking auto-instrumentation, exporter configuration, or the OTLP wire format for existing integrators.

**Last Updated**: 2026-07-13

---

## Source

[GitHub issue #23](https://github.com/helpers-no/sovdev-logger/issues/23) on `helpers-no/sovdev-logger`, filed by the ollacrm integration team running `1.0.2` in production. Their own risk assessment: none of the 4 alerts have an exploitable path in *their* deployment (the high-severity ones require the Prometheus pull-exporter, unused; the moderate ones require inbound W3C `baggage` header extraction or a direct `uuid.v3/v5/v6` call, neither of which they do) — but they were explicit this is "deployment-specific luck, not something the package should rely on integrators to verify individually."

---

## Questions to Answer

1. **[Q1]** Is it safe to jump `@opentelemetry/sdk-node` from `^0.55.0` to current latest in one step, or does the changelog between those versions contain breaking changes that need an intermediate stop / careful review (0.x packages can break on minor bumps per semver convention for pre-1.0 packages)?
2. **[Q2]** `@opentelemetry/core` is jumping from an installed `1.28.0`/`1.30.1` (transitive, per the issue) to a `2.x` major version — what actually changed across that major bump, and does anything in `src/logger.ts` depend on `core`'s API surface directly (vs. only transitively through `sdk-node`)?
3. **[Q3]** Should `uuid` become a direct dependency (it's currently only a transitive one, despite `src/logger.ts` importing `uuidv4` from it directly — see Current State) as part of this same upgrade, or as a separate, smaller fix?
4. **[Q4]** What's the actual test plan for "this upgrade didn't break anything" — the existing E2E tests (`typescript/test/e2e/company-lookup/`) already exercise real OTLP delivery against both UIS and Grafana Cloud; is running those sufficient, or does the auto-instrumentation change specifically need its own dedicated check (e.g. does Winston auto-instrumentation still patch correctly under the new `auto-instrumentations-node` version)?
5. **[Q5]** Does this get released as a patch, minor, or major version of `@terchris/sovdev-logger` itself — given transitive dependency bumps alone don't usually need a major bump, but a bundle-size or behavior change from `auto-instrumentations-node` might?

---

## Current State

Confirmed directly against `typescript/package.json` and the npm registry (not assumed from the issue's numbers, which could be stale):

| Package | Installed range (`package.json`) | Currently latest on npm | Gap |
|---|---|---|---|
| `@opentelemetry/sdk-node` | `^0.55.0` | `0.220.0` | ~165 minor versions |
| `@opentelemetry/auto-instrumentations-node` | `^0.51.0` | `0.78.0` | ~27 minor versions |
| `@opentelemetry/core` | `1.28.0`/`1.30.1` (transitive, pinned across the tree) | `2.9.0` | 1 major version |
| `@opentelemetry/api` | `^1.9.0` | `1.9.1` | patch only — **not** part of this problem |
| `uuid` | not a direct dependency at all — only `@types/uuid ^10.0.0` (devDependency); the real `uuid` package is transitive, installed at `9.0.1` | `14.0.1` | direct-dependency gap, not just a version gap |

- **`uuid` is imported directly in source** (`src/logger.ts` imports `uuidv4` from `'uuid'`) **but isn't declared as a direct dependency** — it currently works only because some other dependency happens to pull it in transitively. This is a correctness gap independent of the version number: if the transitive path ever changes, the import could break with no direct `package.json` entry to explain why.
- `@opentelemetry/api` (the stable, versioned-1.x-and-up interfaces package) is already current — the real gap is entirely in the **implementation** packages (`sdk-node`, `auto-instrumentations-node`) and the shared **utility** package (`core`), which follow a different, faster-moving versioning track than `api`.
- The existing E2E test suite (`typescript/test/e2e/company-lookup/`) already exercises real OTLP log/metric/trace delivery against both UIS and Grafana Cloud end-to-end — this is the natural regression check for "did the upgrade break real delivery," though it doesn't specifically target auto-instrumentation's Winston-patching behavior.

---

## Why this isn't a routine bump

OpenTelemetry's Node SDK packages (`sdk-node`, `auto-instrumentations-node`, and friends) are still versioned `0.x` — under semver convention, a `0.x` package can introduce breaking changes on a **minor** version bump, not just a major one. Jumping `^0.55.0` → `0.220.0` crosses roughly 165 minor releases; treating that the same as a routine patch-level Dependabot bump risks missing a real breaking change buried somewhere in that range (a renamed config option, a changed default, a removed export). `@opentelemetry/core` crossing `1.x` → `2.x` is an explicit major bump by any convention. Both deserve a deliberate look at the packages' own changelogs/migration notes before committing to a version, not just "bump the range and see what breaks."

---

## Options

### Option A: One big jump straight to current latest, validated by the existing E2E suite

Bump all four to current latest in one PR, run the existing E2E tests against both UIS and Grafana Cloud, ship if green.

**Pros:** Fastest to close all 4 Dependabot alerts at once; the E2E suite already proves real end-to-end delivery, which is the thing that actually matters to integrators.

**Cons:** If something breaks, the failure could be attributable to any of ~165+ intermediate releases across two packages at once — hard to bisect. The E2E suite doesn't specifically exercise auto-instrumentation's Winston-patching path in isolation, only as a side effect of logging during the test.

### Option B: Staged bump — `core` first (isolated, smaller major-version surface), then `sdk-node`/`auto-instrumentations-node` together

Two separate PRs: first `@opentelemetry/core`'s major bump alone (smaller, more reviewable diff, easier to isolate if something regresses), then the two `0.x` implementation packages together (they're versioned in lockstep by the OTel JS project and are meant to be upgraded as a pair).

**Pros:** Smaller, individually-bisectable changes; matches how the OTel JS project itself recommends upgrading (SDK + auto-instrumentations as a matched pair, core separately).

**Cons:** Two PRs/release cycles instead of one; more process overhead for what may turn out to be an uneventful upgrade.

### Option C: Add a dedicated auto-instrumentation smoke test before either bump

Before touching versions, add a small, fast, isolated test that specifically confirms Winston auto-instrumentation still patches correctly (independent of a full OTLP round-trip) — then use it as a fast pre-merge gate for whichever bump strategy (A or B) is chosen.

**Pros:** Directly answers **[Q4]** with a real, fast, repeatable check rather than relying on the slower E2E suite as the only signal; useful as a permanent regression guard for future OTel upgrades too, not just this one.

**Cons:** Extra upfront work before the actual version bump lands; the alerts stay open a bit longer while this is built.

---

## Recommendation

**[Q6]** Leaning toward **Option B** (staged: `core` first, then the `0.x` pair together) **plus** a lightweight version of **Option C** — not a whole new test file necessarily, but at minimum a manual check ("does a Winston `logger.info()` call still produce an auto-instrumented log record with trace context attached?") run once per bump, so a regression in auto-instrumentation specifically doesn't hide behind a green E2E suite that happens to not exercise that exact path. This is a maintainer call on how much process the 4 alerts (none currently exploitable in the one deployment we've heard from) warrant — Option A is defensible if the maintainer is comfortable treating the existing E2E suite as sufficient evidence.

Fold **[Q3]** (making `uuid` a direct dependency) into the same PR as the `core` bump — it's a one-line `package.json` change with no version-compatibility risk of its own, not worth a separate release cycle.

---

## Next Steps

- [ ] Maintainer decides bump strategy (**[Q6]**: Option A, B, or C)
- [ ] Read `@opentelemetry/core`'s 1→2 major version migration notes before starting (**[Q2]**)
- [ ] Create `PLAN-otel-dependency-upgrade.md` with the chosen approach and explicit before/after version numbers
