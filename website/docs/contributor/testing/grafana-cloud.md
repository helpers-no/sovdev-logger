---
title: "Grafana Cloud"
sidebar_label: "Grafana Cloud"
sidebar_position: 2
description: "Verify sovdev-logger against Grafana Cloud's hosted Loki/Tempo/Mimir — no local Kubernetes needed."
---

# Testing against Grafana Cloud

:::note Verified
Fully verified end-to-end against a live stack: real E2E test telemetry, pushed via OTLP, confirmed landing correctly in all three signals with exact `--compare-with` data matching (Loki 17/17, Tempo 4/4, Prometheus 5/5). See [`INVESTIGATE-grafana-cloud-validator.md`](../../ai-developer/plans/completed/INVESTIGATE-grafana-cloud-validator.md) for the full history.
:::

Grafana Cloud's free tier hosts the same Loki (logs), Tempo (traces), and Mimir (Prometheus-compatible metrics) that [UIS](uis.md) runs locally — same query APIs, no self-hosted Kubernetes cluster required. This is the "I don't want to run Rancher Desktop just to try this library" path.

Unlike UIS, verification tooling for Grafana Cloud is written in **TypeScript, not bash** — see the investigation doc above for why: every bug found in the bash-based `query-loki.sh` this session traced back to bash's lack of real JSON handling, not anything specific to Kubernetes.

## 1. Sign up

[grafana.com/products/cloud/free-tier](https://grafana.com/products/cloud/free-tier/) → sign up (no credit card required). Direct signup link: [grafana.com/auth/sign-up/create-user](https://grafana.com/auth/sign-up/create-user/?pg=prod-cloud-free-tier&plcmt=hero-btn&cta=free).

Free tier: 14-day retention across logs/traces/metrics, with quotas generous enough for a repeatedly-run test (50GB logs/mo, 50GB traces/mo, 10K active series).

## 2. Create two Access Policies (least-privilege, confirmed working)

Grafana Cloud's ingestion and query sides use separate credentials. In the Cloud Portal, go to **Security → Access Policies** — the URL is `https://grafana.com/orgs/<your-org-slug>/access-policies`, where `<your-org-slug>` is whatever you named your own Grafana Cloud org when you signed up (this project's org happens to be named `urbalurba`, after the local UIS stack's own name — that's not a Grafana Cloud term, just the maintainer's own choice, and yours will be different unless you deliberately reuse it). Click **Create access policy** and create two, each scoped to your stack specifically (**Realm: pick your stack, not "all stacks"**):

1. **`sovdev-logger-ingest`** — scopes: `metrics:write`, `logs:write`, `traces:write`. Used by the app under test to push OTLP telemetry.
2. **`sovdev-logger-verify`** — scopes: `metrics:read`, `logs:read`, `traces:read`. Used by the query tooling below to read it back.

The "Create new access policy" form, confirmed against a real one: **Display name** and a separate **Name** field ("used as a unique identifier") — set both the same, no reason for them to differ. **Realms** is a multi-select dropdown (not free text) — pick your one stack specifically. **Scopes** is a table: rows are resources (`metrics`, `logs`, `traces`, `profiles`, `alerts`, `rules`, `accesspolicies`), columns are `Read`/`Write`/`Delete` checkboxes — check only the cells you actually need (e.g. just `Write` for `metrics`/`logs`/`traces` on the ingest policy). On each policy, click **Add token**, name it to match the policy, and copy the value immediately — it's shown once.

**Creating the access policies and generating tokens is something you have to do yourself.** Two separate Claude Code instances both independently declined to click "Create"/"Add token" on our behalf, even with explicit authorization — modifying access controls and minting long-lived credentials is treated as a hard line, not an "are you sure" prompt. Budget for doing this step by hand.

## 3. Find your endpoint URLs and Instance IDs — confirmed non-uniform, don't guess

Get here via your stack's management page — `https://grafana.com/orgs/<your-org-slug>/stacks/<stack-id>` (found by clicking your stack's name in the left nav, under **GRAFANA CLOUD**, not under Security). The number in that URL is Grafana's own stack ID, and it's the **same number** as the OTLP Instance ID below — confirmed directly (this project's stack: `.../stacks/484308`, OTLP Instance ID `484308`).

Each service has its own card on that page with a **Configure** or **Details** link to its own connection page, its own hostname, and its own numeric **Instance ID** (used as the HTTP Basic Auth username; the token from step 2 is the password). Confirmed on a real stack — the naming is **not** uniform, don't assume a shared pattern:

| Signal | Example host | Instance ID field |
|---|---|---|
| OTLP ingestion (all 3 signals, one endpoint) | `https://otlp-gateway-prod-<region>.grafana.net/otlp` — reached via the **OpenTelemetry** card's **Configure** link, page URL `.../stacks/<stack-id>/otlp-info` | its own separate Instance ID (same number as the stack ID itself), distinct from the three below |
| Loki (logs) | `https://logs-prod-<region>.grafana.net` | shown on the Loki connection page |
| Tempo (traces) | `https://tempo-<region>.grafana.net` (no `-prod`, no numeric suffix — genuinely different shape from the other two) | shown on the Tempo connection page |
| Prometheus/Mimir (metrics) | `https://prometheus-prod-01-<region>.grafana.net` | shown on the Prometheus connection page |

The OTLP connection page also offers to generate a token directly ("Password / API Token — Generate now") — skip it; it's a simpler but less-scoped path than the Access Policy tokens from step 2. Use the Access Policy token as the password instead.

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

Each pipes Grafana Cloud's response to the matching `tools/validation/validators/validate-*-consistency.py` script UIS's `--compare-with` already uses — exact `trace_id`/`event_id` matching against the source log file, not just "service found." Loki and Prometheus need no transformation (Grafana Cloud's hosted APIs return the identical response shape as self-hosted). Tempo does: `query-tempo.ts` fetches each trace's full span detail and converts base64 span/trace IDs to hex, replicating exactly what the original `query-tempo.sh` did, to match the `spanSets[].spans[]` shape the Python validator expects.

Confirmed passing against real E2E test output: Loki 17/17, Tempo 4/4 (may need a retry — traces can take a few seconds to become searchable after ingestion, same as UIS), Prometheus 5/5.

## CI's own consistency check

As of 2026-07-14, `.github/workflows/ci.yml`'s `grafana-cloud-consistency` job runs a two-stage check automatically, on every push/PR — not just a build/lint check, real proof against real Grafana Cloud data:

1. **Fail fast**: [`sovdev-selftest --backend grafana-cloud`](selftest-cli.md) — the exact tool a real customer runs to verify their own connection. If a basic write+read-back against this backend doesn't work, there's no point spending ~2 minutes on the full E2E test below.
2. **Full consistency check**: the "write to file, validate the file, read back, diff against the file" sequence from steps 6–7 above, only if step 1 passes.

This is the gate `PLANS.md` refers to: a change to `typescript/src/**.ts` doesn't get merged unless both stages pass for real.

**Dedicated CI-only credentials, not the maintainer's personal ones.** Same reasoning as every other Access Policy in this project (one per system, least-privilege): CI got its own pair, entirely separate from `sovdev-logger-ingest`/`sovdev-logger-verify` above.

1. **`sovdev-ci-ingest`** — `logs:write`, `metrics:write`, `traces:write`, no read at all. Same shape as any other ingest policy.
2. **`sovdev-ci-verify`** — `logs:read`, `metrics:read`, `traces:read`, **LBAC-scoped** with a label selector:
   ```
   service_name=~"^sovdev-ci-company-lookup.*"
   ```
   **Use the regex operator (`=~`), not exact-match (`=`).** Confirmed the hard way: an exact-match selector on `sovdev-ci-company-lookup` alone won't match anything with a suffix, and this project's E2E test's own service name is used as-is (no suffix today, but the regex form is what the Access Policy's own "Label selectors" section expects for prefix-style matching — see the ⚠️ below for where this control actually lives in the portal). Also confirmed live: label selectors only apply to `logs`/`metrics` reads, never `traces` — Grafana Cloud's own UI states this directly ("Available only with read permissions for metrics and logs"). `traces:read` on this policy stays stack-wide; accepted as a known, non-blocking gap.

   ⚠️ **The "Add label selector" control doesn't appear until scopes are checked, and it's collapsed by default.** After checking `logs:read`/`metrics:read`, look for a collapsed **"Label selectors (0)"** section below the Scopes table — not a per-checkbox button next to each row, as you might expect. Click it to expand, then **Add label selector**.

CI's E2E test run uses a dedicated `service_name` too — `sovdev-ci-company-lookup`, distinct from the maintainer's own manual test runs (`sovdev-test-company-lookup-typescript-grafana-cloud`) — so the two never mix in the shared dashboard, and the LBAC selector above stays meaningfully scoped.

**Stored as two individual GitHub Actions secrets**, not one bundled file: `SOVDEV_CI_INGEST_TOKEN` and `SOVDEV_CI_VERIFY_TOKEN`. Everything else the workflow needs (the stack-wide OTLP/Loki/Prometheus/Tempo URLs and Instance IDs from step 3 above) is hardcoded directly in `ci.yml` — those aren't secrets, they're already published in plain text in this very doc and in `.env.example`. Deliberately not one blob secret: rotating a single token shouldn't require re-pasting values that didn't change, and GitHub secrets are opaque once saved (you can't view or diff them again, only overwrite) — bundling increases the blast radius of a copy-paste mistake, not reduces it.

**To rotate**: mint a new token on the same Access Policy (or a fresh Access Policy, if rotating the policy itself) in the portal, then:
```bash
echo -n "<new-token>" | gh secret set SOVDEV_CI_INGEST_TOKEN --repo helpers-no/sovdev-logger
echo -n "<new-token>" | gh secret set SOVDEV_CI_VERIFY_TOKEN --repo helpers-no/sovdev-logger
```

**To test the CI flow locally before trusting it in GitHub Actions**: see [`tools/validation/grafana-cloud/README.md`](https://github.com/helpers-no/sovdev-logger/tree/main/tools/validation/grafana-cloud)'s `full-consistency-check.sh` section — it accepts `--env-file` so you can point the E2E test step at any credentials, including a local copy of CI's own (kept in `terchris/sovdev-ci-grafana.env`, gitignored, not part of this repo).

## Troubleshooting

- **Access policy / token creation**: has to be done by a human — see step 2.
- **Hyphens in env var names**: silently break `source` — see step 4.
- **A query path that looks right in the portal isn't necessarily the real public API path**: see step 5 — Grafana's own connection-page labels for Tempo and Prometheus were misleading in different directions. Don't extend this tooling to a new signal or region without checking with `probe-tempo-prometheus.ts`'s pattern first.
- **`401` with `"no credentials provided"` (not an invalid-credentials message)**: an unquoted `OTEL_EXPORTER_OTLP_HEADERS` value containing a space got word-split by bash `source`, truncating the token entirely — see step 6.
- **`query-loki.ts --compare-with` reports entries "missing" that you know were just pushed**: check you're not hitting the default `--limit` (auto-bumped based on the file's entry count for `query-loki.ts`, but only above whatever `--limit` you passed manually — if in doubt, don't pass `--limit` at all and let the auto-calculation apply).
- **Everything reports `0 matched` even after a clean-looking test run**: run `bash run-test.sh` with `OTEL_LOG_LEVEL=debug` and grep the output for `unauthorized`/`401`/`OTLPExporterError` — a clean-looking `✅ ... flushed successfully` message does **not** guarantee the data was actually accepted; the SDK doesn't surface OTLP's `partialSuccess`/rejection info anywhere by default.
