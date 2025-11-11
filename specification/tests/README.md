# Sovdev Logger Validation Scripts

This directory contains **Python validation scripts** that verify log formats, backend responses, and data consistency across the sovdev-logger observability stack.

## Purpose

These validators ensure:
- Log files conform to JSON Schema specifications
- Backend APIs (Loki, Prometheus, Tempo) store data correctly with snake_case fields
- Data consistency between file logs and observability backends (Loki, Prometheus, Tempo)
- All telemetry data is properly exported via OTLP

**Key benefit:** Automated validation of the complete telemetry pipeline from file logging to observability backends.

---

## Prerequisites

Before using these validators, ensure:

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

**Core Principle:** All validators are Python scripts that validate against JSON Schemas or cross-validate data consistency.

Complete table of all validation scripts:

| Script | Purpose | Usage | Input | Output | Used By |
|--------|---------|-------|-------|--------|---------|
| [**validate-log-format.py**](validate-log-format.py) | Validate log file format against schema | `python3 validate-log-format.py <logfile>` | NDJSON log file | Schema compliance + custom rules | [`validate-log-format.sh`](../tools/validate-log-format.sh) |
| [**validate-loki-response.py**](validate-loki-response.py) | Validate Loki API response against schema | `python3 validate-loki-response.py <response.json>` | Loki query response | Schema + snake_case validation | [`run-full-validation.sh`](../tools/run-full-validation.sh)<br/>[`run-grafana-validation.sh`](../tools/run-grafana-validation.sh) |
| [**validate-prometheus-response.py**](validate-prometheus-response.py) | Validate Prometheus API response against schema | `python3 validate-prometheus-response.py <response.json>` | Prometheus query response | Schema + snake_case labels | [`run-full-validation.sh`](../tools/run-full-validation.sh)<br/>[`run-grafana-validation.sh`](../tools/run-grafana-validation.sh) |
| [**validate-tempo-response.py**](validate-tempo-response.py) | Validate Tempo API response against schema | `python3 validate-tempo-response.py <response.json>` | Tempo search response | Schema + trace ID format | [`run-full-validation.sh`](../tools/run-full-validation.sh)<br/>[`run-grafana-validation.sh`](../tools/run-grafana-validation.sh) |
| [**validate-loki-consistency.py**](validate-loki-consistency.py) | Cross-validate file logs vs Loki backend | `python3 validate-loki-consistency.py <logfile> <loki-response.json>` | Log file + Loki response | Consistency report | [`run-full-validation.sh`](../tools/run-full-validation.sh)<br/>[`run-grafana-validation.sh`](../tools/run-grafana-validation.sh) |
| [**validate-prometheus-consistency.py**](validate-prometheus-consistency.py) | Cross-validate file logs vs Prometheus metrics | `python3 validate-prometheus-consistency.py <logfile> <prom-response.json>` | Log file + Prometheus response | Metrics match report | [`run-full-validation.sh`](../tools/run-full-validation.sh)<br/>[`run-grafana-validation.sh`](../tools/run-grafana-validation.sh) |
| [**validate-tempo-consistency.py**](validate-tempo-consistency.py) | Cross-validate file trace_ids vs Tempo traces | `python3 validate-tempo-consistency.py <logfile> <tempo-response.json>` | Log file + Tempo response | Trace ID match report | [`run-full-validation.sh`](../tools/run-full-validation.sh)<br/>[`run-grafana-validation.sh`](../tools/run-grafana-validation.sh) |

**Common options for all validators:**
- `--json` - Output JSON format for automation
- `--help` - Show usage information
- `-` - Read from stdin (for piping query results)

**Validator categories:**
- **Schema validators** (4): Validate API responses and log files against JSON Schema
- **Consistency validators** (3): Cross-validate data between file logs and observability backends

---

## Usage Examples

**Note:** These examples show **manual direct usage** of validators for debugging and custom workflows.
For standard validation, use query scripts with `--validate` and `--compare-with` flags (see "Complete Validation Workflow" section).

### Schema Validation

```bash
# Validate log file format
python3 validate-log-format.py /workspace/python/test/e2e/company-lookup/logs/dev.log

# Validate error log (strict mode - ERROR logs only)
python3 validate-log-format.py /workspace/python/test/e2e/company-lookup/logs/error.log --error-log

# Validate Loki response (piped from query)
./query-loki.sh sovdev-test-company-lookup-python --json | python3 validate-loki-response.py -

# Validate Prometheus response
./query-prometheus.sh sovdev-test-company-lookup-python --json | python3 validate-prometheus-response.py -

# Validate Tempo response
./query-tempo.sh sovdev-test-company-lookup-python --json | python3 validate-tempo-response.py -
```

### Consistency Validation

```bash
# Cross-validate file logs vs Loki backend
./query-loki.sh sovdev-test-company-lookup-python --json | \
  python3 validate-loki-consistency.py logs/dev.log -

# Cross-validate file logs vs Prometheus metrics
./query-prometheus.sh sovdev-test-company-lookup-python --json | \
  python3 validate-prometheus-consistency.py logs/dev.log -

# Cross-validate file trace_ids vs Tempo traces
./query-tempo.sh sovdev-test-company-lookup-python --json | \
  python3 validate-tempo-consistency.py logs/dev.log -
```

### JSON Output for Automation

```bash
# Get JSON output for CI/CD pipelines
python3 validate-log-format.py logs/dev.log --json > validation-result.json

# Parse validation result
cat validation-result.json | jq '.valid'  # true/false

# Check for errors
cat validation-result.json | jq '.errors[]'
```

### Complete Validation Workflow

**Recommended Approach: Use Built-in Validation Flags**

Query scripts now have built-in validation via `--validate` and `--compare-with` flags:

```bash
# Automated approach (recommended - used by run-full-validation.sh)
LOG_FILE="python/test/e2e/company-lookup/logs/dev.log"
SERVICE="sovdev-test-company-lookup-python"

# Combined validation: schema + consistency in one query per backend
./query-loki.sh "$SERVICE" --validate --compare-with "$LOG_FILE"
./query-prometheus.sh "$SERVICE" --validate --compare-with "$LOG_FILE"
./query-tempo.sh "$SERVICE" --validate --compare-with "$LOG_FILE"
```

**Manual Approach: Direct Validator Usage**

For advanced debugging or custom workflows, you can call validators directly:

```bash
LOG_FILE="python/test/e2e/company-lookup/logs/dev.log"
SERVICE="sovdev-test-company-lookup-python"

# 1. Validate log file format
python3 validate-log-format.py "$LOG_FILE"

# 2. Validate backend responses (schema only)
./query-loki.sh "$SERVICE" --json | python3 validate-loki-response.py -
./query-prometheus.sh "$SERVICE" --json | python3 validate-prometheus-response.py -
./query-tempo.sh "$SERVICE" --json | python3 validate-tempo-response.py -

# 3. Cross-validate consistency (separate queries)
./query-loki.sh "$SERVICE" --json | python3 validate-loki-consistency.py "$LOG_FILE" -
./query-prometheus.sh "$SERVICE" --json | python3 validate-prometheus-consistency.py "$LOG_FILE" -
./query-tempo.sh "$SERVICE" --json | python3 validate-tempo-consistency.py "$LOG_FILE" -
```

---

## Integration with Tools

These validators are the core of the validation pipeline, connecting schemas to tools:

```
┌─────────────────────────────────────────────────────────────────┐
│              JSON Schemas (specification/schemas/)               │
│  log-entry-schema.json │ loki-response-schema.json │ ...        │
└─────────────┬───────────────────────────────────────────────────┘
              │
              ↓ (loaded by)
┌─────────────────────────────────────────────────────────────────┐
│           Python Validators (This Directory)                     │
│  validate-log-format.py │ validate-loki-response.py │ ...       │
└─────────────┬───────────────────────────────────────────────────┘
              │
              ↓ (called by)
┌─────────────────────────────────────────────────────────────────┐
│         Shell Script Tools (specification/tools/)                │
│  run-full-validation.sh │ validate-log-format.sh │ ...          │
└─────────────────────────────────────────────────────────────────┘
```

**Tool integration:**

| Tool | Validators Used | Approach |
|------|-----------------|----------|
| `run-full-validation.sh` | All 7 validators | Built-in validation flags (combined schema + consistency) |
| `run-grafana-validation.sh` | 6 validators (Grafana proxy) | Built-in validation flags (combined schema + consistency) |
| `validate-log-format.sh` | `validate-log-format.py` | Direct wrapper |
| Query tools (`query-*.sh`) | Response + consistency validators | Optional `--validate` and `--compare-with` flags |

**Example from `run-full-validation.sh` (current implementation):**
```bash
# Step B: Validate log file
./validate-log-format.sh "$LOG_FILE"

# Step C: Loki validation (combined schema + consistency)
./query-loki.sh "$SERVICE" --validate --compare-with "$LOG_FILE"

# Step D: Prometheus validation (combined schema + consistency)
./query-prometheus.sh "$SERVICE" --validate --compare-with "$LOG_FILE"

# Step E: Tempo validation (combined schema + consistency)
./query-tempo.sh "$SERVICE" --validate --compare-with "$LOG_FILE"

# Internally, query scripts call validators automatically:
# --validate flag → calls validate-loki-response.py (schema validation)
# --compare-with flag → calls validate-loki-consistency.py (consistency validation)
```

---


**Last Updated:** 2025-10-13
**Maintainer:** Claude Code / Terje Christensen
