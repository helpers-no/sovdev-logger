---
title: "Log data structure"
sidebar_label: "Log data structure"
sidebar_position: 4
description: "Field reference, logging patterns, and correlation strategies."
---

# sovdev-logger - Logging Data Structure and Usage

## Overview

The sovdev-logger is a structured logging library for TypeScript/JavaScript that sends logs to an OpenTelemetry (OTLP) collector, which forwards them to Loki for storage and Grafana for visualization. It follows the "Loggeloven av 2025" compliance requirements and uses OpenTelemetry/Elastic ECS standard field names.

## Log Entry Structure

Each log entry contains the following fields:

### Required Fields
- **timestamp**: ISO 8601 timestamp (e.g., "2025-10-03T14:47:45.156Z")
- **level**: Log level ("info", "warn", "error", "debug", "trace", "fatal")
- **service_name**: Your service identifier (e.g., "company-lookup-service")
- **service_version**: Service version (e.g., "1.0.0")
- **session_id**: Session grouping ID (UUID for entire execution)
- **peer_service**: Target system being called (e.g., "SYS1234567")
- **function_name**: Name of the function that created the log (e.g., "lookupCompany", "batchLookup", "main")
- **message**: Human-readable log message (e.g., "Company found: KVISTADMANNEN AS")

### Correlation Fields (OpenTelemetry/ECS Standard)
- **trace_id**: Business transaction identifier that links related operations (UUID format)
- **event_id**: Unique identifier for each log entry (UUID format)

### Log Classification
- **log_type**: Type of log entry
  - `"transaction"`: Individual request/response logs
  - `"job.status"`: Batch job lifecycle events (Started, Completed, Failed)
  - `"job.progress"`: Progress tracking for batch operations (Processing X of Y)

### Context Fields (Optional)
- **input_json**: Input parameters as JSON string (e.g., `"{\"organisasjonsnummer\": \"971277882\"}"`)
- **response_json**: Response data as JSON string (e.g., `"{\"navn\": \"DIREKTORATET\", \"organisasjonsform\": \"Organisasjonsledd\"}"`)
- **exception_type**: Exception type (e.g., "Error")
- **exception_message**: Error message (e.g., "HTTP 404: ")
- **exception_stack**: Stack trace (truncated to 350 chars max)

## Three Logging Patterns

### Pattern 1: Transaction Logging (Request-Response)

**Purpose**: Track individual operations with their inputs and outputs

**Example**: Company lookup operation
```json
{
  "timestamp": "2025-10-06T09:42:43.454Z",
  "level": "info",
  "service_name": "company-lookup-service",
  "service_version": "1.0.0",
  "session_id": "18df09dd-c321-43d8-aa24-19dd7c149a56",
  "peer_service": "SYS1234567",
  "function_name": "lookupCompany",
  "message": "Looking up company 916201478",
  "log_type": "transaction",
  "trace_id": "3f43a369-9cc2-4351-a472-c5d050ab9cbf",
  "event_id": "29319322-17a6-40bc-8ea6-ac0fc9771177",
  "input_json": "{\"organisasjonsnummer\": \"916201478\"}",
  "response_json": "null"
}
```

**Response log** (same trace_id):
```json
{
  "timestamp": "2025-10-06T09:42:44.009Z",
  "level": "info",
  "service_name": "company-lookup-service",
  "service_version": "1.0.0",
  "session_id": "18df09dd-c321-43d8-aa24-19dd7c149a56",
  "peer_service": "SYS1234567",
  "function_name": "lookupCompany",
  "message": "Company found: KVISTADMANNEN AS",
  "log_type": "transaction",
  "trace_id": "3f43a369-9cc2-4351-a472-c5d050ab9cbf",
  "event_id": "755815f6-9f9b-47dc-9e06-0a4de8d9bdcd",
  "input_json": "{\"organisasjonsnummer\": \"916201478\"}",
  "response_json": "{\"navn\": \"KVISTADMANNEN AS\", \"organisasjonsform\": \"Aksjeselskap\"}"
}
```

**Key Characteristic**: Two log entries share the same `trace_id` to link request and response

### Pattern 2: Job Status Logging (Batch Lifecycle)

**Purpose**: Track the start, completion, or failure of batch jobs

**Example**: Batch job started
```json
{
  "timestamp": "2025-10-03T14:47:45.156Z",
  "level": "info",
  "service_name": "company-lookup-service",
  "service_version": "1.0.0",
  "session_id": "18df09dd-c321-43d8-aa24-19dd7c149a56",
  "peer_service": "INTERNAL",
  "function_name": "batchLookup",
  "message": "Job Started: CompanyLookupBatch",
  "log_type": "job.status",
  "trace_id": "05947fb2-499f-47fd-9d9b-0406711b5337",
  "event_id": "cb37430e-4b06-4c9e-9b66-bfb015c419e9",
  "input_json": "{\"jobName\": \"CompanyLookupBatch\", \"jobStatus\": \"Started\", \"totalCompanies\": 4}",
  "response_json": "null"
}
```

**Job completed** (same trace_id):
```json
{
  "timestamp": "2025-10-03T14:47:45.826Z",
  "level": "info",
  "service_name": "company-lookup-service",
  "service_version": "1.0.0",
  "session_id": "18df09dd-c321-43d8-aa24-19dd7c149a56",
  "peer_service": "INTERNAL",
  "function_name": "batchLookup",
  "message": "Job Completed: CompanyLookupBatch",
  "log_type": "job.status",
  "trace_id": "05947fb2-499f-47fd-9d9b-0406711b5337",
  "event_id": "f1a480a5-f785-4611-842b-0828d20c5562",
  "input_json": "{\"jobName\": \"CompanyLookupBatch\", \"jobStatus\": \"Completed\", \"totalCompanies\": 4, \"successful\": 4, \"failed\": 0, \"successRate\": \"100%\"}",
  "response_json": "null"
}
```

**Key Characteristic**: All job lifecycle events share the same `trace_id` (the batch job's trace_id)

### Pattern 3: Job Progress Logging (Batch Processing)

**Purpose**: Track progress through batch operations (Processing X of Y)

**Example**: Processing item 2 of 4
```json
{
  "timestamp": "2025-10-03T14:47:45.419Z",
  "level": "info",
  "service_name": "company-lookup-service",
  "service_version": "1.0.0",
  "session_id": "18df09dd-c321-43d8-aa24-19dd7c149a56",
  "peer_service": "INTERNAL",
  "function_name": "batchLookup",
  "message": "Processing 915933149 (2/4)",
  "log_type": "job.progress",
  "trace_id": "05947fb2-499f-47fd-9d9b-0406711b5337",
  "event_id": "9da1a14a-4a3b-437f-bd26-afd810367e6b",
  "input_json": "{\"jobName\": \"BatchProcessing\", \"itemId\": \"915933149\", \"currentItem\": 2, \"totalItems\": 4, \"progressPercentage\": 50, \"organisasjonsnummer\": \"915933149\"}",
  "response_json": "null"
}
```

**Key Characteristic**: Progress logs use the batch job's `trace_id`, while the individual item processing uses a different `trace_id`

## Trace ID Correlation Strategy

The library supports three logging scenarios with different trace_id strategies:

### Scenario 1: Single Transaction (No Grouping)
**When to use**: Single operation with request and response
**trace_id strategy**: Generate ONE trace_id, use it for both request and response logs
**Example**: Looking up one company

```
trace_id = "abc-123"
├─ Request log (trace_id: "abc-123", log_type: "transaction")
└─ Response log (trace_id: "abc-123", log_type: "transaction")
```

### Scenario 2: Batch Job (With Grouping)
**When to use**: Processing multiple items as a batch
**trace_id strategy**: Use DUAL trace_id - one for batch, one per item
**Example**: Processing 100 companies in a batch

```
Batch trace_id = "batch-123"
├─ Job Started (trace_id: "batch-123", log_type: "job.status")
├─ Processing item 1 (trace_id: "batch-123", log_type: "job.progress")
│  ├─ Item Request (trace_id: "item-aaa", log_type: "transaction")
│  └─ Item Response (trace_id: "item-aaa", log_type: "transaction")
├─ Processing item 2 (trace_id: "batch-123", log_type: "job.progress")
│  ├─ Item Request (trace_id: "item-bbb", log_type: "transaction")
│  └─ Item Response (trace_id: "item-bbb", log_type: "transaction")
└─ Job Completed (trace_id: "batch-123", log_type: "job.status")
```

### Scenario 3: Integration Session (Top-Level Grouping)
**When to use**: Multiple related operations in one integration session
**trace_id strategy**: Generate ONE session trace_id at start, pass it to all operations
**Example**: User uploads file → validate → process → store → notify

```
Session trace_id = "session-xyz"
├─ Integration Started (trace_id: "session-xyz")
├─ File Validation (trace_id: "session-xyz")
├─ Data Processing (trace_id: "session-xyz")
├─ Storage Operation (trace_id: "session-xyz")
└─ Integration Completed (trace_id: "session-xyz")
```

---

### Detailed: Dual Trace ID Strategy for Batch Operations

The library uses a **dual trace_id strategy** for batch operations (Scenario 2):

### Batch-Level trace_id
- Generated once for the entire batch job
- Used by:
  - Job status logs (Started, Completed)
  - Job progress logs (Processing X of Y)
- Purpose: Link all batch operations together

### Item-Level trace_id
- Generated for each item being processed
- Used by:
  - Transaction logs for individual items (request + response)
- Purpose: Link request/response pairs for a single item

### Example Flow

```
Batch Job: trace_id = "batch-123"
├─ Job Started (trace_id: "batch-123", log_type: "job.status")
├─ Processing 1/4 (trace_id: "batch-123", log_type: "job.progress")
│  ├─ Item Request (trace_id: "item-aaa", log_type: "transaction")
│  └─ Item Response (trace_id: "item-aaa", log_type: "transaction")
├─ Processing 2/4 (trace_id: "batch-123", log_type: "job.progress")
│  ├─ Item Request (trace_id: "item-bbb", log_type: "transaction")
│  └─ Item Response (trace_id: "item-bbb", log_type: "transaction")
└─ Job Completed (trace_id: "batch-123", log_type: "job.status")
```

## How Developers Use These Logs

### Use Case 1: Debug a Failed Transaction
**Goal**: Find out why a specific company lookup failed

**Steps**:
1. Search for the company ID (e.g., "974652846") in logs
2. Find the trace_id for that operation
3. Filter all logs by that trace_id to see:
   - Request (input parameters)
   - Response or error
   - Exception details if it failed

**Benefit**: See complete request/response flow with all context

### Use Case 2: Monitor Batch Job Progress
**Goal**: Track how a batch job is progressing

**Steps**:
1. Find the job start log (log_type: "job.status", message contains "Started")
2. Get the trace_id for that batch
3. Filter by that trace_id + log_type: "job.progress" to see:
   - Which items have been processed (1/4, 2/4, etc.)
   - Progress percentage
   - Any items that failed

**Benefit**: Real-time view of batch processing without looking at individual transactions

### Use Case 3: Analyze Batch Job Results
**Goal**: Understand what happened in a completed batch job

**Steps**:
1. Find job completion log (log_type: "job.status", message contains "Completed")
2. Review summary data:
   - Total items processed
   - Success count
   - Failure count
   - Success rate percentage

**Benefit**: Quick overview without analyzing individual items

### Use Case 4: Correlate Batch Job with Individual Failures
**Goal**: Find which specific items failed in a batch job

**Steps**:
1. Get batch job trace_id from job status logs
2. Filter progress logs by batch trace_id to find item IDs
3. For each item, find its item-level trace_id from transaction logs
4. Look for exception fields in transaction logs

**Benefit**: Link batch-level overview to item-level details

### Use Case 5: Track Related Operations Across Services
**Goal**: Follow a transaction through multiple microservices

**Steps**:
1. Start with initial request log and get its trace_id
2. Pass trace_id to downstream services
3. All related logs across services share the same trace_id
4. Query logs from all services filtered by trace_id

**Benefit**: Distributed tracing for debugging cross-service operations

## Current Grafana Dashboard Implementation

**Dashboard Name**: "sovdev-logger - Correlated Transaction View"
**Location**: Kubernetes ConfigMap `grafana-dashboard-sovdev-verification` in namespace `monitoring`
**Auto-refresh**: 5 seconds
**Time window**: Last 15 minutes
**Data source**: Loki

### Panel 1: All Logs (Grouped by traceId) - Click to expand correlation fields
- **Type**: Logs panel
- **Position**: Top of dashboard (full width, 10 rows height)
- **Query**: `{service_name=~"sovdev-test.*"}`
- **Purpose**: See raw log stream in chronological order
- **Features**:
  - Shows all log entries sorted descending by time
  - Click on any log to expand and see all labels/fields
  - Labels include: trace_id, event_id, log_type, service_name, function_name
  - Log details panel shows complete JSON structure
- **Configuration**:
  - Show labels: true
  - Enable log details: true
  - Wrap log messages: true
  - Sort order: Descending

**What you see**: Raw chronological stream of all logs with expandable details

### Panel 2: Transaction Correlation Table (trace_id links related logs)
- **Type**: Table panel
- **Position**: Below Panel 1 (full width, 12 rows height)
- **Query**:
  ```logql
  {service_name=~"sovdev-test.*"}
  | line_format "{{.timestamp}}|{{.trace_id}}|{{.event_id}}|{{.log_type}}|{{.service_name}}|{{.service_version}}|{{.peer_service}}|{{.function_name}}|{{__line__}}|{{.input_json}}|{{.response_json}}"
  ```
- **Purpose**: Structured table view with all fields as columns for easy filtering and sorting
- **Transformations**:
  1. Extract fields using pipe separator (|)
  2. Rename fields to: timestamp, trace_id, event_id, log_type, service_name, service_version, peer_service, function_name, message, input_json, response_json
- **Column Configuration**:
  - **trace_id**: 250px width, blue color (makes correlation visible)
  - **log_type**: 120px width, orange color (highlights log type)
  - **input_json**: 300px width (readable JSON data)
  - **response_json**: 300px width (readable JSON data)
  - Other columns: auto width
- **Sorting**: Default sort by timestamp descending
- **Features**:
  - Click column header to sort
  - All correlation fields visible at once
  - JSON data inline in cells
  - Can filter/search within table

**What you see**: Spreadsheet-like view with each log as a row, all fields as columns, color-coded trace_id and log_type

### Panel 3: Batch Job Progress (filtered by trace_id)
- **Type**: Table panel
- **Position**: Below Panel 2 (full width, 10 rows height)
- **Query**:
  ```logql
  {service_name=~"sovdev-test.*"}
  |~ "Processing .* \\([0-9]+/[0-9]+\\)"
  | line_format "{{.timestamp}}|{{.trace_id}}|{{.service_name}}|{{.peer_service}}|{{__line__}}|{{.input_json}}"
  ```
- **Purpose**: Show only progress tracking logs (Processing X of Y pattern)
- **Transformations**:
  1. Extract fields using pipe separator
  2. Rename to: timestamp, trace_id (batch job), service_name, peer_service, message, input_json
- **Features**:
  - Filters out all non-progress logs
  - Shows batch trace_id (shared across all progress logs for same job)
  - input_json contains progress metadata (currentItem, totalItems, progressPercentage)
  - Grouped by batch trace_id

**What you see**: Only the "Processing X (Y/Z)" logs, making it easy to track batch progress without noise

### Panel 4: Errors and Exceptions (with trace_id for correlation)
- **Type**: Table panel
- **Position**: Below Panel 3 (full width, 10 rows height)
- **Query**: `{service_name=~"sovdev-test.*",exception_type!=""}`
- **Purpose**: Show only logs that contain errors/exceptions
- **Features**:
  - Filters using Loki label `exception_type` (only exists when exception logged)
  - Shows complete log entry including trace_id
  - exception_type column highlighted in red
  - Includes exception message and stack trace
- **Configuration**:
  - exception_type field: red color threshold (severity indicator)

**What you see**: Only error logs with exception details, trace_id allows correlation back to original request

## Current Dashboard Workflow

### Typical Usage Pattern

1. **Start with Panel 1** - See what's happening in real-time
2. **Switch to Panel 2** - Analyze specific transactions in table format
3. **Use Panel 3** - Focus on batch job progress
4. **Check Panel 4** - Investigate any errors

### Example: Debugging a Failed Batch Item

1. **Panel 4**: Notice error with exception_type "Error", message "HTTP 404"
2. Copy the trace_id from the error log (e.g., "f3398ea8-e629-46d1-8204-6e912bea2083")
3. **Panel 2**: Filter table by trace_id (use browser search or table filter)
4. See both request and error logs with same trace_id
5. Review input_json to see what was being processed when it failed
6. **Panel 3**: Find which batch this was part of by looking for progress log with same itemId
7. Get batch trace_id from progress log
8. Filter Panel 2 by batch trace_id to see entire batch context

### Current Dashboard Limitations

**Visual Correlation**
- trace_id is visible but requires manual filtering/searching
- No visual grouping of related logs (request→response pairs look like separate rows)
- Can't easily see "this response belongs to that request"

**Batch Job Visibility**
- Can't see batch job as a hierarchical structure
- Progress logs and item logs are flat list
- Hard to visualize "batch job containing 4 item operations"
- No aggregation (must count progress logs manually to see how many completed)

**Time-Based Analysis**
- Pure table/log views, no graphs
- Can't see trends (error rate increasing over time)
- Can't visualize job duration or throughput

**JSON Readability**
- input_json and response_json shown as raw strings in narrow columns
- Complex nested objects require horizontal scrolling
- No syntax highlighting or formatting

**Manual Work Required**
- Copy/paste trace_id between panels
- Browser search to find related logs
- Mental correlation of batch→progress→items
- Counting to determine success/failure rates

## Dashboard Challenges and Opportunities for Improvement

### Challenge 1: Correlating Request/Response Pairs
**Current State**: Table shows all logs in flat list
**Problem**: Hard to visually see which request matches which response
**Opportunity**: Group or nest logs by traceId to show request→response flow

### Challenge 2: Visualizing Batch Job Hierarchy
**Current State**: Batch logs and item logs are mixed together
**Problem**: Can't easily see the relationship between:
  - Batch job (Started → Progress → Completed)
  - Individual item transactions within the batch
**Opportunity**: Hierarchical view or timeline showing batch operations containing item operations

### Challenge 3: Time-Series Analysis
**Current State**: Only table views, no graphs
**Problem**: Can't see patterns over time (e.g., batch job duration, error rates, throughput)
**Opportunity**: Add time-series visualizations:
  - Jobs started/completed over time
  - Success vs failure rate
  - Processing time per item
  - Throughput (items/second)

### Challenge 4: JSON Field Exploration
**Current State**: InputJSON and responseJSON shown as raw strings in table cells
**Problem**: Complex nested JSON is hard to read in narrow table columns
**Opportunity**:
  - JSON tree viewer
  - Expand/collapse for nested objects
  - Syntax highlighting
  - Search within JSON

### Challenge 5: Multi-System View
**Current State**: Dashboard filters by `service_name=~"sovdev-test.*"` (all test services)
**Problem**: As more services use the logger, logs from different systems get mixed
**Opportunity**:
  - System selector/filter dropdown
  - Multi-panel view (one panel per system)
  - Cross-system correlation (trace across services)

### Challenge 6: Progress Tracking
**Current State**: Progress logs shown as individual rows
**Problem**: Hard to visualize progress over time (can't easily see "we're 50% done")
**Opportunity**:
  - Progress bar visualization (0% → 100%)
  - Real-time update as batch progresses
  - Estimated time to completion
  - Visual indicators for stalled batches

### Challenge 7: Error Context
**Current State**: Errors shown in separate panel
**Problem**: Have to manually correlate error traceId back to the original request
**Opportunity**:
  - Click error to expand full transaction context (request → error)
  - Show error in context of batch job (which item failed during which batch)
  - Visual timeline showing when error occurred in batch sequence

## Data Storage Details

- **OTLP Endpoint**: http://otel.localhost/v1/logs (via Traefik IngressRoute)
- **Storage**: Loki (with TSDB index)
- **Visualization**: Grafana
- **Labels**: service_name, exceptionType (indexed)
- **Content**: All other fields stored in log body
- **Retention**: Configured in Loki (default varies by environment)

## Example Use Case: Real-World Batch Processing

**Scenario**: Process 1000 customer records from a CSV file, enriching each with data from external API

**Log Flow**:
1. Job Started (log_type: job.status, trace_id: batch-xyz, totalItems: 1000)
2. Progress 1/1000 (log_type: job.progress, trace_id: batch-xyz, itemId: customer-001)
3. Transaction: Lookup customer-001 (log_type: transaction, trace_id: item-aaa, input_json: "{\"customerId\": \"001\"}")
4. Transaction: Found customer-001 (log_type: transaction, trace_id: item-aaa, response_json: "{\"name\": \"...\"}")
5. Progress 2/1000 (log_type: job.progress, trace_id: batch-xyz, itemId: customer-002)
6. ... (repeat for all 1000)
7. Job Completed (log_type: job.status, trace_id: batch-xyz, successful: 995, failed: 5, duration: "15m")

**Dashboard Needs**:
- See overall job progress (995/1000 complete)
- Identify which 5 customers failed
- For each failure, see the error and input data
- Visualize processing speed over time (started fast, slowed down)
- Alert if job stalls (no progress for 5 minutes)
