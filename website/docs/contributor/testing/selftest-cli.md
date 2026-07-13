---
title: "Quick check: sovdev-selftest"
sidebar_label: "Quick check: sovdev-selftest"
sidebar_position: 2
description: "A fast, bundled CLI that writes a marker log + metric and reads both back, confirming a backend connection actually works."
---

# Quick check: `sovdev-selftest`

The full E2E test ([UIS](uis.md), [Grafana Cloud](grafana-cloud.md)) is the thorough, "does the whole library behave correctly" check — 17 log entries, schema validation, trace/span correlation. `sovdev-selftest` is the fast version: one marker log, one marker metric, read both back, PASS/FAIL. Ships as a real `bin` entry inside `@terchris/sovdev-logger` itself — no separate install, no clone of this repo needed (see [`INVESTIGATE-selftest-cli.md`](../../ai-developer/plans/completed/INVESTIGATE-selftest-cli.md) for the full design and [`PLAN-selftest-cli.md`](../../ai-developer/plans/completed/PLAN-selftest-cli.md) for how it was built and validated).

**Current limitation, not yet fixed**: reads back using the maintainer's own existing credentials (`GRAFANA_CLOUD_VERIFY_TOKEN` for Grafana Cloud, a Grafana admin login for UIS) — safe for the maintainer's own use, **not yet safe to hand to an external consumer** like ollacrm, since both are unscoped and can read every onboarded system's data, not just one. Giving external consumers their own scoped read credential is a tracked, deferred follow-up — see the investigation's Next Steps.

## Usage

```bash
npx sovdev-selftest --backend grafana-cloud   # or: --backend uis
npx sovdev-selftest --json                    # machine-readable, for CI
npx sovdev-selftest --help
```

`--backend` is optional if only one backend's env vars are set (auto-detects) — but required if both are set at once, which is the normal case in this project's own devcontainer.

`--help` (`node dist/cli/selftest.js --help` from `typescript/`, or `npx sovdev-selftest --help` once installed) prints the full option list and required env vars per backend:

```
sovdev-selftest -- confirms a logging/metrics backend connection actually works.

Writes one marker log + one marker metric under a disposable
<service-name>-selftest name (so it never touches your real dashboard data),
then reads both back from the backend itself -- not just "the write call
didn't throw", which OTLP exporters don't guarantee reflects real delivery.
Reports four independent signals: write-log, write-metric, read-log,
read-metric. Exits 0 only if all four pass, 1 otherwise.

Usage: sovdev-selftest [options]

Options:
  --backend grafana-cloud|uis   Which backend to write to and read back from. Required when
                                both backends' env vars are set at once (the normal case in
                                this project's own devcontainer) -- auto-detected only when
                                exactly one backend is configured.
  --service-name NAME           Real service name to use (defaults to $OTEL_SERVICE_NAME).
                                The actual write/read happens under "<name>-selftest".
  --json                        Machine-readable output for CI: the four signals as one JSON
                                line on stdout, nothing else on stdout. Progress still prints
                                to stderr.
  --help                        Show this help and exit.

Required environment variables (see contributor/testing/selftest-cli.md for
the full list and devcontainer-specific notes):
  Grafana Cloud: GRAFANA_CLOUD_INGEST_TOKEN, GRAFANA_CLOUD_VERIFY_TOKEN,
                 GRAFANA_CLOUD_OTLP_ENDPOINT, GRAFANA_CLOUD_OTLP_INSTANCE_ID,
                 GRAFANA_CLOUD_LOKI_URL, GRAFANA_CLOUD_LOKI_INSTANCE_ID,
                 GRAFANA_CLOUD_PROMETHEUS_URL, GRAFANA_CLOUD_PROMETHEUS_INSTANCE_ID
  UIS:           GRAFANA_URL, GRAFANA_USER, GRAFANA_PASSWORD
                 (+ GRAFANA_HOST_HEADER, optional, only needed from inside a
                 devcontainer where GRAFANA_URL points at host.docker.internal)
  Both backends also need the usual OTEL_EXPORTER_OTLP_*_ENDPOINT /
  OTEL_SERVICE_NAME variables any sovdev-logger app needs to write logs at all.
```

## Against UIS

**From the host Mac** — `otel.localhost`/`grafana.localhost` resolve directly there:

```bash
OTEL_SERVICE_NAME=<your-service-name>
OTEL_EXPORTER_OTLP_LOGS_ENDPOINT=http://otel.localhost/v1/logs
OTEL_EXPORTER_OTLP_METRICS_ENDPOINT=http://otel.localhost/v1/metrics
OTEL_EXPORTER_OTLP_TRACES_ENDPOINT=http://otel.localhost/v1/traces
OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf

GRAFANA_URL=http://grafana.localhost
GRAFANA_USER=admin
GRAFANA_PASSWORD=SecretPassword1
```

**From inside the devcontainer** — `otel.localhost`/`grafana.localhost` resolve to the container's own loopback there (confirmed directly: `getent hosts` returns `127.0.0.1`), not the host machine, so nothing answers on either. Use `host.docker.internal` (Docker's built-in host alias) plus an explicit `Host` header instead, so Traefik still routes by hostname — the write side already needed this (`OTEL_EXPORTER_OTLP_HEADERS=Host=otel.localhost`, per [UIS](uis.md) step 4); the read side needs the equivalent, `GRAFANA_HOST_HEADER`:

```bash
OTEL_SERVICE_NAME=<your-service-name>
OTEL_EXPORTER_OTLP_LOGS_ENDPOINT=http://host.docker.internal/v1/logs
OTEL_EXPORTER_OTLP_METRICS_ENDPOINT=http://host.docker.internal/v1/metrics
OTEL_EXPORTER_OTLP_TRACES_ENDPOINT=http://host.docker.internal/v1/traces
OTEL_EXPORTER_OTLP_HEADERS=Host=otel.localhost
OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf

GRAFANA_URL=http://host.docker.internal
GRAFANA_HOST_HEADER=grafana.localhost
GRAFANA_USER=admin
GRAFANA_PASSWORD=SecretPassword1
```

`GRAFANA_HOST_HEADER` is optional and only needed for this devcontainer case. Note this is why the read side is built on `node:http`/`node:https` rather than the global `fetch()` — verified directly that `fetch()`/undici silently drops a manually-set `Host` header (it's a WHATWG-forbidden header name), which would have made this override look like it worked while actually still routing (and 404ing) on the wrong hostname.

No `kubectl` needed either way — the read side goes through Grafana's own datasource-proxy API, not direct cluster access.

## Against Grafana Cloud

Reuses the exact same vars `tools/validation/grafana-cloud/.env.example` already documents:

```bash
OTEL_SERVICE_NAME=<your-service-name>
GRAFANA_CLOUD_OTLP_ENDPOINT=...
GRAFANA_CLOUD_OTLP_INSTANCE_ID=...
GRAFANA_CLOUD_INGEST_TOKEN=...
GRAFANA_CLOUD_VERIFY_TOKEN=...
GRAFANA_CLOUD_LOKI_URL=...
GRAFANA_CLOUD_LOKI_INSTANCE_ID=...
GRAFANA_CLOUD_PROMETHEUS_URL=...
GRAFANA_CLOUD_PROMETHEUS_INSTANCE_ID=...
```

## What it does

Writes one log + one metric under `<OTEL_SERVICE_NAME>-selftest` (disposable, so it never pollutes the real dashboard's data), polls for up to 30s (log) / 60s (metric), and reports four independent signals — each showing what was actually written or read back, not just pass/fail.

It reports progress **as it happens**, not just retrospectively at the end — every CLI-owned line is timestamped (so real ordering is verifiable, not just asserted), starting with a version banner, then an explicit `=== Test starting ===` / `=== Test finished ===` boundary around the whole write+read sequence. Progress is announced *between* each real library call, in the order things actually happen — `sovdev_initialize()` (which is what prints "OTLP Metrics configured...") runs before anything is queued or sent, so "Initializing..." genuinely appears first, not after, and an explicit "Initialization complete." line marks the boundary before anything is queued.

Not every line in the output is this tool's own claim — `sovdev_initialize()`/`sovdev_shutdown()` print their own internal diagnostic lines (session ID, OTLP setup, flush/shutdown progress) as a side effect of the real library calls this tool makes, passed straight through, not authored or verified by this tool. Rather than leave that to be inferred, the `=== Test starting ===` line states the rule once, up front: **timestamped lines are this tool's own reporting; un-timestamped lines are sovdev-logger's own internal output, not a claim this tool is making.**

Nothing is described in summary form — the write step logs the literal argument list `sovdev_log()` is about to be called with (including the three optional arguments left `null`, so nothing is hidden by omission either), and the read step logs the exact request URL immediately before firing it, straight from the same variable used for the real `fetch()` call — not a string reconstructed separately for display, which could drift from what's actually sent. That URL carries no credential (Basic Auth goes in a header, not the query string), so it's safe to print in full, and it's also exactly what you'd paste into a browser or `curl -u user:pass` yourself to check the read independently, rather than take the tool's word for it:

```
[2026-07-13T00:57:05.442Z] sovdev-selftest v1.0.2 (@terchris/sovdev-logger)
[2026-07-13T00:57:05.785Z] === Test starting === (timestamped lines below are this tool's own reporting; un-timestamped lines are sovdev-logger's own internal diagnostic output, printed as-is, not a claim made by this tool)
[2026-07-13T00:57:05.785Z] Initializing sovdev-logger for service_name=ollacrm-api-selftest (configures the OTLP exporters) ...
🔑 Session ID: ...
📊 OTLP Metrics configured for: ...
   (sovdev_initialize()'s own diagnostic output continues here)
[2026-07-13T00:57:05.811Z] Initialization complete.
[2026-07-13T00:57:05.811Z] Queuing log entry -- sovdev_log(level=INFO, function_name=sovdev-selftest, message="sovdev-selftest marker", peer_service=INTERNAL, input_json=null, response_json=null, exception_object=null) ...
02:57:05 [info] ollacrm-api-selftest:sovdev-selftest - sovdev-selftest marker
[2026-07-13T00:57:05.814Z] Queued. This same call also auto-emitted the sovdev_operations_total metric.
[2026-07-13T00:57:05.814Z] Flushing and shutting down -- this is when the queued log + metric actually get sent over the network ...
   (sovdev_shutdown()'s own flush/shutdown diagnostic output continues here)
[2026-07-13T00:57:07.825Z] Shutdown complete.
[2026-07-13T00:57:07.825Z] Reading back the log (polling up to 30s) ...
[2026-07-13T00:57:07.827Z] Querying: GET https://logs-prod-eu-west-0.grafana.net/loki/api/v1/query_range?query=%7Bservice_name%3D%22ollacrm-api-selftest%22%7D&limit=1&start=...&end=...
[2026-07-13T00:57:07.987Z] Found: "sovdev-selftest marker" at 2026-07-13T00:57:05.813Z
[2026-07-13T00:57:07.988Z] Reading back the metric (polling up to 60s) ...
[2026-07-13T00:57:07.988Z] Querying: GET https://prometheus-prod-01-eu-west-0.grafana.net/api/prom/api/v1/query?query=sovdev_operations_total%7Bservice_name%3D%22ollacrm-api-selftest%22%7D
[2026-07-13T00:57:08.278Z] Found: value=1 at 2026-07-13T00:57:08.258Z
[2026-07-13T00:57:08.278Z] === Test finished ===

✅ write-log: sent message="sovdev-selftest marker" under service_name=ollacrm-api-selftest
✅ write-metric: sent sovdev_operations_total{service_name="ollacrm-api-selftest"} 1
✅ read-log: "sovdev-selftest marker" at 2026-07-13T00:57:05.813Z
✅ read-metric: value=1 at 2026-07-13T00:57:08.258Z

✅ All checks passed.
```

Every retry during polling repeats the "Querying: GET ..." line with its own (slightly later) timestamp range — that's a real, distinct HTTP request each time, not a cosmetic repeat, so it's shown every time rather than only on the first attempt.

The timestamped lines and progress markers print to **stderr**, the final report to stdout — so `--json` mode's stdout stays pure JSON regardless (see below), while a human watching the terminal still sees everything, with real ordering they can verify themselves rather than take on faith.

The banner really is the first thing printed, not just the first *intended* to be — the heavy `@opentelemetry/*` SDK chain (~434ms to load, measured directly) is imported lazily, only after the banner prints and the arguments/config are already validated, not as a top-level import. `--help` in particular never pays that cost at all: 40ms total, measured with `time -p`.

A failure is specific, not generic — e.g. a wrong credential fails immediately with the real HTTP status, not after waiting out the full timeout:

```
❌ read-log: query failed: Query failed: 401 Unauthorized
❌ read-metric: query failed: Query failed: 401 Unauthorized
```

`--json` emits the same four signals as one structured line (`{"write-log":{"pass":true,"detail":"..."}, ...}`) with nothing else on stdout — safe for a CI script to pipe straight into `JSON.parse()`, even if the ambient environment has `LOG_TO_CONSOLE=true` set (sovdev-logger's own console output is suppressed for the duration of the write step in `--json` mode). Exit code `0` only if all four signals pass, `1` otherwise.
