---
title: General documentation
sidebar_label: General documentation
sidebar_position: 0
description: "What sovdev-logger is, why it exists, and why it's built on OpenTelemetry/OTLP — before any implementation detail."
---

# General documentation

What sovdev-logger is and why it's built the way it is — for anyone deciding whether to use it, before the how-to detail.

## Pages

- **[Why Structured Logging](why-structured-logging.md)** — why every log entry is a fixed-schema JSON object instead of a free-text message, including the real costs, not just the benefits.
- **[Why OTLP](why-otlp.md)** — why sovdev-logger is built on OpenTelemetry/OTLP rather than a bespoke format or a vendor SDK, including the real costs, not just the benefits.
- **[Why Consistent Logging Across Systems](why-consistent-logging.md)** — the organization-level benefit: every system logging the same way is what makes automated monitoring and ticket routing (e.g. into ServiceNow) possible, not just one application's own dashboard.

## See also

- **[Using sovdev-logger](../using/index.md)** — quickstarts and configuration, for library users
- **[Contributor documentation](../contributor/index.md)** — the specification and implementation contract, for people building or maintaining a language port
