---
title: "Example: onboarding ollacrm"
sidebar_label: "Example: onboarding ollacrm"
sidebar_position: 1
description: "A real, worked example of onboarding a new system onto sovdev-logger and the shared Grafana Cloud stack — ollacrm, the first external consumer."
---

# Example: onboarding ollacrm

[Onboarding a new system](../index.md) is the generic recipe. This page is the concrete worked example that recipe was written from: `ollacrm` — a private TypeScript/Hono service on Cloud Run, sovdev-logger's first real consumer outside this repo. Every snippet below is checked against ollacrm's actual code, not invented, so it doubles as both a record of what was actually done and a template for the next system to onboard.

## The starting point

`ollacrm-api` had zero structured logging — 18 raw `console.log`/`console.error`/`console.warn` calls, captured only as unstructured Cloud Run stdout/stderr. No metrics, no traces, no correlation between a failure and the request that caused it.

## 1. Install

```bash
cd services/api
npm install @terchris/sovdev-logger
```

The published package (`@terchris/sovdev-logger@1.0.1`) already includes the OTLP header spec-compliance fix — no workarounds needed, just install it.

## 2. Configuration, matched to how this service already deploys

`sovdev_validate_config()` needs six environment variables:

```
OTEL_SERVICE_NAME=ollacrm-api
OTEL_EXPORTER_OTLP_LOGS_ENDPOINT=<otlp-endpoint>/v1/logs
OTEL_EXPORTER_OTLP_METRICS_ENDPOINT=<otlp-endpoint>/v1/metrics
OTEL_EXPORTER_OTLP_TRACES_ENDPOINT=<otlp-endpoint>/v1/traces
OTEL_EXPORTER_OTLP_HEADERS="Authorization=Basic <base64(instance-id:token)>"
OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf
```

The endpoint, Instance ID, and token come from following [Onboarding a new system](../index.md)'s recipe first (a dedicated `ollacrm-ingest` access policy, independent from sovdev-logger's own).

ollacrm's Cloud Run deploy (`.github/workflows/deploy.yml`) already distinguishes plain identifiers (`--update-env-vars`) from real secrets (`--set-secrets`, mounted from Secret Manager — the pattern its existing `VAPID_PRIVATE_KEY` already uses). `OTEL_EXPORTER_OTLP_HEADERS` contains a credential, so it follows the secret path; the other five are identifiers:

```yaml
--update-env-vars=...,OTEL_SERVICE_NAME=ollacrm-api,OTEL_EXPORTER_OTLP_LOGS_ENDPOINT=...,OTEL_EXPORTER_OTLP_METRICS_ENDPOINT=...,OTEL_EXPORTER_OTLP_TRACES_ENDPOINT=...,OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf
--set-secrets=VAPID_PRIVATE_KEY=vapid-private:latest,OTEL_EXPORTER_OTLP_HEADERS=otel-otlp-headers:latest
```

This generalizes directly: whatever the new system's own deploy pipeline already uses for secrets vs. plain config, `OTEL_EXPORTER_OTLP_HEADERS` goes wherever secrets go, the rest goes wherever identifiers go.

## 3. Initialize once, shut down on SIGTERM — the gap sovdev-logger's own README doesn't cover

Every example in sovdev-logger's TypeScript README is a short script: call `sovdev_shutdown()` once at the end, then exit. ollacrm-api is a persistent Hono server — there is no "end of script." The correct shape for any long-running server:

- Call `sovdev_initialize()` once, at module load, alongside the rest of the server's top-level setup.
- Call `sovdev_log()` freely per request — **no flush per call**. Logs batch-export every 1 second, metrics every 10 seconds, automatically. Flushing more often than that only adds latency, for nothing. (`sovdev_flush()` is safe to call if you ever want telemetry out sooner — e.g. defensively — but a server shouldn't need it on the normal request path.)
- Shut down exactly once, on graceful shutdown — call `sovdev_shutdown()`, not `sovdev_flush()`. Cloud Run sends `SIGTERM` with a grace period before `SIGKILL` on scale-down or redeploy — long enough to cover the batch windows above.

Concretely, in `services/api/src/server.ts`:

```typescript
import { sovdev_initialize, sovdev_shutdown } from "@terchris/sovdev-logger";

sovdev_initialize("ollacrm-api", undefined, {
  SHEETS: "google-sheets",
  DRIVE: "google-drive",
  CALENDAR: "google-calendar",
  VERTEX_AI: "google-vertex-ai",
});

// ... existing app.get/app.post routes, unchanged ...

const port = Number(process.env.PORT ?? 8080);
serve({ fetch: app.fetch, port }, () => {
  console.log(`ollacrm api on :${port}`);
});

process.on("SIGTERM", async () => {
  await sovdev_shutdown();
  process.exit(0);
});
```

This is a general pattern, not ollacrm-specific — any Node server behind Cloud Run (or anything else that sends `SIGTERM` before killing a process) uses the same three-part shape: initialize at startup, log freely, shut down exactly once on the way out. `sovdev_shutdown()` (not `sovdev_flush()`) is the right call here specifically because it's the true, one-time end of the process — `sovdev_flush()` is for anywhere else you might want telemetry out sooner, safe to call as often as you like.

## 4. Peer services

sovdev-logger tracks per-external-system metrics and dependencies via a `peer_service` argument on every log call. ollacrm-api talks to Google Sheets (the CRM data store), Drive, Calendar, and Vertex AI (Gemini) — the identifiers above are what it picked; `create_peer_services({...})` auto-generates `PEER_SERVICES.INTERNAL` (resolving to `ollacrm-api` itself) for anything that isn't an external call. Whatever the new system calls externally, name each one and the dependency view in the shared dashboard fills in on its own.

## 5. A real conversion

`services/api/src/adapters/sheets.ts`'s `fetchRetry()` already had the exact retry/give-up shape sovdev-logger is built for — transient retry at INFO, give-up at ERROR, both against an external system (Sheets):

**Before:**
```typescript
console.log(`sheets: ${step} transient (${netErr ? "network" : r!.status}), retry ${attempt}/${MAX_ATTEMPTS - 1}`);
// ...
console.log(`sheets: ${step} network give-up: ${String(netErr).slice(0, 150)}`);
throw netErr;
// ...
console.log(`sheets: ${step} give-up (${r!.status}): ${body}`);
throw new Error(`${step} failed (${r!.status}): ${body}`);
```

**After:**
```typescript
sovdev_log(SOVDEV_LOGLEVELS.INFO, "fetchRetry", `${step} transient, retrying`,
  PEER_SERVICES.SHEETS, { step, attempt, url }, null, null);
// ...
sovdev_log(SOVDEV_LOGLEVELS.ERROR, "fetchRetry", `${step} network give-up`,
  PEER_SERVICES.SHEETS, { step, url }, null, netErr);
throw netErr;
// ...
sovdev_log(SOVDEV_LOGLEVELS.ERROR, "fetchRetry", `${step} give-up (${r!.status})`,
  PEER_SERVICES.SHEETS, { step, url }, null, new Error(`${step} failed (${r!.status}): ${body}`));
throw new Error(`${step} failed (${r!.status}): ${body}`);
```

One function, converted, immediately gets: an error-rate metric specific to Sheets, a searchable/filterable log instead of a truncated string, and — once wrapped in `sovdev_start_span`/`sovdev_end_span` at the calling handler — a trace showing exactly which Sheets call failed and how long it took first.

## 6. Verify

Once the real env var values are in place:

1. Deploy, or run locally with the same env vars set.
2. Trigger a request that hits the converted code path (or just `/health`, as the simplest smoke test that the SDK initializes without error).
3. Open the shared dashboard — `ollacrm-api` appears as a new option in the `$service_name` picker within a few seconds. No dashboard changes needed — this is exactly what [Onboarding a new system](../index.md) describes.

## See also

- [Onboarding a new system](../index.md) — the generic recipe this example follows
- [Why Consistent Logging Across Systems](../../../general/why-consistent-logging.md) — why this scales to system #3, #4, ... #100
- [Dashboard walkthrough](../../dashboard-walkthrough/index.md) — what each panel means once ollacrm's data arrives
