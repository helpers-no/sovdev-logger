---
title: "Logging conventions — how ollacrm uses sovdev-logger"
sidebar_label: "Logging conventions"
sidebar_position: 2
description: "A real production consumer's usage patterns on top of sovdev-logger — which fields go where, log-level semantics, and where logging happens by layer."
---

# Logging conventions — how ollacrm uses sovdev-logger

This is **one real consumer's own convention**, not a rule sovdev-logger enforces — shared because it's a concrete, production-tested example of the patterns a downstream project settles into, useful for anyone integrating the library into a similarly-shaped service. Written by the ollacrm team, from [GitHub issue #27](https://github.com/helpers-no/sovdev-logger/issues/27); bug/gap feedback from the same integration lives separately in [issue #26](https://github.com/helpers-no/sovdev-logger/issues/26), tracked in [`INVESTIGATE-issue26-ollacrm-feedback.md`](../../../ai-developer/plans/backlog/INVESTIGATE-issue26-ollacrm-feedback.md).

Which fields go where, what `peer_service`/`function_name` mean in practice, log-level semantics, the no-PHI rule, and when to log vs. span.

## The record shape

Every `sovdev_log()` call produces one record. Fields come from three places.

### Automatic — the library sets these

| Field | Value | Source |
|---|---|---|
| `timestamp`, `event_id`, `trace_id` | per call | library |
| `span_id` | only inside a `sovdev_start_span`/`end_span` pair | library |
| `service_name` | `ollacrm-api` | `sovdev_initialize(SERVICE_NAME, ...)` — reads `OTEL_SERVICE_NAME` env, falls back to `"ollacrm-api"` |
| `service_version` | deployed app version | `process.env.APP_VERSION ?? "dev"` |

### Request-scoped context — set once per request

`sovdev_set_context()`, called right after the JWT resolves. Inherited by every `sovdev_log()` call made afterward in that request, via `AsyncLocalStorage` — no call site passes these explicitly.

| Field | ollacrm's value | Resolved from |
|---|---|---|
| `client_name` | `"olla-web"` / `"olla-cli"` / `"gcloud-dev"` / `"unknown-client"` | the JWT's `aud` claim → an `AUDIENCE_CLIENT_NAMES` map — *which registered OAuth client* issued the token, not a static service-name echo |
| `service_principal` | `"ollacrm-sheets-dwd"` | fixed constant — the domain-wide-delegation mechanism every Sheets/Drive call uses, not a per-request value |
| `acting_user` | the signed-in user's email | the JWT `email` — the same identity as the per-call `actorEmail` field below |

Not set on the `/internal/*` scheduler path — the 10-min processor's own logs carry no request context today (a known, open gap on ollacrm's side).

**Live-verified** against real production infrastructure, not just typechecked: a real `contacts list` request logged `acting_user: "<user>@1strevenue.com"`, `client_name: "gcloud-dev"`, `service_principal: "ollacrm-sheets-dwd"` on every subsequent HTTP call, confirmed in both the local file log and a direct Grafana Cloud Loki query.

### Per-call — what each `sovdev_log(...)` site passes explicitly

| Field | Convention |
|---|---|
| `level` | `INFO` (success/normal), `WARN` (a routine, non-paging failure — a 500 response, a push-delivery give-up), `ERROR` (a real failed operation worth surfacing distinctly — a calendar write failure), `DEBUG` (the *why* behind a decision, where INFO/WARN/ERROR already log the *what* — a cache hit, which matcher layer fired), `TRACE` (step-by-step flow, finer than DEBUG — a retry attempt number, which enrichment phase is running). **ERROR/FATAL open real ServiceNow incidents on a shared instance** — the reason WARN is the default for routine failures. **`FATAL` isn't literally reachable via `sovdev_log`** in ollacrm's one genuine FATAL case (a boot-time `sovdev_initialize()` failure); `console.error`+`process.exit` covers it (see startup self-check below). **`TRACE` is currently indistinguishable from `DEBUG`** once it reaches Grafana (`severity_number: 5`, DEBUG's number) — tracked as a confirmed bug in `INVESTIGATE-issue26-ollacrm-feedback.md`. |
| `function_name` | The JS function's own name (`"generate"`, `"problem"`), or dot-namespaced when one function holds multiple distinct operations (`"enrichPending.aliasSelfHeal"`) — the single authoritative "what happened" field, filterable in Grafana. |
| `message` | Written for the on-call engineer at 7pm Friday who's never seen this codebase — plain, specific, stands alone. |
| `peer_service` | Which external dependency this call concerns, from a `PEER_SERVICES` map: `SHEETS`, `DRIVE`, `CALENDAR`, `VERTEX_AI`, `ADMIN_DIRECTORY`, or `INTERNAL` (no external dependency — a business-action log, a job-status line, an HTTP failure). |
| `input_json` | Structured request-shaped context: `entityKind`+`entityId`, `actorEmail` (per-call echo of the same identity `acting_user` now carries ambiently). |
| `response_json` | Structured result-shaped context: `outcome` (`"success"` \| `"skipped"` \| `"failed"` — a small fixed vocabulary, directly filterable, correlated with but independent of `level`), `reason` (only when `outcome: "skipped"` — a short fixed code like `"no-unique-org"`, never free text), or call-specific data like a Gemini call's `promptTokens`/`responseTokens`/`totalTokens` (from `usageMetadata`). |
| `exception_object` | A real `Error`, when one exists — auto-populates `exception_type`/`message`/`stacktrace`. Used instead of a `reason` string for genuine exceptions, never both. |

### Startup self-check

`sovdev_validate_config()` is called once, before `sovdev_initialize()`, via `console.warn` (not `sovdev_log`) — the logger genuinely isn't initialized yet (`sovdev_log` throws `"not initialized"` if called before `sovdev_initialize()` succeeds). A missing/malformed OTLP var only warns — `sovdev_initialize()` gracefully falls back to defaults for merely-missing config, doesn't throw (the app boots fine with a warning). If `sovdev_initialize()` itself throws (a real internal SDK failure), ollacrm does `console.error` then `process.exit(1)` — a deliberate clean shutdown, since every one of its ~90 `sovdev_log` call sites assumes init succeeded.

### The one hard rule, every field

**Never**: names, titles, notes, or any care-content string in `message`, `input_json`, or `response_json`. Prefer event names, IDs (opaque ULIDs), status, counts, durations. `acting_user`/`actorEmail` is the one deliberate exception — it's the user ID (who did it), not content (what it's about).

## Where logging happens, by layer

The pattern each layer follows (≈90 call sites), so a new call site knows which to match.

| Layer | Pattern |
|---|---|
| `problem.ts` | One system-wide WARN for every 5xx response, across all handlers — no per-handler error log on top. `peer_service: INTERNAL`. |
| handlers (business actions) | One INFO on success per write operation (create/update/merge/delete/confirm/reject) — 48 operations across 14 files. No per-handler error log (covered by `problem.ts`). |
| AI wrapper (`vertex.ts`) | One `generate()` choke point wraps all 9 AI functions — INFO before (prompt size), DEBUG for response schema (never prompt content), TRACE per retry, INFO/ERROR after (duration, token counts). Every AI call site inherits this. |
| `ask.ts` | The whole handler wrapped in one `sovdev_start_span("askQuestion")`/`end_span` — real end-to-end duration; live-verified every log line in a request shared one `span_id`/`trace_id`. |
| processor (`process.ts`) | `sovdev_log_job_status` (Started/Completed) + `sovdev_log_job_progress` per item + `sovdev_start_span`/`end_span` around each item. |
| `enrich.ts` | Reconciliation/matching decisions each INFO/WARN with `outcome`/`reason`; DEBUG on a match only (which layer fired); TRACE per document-enrichment phase boundary. |
| adapters (`sheets`/`drive`/`calendar`/`notify`) | A per-adapter HTTP choke point: INFO before/after, ERROR on failure, `peer_service` = the dependency. Labels are opaque ids/fixed strings, never filenames/titles. |
| read-only/static handlers | Zero direct calls, correctly. |

## See also

- [Onboarding ollacrm](index.md) — the setup checklist this convention builds on top of
- [TypeScript README](https://github.com/helpers-no/sovdev-logger/blob/main/typescript/README.md) — the library's own API reference
