# Investigate: Terminology review — field names and dashboard panel titles

Reviews every schema field name and every dashboard panel title for clarity and accuracy, triggered by finding the dashboard's "Active Integrations" panel actually counts distinct `service_name` values, not integrations — and the maintainer asking to look hard at every term, not just that one.

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Backlog

**Goal**: Decide which of the found terminology issues (dashboard-only, low-risk; and schema-field-level, real but currently low-cost to fix) are worth changing, and how.

**Last Updated**: 2026-07-13

---

## Source

Triggered mid-session, right after shipping `PLAN-context-propagation.md`: the maintainer asked about the operator dashboard panel idea, which surfaced that "Active Integrations" (a panel counting distinct `service_name` values) is a misleading name — "integration" more naturally suggests an external connection (`peer_service`), not "how many of our own services are reporting." Asked whether to review just the dashboard's terms or the whole field-naming vocabulary too — the maintainer chose **the whole vocabulary**.

**Scope note**: schema field names are shipped and cross-language (`log-entry-schema.json` generates Python's `field_names.py` via codegen; TypeScript uses matching literals by convention). Renaming one is a breaking change in principle — but per `PLAN-context-propagation.md`'s own Q4, **ollacrm is still the only consumer of `sovdev-logger` today**, which is exactly why that plan felt free to make additive/shape decisions without versioning gymnastics. The same reasoning applies here: this is close to the cheapest point in the project's life to rename a field, before more consumers exist to break.

---

## Current State: full inventory

### Schema fields (`tools/validation/schemas/log-entry-schema.json`)

| Field | Description (from schema) | Note |
|---|---|---|
| `timestamp` | ISO 8601 timestamp | — |
| `level` | Log level | — |
| `message` | Human-readable message | — |
| `service_name` | Service identifier | Matches OTel's `service.name` semantic convention |
| `service_version` | Service version | Matches OTel's `service.version` |
| `peer_service` | Peer service identifier | Matches OTel's own `peer.service` semantic convention exactly |
| `client_name` | Calling client/frontend identifier | Added in `PLAN-context-propagation.md`; deliberately not "environment"/"dataset" per that investigation |
| `session_id` | Session identifier (UUID v4), "primarily used in OTLP export" | **See [Q2]** — this is a process-instance identifier, not a user/auth session |
| `function_name` | Function/method name | — |
| `log_type` | `transaction` / `job.status` / `job.progress` | **See [Q4]** — mixed dot/non-dot convention within one enum |
| `trace_id` | "OpenTelemetry trace identifier... extracted from OTEL span context" | **See [Q3]** — not always true; see Current State below |
| `span_id` | OpenTelemetry span identifier | Only present when a real span is active — correctly optional, no issue |
| `event_id` | Unique per-entry identifier | — |
| `input_json` | Input parameters | **See [Q5]** — paired asymmetrically with `response_json` |
| `response_json` | Response data | **See [Q5]** |
| `exception_type` / `exception_message` / `exception_stacktrace` | Exception fields | Consistent family, no issue |

### Dashboard panel titles (`tools/dashboards/sovdev-logger-overview.json`)

| Title | Query | Note |
|---|---|---|
| **Active Integrations** | `count(count by (service_name) (sovdev_operations_total{...}))` | **See [Q1]** — counts distinct services, not integrations |
| Total Operations (cumulative) | `sum by (service_name, peer_service) (sovdev_operations_total{...})` | Clear |
| Error Rate (cumulative) | ratio of the above two | Clear |
| Average Operation Duration (cumulative) | duration sum/count | Clear |
| Job Lifecycle (Status + Progress) | `log_type=~"job.status\|job.progress"` | Clear |
| Recent Traces | Tempo table | Clear |
| Recent Errors (Detailed Logs from Loki) | `exception_type!="" \| log_type="transaction"` | **See [Q7]** — title-suffix style inconsistent with the next panel |
| Transaction Logs (Full Detail from Loki) | `log_type="transaction"` | **See [Q7]** |
| "Client" column (Recent Errors table) | `client_name` via `extractFields` | Added this session, no issue found |

---

## Questions to Answer

1. **[Q1]** `"Active Integrations"` counts distinct `service_name` values with the metric present — i.e. "how many APIs are actively logging." "Integration" more naturally reads as "an external system we're connected to" (which is what `peer_service` actually represents). Rename to something like `"Active Services"` or `"Services Logging"`? This directly matters for the still-open operator-dashboard idea too — if we ship a *second* "how many distinct X" panel (for `client_name`) alongside a confusingly-named first one, the confusion compounds.

2. **[Q2]** `session_id` is a UUID generated once per process at `sovdev_initialize()`, stored as an OTel Resource attribute, whose actual purpose ("session grouping for execution tracking") is exactly what OpenTelemetry's own `service.instance.id` semantic convention is *for* — confirmed directly: `logger.ts` sets it as a plain custom `session_id` resource key, never using the `ATTR_SERVICE_INSTANCE_ID` semantic-convention constant that already exists in `@opentelemetry/semantic-conventions` (the same package `service_name`/`service_version`/`peer_service` already pull their standard constants from). "Session" also risks reading as a *user* or *auth* session to anyone coming from a web-app background, which this field has nothing to do with. Rename to `instance_id` (or adopt the OTel convention's own field name/attribute directly)?

3. **[Q3]** `trace_id` is documented as "extracted from OTEL span context for proper distributed tracing" — true only when a span is active. Confirmed directly: `create_log_entry()` always generates a random fallback (`temp_trace_id = uuidv4().replace(/-/g, '')`) first, and `write_log()` only overwrites it with the *real* span-derived trace ID if an active, non-ended span exists at that moment. Both forms are syntactically identical (32-char hex) — there's no way to tell, from the log entry alone, whether a given `trace_id` value is a real distributed-tracing correlator or a random per-entry ID with no correlation meaning at all. This isn't really a *naming* problem the way the others are (the name `trace_id` is fine either way) — it's a **trustworthiness** problem: the field can silently mean two different things. Worth its own decision: document this limitation prominently, or find a way to signal which kind a given entry has (e.g., only emit `trace_id` at all when a real span is active, leaving it absent otherwise, the same way `span_id` already works)?

4. **[Q4]** `log_type`'s enum mixes `"transaction"` (no dot) with `"job.status"`/`"job.progress"` (dot-separated) — confirmed directly in the schema. The project's own stated convention is snake_case, no dots, for *field names* — this inconsistency is in enum *values*, a different but adjacent inconsistency worth normalizing (e.g. `"transaction"`, `"job_status"`, `"job_progress"`, or the reverse — `"transaction"` becomes `"log.transaction"` to match the dotted style). Either direction is defensible; leaving it mixed is the one option that isn't.

5. **[Q5]** `input_json` pairs with `response_json` — an asymmetric naming pair (input↔response, not input↔output, nor request↔response). Rename one side for symmetry — `input_json`/`output_json`, or `request_json`/`response_json`?

6. **[Q6]** Given schema renames are effectively free right now (one consumer, per `PLAN-context-propagation.md`'s Q4 precedent) but won't stay free forever, should any confirmed renames from Q2/Q4/Q5 happen **now**, as their own small plan, rather than risk revisiting this once there's a second real consumer and every rename becomes a breaking-change negotiation?

7. **[Q7]** `"Recent Errors (Detailed Logs from Loki)"` vs `"Transaction Logs (Full Detail from Loki)"` — two adjacent panels showing the same kind of thing (a Loki log table) with differently-structured title suffixes ("Detailed Logs from Loki" vs "Full Detail from Loki"). Minor, but worth a consistent pattern — e.g. both as `"... (Loki)"`, or both keeping a fuller descriptive suffix, just the *same* one.

---

## Recommendation

**[Q1]** (dashboard rename) and **[Q7]** (panel title consistency) are low-risk, dashboard-JSON-only changes — no schema, no cross-language impact, no codegen involved. These can be decided and shipped quickly.

**[Q2]** (`session_id` → align with OTel's `service.instance.id`) has the strongest case of the schema-level findings: it's not just a clarity nice-to-have, it directly follows the pattern this project's *own* other fields already set (`service_name`/`service_version`/`peer_service` all deliberately mirror real OTel semantic conventions; `session_id` is the one field that reinvents instead of adopting). Worth doing while it's cheap.

**[Q3]** (`trace_id`'s dual meaning) is the most substantive finding but isn't really a naming fix — it's a design question about whether a fallback, non-correlating value should even be emitted under the same field name as a real one. Recommend treating this as its own decision, potentially deferred, rather than bundling it into a same-day rename batch with Q2/Q4/Q5.

**[Q4]** (`log_type` enum consistency) and **[Q5]** (`input_json`/`response_json` symmetry) are real but cosmetic — worth fixing alongside Q2 if a rename batch happens at all, not urgent enough to justify one on their own.

**[Q6]** is the real gating decision: does the maintainer want to act on any of this now (bundled into one small schema-rename plan, while it's cheap), or defer all of it and accept schema renames become more expensive later?

---

## Next Steps

- [ ] Maintainer decides Q1 (rename "Active Integrations") and Q7 (panel title consistency) — likely quick, no schema impact
- [ ] Maintainer decides Q2 (`session_id` → OTel-aligned name), Q4 (`log_type` enum consistency), Q5 (`input_json`/`response_json` symmetry) — schema-level, cross-language, currently cheap
- [ ] Maintainer decides Q3 (`trace_id`'s dual meaning) — a design question, not a naming one; may warrant its own separate investigation rather than folding into this one
- [ ] Create `PLAN-terminology-cleanup.md` (or similarly scoped, possibly split into a dashboard-only plan and a schema-rename plan) with whichever items are approved
