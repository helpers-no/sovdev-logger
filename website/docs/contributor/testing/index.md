---
title: Testing backends
sidebar_label: Testing backends
sidebar_position: 0
description: "How to stand up a real OTLP backend to test sovdev-logger against, one platform at a time."
---

# Testing backends

`compare-with-master.sh` and each language's E2E test need a real, live OTLP backend (Loki, Prometheus, Tempo, an OTel Collector, and Grafana to look at the result) to test against — not a mock. This section documents how to stand one up, one platform at a time, and how to point a language implementation's E2E test at it.

## Pages

- **[UIS (local)](uis.md)** — Urbalurba Infrastructure Stack, a full observability stack running on your own machine via Rancher Desktop. The first backend documented here, and the one used for local development.
- **[Grafana Cloud](grafana-cloud.md)** — the same Loki/Tempo/Mimir stack UIS runs locally, hosted, for testing without local Kubernetes. Fully verified end-to-end (TypeScript) — see [`INVESTIGATE-grafana-cloud-validator.md`](../../ai-developer/plans/completed/INVESTIGATE-grafana-cloud-validator.md).

## Planned pages

- Azure (Azure Monitor / Application Insights)
- Google Cloud (Cloud Trace / Cloud Logging / Cloud Monitoring)

Each page follows the same shape: how to install/reach the backend, the OTLP endpoint convention, and a worked example of pointing one language's E2E test at it and confirming data actually landed (not just that the SDK didn't throw).
