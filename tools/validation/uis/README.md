# Sovdev Logger Verification Tools — Local UIS Backend

Language-agnostic bash tools that query a local UIS (Urbalurba Infrastructure Stack) observability stack — Loki, Prometheus, Tempo — directly via `kubectl`, and compare the results against a candidate language's E2E test output.

For the Grafana Cloud equivalent (TypeScript, HTTP Basic Auth instead of `kubectl`), see [`../grafana-cloud/`](../grafana-cloud/).

**See [Testing against UIS](https://sovdev-logger.sovereignsky.no/contributor/testing/uis) for the full, verified, step-by-step workflow.** This README documents the tools themselves; that page documents how they fit into standing up UIS and running a language's E2E test against it.

---

## Prerequisites

1. **Running inside the devcontainer** — these tools need `kubectl` access to the local cluster, plus `curl`, `jq`, `python3`.
2. **Monitoring stack running:**
   ```bash
   kubectl get pods -n monitoring
   # Should show: loki, prometheus, tempo, grafana, otel-collector pods
   ```
3. **Language implementation follows the standard E2E structure:**
   ```
   {language}/test/e2e/company-lookup/
   ├── run-test.sh
   ├── company-lookup.*
   ├── .env
   └── logs/
   ```

---

## Tools

| Script | Purpose | Usage |
|--------|---------|-------|
| [**query-loki.sh**](query-loki.sh) | Query Loki for logs; `--validate` for schema check, `--compare-with FILE` for exact entry-by-entry match against a log file | `./query-loki.sh sovdev-test-company-lookup-python --compare-with logs/dev.log` |
| [**query-prometheus.sh**](query-prometheus.sh) | Same, for Prometheus metrics | `./query-prometheus.sh sovdev-test-company-lookup-python --compare-with logs/dev.log` |
| [**query-tempo.sh**](query-tempo.sh) | Same, for Tempo traces | `./query-tempo.sh sovdev-test-company-lookup-python --compare-with logs/dev.log` |
| [**validate-log-format.sh**](validate-log-format.sh) | Validate a log file's format against the JSON Schema (wraps `../validators/validate-log-format.py`) | `./validate-log-format.sh {language}/test/e2e/company-lookup/logs/dev.log` |
| [**compare-with-master.sh**](compare-with-master.sh) | Field-by-field diff of a candidate language's `dev.log` against TypeScript's, for the same fixed scenario — the authoritative "does it match the reference implementation" check | `./compare-with-master.sh python` |
| [**run-company-lookup.sh**](run-company-lookup.sh) | Quick smoke test: runs the E2E app and validates file logs only, no backend queries | `./run-company-lookup.sh python` |

**Common flags on all three query scripts:**
- (no flag) — query only, returns raw data
- `--validate` — also validate the response against its JSON Schema
- `--compare-with FILE` — also cross-check every entry against a log file by `trace_id`/`event_id` (the strongest check — a real mismatch fails loudly, "found: yes" does not)
- `--json` — raw JSON output
- `--limit N`, `--time-range R` — query tuning

---

## The Verified Workflow

1. Run the language's E2E test (`{language}/test/e2e/company-lookup/run-test.sh`) — generates `logs/dev.log`.
2. `./validate-log-format.sh {language}/test/e2e/company-lookup/logs/dev.log` — fast, local, no backend needed.
3. `./query-loki.sh`, `./query-tempo.sh`, `./query-prometheus.sh`, each with `--compare-with` against that same log file — confirms the data actually reached every backend, exactly.
4. `./compare-with-master.sh {language}` — confirms the candidate's output matches TypeScript's, field by field (excluding per-run values like `timestamp`/`trace_id`/`session_id`).

**Note:** Prometheus metrics are cumulative counters — running the E2E test repeatedly against the same long-lived UIS instance without a reset will show counts higher than one run's worth. This isn't a bug; check within a couple of minutes of a single run, or expect the counts to include prior runs.

## Integration with Validators

Query scripts call the Python validators in [`../validators/`](../validators/) automatically when `--validate`/`--compare-with` are used — see that directory's README for the validators themselves, and [`../schemas/`](../schemas/) for the JSON Schemas they validate against.

```
tools/validation/uis/query-loki.sh --compare-with logs/dev.log
              │
              ↓ (pipes response to)
tools/validation/validators/validate-loki-consistency.py
              │
              ↓ (loads)
tools/validation/schemas/loki-response-schema.json
```

---

**Last Updated:** 2026-07-11
