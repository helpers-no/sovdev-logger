# Investigate: ollacrm's consolidated feedback (GitHub issue #26)

Triages [GitHub issue #26](https://github.com/helpers-no/sovdev-logger/issues/26) — real production feedback from ollacrm's integration, covering a confirmed severity-mapping bug, a confirmed-still-present connectivity-check bug, an uninitialized-logger DX gap, three onboarding-doc gaps, and a real architectural fix for the auto-instrumentation import-order footgun — verified item-by-item against the current shipped code, not taken at face value from the issue text.

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Backlog

**Goal**: Confirm which of the issue's claims still hold against current `main`, and for each confirmed item, either a clear one-line fix ready for a `PLAN-*.md`, or — for the two genuine design questions — a real options analysis.

**Last Updated**: 2026-07-14

**Source**: [Issue #26](https://github.com/helpers-no/sovdev-logger/issues/26), filed by the ollacrm team (`terchris`), consolidating feedback from several integration rounds (Stage 1 adoption, the scoped→unscoped package migration, a recent coverage audit).

---

## Current State — verified directly against `main`, item by item

### 1. `sovdev_generate_trace_id` — issue says "still open," actually already resolved

The issue reports this function is documented in the README's "Using traceId to Link Operations" section but absent from the package's exports. **Checked directly**: `grep -rn "sovdev_generate_trace_id"` across `typescript/README.md` and `typescript/src/*.ts` returns **zero matches** — the README section was already removed, per `INVESTIGATE-context-propagation.md`'s own earlier resolution (`sovdev_start_span`/`sovdev_end_span` already give the same trace correlation with less code, so the never-shipped function was deleted from docs rather than built). Ollacrm's checkout predates that fix, or they checked the published npm tarball before it re-published. **No code/doc change needed — just reply on the issue confirming it's resolved.**

### 2. `SOVDEV_LOGLEVELS.TRACE` silently coerced to `DEBUG` severity — confirmed, real, one-line bug

`typescript/src/logLevels.ts:8-14` confirms `TRACE` is a genuine, distinct, public log level (`SOVDEV_LOGLEVELS.TRACE = 'trace'`), not an alias for `DEBUG`. But `typescript/src/logger.ts:201-207`'s `severity_map` hardcodes:

```typescript
const severity_map: { [key: string]: SeverityNumber } = {
  trace: SeverityNumber.DEBUG,  // <- bug: collapses TRACE into DEBUG
  debug: SeverityNumber.DEBUG,
  ...
```

Checked the actual OTel enum this file already imports (`@opentelemetry/api-logs`'s `LogRecord.d.ts`): `TRACE = 1` through `TRACE4 = 4` exist as distinct values, separate from `DEBUG = 5`. **This isn't a Winston limitation** (the issue's guessed root cause) — Winston's level name (`'trace'`) already flows through correctly; the bug is purely this one hardcoded map entry pointing at the wrong enum member. **One-line fix**: `trace: SeverityNumber.DEBUG` → `trace: SeverityNumber.TRACE`.

### 3. `sovdev_test_otlp_connection()` misreads HTTP 204 as unreachable — confirmed, still present

`typescript/src/logger.ts:1266-1279`:

```typescript
if (res.statusCode === 200 || res.statusCode === 202) {
  resolve({ reachable: true });
} else if (res.statusCode === 404) {
  ...
} else if (res.statusCode === 400) {
  resolve({ reachable: true }); // 400 might mean endpoint reachable but payload format issue
} else {
  resolve({ reachable: false, error: `HTTP ${res.statusCode}: ...` }); // 204 falls here
}
```

`204 No Content` — Grafana Cloud's real response for a successful OTLP logs push, per the issue's own live test against `otlp-gateway-prod-eu-west-0.grafana.net` — falls into the generic `else` branch and gets reported as unreachable, even though `400` (a genuinely ambiguous case) is already special-cased as reachable. **This is the same bug already noted, unfixed, in `1PRIORITY.md`'s history from the original issue #23** — never actually picked up. **One-line fix**: add `res.statusCode === 204` alongside `200`/`202`.

### 4. `sovdev_log` throws "not initialized" with no consumer testing guidance — confirmed real gap, genuine design question

`typescript/src/logger.ts:1504` throws `'Sovdev Logger not initialized. Call sovdev_initialize(service_name) at application startup.'` if `sovdev_log()` runs before `sovdev_initialize()`. Checked `typescript/README.md`'s only "Testing" section (line 1429, "Testing (for Contributors)") — it's entirely about **this library's own** test suite (`npm run test:unit`, 18/19/E2E test counts), nothing about how a **consumer's** own unit tests should handle a pure helper function that calls `sovdev_log()` internally without the app's real boot sequence having run. Confirmed: no mock/stub/no-op mode exists, no documented "call `sovdev_initialize()` in your test setup" pattern. This is a genuine design question — see Options below, not a one-line fix.

### 5. Three onboarding-doc gaps — all confirmed absent

Checked `website/docs/using/onboarding/index.md` directly for each:
- **Bundle size** (~7 MB from OTel SDK + `auto-instrumentations-node` + winston) — zero mentions.
- **`LOG_TO_FILE`** (relevant for any ephemeral-filesystem deployment like Cloud Run) — zero mentions.
- **ERROR/FATAL → ServiceNow-incident warning** — exists only in `typescript/README.md:1398` (the Compliance section), not in the onboarding guide, where it matters most (before someone's first test log accidentally opens a real incident ticket).

All three are straightforward doc additions — no design decision needed, ready for a `PLAN-*.md` directly. (The fourth doc gap the issue reported — auto-instrumentation import order — turned out to have a real root-cause fix available, not just a documentation gap; see item 6.)

### 6. Auto-instrumentation import-order footgun — confirmed real, and root-cause fixable, not just documentable

The issue reports this only as a doc gap: *"Auto-instrumentation's import-order requirement is only documented in a code comment"* (`typescript/test/e2e/company-lookup/company-lookup.ts:78-80`, explaining why that example uses a dynamic `import()` for `https` instead of a normal top-of-file import). Confirmed absent from both the onboarding guide and the README's quick-start.

**But the underlying mechanism is worth understanding before just documenting around it.** OpenTelemetry's auto-instrumentation works by patching a module (`https`, `pg`, etc.) at the moment Node's module loader first loads it — patching after the fact does nothing, since any code already holding a reference to the original functions keeps using them. `sovdev_initialize()` (`typescript/src/logger.ts:949-952`) registers `getNodeAutoInstrumentations()` from **inside application code**, as a normal function call. In an ES module file, all top-level `import`s are hoisted and run before any function body executes — so if any instrumented module is imported normally anywhere in the app (or in a transitive dependency), it's already loaded by the time `sovdev_initialize()` runs, no matter where that call sits. This is exactly why the E2E reference example needs its dynamic-`import()` workaround.

**Checked directly against the actual installed package** (`typescript/node_modules/@opentelemetry/auto-instrumentations-node/README.md`, not assumed from memory): OpenTelemetry's own documented best practice for exactly this problem is a `--require`/`--import` **preload flag**, not a programmatic call from inside the app:

```bash
node --require '@opentelemetry/auto-instrumentations-node/register' app.js
# or:
NODE_OPTIONS="--require @opentelemetry/auto-instrumentations-node/register"
```

This runs instrumentation setup as a separate step before Node loads the app file at all — no ordering race, by construction, not by discipline. The README frames the programmatic path (what `sovdev_initialize()` does today) as the option for *custom per-instrumentation configuration*, not the default recommendation — and it's specifically that path which carries the ordering risk.

**Refined finding, checked directly against `configure_opentelemetry()` (`typescript/src/logger.ts:863-964`)**: the ordering-sensitive part — building the `NodeSDK`, registering `getNodeAutoInstrumentations()` — only needs `service_name` and `service_version`, both already env-var-derivable (`OTEL_SERVICE_NAME`, `getServiceVersion()`'s existing fallback chain). `peer_services` is **not used anywhere in this function** — it's only consumed later, in `initialize_sovdev_logger()`, to build the `PEER_SERVICES.mappings` lookup object, which has no ordering constraint at all (Winston setup, peer-service mapping, metrics — none of it cares whether it runs before or after the app's own imports). This means a preload entry point doesn't need to solve "how does `peer_services` become an env var" — it only ever needs the two values already handled by existing env vars. See the revised Option 6B below.

### Already resolved / no action needed (per the issue itself)

- Context propagation (`sovdev_set_context()`) — ollacrm confirms it's live-verified working in production. No action.
- OTel/uuid Dependabot vulnerabilities — ollacrm confirms `npm audit` clean on the current unscoped package. No action.

### Positive data points (no action, worth citing back)

- esbuild single-file bundling verified clean against real production dashboard data.
- `company-lookup.ts` E2E example praised as "genuinely good teaching artifact" — worth pointing new integrators to it more directly (ties into [Q2] of `INVESTIGATE-docs-site-structure.md`, the generic-developer-quickstart-template question).

---

## Options

### For item 4: `sovdev_log` throwing when uninitialized

#### Option 4A: Document only

Add a clearly-titled section (README + onboarding guide) explaining the throw, why it happens, and the one-line fix: call `sovdev_initialize()` once in test setup (e.g. a Jest/Vitest `beforeAll`). Zero code change, zero risk of masking a real misconfiguration in production.

**Pros**: no behavior change to reason about; a genuinely one-line fix once known, exactly as the issue itself frames it.
**Cons**: doesn't help the case the issue actually hit twice — a **pure helper function**'s own isolated unit test, which may not want to run the app's full boot sequence (real OTLP endpoints, real env vars) just to satisfy one throw.

#### Option 4B: No-op/console-fallback mode when uninitialized

`sovdev_log()` falls back to a plain `console.log`/no-op instead of throwing, when called before `sovdev_initialize()`.

**Pros**: a stray call in test code degrades gracefully instead of failing the test suite.
**Cons**: silently changes behavior for what might be a **real** production misconfiguration (forgetting to call `sovdev_initialize()` at all) — turns a loud, immediate, obvious failure into a silent one. This is a real regression risk for the exact opposite reason the throw exists in the first place.

#### Option 4C: Both — document the test-setup pattern, and add a narrowly-scoped test-only escape hatch

E.g. an explicit `sovdev_initialize_for_testing()` or similar, clearly named to signal "test-only, do not use in production code" — so a consumer's unit test can opt in to lenient behavior without silently weakening the production throw.

**Pros**: solves the actual reported pain (isolated unit tests of pure helpers) without touching the production safety net.
**Cons**: one more public API surface to design, document, and maintain — needs its own naming/shape decision.

### For item 6: auto-instrumentation import order

#### Option 6A: Document the workaround only

Add the import-order warning (currently only a code comment) to the README quick-start and onboarding guide, with the dynamic-`import()` pattern as the documented fix.

**Pros**: zero code change, ships immediately alongside items 2/3/5.
**Cons**: doesn't fix the actual footgun — a new integrator can still get silently-unpatched instrumentation with no error, just now with a documented (but easy to miss) warning instead of an undocumented one. Every future consumer inherits the same risk, mitigated only by having read the docs closely.

#### Option 6B: Ship a preload entry point, with a split responsibility — root-cause fix, revised

Add a `sovdev-logger/register` module that does **only the ordering-sensitive part**: build the `NodeSDK`, register `getNodeAutoInstrumentations()`, sourced from `OTEL_SERVICE_NAME`/existing env vars — nothing new to design here, since those env vars already exist. Invoked via:

```bash
node --import sovdev-logger/register app.js
```

`sovdev_initialize()` **stays exactly as consumers already call it today** — same signature, same `peer_services` argument, no breaking change — but becomes idempotent: it checks whether a real tracer provider is already registered (OTel's own `trace.getTracerProvider()` API already exposes this — no new state to invent) and, if so, skips re-registering the SDK/instrumentation and only does the Winston/`peer_services`/metrics wiring it always did. If the preload wasn't used, it falls back to registering everything itself, exactly as today.

**This resolves [Q4]** (the original version of this option's open design question, "what's the env-var shape for `peer_services`") — there isn't one to answer, because `peer_services` never has to leave application code at all.

**Pros**: fixes the actual root cause instead of documenting around it; matches OpenTelemetry's own recommended pattern exactly; genuinely additive — consumers who don't adopt the preload get exactly today's behavior (including today's import-order risk, unchanged) and consumers who do adopt it change only their `node` invocation, not their application code. Small enough to be close to a `PLAN-*.md` directly, not a speculative future design.
**Cons**: still needs idempotency-check logic added to `initialize_sovdev_logger()`, and [Q5] (CJS vs. ESM entry point support) answered before implementation.

#### Option 6C: Option 6A now, Option 6B as a follow-up `PLAN-*.md`

Ship the documentation fix immediately (no reason to leave a known, easy-to-fix doc gap open), and draft the preload entry point as its own plan — now closer to "ready to implement" than "needs a design decision," since the split-responsibility design above removed the one open question that made it feel speculative.

**Pros**: doesn't block the cheap, immediate fix on drafting the plan; the plan itself is now small and well-scoped rather than open-ended.
**Cons**: none significant — this is just sequencing, not a real trade-off.

---

## Recommendation

**Items 2, 3, 5**: ready for a `PLAN-*.md` directly — each is a verified, one-line-to-small fix with no design ambiguity.
**Item 1**: no fix needed, just a reply on the issue.
**Item 4**: **Option 4A first** (cheap, zero-risk, addresses the "opaque otherwise" half of the issue's own framing), with **Option 4C as a real follow-up** if consumers keep hitting this in isolated unit tests after the docs ship — don't build the test-only API speculatively before confirming Option 4A alone doesn't already resolve it.
**Item 6**: **Option 6C** — ship the documentation fix (6A) now alongside items 2/3/5. The preload entry point (6B) no longer has an open design question blocking it ([Q4] resolved below — `peer_services` never needs to leave application code) — draft its `PLAN-*.md` directly once [Q5] (CJS/ESM entry-point support) is checked.

---

## Open Questions

1. **[Q1]** Does `SOVDEV_LOGLEVELS.TRACE` → `SeverityNumber.TRACE` need any migration/compat note for existing consumers whose dashboards/alerts might currently (incorrectly) treat TRACE-level logs as DEBUG? Likely not — nobody has built dashboard logic depending on the *bug*, but worth a quick check before shipping the fix.
2. **[Q2]** For item 3's fix, is `204` the *only* other success status Grafana Cloud's OTLP gateway can return, or should the check be broadened (e.g. any `2xx`) rather than allowlisting statuses one at a time as they're discovered? Worth checking OTel's own OTLP/HTTP spec for the full set of valid success responses rather than patching reactively per bug report.
3. **[Q3]** Should item 4's Option 4A test-setup guidance live in the README's existing "Testing (for Contributors)" section (renamed/split to cover both audiences), or as a new, separate "Testing your integration" section aimed specifically at consumers? The current section is titled and scoped for contributors only.
4. ~~**[Q4]**~~ **Resolved.** Originally: what's the env-var shape for `peer_services`? Turns out moot — checked `configure_opentelemetry()` (`typescript/src/logger.ts:863-964`) directly and confirmed `peer_services` isn't used anywhere in the ordering-sensitive part (SDK/auto-instrumentation registration); it's only consumed later, in `initialize_sovdev_logger()`, for the `PEER_SERVICES.mappings` lookup, which has no ordering constraint. The preload entry point (revised Option 6B) only ever needs `service_name`/`service_version`, both already env-var-backed — `peer_services` stays exactly as it is today, passed to `sovdev_initialize()` from application code, no new design needed.
5. **[Q5]** Does `sovdev-logger/register` need to support both a CommonJS (`--require`) and an ESM (`--import`) entry point, or just one? Depends on what module format sovdev-logger itself ships and what its consumers use — needs checking against `typescript/package.json`'s `exports`/`type` fields before designing the entry point.

## Next Steps

- [ ] Reply on issue #26 confirming item 1 already resolved
- [ ] Draft `PLAN-*.md` for items 2, 3, and 5 (likely one combined plan — all are small, independent, verified fixes)
- [ ] Decide Option 4A vs 4C for item 4 once [Q3] is answered
- [ ] Check [Q2] against the OTLP/HTTP spec before finalizing item 3's fix
- [ ] Ship item 6's Option 6A (doc fix) alongside items 2/3/5
- [ ] Check [Q5] (CJS vs. ESM entry-point support), then draft item 6's Option 6B (`sovdev-logger/register` preload entry point, split-responsibility design) as its own `PLAN-*.md` — no longer blocked on an open design question

## Files to Modify

- `typescript/src/logger.ts` — item 2 (`severity_map`, line ~203), item 3 (`res.statusCode` check, line ~1266)
- `website/docs/using/onboarding/index.md` — item 5's three gaps, item 6's Option 6A warning
- `typescript/README.md` — item 4's Option 4A (test-setup guidance), item 6's Option 6A warning
- `typescript/src/register.ts` (new, item 6's Option 6B, follow-up plan) — the preload entry point, doing only the ordering-sensitive SDK/auto-instrumentation registration
- `typescript/src/logger.ts` (item 6's Option 6B, follow-up plan) — `initialize_sovdev_logger()` gains an idempotency check (`trace.getTracerProvider()`) to skip re-registering the SDK/instrumentation if the preload already did
- `typescript/package.json` (item 6's Option 6B, follow-up plan) — new `exports` entry for `sovdev-logger/register`
