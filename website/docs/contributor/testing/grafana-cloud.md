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

The "Create new access policy" form, confirmed against a real one: **Display name** and a separate **Name** field ("used as a unique identifier") — set both the same, no reason for them to differ. **Realms** is a multi-select dropdown (not free text) — pick your one stack specifically; this scopes the policy to *which stack* it applies to, a separate concept from the **Scopes** table's `Read`/`Write`/`Delete` checkboxes (which resource *actions* are allowed) and from label selectors below (*which data within that stack*, read-only — see the next section). **Scopes** is a table: rows are resources (`metrics`, `logs`, `traces`, `profiles`, `alerts`, `rules`, `accesspolicies`), columns are `Read`/`Write`/`Delete` checkboxes — check only the cells you actually need (e.g. just `Write` for `metrics`/`logs`/`traces` on the ingest policy).

Click **Create access policy**, then on the resulting policy card click **Add token**, name it to match the policy, and copy the value immediately — it's shown once. **The policy card shows "0 tokens" until you do this — creating the Access Policy alone doesn't produce a usable credential**, the token is a separate object minted on top of it.

**If you want this verify token scoped to just one system's data** (rather than the stack-wide, unrestricted `sovdev-logger-verify` this step produces by default) — e.g. for a new customer's own token, or CI's — see "CI's own consistency check" below for the exact label-selector steps (the "Label selectors" section, the regex-vs-exact-match gotcha, and the traces limitation) — the same steps apply regardless of whose token it is, not just CI's.

**Creating the access policies and generating tokens is something you have to do yourself.** Two separate Claude Code instances both independently declined to click "Create"/"Add token" on our behalf, even with explicit authorization — modifying access controls and minting long-lived credentials is treated as a hard line, not an "are you sure" prompt. Budget for doing this step by hand.

## Known limitation: write tokens aren't service_name-restricted

**Confirmed directly (2026-07-14) and by Grafana's own documentation**: an ingest token (`*-ingest`, `logs:write`/`metrics:write`/`traces:write`) can write data under **any** `service_name`, not just the one it's nominally issued for. Tested empirically: using `sovdev-ci-ingest`'s token, a log entry was written and confirmed landing in Grafana Cloud under `service_name="totally-different-spoofed-service"` — a name that has nothing to do with what that token is for.

This isn't a misconfiguration — Grafana Cloud's Label-Based Access Control (used throughout this project for `*-verify` tokens, e.g. [step 2](#2-create-two-access-policies-least-privilege-confirmed-working) above and the CI setup below) **only applies to read scopes, never write**. Confirmed by two independent first-party sources:
- [LBAC docs](https://grafana.com/docs/grafana-cloud/security-and-account-management/authentication-and-permissions/access-policies/label-access-policies/): *"Label selectors for access policies can only be used with read permission for metrics and logs."*
- [Grafana Enterprise Metrics/Logs docs](https://grafana.com/docs/enterprise-metrics/latest/manage/tenant-management/lbac/): *"GEM does not enforce label-based access control on the write requests... a `metrics:write` scope... allows clients to push any metrics without restrictions regarding the labels."* (GEL logs docs state the identical thing for `logs:write`.)

**Practical consequence**: every ingest token in this project (`ollacrm-ingest`, `sovdev-ci-ingest`, `sovdev-logger-ingest`) can, if leaked, write fabricated data claiming to be *any* system in the shared stack — not just its own. This does **not** compromise read confidentiality (each system's `*-verify` token stays correctly LBAC-scoped to its own data, confirmed throughout this doc and `INVESTIGATE-developer-first-onboarding.md`'s [Q6]) — but it does mean the "one token per system, contained blast radius" story only holds for reads, not writes. A leaked ingest token's write-side blast radius is the whole shared stack.

**No portal-level fix exists.** Restricting this would need enforcement *outside* Grafana Cloud's own Access Policy model entirely — e.g. an OTel Collector or Grafana Alloy instance sitting in front of ingestion, running its own attribute/relabel processor keyed to which credential presented the request. That's real new infrastructure, not a configuration change, and hasn't been built or scoped for this project. Until/unless that's decided as worth building, treat this as an accepted, documented limitation — not a gap that's been silently overlooked.

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

**Dedicated CI-only credentials, not the maintainer's personal ones.** Same reasoning as every other Access Policy in this project (one per system, least-privilege): CI got its own pair, entirely separate from `sovdev-logger-ingest`/`sovdev-logger-verify` above. The label-selector mechanics below (points 1–2) are general-purpose — the same steps apply to scoping *any* system's verify token, not just CI's; this is just where they're written down in full, since CI's own setup is where they were first worked out in practice.

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

### The `grafana-cloud-consistency` CI job specifically

- **`Quick connection check (sovdev-selftest)` step fails**: this is the fail-fast stage — if it fails, the full E2E test never runs. Almost always one of: (a) `SOVDEV_CI_INGEST_TOKEN`/`SOVDEV_CI_VERIFY_TOKEN` rotated or revoked in the portal without updating the GitHub secret (see "To rotate" above), (b) the `sovdev-ci-verify` Access Policy's label selector got edited/removed — re-check it's still the regex form (`service_name=~"^sovdev-ci-company-lookup.*"`), not exact-match, (c) a genuine regression in `sovdev_initialize`/`sovdev_log`/`sovdev_shutdown` itself — check the step's own log output for the four signals (write-log/write-metric/read-log/read-metric), whichever one is `❌` tells you which half (write vs. read) broke.
- **`Run full consistency check` step fails after the selftest step passed**: the connection itself is fine, so look at which specific backend failed in the step's output (Loki/Prometheus/Tempo each print their own `✅`/`❌` block) — a real regression in `logger.ts`'s field-population logic will usually show up here as a *mismatch* (a field present in the file but different in the backend), not a missing-entry error, which is a more precise signal than the selftest step gives.
- **Tempo fails after all 6 retry attempts (~60s)**: either a real regression, or Grafana Cloud's indexing was unusually slow that run. Re-run the job once (`gh run rerun 29319170409 --repo helpers-no/sovdev-logger --failed`, or the "Re-run failed jobs" button in the GitHub UI) before assuming it's a real bug — Tempo's indexing latency isn't perfectly bounded, and 60s was chosen from observed behavior, not a documented SLA.
- **The job fails with `Missing required env vars: ...`**: one of the `GRAFANA_CLOUD_*` secrets/hardcoded values in `ci.yml`'s `env:` block is missing or misspelled — compare against `full-consistency-check.sh`'s own `REQUIRED_VARS` list (includes `GRAFANA_CLOUD_TEMPO_URL`/`GRAFANA_CLOUD_TEMPO_INSTANCE_ID`, easy to forget since `sovdev-selftest` itself doesn't need them).
- **Works locally with `terchris/sovdev-ci-grafana.env` but fails only in CI**: check the two secrets actually match that file's values — `gh secret list --repo helpers-no/sovdev-logger` shows *when* each was last updated, not its value, so a stale secret from before a token rotation is a real, silent-until-it-fails possibility.
