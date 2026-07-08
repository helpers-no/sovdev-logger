---
title: Using sovdev-logger
sidebar_label: Using sovdev-logger
sidebar_position: 0
description: "Quickstarts and configuration for using sovdev-logger in your application."
---

# Using sovdev-logger

For people **using** sovdev-logger in their application — install, configure, log. Not for people implementing or maintaining the library itself; see [Contributor documentation](../contributor/index.md) for that.

## Quickstart per language

Package READMEs stay the canonical, up-to-date source — not duplicated here (see [Q2](../ai-developer/plans/completed/INVESTIGATE-documentation-strategy.md) in the documentation-strategy investigation for why):

- **[TypeScript README](https://github.com/helpers-no/sovdev-logger/blob/main/typescript/README.md)** — complete API reference, examples, patterns (canonical — other languages diff against this)
- **[Python README](https://github.com/helpers-no/sovdev-logger/blob/main/python/README.md)** — complete API reference, notes differences from TypeScript

## Pages

- **[Azure integration](azure-integration.md)** — why standard OpenTelemetry rather than Azure's own distro, and how the same code runs locally and in Azure.
- **[Configuration](configuration.md)** — environment variables, OTLP setup, file logging.
- **[Logging concepts](logging-concepts.md)** — distributed tracing with spans, when to use them.
- **[Log data structure](logging-data.md)** — field reference, logging patterns, correlation strategies.
- **[Observability architecture](observability-architecture.md)** — dashboard setup, service name naming, verification.
- **[Loggeloven compliance](loggeloven.md)** — Norwegian Red Cross logging requirements.
