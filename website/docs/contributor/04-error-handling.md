---
title: Error handling
sidebar_label: Error handling
sidebar_position: 8
description: "Exception handling, credential removal, stack trace limits."
---

# Error Handling and Exception Processing

## Overview

This document defines how sovdev-logger implementations MUST handle errors and exceptions, with particular focus on **security** (credential removal) and **operational safety** (stack trace limiting, graceful degradation).

---

## Core Principles

### 1. Never Break User Code
The logger MUST NEVER throw exceptions that break the user's application. Logging failures should be logged to console and execution should continue.

### 2. Security by Default
All exception data MUST be sanitized to remove credentials before being logged or exported.

### 3. Operational Safety
Stack traces MUST be limited to prevent log flooding attacks or accidental massive log entries.

### 4. Graceful Degradation
If OpenTelemetry export fails, console and file logging MUST continue working.

---

## Exception Type Standardization

### Problem
Different programming languages have different exception type names:
- Python: `Exception`, `ValueError`, `TypeError`, etc.
- TypeScript: `Error`, `TypeError`, `ReferenceError`, etc.
- Java: `Exception`, `RuntimeException`, `IOException`, etc.
- Go: No exception types (uses `error` interface)

This inconsistency breaks cross-language alerting and Grafana queries.

### Solution
**ALL implementations MUST use "Error" as the `exceptionType` field value**, regardless of the actual language-specific exception class.

**TypeScript Example:**
```typescript
try {
  throw new TypeError('Invalid input');
} catch (error) {
  sovdev_log(
    SOVDEV_LOGLEVELS.ERROR,
    'validate',
    'Validation failed',
    PEER_SERVICES.INTERNAL,
    null,
    null,
    error as Error  // TypeScript: error.constructor.name = "TypeError"
  );
}
```

**Python Example:**
```python
try:
    raise ValueError('Invalid input')
except Exception as error:
    sovdev_log(
        SOVDEV_LOGLEVELS.ERROR,
        'validate',
        'Validation failed',
        PEER_SERVICES.INTERNAL,
        exception=error  # Python: type(error).__name__ = "ValueError"
    )
```

**Expected Output (OTLP) - IDENTICAL for both:**
```json
{
  "exceptionType": "Error",
  "exceptionMessage": "Invalid input",
  "exceptionStack": "..."
}
```

**Why "Error" not "Exception":**
- "Error" is universally understood across languages
- TypeScript/JavaScript use "Error" as base class
- More concise and familiar to most developers
- Language-specific details available in `exceptionStack`

---

## Stack Trace Limiting

### Problem
Unlimited stack traces can cause:
- **Log flooding**: Very deep call stacks create massive log entries
- **Storage costs**: Elasticsearch/Loki storage consumed by huge traces
- **Performance**: Parsing and querying large log entries is slow
- **Security**: Longer traces increase risk of credential leakage

### Solution
**Stack traces MUST be truncated to 350 characters maximum.**

**Implementation Pattern:**
```typescript
function limitStackTrace(stack: string, maxLength: number = 350): string {
  if (!stack) return '';
  if (stack.length <= maxLength) return stack;
  return stack.substring(0, maxLength) + '... (truncated)';
}
```

**Example:**
```typescript
// Original stack: 2000 characters
const longStack = `Error: HTTP 404: Not Found
    at IncomingMessage.<anonymous> (/workspace/typescript/test/e2e/company-lookup/company-lookup.ts:50:20)
    at IncomingMessage.emit (node:events:514:28)
    at endReadableNT (node:internal/streams/readable:1360:12)
    ... (many more lines)
`;

// After limiting: 350 characters
const limitedStack = `Error: HTTP 404: Not Found
    at IncomingMessage.<anonymous> (/workspace/typescript/test/e2e/company-lookup/company-lookup.ts:50:20)
    at IncomingMessage.emit (node:events:514:28)
    at endReadableNT (node:internal/streams/readable:1360:12)... (truncated)`;
```

**Why 350 characters:**
- Captures top 3-5 stack frames (most relevant for debugging)
- Small enough to prevent log flooding
- Large enough to identify error location
- Fits comfortably in Grafana table cells

---

## Credential Removal from Stack Traces

### Problem
Exception stack traces may contain sensitive credentials:
- Authorization headers (`Authorization: Bearer secret-token`)
- API keys (`X-API-Key: api-key-12345`)
- Passwords (`password=secret123`)
- JWT tokens (`eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...`)
- Session cookies (`sessionId=abc123xyz`)

These credentials MUST NOT be logged or exported to OTLP.

### Solution
**All stack traces MUST be sanitized using regex patterns to remove credential values.**

### Required Regex Patterns

**TypeScript Implementation:**
```typescript
function removeCredentialsFromStack(stack: string): string {
  if (!stack) return '';

  let cleanStack = stack;

  // Remove Authorization headers
  cleanStack = cleanStack.replace(
    /Authorization[:\s]+[^\s,}]+/gi,
    'Authorization: [REDACTED]'
  );

  // Remove Bearer tokens
  cleanStack = cleanStack.replace(
    /Bearer\s+[A-Za-z0-9\-._~+/]+=*/gi,
    'Bearer [REDACTED]'
  );

  // Remove API keys
  cleanStack = cleanStack.replace(
    /api[-_]?key[:\s=]+[^\s,}]+/gi,
    'api-key: [REDACTED]'
  );

  // Remove passwords
  cleanStack = cleanStack.replace(
    /password[:\s=]+[^\s,}]+/gi,
    'password: [REDACTED]'
  );

  // Remove JWT tokens (pattern: xxx.yyy.zzz)
  cleanStack = cleanStack.replace(
    /[A-Za-z0-9\-_]+\.[A-Za-z0-9\-_]+\.[A-Za-z0-9\-_]+/g,
    '[REDACTED-JWT]'
  );

  // Remove session IDs
  cleanStack = cleanStack.replace(
    /session[-_]?id[:\s=]+[^\s,}]+/gi,
    'session-id: [REDACTED]'
  );

  // Remove cookie values
  cleanStack = cleanStack.replace(
    /Cookie[:\s]+[^\r\n]+/gi,
    'Cookie: [REDACTED]'
  );

  return cleanStack;
}
```

**Python Implementation:**
```python
import re

def remove_credentials_from_stack(stack: str) -> str:
    """Remove sensitive credentials from exception stack traces."""
    if not stack:
        return ''

    clean_stack = stack

    # Remove Authorization headers
    clean_stack = re.sub(
        r'Authorization[:\s]+[^\s,}]+',
        'Authorization: [REDACTED]',
        clean_stack,
        flags=re.IGNORECASE
    )

    # Remove Bearer tokens
    clean_stack = re.sub(
        r'Bearer\s+[A-Za-z0-9\-._~+/]+=*',
        'Bearer [REDACTED]',
        clean_stack,
        flags=re.IGNORECASE
    )

    # Remove API keys
    clean_stack = re.sub(
        r'api[-_]?key[:\s=]+[^\s,}]+',
        'api-key: [REDACTED]',
        clean_stack,
        flags=re.IGNORECASE
    )

    # Remove passwords
    clean_stack = re.sub(
        r'password[:\s=]+[^\s,}]+',
        'password: [REDACTED]',
        clean_stack,
        flags=re.IGNORECASE
    )

    # Remove JWT tokens
    clean_stack = re.sub(
        r'[A-Za-z0-9\-_]+\.[A-Za-z0-9\-_]+\.[A-Za-z0-9\-_]+',
        '[REDACTED-JWT]',
        clean_stack
    )

    # Remove session IDs
    clean_stack = re.sub(
        r'session[-_]?id[:\s=]+[^\s,}]+',
        'session-id: [REDACTED]',
        clean_stack,
        flags=re.IGNORECASE
    )

    # Remove cookie values
    clean_stack = re.sub(
        r'Cookie[:\s]+[^\r\n]+',
        'Cookie: [REDACTED]',
        clean_stack,
        flags=re.IGNORECASE
    )

    return clean_stack
```

### Test Cases for Credential Removal

**Test 1: Authorization Header**
```
Input:  "Error at fetch() with headers Authorization: Bearer eyJhbGciOiJIUzI1..."
Output: "Error at fetch() with headers Authorization: [REDACTED]"
```

**Test 2: API Key**
```
Input:  "Request failed: X-API-Key: abc123xyz456"
Output: "Request failed: X-API-Key: [REDACTED]"
```

**Test 3: Password**
```
Input:  "Login error: password=secretPass123"
Output: "Login error: password: [REDACTED]"
```

**Test 4: JWT Token**
```
Input:  "Token expired: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.dozjgNryP4J3jVmNHl0w5N_XgL0n3I9PlFUP0THsR8U"
Output: "Token expired: [REDACTED-JWT]"
```

**Test 5: Session ID**
```
Input:  "Session error: session_id=abc123def456"
Output: "Session error: session-id: [REDACTED]"
```

**Test 6: Cookie**
```
Input:  "Request with Cookie: sessionId=abc123; userId=xyz789"
Output: "Request with Cookie: [REDACTED]"
```

---

## Exception Processing Pipeline

### Complete Processing Flow

```typescript
function processException(error: Error): {
  exception_type: string;
  exception_message: string;
  exception_stacktrace: string;
} {
  // 1. Extract raw stack trace
  let rawStack = error.stack || '';

  // 2. Remove credentials
  let cleanStack = removeCredentialsFromStack(rawStack);

  // 3. Limit stack trace length
  let limitedStack = limitStackTrace(cleanStack, 350);

  // 4. Standardize exception type
  const exception_type = 'Error';  // Always "Error" regardless of actual type

  // 5. Extract message
  const exception_message = error.message || 'Unknown error';

  return {
    exception_type,
    exception_message,
    exception_stacktrace: limitedStack
  };
}
```

### Order of Operations is Critical

**CORRECT order:**
1. Extract raw stack trace
2. Remove credentials (security)
3. Limit length (operational safety)
4. Export to OTLP/console/file

**WRONG order (insecure):**
1. Limit length first
2. Remove credentials second
→ **Problem:** Credentials at end of stack might not be removed if stack was truncated before credential removal

---

## Graceful Degradation

### OpenTelemetry Export Failures

**Scenario:** OTLP collector is unreachable or returns errors.

**Required Behavior:**
- ✅ Log warning to console: "Failed to export logs to OTLP: `<error>`"
- ✅ Continue writing to console output
- ✅ Continue writing to file output
- ✅ Do NOT throw exception to user code
- ✅ Do NOT crash application

**Implementation Pattern:**
```typescript
try {
  await otlpExporter.export(logs);
} catch (error) {
  console.warn('Failed to export logs to OTLP:', error.message);
  // Continue execution - console and file logging still work
}
```

### File System Failures

**Scenario:** Cannot write to log file (permissions, disk full, etc.).

**Required Behavior:**
- ✅ Log warning to console: "Failed to write to log file: `<error>`"
- ✅ Continue writing to console output
- ✅ Continue OTLP export
- ✅ Do NOT throw exception to user code

**Implementation Pattern:**
```typescript
try {
  fs.appendFileSync(logFilePath, logEntry + '\n');
} catch (error) {
  console.warn('Failed to write to log file:', error.message);
  // Continue execution - console and OTLP still work
}
```

### Console Output Failures

**Scenario:** stdout/stderr is closed or redirected to invalid target.

**Required Behavior:**
- ✅ Silently continue (no warning possible since console is unavailable)
- ✅ Continue writing to file
- ✅ Continue OTLP export

**Implementation Pattern:**
```typescript
try {
  console.log(formattedLog);
} catch (error) {
  // Cannot log warning since console is unavailable
  // Silently continue with file and OTLP
}
```

---

## Error Handling in sovdev_shutdown()

### Purpose
`sovdev_shutdown()` forces immediate export of all pending batches to the OTLP collector, then permanently shuts down the SDK. This is critical before application exit, and MUST only be called once per process — `sovdev_flush()` is the repeatable counterpart for anywhere short of true process end (see `01-api-contract.md` sections 5-6 for the full contract, including the cross-language bug this split fixed).

### Timeout Behavior
**Requirement:** The flush portion MUST complete within 30 seconds or timeout.

**Implementation Pattern:**
```typescript
async function sovdev_shutdown(timeoutMs: number = 30000): Promise<void> {
  const timeoutPromise = new Promise<void>((_, reject) => {
    setTimeout(() => reject(new Error('Flush timeout')), timeoutMs);
  });

  const flushPromise = Promise.all([
    logProvider.forceFlush(),
    meterProvider.forceFlush(),
    traceProvider.forceFlush()
  ]);

  try {
    await Promise.race([flushPromise, timeoutPromise]);
  } catch (error) {
    console.warn('Failed to flush logs:', error.message);
    // Do not throw - allow application to continue shutdown
  }

  await Promise.all([
    logProvider.shutdown(),
    meterProvider.shutdown(),
    traceProvider.shutdown()
  ]);
}
```

### Exit Handler Integration

**Requirement:** Shutdown SHOULD be called automatically on process exit signals — exactly once, never per-request in a long-running server.

**TypeScript/Node.js Example:**
```typescript
process.on('SIGINT', async () => {
  console.log('Shutting down telemetry before exit...');
  await sovdev_shutdown();
  process.exit(0);
});

process.on('SIGTERM', async () => {
  console.log('Shutting down telemetry before exit...');
  await sovdev_shutdown();
  process.exit(0);
});

process.on('beforeExit', async () => {
  await sovdev_shutdown();
});
```

**Python Example** (synchronous — no `asyncio`/`await` needed, unlike TypeScript):
```python
import signal
import atexit

def shutdown_on_exit():
    sovdev_shutdown()

atexit.register(shutdown_on_exit)

def signal_handler(signum, frame):
    print('Shutting down telemetry before exit...')
    sovdev_shutdown()
    sys.exit(0)

signal.signal(signal.SIGINT, signal_handler)
signal.signal(signal.SIGTERM, signal_handler)
```

**See Also**:
- **API Contract**: `01-api-contract.md` → Function 6: sovdev_shutdown (and Function 5: sovdev_flush, the repeatable counterpart)
- **Batch Processing Details**: `03-implementation-patterns.md` → OpenTelemetry Batch Processing

---

## Null/Undefined Handling

### Input Parameters

**Requirement:** Library MUST handle null/undefined/None gracefully for optional parameters.

**Test Cases:**
```typescript
// Valid: Optional parameters omitted
sovdev_log(SOVDEV_LOGLEVELS.INFO, 'test', 'msg', PEER_SERVICES.INTERNAL);

// Valid: Optional parameters explicitly null
sovdev_log(SOVDEV_LOGLEVELS.INFO, 'test', 'msg', PEER_SERVICES.INTERNAL, null, null, null, null);

// Valid: Some optional parameters provided
sovdev_log(SOVDEV_LOGLEVELS.INFO, 'test', 'msg', PEER_SERVICES.INTERNAL, {input: 'data'}, null);
```

**Required Behavior:**
- `null` or `undefined` inputJSON → `inputJSON: "null"` in output
- `null` or `undefined` responseJSON → `responseJSON: "null"` in output
- `null` or `undefined` exception → no exception fields in output
- `null` or `undefined` traceId → generate new UUID

### Required Parameters

**Requirement:** Library MUST validate required parameters and fail gracefully.

**Required parameters:**
- `level` (log level)
- `functionName` (string)
- `message` (string)
- `peerService` (string)

**Test Cases:**
```typescript
// Invalid: null level
sovdev_log(null, 'test', 'msg', PEER_SERVICES.INTERNAL);
// Expected: Log warning to console, skip logging operation

// Invalid: empty functionName
sovdev_log(SOVDEV_LOGLEVELS.INFO, '', 'msg', PEER_SERVICES.INTERNAL);
// Expected: Log warning to console, use "unknown" as functionName

// Invalid: empty message
sovdev_log(SOVDEV_LOGLEVELS.INFO, 'test', '', PEER_SERVICES.INTERNAL);
// Expected: Log warning to console, use "(no message)" as message
```

---

## Error Messages

### User-Facing Error Messages

All error messages MUST be:
- **Clear**: Explain what went wrong
- **Actionable**: Tell user how to fix it
- **Non-technical**: Avoid internal implementation details
- **Consistent**: Use same format across all errors

**Examples:**

```typescript
// Good error message
"Failed to initialize sovdev-logger: SERVICE_NAME environment variable not set.
Set SERVICE_NAME or call sovdev_initialize() with service name."

// Bad error message
"Error: undefined is not a function at Logger.initialize"
```

```typescript
// Good error message
"Failed to export logs to OTLP collector at http://localhost:4318/v1/logs:
Connection refused. Verify OTLP collector is running and OTEL_EXPORTER_OTLP_LOGS_ENDPOINT is correct."

// Bad error message
"ECONNREFUSED"
```

### Warning Messages

Warnings SHOULD be logged for:
- OpenTelemetry export failures (degraded mode)
- File write failures (degraded mode)
- Invalid optional parameters (defaulted)
- Flush timeout (potential data loss)

**Format:**
```
[sovdev-logger] WARNING: <message>
```

**Examples:**
```
[sovdev-logger] WARNING: Failed to write to log file /var/log/app.log: Permission denied
[sovdev-logger] WARNING: OTLP export failed: Connection timeout after 30s
[sovdev-logger] WARNING: Flush timeout - some logs may not have been exported
```

---

## Security Considerations

### Private Information Disclosure

**Beyond credentials, also consider:**
- Personal identifiable information (PII)
- Internal IP addresses
- Internal hostnames
- Database connection strings
- File system paths (may reveal internal structure)

**Current Scope:** Sovdev-logger ONLY removes credentials. Application developers are responsible for not passing PII in `inputJSON` or `responseJSON`.

**Future Enhancement:** Could add optional PII detection/masking (email addresses, phone numbers, social security numbers).

### Log Injection Attacks

**Threat:** Attacker controls input data that contains newlines or ANSI codes, breaking log format.

**Mitigation:**
- JSON output is naturally resistant (JSON escapes newlines)
- Console output should escape ANSI codes in user-provided data
- File output uses JSON Lines format (one entry per line)

**Implementation Note:** Validate that `message` and `functionName` don't contain newlines in console output.

---

## Testing Error Handling

### Required Test Cases

1. **Exception with credentials in stack**
   - Verify credentials are removed

2. **Very long stack trace**
   - Verify truncation to 350 characters

3. **OTLP export failure**
   - Verify console/file still work

4. **File write failure**
   - Verify console/OTLP still work

5. **Null parameters**
   - Verify graceful defaults

6. **Invalid required parameters**
   - Verify warning logged, operation skipped

7. **Flush timeout**
   - Verify returns after 30 seconds

8. **Multiple exceptions rapidly**
   - Verify no resource leaks or blocking

---

## Performance Considerations

### Error Processing Overhead

**Requirement:** Exception processing MUST add < 1ms overhead per error log.

**Measurement:**
```typescript
const start = performance.now();
for (let i = 0; i < 1000; i++) {
  sovdev_log(
    SOVDEV_LOGLEVELS.ERROR,
    'test',
    'error',
    PEER_SERVICES.INTERNAL,
    null,
    null,
    new Error('test error')
  );
}
const end = performance.now();
const avgTime = (end - start) / 1000;
console.log(`Average error log time: ${avgTime}ms`);
// Expected: < 1ms
```

### Regex Performance

**Concern:** Multiple regex operations on every stack trace could be slow.

**Optimization:** Combine patterns where possible, precompile regex.

```typescript
// Optimized: Single regex with alternation
const CREDENTIAL_PATTERN = new RegExp(
  '(Authorization[:\\s]+[^\\s,}]+)|' +
  '(Bearer\\s+[A-Za-z0-9\\-._~+/]+=*)|' +
  '(api[-_]?key[:\\s=]+[^\\s,}]+)|' +
  '(password[:\\s=]+[^\\s,}]+)',
  'gi'
);

function removeCredentials(stack: string): string {
  return stack.replace(CREDENTIAL_PATTERN, '[REDACTED]');
}
```

---

## Success Criteria

Error handling is **correct** when:

1. ✅ All exceptions use "Error" as `exceptionType` (cross-language consistency)
2. ✅ Stack traces limited to 350 characters (operational safety)
3. ✅ Credentials removed from all stack traces (security)
4. ✅ OpenTelemetry failures don't crash application (graceful degradation)
5. ✅ File write failures don't crash application (graceful degradation)
6. ✅ Null/undefined parameters handled gracefully (robustness)
7. ✅ Flush completes within 30 seconds or times out (predictable behavior)
8. ✅ User-facing error messages are clear and actionable (usability)

---

**Document Status:** ✅ v1.0.0 COMPLETE
**Last Updated:** 2025-10-27
**Part of:** sovdev-logger specification v1.1.0
