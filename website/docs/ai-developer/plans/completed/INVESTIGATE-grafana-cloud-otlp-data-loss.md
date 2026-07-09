# Investigate: Real sovdev-logger telemetry produces zero queryable data in Grafana Cloud despite a clean flush

Found while verifying the OTLP-headers fix end-to-end against Grafana Cloud: the app reported a completely clean flush (no errors, no thrown exceptions) and authentication was confirmed working via direct probes, yet the real application's logs/traces/metrics never showed up as queryable data in Grafana Cloud — while a trivial, hand-built diagnostic payload sent to the same endpoints *did* land successfully. **Resolved** — title kept for history; the actual cause wasn't data loss on Grafana Cloud's side at all.

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Resolved — same bug class as the original header-format issue, triggered differently

**Child plan**: [PLAN-fix-grafana-cloud-otlp-data-loss.md](PLAN-fix-grafana-cloud-otlp-data-loss.md) — implements and verifies the fix documented below. (Note: the plan's own code changes live on the `feat/grafana-cloud-validation` branch, not yet merged; the plan document itself lives here on `fix/otlp-headers-spec-compliance`.)

**Goal**: Determine why the real OTel SDK export pipeline produced no queryable data in Grafana Cloud despite reporting success, and fix it.

**Last Updated**: 2026-07-10 — root cause found and fixed. Full end-to-end verification now passes: Loki 17/17, Tempo 4/4, Prometheus 5/5 exact-match against real E2E test output via `--compare-with`.

---

## Resolution

**The protobuf-vs-JSON hypothesis ([Q1]) was tested directly (Option A) and disproven.** Setting `OTEL_EXPORTER_OTLP_PROTOCOL=http/json` and re-running changed nothing. Checking the actual installed exporter packages explained why: `@opentelemetry/exporter-logs-otlp-http` and `@opentelemetry/exporter-trace-otlp-http` **hardcode JSON serialization** (`JsonLogsSerializer`/`JsonTraceSerializer`, `Content-Type: application/json`) and **never read `OTEL_EXPORTER_OTLP_HEADERS`-adjacent protocol env vars at all** — confirmed via direct grep of the installed source, zero references. The real exporter was sending JSON both before and after the test; nothing about encoding ever differed from the working `connectivity-test` payload.

**The actual cause**: after Phase 1 of the header-format fix removed the app's explicit `headers` config (relying on the OTel SDK's native env-var parsing instead — see `INVESTIGATE-otlp-headers-standard-compliance.md`), the generated `.env.grafana-cloud` file wrote `OTEL_EXPORTER_OTLP_HEADERS=Authorization=Basic <token>` **unquoted**. That value contains a space (between `Basic` and the token). Bash's `source` — used by `run-test.sh` to load the env file — word-splits unquoted values on spaces, so everything after that space became a separate shell word and was silently dropped from the variable's actual value. Confirmed directly: `process.env.OTEL_EXPORTER_OTLP_HEADERS.length` was `19` (exactly `"Authorization=Basic"`, no token at all) instead of the real ~244 characters.

This produced a `401` with the message `"authentication error: no credentials provided"` — captured by monkey-patching `https.request` to log the actual response body (the OTel SDK captures the response but never logs or inspects it, so this was invisible without manual instrumentation). Critically, this is a **different message** from "invalid credentials" — it means no Authorization header reached the request at all, not that a bad one did. Once the earlier transient real `401` (bad/propagating token, resolved separately) was fixed, this second, distinct 401 was masked as "the same problem," until the actual response body was captured and read.

**The fix**: quote the header value wherever it's generated or hand-written — `generate-e2e-env.ts` now writes `OTEL_EXPORTER_OTLP_HEADERS="Authorization=Basic ${authHeader}"`. This is the *same root cause class* as the original JSON-quoting bug (`INVESTIGATE-otlp-headers-standard-compliance.md`) — an unquoted `.env` value containing a character bash's `source` treats specially (there, embedded `"` triggering word-splitting on the whole JSON; here, a plain space) — just triggered by a different character. The lesson generalizes: **any `.env` value containing a space needs quoting**, regardless of whether it's JSON, and this isn't specific to `OTEL_EXPORTER_OTLP_HEADERS` — it's ordinary shell quoting hygiene that happened to bite twice on the same variable for two different reasons.

**A second, unrelated bug found and fixed along the way**: `query-loki.ts` never ported `query-loki.sh`'s auto-limit-increase for `--compare-with` mode. The default `--limit 10` was silently truncating real results below the file's actual entry count (17), misreporting genuine matches as "missing in Loki." Fixed by adding the same auto-calculation (`file entry count + 10`) the bash original always had.

---

## Questions to Answer (resolved)

1. **[Q1]** Protobuf-encoding-specific problem? — **No.** Disproven directly (see Resolution) — the exporters always send JSON regardless of the protocol env var.
2. **[Q2]** Does Grafana Cloud's OTLP gateway validate protobuf differently? — **Moot**, since [Q1] ruled out protobuf as a factor at all in this codebase's actual behavior.
3. **[Q3]** Specific to logs, or all three signals? — **All three**, for the same reason (all three exporters relied on the same broken env var). All three now confirmed working post-fix.
4. **[Q4]** Does the local otel-collector intermediary matter? — **No** — the actual cause was entirely on the credential-transport side (a missing Authorization header), not a translation/normalization difference between local UIS and Grafana Cloud's native gateway.

---

## Next Steps

- [x] Tested Option A (protobuf vs. JSON) — disproven
- [x] Found the real cause by capturing the actual OTLP response body (a monkey-patched `https.request`, since the SDK never logs or inspects this) — `"authentication error: no credentials provided"`
- [x] Root-caused to an unquoted `.env` value with an embedded space, truncated by bash `source` — fixed in `generate-e2e-env.ts` (and the already-generated `.env.grafana-cloud` file)
- [x] Found and fixed a second, unrelated bug: `query-loki.ts` missing the auto-limit-increase for `--compare-with`
- [x] Re-ran `query-loki.ts`/`query-tempo.ts`/`query-prometheus.ts` with `--compare-with` against real E2E test output — all three pass (Loki 17/17, Tempo 4/4, Prometheus 5/5), closing out `INVESTIGATE-grafana-cloud-validator.md`'s remaining ingestion-verification step
