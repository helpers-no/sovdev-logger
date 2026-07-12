---
title: About
sidebar_label: About
slug: /about
sidebar_position: 0
description: "About sovdev-logger — what it is, why it's built on OpenTelemetry, and how it's developed and maintained."
---

# About sovdev-logger

**sovdev-logger is a specification-first, multi-language structured logging library.** One log call gives structured logs, metrics, and distributed traces — correlated automatically — against any OpenTelemetry-compatible backend (Azure Monitor, Grafana Cloud, Datadog, New Relic, Honeycomb, or self-hosted).

TypeScript is the reference implementation; Python is conformant and verified against it; Go, C#, Rust, and PHP are planned. Every implementation must produce **identical output** for the same log call — that's what the [specification](./contributor/index.md) and an automated comparison tool exist to guarantee.

This About section explains **what the project is** and **why it's built this way**, so a reader can decide whether to use it and a contributor can build or maintain a language port. It has three parts:

- **[General documentation](./general/index.md)** — what sovdev-logger is and why it's built on OpenTelemetry/OTLP, including the real tradeoffs.
- **[Using sovdev-logger](./using/index.md)** — quickstarts, configuration, and log structure, for people using the library in their application.
- **[Contributor documentation](./contributor/index.md)** — the specification and implementation contract, for people building or maintaining a language port.

> How we plan and build this project — the investigation → plan → implementation flow, git rules — is in the [AI Developer Workflow](./ai-developer/README.md) section, a process framework shared with sibling Red Cross Norway repos rather than product documentation.
