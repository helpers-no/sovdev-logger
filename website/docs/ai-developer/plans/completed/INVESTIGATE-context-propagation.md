# Investigate: Request-scoped context propagation for `sovdev_log`

Explores how to let integrators set a cross-cutting field (which frontend/client is calling) once per request and have every downstream `sovdev_log()` call inherit it automatically, instead of threading it through every function signature — driven by a concrete ollacrm use case — and whether the same mechanism should also resolve the separate, smaller `sovdev_generate_trace_id` gap.

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Completed — shipped via `PLAN-context-propagation.md`

**Goal**: Decide the API shape and underlying mechanism for request-scoped context propagation (grounded in ollacrm's real client-identity need), confirm how the new field is actually queryable in Grafana (resolved: structured metadata, not an index label — see Decisions Resolved), and whether `sovdev_generate_trace_id` (documented in the README, never shipped) should be implemented, folded into this mechanism, or removed from the docs.

**Last Updated**: 2026-07-13
**Completed**: 2026-07-13 — its one child plan, [`PLAN-context-propagation.md`](PLAN-context-propagation.md), shipped (all 5 phases, validated end-to-end against real Grafana Cloud and UIS). Moving here per this repo's convention: an INVESTIGATE stays in `backlog/` for its whole life and only moves to `completed/` once every child PLAN it spawned has shipped.

---

## Source

[GitHub issue #23](https://github.com/helpers-no/sovdev-logger/issues/23) on `helpers-no/sovdev-logger`, filed by the ollacrm integration team after running `@terchris/sovdev-logger@1.0.2` in production on Cloud Run for a few weeks, followed by a maintainer discussion that grounded the abstract ask in ollacrm's real architecture (see next section). Two of the issue's five findings feed this investigation:

- **Feature request** — no ambient/"request-scoped" way to set a value once (e.g. per HTTP request) and have it inherit into every `sovdev_log` call downstream. Concrete ask: `sovdev_set_context({...})`, called once per request/middleware, backed by `AsyncLocalStorage` or OTel's own `context`/`baggage` primitives.
- **Bug** — `sovdev_generate_trace_id` is documented in `README.md`'s "Using traceId to Link Operations" section but isn't exported. The integrator worked around it with `sovdev_start_span`/`sovdev_end_span` (which do exist and work).

---

## Concrete driving use case: ollacrm

Resolved through direct discussion with the maintainer, not assumed:

- ollacrm is a frontend (`olla.helsestell.no`) + API (`api.helsestell.no`) that serves it. More frontends will be added later, all calling the same API.
- Each frontend is **registered** with a name and an API key (1:1 — one key per client). The API resolves the key once, at request-auth time, to a client record.
- **Driving need**: the API is being changed to serve two different databases — production and test — so a QA/test frontend can exercise the *same running API* without touching production data. Which database a request hits is **a fixed, structural property of which client called** — a client's key permanently grants access to exactly one database, not a mutable setting that could be reassigned later. Migrating an existing client to a different database isn't something that happens to an existing registration; it would mean provisioning a genuinely new client (a new key, a new name).
- Because of that, **`client_name` alone is sufficient** — it was initially assumed a second `dataset`/`database` field would also be needed, but that was reconsidered once the client→database relationship turned out to be immutable per client identity, not a fact that could drift independently of it (see **[Q7]**'s resolution below for the full reasoning, kept for the record rather than silently dropped).
- Client name is decided **per request**, because a single running `api.helsestell.no` process serves multiple clients over its lifetime — it can't be a static, set-once-at-startup fact the way `service_name` is.
- **The API key itself must never be logged** — only the resolved client name. The key's only job is authentication; once resolved to a name, it's discarded and shouldn't travel any further.
- The end goal is fleet-wide filtering in Grafana: with hundreds of APIs and many registered clients across them, being able to cheaply filter/group "all logs from client X" across the whole fleet, not just within one API's own logs.

This rules out reusing `peer_service` for client identity — confirmed directly, not assumed (`typescript/src/logger.ts:118`, `README.md:693-696`): `peer_service` is documented and used strictly **outbound** ("the external system *you're* calling"), never "who called you." It also isn't currently a Loki label anyway — it's a log-record attribute only, not part of the OTel `Resource` (`logger.ts:717-722`/`802-807` build the `Resource`; `peer_service` is added later, only inside the Winston→OTLP `attributes` object at `logger.ts:173-222`). Only `service_name` (via `ATTR_SERVICE_NAME`, `logger.ts:718`/`803`) and `session_id` are Resource-only fields that Grafana/Loki promotes to real stream labels today.

---

## Multi-backend implication: this must also work on Azure and Google Cloud later

The maintainer has flagged that Azure Monitor and Google Cloud (already scoped in [`INVESTIGATE-external-backend-verification.md`](../backlog/INVESTIGATE-external-backend-verification.md), not yet built) will eventually need this same client-name filtering, not just Grafana Cloud/UIS. That earlier investigation already did real, verified research on how each backend's *query* side works, which changes the shape of **[Q8]** below:

- **Grafana Cloud/UIS (Loki)**: **resolved by direct testing, see [Q8]** — `client_name` can never become a true index label (only resource attributes can), but both backends already handle it well as structured metadata, including fleet-wide search, with no config change needed. Slower than a true label at real scale, but functional.
- **Azure Monitor**: queried via KQL against Log Analytics tables (`OTelLogs`/`OTelTraces`) — a traditional structured-table model, not a label/stream-selector split. Any column in the table is directly filterable by KQL; there's no confirmed equivalent of "must be promoted to a label to be cheap to query" the way Loki requires (per `INVESTIGATE-external-backend-verification.md`'s comparison table). This needs its own direct verification when Azure integration actually happens, not an assumption drawn from the Loki case — but *if* confirmed, it means Loki's label-promotion requirement may be the unusual case here, not the default across backends.
- **Google Cloud (Cloud Logging)**: queried via Cloud Logging's own filter language — also closer to a structured-field model than Loki's stream-label split, though Cloud Logging does have its own distinct "labels" concept for indexed filtering separate from `jsonPayload` content. Whether sovdev-logger's new attribute would need an equivalent promotion step there is unverified and should be checked directly when that integration happens, not assumed identical to either the Loki or the Azure case.

**[Q12]** Practical implication for *this* investigation, not the later backend-specific ones: whatever mechanism is chosen (Options A/B/C below) should emit `client_name` as a plain OTLP log-record attribute — nothing Loki-specific baked into the library's emission logic. The backend-specific work (Loki structured-metadata behavior now; verifying KQL/Cloud-Logging-filter behavior against this same attribute name later) stays out of `sovdev-logger`'s own code either way, and is tracked per-backend in `INVESTIGATE-external-backend-verification.md`, not duplicated here. The field name chosen in **[Q7]** should avoid anything that only makes sense in a Loki-label context so it reads equally naturally as a KQL column or a Cloud Logging field later.

---

## Questions to Answer

1. ~~**[Q1]**~~ Should the new mechanism be a bespoke `sovdev_`-owned context, OTel's own `context`/`baggage` API, or a thin wrapper combining both? **Resolved** → Option A, bespoke `AsyncLocalStorage`. See Decisions Resolved below.
2. ~~**[Q2]**~~ Does `sovdev_generate_trace_id` get implemented as its own function, folded into the new context mechanism, or removed from the README as dead documentation? **Resolved** → removed. See Decisions Resolved below.
3. ~~**[Q3]**~~ What's the merge behavior when a field is set at multiple levels? **Resolved** → no override, context is the only source. See Decisions Resolved below.
4. ~~**[Q4]**~~ Should this ship as a 1.x minor (additive, backward compatible) or does it need any breaking change to `sovdev_log()`'s existing signature? **Resolved** → moot. See Decisions Resolved below.
5. ~~**[Q6]**~~ Verify directly (not assume) whether `NodeSDK`'s default context manager already propagates correctly across the async boundaries a real Express/Fastify-style request handler uses, or whether `NodeSDK` needs an explicit `contextManager` configured first — this decides whether Options B/C are viable at all. **Moot** — Q1 resolved to Option A, which doesn't touch OTel's context manager at all.
6. ~~**[Q7]**~~ What do we actually call the new field, and do we need a second one for the database? **Resolved** → `client_name` only, one field, not two. See Decisions Resolved below.
7. ~~**[Q8]**~~ How does an attribute actually get promoted to a Loki label on each backend? **Resolved by direct empirical testing** → it can't, on either backend, regardless of config — see Decisions Resolved below.
8. ~~**[Q9]**~~ Is setting client-name/database context **required** on every `sovdev_log()` call once this ships, or strictly **optional**? **Resolved** → optional/additive. See Decisions Resolved below.
9. ~~**[Q10]**~~ Should sovdev-logger help with client registration (name ↔ API key), or stay completely out of scope? **Resolved** → out of scope. See Decisions Resolved below.
10. ~~**[Q11]**~~ Fleet-wide label-cardinality/cost sanity check. **Resolved as moot** — see Decisions Resolved below (structured metadata carries no label-cardinality cost, since it never creates a new stream).
11. ~~**[Q12]**~~ Keep the emission mechanism and field name backend-agnostic so this doesn't need redesigning when Azure Monitor/Google Cloud support lands later. **Resolved** → already satisfied by construction, nothing to trade off. See Decisions Resolved below.

---

## Decisions resolved during planning

- **[Q1] → Option A, bespoke `AsyncLocalStorage`.** Confirmed with the maintainer: `api.helsestell.no` makes no outbound calls to other services — it only receives requests from frontends and talks to its own database. Since there's no downstream service that would ever need to inherit this context across a network hop, OTel's Baggage/cross-process propagation (Options B/C's main advantage) has no concrete use case here. Bespoke `AsyncLocalStorage` is simpler and needs no verification of `NodeSDK`'s context-manager behavior (Q6, now moot).
- **[Q7] → `client_name` only — a second `dataset`/`database` field was considered and dropped.** `client_name` identifies the calling frontend; deliberately not `caller_name` (matches how ollacrm already talks about its registrations). A second field for which database a request hit was assumed necessary early in this investigation and is referenced in earlier sections/history below, but was dropped once the maintainer clarified the real constraint: a client's key permanently and structurally grants access to exactly one database — it's not a mutable setting that could be reassigned independently of client identity. Migrating a client to a different database would mean provisioning an entirely new client (a new key, a new name), which would already show up as a different `client_name` in the logs. Since the mapping can't drift out from under an existing client identity, `client_name` alone already fully and permanently determines the database — logging it again separately would be redundant, not a safety net against a scenario that can't happen. (This reasoning would need revisiting only if ollacrm's model ever changes to allow reassigning an *existing* client to a different database.)
- **[Q8] → `client_name` can't become a real index label on either backend, by design, not by missing config — but it doesn't need to, because both backends already handle this well via structured metadata, confirmed by direct testing, not documentation alone.**

  Tested directly against both real backends: a throwaway script (bypassing sovdev-logger entirely, using `@opentelemetry/sdk-logs` directly, since no public API for a custom log attribute exists yet) emitted one log with `client_name` as a log-record attribute to each backend, then queried each one's real Loki API. (The test also included a second `dataset` attribute before that field was dropped per Q7 above — the finding below applies identically to a single attribute.)

  - `GET /loki/api/v1/labels` on **both** Grafana Cloud and UIS returned only `service_name` and `deployment_environment` (plus `pod`/`stream` on UIS) — **`client_name` is not a registered label name on either backend.** This isn't a missing config option to fix: per Grafana Labs' own docs and confirmed by three real GitHub issues on exactly this confusion ([#13440](https://github.com/grafana/loki/issues/13440), [#13044](https://github.com/grafana/loki/issues/13044), [#15927](https://github.com/grafana/loki/issues/15927)), Loki's `otlp_config`/`default_resource_attributes_as_index_labels` mechanism can **only** promote **resource-level** attributes to index labels — log-record attributes (which is what `client_name` structurally has to be, since it varies per request within one static process) can only ever become **structured metadata**, never a true label, on any Loki version, self-hosted or Cloud.
  - Both backends **do** already store it as structured metadata with zero config changes needed — UIS has `allow_structured_metadata: true` already set (confirmed directly in its `loki` configmap), and Grafana Cloud showed the identical behavior with no config access on our side at all.
  - Structured metadata **is** efficiently queryable, confirmed via LogQL's label-filter syntax: `{service_name="X"} | client_name="olla"` returned the match on both backends, with the response's own stats confirming `queryReferencedStructuredMetadata: true` (the real, purpose-built path — not a full-body regex scan).
  - **Fleet-wide search — ollacrm's actual stated goal — works, confirmed directly**: `{service_name=~".+"} | client_name="q8-test-client"` (a wildcard stream selector, since the API doesn't need to be known ahead of time) found the match on both Grafana Cloud and UIS.
  - **The honest remaining caveat**: this is architecturally different from a true label, not just cosmetically. A true label lets Loki's index skip non-matching streams before scanning even starts; a wildcarded selector + structured-metadata filter has to touch every stream/chunk within the time+selector scope first, then filter within each. At the small scale tested here (order of 100s of log lines) both forms of query were fast (single-digit to low-double-digit milliseconds) — at real "hundreds of APIs" production volume over longer query windows, the wildcard-scan approach is very likely to cost meaningfully more than a true label lookup would, though it isn't broken. This is a real, structural limit of Loki's OTLP ingestion model, not something a future PLAN can configure its way around.
  - **Consequence for Q11 (label cardinality)**: since `client_name` will never be an index label at all, it carries **zero** label-cardinality cost — cardinality/cost concerns only apply to true index labels (each unique value creates a new stream). Q11 is resolved as moot, not just deferred.
- **[Q9] → Optional/additive.** Defaults to absent. Only APIs shaped like ollacrm (multiple registered frontends per process) need to call the new context-setting function at all; every other existing integrator's code is unaffected.
- **[Q4] → Moot.** ollacrm is the only current consumer of `@terchris/sovdev-logger` — there's nothing to break. Backward-compatibility/versioning concerns don't constrain this design at all; whatever shape is cleanest can ship without needing an additive-only or major-version-bump framing.
- **[Q3] → No override — context is the only source, `sovdev_log()` gains no new parameters for this.** Considered allowing a per-call override (extra optional arguments to `sovdev_log()` that override the ambient `client_name` for just that one line), but no concrete need for it surfaced — every log line within a request genuinely belongs to that request's one client, with no known case of a single line needing to claim a different one. Keeping `sovdev_log()`'s signature untouched also avoids reintroducing the per-call-passing friction this whole feature exists to eliminate.
- **[Q10] → Out of scope for sovdev-logger.** Client registration (name ↔ API key) stays entirely ollacrm's own application logic; sovdev-logger only ever receives the already-resolved `client_name` string via the new context-setting call, and knows nothing about keys, registrations, or how the mapping works. Every organization would have a different registration scheme (a database table, a config file, a secrets manager) — a built-in registry in the library would fit almost nobody well, and nobody has asked for one. The library stays a logging tool, not an identity/auth tool.
- **[Q12] → Already satisfied by construction, nothing to trade off.** `client_name` is emitted as a plain OTLP log-record attribute with no Loki-specific construct anywhere in the mechanism, and `AsyncLocalStorage` itself has no backend awareness at all — this was true the moment Q1/Q7/Q8 were decided, not an extra design constraint that cost anything. The one open item is unrelated to this investigation: Azure Monitor's/Cloud Logging's actual query behavior for this same attribute is still unverified, tracked in `INVESTIGATE-external-backend-verification.md` for when that integration is actually built.

---

## Current State

- **`AsyncLocalStorage` is already used internally**, just not exposed: `src/logger.ts:24` imports it, `src/logger.ts:54` instantiates `spanStorage = new AsyncLocalStorage<Span>()`, used at `src/logger.ts:1591`/`1656` to correlate spans across async call chains. The precedent and the pattern already exist in this codebase — this isn't introducing something foreign.
- **No `sovdev_set_context` or equivalent exists.** `sovdev_log()`'s signature (`src/logger.ts` — see `sovdev_log` export) requires every field explicit on every call, exactly as the issue describes.
- **`@opentelemetry/api`'s `context` is imported but unused**: `src/logger.ts:37` imports `context` from `@opentelemetry/api` alongside `trace`, `Span`, `SpanStatusCode` — but nothing in `src/` calls `context.active()` or `context.with()`. No `propagation`/`baggage` module is imported anywhere.
- **No explicit context manager or propagator is configured.** The `NodeSDK` instantiation (`src/logger.ts:869-880`) only sets `resource` and `instrumentations` — no `contextManager` or `textMapPropagator` option is passed. Whether the SDK's default context manager already happens to be async-context-aware needs to be verified directly (not assumed) before committing to an approach that relies on it.
- **`sovdev_generate_trace_id` does not exist anywhere in `src/`** — confirmed by grep, not just unexported. `README.md`'s "Using traceId to Link Operations" section documents and calls it as if it were real. This is pure documentation drift, not a partially-shipped feature.
- **`sovdev_start_span`/`sovdev_end_span` already exist, return real spans, and already auto-correlate logs** — confirmed directly in `write_log()` (`logger.ts:505-524`): it reads the active span from `spanStorage` and stamps `trace_id`/`span_id` onto every `sovdev_log()` call made while that span is active, automatically, with no extra argument needed per call. This is not a partial workaround — it's a complete, superior replacement for what the README's `sovdev_generate_trace_id` workflow describes (which would require passing a trace ID as an explicit argument on every single call). The E2E example even comments on this directly: "trace_id and span_id are automatically extracted from active span!" (`company-lookup.ts:171-173` etc.).
- Installed `@opentelemetry/api` is `^1.9.0` (`typescript/package.json:47`) — current npm latest is `1.9.1`, so this dependency isn't a blocker either way; `context`/`propagation`/`baggage` are all available today without any version bump.

---

## Options

**Decided: Option A** (see Decisions Resolved above). Options B/C kept below for the record — the tradeoffs that ruled them out for now would need revisiting if a future integrator's API *does* need this context to survive an outbound call to another service.

### Option A: Bespoke `sovdev_set_context()`, a second dedicated `AsyncLocalStorage` instance

Parallel to the existing `spanStorage`, add a `logContextStorage = new AsyncLocalStorage<Record<string, unknown>>()`. `sovdev_set_context({...})` wraps the rest of the request in `.run()`; `sovdev_log()` reads the active store and merges it into the emitted log.

**Pros:**
- Full control over field shape/naming and how it merges into `sovdev_log`'s output.
- Doesn't require the integrator to touch `@opentelemetry/api` directly — a `sovdev_`-prefixed one-liner, consistent with the rest of the library's ergonomics.
- Small, self-contained change — mirrors a pattern (`spanStorage`) already proven in this exact file.

**Cons:**
- Reinvents something OTel's own `context`/Baggage API already solves.
- If a value ever needs to survive a network hop between services (the issue explicitly flags W3C Baggage as a "not our immediate need, but worth being extensible toward" concern), a bespoke `AsyncLocalStorage` can't do that without separately implementing wire-format propagation from scratch.

### Option B: Use OTel's own `context`/`baggage` API directly

`sovdev_log()` reads `propagation.getBaggage(context.active())` and merges any baggage entries into the emitted log. Integrators set values via the standard `propagation.setBaggage()`/`context.with()` calls, not a `sovdev_`-owned function.

**Pros:**
- Standard API, no new surface for this library to own or document independently.
- W3C Baggage propagation across a network hop comes for free — the baggage propagator handles the wire format, satisfying the issue's forward-looking ask without extra work.
- `@opentelemetry/api` is already a dependency; no new one needed.

**Cons:**
- Per the W3C Baggage spec, values are strings attached to *every* outgoing telemetry item (spans included), which may be more invasive than an integrator wants for a field meant only for logs.
- Requires integrators to learn the OTel context/baggage API surface directly — a higher bar than a one-line `sovdev_set_context({...})` call, and inconsistent with the library's stated goal of a simple, opinionated wrapper.
- Would need an explicit propagator/context-manager configured on the `NodeSDK` (currently absent, per Current State) to guarantee it survives async boundaries — not just "already there for free".

### Option C: Hybrid — `sovdev_set_context()` as a thin wrapper over OTel's `context` (not Baggage)

Use `@opentelemetry/api`'s `context.active()`/`context.with()` with a library-owned context key (not the Baggage API, so no automatic cross-process propagation yet — matching the issue's own framing that this isn't the immediate need). `sovdev_set_context({...})` stores a plain object on this key; `sovdev_log()` reads and merges it.

**Pros:**
- Matches the issue's concrete ask almost exactly (a simple `sovdev_set_context({...})` call).
- Built on the standard OTel context primitive rather than a second bespoke `AsyncLocalStorage` instance — if cross-process propagation is wanted later, migrating this one key onto Baggage is a smaller step than migrating off a wholly separate mechanism.
- Consistent with how `spanStorage` already piggybacks on async context propagation, but consolidates on the OTel-native primitive going forward instead of adding a second parallel one.

**Cons:**
- Still a `sovdev_`-specific key layered on OTel context, not literally "use OTel's own Baggage" — a purist might call this "our own mechanism wearing a standard API's clothes."
- Same open verification need as Option B: does the SDK's context manager already propagate correctly across the async boundaries this library's callers use (HTTP handlers, `async`/`await` chains), or does `NodeSDK` need an explicit `contextManager` configured first?

---

## `sovdev_generate_trace_id` — resolved: remove it

~~**[Q5]**~~ **Resolved → [Q5a], remove from the README.** Verified directly (not assumed) that this isn't a partial gap to fill in — `sovdev_start_span()`/`sovdev_log()`/`sovdev_end_span()` already give the exact outcome the README's `sovdev_generate_trace_id` workflow promises, automatically and with less code: every `sovdev_log()` call made while a span is active gets that span's real `trace_id`/`span_id` stamped on with zero extra arguments, confirmed in `write_log()` (`logger.ts:505-524`) and demonstrated in the E2E example. The README's documented (but never-built) workflow would have required manually generating an ID and passing it as an explicit extra argument on *every* `sovdev_log()` call in the chain — objectively worse than what already ships. No concrete need surfaced (from ollacrm or otherwise) for trace correlation *without* a span's start/end lifecycle, so [Q5b]/[Q5c] (building a new standalone generator, or folding one into the new context mechanism) would be shipping a feature to solve an already-solved problem. Just delete the README section and, ideally, add a line pointing readers to `sovdev_start_span`/`sovdev_end_span` instead.

---

## Recommendation

All twelve questions are now decided — see Decisions Resolved above. Nothing blocks moving to a `PLAN-*.md`: the mechanism, field, query behavior, scope boundary, and multi-backend posture are all settled, and both implemented backends (Grafana Cloud, UIS) are confirmed, by direct testing, to already support the intended usage today with zero infra config changes.

---

## Next Steps

- [x] Decide mechanism (**[Q1]** → Option A), the field (**[Q7]** → `client_name` only, one field not two), required-vs-optional (**[Q9]** → optional), how it's queried (**[Q8]** → structured metadata, confirmed working on both backends; **[Q11]** → moot), override behavior (**[Q3]** → none, context is the only source), breaking-change framing (**[Q4]** → moot, ollacrm is the only consumer), client-registration scope (**[Q10]** → out of scope for the library), backend-agnostic posture (**[Q12]** → already satisfied), and `sovdev_generate_trace_id` (**[Q2]**/**[Q5]** → remove from the README, point to spans instead)
- [ ] Create `PLAN-context-propagation.md` with the chosen approach — should include: the README deletion for `sovdev_generate_trace_id`, and a short doc note for ollacrm (and future adopters) on the actual query syntax: `{service_name="x"} | client_name="y"` (known service) or `{service_name=~".+"} | client_name="y"` (fleet-wide), not a label selector
