---
title: Contributor documentation
sidebar_label: Contributor
sidebar_position: 0
description: "The specification and implementation contract for people building or maintaining a sovdev-logger language port."
---

# Contributor documentation

For people (human or LLM) **implementing or maintaining** a sovdev-logger language port — the API contract, field definitions, and design rationale every implementation must follow. Not for people just using the library; see [Using sovdev-logger](../using/index.md) for that.

## Start here

- **[Implementation guide](implementation-guide.md)** — the end-to-end process: contract → TypeScript → anti-patterns → implement → `compare-with-master.sh`

## Core documents

- **[Design principles](00-design-principles.md)** — core philosophy and key design decisions
- **[OpenTelemetry SDK guide](research-otel-sdk-guide.md)** — OpenTelemetry SDK differences between languages
- **[API contract](01-api-contract.md)** — the public API every language MUST implement
- **[Development loop](09-development-loop.md)** — the iterative edit/lint/build/validate workflow

## Supporting documents

- **[Field definitions](02-field-definitions.md)** — every log field, its type, and when it's present
- **[Implementation patterns](03-implementation-patterns.md)** — required patterns (snake_case, directory structure)
- **[Error handling](04-error-handling.md)** — exception handling, credential removal, stack trace limits
- **[Environment configuration](05-environment-configuration.md)** — environment variables, DevContainer setup, toolchain
- **[Test scenarios](06-test-scenarios.md)** — test scenarios and verification procedures
- **[Anti-patterns](07-anti-patterns.md)** — the mistakes every prior implementation attempt has actually made
- **[Test program: company lookup](08-testprogram-company-lookup.md)** — the E2E test every implementation must pass
- **[Code quality](10-code-quality.md)** — linting standards and quality rules

## Functional code (not migrated — lives in the repo)

`specification/schemas/`, `specification/tests/`, and `specification/tools/` (including `compare-with-master.sh`, the actual completion gate) are functional code, not documentation — see them directly in the [repo](https://github.com/helpers-no/sovdev-logger/tree/main/specification).
