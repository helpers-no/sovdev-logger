---
title: "Grafana Cloud"
sidebar_label: "Grafana Cloud"
sidebar_position: 2
description: "Verify sovdev-logger against Grafana Cloud's hosted Loki/Tempo/Mimir — no local Kubernetes needed."
---

# Testing against Grafana Cloud

:::note Verified
Fully verified end-to-end against a live stack: real E2E test telemetry, pushed via OTLP, confirmed landing correctly in all three signals with exact `--compare-with` data matching (Loki 17/17, Tempo 4/4, Prometheus 5/5). See [`INVESTIGATE-grafana-cloud-validator.md`](../../ai-developer/plans/backlog/INVESTIGATE-grafana-cloud-validator.md) for the full history.
:::

Grafana Cloud's free tier hosts the same Loki (logs), Tempo (traces), and Mimir (Prometheus-compatible metrics) that [UIS](uis.md) runs locally — same query APIs, no self-hosted Kubernetes cluster required. This is the "I don't want to run Rancher Desktop just to try this library" path.

Unlike UIS, verification tooling for Grafana Cloud is written in **TypeScript, not bash** — see the investigation doc above for why: every bug found in the bash-based `query-loki.sh` this session traced back to bash's lack of real JSON handling, not anything specific to Kubernetes.

## 1. Sign up

[grafana.com/products/cloud/free-tier](https://grafana.com/products/cloud/free-tier/) → sign up (no credit card required). Direct signup link: [grafana.com/auth/sign-up/create-user](https://grafana.com/auth/sign-up/create-user/?pg=prod-cloud-free-tier&plcmt=hero-btn&cta=free).

Free tier: 14-day retention across logs/traces/metrics, with quotas generous enough for a repeatedly-run test (50GB logs/mo, 50GB traces/mo, 10K active series).

## 2. Create two Access Policies (least-privilege, confirmed working)

Grafana Cloud's ingestion and query sides use separate credentials. In the Cloud Portal, go to **Security → Access Policies → Create access policy** and create two, each scoped to your stack specifically (**Realm: pick your stack, not "all stacks"**):

1. **`sovdev-logger-ingest`** — scopes: `metrics:write`, `logs:write`, `traces:write`. Used by the app under test to push OTLP telemetry.
2. **`sovdev-logger-verify`** — scopes: `metrics:read`, `logs:read`, `traces:read`. Used by the query tooling below to read it back.

Scope names are a Read/Write/Delete matrix per resource, `<resource>:<action>` — confirmed directly from the picker (logs also has a `logs:delete` scope, not needed here). On each policy, click **Add token**, name it to match the policy, and copy the value immediately — it's shown once.

**Creating the access policies and generating tokens is something you have to do yourself.** Two separate Claude Code instances both independently declined to click "Create"/"Add token" on our behalf, even with explicit authorization — modifying access controls and minting long-lived credentials is treated as a hard line, not an "are you sure" prompt. Budget for doing this step by hand.

## 3. Find your endpoint URLs and Instance IDs — confirmed non-uniform, don't guess

Each service has its own connection page in the portal with its own hostname and numeric **Instance ID** (used as the HTTP Basic Auth username; the token from step 2 is the password). Confirmed on a real stack — the naming is **not** uniform, don't assume a shared pattern:

| Signal | Example host | Instance ID field |
|---|---|---|
| OTLP ingestion (all 3 signals, one endpoint) | `https://otlp-gateway-prod-<region>.grafana.net/otlp` | its own separate Instance ID, distinct from the three below |
| Loki (logs) | `https://logs-prod-<region>.grafana.net` | shown on the Loki connection page |
| Tempo (traces) | `https://tempo-<region>.grafana.net` (no `-prod`, no numeric suffix — genuinely different shape from the other two) | shown on the Tempo connection page |
| Prometheus/Mimir (metrics) | `https://prometheus-prod-01-<region>.grafana.net` | shown on the Prometheus connection page |

## 4. Configure `tools/validation/grafana/.env`

```bash
cd tools/validation/grafana
cp .env.example .env
```

Fill in `.env` with the ingest token, verify token, and each signal's URL + Instance ID from steps 2–3. See `.env.example` for the exact variable names (`GRAFANA_CLOUD_LOKI_URL`, `GRAFANA_CLOUD_LOKI_INSTANCE_ID`, etc.) — all `GRAFANA_CLOUD_*`, no other convention.

**Gotcha already hit once**: environment variable names can't contain hyphens (`SOVDEV-LOGGER-VERIFY-TOKEN=...` silently fails to export under bash `source` — bash tries to run it as a command instead). Use underscores throughout, matching `.env.example`.

## 5. Verify the connection actually works

```bash
cd tools/validation/grafana
npm install   # first time only
set -a && source .env && set +a
npx tsx check-connection.ts
```

This checks that every variable is set and sane (valid `https://` URL, numeric Instance ID, token long enough and has the expected `glc_` prefix) — then makes a **real** query against all three signals to confirm auth and the query path actually work, not just that the variables look plausible. Confirmed working, all 13 checks pass on a real stack (numbers will differ once you've actually pushed data — see step 7):

```
[11] ✅ Loki connection: status=success, N stream(s) matched
[12] ✅ Tempo connection: search succeeded, N trace(s) matched
[13] ✅ Prometheus connection: status=success, resultType=vector, N series matched
```

Getting here took determining the real query paths empirically rather than trusting the portal's own connection-page labels: `tools/validation/grafana/probe-tempo-prometheus.ts` tested both a plausible-looking variant and the portal's literal displayed path for each of Tempo and Prometheus. Result: Tempo needs a `/tempo` prefix (`/tempo/api/search`, not plain `/api/search` — the opposite of what was guessed going in), and Prometheus needs Grafana Cloud's Cortex-style `/api/prom` prefix (`/api/prom/api/v1/query`, not plain `/api/v1/query` — this one matched the guess). Neither was assumed into the final scripts without that check.

## 6. Wire up ingestion for an E2E test (without touching your UIS config)

```bash
cd /path/to/sovdev-logger
set -a && source tools/validation/grafana/.env && set +a
npx tsx tools/validation/grafana/generate-e2e-env.ts \
  typescript/test/e2e/company-lookup/.env.grafana-cloud \
  sovdev-test-company-lookup-typescript-grafana-cloud
```

This writes a **sibling** `.env.grafana-cloud`, never touching the existing `.env` (which stays pointed at local UIS). `run-test.sh` accepts `--env-file` so you can pick which backend's config to load per run:

```bash
cd typescript/test/e2e/company-lookup
bash run-test.sh --skip-validation --env-file .env.grafana-cloud   # Grafana Cloud
bash run-test.sh --skip-validation                                  # local UIS, unchanged
```

**The generated `OTEL_EXPORTER_OTLP_HEADERS` value must be quoted** — `generate-e2e-env.ts` already does this, but if you ever hand-edit this file: `Authorization=Basic <token>` contains a space, and an unquoted value with a space gets word-split by bash's `source`, silently truncating everything after the space. This produced a genuinely confusing `401 "no credentials provided"` — not "bad token," no token reached the request at all. Same root cause as the old JSON-quoting bug this project already fixed once, just triggered by a space instead of embedded quotes. If you ever see this specific 401 message, check quoting first.

## 7. Query and verify test output

```bash
cd tools/validation/grafana
npx tsx query-loki.ts <service-name> --compare-with /path/to/logs/dev.log
npx tsx query-tempo.ts <service-name> --compare-with /path/to/logs/dev.log
npx tsx query-prometheus.ts <service-name> --compare-with /path/to/logs/dev.log
```

Each pipes Grafana Cloud's response to the matching `specification/tests/validate-*-consistency.py` script UIS's `--compare-with` already uses — exact `trace_id`/`event_id` matching against the source log file, not just "service found." Loki and Prometheus need no transformation (Grafana Cloud's hosted APIs return the identical response shape as self-hosted). Tempo does: `query-tempo.ts` fetches each trace's full span detail and converts base64 span/trace IDs to hex, replicating exactly what the original `query-tempo.sh` did, to match the `spanSets[].spans[]` shape the Python validator expects.

Confirmed passing against real E2E test output: Loki 17/17, Tempo 4/4 (may need a retry — traces can take a few seconds to become searchable after ingestion, same as UIS), Prometheus 5/5.

## Troubleshooting

- **Access policy / token creation**: has to be done by a human — see step 2.
- **Hyphens in env var names**: silently break `source` — see step 4.
- **A query path that looks right in the portal isn't necessarily the real public API path**: see step 5 — Grafana's own connection-page labels for Tempo and Prometheus were misleading in different directions. Don't extend this tooling to a new signal or region without checking with `probe-tempo-prometheus.ts`'s pattern first.
- **`401` with `"no credentials provided"` (not an invalid-credentials message)**: an unquoted `OTEL_EXPORTER_OTLP_HEADERS` value containing a space got word-split by bash `source`, truncating the token entirely — see step 6.
- **`query-loki.ts --compare-with` reports entries "missing" that you know were just pushed**: check you're not hitting the default `--limit` (auto-bumped based on the file's entry count for `query-loki.ts`, but only above whatever `--limit` you passed manually — if in doubt, don't pass `--limit` at all and let the auto-calculation apply).
- **Everything reports `0 matched` even after a clean-looking test run**: run `bash run-test.sh` with `OTEL_LOG_LEVEL=debug` and grep the output for `unauthorized`/`401`/`OTLPExporterError` — a clean-looking `✅ ... flushed successfully` message does **not** guarantee the data was actually accepted; the SDK doesn't surface OTLP's `partialSuccess`/rejection info anywhere by default.
