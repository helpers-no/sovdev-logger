# Sovdev Logger JSON Schemas

This directory contains **JSON Schema definitions** (Draft 7) that define the structure and validation rules for log entries and observability backend API responses.

## Purpose

These schemas ensure:
- **Field naming consistency**: All fields use snake_case (service_name, log_type, trace_id, etc.)
- **Type safety**: Correct data types for all fields (strings, numbers, objects)
- **Format validation**: UUIDs, timestamps, hex values follow correct formats
- **Required fields**: Critical fields are always present
- **Forbidden patterns**: Explicitly reject camelCase and dotted notation

**Key benefit:** Machine-readable contracts that validate sovdev-logger data across the entire observability stack.

---

## Prerequisites

These schemas are used by:

1. **Python validators** in `tools/validation/validators/`
2. **Shell script tools** in `tools/validation/uis/`
3. **Development tools** (JSON Schema validators, IDEs)

**Dependencies:**
- JSON Schema Draft 7 compatible validator (e.g., `jsonschema` Python library)

---

## Quick Reference

**Core Principle:** All schemas enforce snake_case field naming and reject camelCase/dotted notation throughout the observability stack.

Complete table of all JSON Schema files:

| Schema | Purpose | Validates | Enforces | Used By |
|--------|---------|-----------|----------|---------|
| [**log-entry-schema.json**](log-entry-schema.json) | File log entry format | NDJSON log files (dev.log, error.log) | snake_case fields<br/>Required: timestamp, trace_id, etc.<br/>UUID formats<br/>Stack trace 350 char limit | [`validate-log-format.py`](../validators/validate-log-format.py) |
| [**loki-response-schema.json**](loki-response-schema.json) | Loki API response format | Loki query_range responses<br/>**Validates stream labels** | snake_case fields in labels<br/>Required: timestamp (ISO 8601)<br/>Rejects serviceName/logType/etc.<br/>Rejects observed_timestamp-only logs | [`validate-loki-response.py`](../validators/validate-loki-response.py) |
| [**prometheus-response-schema.json**](prometheus-response-schema.json) | Prometheus API response format | Prometheus query responses | snake_case metric labels<br/>service_name/log_type/log_level<br/>Metric value format | [`validate-prometheus-response.py`](../validators/validate-prometheus-response.py) |
| [**tempo-response-schema.json**](tempo-response-schema.json) | Tempo API response format | Tempo search responses | traceID hex format (16-32 chars)<br/>spanID hex format (16 chars)<br/>Timestamp nanosecond format | [`validate-tempo-response.py`](../validators/validate-tempo-response.py) |

---

## How Loki OTLP Storage Works

**Critical Understanding:** Loki stores OTLP logs differently than file logs.

### File Logs (dev.log, error.log)
File logs contain the complete structured log entry as a JSON object:
```json
{
  "timestamp": "2025-10-15T14:10:23.753Z",
  "service_name": "sovdev-test-app",
  "function_name": "processRequest",
  "message": "Processing completed",
  "trace_id": "4e759052c4814a4c91df3adca5736e4b",
  ...
}
```
**Validated by:** `log-entry-schema.json` via `validate-log-format.py`

### Loki OTLP Storage (via OpenTelemetry)
Loki splits log data into two parts:

1. **Stream Labels** (indexed, queryable):
   ```json
   {
     "service_name": "sovdev-test-app",
     "function_name": "processRequest",
     "timestamp": "2025-10-15T14:10:23.753Z",  ← REQUIRED!
     "trace_id": "4e759052c4814a4c91df3adca5736e4b",
     "observed_timestamp": "1760537423753565219",  ← OTEL internal field
     ...
   }
   ```

2. **Values Array** (log messages):
   ```json
   [
     ["1760537423753565219", "Processing completed"]
   ]
   ```
   Note: The values array contains plain text messages, NOT JSON objects.

### Timestamp Requirements

**File logs require:**
- `timestamp`: ISO 8601 string (e.g., "2025-10-15T14:10:23.753Z")

**Loki stream labels require:**
- `timestamp`: ISO 8601 string (e.g., "2025-10-15T14:10:23.753Z")
- `observed_timestamp`: Nanoseconds since Unix epoch (OTEL internal field)

**Critical:** Both `timestamp` and `observed_timestamp` must be present in Loki stream labels:
- `timestamp`: Required by Grafana dashboards for display
- `observed_timestamp`: Added automatically by OTEL SDK

**Common Implementation Error:**
❌ Only having `observed_timestamp` in stream labels will cause:
- Grafana dashboard "Timestamp" column to be empty
- Validation to fail with helpful error message
- Time-based queries to malfunction

**Correct Implementation:**
✅ Add `timestamp` field to resource attributes or log record attributes before OTLP export
✅ Verify both fields appear in Loki stream labels
✅ Run `validate-loki-response.py` to confirm

### The log_entry Schema Definition

The `loki-response-schema.json` includes a `definitions.log_entry` section that lists all required fields:
```json
{
  "definitions": {
    "log_entry": {
      "type": "object",
      "required": [
        "timestamp",
        "service_name",
        "function_name",
        "log_type",
        "trace_id",
        ...
      ]
    }
  }
}
```

**Purpose:** This definition serves as the reference for what fields should be in stream labels. The validator uses this list to check stream labels for completeness.

**Why it exists:** It ensures consistency between file logs and OTLP logs - the same fields should appear in both formats.

---

## Integration with Tools

These schemas are the foundation of the validation pipeline:

```
┌─────────────────────────────────────────────────────────────────┐
│                     JSON Schemas (This Directory)                │
│  log-entry-schema.json │ loki-response-schema.json │ ...        │
└─────────────┬───────────────────────────────────────────────────┘
              │
              ↓ (loaded by)
┌─────────────────────────────────────────────────────────────────┐
│              Python Validators (tools/validation/validators/)            │
│  validate-log-format.py │ validate-loki-response.py │ ...       │
└─────────────┬───────────────────────────────────────────────────┘
              │
              ↓ (called by)
┌─────────────────────────────────────────────────────────────────┐
│         Shell Script Tools (tools/validation/uis/)                │
│  query-loki.sh │ compare-with-master.sh │ validate-log-format.sh │
└─────────────────────────────────────────────────────────────────┘
```


## Troubleshooting Common Issues

### Validation Passes But Grafana Shows Empty Timestamp

**Symptom:**
- File log validation passes ✅
- Loki response validation fails ❌
- Grafana dashboard shows empty "Timestamp" column

**Cause:** Implementation writes `timestamp` to file logs but not to OTLP exports.

**Solution:**
1. Check Loki response: `./tools/validation/uis/query-loki.sh 'your-service' --json`
2. Verify stream labels contain `timestamp` field
3. If only `observed_timestamp` present, add `timestamp` to resource/log attributes before OTLP export
4. Re-run `validate-loki-response.py` to confirm fix

**Example Error Output:**
```
❌ Stream 0: Missing required fields: ['timestamp']
❌     Found 'observed_timestamp' but missing 'timestamp'
❌     Note: Grafana dashboards require 'timestamp' (ISO 8601 string)
❌     'observed_timestamp' is an OTEL internal field and not sufficient
```

### Why Two Timestamp Fields?

**Question:** Why do we need both `timestamp` and `observed_timestamp`?

**Answer:**
- `timestamp`: Application timestamp (when event occurred) - required by Grafana and our spec
- `observed_timestamp`: OTEL SDK timestamp (when log was observed) - internal to OpenTelemetry

The OTEL SDK automatically adds `observed_timestamp`. Your implementation must also add `timestamp`.

---

## Related Documentation

- **Field definitions:** See [Field definitions](https://sovdev-logger.sovereignsky.no/contributor/field-definitions) for detailed field descriptions
- **API contract:** See [API contract](https://sovdev-logger.sovereignsky.no/contributor/api-contract) for logging API specification
- **Validators:** See `tools/validation/validators/README.md` for Python validators that use these schemas
- **Tools:** See `tools/validation/uis/README.md` for shell scripts that orchestrate validation

---

**Last Updated:** 2025-10-15
**Maintainer:** Claude Code / Terje Christensen
