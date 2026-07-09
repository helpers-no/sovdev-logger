# Fix real telemetry silently failing to reach Grafana Cloud despite a clean SDK flush

Fixes an unquoted `.env` value that caused bash's `source` to truncate the Grafana Cloud OTLP auth header to nothing, plus a related tooling bug that had been masking the truncation's real symptom as "data missing," not "auth failing."

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Completed

**Investigation**: [INVESTIGATE-grafana-cloud-otlp-data-loss.md](INVESTIGATE-grafana-cloud-otlp-data-loss.md) — root-cause diagnosis, including the debunked protobuf-vs-JSON hypothesis and the evidence trail that led to the real cause.

**Goal**: Find out why real application telemetry (as opposed to hand-built diagnostic payloads) never showed up as queryable data in Grafana Cloud despite the SDK reporting a clean flush, and fix it.

**Completed**: 2026-07-10

---

## Problem Summary

After Phase 1 of `PLAN-fix-otlp-headers-spec-compliance.md` (still `active/`, not yet completed) fixed the `OTEL_EXPORTER_OTLP_HEADERS` format bug, the TypeScript E2E test flushed cleanly against Grafana Cloud with no thrown errors — but none of the real app's logs, traces, or metrics could be found via `query-loki.ts`/`query-tempo.ts`/`query-prometheus.ts`, while a trivial hand-built diagnostic payload sent to the same endpoints landed fine. The SDK gave no signal that anything was wrong: it captures the raw HTTP response on any 2xx-looking flush but never inspects or logs `partialSuccess`/rejection info, and a genuine 401 auth failure was, in this case, swallowed the same way.

## Root Cause

`tools/validation/grafana/generate-e2e-env.ts` wrote `OTEL_EXPORTER_OTLP_HEADERS=Authorization=Basic ${authHeader}` **unquoted** into the generated `.env.grafana-cloud` file. The value contains a space (`Basic <token>`). `run-test.sh` loads env files via bash's `source`, which word-splits unquoted values on spaces — everything after the space became a separate shell word and was silently dropped. Confirmed directly at runtime: `process.env.OTEL_EXPORTER_OTLP_HEADERS.length` was `19` (exactly `"Authorization=Basic"`, no token) instead of the real ~244 characters.

This produced Grafana Cloud's OTLP gateway returning HTTP `401` with body `{"status":"error","error":"authentication error: no credentials provided"}` — a different, more specific message than "invalid credentials," and the key clue that no Authorization header reached the request at all. It was invisible through normal test output because the OTel SDK's HTTP transport never logs the response body it captures.

This is the same root-cause *class* as the bug fixed in `PLAN-fix-otlp-headers-spec-compliance.md` Phase 1 — an unquoted `.env` value containing a character bash's `source` treats specially (there, embedded `"` in JSON; here, a plain space) — just triggered by a different character, and in a different file (tooling-generated `.env.grafana-cloud`, not the library itself).

A first hypothesis (protobuf vs. JSON encoding) was tested and ruled out before the real cause was found — see Phase 1 below.

---

## Phase 1: Rule out protobuf vs. JSON — DONE

### Tasks

- [x] 1.1 Set `OTEL_EXPORTER_OTLP_PROTOCOL=http/json` and re-ran the E2E test against Grafana Cloud — no change in behavior
- [x] 1.2 Grepped the installed `@opentelemetry/exporter-logs-otlp-http` and `@opentelemetry/exporter-trace-otlp-http` package source for any reference to `OTEL_EXPORTER_OTLP_PROTOCOL` — zero matches; both packages hardcode `JsonLogsSerializer`/`JsonTraceSerializer` and `Content-Type: application/json` regardless of this env var
- [x] 1.3 Concluded the hypothesis was invalid — encoding was always JSON, both before and after the "test," so it was never the differentiator

### Validation

Confirmed via direct package source inspection, not just behavioral inference — the env var this hypothesis rested on is never read by the exporter classes in use.

---

## Phase 2: Find the real cause — DONE

### Tasks

- [x] 2.1 Monkey-patched `https.request` via `NODE_OPTIONS='--require <script>'` to capture the actual OTLP gateway response body, since the SDK never logs it
- [x] 2.2 Captured the real response: `401` — `{"status":"error","error":"authentication error: no credentials provided"}`
- [x] 2.3 Checked `process.env.OTEL_EXPORTER_OTLP_HEADERS.length` at runtime inside the test process — found `19`, not the expected ~244
- [x] 2.4 Traced the truncation to `generate-e2e-env.ts` writing the header value unquoted, with bash's `source` word-splitting on the embedded space

### Validation

Reproduced the exact truncation length (`19 === "Authorization=Basic".length`) confirming the mechanism, not just the symptom.

---

## Phase 3: Fix and verify — DONE

### Tasks

- [x] 3.1 Quoted the generated value in `tools/validation/grafana/generate-e2e-env.ts`: `OTEL_EXPORTER_OTLP_HEADERS="Authorization=Basic ${authHeader}"`
- [x] 3.2 Applied the same fix directly to the already-generated `typescript/test/e2e/company-lookup/.env.grafana-cloud` (gitignored, personal, not regenerated automatically)
- [x] 3.3 Found and fixed an unrelated bug hit while re-verifying: `tools/validation/grafana/query-loki.ts` never ported `query-loki.sh`'s auto-limit-increase for `--compare-with` mode, so the default `--limit 10` silently capped results below the real 17-entry count and misreported genuine matches as "missing." Fixed by adding the same `fileEntryCount + 10` auto-calculation the bash original had.
- [x] 3.4 Re-ran the full TypeScript E2E test against Grafana Cloud, then all three query tools with `--compare-with` against the real test output

### Validation

```
bash run-test.sh --skip-validation --env-file .env.grafana-cloud
npx tsx query-loki.ts --compare-with <log file>
npx tsx query-tempo.ts --compare-with <trace file>
npx tsx query-prometheus.ts --compare-with <metrics file>
```

Result: clean flush (no auth errors), **Loki 17/17**, **Tempo 4/4** (after one retry for ingestion delay), **Prometheus 5/5** — exact match against real E2E test output on all three signals.

---

## Acceptance Criteria

- [x] Root cause identified and confirmed with direct evidence (not inferred from behavior alone)
- [x] Protobuf-vs-JSON hypothesis explicitly ruled out and documented, so it isn't re-investigated later
- [x] Fix applied at the source (`generate-e2e-env.ts`) so regenerating `.env.grafana-cloud` from scratch produces a correct file
- [x] `query-loki.ts` auto-limit bug fixed as a side effect of re-verification
- [x] Full end-to-end verification passes on all three signals (Loki, Tempo, Prometheus) against real application telemetry, not just hand-built diagnostic payloads
- [x] `INVESTIGATE-grafana-cloud-validator.md`'s remaining ingestion-verification step is closed out by this result (lives on the `feat/grafana-cloud-validation` branch, not yet merged — plain-text reference, not a link, until the branches merge)

---

## Implementation Notes

- The diagnostic technique that found this (`NODE_OPTIONS='--require <script>'` monkey-patching `https.request`) is worth keeping in mind for future "SDK says success but data isn't there" mysteries — the OTel JS SDK's HTTP transport captures but never surfaces the raw response body anywhere in normal operation.
- General lesson beyond this specific env var: **any `.env` value containing a space needs quoting** when loaded via bash `source`. This bit the same variable twice for two different reasons (embedded `"` in Phase 1 of the headers plan, then a plain space here) — it's ordinary shell quoting hygiene, not something specific to OTLP headers.

## Files Modified

- `tools/validation/grafana/generate-e2e-env.ts` (on `feat/grafana-cloud-validation`)
- `typescript/test/e2e/company-lookup/.env.grafana-cloud` (gitignored, not committed)
- `tools/validation/grafana/query-loki.ts` (on `feat/grafana-cloud-validation`)
- `website/docs/ai-developer/plans/completed/INVESTIGATE-grafana-cloud-otlp-data-loss.md` (rewritten to document the resolution, moved from `backlog/`)
