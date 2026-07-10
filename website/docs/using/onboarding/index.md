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

Grafana Cloud portal → **Security → Access Policies → Create access policy**:

- Name it `<service-name>-ingest` (e.g. `ollacrm-ingest`)
- Scopes: `logs:write`, `metrics:write`, `traces:write`
- **Realm: this one stack specifically, not "all stacks"**
- Click **Add token**, name it to match, copy the value immediately — it's shown once

This step doesn't get delegated to an AI agent: minting credentials and touching access controls in the portal is a hard line this project already drew once — two separate Claude Code sessions have each independently declined to click "Create" here, even with explicit authorization.

### 3. Find the OTLP endpoint and its Instance ID

One endpoint handles all three signals: `https://otlp-gateway-prod-<region>.grafana.net/otlp` — find the exact value and its **Instance ID** on the OTLP connection page in the portal. This Instance ID is specific to OTLP ingestion; it's a *different* Instance ID than Loki, Tempo, or Prometheus each have on their own connection pages — confirmed non-uniform, don't assume a shared pattern or reuse another signal's ID here.

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

### 5. Treat `OTEL_EXPORTER_OTLP_HEADERS` as a real secret

It contains the token from step 2. Store it in whatever secret manager the new system's own deploy pipeline already uses for real secrets — never as a plain environment variable alongside identifiers like `OTEL_SERVICE_NAME`. The other five variables are plain identifiers (URLs, a service name, a protocol string) and can live as ordinary env vars/config.

### 6. Verify it shows up

Run the new system once, generating at least one log call. Open the dashboard — the new `service_name` appears automatically in the `$service_name` picker (multi-select, "All" selected by default) and in every panel's legend. Nothing about the dashboard changes: this is exactly what its template variable and per-peer-service panels were built for. See [Dashboard walkthrough](../dashboard-walkthrough/index.md) for what each panel means once you're looking at it.

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
