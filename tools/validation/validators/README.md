# Sovdev Logger Validation Scripts

This directory contains **Python validation scripts** that verify log formats, backend responses, and data consistency across the sovdev-logger observability stack. Backend-agnostic: called by both the local-UIS bash tools (`../uis/`) and the Grafana Cloud TypeScript tools (`../grafana-cloud/`) — the fetch/auth layer differs per backend, but the comparison logic here never does.

## Purpose

These validators ensure:
- Log files conform to JSON Schema specifications
- Backend APIs (Loki, Prometheus, Tempo) store data correctly with snake_case fields
- Data consistency between file logs and observability backends (Loki, Prometheus, Tempo)
- All telemetry data is properly exported via OTLP

---

## Prerequisites

1. **Python 3.7+ with jsonschema library:**
   ```bash
   pip install jsonschema
   ```

2. **JSON Schema files are available:**
   ```bash
   ls -la ../schemas/
   # Should show: log-entry-schema.json, loki-response-schema.json,
   #              prometheus-response-schema.json, tempo-response-schema.json
   ```

3. **For consistency validators:** Log files and backend query responses available

---

## Quick Reference

| Script | Purpose | Usage | Input | Output |
|--------|---------|-------|-------|--------|
| [**validate-log-format.py**](validate-log-format.py) | Validate log file format against schema | `python3 validate-log-format.py <logfile>` | NDJSON log file | Schema compliance + custom rules |
| [**validate-loki-response.py**](validate-loki-response.py) | Validate Loki API response against schema | `python3 validate-loki-response.py <response.json>` | Loki query response | Schema + snake_case validation |
| [**validate-prometheus-response.py**](validate-prometheus-response.py) | Validate Prometheus API response against schema | `python3 validate-prometheus-response.py <response.json>` | Prometheus query response | Schema + snake_case labels |
| [**validate-tempo-response.py**](validate-tempo-response.py) | Validate Tempo API response against schema | `python3 validate-tempo-response.py <response.json>` | Tempo search response | Schema + trace ID format |
| [**validate-loki-consistency.py**](validate-loki-consistency.py) | Cross-validate file logs vs Loki backend | `python3 validate-loki-consistency.py <logfile> <loki-response.json>` | Log file + Loki response | Consistency report |
| [**validate-prometheus-consistency.py**](validate-prometheus-consistency.py) | Cross-validate file logs vs Prometheus metrics | `python3 validate-prometheus-consistency.py <logfile> <prom-response.json>` | Log file + Prometheus response | Metrics match report |
| [**validate-tempo-consistency.py**](validate-tempo-consistency.py) | Cross-validate file trace_ids vs Tempo traces | `python3 validate-tempo-consistency.py <logfile> <tempo-response.json>` | Log file + Tempo response | Trace ID match report |
| [**compare-log-files.py**](compare-log-files.py) | Field-by-field diff between two languages' log output for the same scenario | called by [`../uis/compare-with-master.sh`](../uis/compare-with-master.sh) | Two log files | Match/mismatch report |

**Common options for all validators:**
- `--json` - Output JSON format for automation
- `--help` - Show usage information
- `-` - Read from stdin (for piping query results)

**Called by:**
- `../uis/query-loki.sh`, `query-prometheus.sh`, `query-tempo.sh` via their `--validate`/`--compare-with` flags
- `../uis/validate-log-format.sh` (direct wrapper around `validate-log-format.py`)
- `../grafana-cloud/query-loki.ts`, `query-prometheus.ts`, `query-tempo.ts` via `lib/consistency-check.ts`, which pipes JSON to these same scripts — the comparison engine is never reimplemented per-backend

---

## Usage Examples

**Note:** These examples show **manual direct usage** of validators for debugging and custom workflows. For standard validation, use the query scripts' `--validate` and `--compare-with` flags instead — see [`../uis/README.md`](../uis/README.md).

### Schema Validation

```bash
# Validate log file format
python3 validate-log-format.py /workspace/python/test/e2e/company-lookup/logs/dev.log

# Validate error log (strict mode - ERROR logs only)
python3 validate-log-format.py /workspace/python/test/e2e/company-lookup/logs/error.log --error-log

# Validate Loki response (piped from query)
../uis/query-loki.sh sovdev-test-company-lookup-python --json | python3 validate-loki-response.py -
```

### Consistency Validation

```bash
# Cross-validate file logs vs Loki backend
../uis/query-loki.sh sovdev-test-company-lookup-python --json | \
  python3 validate-loki-consistency.py logs/dev.log -
```

### JSON Output for Automation

```bash
python3 validate-log-format.py logs/dev.log --json > validation-result.json
cat validation-result.json | jq '.valid'  # true/false
cat validation-result.json | jq '.errors[]'
```

---

## Integration with Tools

```
┌─────────────────────────────────────────────────────────────────┐
│              JSON Schemas (tools/validation/schemas/)            │
│  log-entry-schema.json │ loki-response-schema.json │ ...         │
└─────────────┬───────────────────────────────────────────────────┘
              │ loaded by
┌─────────────────────────────────────────────────────────────────┐
│           Python Validators (This Directory)                     │
│  validate-log-format.py │ validate-loki-response.py │ ...        │
└─────────────┬───────────────────────────────────────────────────┘
              │ called by
       ┌──────┴──────┐
       ↓             ↓
┌─────────────┐  ┌──────────────────────────────┐
│ tools/validation/uis/    │  │ tools/validation/grafana-cloud/ │
│ (bash, local UIS)        │  │ (TypeScript, Grafana Cloud)     │
└─────────────┘  └──────────────────────────────┘
```

**Recommended: use the query scripts' built-in `--validate`/`--compare-with` flags** rather than piping to these validators by hand — see `../uis/README.md` (local UIS) or `../grafana-cloud/` (Grafana Cloud) for the exact commands. Manual invocation, shown above, is for debugging one specific layer in isolation.

---

**Last Updated:** 2026-07-11
