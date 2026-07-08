---
title: Azure integration
sidebar_label: Azure integration
sidebar_position: 1
description: "Why sovdev-logger uses the standard OpenTelemetry SDK rather than Azure Monitor's own distro, and how the same code runs locally and in Azure."
---

# Azure integration

sovdev-logger works with Azure Monitor/Application Insights, but deliberately uses the **standard OpenTelemetry SDK** rather than Microsoft's own [Azure Monitor OpenTelemetry Distro](https://learn.microsoft.com/en-us/azure/azure-monitor/app/opentelemetry). Both are officially supported by Microsoft; see [Why OTLP](../general/why-otlp.md) for the general case behind that choice. This page covers the Azure-specific tradeoff and the practical configuration.

## Why the standard SDK, not the Azure distro

Microsoft's own guidance recommends their distro "for new applications or customers to power Azure Monitor Application Insights" — it's more convenient (one-line setup) and Azure-specific. sovdev-logger uses the standard SDK instead:

- **Portability**: the same SDK works identically against Loki (local development) and Azure Monitor (production) — the distro doesn't run against Loki.
- **No lock-in**: switching observability backends later (Datadog, Grafana Cloud, self-hosted) is a configuration change, not a rewrite.
- **Azure still works fully**: Application Insights accepts OTLP natively, and the [`azuremonitorexporter`](https://learn.microsoft.com/en-us/azure/azure-monitor/app/opentelemetry) collector component routes standard OTLP traffic to Azure Monitor — you don't lose Azure functionality by not using the distro, you trade one-line convenience for portability.

## The same code, three deployment scenarios

sovdev-logger's SDK calls don't change between environments — only the configured OTLP endpoint does:

| Scenario | Where it runs | OTLP endpoint | Backend |
|---|---|---|---|
| Local development | Node.js/Python on a laptop | `127.0.0.1:4318`, `Host: otel.localhost` | Loki + Tempo + Prometheus → Grafana (local) |
| In-cluster | A pod in the dev/test Kubernetes cluster | `otel-collector...svc.cluster.local:4318` | Same Loki/Tempo/Prometheus stack |
| Azure production | Azure Function / App Service / Container Apps | `https://insights.azure.com/v1/logs`, `Authorization: Bearer <token>` | Application Insights (unified logs, traces, metrics) |

All three route through an OpenTelemetry Collector, which receives OTLP and forwards to whichever backend is configured — the application code is identical in all three; only the collector's routing configuration changes.
