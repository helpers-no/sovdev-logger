/**
 * ============================================================================
 * Company-Lookup E2E Test Application
 * ============================================================================
 *
 * PURPOSE:
 * This is the **reference E2E test** for sovdev-logger across all programming
 * languages. It demonstrates ALL 8 core API functions and serves as the
 * example that other language implementations learn from.
 *
 * TEST SCENARIO:
 * Simulates a real-world batch processing service that:
 * 1. Looks up Norwegian companies from the Brønnøysund Registry (BRREG)
 * 2. Processes multiple companies in a batch
 * 3. Tracks job progress and handles errors
 * 4. Demonstrates transaction correlation via explicit trace IDs
 *
 * WHAT THIS DEMONSTRATES:
 * - All 8 sovdev-logger API functions (initialization, logging, trace generation, job tracking, flush)
 * - Triple output architecture (console + file + OTLP)
 * - Peer service tracking (internal operations vs external API calls)
 * - Transaction correlation using explicit trace IDs (no OTEL imports required!)
 * - Error handling and logging
 * - Session ID for grouping all logs from one execution
 * - Job status and progress tracking for batch operations
 *
 * CROSS-LANGUAGE REQUIREMENTS:
 * Every language implementation MUST:
 * - Use the same company organization numbers (for consistency)
 * - Generate the same log entry types in the same order
 * - Pass the same validation criteria (JSON schema, field names, etc.)
 * - Use identical peer service names and system IDs
 * - Produce functionally equivalent log output
 *
 * VALIDATION:
 * This test is validated by:
 * - tools/validation/uis/validate-log-format.sh (JSON schema validation)
 * - tools/validation/uis/compare-with-master.sh (cross-language conformance)
 * - Loki queries via tools/validation/uis/query-loki.sh
 * ============================================================================
 */

// ============================================================================
// IMPORTS - sovdev-logger API Functions
// ============================================================================
// These are the 9 core functions we're demonstrating in this E2E test:
// 1. sovdev_initialize()         - Initialize the logger
// 2. sovdev_log()                - General purpose logging
// 3. sovdev_log_job_status()     - Job lifecycle tracking (started/completed)
// 4. sovdev_log_job_progress()   - Progress tracking for batch operations
// 5. sovdev_flush()              - Flush OTLP batches before exit
// 6. sovdev_start_span()         - Start an OpenTelemetry span for transaction correlation
// 7. sovdev_end_span()           - End an OpenTelemetry span
// 8. SOVDEV_LOGLEVELS            - Log level constants
// 9. create_peer_services()      - Define external system mappings

import {
  sovdev_validate_config,    // NEW: Validate OTLP configuration
  sovdev_test_otlp_connection, // NEW: Test OTLP connectivity
  sovdev_initialize,         // Function 1: Initialize logger with service info
  sovdev_log,                // Function 2: General logging (transactions, errors, etc.)
  sovdev_log_job_status,     // Function 3: Job lifecycle (started/completed)
  sovdev_log_job_progress,   // Function 4: Progress tracking (items in batch)
  sovdev_flush,              // Function 5: Flush OTLP batches before exit
  sovdev_start_span,         // Function 6: Start OpenTelemetry span for correlation
  sovdev_end_span,           // Function 7: End OpenTelemetry span
  SOVDEV_LOGLEVELS,          // Function 8: Log level constants (INFO, ERROR, etc.)
  create_peer_services       // Function 9: Create peer service mappings
} from '../../../dist/index.js';

// ============================================================================
// IMPORTANT: Dynamic Import for Auto-Instrumentation
// ============================================================================
// NOTE: We do NOT import 'https' at the top of the file!
//
// WHY: OpenTelemetry auto-instrumentation must be initialized BEFORE the
// instrumented modules (http/https) are imported. Since sovdev_initialize()
// sets up auto-instrumentation but is called inside main(), we need to
// delay importing https until after initialization.
//
// SOLUTION: Use dynamic import inside fetchCompanyData()
//
// For production applications, you would typically:
// 1. Create a separate instrumentation.js file that runs before app code
// 2. Use Node's --require flag: node --require ./instrumentation.js app.js
// 3. Or use import() to load your app after instrumentation is set up

// ============================================================================
// PEER SERVICES - External System Mapping (CMDB Integration)
// ============================================================================
// WHY: Track which external systems we interact with for observability
//
// create_peer_services() generates:
// 1. Constants for type-safe peer service references (PEER_SERVICES.BRREG)
// 2. Mappings for validation (ensures valid system IDs in logs)
// 3. Auto-generates INTERNAL constant for internal operations
//
// CROSS-LANGUAGE: All languages MUST use the same system ID (SYS1234567)
// for BRREG to ensure log output consistency.

const PEER_SERVICES = create_peer_services({
  BRREG: 'SYS1234567'  // Norwegian company registry (Brønnøysundregistrene)
  // INTERNAL is auto-generated, set to this service's own service_name
});

// ============================================================================
// TYPE DEFINITIONS - Company Data from BRREG API
// ============================================================================
// Defines the expected structure from the Norwegian company registry API

interface CompanyData {
  organisasjonsnummer: string;  // Organization number (9 digits)
  navn: string;                 // Company name
  organisasjonsform?: {         // Organization type (AS, ASA, etc.)
    kode: string;
    beskrivelse: string;
  };
}

// ============================================================================
// HELPER FUNCTION - Fetch Company Data from External API
// ============================================================================
// WHY: This is a helper function, NOT a sovdev-logger demonstration
//
// PURPOSE: Make real HTTP call to Norwegian company registry
// NOTE: This function does NOT use sovdev-logger - logging happens in the
//       calling function (lookupCompany) which wraps this call.
//
// IMPORTANT: Uses dynamic import for https module to enable auto-instrumentation
// The https module is imported INSIDE this function (after sovdev_initialize()
// has been called) so OpenTelemetry can automatically instrument HTTP calls.
//
// CROSS-LANGUAGE: Other languages should implement equivalent HTTP client
// functionality but the logging patterns must remain identical.

async function fetchCompanyData(orgNumber: string): Promise<CompanyData> {
  // Dynamic import - loads https AFTER auto-instrumentation is set up
  const https = await import('https');

  return new Promise((resolve, reject) => {
    const url = `https://data.brreg.no/enhetsregisteret/api/enheter/${orgNumber}`;

    https.default
      .get(url, (res) => {
        let data = '';
        res.on('data', (chunk) => (data += chunk));
        res.on('end', () => {
          if (res.statusCode === 200) {
            resolve(JSON.parse(data));
          } else {
            reject(new Error(`HTTP ${res.statusCode}: ${data}`));
          }
        });
      })
      .on('error', reject);
  });
}

// ============================================================================
// FUNCTION: lookupCompany - Single Company Lookup with Transaction Correlation
// ============================================================================
// DEMONSTRATES: sovdev_log() with automatic span-based trace correlation
//
// WHY THIS FUNCTION EXISTS:
// - Shows how to use sovdev_log() for request/response logging
// - Demonstrates transaction correlation via OpenTelemetry spans
// - Shows error handling with sovdev_log()
// - Demonstrates peer service tracking (BRREG)
//
// TRANSACTION CORRELATION:
// We start a span ONCE using sovdev_start_span(), which automatically creates
// a trace_id and span_id. All sovdev_log() calls within this span automatically
// inherit the trace context - no manual trace_id passing needed!
//
// LOG ENTRIES GENERATED:
// - 1x INFO log: "Looking up company..." (transaction start, input only)
// - 1x INFO log: "Company found..." (transaction success, input + response)
// OR
// - 1x ERROR log: "Failed to lookup..." (transaction failure, input + exception)
//
// CROSS-LANGUAGE: All languages must generate the same log entry pattern

async function lookupCompany(orgNumber: string): Promise<void> {
  // PATTERN: Define FUNCTIONNAME constant to avoid typos in log calls
  const FUNCTIONNAME = 'lookupCompany';

  // PATTERN: Define input object once, reuse in all log calls
  const input = { organisasjonsnummer: orgNumber };

  // ============================================================================
  // TRANSACTION CORRELATION - Start Span
  // ============================================================================
  // WHY: Start a span ONCE for correlating all logs in this operation
  //
  // CRITICAL PATTERN: Start span using sovdev_start_span() at the beginning,
  // then all sovdev_log() calls automatically inherit the trace context.
  // Remember to call sovdev_end_span() when done!
  //
  // CROSS-LANGUAGE: OpenTelemetry spans provide automatic context propagation
  //                This makes distributed tracing work seamlessly!

  const span = sovdev_start_span(FUNCTIONNAME, input);

  try {
    // ========================================================================
    // LOG #1: Transaction Start - Before External API Call
    // ========================================================================
    // DEMONSTRATES: sovdev_log() with input_json only (no response yet)
    //
    // WHY: Log the start of external system interaction with input parameters
    // PEER SERVICE: BRREG (external system)
    // PARAMETERS:
    //   - level: INFO (normal operation)
    //   - function_name: 'lookupCompany' (from FUNCTIONNAME constant)
    //   - message: Human-readable description
    //   - peer_service: PEER_SERVICES.BRREG (tracking external system call)
    //   - input_json: { organisasjonsnummer: orgNumber }
    //   - response_json: undefined (not available yet)
    //   - exception: undefined (no error)
    // NOTE: trace_id and span_id are automatically extracted from active span!

    sovdev_log(
      SOVDEV_LOGLEVELS.INFO,
      FUNCTIONNAME,
      `Looking up company ${orgNumber}`,
      PEER_SERVICES.BRREG,
      input,
      null,      // No response yet
      null       // No exception
    );

    // Call external API (not logged - helper function)
    const companyData = await fetchCompanyData(orgNumber);

    // Prepare response object for logging
    const response = {
      navn: companyData.navn,
      organisasjonsform: companyData.organisasjonsform?.beskrivelse
    };

    // ========================================================================
    // LOG #2: Transaction Success - After External API Call
    // ========================================================================
    // DEMONSTRATES: sovdev_log() with both input_json AND response_json
    //
    // WHY: Log successful completion with both request and response data
    // PEER SERVICE: BRREG (same as start log for correlation)
    // PARAMETERS:
    //   - level: INFO (successful operation)
    //   - function_name: 'lookupCompany' (same as start log)
    //   - message: Human-readable success message with company name
    //   - peer_service: PEER_SERVICES.BRREG (same external system)
    //   - input_json: Same input as start log (for correlation)
    //   - response_json: { navn, organisasjonsform } (API response data)
    //   - exception: undefined (no error)
    // NOTE: trace_id and span_id automatically match the start log via active span!

    sovdev_log(
      SOVDEV_LOGLEVELS.INFO,
      FUNCTIONNAME,
      `Company found: ${companyData.navn}`,
      PEER_SERVICES.BRREG,
      input,
      response,
      null       // No exception
    );

    // ========================================================================
    // END SPAN - Mark Transaction as Successful
    // ========================================================================
    // WHY: Signal that the span completed successfully
    // This allows distributed tracing to track the full transaction lifecycle
    sovdev_end_span(span);

  } catch (error) {
    // ========================================================================
    // ERROR HANDLING - Log Exception
    // ========================================================================
    // WHY: Log failed operation with error details for debugging

    // ========================================================================
    // LOG #3: Transaction Error - API Call Failed
    // ========================================================================
    // DEMONSTRATES: sovdev_log() with ERROR level and exception parameter
    //
    // WHY: Log failed operation with error details for debugging
    // PEER SERVICE: BRREG (same as start log, shows which system failed)
    // PARAMETERS:
    //   - level: ERROR (operation failed)
    //   - function_name: 'lookupCompany' (same as start log)
    //   - message: Human-readable error message
    //   - peer_service: PEER_SERVICES.BRREG (which system failed)
    //   - input_json: Same input as start log (what we tried to lookup)
    //   - response_json: null (no response on error)
    //   - exception: error object (captured exception details)
    // NOTE: trace_id and span_id automatically match via active span!
    //
    // NOTE: Exception is processed by sovdev-logger:
    //   - exception_type: Always "Error" (cross-language standard)
    //   - exception_message: error.message
    //   - exception_stack: Cleaned stack trace (max 350 chars, credentials removed)

    sovdev_log(
      SOVDEV_LOGLEVELS.ERROR,
      FUNCTIONNAME,
      `Failed to lookup company ${orgNumber}`,
      PEER_SERVICES.BRREG,
      input,
      null,
      error
    );

    // ========================================================================
    // END SPAN - Mark Transaction as Failed
    // ========================================================================
    // WHY: Signal that the span failed with an error
    // This marks the span status as ERROR and records the exception details
    sovdev_end_span(span, error);

    // Re-throw to propagate error to caller
    throw error;
  }
}

// ============================================================================
// FUNCTION: batchLookup - Batch Processing with Job Tracking
// ============================================================================
// DEMONSTRATES: sovdev_log_job_status() and sovdev_log_job_progress()
//
// WHY THIS FUNCTION EXISTS:
// - Shows how to track job lifecycle (started -> completed)
// - Demonstrates progress tracking for batch operations
// - Shows how to log batch errors without stopping processing
// - Demonstrates internal vs external peer services
//
// LOG ENTRIES GENERATED (for 4 companies):
// - 1x job.status log: "Started" (log_type: job.status)
// - 4x job.progress logs: One per company (log_type: job.progress)
// - 2x transaction logs per company (from lookupCompany): start + success/error
// - 1x error log: For the invalid company number (974652846)
// - 1x job.status log: "Completed" with summary statistics
//
// TOTAL: ~15-17 log entries for this batch operation
//
// CROSS-LANGUAGE: All languages must generate the same log entry pattern
// with identical job names, status values, and progress tracking

async function batchLookup(orgNumbers: string[]): Promise<void> {
  const jobName = 'CompanyLookupBatch';
  const FUNCTIONNAME = 'batchLookup';
  const jobStartInput = { totalCompanies: orgNumbers.length };

  // ============================================================================
  // LOG #1: Job Started - Batch Operation Begins
  // ============================================================================
  // DEMONSTRATES: sovdev_log_job_status() with "Started" status
  //
  // WHY: Mark the start of a batch job for tracking in dashboards
  // LOG TYPE: job.status (automatically set by sovdev_log_job_status)
  // PEER SERVICE: INTERNAL (this is our internal batch job, not external API)
  // PARAMETERS:
  //   - level: INFO (normal operation)
  //   - function_name: 'batchLookup'
  //   - job_name: 'CompanyLookupBatch' (identifies this specific job)
  //   - status: 'Started' (job lifecycle state)
  //   - peer_service: PEER_SERVICES.INTERNAL (internal operation)
  //   - input_json: { totalCompanies: 4 } (job context)
  //
  // GRAFANA USE: Query by log_type="job.status" to see all job lifecycles

  sovdev_log_job_status(
    SOVDEV_LOGLEVELS.INFO,
    FUNCTIONNAME,
    jobName,
    'Started',
    PEER_SERVICES.INTERNAL,
    jobStartInput
  );

  // Track batch results
  let successful = 0;
  let failed = 0;

  // ============================================================================
  // BATCH PROCESSING LOOP - Process Each Company
  // ============================================================================
  // WHY: Iterate through all companies, logging progress and handling errors

  for (let i = 0; i < orgNumbers.length; i++) {
    const orgNumber = orgNumbers[i];
    const progressInput = { organisasjonsnummer: orgNumber };

    // ==========================================================================
    // LOG #2-5: Progress Tracking - One Log Per Item in Batch
    // ==========================================================================
    // DEMONSTRATES: sovdev_log_job_progress() for tracking batch progress
    //
    // WHY: Track which item we're processing in the batch (for dashboards)
    // LOG TYPE: job.progress (automatically set by sovdev_log_job_progress)
    // PEER SERVICE: BRREG (we're tracking progress of BRREG lookups)
    // PARAMETERS:
    //   - level: INFO (normal progress)
    //   - function_name: 'batchLookup'
    //   - item_name: Organization number being processed
    //   - item_number: Current position (1-based: 1, 2, 3, 4)
    //   - total_items: Total batch size (4)
    //   - peer_service: PEER_SERVICES.BRREG (tracking external API progress)
    //   - input_json: { organisasjonsnummer: orgNumber } (what we're processing)
    //
    // GRAFANA USE: Query by log_type="job.progress" to see batch progress

    sovdev_log_job_progress(
      SOVDEV_LOGLEVELS.INFO,
      FUNCTIONNAME,
      orgNumber,          // Item name (what we're processing)
      i + 1,              // Item number (current position, 1-based)
      orgNumbers.length,  // Total items (batch size)
      PEER_SERVICES.BRREG,
      progressInput
    );

    try {
      // Call lookupCompany (generates 2 transaction logs per company)
      await lookupCompany(orgNumber);
      successful++;

    } catch (error) {
      // =======================================================================
      // ERROR HANDLING - Log Batch Item Failure Without Stopping
      // =======================================================================
      // WHY: One failed item shouldn't stop the entire batch
      //
      // DEMONSTRATES: sovdev_log() for batch-level error tracking
      // NOTE: The individual lookup error was already logged in lookupCompany()
      //       This log provides batch-level context (which item number failed)

      failed++;
      const errorInput = { organisasjonsnummer: orgNumber, itemNumber: i + 1 };

      sovdev_log(
        SOVDEV_LOGLEVELS.ERROR,
        FUNCTIONNAME,
        `Batch item ${i + 1} failed`,
        PEER_SERVICES.BRREG,
        errorInput,
        null,
        error
      );
    }

    // Small delay to avoid hitting BRREG API rate limits
    // (Not related to logging - just good API citizenship)
    await new Promise((resolve) => setTimeout(resolve, 100));
  }

  // ============================================================================
  // LOG #6: Job Completed - Batch Operation Ends with Summary
  // ============================================================================
  // DEMONSTRATES: sovdev_log_job_status() with "Completed" status
  //
  // WHY: Mark job completion and provide summary statistics for dashboards
  // LOG TYPE: job.status (automatically set by sovdev_log_job_status)
  // PEER SERVICE: INTERNAL (this is our internal batch job)
  // PARAMETERS:
  //   - level: INFO (successful completion - even with some failures)
  //   - function_name: 'batchLookup'
  //   - job_name: 'CompanyLookupBatch' (same as start log for correlation)
  //   - status: 'Completed' (job lifecycle state)
  //   - peer_service: PEER_SERVICES.INTERNAL (internal operation)
  //   - input_json: Summary statistics (total, successful, failed, success rate)
  //
  // GRAFANA USE: Query by job_name + status to see job completion statistics

  const jobCompleteInput = {
    totalCompanies: orgNumbers.length,
    successful: successful,
    failed: failed,
    successRate: `${Math.round((successful / orgNumbers.length) * 100)}%`
  };

  sovdev_log_job_status(
    SOVDEV_LOGLEVELS.INFO,
    FUNCTIONNAME,
    jobName,
    'Completed',
    PEER_SERVICES.INTERNAL,
    jobCompleteInput
  );
}

// ============================================================================
// FUNCTION: main - Application Entry Point
// ============================================================================
// DEMONSTRATES: sovdev_initialize(), sovdev_log(), and sovdev_flush()
//
// WHY THIS FUNCTION EXISTS:
// - Shows how to initialize sovdev-logger at application startup
// - Demonstrates application lifecycle logging (start/finish)
// - Shows critical sovdev_flush() call before exit
// - Defines the test data that all language implementations must use
//
// LOG ENTRIES GENERATED:
// - 1x INFO log: "Company Lookup Service started" (application start)
// - ~15-17 logs from batchLookup (job status, progress, transactions, errors)
// - 1x INFO log: "Company Lookup Service finished" (application finish)
//
// CROSS-LANGUAGE: All languages must use the same test data (company numbers)

async function main() {
  const FUNCTIONNAME = 'main';

  console.log('='.repeat(80));
  console.log('Company-Lookup E2E Test');
  console.log('='.repeat(80));
  console.log('');

  // ============================================================================
  // PRE-FLIGHT CHECKS: Validate Configuration and Connectivity
  // ============================================================================
  // DEMONSTRATES: sovdev_validate_config() and sovdev_test_otlp_connection()
  //
  // WHY: Catch configuration issues BEFORE running the test
  //   - Missing .env file → warns early instead of failing silently
  //   - Wrong OTLP endpoints → identifies connectivity issues immediately
  //   - Saves hours of debugging "why isn't data appearing in Grafana?"
  //
  // CROSS-LANGUAGE: All language implementations SHOULD add these checks

  console.log('🔍 Step 1: Validating environment configuration...');
  const configValidation = sovdev_validate_config();

  if (!configValidation.valid) {
    console.warn('⚠️  OTLP configuration incomplete:');
    configValidation.missing.forEach(v => console.warn(`    - ${v}`));
    console.warn('    File logging will work, but OTLP export may be disabled.');
    console.warn('');
  } else {
    console.log('✅ Configuration valid');
    console.log(`    Service: ${configValidation.config.serviceName}`);
    console.log(`    Logs endpoint: ${configValidation.config.logsEndpoint}`);
  }

  if (configValidation.warnings.length > 0) {
    console.warn('⚠️  Configuration warnings:');
    configValidation.warnings.forEach(w => console.warn(`    - ${w}`));
    console.warn('');
  }

  console.log('');
  console.log('🔌 Step 2: Testing OTLP connectivity (optional)...');
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
    console.warn('');
  } else {
    console.log('✅ All OTLP endpoints reachable');
    console.log('    ✓ Logs endpoint');
    console.log('    ✓ Metrics endpoint');
    console.log('    ✓ Traces endpoint');
  }

  console.log('');
  console.log('='.repeat(80));
  console.log('');

  // ============================================================================
  // INITIALIZATION - Configure sovdev-logger (ONE TIME at startup)
  // ============================================================================
  // DEMONSTRATES: sovdev_initialize() - MUST be called before any logging
  //
  // WHY: Configures the logger with service identity and peer service mappings
  // PARAMETERS:
  //   - service_name: From OTEL_SERVICE_NAME env var (OpenTelemetry standard)
  //                   Falls back to "company-lookup-service" if not set
  //   - service_version: Version string (appears in all logs)
  //   - system_ids_mapping: Peer service mappings from create_peer_services()
  //
  // WHAT THIS DOES:
  //   1. Generates a session_id (UUID) for this execution (groups all logs)
  //   2. Configures three outputs: Console + File + OTLP
  //   3. Sets up peer service validation
  //   4. Initializes OpenTelemetry providers (logs, metrics, traces)
  //
  // CROSS-LANGUAGE: All languages MUST call initialization before logging
  // TEST DATA: Use OTEL_SERVICE_NAME="sovdev-test-company-lookup-typescript"

  const systemId = process.env.OTEL_SERVICE_NAME || "company-lookup-service";

  sovdev_initialize(
    systemId,                    // Service name (from env or default)
    "1.0.0",                     // Service version
    PEER_SERVICES.mappings       // Peer service validation mappings
  );

  // ============================================================================
  // LOG #1: Application Start - Service Lifecycle
  // ============================================================================
  // DEMONSTRATES: sovdev_log() for application lifecycle events
  //
  // WHY: Mark application start for observability dashboards
  // PEER SERVICE: INTERNAL (this is our internal application event)

  sovdev_log(
    SOVDEV_LOGLEVELS.INFO,
    FUNCTIONNAME,
    'Company Lookup Service started',
    PEER_SERVICES.INTERNAL
  );

  // ============================================================================
  // TEST DATA - Company Organization Numbers
  // ============================================================================
  // CRITICAL: All language implementations MUST use these exact numbers
  //
  // WHY: Ensures consistent test output across all languages for validation
  //
  // EXPECTED BEHAVIOR:
  // - 971277882 (Norges Røde Kors): SUCCESS - Valid company
  // - 915933149 (Røde Kors Hjelpekorps): SUCCESS - Valid company
  // - 974652846 (Invalid): FAILURE - Will generate error log (intentional)
  // - 916201478 (Norsk Folkehjelp): SUCCESS - Valid company
  //
  // CROSS-LANGUAGE: These numbers are chosen because:
  //   1. Real organizations (Norwegian Red Cross family)
  //   2. One invalid number to test error handling
  //   3. Public data (no privacy concerns)
  //   4. Stable (won't change over time)

  const companies = [
    '971277882', // Norges Røde Kors (Norwegian Red Cross)
    '915933149', // Røde Kors Hjelpekorps (Red Cross Rescue Corps)
    '974652846', // INVALID - Will cause error (demonstrates error handling)
    '916201478'  // Norsk Folkehjelp (Norwegian People's Aid)
  ];

  // ============================================================================
  // BATCH PROCESSING - Process All Companies
  // ============================================================================
  // Calls batchLookup which demonstrates:
  // - sovdev_log_job_status() (start + completed)
  // - sovdev_log_job_progress() (4 progress logs)
  // - Multiple sovdev_log() calls from lookupCompany()
  // - Error handling for invalid company number

  await batchLookup(companies);

  // ============================================================================
  // LOG #2: Application Finish - Service Lifecycle
  // ============================================================================
  // DEMONSTRATES: sovdev_log() for application lifecycle events
  //
  // WHY: Mark application completion for observability dashboards
  // PEER SERVICE: INTERNAL (this is our internal application event)

  sovdev_log(
    SOVDEV_LOGLEVELS.INFO,
    FUNCTIONNAME,
    'Company Lookup Service finished',
    PEER_SERVICES.INTERNAL
  );

  // ============================================================================
  // FLUSH - CRITICAL for Short-Lived Applications
  // ============================================================================
  // DEMONSTRATES: sovdev_flush() - MUST be called before application exit
  //
  // WHY: OpenTelemetry uses batch processing for performance efficiency
  //
  // THE PROBLEM:
  // - Logs are batched in memory (default: 512 logs OR 5 seconds)
  // - Traces are batched in memory (default: 512 spans OR 5 seconds)
  // - Metrics are batched in memory (default: 60 seconds)
  //
  // WITHOUT sovdev_flush():
  // - Application exits after 2 seconds
  // - Last batch still in memory (not sent yet)
  // - All logs from last batch are LOST forever
  //
  // WITH sovdev_flush():
  // - Forces immediate export of all batched data
  // - Waits for export to complete (or 30s timeout)
  // - All logs safely delivered to OTLP collector
  //
  // WHEN TO CALL:
  // 1. Before process.exit()
  // 2. In catch blocks before exiting on error
  // 3. At the end of short-lived scripts/jobs
  //
  // CROSS-LANGUAGE: All languages MUST call flush before exit

  await sovdev_flush();
}

// ============================================================================
// APPLICATION ENTRY POINT - Error Handling
// ============================================================================
// Catches unhandled errors and ensures flush happens even on failure

main().catch(async (error) => {
  console.error('Fatal error:', error);

  // CRITICAL: Flush logs even on fatal error
  // Without this, error logs might not reach the OTLP collector
  await sovdev_flush();

  process.exit(1);
});
