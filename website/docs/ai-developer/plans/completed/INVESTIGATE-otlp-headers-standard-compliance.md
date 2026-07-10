# Investigate: Fix sovdev-logger's OTEL_EXPORTER_OTLP_HEADERS to follow the actual OpenTelemetry standard

Found while wiring up Grafana Cloud ingestion for `INVESTIGATE-grafana-cloud-validator.md` (on a separate, not-yet-merged branch — not linked here to avoid a broken-link build failure until both land on `main`): sovdev-logger's own contract mandates a JSON format for `OTEL_EXPORTER_OTLP_HEADERS` that deviates from the actual OpenTelemetry specification — and the deviation isn't just cosmetic, it actively collides with the underlying OTel SDK's own native handling of that same, reserved env var name, silently dropping telemetry whenever a header value contains a literal `=` character (e.g. any Basic Auth token, since base64 padding uses `=`).

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Resolved — child plan shipped, `@terchris/sovdev-logger@1.0.1` published

**Goal**: Bring sovdev-logger's `OTEL_EXPORTER_OTLP_HEADERS` handling into line with the actual OpenTelemetry specification (the W3C Baggage HTTP header format: `key1=value1,key2=value2`), removing the library's own custom JSON-based convention and the collision it causes — across both the contract doc and both language implementations.

**Last Updated**: 2026-07-09 — diagnosis complete, confirmed by reading the actual installed `@opentelemetry/otlp-exporter-base`/`@opentelemetry/core` source, not assumed from documentation.

---

## Questions to Answer

1. **[Q1]** Is this actually a real deviation from the OTel standard? — **Decided: yes, confirmed.** See [Current State](#current-state) for the full trace through the actual SDK source.
2. **[Q2]** Fix now or defer? — **Decided: fix now.** The bug silently drops telemetry (caught exception logged as a non-fatal warning, easy to miss) for any consumer using Basic-Auth-style headers — not a Grafana-Cloud-specific edge case, a general correctness bug in a published package.
3. **[Q3]** Version bump strategy — `@terchris/sovdev-logger` is already published at `1.0.0`. Does this fix ship as a `1.0.1` patch release? The public API (`sovdev_initialize`, `sovdev_log`, etc.) doesn't change — only the `.env`/env-var *configuration* format changes — but that's still a behavior change for anyone who copied the current `.env.example` pattern. — **Open.**
4. **[Q4]** Backward compatibility — support both the old JSON format and the new spec format (detect which one was given), or a clean break? The package was published *today*, in this same session, with effectively zero real external consumers yet. — **Leaning clean break** (no detection code, no dual-format complexity) given the timing, but flagging as a real decision rather than assuming.
5. **[Q5]** Scope of the custom validation/connectivity-test code (`sovdev_validate_config`, `sovdev_test_otlp_connection` in TypeScript; the equivalent in Python) that currently does its own `JSON.parse`/`json.loads` on this env var for diagnostic purposes, separate from the actual exporter configuration — rewrite to parse the new format, or simplify/remove since the OTel SDK's own error handling surfaces auth failures naturally? — **Open.**
6. **[Q6]** TypeScript first (the reference implementation this project always treats as canonical) then port to Python and re-verify with `compare-with-master.sh`, or both languages together? — **Decided: TypeScript first**, matching the established, working pattern from every prior cross-language plan in this project.

---

## Current State

### The actual OpenTelemetry standard for this env var

Per the OTel spec and the [W3C Baggage HTTP header format](https://github.com/w3c/baggage/blob/master/baggage/HTTP_HEADER_FORMAT.md) it's based on: `OTEL_EXPORTER_OTLP_HEADERS` (and the per-signal variants `OTEL_EXPORTER_OTLP_{LOGS,METRICS,TRACES}_HEADERS`) is a comma-separated list of `key=value` pairs — e.g. `Authorization=Basic dXNlcjpwYXNz,X-Custom=foo`. Not JSON.

### sovdev-logger's contract mandates the wrong format

`website/docs/contributor/01-api-contract.md:936`: *"`OTEL_EXPORTER_OTLP_HEADERS` - HTTP headers (must be JSON format)"*. This isn't an implementation bug independently made twice — both `typescript/src/logger.ts` and `python/src/logger.py` correctly implemented what the contract told them to do. The contract itself is wrong. Confirmed via grep across the whole `specification`/`website/docs/contributor` tree — the JSON convention appears consistently everywhere this env var is documented or used (`05-environment-configuration.md`, `06-test-scenarios.md`), including the guidance that single-quoting the value in `.env` is "critical" to prevent bash from corrupting the JSON during `source` — a workaround for a self-inflicted problem, not something OTel itself ever requires.

### Why this doesn't just fail to add custom headers — it actively breaks the SDK's own request

Traced through the actual installed packages (`typescript/node_modules/@opentelemetry/otlp-exporter-base`, `@opentelemetry/core`), not assumed:

1. `OTLPExporterNodeBase`'s constructor (used by every signal's exporter — logs, metrics, traces) calls `mergeOtlpHttpConfigurationWithDefaults(explicitConfig, getHttpConfigurationFromEnvironment(...), defaults)`. The middle argument reads `process.env.OTEL_EXPORTER_OTLP_HEADERS` **independently**, regardless of whatever `headers` object the application code explicitly passes to the exporter constructor.
2. That env-var reader parses the raw string via `baggageUtils.parseKeyPairsIntoRecord()` — the actual W3C Baggage parser. Given sovdev-logger's JSON string (e.g. `{"Authorization":"Basic <base64>"}`), this parser's `indexOf('=')`-based splitting finds the **first** `=` — which, for a value with no `=` at all (like UIS's `{"Host":"otel.localhost"}`), produces an empty value that gets filtered out silently (no bug, by accident). But for a Basic Auth token, base64 padding legitimately contains `=` characters — the parser finds that `=`, splits there, and produces a **non-empty garbage key** (the raw JSON text up to that point) that survives the filter.
3. `mergeHeaders()` then combines this garbage additively with the application's correctly-parsed explicit headers — both end up in the final header set, not one replacing the other.
4. When the HTTP transport iterates the combined headers to call Node's `ClientRequest.setHeader(name, value)`, the garbage key (containing `{`, `"`, `:` — not valid HTTP token characters) throws `ERR_INVALID_HTTP_TOKEN`, caught by sovdev-logger's flush/shutdown error handling and logged as a non-fatal warning — meaning **the actual telemetry for that flush is silently dropped**, not just that the extra header failed to attach.

Confirmed empirically end-to-end: this exact crash reproduced live when wiring up the TypeScript E2E test against Grafana Cloud (`typescript/test/e2e/company-lookup/.env.grafana-cloud`'s `OTEL_EXPORTER_OTLP_HEADERS='{"Authorization":"Basic ...=="}'`) — flush failed with the literal JSON string as the rejected header name.

### Confirmed this is safe to fix with the real spec format

Checked the separator constants directly (`@opentelemetry/core/build/src/baggage/constants.js`): item separator is `,`, key/value separator is `=` (first-occurrence only, via `indexOf`), property separator is `;`. Base64's alphabet (`A-Z a-z 0-9 + / =`) never contains `,` or `;`, and the `=` padding is handled correctly since the parser splits on the *first* `=` only. `Authorization=Basic <base64>` — the real spec format — parses correctly through the SDK's own native mechanism with no custom code needed.

### Cross-language: Python has the identical pattern

`python/src/logger.py` lines 688-691 (metrics), 733-743 (traces), and reuses the same parsed `headers` for logs (~769) — `json.loads(os.environ.get("OTEL_EXPORTER_OTLP_HEADERS", "{}"))`. The Python OTel SDK almost certainly has the same env-var-reads-independently-of-constructor-args behavior (same cross-language OTel spec), though this hasn't been traced through the Python SDK's source the way the JS SDK was — worth confirming empirically when porting the fix, not assuming it's identical just because the language-level bug pattern matches.

### Blast radius

- **Affected**: sovdev-logger's own OTLP export configuration (both languages, all three signals) — anywhere a header value contains `=`.
- **Not affected**: `tools/validation/grafana/`'s query/verification tooling — it builds Basic Auth headers directly via `fetch()`/`Authorization` header, never going through `OTEL_EXPORTER_OTLP_HEADERS` or the OTel SDK's env-var mechanism at all.
- **Already published**: `@terchris/sovdev-logger@1.0.0` is live on npm with this bug present.

---

## Options

Given [Q1]/[Q2]/[Q6] are already decided, the only real options concern [Q3] (version bump) and [Q4] (backward compatibility):

### Option A: Clean break, patch version bump (1.0.1), no dual-format support

Remove the JSON parsing entirely, document the new format, bump to `1.0.1`. Anyone who already grabbed `1.0.0` and hit this bug gets the actual fix; nobody was likely relying on the specific broken JSON behavior since it never worked correctly for Basic-Auth-style headers anyway.

**Pros:** Simplest code, no dual-format detection complexity to maintain or eventually deprecate. Matches the reality that this package has had zero real-world adoption time (published today).
**Cons:** Anyone who somehow already wrote a `.env` using the JSON format (e.g. copied from the current, soon-to-be-wrong docs) needs to update it — though this is true regardless of whether old-format support is kept, since the *contract doc* itself is being corrected.

### Option B: Support both formats during a transition window

Detect JSON (starts with `{`) vs. spec format at parse time, support both, document the JSON format as deprecated.

**Pros:** Zero breakage for any existing `.env` files using the current (wrong) format.
**Cons:** Real complexity for a bug that's never actually worked correctly in the first place (JSON format was always going to collide with any header value containing `=`) — there's nothing valuable to preserve compatibility with. Adds detection logic that itself needs testing and eventually needs removing.

---

## Recommendation

**Option A.** There's no working behavior to preserve compatibility with — the JSON format was never actually safe to use with Basic-Auth-style headers, which is exactly the case that matters for every real backend beyond local UIS (Azure, Google Cloud, Grafana Cloud all use some form of token-based auth). A clean break costs nothing given the package's actual adoption state (published today, in this session) and avoids maintaining dual-format detection code for a format that should never have existed.

[Q3] (exact version number) and [Q5] (validation-code scope) remain the maintainer's call — Option A doesn't resolve them, it just avoids adding a third option's worth of complexity around [Q4].

---

## Next Steps

- [x] Drafted [`PLAN-fix-otlp-headers-spec-compliance.md`](../completed/PLAN-fix-otlp-headers-spec-compliance.md) — the concrete, phased implementation plan (TypeScript → Python → version bump/republish)
- [x] Child plan shipped: all 3 phases done, `@terchris/sovdev-logger@1.0.1` published to npm — this INVESTIGATE moves to `completed/` alongside it
- [x] [Q3] (version bump: `1.0.1`, patch) and [Q5] (validation/connectivity-test code: rewritten to the new format, not removed) decided inline in the PLAN's Phase 1/3 tasks
