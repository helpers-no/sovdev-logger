---
title: General documentation
sidebar_label: General documentation
sidebar_position: 0
description: "What sovdev-logger is, why it exists, and why it's built on OpenTelemetry/OTLP — before any implementation detail."
---

# General documentation

What sovdev-logger is and why it's built the way it is — for anyone deciding whether to use it, before the how-to detail.

## Why the name

"sovdev" is short for **sovereign developer** — the idea that the same log call should keep working the same way regardless of two things a developer doesn't control forever: which language they're writing in, and which observability backend the organization sends telemetry to today.

- **Independent of programming language.** TypeScript, Python, and every future language port emit identical field names and structure for the same log call, enforced by the [specification](../contributor/index.md) and its cross-language conformance check — not just a naming convention someone has to remember. A query written once works against any implementation's logs.
- **Independent of logging stack.** Because sovdev-logger is built on OpenTelemetry/OTLP rather than a vendor SDK or a bespoke format, the same instrumentation works unchanged against Loki/Prometheus/Tempo, Azure Monitor, Grafana Cloud, Datadog, or whatever backend comes next — see [Why OTLP](why-otlp.md).

Neither independence is free — see [Why Structured Logging](why-structured-logging.md) and [Why OTLP](why-otlp.md) for what each actually costs. But together, that's what "sovereign" means here: a developer's logging code isn't hostage to a language choice or a vendor choice.

## Pages

- **[Why Structured Logging](why-structured-logging.md)** — why every log entry is a fixed-schema JSON object instead of a free-text message, including the real costs, not just the benefits.
- **[Why OTLP](why-otlp.md)** — why sovdev-logger is built on OpenTelemetry/OTLP rather than a bespoke format or a vendor SDK, including the real costs, not just the benefits.
- **[Why Consistent Logging Across Systems](why-consistent-logging.md)** — the organization-level benefit: every system logging the same way is what makes automated monitoring and ticket routing (e.g. into ServiceNow) possible, not just one application's own dashboard.

## See also

- **[Using sovdev-logger](../using/index.md)** — quickstarts and configuration, for library users
- **[Contributor documentation](../contributor/index.md)** — the specification and implementation contract, for people building or maintaining a language port
