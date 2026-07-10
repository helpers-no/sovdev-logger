# @terchris/sovdev-logger

**One log call. Complete observability.**

Stop writing separate code for logs, metrics, and traces. Write one log entry and automatically get:
- ✅ **Structured logs** (Azure Log Analytics, Loki, or local files)
- ✅ **Metrics dashboards** (Azure Monitor, Prometheus, Grafana)
- ✅ **Distributed traces** (Azure Application Insights, Tempo)
- ✅ **Service dependency maps** (automatic correlation)

---

## Who Do You Write Logs For?

You write code for yourself during development. But **you write logs for the operations engineer staring at a screen at 7 PM on Friday.**

Picture this: Your application just crashed in production. Everyone on your team has left for the weekend. The ops engineer who got the alert doesn't know your codebase, doesn't know your business logic, and definitely doesn't want to be there right now. They're trying to piece together what went wrong from cryptic error messages and scattered log entries.

**Make their job easy.**

Good logging is the difference between:

- ❌ "Some null reference exception occurred somewhere" *(cue 3-hour debugging session)*
- ✅ "User authentication failed for email 'john@company.com' - invalid password attempt #3, account locked for security" *(fixed in 5 minutes)*

When you write clear, contextual logs, you're not just debugging future problems—**you're earning respect**. That ops engineer will look up who wrote this beautifully logged code and think: *"Now THIS is a developer who knows what they're doing."*

Help them get home to their family. Help yourself build a reputation as someone who writes production-ready code.

**Your future self (and your colleagues) will thank you.**

---

## The Problem: Traditional Observability is Complex

```typescript
// Traditional approach: 20+ lines per operation
logger.info('Payment processed', { orderId: '123' });
paymentCounter.inc();
paymentDuration.observe(duration);
const span = tracer.startSpan('processPayment');
span.setAttributes({ orderId: '123' });
span.end();
// ... manually correlate logs, metrics, traces
```

## The Solution: Zero-Effort Observability

```typescript
// sovdev-logger: 1 line, complete observability
const FUNCTIONNAME = 'processPayment';
const input = { orderId: '123', amount: 99.99 };
const output = { transactionId: 'tx-456', status: 'approved' };

sovdev_log(INFO, FUNCTIONNAME, 'Payment processed', PEER_SERVICES.PAYMENT_GATEWAY, input, output);
// ↑ Automatic logs + metrics + traces + correlation
```

**Result**: 95% less instrumentation code, complete observability out of the box.

---

## Quick Start (60 Seconds)

### 1. Install

```bash
npm install @terchris/sovdev-logger
```

### 2. Basic Usage (Console + File Logging)

Create `test.ts`:

```typescript
import { sovdev_initialize, sovdev_log, sovdev_shutdown, SOVDEV_LOGLEVELS, create_peer_services } from '@terchris/sovdev-logger';

// INTERNAL is auto-generated, just pass empty object if no external systems
const PEER_SERVICES = create_peer_services({});

async function main() {
  const FUNCTIONNAME = 'main';

  // Initialize
  sovdev_initialize('my-app');

  // Log with full context
  const input = { userId: '123', action: 'processOrder' };
  const output = { orderId: '456', status: 'success' };

  sovdev_log(
    SOVDEV_LOGLEVELS.INFO,
    FUNCTIONNAME,
    'Order processed successfully',
    PEER_SERVICES.INTERNAL,
    input,
    output
  );

  // Shut down before exit (CRITICAL!) — flushes and terminates the SDK.
  // This is a short script, so this is the true end of the process. In a
  // long-running server, call sovdev_flush() instead wherever you need
  // telemetry out sooner — it's safe to call repeatedly, unlike this.
  await sovdev_shutdown();
}

main().catch(console.error);
```

### 3. Run

```bash
npx tsx test.ts
```

### 4. See Results

- ✅ **Console**: Human-readable colored output
- ✅ **File**: Structured JSON in `./logs/dev.log`
- 📊 **Want Grafana dashboards?** → See [Configuration](#configuration)

---

## What You Get Automatically

```
┌─────────────────────────────────────────────────────┐
│  Your Code: sovdev_log(...)                        │
│             ↓                                       │
│  One Log Call                                       │
└──────────────┬──────────────────────────────────────┘
               │
    ┌──────────┼──────────┬──────────┐
    ↓          ↓          ↓          ↓
┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐
│ Logs   │ │Metrics │ │Traces  │ │ File   │
│Azure LA│ │Azure   │ │App     │ │ (JSON) │
│  Loki  │ │Monitor │ │Insights│ │        │
│        │ │Grafana │ │ Tempo  │ │        │
└────────┘ └────────┘ └────────┘ └────────┘
```

Every `sovdev_log()` call generates:
- **Logs**: Structured JSON with full context (what happened, input, output)
- **Metrics**: Counters, histograms, gauges for Azure Monitor, Prometheus, or Grafana
- **Traces**: Distributed tracing spans with automatic correlation (Azure Application Insights, Tempo)
- **Service Maps**: Automatic dependency graphs showing system-to-system calls
- **File Logs**: Optional JSON files for local development and debugging

**No extra code required.**

---

## Log Structure (snake_case Fields)

All log entries follow a consistent structure with **snake_case field naming** (underscores, not dots or camelCase):

### Basic Log Entry

```json
{
  "event_id": "10a1d43f-bd70-4581-8e30-c6fa60160ff0",
  "service_name": "my-app",
  "service_version": "1.0.0",
  "function_name": "processPayment",
  "level": "info",
  "log_type": "transaction",
  "message": "Payment processed successfully",
  "timestamp": "2025-10-10T19:38:39.109Z",
  "trace_id": "a17e6a44986c4581a13e19d6b0a9b295",
  "span_id": "b7e53ae49dd3b969",
  "peer_service": "SYS2034567",
  "input_json": {
    "orderId": "123",
    "amount": 99.99
  },
  "response_json": {
    "transactionId": "tx-456",
    "status": "approved"
  }
}
```

### Error Log Entry (with Exception Fields)

```json
{
  "event_id": "b73f6657-7731-453b-9d17-f61a6da52a71",
  "service_name": "my-app",
  "service_version": "1.0.0",
  "function_name": "processPayment",
  "level": "error",
  "log_type": "transaction",
  "message": "Payment failed",
  "timestamp": "2025-10-10T19:38:40.440Z",
  "trace_id": "5c50f2b84f562949abcedb71298cd39a",
  "span_id": "b7f6c8e6b794f83f",
  "peer_service": "SYS2034567",
  "exception_type": "Error",
  "exception_message": "HTTP 404: Payment gateway unavailable",
  "exception_stacktrace": "Error: HTTP 404...\n    at processPayment (/app/payment.ts:50:20)\n    ...",
  "input_json": {
    "orderId": "123",
    "amount": 99.99
  },
  "response_json": {
    "status": "failed"
  }
}
```

### Job Status Log Entry

```json
{
  "event_id": "d2f77136-f6c8-499a-b1ac-4d8e09c7501d",
  "service_name": "my-app",
  "function_name": "importUsers",
  "level": "info",
  "log_type": "job.status",
  "message": "Job Started: UserImportJob",
  "timestamp": "2025-10-10T19:38:39.110Z",
  "trace_id": "3024d80d06a74509a212baca13870433",
  "peer_service": "my-app",
  "input_json": {
    "job_name": "UserImportJob",
    "job_status": "Started",
    "totalUsers": 5000
  },
  "response_json": null
}
```

### Job Progress Log Entry

```json
{
  "event_id": "41247f72-6b93-4c26-92ed-d58cb20e3851",
  "service_name": "my-app",
  "function_name": "importUsers",
  "level": "info",
  "log_type": "job.progress",
  "message": "Processing user-123 (45/5000)",
  "timestamp": "2025-10-10T19:38:39.111Z",
  "trace_id": "5f0b0d8227f94217bb3028920d2cb07e",
  "peer_service": "my-app",
  "input_json": {
    "job_name": "UserImportJob",
    "item_id": "user-123",
    "current_item": 45,
    "total_items": 5000,
    "progress_percentage": 0.9
  },
  "response_json": null
}
```

**Key Field Naming Rules:**
- ✅ **Use underscores**: `service_name`, `function_name`, `trace_id`, `span_id`
- ✅ **Flat structure**: `exception_type`, NOT `exception.type`
- ✅ **Consistent casing**: All field names are lowercase with underscores
- ❌ **Never use dots**: Avoid `service.name` or nested structures for standard fields
- ❌ **Never use camelCase**: Avoid `serviceName` or `functionName`

**Why snake_case?**
- OpenTelemetry automatically converts dot notation to underscores when storing in backends
- Using snake_case directly avoids transformation inconsistencies
- Ensures fields are stored and retrieved with the same names
- Simplifies querying in Grafana, Loki, and Prometheus

---

## For Microsoft/Azure Developers

**"I only know Azure Monitor and Application Insights..."**

Good news! This library uses **OpenTelemetry** - Microsoft's recommended standard for observability. Your code works with **both** Azure and open-source tools:

```typescript
// Same code works everywhere
sovdev_log(INFO, FUNCTIONNAME, 'Order processed', PEER_SERVICES.INTERNAL, input, output);
```

**Where your logs go**:

| Environment | Logs | Metrics | Traces |
|------------|------|---------|---------|
| **Azure Production** | Azure Log Analytics | Azure Monitor | Application Insights |
| **Local Development** | Console + JSON files | Grafana (optional) | Tempo (optional) |
| **On-Premises** | Loki | Prometheus | Tempo |

**Key benefits for Azure developers**:
- ✅ **No vendor lock-in**: Write once, deploy anywhere (Azure, AWS, on-prem)
- ✅ **Local testing**: Full observability stack on your laptop (no cloud costs)
- ✅ **Azure-compatible**: OpenTelemetry Protocol (OTLP) works with Azure Monitor
- ✅ **Future-proof**: Microsoft recommends OpenTelemetry for new applications

**Want Azure integration?** See [Configuration for Azure](#configuration-for-azure) below.

---

## Next Steps

Choose your path:

| Goal | Next Section |
|------|-------------|
| 📖 Just logging to console/file? | You're done! Keep using `sovdev_log()` |
| ☁️ Send to Azure Monitor? | [Configuration for Azure](#configuration-for-azure) |
| 📊 Send to Grafana/Loki/Tempo? | [Configuration](#configuration) |
| 🔄 Processing batches/jobs? | [Batch Job Pattern](#batch-job-pattern) |
| 🔗 Link related operations? | [Using traceId](#using-traceid-to-link-operations) |
| 🤔 Understand how it works? | [How It Works](#how-it-works) |

---

## Common Logging Patterns

### Pattern 1: Single Transaction (API Call, Database Query)

```typescript
// Define peer services once at the top of your file
const PEER_SERVICES = create_peer_services({
  PAYMENT_GATEWAY: 'SYS2034567'   // External payment system (system ID)
  // INTERNAL is auto-generated - no need to declare it
});

async function processPayment(orderId: string, amount: number) {
  // BEST PRACTICE: Use const FUNCTIONNAME at the start of every function
  const FUNCTIONNAME = 'processPayment';

  // Capture input BEFORE the operation
  const input = { orderId, amount, currency: 'USD' };

  try {
    // Call external system
    const result = await paymentGateway.charge(orderId, amount);

    // Capture output AFTER the operation
    const output = { transactionId: result.id, status: 'approved' };

    // Log success: input + output = complete audit trail
    sovdev_log(
      SOVDEV_LOGLEVELS.INFO,
      FUNCTIONNAME,
      'Payment processed successfully',
      PEER_SERVICES.PAYMENT_GATEWAY,  // Track external dependency
      input,
      output
    );

    return result;
  } catch (error) {
    // Capture error output
    const output = { status: 'failed', reason: error.message };

    // Log failure: input + output + exception
    sovdev_log(
      SOVDEV_LOGLEVELS.ERROR,
      FUNCTIONNAME,
      'Payment failed',
      PEER_SERVICES.PAYMENT_GATEWAY,  // Still track peer service on error
      input,
      output,
      error  // Exception object for stack trace
    );
    throw error;
  }
}
```

**Key Points**:
- ✅ `const FUNCTIONNAME` - Makes finding bugs easier
- ✅ `const input` - Explicit variable names show what data went in
- ✅ Track peer service even on errors - Creates service dependency graphs
- ✅ Log both input AND output - Complete audit trail

---

### Batch Job Pattern

```typescript
async function importUsers(users: User[]) {
  const FUNCTIONNAME = 'importUsers';

  // 1. Log job START - marks beginning of batch operation
  sovdev_log_job_status(
    SOVDEV_LOGLEVELS.INFO,
    FUNCTIONNAME,
    'UserImportJob',              // Job name (for filtering in Grafana)
    'Started',                    // Job status
    PEER_SERVICES.INTERNAL,       // Use INTERNAL for batch jobs (not calling external systems)
    { totalUsers: users.length, source: 'CSV' }
  );

  // Track success/failure counts
  let successCount = 0;
  let failureCount = 0;

  // 2. Process each item and log PROGRESS
  for (let i = 0; i < users.length; i++) {
    const user = users[i];

    try {
      await createUser(user);
      successCount++;

      // ✅ BEST PRACTICE: Log progress every N items (avoid log spam)
      if ((i + 1) % 10 === 0 || i === users.length - 1) {
        sovdev_log_job_progress(
          SOVDEV_LOGLEVELS.INFO,
          FUNCTIONNAME,
          user.id,                  // itemId: Identifier for the item being processed (shows in logs)
          i + 1,                    // currentItem: How many items processed so far (1, 2, 3...)
          users.length,             // totalItems: Total number of items in batch (calculates %)
          PEER_SERVICES.INTERNAL,   // Batch processing is internal
          { successCount, failureCount }
        );
      }
    } catch (error) {
      failureCount++;

      // ✅ IMPORTANT: Always log individual failures (don't skip errors)
      sovdev_log_job_progress(
        SOVDEV_LOGLEVELS.ERROR,
        FUNCTIONNAME,
        user.id,                  // itemId: Which user failed (for troubleshooting)
        i + 1,                    // currentItem: Position in batch where failure occurred
        users.length,             // totalItems: Total batch size (shows % failed)
        PEER_SERVICES.INTERNAL,   // Still INTERNAL even on error
        { email: user.email, error: error.message }
      );
    }
  }

  // 3. Log job COMPLETION - marks end of batch with final statistics
  sovdev_log_job_status(
    SOVDEV_LOGLEVELS.INFO,
    FUNCTIONNAME,
    'UserImportJob',
    'Completed',                  // Job status
    PEER_SERVICES.INTERNAL,       // Batch job completion is internal
    { totalUsers: users.length, successCount, failureCount }
  );
}
```

**Result in Grafana**:
- Query: `{job_name="UserImportJob"}` shows job lifecycle (Started → Progress → Completed)
- See which specific users failed: filter by ERROR level
- Calculate success rate: `successCount / totalUsers`

---

### Using traceId to Link Operations

**Use Case**: Process one company through multiple steps (lookup → validate → save). You want all 3 operations grouped together in Grafana.

```typescript
import { sovdev_generate_trace_id } from '@terchris/sovdev-logger';

async function processCompany(orgNumber: string) {
  const FUNCTIONNAME = 'processCompany';

  // IMPORTANT: Generate ONE traceId at the start - use it for ALL operations
  const companyTraceId = sovdev_generate_trace_id();

  // Step 1: Lookup company in external registry (BRREG)
  const input1 = { organisasjonsnummer: orgNumber };
  const companyData = await lookupInBREG(orgNumber);
  const output1 = { name: companyData.name };

  sovdev_log(
    SOVDEV_LOGLEVELS.INFO,
    FUNCTIONNAME,
    'Company found',
    PEER_SERVICES.BRREG,        // External system call
    input1,
    output1,
    null,                       // No exception
    companyTraceId              // ← Links this operation to the company
  );

  // Step 2: Validate data (internal operation)
  const isValid = validateCompany(companyData);
  const input2 = { name: companyData.name };
  const output2 = { valid: isValid };

  sovdev_log(
    SOVDEV_LOGLEVELS.INFO,
    FUNCTIONNAME,
    'Validation complete',
    PEER_SERVICES.INTERNAL,     // Internal operation
    input2,
    output2,
    null,
    companyTraceId              // ← Same traceId links to step 1
  );

  // Step 3: Save to database
  await saveCompany(companyData);
  const input3 = { organisasjonsnummer: orgNumber };
  const output3 = { saved: true };

  sovdev_log(
    SOVDEV_LOGLEVELS.INFO,
    FUNCTIONNAME,
    'Company saved',
    PEER_SERVICES.DATABASE,     // Database call
    input3,
    output3,
    null,
    companyTraceId              // ← Same traceId links all 3 steps together
  );
}
```

**Result in Grafana**:
```
Query: {traceId="company-abc123"}

Shows ALL 3 operations (all share traceId "company-abc123"):
  ├─ lookupCompany → BRREG (200ms)
  ├─ validateCompany → INTERNAL (5ms)
  └─ saveCompany → Database (50ms)

Total duration: 255ms
Complete flow for this company visible in one view!
```

**When to use traceId:**
- ✅ Processing one item through multiple steps (read → transform → write)
- ✅ Transaction flows where you want to see the complete journey
- ✅ Debugging: "Show me everything that happened for company X"
- ❌ Single, independent operations (library auto-generates traceId)

---

## Common Mistakes

### ❌ Forgetting to Shut Down

```typescript
async function main() {
  sovdev_log(INFO, FUNCTIONNAME, 'Test', PEER_SERVICES.INTERNAL, input);
  // Missing: await sovdev_shutdown();
}
// Result: Last logs lost, and the process may hang instead of exiting!
```

**Fix**: In a short script, always call `await sovdev_shutdown()` before exit — not `sovdev_flush()`, which never terminates the SDK and won't let the process exit cleanly on its own.

```typescript
async function main() {
  sovdev_log(INFO, FUNCTIONNAME, 'Test', PEER_SERVICES.INTERNAL, input);
  await sovdev_shutdown();  // ✅
}

main().catch(async (error) => {
  console.error('Fatal error:', error);
  await sovdev_shutdown(); // ✅ Shut down even on error!
  process.exit(1);
});
```

**In a long-running server**, don't call `sovdev_shutdown()` per-request — call `sovdev_flush()` if you want telemetry out sooner (safe to call repeatedly), and `sovdev_shutdown()` exactly once, in your shutdown handler (e.g. on `SIGTERM`). See [Onboarding a new system](https://sovdev-logger.sovereignsky.no/using/onboarding) for the full server pattern.

### ❌ Not Using FUNCTIONNAME Constant

```typescript
// ❌ Wrong - hardcoded string (typo-prone)
function processPayment() {
  sovdev_log(INFO, 'proccessPayment', msg, PEER_SERVICES.PAYMENT_GATEWAY, input, output); // Typo!
}

// ✅ Correct - use constant
function processPayment() {
  const FUNCTIONNAME = 'processPayment';
  sovdev_log(INFO, FUNCTIONNAME, msg, PEER_SERVICES.PAYMENT_GATEWAY, input, output);
}
```

**Why**:
- Prevents typos
- Makes refactoring easier
- Consistent pattern across all functions
- Easier to search logs by function name

### ❌ Hardcoding Peer Service Names

```typescript
// ❌ Wrong - hardcoded string (no type safety, hard to maintain)
sovdev_log(INFO, FUNCTIONNAME, msg, 'SYS1234567', input, output);

// ✅ Correct - use PEER_SERVICES constants
const PEER_SERVICES = create_peer_services({
  BRREG: 'SYS1234567'  // INTERNAL auto-generated
});
sovdev_log(INFO, FUNCTIONNAME, msg, PEER_SERVICES.BRREG, input, output);
```

**Why**:
- Type-safe: IDE autocomplete and compile-time checks
- Single source of truth for external system names
- Easy to update when system IDs change
- Creates automatic service dependency maps in Grafana

---

## API Reference

**API Naming Convention:**
TypeScript uses **snake_case** function names (`sovdev_log`, `sovdev_initialize`, `create_peer_services`) for consistency with Python implementation and the specification. All field names are **snake_case** across all languages (`service_name`, `function_name`, `trace_id`, `peer_service`).

### sovdevInitialize

```typescript
sovdev_initialize(
  serviceName: string,
  serviceVersion?: string,
  peerServices: Record<string, string>
): void
```

Initialize the logger with service information and peer system mappings. **Must be called once at application startup.**

**Parameters:**

- **`serviceName`** (required) - Unique identifier for your service
  - Examples: `"user-service"`, `"payment-api"`, `"company-lookup"`

- **`serviceVersion`** (optional) - Version of your service
  - Auto-detected from: `SERVICE_VERSION` env var, `npm_package_version`, `package.json`
  - Falls back to `"unknown"`

- **`peerServices`** - Pass `PEER_SERVICES.mappings`
  - Tells the logger which external systems (peer services) your application calls
  - Enables service dependency maps in Grafana showing which external systems you call
  - Example: `{ BRREG: 'INT1001234', ALTINN: 'INT1005678' }` (INTERNAL auto-added)
  - Always use `PEER_SERVICES.mappings` - don't manually create this object

**Example:**

```typescript
// .env file:
// OTEL_SERVICE_NAME=my-company-lookup-service     ← Your service name (OpenTelemetry standard)
// BRREG_SYSTEM_ID=INT1001234                      ← External system ID
// ALTINN_SYSTEM_ID=INT1005678                     ← External system ID

// Define which external systems (peer services) your app calls
const PEER_SERVICES = create_peer_services({
  // INTERNAL is auto-generated - no need to declare it!
  BRREG: process.env.BRREG_SYSTEM_ID!,      // External system: INT1001234
  ALTINN: process.env.ALTINN_SYSTEM_ID!     // External system: INT1005678
});

// Initialize with YOUR service name and peer services
sovdev_initialize(
  process.env.OTEL_SERVICE_NAME!,   // 'my-company-lookup-service' (OpenTelemetry standard)
  '1.0.0',                          // Your version
  PEER_SERVICES.mappings            // INTERNAL auto-added as 'my-company-lookup-service'
);

// Now you can use PEER_SERVICES.INTERNAL in your logs!
// It will automatically resolve to 'my-company-lookup-service'
```

---

### sovdevLog

```typescript
sovdev_log(
  level: sovdev_log_level,
  functionName: string,
  message: string,
  peerService: string,
  inputJSON?: any,
  responseJSON?: any,
  exceptionObject?: any,
  traceId?: string
): void
```

General purpose logging function that captures complete operation context.

**Parameters:**

- **`level`** - Log severity from `SOVDEV_LOGLEVELS` (DEBUG, INFO, WARN, ERROR, FATAL)
- **`functionName`** - Name of the function/operation being logged
  - **Best practice**: Use `const FUNCTIONNAME = 'functionName'`
- **`message`** - Human-readable description of what happened
- **`peerService`** (required) - The external system/service you're calling
  - Use `PEER_SERVICES.INTERNAL` for internal operations
  - Use `PEER_SERVICES.PAYMENT_GATEWAY`, `PEER_SERVICES.DATABASE`, etc. for external calls
  - **Why**: Creates automatic service dependency graphs in Grafana
- **`inputJSON`** (optional) - Data that went INTO the operation
- **`responseJSON`** (optional) - Data that came OUT of the operation
- **`exceptionObject`** (optional) - Error or exception object if operation failed
- **`traceId`** (optional, advanced) - Manual trace correlation ID
  - **99% of developers should omit this** - it's auto-generated!
  - Only use to manually correlate operations (see [Using traceId](#using-traceid-to-link-operations))

**Example:**

```typescript
const FUNCTIONNAME = 'processPayment';
const input = { orderId: '123', amount: 99.99 };
const output = { transactionId: 'tx-456', status: 'approved' };

sovdev_log(
  SOVDEV_LOGLEVELS.INFO,
  FUNCTIONNAME,
  'Payment processed successfully',
  PEER_SERVICES.PAYMENT_GATEWAY,
  input,
  output
);
```

---

### sovdevLogJobStatus

```typescript
sovdev_log_job_status(
  level: sovdev_log_level,
  functionName: string,
  jobName: string,
  status: string,
  peerService: string,
  inputJSON?: any,
  traceId?: string
): void
```

Track the lifecycle of long-running jobs or batch processes (start, completion, failure).

**Parameters:**

- **`status`** - Job lifecycle state: `'Started'`, `'Completed'`, `'Failed'`, `'Cancelled'`
- **`jobName`** - Unique job identifier (e.g., `'UserSyncJob'`, `'DailyBackup'`)

**Example:**

```typescript
const FUNCTIONNAME = 'syncUserData';

// Job start
sovdev_log_job_status(
  SOVDEV_LOGLEVELS.INFO,
  FUNCTIONNAME,
  'UserSyncJob',
  'Started',
  PEER_SERVICES.INTERNAL,
  { source: 'ActiveDirectory', totalUsers: 5000 }
);

// ... process users ...

// Job completion
sovdev_log_job_status(
  SOVDEV_LOGLEVELS.INFO,
  FUNCTIONNAME,
  'UserSyncJob',
  'Completed',
  PEER_SERVICES.INTERNAL,
  { usersProcessed: 5000, duration: '45s' }
);
```

---

### sovdevLogJobProgress

```typescript
sovdev_log_job_progress(
  level: sovdev_log_level,
  functionName: string,
  itemId: string,
  current: number,
  total: number,
  peerService: string,
  inputJSON?: any,
  traceId?: string
): void
```

Show progress when processing batches, arrays, or large datasets. Creates "Processing item 45 of 100" style logs.

**Parameters:**

- **`itemId`** - Current item identifier (e.g., `userId`, `orderId`, `fileName`)
- **`current`** - Current item number (1-based counting: 1, 2, 3...)
- **`total`** - Total number of items to process

**Example:**

```typescript
for (let i = 0; i < users.length; i++) {
  const user = users[i];

  await createUser(user);

  sovdev_log_job_progress(
    SOVDEV_LOGLEVELS.INFO,
    'importUsers',
    user.id,
    i + 1,
    users.length,
    PEER_SERVICES.INTERNAL,
    { email: user.email, status: 'created' }
  );
}
```

---

### sovdevFlush

```typescript
async sovdev_flush(): Promise<void>
```

Force-export any buffered logs, metrics, and traces to the OTLP collector right now.

**Safe to call any number of times, at any point in a process's life — this does not shut anything down.** Use it in a long-running server whenever you want telemetry out sooner than the normal batch interval (e.g. defensively after logging something important). For the true end of a process, use `sovdev_shutdown()` instead — see below.

(Prior to this being split into two functions, `sovdev_flush()` used to also shut down the SDK, which meant calling it more than once silently stopped metrics from being recorded — logs kept working, metrics didn't, with no error either way. That's fixed: `sovdev_flush()` alone is now always safe to repeat.)

---

### sovdevShutdown

```typescript
async sovdev_shutdown(): Promise<void>
```

Force-flush, then permanently shut down the OTel SDK and every provider. **Call this exactly once — the last thing before your process exits.** After this call, logging/metrics/tracing stop working for the rest of the process's life.

**Why This Is Critical:**

OpenTelemetry uses a `BatchLogRecordProcessor` which batches logs for performance. When your application exits, any logs still in the batch buffer will be lost unless you flush them first — and in a short script, the background batch timers also need to be cleared (which `sovdev_shutdown()` does) for the process to exit naturally instead of hanging.

**Best Practice (short scripts / jobs):**

```typescript
async function main() {
  sovdev_initialize('my-service');

  // ... your application code ...

  // Always shut down before exit
  await sovdev_shutdown();
}

main().catch(async (error) => {
  console.error('Fatal error:', error);
  await sovdev_shutdown(); // Shut down even on error!
  process.exit(1);
});
```

**Long-running servers**: never call `sovdev_shutdown()` per-request. Call `sovdev_flush()` (freely, repeatedly) if you want telemetry out sooner, and `sovdev_shutdown()` exactly once, in your process's shutdown handler (e.g. on `SIGTERM`).

---

## Optional Diagnostic Functions

⚠️ **These functions are optional and primarily useful during development and debugging.**

### sovdev_validate_config

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

Validate that all required OpenTelemetry environment variables are set and properly formatted.

**Returns:**
- `valid` - `true` if all required variables are set, `false` otherwise
- `missing` - Array of missing required environment variable names
- `warnings` - Array of configuration warnings
- `config` - Current configuration values

**Checks for Required Variables:**
- `OTEL_SERVICE_NAME`
- `OTEL_EXPORTER_OTLP_LOGS_ENDPOINT`
- `OTEL_EXPORTER_OTLP_METRICS_ENDPOINT`
- `OTEL_EXPORTER_OTLP_TRACES_ENDPOINT`
- `OTEL_EXPORTER_OTLP_HEADERS` (comma-separated `key=value` pairs — see the note at the top of [Configuration](#configuration); required headers are backend-specific, not always a `Host` header)

**Example:**

```typescript
import { sovdev_validate_config, sovdev_initialize } from '@terchris/sovdev-logger';

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

// Proceed with initialization (file logging still works without OTLP)
sovdev_initialize('my-service', '1.0.0');
```

**When to Use:**
- ✅ During development to verify .env file is configured correctly
- ✅ In deployment scripts to validate environment before starting service
- ✅ When debugging "why aren't logs appearing in Loki/Prometheus/Tempo?"
- ❌ NOT required for normal application operation

---

### sovdev_test_otlp_connection

```typescript
async sovdev_test_otlp_connection(timeout?: number): Promise<{
  success: boolean;
  logs: { reachable: boolean; error?: string };
  metrics: { reachable: boolean; error?: string };
  traces: { reachable: boolean; error?: string };
}>
```

Test connectivity to all three OTLP endpoints by sending properly formatted test data.

**Parameters:**
- `timeout` - Optional timeout in milliseconds (default: 5000ms)

**Returns:** Promise resolving to object containing:
- `success` - `true` if ALL three endpoints are reachable
- `logs` - Connectivity result for logs endpoint
- `metrics` - Connectivity result for metrics endpoint
- `traces` - Connectivity result for traces endpoint

**Example:**

```typescript
import { sovdev_test_otlp_connection, sovdev_initialize } from '@terchris/sovdev-logger';

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

// Proceed with initialization
sovdev_initialize('my-service', '1.0.0');
```

**Common Errors:**
- **404 Not Found** - Usually indicates missing `Host: otel.localhost` header in `OTEL_EXPORTER_OTLP_HEADERS`
- **Connection refused** - OTLP collector not running or wrong endpoint URL
- **Timeout** - Network issue or endpoint unreachable

**When to Use:**
- ✅ During development to verify OTLP collector is running and accessible
- ✅ In deployment health checks to validate infrastructure connectivity
- ✅ When debugging OTLP connection issues (404, connection refused, timeouts)
- ✅ In CI/CD pipelines to validate deployment environment
- ❌ NOT required for normal application operation

**Why Three Separate Endpoints?**

OpenTelemetry OTLP collector exposes three separate endpoints by design:
- `/v1/logs` - Log records
- `/v1/metrics` - Metric data points
- `/v1/traces` - Trace spans

Each signal type has different structure and backend routing requirements. This is OpenTelemetry specification standard, not an implementation choice.

---

## Configuration

**A note on `OTEL_EXPORTER_OTLP_HEADERS` before you start:** it uses the standard OpenTelemetry format — comma-separated `key=value` pairs (e.g. `Host=otel.localhost` or `Authorization=Basic <token>`), **not JSON**. This is read natively by the underlying OpenTelemetry SDK, independent of anything sovdev-logger does. **Quote the value in your `.env` file whenever it contains a space** (any Basic/Bearer auth header does) — an unquoted value with a space gets truncated by shell word-splitting when loaded via `source` or similar, silently dropping the token and causing a `401` with no obvious cause. Every example below already shows the correct quoting.

### Scenario 1: Local Development (Console + File Only)

**No configuration needed!** Just install and use:

```bash
npm install @terchris/sovdev-logger
```

The library will:
- ✅ Log to console (colored, human-readable)
- ✅ Log to files (JSON, structured in `./logs/`)
- ❌ Not send to OTLP (Grafana/Loki) yet

**Optional**: Enable file logging explicitly:

```bash
LOG_TO_FILE=true
LOG_FILE_PATH=./logs/app.log        # Optional: custom path
ERROR_LOG_PATH=./logs/error.log     # Optional: custom error path
```

---

### Configuration for Azure

### Scenario 2: Send to Azure Monitor (Azure Production)

**Use Case:** Running your Node.js app in Azure App Service, Container Apps, or AKS - sending observability data to Azure Monitor.

#### Step 1: Install Azure Monitor OpenTelemetry

```bash
npm install @azure/monitor-opentelemetry
```

#### Step 2: Initialize with Azure Monitor

Update your app initialization:

```typescript
import { sovdev_initialize, sovdev_log, sovdev_flush, SOVDEV_LOGLEVELS, create_peer_services } from '@terchris/sovdev-logger';
import { useAzureMonitor } from '@azure/monitor-opentelemetry';

// Initialize Azure Monitor (reads APPLICATIONINSIGHTS_CONNECTION_STRING from env)
useAzureMonitor();

// Initialize sovdev-logger
const PEER_SERVICES = create_peer_services({
  DATABASE: 'INT1234567',
  PAYMENT_API: 'SYS7654321'
  // INTERNAL is auto-generated
});

sovdev_initialize('my-azure-app', '1.0.0');

// Your application code...
async function main() {
  const FUNCTIONNAME = 'main';
  sovdev_log(SOVDEV_LOGLEVELS.INFO, FUNCTIONNAME, 'Application started', PEER_SERVICES.INTERNAL);

  // App Service keeps running after this — use sovdev_flush() here (safe to
  // call repeatedly), NOT sovdev_shutdown(). Wire sovdev_shutdown() to the
  // app's actual termination instead (e.g. a SIGTERM handler).
  await sovdev_flush();
}
```

#### Step 3: Configure Azure Application Insights

Set environment variable in Azure (App Service → Configuration → Application Settings):

```bash
APPLICATIONINSIGHTS_CONNECTION_STRING=InstrumentationKey=xxxxx-xxxx-xxxx-xxxx-xxxxxxxxx;IngestionEndpoint=https://...
```

**That's it!** Your `sovdev_log()` calls now send:
- ✅ Logs → Azure Log Analytics
- ✅ Metrics → Azure Monitor Metrics
- ✅ Traces → Application Insights (transaction search, application map)

**View in Azure Portal:**
- Logs: `Application Insights → Logs → traces table`
- Metrics: `Application Insights → Metrics`
- Dependencies: `Application Insights → Application map`

---

### Scenario 3: Send to Grafana (With sovdev-infrastructure)

**Use Case:** Running your app locally on Mac, sending logs to OTLP collector in sovdev-infrastructure (Rancher Desktop cluster).

Create `.env` file:

```bash
# Use IP address 127.0.0.1 (Node.js cannot resolve .localhost domains)
OTEL_EXPORTER_OTLP_LOGS_ENDPOINT=http://127.0.0.1/v1/logs
OTEL_EXPORTER_OTLP_METRICS_ENDPOINT=http://127.0.0.1/v1/metrics
OTEL_EXPORTER_OTLP_TRACES_ENDPOINT=http://127.0.0.1/v1/traces

# Optional file logging
LOG_TO_FILE=true
LOG_FILE_PATH=./logs/app.log

NODE_ENV=development
```

Update your run script to include the Host header:

```bash
#!/bin/bash
# REQUIRED: Host header for Traefik routing
OTEL_EXPORTER_OTLP_HEADERS="Host=otel.localhost" npx tsx your-app.ts
```

**Why These Values:**
- ✅ `127.0.0.1` - Your Mac's localhost resolves to sovdev-infrastructure (Rancher Desktop)
- ✅ Port 80 - Traefik ingress listens on port 80
- ✅ `Host: otel.localhost` - Traefik routes based on this header
- ❌ `otel.localhost` URL - Node.js DNS can't resolve `.localhost` domains

**Open Grafana:**

```bash
open http://grafana.localhost
```

---

### Need More Configuration?

See [Advanced Configuration](#advanced-configuration) for:
- Kubernetes deployment (inside sovdev-infrastructure)
- Azure / Cloud deployment
- Troubleshooting OTLP connection

---

## How It Works

### Zero-Effort Observability Concept

Traditional observability requires developers to implement three separate instrumentation strategies:
- **Logs**: Write logging code (e.g., console.log, winston)
- **Metrics**: Add counters, gauges, histograms (e.g., Prometheus client)
- **Traces**: Instrument distributed tracing (e.g., OpenTelemetry spans)

**sovdev-logger eliminates this complexity**. When you write a single log entry, the library automatically generates:

**1. Structured Logs** (for searching and debugging)
- Exported via OpenTelemetry protocol (OTLP)
- Searchable by service name, function, error level
- Contains full context: what happened, what went in, what came out

**2. Prometheus Metrics** (for dashboards and alerting)
- Automatic counters: How many operations? How many errors?
- Automatic histograms: How long did operations take?
- Enables sub-second dashboard queries

**3. Distributed Traces** (for understanding flow)
- Automatic span creation showing operation timeline
- Links related operations across services
- Generates service dependency graphs automatically

**4. Session Grouping** (for execution tracking)
- Unique `session.id` generated when your application starts
- Every log/metric/trace from that run gets the same session ID
- Find everything from "the 3 AM batch run" or "my test execution"

### Automatic Prometheus Metrics

| Metric | Type | Description |
|--------|------|-------------|
| `sovdev_operations_total` | Counter | Total operations count |
| `sovdev_errors_total` | Counter | Total errors (ERROR/FATAL) |
| `sovdev_operation_duration_milliseconds` | Histogram | Operation duration |
| `sovdev_operations_active` | Gauge | Currently active operations |

**Example queries:**

```promql
# Operations rate by service
rate(sovdev_operations_total[1m])

# Error rate
rate(sovdev_errors_total[1m]) / rate(sovdev_operations_total[1m])

# Average operation duration
rate(sovdev_operation_duration_milliseconds_sum[1m]) / rate(sovdev_operation_duration_milliseconds_count[1m])
```

---

## Examples

### Basic Usage

See [Quick Start](#quick-start-60-seconds) above for a minimal single-file example.

### Advanced Usage

[`test/e2e/company-lookup/company-lookup.ts`](https://github.com/helpers-no/sovdev-logger/blob/main/typescript/test/e2e/company-lookup/company-lookup.ts) is a full working example covering batch processing, job status/progress logging, peer services, error handling, and traceId correlation — the same patterns shown above, in one real program. Run it yourself:

```bash
cd test/e2e/company-lookup
cp .env.example .env    # points at a local OTLP backend by default -- if you don't have
bash run-test.sh        # one running, OTLP export fails gracefully; console + file logging still works
```

---

## Advanced Configuration (All Scenarios)

### Scenario 1: Development on Mac (External to sovdev-infrastructure)

**Already covered in [Configuration](#configuration) above.**

---

### Scenario 2: Application Running Inside sovdev-infrastructure

**Use Case:** Your app is deployed as a pod in sovdev-infrastructure (Kubernetes cluster), sending logs to OTLP collector in the same cluster.

```bash
# Use Kubernetes internal service DNS (monitoring namespace)
OTEL_EXPORTER_OTLP_LOGS_ENDPOINT=http://otel-collector-opentelemetry-collector.monitoring.svc.cluster.local:4318/v1/logs
OTEL_EXPORTER_OTLP_METRICS_ENDPOINT=http://otel-collector-opentelemetry-collector.monitoring.svc.cluster.local:4318/v1/metrics
OTEL_EXPORTER_OTLP_TRACES_ENDPOINT=http://otel-collector-opentelemetry-collector.monitoring.svc.cluster.local:4318/v1/traces

# NO Host header needed - direct connection, no Traefik
# File logging (optional - logs go to pod filesystem)
LOG_TO_FILE=false

NODE_ENV=production
```

**Why These Values:**
- ✅ Kubernetes DNS works inside sovdev-infrastructure
- ✅ Port 4318 - Direct OTLP HTTP port (bypasses Traefik)
- ✅ No Host header needed - Direct service-to-service communication

---

### Scenario 3: Azure / Cloud Deployment

**Use Case:** App running in Azure, sending logs to Azure Application Insights or cloud-based OTLP collector.

**Azure Application Insights:**

```bash
OTEL_EXPORTER_OTLP_LOGS_ENDPOINT=https://your-app-insights.azure.com/v1/logs
OTEL_EXPORTER_OTLP_METRICS_ENDPOINT=https://your-app-insights.azure.com/v1/metrics
OTEL_EXPORTER_OTLP_TRACES_ENDPOINT=https://your-app-insights.azure.com/v1/traces

# Authentication (use Azure managed identity or connection string)
# Quoted because the value contains a space -- see the note at the top of Configuration.
OTEL_EXPORTER_OTLP_HEADERS="Authorization=Bearer YOUR_TOKEN"

LOG_TO_FILE=false
NODE_ENV=production
```

**Grafana Cloud:**

```bash
OTEL_EXPORTER_OTLP_LOGS_ENDPOINT=https://otlp-gateway-prod-eu-west-0.grafana.net/otlp/v1/logs
OTEL_EXPORTER_OTLP_METRICS_ENDPOINT=https://otlp-gateway-prod-eu-west-0.grafana.net/otlp/v1/metrics
OTEL_EXPORTER_OTLP_TRACES_ENDPOINT=https://otlp-gateway-prod-eu-west-0.grafana.net/otlp/v1/traces

OTEL_EXPORTER_OTLP_HEADERS="Authorization=Basic BASE64_ENCODED_CREDENTIALS"
NODE_ENV=production
```

---

## Troubleshooting

### Problem: Logs not reaching OTLP Collector

**Step 1: Verify Configuration**

```bash
# Check environment variables
echo $OTEL_EXPORTER_OTLP_LOGS_ENDPOINT
echo $OTEL_EXPORTER_OTLP_HEADERS
```

**Step 2: Test OTLP Endpoint**

```bash
# Scenario 1 (Mac + Traefik)
curl -v -X POST http://127.0.0.1/v1/logs \
  -H "Host: otel.localhost" \
  -H "Content-Type: application/json" \
  -d '{}'
# Should return HTTP 200 or 400 (not 404)

# Scenario 2 (Kubernetes)
curl -v http://otel-collector-opentelemetry-collector.monitoring.svc.cluster.local:4318/v1/logs
```

**Step 3: Check Console Output**

Look for OpenTelemetry initialization messages:

```
✅ Global LoggerProvider set
✅ OpenTelemetry SDK started successfully
📡 OTLP Log exporter configured for: http://...
```

If you see errors during init, the OTLP endpoint is likely unreachable.

---

## Compliance

This library implements "Loggeloven av 2025" requirements:

- ✅ **Structured JSON format**: All logs use structured JSON with consistent schema
- ✅ **Required fields**: Every log includes `service_name`, `function_name`, `timestamp`, `trace_id`, `event_id`
- ✅ **snake_case field naming**: All field names use underscores (`service_name`, `function_name`, `exception_type`, `span_id`)
- ✅ **OpenTelemetry-compliant exception fields**: Flat structure with `exception_type`, `exception_message`, `exception_stacktrace` (not nested, not dot notation)
- ✅ **ERROR/FATAL levels trigger ServiceNow incidents**: Automatic alerting on critical errors
- ✅ **Security**: Credentials automatically removed from logs (Authorization headers, auth objects)
- ✅ **Distributed tracing**: OpenTelemetry trace and span correlation for operation tracking

**Field Naming Standard:**
All log fields use snake_case (lowercase with underscores) to ensure consistent storage and retrieval across OpenTelemetry backends (Loki, Tempo, Prometheus). This avoids transformation inconsistencies when OTLP automatically converts dot notation to underscores.

---

## Contributing to sovdev-logger

> **Note**: This section is for **library contributors** who want to modify sovdev-logger itself.
> If you're a **library user** (using sovdev-logger in your app), you don't need this section.

### Setup for Contributors

```bash
# Clone the repository
git clone https://github.com/helpers-no/sovdev-logger.git
cd sovdev-logger/typescript

# Install dependencies
npm install

# Build the library
npm run build

# Watch mode (rebuilds on file changes)
npm run dev
```

### Testing (for Contributors)

The library has three levels of automated tests:

```bash
# Run unit tests (fast, no dependencies)
npm run test:unit

# Run integration tests (tests console/file logging)
npm run test:integration

# Run E2E tests (verifies full OTLP pipeline with Loki/Prometheus/Tempo)
npm run test:e2e

# Run all tests (recommended before commits)
npm run test:all
```

**Test Coverage:**
- **Unit tests** (18 tests): Log levels, peer services, trace ID generation
- **Integration tests** (19 tests): Console logging, file logging, flush behavior, initialization
- **E2E tests**: Full OTLP pipeline verification with Grafana stack

For detailed E2E testing and verification instructions, see [test/e2e/README.md](test/e2e/README.md).

### Contributing Workflow

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/my-improvement`
3. Make your changes
4. Run tests: `npm run test:all`
5. Build: `npm run build`
6. Commit: `git commit -m "Add feature: ..."`
7. Push and create a pull request

---

## License

MIT

---

## Repository

[https://github.com/helpers-no/sovdev-logger](https://github.com/helpers-no/sovdev-logger)
