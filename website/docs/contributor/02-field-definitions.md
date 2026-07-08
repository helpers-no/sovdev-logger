---
title: Field definitions
sidebar_label: Field definitions
sidebar_position: 6
description: "Required fields in all log outputs."
---

# Sovdev Logger Field Definitions

## Overview

This document defines **every field** that must appear in log entries across all three output destinations (OTLP, console, file). Field names, types, and formats must be **identical** across all language implementations.

## Field Naming Convention

**All field names use underscore notation (snake_case) for consistency across all outputs.**

### Rationale
- **Cross-language consistency**: Python, Go, Rust, PHP all use snake_case
- **Code-to-log alignment**: Variable names match log field names exactly
- **No transformations**: Same field names in code, file logs, OTLP export, and backend storage
- **Future-proof**: Easy to add new languages without naming conflicts

### Standard Fields

| Field Name | Type | Description | Required |
|------------|------|-------------|----------|
| service_name | string | Service identifier | Yes |
| service_version | string | Service version | Yes |
| session_id | string | Session grouping ID (UUID for entire execution) | OTLP Only |
| peer_service | string | Target system identifier | Yes |
| function_name | string | Function/method name | Yes |
| log_type | string | Log classification (transaction, session, error, etc.) | Yes |
| message | string | Log message | Yes |
| trace_id | string | Transaction correlation ID (UUID) | Yes |
| event_id | string | Unique log entry ID (UUID) | Yes |
| timestamp | string | When log entry was created (ISO 8601) | Yes |
| level | string | Log level (lowercase: info, error, etc.) | Yes (file/console) |
| input_json | object/string | Input parameters | Optional |
| response_json | object/string | Output data | Optional |
| exception | object | Exception details (type, message, stack) | Optional (ERROR/FATAL only) |

**Note**: All fields use snake_case in code, file logs, OTLP export, and backend storage. No transformations applied.

---

## Core Fields (All Log Types)

### Service Identification

| Field | Type | Source | Example | OTLP | Console | File | Notes |
|-------|------|--------|---------|------|---------|------|-------|
| **service_name** | string | SERVICE_NAME env var or init param | "sovdev-test-app" | ✅ | ✅ | ✅ | Service identifier |
| **service_version** | string | SERVICE_VERSION env var or init param (default "1.0.0") | "1.0.0" | ✅ | ✅ | ✅ | Service version |
| **scope_name** | string | service name (NOT module name) | "sovdev-test-app" | ✅ | ❌ | ❌ | OpenTelemetry instrumentation scope |
| **scope_version** | string | hardcoded "1.0.0" | "1.0.0" | ✅ | ❌ | ❌ | Library version |

**Critical**: `scope_name` MUST use service name, NOT module/class name (`__name__` in Python, etc.)

### Correlation IDs

| Field | Type | Source | Example | OTLP | Console | File | Notes |
|-------|------|--------|---------|------|---------|------|-------|
| **trace_id** | string | 32-char hex from OTEL span | "a511b23170d1efb01d110191712cb439" | ✅ | ✅ | ✅ | OpenTelemetry trace identifier (links related operations in distributed system) |
| **span_id** | string | 16-char hex from OTEL span | "7bf8a401f109ebe9" | ✅ | ❌ | ✅ | OpenTelemetry span identifier (links to specific operation within trace) |
| **event_id** | string | UUID v4 (lowercase, 36 chars) | "dca7f112-1c94-478f-88f2-ec9805574190" | ✅ | ❌ | ✅ | Unique log entry identifier |
| **session_id** | string | UUID v4 generated at init | "18df09dd-c321-43d8-aa24-19dd7c149a56" | ✅ | ❌ | ❌ | Execution correlation - OpenTelemetry Resource attribute (groups all logs/metrics/traces from same run) |

**Note**:
- **trace_id** and **span_id**: Extracted from OpenTelemetry span context (hex format, no dashes)
- **event_id** and **session_id**: Generated as UUID v4 (lowercase with hyphens)

### Timestamps

| Field | Type | Source | Example | OTLP | Console | File | Notes |
|-------|------|--------|---------|------|---------|------|-------|
| **timestamp** | string | ISO 8601 format | "2025-10-07T08:34:22.398784+00:00" | ✅ | ✅ | ✅ | When log entry was created |
| **observed_timestamp** | string | nanoseconds since Unix epoch | "1759826062404246784" | ✅ | ❌ | ❌ | When log was observed by OpenTelemetry |

**Format Requirements**:
- **ISO 8601**: `YYYY-MM-DDTHH:mm:ss.ffffff+00:00` (Python) or `YYYY-MM-DDTHH:mm:ss.SSSZ` (TypeScript)
- **Nanoseconds**: 19-digit integer string representing nanoseconds since 1970-01-01 00:00:00 UTC

### Log Metadata

| Field | Type | Source | Example | OTLP | Console | File | Notes |
|-------|------|--------|---------|------|---------|------|-------|
| **level** | string | lowercase log level | "info", "error" | ❌ | ✅ | ✅ | Human-readable level (file/console) |
| **severity_text** | string | uppercase log level | "INFO", "ERROR" | ✅ | ❌ | ❌ | OpenTelemetry severity text |
| **severity_number** | integer | OpenTelemetry severity | 9 (INFO), 17 (ERROR) | ✅ | ❌ | ❌ | OpenTelemetry severity number |

**Severity Number Mapping**:
- TRACE: 1
- DEBUG: 5
- INFO: 9
- WARN: 13
- ERROR: 17
- FATAL: 21

### Business Context

| Field | Type | Source | Example | OTLP | Console | File | Notes |
|-------|------|--------|---------|------|---------|------|-------|
| **function_name** | string | provided by developer | "lookupCompany" | ✅ | ✅ | ✅ | Function where logging occurs |
| **message** | string | provided by developer | "Looking up company 123456789" | ✅ | ✅ | ✅ | Human-readable log message |
| **log_type** | string | "transaction", "job.status", "job.progress" | "transaction" | ✅ | ❌ | ✅ | Type of log entry |
| **peer_service** | string | peer service ID or INTERNAL | "SYS1234567" | ✅ | ❌ | ✅ | Target system identifier |

### Data Fields

| Field | Type | Source | Example | OTLP | Console | File | Notes |
|-------|------|--------|---------|------|---------|------|-------|
| **input_json** | string | JSON.stringify(input) or "null" | '{"organisasjonsnummer":"123456789"}' | ✅ | ❌ | ✅ | Request/input data (serialized) |
| **response_json** | string | JSON.stringify(response) or "null" | '{"name":"Company AS"}' | ✅ | ❌ | ✅ | Response/output data (serialized) |

**Critical**: Both fields MUST ALWAYS be present, even when no data exists (value "null" as string).

### OpenTelemetry Metadata

| Field | Type | Source | Example | OTLP | Console | File | Notes |
|-------|------|--------|---------|------|---------|------|-------|
| **telemetry_sdk_language** | string | OpenTelemetry SDK | "python", "nodejs" | ✅ | ❌ | ❌ | Language runtime identifier |
| **telemetry_sdk_version** | string | OpenTelemetry SDK | "1.37.0", "1.28.0" | ✅ | ❌ | ❌ | OpenTelemetry SDK version |

---

## Exception Fields (ERROR/FATAL logs only)

| Field | Type | Source | Example | OTLP | Console | File | Notes |
|-------|------|--------|---------|------|---------|------|-------|
| **exception_type** | string | ALWAYS "Error" | "Error" | ✅ | ✅ | ✅ | Standardized across languages |
| **exception_message** | string | exception message | "HTTP 404:" | ✅ | ✅ | ✅ | Exception message |
| **exception_stacktrace** | string | stack trace (max 350 chars) | "Traceback (most recent call last):\n  File..." | ✅ | ✅ | ✅ | Stack trace with security cleanup |

**Critical Standardization**:
- **exception_type**: MUST be "Error" for ALL languages (not "Exception", "Throwable", etc.)
- **Security**: Stack traces MUST have credentials removed (auth headers, passwords, tokens)
- **Limit**: Stack traces MUST be truncated to 350 characters maximum

---

## Job Status Fields (log_type: "job.status")

Additional fields present in `input_json` for job status logs:

| Field | Type | Example | Notes |
|-------|------|---------|-------|
| **job_name** | string | "CompanyLookupBatch" | Human-readable job name |
| **job_status** | string | "Started", "Completed", "Failed" | Job status |

**Message Format**: `"Job {job_status}: {job_name}"`

Example input_json:
```json
{
  "job_name": "CompanyLookupBatch",
  "job_status": "Started",
  "total_companies": 4
}
```

---

## Job Progress Fields (log_type: "job.progress")

Additional fields present in `input_json` for job progress logs:

| Field | Type | Example | Notes |
|-------|------|---------|-------|
| **item_id** | string | "971277882" | Identifier for current item |
| **current_item** | integer | 25 | Current item number (1-based) |
| **total_items** | integer | 100 | Total number of items |
| **progress_percentage** | integer | 25 | Math.round((current/total) * 100) |

**Message Format**: `"Processing {item_id} ({current_item}/{total_items})"`

Example input_json:
```json
{
  "item_id": "971277882",
  "current_item": 25,
  "total_items": 100,
  "progress_percentage": 25,
  "organisasjonsnummer": "971277882"
}
```

---

## Console Output Format

### Development Mode (Colored, Human-Readable)
```
2025-10-07 08:34:22 [ERROR] sovdev-test-company-lookup-python
  Function: lookupCompany
  Trace ID: a511b23170d1efb01d110191712cb439
  Span ID: 7bf8a401f109ebe9
  Session ID: 18df09dd-c321-43d8-aa24-19dd7c149a56
  Error: HTTP 404:
  Stack: Traceback (most recent call last):
    File "/workspace/python/test/e2e/company-lookup/company-lookup.py", line 42
```

**Format Rules**:
- **Timestamp**: `YYYY-MM-DD HH:mm:ss`
- **Level**: Uppercase in brackets `[ERROR]`
- **Service**: On same line as timestamp and level
- **Indentation**: 2 spaces for details
- **Colors**: Use ANSI color codes (ERROR=red, WARN=yellow, INFO=green, etc.)

### Production Mode (JSON)
```json
{
  "timestamp": "2025-10-07T08:34:22.398784+00:00",
  "level": "error",
  "service_name": "sovdev-test-company-lookup-python",
  "service_version": "1.0.0",
  "session_id": "18df09dd-c321-43d8-aa24-19dd7c149a56",
  "function_name": "lookupCompany",
  "message": "Failed to lookup company 974652846",
  "trace_id": "a511b23170d1efb01d110191712cb439",
  "span_id": "7bf8a401f109ebe9",
  "exception_type": "Error",
  "exception_message": "HTTP 404:",
  "exception_stacktrace": "Traceback..."
}
```

---

## File Output Format (JSON Lines)

Each log entry is a single line of JSON with snake_case field names:

```json
{"timestamp":"2025-10-07T08:34:22.398784+00:00","level":"error","service_name":"sovdev-test-company-lookup-python","service_version":"1.0.0","session_id":"18df09dd-c321-43d8-aa24-19dd7c149a56","peer_service":"SYS1234567","function_name":"lookupCompany","log_type":"transaction","message":"Failed to lookup company 974652846","trace_id":"a511b23170d1efb01d110191712cb439","span_id":"7bf8a401f109ebe9","event_id":"cf115688-513e-48fe-8049-538a515f608d","input_json":{"organisasjonsnummer":"974652846"},"response_json":null,"exception_type":"Error","exception_message":"HTTP 404:","exception_stacktrace":"Traceback..."}
```

**Format Rules**:
- **JSON Lines**: One log entry per line (newline-delimited JSON)
- **snake_case**: All field names use underscores
- **No Pretty Printing**: Compact JSON (no whitespace)

---

## OTLP Output Format

Logs are sent to OpenTelemetry Collector via OTLP protocol using snake_case field names. Field structure in Loki:

```json
{
  "scope_name": "sovdev-test-company-lookup-python",
  "scope_version": "1.0.0",
  "observed_timestamp": "1759823543622190848",
  "severity_number": 17,
  "severity_text": "ERROR",
  "service_name": "sovdev-test-company-lookup-python",
  "service_version": "1.0.0",
  "session_id": "18df09dd-c321-43d8-aa24-19dd7c149a56",
  "peer_service": "SYS1234567",
  "function_name": "lookupCompany",
  "log_type": "transaction",
  "trace_id": "a511b23170d1efb01d110191712cb439",
  "span_id": "7bf8a401f109ebe9",
  "event_id": "cf115688-513e-48fe-8049-538a515f608d",
  "input_json": "{\"organisasjonsnummer\":\"974652846\"}",
  "response_json": "null",
  "exception_type": "Error",
  "exception_message": "HTTP 404:",
  "exception_stacktrace": "Traceback...",
  "telemetry_sdk_language": "python",
  "telemetry_sdk_version": "1.37.0"
}
```

**Format Rules**:
- **Flat Structure**: All fields at root level (no nesting)
- **snake_case**: All field names use underscores (service_name, peer_service, session_id, function_name, log_type, etc.)
- **No Transformations**: OTLP Collector receives fields as-is and passes them through unchanged to Loki

---

## Field Presence Matrix

Summary of which fields appear in which outputs:

| Field | OTLP | Console | File | Always Present |
|-------|------|---------|------|----------------|
| service_name | ✅ | ✅ | ✅ | ✅ |
| service_version | ✅ | ✅ | ✅ | ✅ |
| scope_name | ✅ | ❌ | ❌ | ✅ (OTLP only) |
| scope_version | ✅ | ❌ | ❌ | ✅ (OTLP only) |
| trace_id | ✅ | ✅ | ✅ | ✅ |
| span_id | ✅ | ❌ | ✅ | ❌ (when span active) |
| event_id | ✅ | ❌ | ✅ | ✅ |
| session_id | ✅ | ❌ | ❌ | ✅ (OTLP Resource only) |
| timestamp | ✅ | ✅ | ✅ | ✅ |
| observed_timestamp | ✅ | ❌ | ❌ | ✅ (OTLP only) |
| level | ❌ | ✅ | ✅ | ✅ |
| severity_text | ✅ | ❌ | ❌ | ✅ (OTLP only) |
| severity_number | ✅ | ❌ | ❌ | ✅ (OTLP only) |
| function_name | ✅ | ✅ | ✅ | ✅ |
| message | ✅ | ✅ | ✅ | ✅ |
| log_type | ✅ | ❌ | ✅ | ✅ |
| peer_service | ✅ | ❌ | ✅ | ✅ |
| input_json | ✅ | ❌ | ✅ | ✅ (even when "null") |
| response_json | ✅ | ❌ | ✅ | ✅ (even when "null") |
| exception_type | ✅ | ✅ | ✅ | ❌ (ERROR/FATAL only) |
| exception_message | ✅ | ✅ | ✅ | ❌ (ERROR/FATAL only) |
| exception_stacktrace | ✅ | ✅ | ✅ | ❌ (ERROR/FATAL only) |

---

## Validation Rules

### Required Field Validation
All implementations MUST validate that these fields are present in every log entry:
- service_name, service_version
- trace_id, event_id, session_id
- timestamp, observed_timestamp (OTLP)
- level (console/file) OR severity_text + severity_number (OTLP)
- function_name, message, log_type
- peer_service
- input_json (even if "null")
- response_json (even if "null")

### Format Validation
- **trace_id**: Must match regex `^[0-9a-f]{32}$` (32-char hex from OTEL span context)
- **span_id**: Must match regex `^[0-9a-f]{16}$` (16-char hex from OTEL span context, optional)
- **UUID Fields** (event_id, session_id): Must match regex `^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$`
- **Timestamps**: Must be valid ISO 8601 or nanoseconds since epoch
- **Log Levels**: Must be one of: trace, debug, info, warn, error, fatal (lowercase)
- **Severity Text**: Must be uppercase version of log level
- **Severity Number**: Must map correctly to log level

### Naming Convention Validation
- **snake_case**: All field names MUST use underscores (service_name, function_name, log_type, etc.)
- **No dots**: Dot notation (service.name, peer.service) is NOT allowed
- **No camelCase**: camelCase notation (functionName, logType, traceId) is NOT allowed

---

**Document Status:** ✅ v1.0.0 COMPLETE
**Last Updated:** 2025-10-27
**Part of:** sovdev-logger specification v1.1.0
