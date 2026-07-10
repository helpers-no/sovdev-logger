---
title: Why Structured Logging
sidebar_label: Why Structured Logging
sidebar_position: 1
description: "Why sovdev-logger enforces a fixed JSON schema instead of free-text log messages, including the real costs."
---

# Why Structured Logging

sovdev-logger exists so one log call gives you structured logs, metrics, and distributed traces — correlated automatically. That part of the pitch is on the [project README](https://github.com/helpers-no/sovdev-logger#readme), and [Why OTLP](./why-otlp.md) covers the wire-protocol half of "how." This page is about the other half: why every log entry is a fixed-schema JSON object instead of a free-text message string — and why that isn't optional or configurable.

## The case for structured logging

**Machine-queryable, not just machine-readable.** A free-text message like `"Handle_New_Employee failed userCreationInfo=(...) failure message=..."` is readable, but only a human parsing it line by line can extract "which user, which system, which failure." A structured entry with `user_id`, `system_id`, and `exception_message` as separate fields means Loki/Grafana can filter, aggregate, and alert on those values directly — no regex, no `grep` guesswork. See [Loggeloven compliance](../using/loggeloven.md) for the concrete before/after example this project's own compliance policy is built around.

**Correlation comes from the schema, not from discipline.** `trace_id`, `span_id`, and `event_id` are fields on every entry, not something a developer has to remember to add consistently. That's what lets a dashboard panel join a log line to its trace and its metric without any manual wiring — see the [Dashboard walkthrough](../using/dashboard-walkthrough/index.md) for what that looks like in practice.

**The same field means the same thing in every language.** `peer_service`, `exception_type`, `function_name` — TypeScript, Python, and every future language port emit identical field names for identical concepts, enforced by the [specification](../contributor/index.md) and its cross-language conformance check. A LogQL query written against one implementation's logs works unchanged against any other's. A free-text format can't offer that guarantee — two developers describing the same failure in prose will phrase it differently.

## What structured logging costs

This isn't free either:

- **Less "just print whatever" freedom.** Every `sovdev_log()` call has to fit the fixed field set the [specification](../using/logging-data.md) defines — you can't add an ad-hoc field mid-incident the way you can drop an extra value into an f-string. New context has to go into the existing `input`/`response` JSON payloads, not a new top-level field.
- **More ceremony per call than `console.log(message)`.** Building the structured entry (service name, peer service, function name, the input/response objects) is more typing than a single string interpolation, especially for a quick debug print.
- **Worse to eyeball directly.** A raw `tail -f` of a structured JSON log stream is harder to scan at a glance than a plain sentence — it's designed to be queried through Grafana/Loki, not read raw in a terminal. The file logger's plain-text mode exists partly to soften this for local development (see [Configuration](../using/configuration.md)), but the OTLP-exported version is JSON, full stop.

## Why the tradeoff is worth it here

The cost is paid once, per log call, by the developer writing it. The benefit — a log line that's already filterable, already correlated to its trace and its metrics, already consistent with every other language's implementation — is paid back every single time someone has to investigate an incident instead of grep through prose guessing at field boundaries.
