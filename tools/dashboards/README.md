# Sovdev Logger Dashboards

Grafana dashboard definitions owned by sovdev-logger itself, and a script to push them to any Grafana instance via its HTTP API.

## Why this exists

The local UIS stack already provisions a dashboard ("Sovdev Logger - Overview", uid `sovdev-metrics`) — but it ships from UIS's own infrastructure repo, not from sovdev-logger, and only covers metrics + basic logs. It has no trace visualization, no job-lifecycle tracking, and no service-dependency view, despite sovdev-logger emitting all of that data today. See [`INVESTIGATE-grafana-dashboard-definitions.md`](https://github.com/helpers-no/sovdev-logger/blob/main/website/docs/ai-developer/plans/completed/INVESTIGATE-grafana-dashboard-definitions.md) for the full audit.

This directory's dashboard (`sovdev-logger-overview.json`, uid `sovdev-logger-full`) is a **separate, sovdev-logger-owned dashboard** — it does not replace or overwrite the UIS-provisioned one. Both can coexist.

## Contents

| File | Purpose |
|------|---------|
| [`sovdev-logger-overview.json`](sovdev-logger-overview.json) | The dashboard itself — hand-authored, not generated from the schema (see [Q3] in the investigation for why) |
| [`push-dashboard.ts`](push-dashboard.ts) | Pushes a dashboard JSON file to a Grafana instance's `/api/dashboards/db` |
| [`configure-trace-correlation.ts`](configure-trace-correlation.ts) | Wires up bidirectional log↔trace correlation (Loki `trace_id` label → Tempo trace; Tempo trace → correlated Loki logs) |

## Usage

```bash
npm install   # once, installs tsx/typescript

# Local UIS
GRAFANA_URL=http://grafana.localhost GRAFANA_USER=admin GRAFANA_PASSWORD=SecretPassword1 \
  npx tsx push-dashboard.ts

# Grafana Cloud (once a dashboard-write Service Account token exists there --
# not set up yet, see the investigation's [Q4])
GRAFANA_URL=https://<stack>.grafana.net GRAFANA_TOKEN=glsa_xxx \
  npx tsx push-dashboard.ts
```

Re-running the push is safe — it's the same UID every time (`overwrite: true`), so it updates the existing dashboard rather than creating duplicates.

### Log↔trace correlation

```bash
GRAFANA_URL=http://grafana.localhost GRAFANA_USER=admin GRAFANA_PASSWORD=SecretPassword1 \
  npx tsx configure-trace-correlation.ts
```

Also safe to re-run — it removes any correlation it previously created before adding a fresh one, rather than accumulating duplicates (the Grafana Correlations API has no upsert of its own).

sovdev-logger's `trace_id` is a Loki **label**, not text embedded in the log line, so the older `derivedFields` datasource setting (line-text regex only) can't reach it — this uses Grafana's newer Correlations API instead, which links a named field (regardless of whether it's a label or line content) to a Tempo query. The reverse direction uses Tempo's own native `tracesToLogsV2` setting, a different, purpose-built mechanism.

## What's in the dashboard

- **`$service_name` template variable** — every panel is parameterized by it (multi-select, defaults to "All"), replacing what used to be a hardcoded service-name regex in the UIS-provisioned dashboard
- **Metrics** (ported from the existing dashboard): Active Integrations, Total Operations, Error Rate, Average Operation Duration
- **Operations / Errors / Error Rate / Avg Duration by Peer Service** (new, 4 panels) — one number per `peer_service` for each metric, using Grafana Stat panels' native multi-series display (no transform needed) — this is sovdev-logger's service-dependency data, already flowing through the existing metrics' labels, just never visualized before. (An earlier version tried a single merged table via instant Prometheus queries; that returned empty through this Grafana build's query pipeline for reasons not fully diagnosed — see the parent plan's "Post-completion fix" section.)
- **Job Lifecycle** (new) — a logs panel showing `log_type="job.status"`/`"job.progress"` entries in chronological order, so a batch job's start → progress → completion reads as a natural timeline
- **Recent Errors** / **Transaction Logs** (ported from the existing dashboard) — detailed Loki tables/logs for `log_type="transaction"` entries

Traces (Tempo) and log↔trace correlation are Phase 2 of the parent plan, not yet in this dashboard.
