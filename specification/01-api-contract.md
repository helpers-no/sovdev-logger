# Sovdev Logger API Contract

## Overview

All sovdev-logger implementations MUST provide these 8 core functions with identical behavior across languages. Function names and parameter names are standardized, but parameter types should follow language conventions (e.g., `string | undefined` in TypeScript, `Optional<String>` in Java, `Option<String>` in Rust).

**Core Functions** (Mandatory):
1. `sovdev_initialize()` - Initialize logger with service info
2. `sovdev_log()` - Log a transaction
3. `sovdev_log_job_status()` - Log job lifecycle events
4. `sovdev_log_job_progress()` - Log job progress
5. `sovdev_flush()` - Flush logs to backends
6. `sovdev_start_span()` - Start distributed trace span
7. `sovdev_end_span()` - End distributed trace span
8. `create_peer_services()` - Create peer service mappings

**Optional Diagnostic Functions** (Recommended for development):
9. `sovdev_validate_config()` - Validate OTLP environment configuration
10. `sovdev_test_otlp_connection()` - Test connectivity to OTLP endpoints

**NOTE**: This specification has been updated to use OpenTelemetry spans for distributed tracing instead of manual trace_id management. See sections 6-7 for `sovdev_start_span()` and `sovdev_end_span()`.

---

## 1. sovdev_initialize

**Purpose**: Initialize the logger with service information and peer service mappings.

**TypeScript Signature**:
```typescript
sovdev_initialize(
  service_name: string,
  service_version?: string,
  peer_services?: { [key: string]: string }
): void
```

**Python Signature**:
```python
def sovdev_initialize(
    service_name: str,
    service_version: str = "1.0.0",
    peer_services: Optional[Dict[str, str]] = None
) -> None:
    """
    Initialize the sovdev-logger.

    Args:
        service_name: Service identifier (from SYSTEM_ID env var)
        service_version: Service version (defaults to "1.0.0")
        peer_services: Peer service mapping from create_peer_services()

    Raises:
        ValueError: If service_name is empty
    """
```

**Parameters**:
- `service_name`: Service identifier (from SYSTEM_ID env var or hardcoded)
- `service_version`: Service version (optional, defaults to "1.0.0")
- `peer_services`: Peer service mapping from create_peer_services() (optional)

**Behavior**:
- MUST be called before any logging operations
- MUST initialize OpenTelemetry SDK with logs, metrics, and traces
- MUST set up all transports (console, file, error file, OTLP)
- MUST generate a unique session ID (UUID v4) for this execution
- MUST store peer service mappings for validation
- MUST be idempotent (safe to call multiple times)

**Example**:
```typescript
// Define peer services - INTERNAL is auto-generated
const PEER_SERVICES = create_peer_services({
  BRREG: 'SYS1234567',  // External system (Norwegian company registry)
  ALTINN: 'SYS7654321'   // External system (Government portal)
});

// Initialize at application startup
sovdev_initialize(
  'company-lookup-service',  // Service name
  '2.1.0',                    // Service version
  PEER_SERVICES.mappings      // Peer service mappings
);

// After initialization, PEER_SERVICES provides type-safe constants:
// - PEER_SERVICES.BRREG = 'SYS1234567'
// - PEER_SERVICES.ALTINN = 'SYS7654321'
// - PEER_SERVICES.INTERNAL = 'company-lookup-service' (auto-generated)
```

---

## 2. sovdev_log

**Purpose**: Log a transaction with optional input/output data and exception.

**TypeScript Signature**:
```typescript
// Type definition
type sovdev_log_level = 'trace' | 'debug' | 'info' | 'warn' | 'error' | 'fatal';

sovdev_log(
  level: sovdev_log_level,  // Accepts: SOVDEV_LOGLEVELS.INFO or 'info'
  function_name: string,
  message: string,
  peer_service: string,
  input_json?: any,
  response_json?: any,
  exception?: Error,
  trace_id?: string
): void
```

**Python Signature**:
```python
def sovdev_log(
    level: str,
    function_name: str,
    message: str,
    peer_service: str,
    input_json: Optional[Any] = None,
    response_json: Optional[Any] = None,
    exception: Optional[BaseException] = None,
    trace_id: Optional[str] = None
) -> None:
    """
    Log a transaction with optional input/output and exception.

    Args:
        level: Log level (use SOVDEV_LOGLEVELS enum or string)
        function_name: Name of the function being logged
        message: Human-readable message
        peer_service: Target system identifier
        input_json: Request data (any JSON-serializable type)
        response_json: Response data (any JSON-serializable type)
        exception: Exception object (if logging error)
        trace_id: UUID for transaction correlation (auto-generated if None)
    """
```

**Parameters**:
- `level`: Log level (TRACE, DEBUG, INFO, WARN, ERROR, FATAL)
- `function_name`: Function/method name where logging occurs
- `message`: Human-readable log message
- `peer_service`: Target system/service identifier (from PEER_SERVICES)
- `input_json`: Request/input data (optional, will be JSON serialized)
- `response_json`: Response/output data (optional, will be JSON serialized)
- `exception`: Exception/error object (optional, will be processed for security)
- `trace_id`: Business transaction ID (optional, generates UUID if not provided)

**Behavior**:
- MUST create structured log entry with all fields
- MUST generate trace_id if not provided (UUID v4)
- MUST generate event_id (UUID v4)
- MUST serialize input_json and response_json to JSON strings
- MUST process exception for security (credential removal, stack limit 350 chars)
- MUST create OpenTelemetry span with attributes
- MUST increment metrics (sovdev_operations_total, sovdev_errors_total if ERROR/FATAL)
- MUST set log_type to "transaction"
- MUST always include response_json field (value "null" if not provided)

**Example - Basic Transaction Log**:
```typescript
async function lookupCompany(orgNumber: string): Promise<void> {
  const FUNCTIONNAME = 'lookupCompany';  // Best practice: Define function name as constant
  const input = { organisasjonsnummer: orgNumber };  // Best practice: Define input as variable

  // Simple INFO log with input and response
  sovdev_log(
    SOVDEV_LOGLEVELS.INFO,
    FUNCTIONNAME,                     // Use constant (easier to maintain)
    `Looking up company ${orgNumber}`, // Human-readable message
    PEER_SERVICES.BRREG,               // External system
    input,                             // Reuse input variable
    null,                              // No response yet
    null,                              // No exception
    null                               // Auto-generate trace_id
  );

  // ... fetch company data ...
  const response = { navn: 'REMA 1000 AS' };  // Best practice: Define response as variable

  sovdev_log(
    SOVDEV_LOGLEVELS.INFO,
    FUNCTIONNAME,                     // Same constant
    `Company found: ${response.navn}`,
    PEER_SERVICES.BRREG,
    input,                             // Reuse same input variable
    response,                          // Use response variable
    null,
    null
  );
}
```

**Example - Error Log with Exception**:
```typescript
async function lookupCompany(orgNumber: string, trace_id?: string): Promise<void> {
  const FUNCTIONNAME = 'lookupCompany';  // Best practice: Define function name as constant
  const txn_trace_id = trace_id || sovdev_generate_trace_id();  // Use provided or generate new
  const input = { organisasjonsnummer: orgNumber };  // Best practice: Define input as variable

  sovdev_log(
    SOVDEV_LOGLEVELS.INFO,
    FUNCTIONNAME,
    `Looking up company ${orgNumber}`,
    PEER_SERVICES.BRREG,
    input,
    null,
    null,
    txn_trace_id  // Same trace_id for related logs
  );

  try {
    const companyData = await fetchCompanyData(orgNumber);
    const response = {  // Best practice: Define response as variable
      navn: companyData.navn,
      organisasjonsform: companyData.organisasjonsform?.beskrivelse
    };

    sovdev_log(
      SOVDEV_LOGLEVELS.INFO,
      FUNCTIONNAME,
      `Company found: ${companyData.navn}`,
      PEER_SERVICES.BRREG,
      input,      // Reuse same input variable
      response,   // Use response variable
      null,
      txn_trace_id  // SAME trace_id links request and response
    );
  } catch (error) {
    // ERROR log with exception handling
    sovdev_log(
      SOVDEV_LOGLEVELS.ERROR,
      FUNCTIONNAME,                       // Same constant
      `Failed to lookup company ${orgNumber}`,
      PEER_SERVICES.BRREG,
      input,                              // Reuse same input variable
      null,                               // No response data
      error,                              // Exception object (will be sanitized)
      txn_trace_id                          // SAME trace_id for error
    );
  }
}
```

**Example - Trace Correlation**:
```typescript
// This example shows how the same input variable and trace_id are reused
// across multiple log calls within a single function - see previous example
// for the complete pattern with FUNCTIONNAME constant, input variable, and
// response variable all following best practices.

// Key benefit: If you need to change the input structure or add fields,
// you only change it in ONE place (the variable definition) rather than
// in every sovdev_log() call.

// In Grafana: {trace_id="<uuid>"} shows all logs with the same trace_id together
```

---

## 3. sovdev_log_job_status

**Purpose**: Log batch job status (Started, Completed, Failed).

**TypeScript Signature**:
```typescript
sovdev_log_job_status(
  level: sovdev_log_level,  // Accepts: SOVDEV_LOGLEVELS.INFO or 'info'
  function_name: string,
  job_name: string,
  status: string,
  peer_service: string,
  input_json?: any,
  trace_id?: string
): void
```

**Python Signature**:
```python
def sovdev_log_job_status(
    level: str,
    function_name: str,
    job_name: str,
    status: str,
    peer_service: str,
    input_json: Optional[Any] = None,
    trace_id: Optional[str] = None
) -> None:
    """
    Log batch job status (Started, Completed, Failed).

    Args:
        level: Log level (typically INFO or ERROR)
        function_name: Function name managing the job
        job_name: Human-readable job name
        status: Job status ("Started", "Completed", "Failed", etc.)
        peer_service: Target system or INTERNAL for internal jobs
        input_json: Job metadata (total items, success count, etc.)
        trace_id: Job correlation ID (use same ID for all logs in this job)
    """
```

**Parameters**:
- `level`: Log level (typically INFO or ERROR)
- `function_name`: Function name managing the job
- `job_name`: Human-readable job name
- `status`: Job status ("Started", "Completed", "Failed", etc.)
- `peer_service`: Target system or INTERNAL for internal jobs
- `input_json`: Job metadata (total items, success count, etc.)
- `trace_id`: Job correlation ID (use same ID for all logs in this job)

**Behavior**:
- MUST create structured log entry with job metadata
- MUST set log_type to "job.status"
- MUST format message as "Job {status}: {job_name}"
- MUST include job status information in input_json
- MUST use provided trace_id for job correlation

**Example - Complete Batch Job Tracking**:
```typescript
async function batchLookup(orgNumbers: string[]): Promise<void> {
  const job_name = 'CompanyLookupBatch';  // Best practice: Define job name as constant
  const FUNCTIONNAME = 'batchLookup';    // Best practice: Define function name as constant
  const batch_trace_id = sovdev_generate_trace_id();  // Generate ONE trace_id for entire batch job
  const job_start_input = { totalCompanies: orgNumbers.length };  // Best practice: Define input as variable

  // 1. Log job start - internal job
  sovdev_log_job_status(
    SOVDEV_LOGLEVELS.INFO,
    FUNCTIONNAME,                     // Use constant
    job_name,                          // Use constant
    'Started',                        // Status
    PEER_SERVICES.INTERNAL,           // Internal job (not external system)
    job_start_input,                    // Use variable
    batch_trace_id                      // All job logs share this trace_id
  );

  // 2. Process items (see sovdev_log_job_progress for progress tracking)
  let successful = 0;
  let failed = 0;
  for (let i = 0; i < orgNumbers.length; i++) {
    try {
      await lookupCompany(orgNumbers[i]);
      successful++;
    } catch (error) {
      failed++;
    }
  }

  // 3. Log job completion - internal job
  const job_completion_input = {  // Best practice: Define completion input as variable
    totalCompanies: orgNumbers.length,
    successful,
    failed
  };

  sovdev_log_job_status(
    SOVDEV_LOGLEVELS.INFO,
    FUNCTIONNAME,                     // Same constant
    job_name,                          // Same constant
    'Completed',                      // Status changed
    PEER_SERVICES.INTERNAL,
    job_completion_input,               // Use variable
    batch_trace_id                      // SAME trace_id links start and completion
  );
}

// In Grafana: {trace_id="<batch-uuid>"} shows complete job lifecycle
// - Job Started log
// - All progress logs
// - Job Completed log
```

---

## 4. sovdev_log_job_progress

**Purpose**: Log progress for individual items in a batch job.

**TypeScript Signature**:
```typescript
sovdev_log_job_progress(
  level: sovdev_log_level,  // Accepts: SOVDEV_LOGLEVELS.INFO or 'info'
  function_name: string,
  item_id: string,
  current: number,
  total: number,
  peer_service: string,
  input_json?: any,
  trace_id?: string
): void
```

**Python Signature**:
```python
def sovdev_log_job_progress(
    level: str,
    function_name: str,
    item_id: str,
    current: int,
    total: int,
    peer_service: str,
    input_json: Optional[Any] = None,
    trace_id: Optional[str] = None
) -> None:
    """
    Log progress for individual items in a batch job.

    Args:
        level: Log level (typically INFO)
        function_name: Function name processing items
        item_id: Identifier for current item being processed
        current: Current item number (1-based)
        total: Total number of items
        peer_service: Target system for this item
        input_json: Item-specific data
        trace_id: Job correlation ID (same as job status logs)
    """
```

**Parameters**:
- `level`: Log level (typically INFO)
- `function_name`: Function name processing items
- `item_id`: Identifier for current item being processed
- `current`: Current item number (1-based)
- `total`: Total number of items
- `peer_service`: Target system for this item
- `input_json`: Item-specific data
- `trace_id`: Job correlation ID (same as job status logs)

**Behavior**:
- MUST create structured log entry with progress metadata
- MUST set log_type to "job.progress"
- MUST format message as "Processing {item_id} ({current}/{total})"
- MUST calculate progress_percentage: Math.round((current / total) * 100)
- MUST include progress fields in input_json (current_item, total_items, item_id, progress_percentage)

**Example - Batch Processing with Progress Tracking**:
```typescript
async function batchLookup(orgNumbers: string[]): Promise<void> {
  const job_name = 'CompanyLookupBatch';
  const FUNCTIONNAME = 'batchLookup';  // Best practice: Define function name as constant
  const batch_trace_id = sovdev_generate_trace_id();  // ONE trace_id for entire batch
  const job_start_input = { totalCompanies: orgNumbers.length };

  // Log job start (see sovdev_log_job_status example)
  sovdev_log_job_status(
    SOVDEV_LOGLEVELS.INFO,
    FUNCTIONNAME,
    job_name,
    'Started',
    PEER_SERVICES.INTERNAL,
    job_start_input,
    batch_trace_id
  );

  // Process each item with progress tracking
  for (let i = 0; i < orgNumbers.length; i++) {
    const orgNumber = orgNumbers[i];
    const item_trace_id = sovdev_generate_trace_id();  // Unique trace_id for each item
    const progress_input = { organisasjonsnummer: orgNumber };  // Best practice: Define input as variable

    // Log progress - tracking BRREG processing
    sovdev_log_job_progress(
      SOVDEV_LOGLEVELS.INFO,
      FUNCTIONNAME,                // Use constant
      orgNumber,                    // Item identifier
      i + 1,                        // Current item (1-based)
      orgNumbers.length,            // Total items
      PEER_SERVICES.BRREG,          // External system for this item
      progress_input,                // Use variable
      batch_trace_id                  // Progress logs use batch trace_id
    );

    // Process the item (uses separate item_trace_id for request/response)
    await lookupCompany(orgNumber, item_trace_id);
  }

  // Log job completion (see sovdev_log_job_status example)
  const job_completion_input = {
    totalCompanies: orgNumbers.length,
    successful: orgNumbers.length,
    failed: 0
  };

  sovdev_log_job_status(
    SOVDEV_LOGLEVELS.INFO,
    FUNCTIONNAME,
    job_name,
    'Completed',
    PEER_SERVICES.INTERNAL,
    job_completion_input,
    batch_trace_id
  );
}

// Result: Two levels of correlation
// 1. Batch level: {trace_id="<batch-uuid>"} shows all progress logs + job status
// 2. Item level: {trace_id="<item-uuid>"} shows request/response for specific item
```

---

## 5. sovdev_flush

**Purpose**: Flush all pending OTLP batches to ensure logs/metrics/traces are exported.

**TypeScript Signature**:
```typescript
sovdev_flush(): Promise<void>
```

**Python Signature**:
```python
def sovdev_flush() -> None:
    """
    Flush all pending logs, metrics, and traces.

    Blocks until all data is exported or 30-second timeout occurs.
    Safe to call from signal handlers and atexit hooks.

    Note: Python uses synchronous flush (blocks), unlike TypeScript async.
    """
```

**Behavior**:
- MUST flush all pending log records to OTLP endpoint
- MUST flush all pending metrics to OTLP endpoint
- MUST flush all pending spans to OTLP endpoint
- MUST be called before application exit (including error exits)
- MUST be awaited in async contexts
- SHOULD complete within reasonable timeout (30 seconds recommended)

**Critical**: Without flushing, the final batch of logs (including job completion status) will be lost when application exits. OpenTelemetry uses batching for performance.

**Example - Application Shutdown**:
```typescript
async function main() {
  sovdev_initialize('company-lookup-service', '1.0.0', PEER_SERVICES.mappings);

  try {
    await batchLookup(orgNumbers);
  } finally {
    await sovdev_flush();  // CRITICAL: Flush before exit
  }
}
```

**See Also**:
- **Batch Processing Details**: `03-implementation-patterns.md` → OpenTelemetry Batch Processing
- **Error Handling**: `04-error-handling.md` → Error Handling in sovdev_flush()
- **Signal Handlers**: `04-error-handling.md` → Exit Handler Integration

---

## 6. sovdev_start_span

**Purpose**: Start an OpenTelemetry span for distributed tracing of an operation.

**TypeScript Signature**:
```typescript
sovdev_start_span(
  operation_name: string,
  attributes?: Record<string, any>
): Span
```

**Python Signature**:
```python
def sovdev_start_span(
    operation_name: str,
    attributes: Optional[Dict[str, Any]] = None
) -> Span:
    """
    Start an OpenTelemetry span for distributed tracing.

    Args:
        operation_name: Name of the operation being traced (e.g., 'lookupCompany', 'processOrder')
        attributes: Optional metadata for searchable traces (e.g., input parameters, identifiers)

    Returns:
        Span: Opaque handle that must be passed to sovdev_end_span()

    Behavior:
        Creates a new OpenTelemetry span and makes it active.
        All subsequent sovdev_log() calls will automatically include:
        - trace_id: OpenTelemetry trace ID (links all operations in this distributed transaction)
        - span_id: Unique identifier for this specific operation

    Note:
        Must call sovdev_end_span(span) when the operation completes.
        Spans are sent to Tempo for distributed tracing visualization.
    """
```

**Behavior**:
- MUST create a new OpenTelemetry span with the given operation name
- MUST make the span active so subsequent logs inherit trace_id and span_id
- MUST return a Span handle (opaque object)
- MUST be paired with `sovdev_end_span(span)` when operation completes
- The returned span handle MUST be passed to `sovdev_end_span()`
- Optional attributes parameter allows adding searchable metadata to the span
- Logs within the span will have both `trace_id` and `span_id` fields
- Logs outside a span will only have `trace_id` (fallback UUID for correlation)

**Example - Basic Span Usage**:
```typescript
async function lookupCompany(orgNumber: string): Promise<void> {
  const FUNCTIONNAME = 'lookupCompany';
  const input = { organisasjonsnummer: orgNumber };

  // Start span and CAPTURE the handle
  const span = sovdev_start_span(FUNCTIONNAME, input);

  try {
    // All logs within this span automatically get trace_id + span_id
    sovdev_log(
      SOVDEV_LOGLEVELS.INFO,
      FUNCTIONNAME,
      `Looking up company ${orgNumber}`,
      PEER_SERVICES.BRREG,
      input
    );

    const companyData = await fetchCompanyData(orgNumber);
    const response = { navn: companyData.navn };

    sovdev_log(
      SOVDEV_LOGLEVELS.INFO,
      FUNCTIONNAME,
      `Company found: ${response.navn}`,
      PEER_SERVICES.BRREG,
      input,
      response
    );

    // End span on success - PASS the span handle
    sovdev_end_span(span);
  } catch (error) {
    sovdev_log(
      SOVDEV_LOGLEVELS.ERROR,
      FUNCTIONNAME,
      `Failed to lookup company ${orgNumber}`,
      PEER_SERVICES.BRREG,
      input,
      null,
      error
    );
    // End span with error - marks span as failed
    sovdev_end_span(span, error);
    throw error;
  }
}

// Result: All 3 logs share same trace_id and span_id
// In Tempo: This appears as a single trace with 3 log events
// Note: Span is ended in both success and error cases (not in finally block)
```

**When to Use Spans**:
- ✅ **Use for**: HTTP requests, database queries, external API calls, batch processing operations
- ❌ **Don't use for**: Every single log (creates overhead), simple internal calculations

---

## 7. sovdev_end_span

**Purpose**: End the currently active OpenTelemetry span.

**TypeScript Signature**:
```typescript
sovdev_end_span(span: Span, error?: Error): void
```

**Python Signature**:
```python
def sovdev_end_span(span: Span, error: Optional[BaseException] = None) -> None:
    """
    End the currently active OpenTelemetry span.

    Args:
        span: The span handle returned from sovdev_start_span()
        error: Optional error if operation failed (marks span as failed)

    Behavior:
        Closes the active span and clears it from context.
        Subsequent logs will not include span_id (only trace_id).
        The span is sent to Tempo for distributed tracing.
        If error is provided, span status is set to ERROR and exception is recorded.

    Important:
        Must pass the span handle returned from sovdev_start_span().
        Call with error parameter in catch/except blocks to mark span as failed.
    """
```

**Behavior**:
- MUST end the span identified by the span parameter
- MUST clear the span from active context
- MUST flush the span to OpenTelemetry (sent to Tempo)
- If error parameter provided, MUST set span status to ERROR
- If error parameter provided, MUST record exception details on the span
- Subsequent logs will NOT have `span_id` until next `sovdev_start_span()`
- Should be called in both success and error paths (not necessarily in finally block)
- The span parameter is REQUIRED (returned from sovdev_start_span)

**Example - Nested Spans**:
```typescript
async function batchLookup(orgNumbers: string[]): Promise<void> {
  const FUNCTIONNAME = 'batchLookup';

  // Start span for the entire batch operation - CAPTURE the handle
  const batchSpan = sovdev_start_span('batchProcessing', {
    totalCompanies: orgNumbers.length
  });

  try {
    sovdev_log(
      SOVDEV_LOGLEVELS.INFO,
      FUNCTIONNAME,
      'Starting batch lookup',
      PEER_SERVICES.INTERNAL,
      { totalCompanies: orgNumbers.length }
    );

    for (const orgNumber of orgNumbers) {
      // Each item gets its own span (nested within batch span)
      await lookupCompany(orgNumber);  // This creates its own span
    }

    sovdev_log(
      SOVDEV_LOGLEVELS.INFO,
      FUNCTIONNAME,
      'Batch lookup completed',
      PEER_SERVICES.INTERNAL,
      { totalCompanies: orgNumbers.length }
    );

    // End batch span on success - PASS the span handle
    sovdev_end_span(batchSpan);
  } catch (error) {
    // End batch span with error - marks span as failed
    sovdev_end_span(batchSpan, error);
    throw error;
  }
}

// Result in Tempo: Hierarchical trace structure
// - Batch span (parent)
//   - Company lookup span 1 (child)
//   - Company lookup span 2 (child)
//   - Company lookup span 3 (child)
```

---

## 8. create_peer_services

**Purpose**: Create type-safe peer service mapping with INTERNAL auto-generation.

**TypeScript Signature**:
```typescript
create_peer_services<T extends Record<string, string>>(
  definitions: T
): {
  [K in keyof T]: string;
} & {
  INTERNAL: string;
  mappings: Record<string, string>;
}
```

**Python Signature**:
```python
class PeerServices:
    """Type-safe peer service constants."""
    mappings: Dict[str, str]
    INTERNAL: str
    # Dynamic attributes for each defined service

def create_peer_services(definitions: Dict[str, str]) -> PeerServices:
    """
    Create peer service mapping with INTERNAL auto-generation.

    Args:
        definitions: Dictionary mapping service names to system IDs

    Returns:
        PeerServices object with:
        - Attribute access (PEER_SERVICES.BRREG returns 'BRREG')
        - Mapping access (PEER_SERVICES.mappings returns full dict)
        - Auto-generated INTERNAL constant

    Example:
        >>> PEER_SERVICES = create_peer_services({
        ...     'BRREG': 'SYS1234567',
        ...     'ALTINN': 'SYS7654321'
        ... })
        >>> PEER_SERVICES.BRREG  # Returns 'BRREG' (constant name)
        'BRREG'
        >>> PEER_SERVICES.mappings  # Returns full mapping
        {'BRREG': 'SYS1234567', 'ALTINN': 'SYS7654321'}
    """
```

**Parameters**:
- `definitions`: Object mapping peer service names to CMDB system IDs

**Behavior**:
- MUST create constants for each defined peer service
- MUST auto-generate INTERNAL constant with value equal to service name
- MUST return mappings object for sovdev_initialize()
- MUST provide type-safe access to peer service IDs

**Example - Type-Safe Peer Service Mapping**:
```typescript
// Define peer services - INTERNAL is auto-generated
const PEER_SERVICES = create_peer_services({
  BRREG: 'SYS1234567',  // Norwegian company registry
  ALTINN: 'SYS7654321', // Government portal
  CRM: 'SYS9876543'     // Customer relationship management system
});

// After creation, PEER_SERVICES provides:
// - Type-safe constants (compile-time validation)
// - Auto-generated INTERNAL (equals service name)
// - Mappings object for sovdev_initialize()

// Type-safe usage - compiler prevents typos:
sovdev_log(
  SOVDEV_LOGLEVELS.INFO,
  'fetchCompany',
  'Fetching from BRREG',
  PEER_SERVICES.BRREG,  // ✅ Valid - IntelliSense autocomplete
  { orgNumber: '971277882' }
);

// Compiler error: Property 'BRRG' does not exist
// sovdev_log(..., PEER_SERVICES.BRRG, ...)  // ❌ Typo caught at compile time

// Internal operations use auto-generated INTERNAL:
sovdev_log_job_status(
  SOVDEV_LOGLEVELS.INFO,
  'processData',
  'DataProcessingJob',
  'Started',
  PEER_SERVICES.INTERNAL,  // Auto-generated, equals service name
  { totalItems: 100 }
);

// Initialize logger with mappings:
sovdev_initialize(
  'company-lookup-service',
  '1.0.0',
  PEER_SERVICES.mappings  // Includes all defined peers + INTERNAL
);

// PEER_SERVICES object structure:
// {
//   BRREG: 'BRREG',           // String constant (not the system ID)
//   ALTINN: 'ALTINN',         // String constant (not the system ID)
//   CRM: 'CRM',               // String constant (not the system ID)
//   INTERNAL: 'INTERNAL',     // String constant 'INTERNAL'
//   mappings: {
//     BRREG: 'SYS1234567',    // Original CMDB system ID
//     ALTINN: 'SYS7654321',   // Original CMDB system ID
//     CRM: 'SYS9876543'       // Original CMDB system ID
//   }
// }
//
// Note: The logger will resolve 'BRREG' to 'SYS1234567' internally using mappings.
//       For 'INTERNAL', the logger replaces it with the actual service name.
```

---

## Optional Diagnostic Functions

⚠️ **These functions are OPTIONAL and NOT part of the mandatory 8-function API contract.**

These diagnostic functions help validate OTLP configuration and connectivity during development and deployment. They are designed to be called **before** `sovdev_initialize()` to catch configuration issues early.

**Key Principles**:
- **Optional**: Implementations MAY provide these functions
- **Non-blocking**: These functions MUST NOT exit the process or throw unhandled exceptions
- **Warn-only**: They should log warnings but allow execution to continue
- **Pre-initialization**: Can be called before `sovdev_initialize()`
- **Development aid**: Primarily useful during implementation and debugging

---

### 9. sovdev_validate_config

**Purpose**: Validate that all required OpenTelemetry environment variables are set and properly formatted.

**TypeScript Signature**:
```typescript
sovdev_validate_config(): {
  valid: boolean;
  missing: string[];
  warnings: string[];
  config: {
    serviceName: string | undefined;
    logsEndpoint: string | undefined;
    metricsEndpoint: string | undefined;
    tracesEndpoint: string | undefined;
    headers: string | undefined;
    protocol: string | undefined;
  };
}
```

**Parameters**: None

**Returns**: Object containing:
- `valid`: `true` if all required environment variables are set, `false` otherwise
- `missing`: Array of missing required environment variable names
- `warnings`: Array of configuration warnings (e.g., missing optional variables)
- `config`: Object containing current configuration values (may contain `undefined` values)

**Checks for Required Variables**:
1. `OTEL_SERVICE_NAME` - Service identifier
2. `OTEL_EXPORTER_OTLP_LOGS_ENDPOINT` - Logs endpoint URL
3. `OTEL_EXPORTER_OTLP_METRICS_ENDPOINT` - Metrics endpoint URL
4. `OTEL_EXPORTER_OTLP_TRACES_ENDPOINT` - Traces endpoint URL
5. `OTEL_EXPORTER_OTLP_HEADERS` - HTTP headers (must be JSON format)

**Checks for Optional Variables**:
- `OTEL_EXPORTER_OTLP_PROTOCOL` - Protocol type (default: grpc, recommended: http/protobuf)

**Validates**:
- Headers contain `Host` header (required for Traefik routing)
- Headers are valid JSON format

**Behavior**:
- MUST check all required environment variables
- MUST NOT exit process or throw exceptions
- MUST return validation results as structured object
- MAY log warnings to console
- SHOULD validate header format (JSON)
- SHOULD check for common misconfigurations

**Example Usage**:
```typescript
// Validate configuration before initialization
const validation = sovdev_validate_config();

if (!validation.valid) {
  console.warn('⚠️  OTLP configuration incomplete:');
  validation.missing.forEach(v => console.warn(`    - ${v}`));
  console.warn('    File logging will work, but OTLP export may be disabled.');
}

if (validation.warnings.length > 0) {
  console.warn('⚠️  Configuration warnings:');
  validation.warnings.forEach(w => console.warn(`    - ${w}`));
}

// Proceed with initialization anyway (file logging still works)
sovdev_initialize('my-service', '1.0.0');
```

**When to Use**:
- ✅ During development to verify .env file is configured correctly
- ✅ In deployment scripts to validate environment before starting service
- ✅ In health check endpoints to report configuration status
- ✅ When debugging "why aren't logs appearing in Loki/Prometheus/Tempo?"
- ❌ NOT required for normal application operation

---

### 10. sovdev_test_otlp_connection

**Purpose**: Test connectivity to all three OTLP endpoints (logs, metrics, traces) by sending properly formatted test data.

**TypeScript Signature**:
```typescript
sovdev_test_otlp_connection(timeout?: number): Promise<{
  success: boolean;
  logs: { reachable: boolean; error?: string };
  metrics: { reachable: boolean; error?: string };
  traces: { reachable: boolean; error?: string };
}>
```

**Parameters**:
- `timeout`: Optional timeout in milliseconds (default: 5000ms)

**Returns**: Promise resolving to object containing:
- `success`: `true` if ALL three endpoints are reachable, `false` if ANY fail
- `logs`: Connectivity result for logs endpoint
  - `reachable`: `true` if endpoint responds with 200/202 status
  - `error`: Error message if unreachable (optional)
- `metrics`: Connectivity result for metrics endpoint
- `traces`: Connectivity result for traces endpoint

**Behavior**:
- MUST send properly formatted OTLP JSON payloads (not empty payloads)
- MUST test all three endpoints: `/v1/logs`, `/v1/metrics`, `/v1/traces`
- MUST include all required headers (including `Host` header for Traefik)
- MUST respect timeout parameter
- MUST NOT exit process or throw unhandled exceptions
- MUST return structured results even if all endpoints fail
- SHOULD send minimal valid OTLP data (single log record, metric data point, span)
- SHOULD use language-native HTTP client that allows custom headers

**OTLP Payload Format**:
The function must send valid OTLP/JSON payloads as defined by OpenTelemetry spec:

**Logs Payload** (`/v1/logs`):
```json
{
  "resourceLogs": [{
    "resource": {
      "attributes": [{"key": "service.name", "value": {"stringValue": "connectivity-test"}}]
    },
    "scopeLogs": [{
      "scope": {"name": "connectivity-test"},
      "logRecords": [{
        "timeUnixNano": "1699999999000000000",
        "severityNumber": 9,
        "severityText": "INFO",
        "body": {"stringValue": "OTLP connectivity test"}
      }]
    }]
  }]
}
```

**Metrics Payload** (`/v1/metrics`):
```json
{
  "resourceMetrics": [{
    "resource": {
      "attributes": [{"key": "service.name", "value": {"stringValue": "connectivity-test"}}]
    },
    "scopeMetrics": [{
      "scope": {"name": "connectivity-test"},
      "metrics": [{
        "name": "connectivity.test",
        "sum": {
          "dataPoints": [{"asInt": "1", "timeUnixNano": "1699999999000000000"}],
          "aggregationTemporality": 2,
          "isMonotonic": true
        }
      }]
    }]
  }]
}
```

**Traces Payload** (`/v1/traces`):
```json
{
  "resourceSpans": [{
    "resource": {
      "attributes": [{"key": "service.name", "value": {"stringValue": "connectivity-test"}}]
    },
    "scopeSpans": [{
      "scope": {"name": "connectivity-test"},
      "spans": [{
        "traceId": "0123456789abcdef0123456789abcdef",
        "spanId": "0123456789abcdef",
        "name": "connectivity-test",
        "kind": 1,
        "startTimeUnixNano": "1699999999000000000",
        "endTimeUnixNano": "1699999999001000000",
        "status": {"code": 1}
      }]
    }]
  }]
}
```

**HTTP Status Codes**:
- `200 OK` or `202 Accepted`: Endpoint is reachable and accepting data ✅
- `400 Bad Request`: Endpoint is reachable but may reject malformed data (still consider reachable) ✅
- `404 Not Found`: Usually indicates missing `Host` header or incorrect routing ❌
- `Timeout`: Network issue or endpoint unreachable ❌
- `Connection refused`: Service not running ❌

**Example Usage**:
```typescript
// Test connectivity before initialization
console.log('🔌 Testing OTLP connectivity...');
const connectivityTest = await sovdev_test_otlp_connection(5000);

if (!connectivityTest.success) {
  console.warn('⚠️  OTLP connectivity issues detected:');

  if (!connectivityTest.logs.reachable) {
    console.warn(`    Logs: ${connectivityTest.logs.error}`);
  }

  if (!connectivityTest.metrics.reachable) {
    console.warn(`    Metrics: ${connectivityTest.metrics.error}`);
  }

  if (!connectivityTest.traces.reachable) {
    console.warn(`    Traces: ${connectivityTest.traces.error}`);
  }

  console.warn('    Proceeding anyway (file logging will still work)...');
} else {
  console.log('✅ All OTLP endpoints reachable');
}

// Proceed with initialization anyway
sovdev_initialize('my-service', '1.0.0');
```

**When to Use**:
- ✅ During development to verify OTLP collector is running and accessible
- ✅ In deployment health checks to validate infrastructure connectivity
- ✅ When debugging "404 Not Found" errors (likely missing Host header)
- ✅ When debugging "connection refused" errors (collector not running)
- ✅ In CI/CD pipelines to validate deployment environment
- ❌ NOT required for normal application operation
- ❌ NOT a replacement for proper monitoring

**Implementation Note**:
Some HTTP client libraries (e.g., `fetch()` in Node.js) restrict certain headers like `Host` for security reasons. Implementations should use native HTTP clients (e.g., `http`/`https` modules in Node.js, `HttpClient` in C#, `net/http` in Go) that allow full header control.

**Why Three Separate Endpoints?**
OpenTelemetry OTLP collector exposes three separate endpoints by design:
- Each signal type (logs, metrics, traces) has different structure and backend routing
- Different signals may be sent to different backends (e.g., Loki for logs, Prometheus for metrics, Tempo for traces)
- This is OpenTelemetry specification standard, not an implementation choice

---

## Log Levels

All implementations MUST support these 6 log levels:

**TypeScript**:
```typescript
// Constants object
export const SOVDEV_LOGLEVELS = {
  TRACE: 'trace',   // Severity: 1  (OpenTelemetry)
  DEBUG: 'debug',   // Severity: 5  (OpenTelemetry)
  INFO: 'info',     // Severity: 9  (OpenTelemetry)
  WARN: 'warn',     // Severity: 13 (OpenTelemetry)
  ERROR: 'error',   // Severity: 17 (OpenTelemetry)
  FATAL: 'fatal'    // Severity: 21 (OpenTelemetry)
} as const;

// Type definition (string literal union)
export type sovdev_log_level = typeof SOVDEV_LOGLEVELS[keyof typeof SOVDEV_LOGLEVELS];
// Resolves to: 'trace' | 'debug' | 'info' | 'warn' | 'error' | 'fatal'

// Usage: Both constants and strings work
sovdev_log(SOVDEV_LOGLEVELS.INFO, ...)  // Recommended (type-safe with autocomplete)
sovdev_log('info', ...)                  // Also works (string literal)
```

**Python**:
```python
from enum import Enum

class SOVDEV_LOGLEVELS(str, Enum):
    """
    Log levels matching OpenTelemetry severity numbers.

    Subclasses str to allow use as string literals.
    """
    TRACE = "trace"   # Severity: 1  (OpenTelemetry)
    DEBUG = "debug"   # Severity: 5  (OpenTelemetry)
    INFO = "info"     # Severity: 9  (OpenTelemetry)
    WARN = "warn"     # Severity: 13 (OpenTelemetry)
    ERROR = "error"   # Severity: 17 (OpenTelemetry)
    FATAL = "fatal"   # Severity: 21 (OpenTelemetry)

# Usage: Both enum and string work
sovdev_log(SOVDEV_LOGLEVELS.INFO, ...)  # Type-safe
sovdev_log("info", ...)  # Also works (string literal)
```

**Mapping to OpenTelemetry Severity**:
- TRACE → 1 (TRACE)
- DEBUG → 5 (DEBUG)
- INFO → 9 (INFO)
- WARN → 13 (WARN)
- ERROR → 17 (ERROR)
- FATAL → 21 (FATAL)

---

## Language-Specific Adaptations

### Naming Conventions

**ALL languages MUST use snake_case for function names to ensure cross-language consistency.**

- **TypeScript/JavaScript**: snake_case (sovdev_log, sovdev_flush)
- **Python**: snake_case (sovdev_log, sovdev_flush)
- **Go**: snake_case (sovdev_log, sovdev_flush)
- **Java**: snake_case (sovdev_log, sovdev_flush)
- **C#**: snake_case (sovdev_log, sovdev_flush)
- **PHP**: snake_case (sovdev_log, sovdev_flush)
- **Rust**: snake_case (sovdev_log, sovdev_flush)

**Note**: Even if your language convention prefers PascalCase (Go, C#) or camelCase (Java), you MUST use snake_case for the public API to maintain consistency across all language implementations.

### Optional Parameters
- **TypeScript**: `param?: Type`
- **Python**: `param: Optional[Type] = None`
- **Go**: Pointer types `*string` or variadic parameters
- **Java**: Method overloading or `Optional<Type>`
- **C#**: Nullable types `Type?` or default parameters
- **Rust**: `Option<Type>`

### Return Types
- **Async Operations**: Use language-native async/await patterns
- **sovdevFlush**: Return Promise/Future/Task depending on language

---

## Development Workflow

For complete implementation workflow, validation procedures, and development environment setup, see:

- **Development Loop**: `09-development-loop.md` - Iterative development workflow (Edit → Build → Test → Validate)
- **Validation Tools**: `tools/README.md` - Complete tool documentation with 8-step validation sequence
- **Environment Setup**: `05-environment-configuration.md` - DevContainer and Kubernetes cluster setup
- **Test Scenarios**: `06-test-scenarios.md` - Expected behavior and verification procedures

**Key Principle**: The specification is the contract. Fix your code to match the specification, not the other way around

---

## Error Handling

All functions MUST:
- Handle OpenTelemetry failures gracefully (log to console, continue execution)
- Validate required parameters (throw/return error if missing)
- Never throw exceptions that break user code
- Log initialization errors to console if OTLP export fails

---

## Version Compatibility

This API contract is **version 1.0.0**.

**Breaking Changes** (require major version bump):
- Removing or renaming functions
- Changing required parameters
- Changing parameter order
- Changing function behavior that breaks existing code

**Non-Breaking Changes** (minor version bump):
- Adding new optional parameters
- Adding new functions
- Adding new log levels

---

**Document Status:** ✅ v1.1.0 COMPLETE
**Last Updated:** 2025-11-12
**Part of:** sovdev-logger specification v1.2.0

**Changelog**:
- v1.1.0 (2025-11-12): Added Optional Diagnostic Functions section (sovdev_validate_config, sovdev_test_otlp_connection)
- v1.0.0 (2025-10-27): Initial release with 8 mandatory functions
