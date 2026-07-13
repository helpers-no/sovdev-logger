# Plan: Upgrade OpenTelemetry dependencies to latest

Closes the real gap `INVESTIGATE-otel-dependency-upgrade.md` found (49 vulnerabilities, 1 critical) by bumping `@opentelemetry/sdk-node`, `@opentelemetry/auto-instrumentations-node`, `@opentelemetry/core` (transitive), and `winston` to their current latest versions in one pass (Option A), declaring `uuid` as a direct dependency along the way, and fixing the real breaking changes the major-version jumps introduce.

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Active

**Goal**: Every OTel package (and `uuid`) at current latest, zero regressions, validated against both real UIS and real Grafana Cloud, with the critical-severity `protobufjs` vulnerability (and the other 48) closed.

**Last Updated**: 2026-07-13

**Investigation**: [INVESTIGATE-otel-dependency-upgrade.md](INVESTIGATE-otel-dependency-upgrade.md) — [Q6] resolved: Option A (one big jump), not the staged/smoke-test approach originally leaned toward. [Q3] (make `uuid` a direct dependency) folded into this same plan per the investigation's own recommendation.

**Real breaking changes found before writing this plan** (not discovered mid-implementation) — checked by installing the actual latest packages in a scratch directory and reading their real `.d.ts` files, not just the changelog prose:

1. **`BasicTracerProvider.addSpanProcessor()` removed** (`@opentelemetry/sdk-trace-base`/`sdk-trace` 2.x) — `logger.ts`'s `tracer_provider.addSpanProcessor(new BatchSpanProcessor(...))` call must become a constructor option: `new BasicTracerProvider({ resource, spanProcessors: [new BatchSpanProcessor(...)] })`. Confirmed `spanProcessors?: SpanProcessor[]` exists on `TracerProviderOptions` in the real installed `2.9.0` package.
2. **`Resource` is now a type-only interface, not a constructible class** (`@opentelemetry/resources` 2.x) — explicitly documented "NOT user-implementable." `logger.ts`'s two `new Resource({...})` calls (lines 789, 874) won't compile at all. Fix: `import { resourceFromAttributes } from '@opentelemetry/resources'` and call `resourceFromAttributes({...})` instead — same attribute-object shape, confirmed via the real installed package's `ResourceImpl.d.ts`.

**Checked and confirmed NOT a problem**: `MeterProvider` already uses the constructor `readers: [...]` pattern (not the removed `addMetricReader()` method) — no change needed there. `uuid`'s `import { v4 as uuidv4 } from 'uuid'` named-export shape is unchanged at the latest `14.x`.

**Not exhaustively audited by reading every changelog page** across ~165 minor `sdk-node`/`auto-instrumentations-node` releases — impractical and less reliable than letting `tsc` surface every other breaking change directly once the versions are actually bumped, which Phase 1 does.

---

## Phase 1: Bump versions and fix compile errors

### Tasks — DONE

- [x] 1.1 Bumped `typescript/package.json`: `@opentelemetry/api-logs`, `sdk-logs`, `exporter-logs-otlp-http`, `exporter-metrics-otlp-http`, `exporter-trace-otlp-http`, `sdk-node` → `^0.220.0`; `resources`, `sdk-metrics`, `sdk-trace-base` → `^2.9.0`; `auto-instrumentations-node` → `^0.78.0`; `semantic-conventions` → `^1.43.0`; `@opentelemetry/api` → `^1.9.1`; `winston` → `^3.19.0`.
- [x] 1.2 Added `uuid` as an explicit direct dependency at `^14.0.1`. **Removed `@types/uuid` entirely instead of bumping it** — npm flagged it as deprecated on install ("this is a stub types definition, uuid provides its own type definitions"); confirmed directly via the installed `uuid` package's own `package.json` (`"types": "./dist/index.d.ts"`), not just the deprecation notice.
- [x] 1.3 Fixed the two known breaking changes (`addSpanProcessor()` → `spanProcessors` constructor option; `new Resource({...})` → `resourceFromAttributes({...})`), **plus two more `tsc` actually surfaced** that weren't caught by the pre-implementation changelog read: `BatchLogRecordProcessor`'s constructor now takes an options object (`{ exporter, ... }`) instead of a positional exporter argument, and `LoggerProvider.addLogRecordProcessor()` was removed in favor of a `processors` constructor option — the exact same pattern as the trace-side removal, just on the logs SDK.
- [x] 1.4 `npx tsc --noEmit` — clean on the second pass, after fixing the 2 additional breaks it surfaced. Confirms `tsc`-driven discovery was the right call over trying to read every changelog page across ~165 minor releases.
- [x] 1.5 `npm run lint` and `npm run build` — both clean.
- [x] 1.6 `npm audit --omit=dev` — **49 vulnerabilities → 0**, including the critical `protobufjs` arbitrary-code-execution advisory. Confirmed via a real `npm audit` run after a clean `node_modules` reinstall (inside the DevContainer, on Node 22.22.2 — the host Mac's Node 20.11.0 doesn't satisfy `engines.node: >=22.0.0` and threw `EBADENGINE`, so all actual build/test work happened in the DevContainer).

### Validation

`tsc`/`lint`/`build` all clean. `npm audit --omit=dev --json` output: `{'info': 0, 'low': 0, 'moderate': 0, 'high': 0, 'critical': 0, 'total': 0}` — a real, re-run check, not assumed from the pre-upgrade count.

---

## Phase 2: End-to-end validation against real backends — DONE

### Tasks

- [x] 2.1 Ran the `company-lookup` E2E test against real UIS. **Hit and fixed an unrelated real bug along the way**: the E2E test's own `node_modules/esbuild` (used by `tsx`) was version-mismatched against its host binary (`0.25.10` vs `0.28.1`), unrelated to anything this plan touched — fixed with a clean `node_modules`/`package-lock.json` reinstall in that directory. After the fix: schema validation passed (17+2 entries), then a direct Loki query confirmed all context fields (`client_name`/`service_principal`/`acting_user`) and trace/span correlation landed correctly.
- [x] 2.2 Same against real Grafana Cloud — schema validation passed, the Grafana Cloud privacy warning still fired correctly for `acting_user`, and a direct Loki Cloud query confirmed the data landed.
- [x] 2.3 Ran Python's E2E test and `compare-with-master.sh python` — clean match across all 17 entries, confirming the OTLP wire format itself didn't change in a way that breaks cross-language parity.
- [x] 2.4 Ran `sovdev-selftest` against both real backends (write + read-back for both log and metric) — passed on both, confirming auto-instrumentation still works correctly under the new `auto-instrumentations-node` version.

### Validation

Real query output confirmed on both backends for the E2E test, a clean cross-language diff, and a clean `sovdev-selftest` pass against both — matching the standard every other backend-facing change this session has used. Zero regressions found in any previously-shipped behavior.

---

## Phase 3: Final checks — DONE

### Tasks

- [x] 3.1 Confirmed no regression to any previously-shipped feature (`client_name`/`service_principal`/`acting_user` context propagation, the Grafana Cloud privacy warning, job status/progress logging) — Phase 2's E2E run exercised all of these against both real backends with no failures.
- [x] 3.2 Version bump: **patch, `1.0.0` → `1.0.1`** — dependency-only change, no public API surface change (no exported function added/removed/renamed).
- [x] 3.3 Checked every live-facing doc for hardcoded OTel version numbers — only one found (`contributor/02-field-definitions.md`'s `telemetry_sdk_version` field, showing illustrative example values like `"1.37.0", "1.28.0"`), which is a format example, not a stale config claim — left as-is, no Docusaurus rebuild needed for this.
- [x] Re-ran `tsc`/`lint`/`build` after the version bump — all clean.

### Validation

Diff scoped to exactly: `typescript/package.json` (dependency versions + package version), `typescript/package-lock.json` (regenerated), `typescript/src/logger.ts` (the 4 breaking-change fixes: `addSpanProcessor`→`spanProcessors`, `new Resource`→`resourceFromAttributes`, `BatchLogRecordProcessor`'s options-object constructor, `addLogRecordProcessor`→`processors`), plus the E2E test's own unrelated stale-esbuild fix (`typescript/test/e2e/company-lookup/package-lock.json`) found and fixed during Phase 2. No unrelated changes.

---

## Acceptance Criteria

- [x] `@opentelemetry/sdk-node`, `auto-instrumentations-node`, `core` (transitive), and `winston` all at current latest.
- [x] `uuid` is a declared direct dependency, not just transitive. (`@types/uuid` removed entirely rather than bumped — `uuid` ships its own types as of `14.x`.)
- [x] `npm audit` shows a verified drop from 49 vulnerabilities to **0** — critical `protobufjs` advisory resolved along with everything else.
- [x] `tsc`/`lint`/`build` clean.
- [x] Real E2E validation against both UIS and Grafana Cloud, plus cross-language comparison against Python, all passing.
- [x] `sovdev-selftest` passes against both real backends.

---

## Files to Modify

- `typescript/package.json`
- `typescript/src/logger.ts` (the two breaking-change fixes, plus anything else `tsc` surfaces)
- `typescript/package-lock.json` (regenerated)
