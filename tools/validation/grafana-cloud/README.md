# Sovdev Logger Verification Tools — Grafana Cloud Backend

TypeScript tools that query Grafana Cloud's hosted Loki, Prometheus, and Tempo directly via HTTP Basic Auth, and compare the results against a candidate language's E2E test output.

For the local UIS equivalent (bash, `kubectl` instead of HTTP), see [`../uis/`](../uis/).

---

## Prerequisites

1. **`.env`** — copy `.env.example`, fill in real values from your Grafana Cloud portal (Security → Access Policies for tokens; each stack's Loki/Tempo/Prometheus connection page for the base URLs and Instance IDs).
2. **`npm install`** in this directory — installs `tsx`/`typescript`/`@types/node`.
3. **Python 3.7+ with `jsonschema`** — the comparison logic lives in `../validators/`, unchanged regardless of backend.

---

## Tools

| Script | Purpose | Usage |
|--------|---------|-------|
| [**query-loki.ts**](query-loki.ts) | Query Loki for logs; `--compare-with FILE` for exact entry-by-entry match against a log file | `npx tsx query-loki.ts <service-name> --compare-with logs/dev.log` |
| [**query-prometheus.ts**](query-prometheus.ts) | Same, for Prometheus metrics | `npx tsx query-prometheus.ts <service-name> --compare-with logs/dev.log` |
| [**query-tempo.ts**](query-tempo.ts) | Same, for Tempo traces | `npx tsx query-tempo.ts <service-name> --compare-with logs/dev.log` |
| [**check-connection.ts**](check-connection.ts) | Quick connectivity/credential smoke test, no comparison | `npx tsx check-connection.ts` |
| [**probe-otlp-ingest.ts**](probe-otlp-ingest.ts), [**probe-tempo-prometheus.ts**](probe-tempo-prometheus.ts) | One-off debugging probes used while first mapping this stack's endpoints — see `INVESTIGATE-grafana-cloud-validator.md` | ad hoc |
| [**generate-e2e-env.ts**](generate-e2e-env.ts) | Generates `typescript/test/e2e/company-lookup/.env.grafana-cloud` from this directory's `.env` | `npx tsx generate-e2e-env.ts` |
| [**full-consistency-check.sh**](full-consistency-check.sh) | **The single command for "does this actually work end-to-end."** Runs the E2E test, validates the log file, then runs all three `--compare-with` checks in sequence — see below. | `./full-consistency-check.sh [--env-file PATH]` |

**Common flags on all three query scripts:** `--json`, `--compare-with FILE` (the strongest check — cross-checks every entry against a log file by `trace_id`/`event_id`, real mismatches fail loudly), `--limit N`, `--time-range R`.

---

## `full-consistency-check.sh` — the real verification flow, in one command

Matches how this project's maintainer originally verified changes by hand: write to a local file first (a ground truth you can inspect directly), validate the file, then read back from each backend and diff the response against that file — not just check that a query returned "something."

```bash
./full-consistency-check.sh
```

1. Runs `typescript/test/e2e/company-lookup`'s E2E test against Grafana Cloud — generates `logs/dev.log`.
2. Validates `dev.log`'s format against the JSON Schema.
3. Queries Loki, Prometheus, and Tempo, each with `--compare-with` against that same file. Tempo's search index lags behind Loki/Prometheus (confirmed empirically) — this step polls with backoff (up to ~60s) rather than failing on the first attempt.

Exit code 0 only if every step passes. **This is the gate referenced in `PLANS.md`: before a change to `typescript/src/**.ts` is pushed to main, this script must exit 0** — it now runs for real in CI too, see below.

By default it uses your own personal dev credentials (`.env` in this directory, `.env.grafana-cloud` in the E2E test directory). The `GRAFANA_CLOUD_*` env vars must already be present in the environment before calling it — it never sources a `.env` file itself, so it can't silently override credentials you set up on purpose. Use `--env-file PATH` to point the E2E test step at different application credentials (e.g. CI's own).

## CI's own consistency check

`.github/workflows/ci.yml`'s `grafana-cloud-consistency` job runs a two-stage check on every push/PR, using dedicated CI-only credentials (`sovdev-ci-ingest`/`sovdev-ci-verify`) — entirely separate from the maintainer's personal dev keys and from any customer's, same reasoning as every other Access Policy in this project:

1. **Fail fast**: `sovdev-selftest --backend grafana-cloud` — the exact tool a real customer runs to verify their own connection. No point spending ~2 minutes on the full E2E test if a basic write+read-back against this same backend doesn't even work.
2. **Full consistency check**: this script, only if step 1 passes.

See [Testing against Grafana Cloud](https://sovdev-logger.sovereignsky.no/contributor/testing/grafana-cloud)'s "CI's own consistency check" section for the full setup story (how the keys were created, how they're stored, how to rotate them).
