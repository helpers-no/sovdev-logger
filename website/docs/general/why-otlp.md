---
title: Why OTLP
sidebar_label: Why OTLP
sidebar_position: 2
description: "Why sovdev-logger is built on OpenTelemetry/OTLP rather than a bespoke format or a vendor SDK, including the real costs."
---

# Why OTLP

sovdev-logger exists so one log call gives you structured logs, metrics, and distributed traces — correlated automatically — without hand-wiring three separate instrumentation libraries per language. [Why Structured Logging](./why-structured-logging.md) covers the "structured" half. This page is about a narrower question: why build it on [OpenTelemetry](https://opentelemetry.io/) and its wire protocol, OTLP, specifically — instead of a bespoke JSON format or a vendor's own SDK.

## The case for OTLP

**One wire protocol, many backends.** OTLP is accepted natively by Loki, Prometheus, and Tempo (what this project runs locally), and by Azure Monitor, Grafana Cloud, Datadog, New Relic, and Honeycomb (what it runs against in production) — without changing a line of application code, only the exporter's configured endpoint. A bespoke JSON format would need a custom integration written and maintained for every one of those backends; OTLP means the backends have already done that work.

**Vendor neutrality is structural, not a policy choice.** OpenTelemetry is a CNCF standard with the entire observability industry building against it — including the vendors themselves. Microsoft's own guidance, for instance, is explicit that OpenTelemetry is "the future of telemetry instrumentation" for Azure Monitor, alongside their own (optional, more convenient, more locking-in) Azure Monitor Distro. Building on the standard SDK rather than a vendor's distro is what makes switching backends later a configuration change, not a rewrite — see [Azure integration](../using/azure-integration.md) for the concrete tradeoff this project made between the two.

**Local development parity.** The same code, the same SDK calls, run against a local Loki/Tempo/Prometheus stack on a laptop and against a cloud backend in production. Nothing about the instrumentation changes between "developing locally" and "running in Azure" — only where the collector sends data.

## What OTLP actually costs

This isn't free, and pretending otherwise wouldn't survive contact with actually using it:

- **More moving parts than `console.log`.** A flat JSON logger is one function call and a file handle. OTLP means an SDK, a batching/export pipeline, and — usually — a collector sitting between your application and the backend. That's real infrastructure to reason about, not just a library import.
- **A genuine learning curve.** Spans, trace context propagation, resource attributes, severity numbers as small integers instead of strings — none of this is obvious coming from a plain logging library, and getting it wrong silently (not loudly) produces logs that look fine locally but don't correlate correctly in a dashboard. Several of the historical bugs this project has fixed (see the [specification](../contributor/index.md)) were exactly this class of mistake.
- **A live dependency on the collector being reachable.** If the OTLP endpoint isn't up, the SDK doesn't fail your application — it retries in the background and eventually gives up, which is the right failure mode, but it does mean "my logs aren't showing up" can now mean "the collector is down" as well as "my code has a bug." (This is not hypothetical: it's the exact error text you'll see running this project's own end-to-end tests without a live collector configured.)

## Why the tradeoff is worth it here

The cost is paid once, in the library, by whoever implements a new language port. Every application that uses sovdev-logger afterward gets structured logs, metrics, and correlated traces for the price of one function call — the complexity is real, but it's centralized rather than repeated per application, per team, per language.
