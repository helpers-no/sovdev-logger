---
title: "Onboarding a new system"
sidebar_label: "Onboarding a new system"
sidebar_position: 0
description: "How to connect a new application to the shared Grafana Cloud stack — one dashboard across many systems, each with its own independently-revocable credential."
---

# Onboarding a new system

This is the recipe for connecting a new application to the shared Grafana Cloud stack sovdev-logger's own dashboard already reads from — written once so the third, tenth, or hundredth system to onboard doesn't need to re-derive it.

## The principle

[Why Consistent Logging Across Systems](../../general/why-consistent-logging.md) makes the case for one schema across every system. The Grafana Cloud side of that is: **one stack, one dashboard — but not one shared credential.** Every system gets its own OTLP ingest token, scoped write-only to that stack, independently revocable. All of them land in the same Loki/Prometheus/Tempo, differentiated only by `service_name` — so the dashboard's `$service_name` picker just grows a new option, with nothing about the dashboard itself needing to change. A leaked or rotated token for one system never touches another's.

## The recipe

### 1. Pick a `service_name`

Kebab-case, unique across the whole stack (e.g. `ollacrm-api`). This is the label that separates this system's data from every other system's in every panel and every query. Treat it as stable — renaming it later splits your history in two, since every past log/metric/trace keeps the old name.

### 2. Create a dedicated Access Policy + token — you do this, not an agent

Grafana Cloud portal → **Security → Access Policies → Create access policy** (this project's stack lives under the org slug `urbalurba` — the maintainer's own chosen name, not a Grafana term — so that's **https://grafana.com/orgs/urbalurba/access-policies**). The "Create new access policy" form has these fields, confirmed against a real one:

- **Display name** and **Name** (a separate "unique identifier" field, shown right below Display name) — set both to `<service-name>-ingest` (e.g. `ollacrm-ingest`); there's no reason for them to differ
- **Realms** — a multi-select dropdown, not free text. Pick this one stack (e.g. `urbalurba`) specifically, **not** "all stacks"
- **Scopes** — a table: rows are resources (`metrics`, `logs`, `traces`, `profiles`, `alerts`, `rules`, `accesspolicies`), columns are `Read`/`Write`/`Delete` checkboxes. Check only **Write** for `metrics`, `logs`, and `traces` — leave every other checkbox unchecked
- Click **Create access policy**, then on the resulting policy card click **Add token**, name it to match, and copy the value immediately — it's shown once

![The "Create new access policy" form, filled in for ollacrm-ingest](./grafana-cloud-access-policy-form.png)

*Screenshot captured 2026-07-10. This is Grafana Cloud's own UI, not something this project controls — if the form looks different when you get here, Grafana Labs has redesigned it since; follow the field descriptions above rather than the exact layout.*

This step doesn't get delegated to an AI agent: minting credentials and touching access controls in the portal is a hard line this project already drew once — two separate Claude Code sessions have each independently declined to click "Create" here, even with explicit authorization.

### 3. Find the OTLP endpoint and its Instance ID

From your stack's management page (**https://grafana.com/orgs/urbalurba/stacks/484308** — the number in that URL is Grafana's own stack ID, and it's the same number as the Instance ID below, confirmed), click **Configure** on the **OpenTelemetry** card. That page (`.../stacks/484308/otlp-info`) shows exactly what you need:

- **OTLP Endpoint** — one endpoint handles all three signals: `https://otlp-gateway-prod-eu-west-0.grafana.net/otlp` for this stack (region varies by stack, don't assume `eu-west-0`)
- **Instance ID** — shown directly on this page (`484308` for this stack)

This Instance ID is specific to OTLP ingestion; it's a *different* Instance ID than Loki, Tempo, or Prometheus each have on their own connection pages (reachable from the same stack management page, one card per signal) — confirmed non-uniform, don't assume a shared pattern or reuse another signal's ID here.

The same page also offers to generate a token directly ("Password / API Token — Generate now") — that's a separate, simpler path than the Access Policy in step 2, but skip it: it doesn't give you the scoped, independently-named, independently-revocable token this recipe is built around. Use the Access Policy token from step 2 as the password instead.

### 4. Configure the new system's OTLP exporter

Six standard OpenTelemetry environment variables, the same regardless of language or framework:

```bash
OTEL_SERVICE_NAME=<service-name>
OTEL_EXPORTER_OTLP_LOGS_ENDPOINT=<otlp-endpoint>/v1/logs
OTEL_EXPORTER_OTLP_METRICS_ENDPOINT=<otlp-endpoint>/v1/metrics
OTEL_EXPORTER_OTLP_TRACES_ENDPOINT=<otlp-endpoint>/v1/traces
OTEL_EXPORTER_OTLP_HEADERS="Authorization=Basic <base64(instance-id:token)>"
OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf
```

Compute the Basic Auth value with the OTLP Instance ID from step 3 and the token from step 2:

```bash
echo -n "<otlp-instance-id>:<ollacrm-ingest-token>" | base64
```

The header value **must stay quoted** wherever it's stored or sourced — `Authorization=Basic <token>` contains a space, and anything that word-splits on spaces (bash's `source`, for one) silently truncates it after the space, producing a confusing `401` with no useful error about why.

### 5. Validate the token actually works — before wiring it into the real system

Don't skip this. A portal saying "access policy created" and an SDK printing "flushed successfully" both prove nothing on their own — this project already found a real bug once where console output claimed success while data silently never arrived (see [`INVESTIGATE-long-running-server-flush.md`](../../ai-developer/plans/completed/INVESTIGATE-long-running-server-flush.md)). The only real proof is a readback that actually finds the data.

Run a tiny, throwaway test through the exact env vars from step 4 — a distinct, disposable `service_name` like `<service-name>-ingest-validation` (not the real one, so this never pollutes the actual dashboard), one `sovdev_log()` call with a unique marker message, then `sovdev_shutdown()`. For example, using the published TypeScript package:

```typescript
import { sovdev_initialize, sovdev_log, sovdev_shutdown, SOVDEV_LOGLEVELS, create_peer_services } from 'sovdev-logger';

sovdev_initialize('ollacrm-ingest-validation', '1.0.0', {});
sovdev_log(SOVDEV_LOGLEVELS.INFO, 'validateIngest', 'MARKER-INGEST-VALIDATION', create_peer_services({}).INTERNAL, null, null, null);
await sovdev_shutdown();
```

Then read it back — reuse the **existing** `sovdev-logger-verify` credentials (`tools/validation/grafana-cloud/query-loki.ts` / `query-prometheus.ts`); it already has stack-wide read access, so no new verify token is needed per system:

```bash
cd tools/validation/grafana-cloud
set -a && source .env && set +a
npx tsx query-loki.ts <service-name>-ingest-validation --json
npx tsx query-prometheus.ts <service-name>-ingest-validation --json
```

Confirm the marker message and a metric both actually show up in the response — not just that the commands ran without error — before moving on. Delete the throwaway test script once confirmed.

### 6. Treat `OTEL_EXPORTER_OTLP_HEADERS` as a real secret

It contains the token from step 2. Store it in whatever secret manager the new system's own deploy pipeline already uses for real secrets — never as a plain environment variable alongside identifiers like `OTEL_SERVICE_NAME`. The other five variables are plain identifiers (URLs, a service name, a protocol string) and can live as ordinary env vars/config.

### 7. Verify it shows up in the real system

Once the new system is actually wired up (not the throwaway validation from step 5) and has generated at least one real log call, open the dashboard — the new `service_name` appears automatically in the `$service_name` picker (multi-select, "All" selected by default) and in every panel's legend. Nothing about the dashboard changes: this is exactly what its template variable and per-peer-service panels were built for. See [Dashboard walkthrough](../dashboard-walkthrough/index.md) for what each panel means once you're looking at it.

## What you're *not* doing

- **Not** creating a new dashboard — the existing one already generalizes to any number of services.
- **Not** creating a new Grafana Cloud stack — one stack, one retention budget, one place to look.
- **Not** sharing a credential across systems — every system's blast radius stays contained to its own token.

## Experience reports

Real systems that have gone through this recipe, with the exact snippets that made it concrete:

- [ollacrm](ollacrm/index.md) — a TypeScript/Hono service on Cloud Run, sovdev-logger's first external consumer

## See also

- [Why Consistent Logging Across Systems](../../general/why-consistent-logging.md) — the philosophy behind this recipe
- [Dashboard walkthrough](../dashboard-walkthrough/index.md) — what each panel shows once data arrives
- [Observability architecture](../observability-architecture.md) — the local-UIS side of dashboard setup
- [Testing against Grafana Cloud](../../contributor/testing/grafana-cloud.md) — how sovdev-logger's own E2E tests use this same stack, for verification rather than a production system
