---
title: "Configuration"
sidebar_label: "Configuration"
sidebar_position: 2
description: "Environment variables, OTLP setup, and file logging configuration."
---

# sovdev-logger Configuration Guide

Environment-based configuration for all sovdev-logger implementations (TypeScript, Python, C#, PHP, Go, Rust).

## Environment Variables

All sovdev-logger implementations use the same environment variables for consistent behavior across programming languages.

### Service Identification

All sovdev-logger implementations require service identification using OpenTelemetry standard fields.

**Required Parameters:**

| Parameter | Description | Required | Example |
|----------|-------------|----------|---------|
| `service_name` | Your service identifier | Yes | `company-lookup-service` |
| `service_version` | Service version | No* | `1.0.0` |
| `peer_services` | External systems mapping | No | See below |

\* **Auto-detected** from package.json if not provided

#### Initialization (TypeScript/JavaScript)

```typescript
import { sovdev_initialize, create_peer_services } from 'sovdev-logger';

// Define peer services (external systems you call)
const PEER_SERVICES = create_peer_services({
  BRREG: 'SYS1234567',        // External API system ID
  DATABASE: 'INT0001234',     // Internal database system ID
  // INTERNAL is auto-generated for internal operations
});

// Initialize logger
sovdev_initialize(
  'company-lookup-service',   // Required: your service name
  '1.0.0',                    // Optional: version (auto-detected from package.json)
  PEER_SERVICES.mappings      // Optional: peer service mappings
);
```

#### Initialization (Python)

```python
# Python
from sovdev_logger import sovdev_initialize, create_peer_services

PEER_SERVICES = create_peer_services({
  'BRREG': 'SYS1234567',
  'DATABASE': 'INT0001234'
})

sovdev_initialize('company-lookup-service', '1.0.0', PEER_SERVICES['mappings'])
```

#### Initialization (Go)

```go
// Go
import (
  "github.com/helpers-no/sovdev-logger/go/sovdevlogger"
)

peerServices := sovdevlogger.CreatePeerServices(map[string]string{
  "BRREG":    "SYS1234567",
  "DATABASE": "INT0001234",
})

sovdevlogger.SovdevInitialize("company-lookup-service", "1.0.0", peerServices.Mappings)
```

#### Initialization (C# - Planned)

```csharp
// C#
using Sovdev.Logger;

var peerServices = SovdevLogger.CreatePeerServices(new Dictionary<string, string> {
  { "BRREG", "SYS1234567" },
  { "DATABASE", "INT0001234" }
});

SovdevLogger.Initialize("company-lookup-service", "1.0.0", peerServices.Mappings);
```

#### Peer Services Explained

Peer services track which external systems your service interacts with:

**TypeScript Example:**
```typescript
import { sovdev_log, SOVDEV_LOGLEVELS } from 'sovdev-logger';

// When calling external API
sovdev_log(
  SOVDEV_LOGLEVELS.INFO,
  'lookupCompany',
  'Looking up company',
  PEER_SERVICES.BRREG,     // Tracks call to BRREG system
  { orgNr: '123456789' },
  null
);

// For internal operations
sovdev_log(
  SOVDEV_LOGLEVELS.INFO,
  'processData',
  'Processing batch',
  PEER_SERVICES.INTERNAL,  // Internal operation
  { count: 10 },
  null
);
```

**Go Example:**
```go
import "github.com/helpers-no/sovdev-logger/go/sovdevlogger"

// When calling external API
sovdevlogger.SovdevLog(
  sovdevlogger.INFO,
  "lookupCompany",
  "Looking up company",
  peerServices.BRREG,      // Tracks call to BRREG system
  map[string]interface{}{"orgNr": "123456789"},
  nil,
  nil,
  "",
)

// For internal operations
sovdevlogger.SovdevLog(
  sovdevlogger.INFO,
  "processData",
  "Processing batch",
  peerServices.INTERNAL,   // Internal operation
  map[string]interface{}{"count": 10},
  nil,
  nil,
  "",
)
```

**Python Example:**
```python
from sovdev_logger import sovdev_log, SOVDEV_LOGLEVELS

# When calling external API
sovdev_log(
  SOVDEV_LOGLEVELS.INFO,
  'lookupCompany',
  'Looking up company',
  PEER_SERVICES['BRREG'],  # Tracks call to BRREG system
  {'orgNr': '123456789'},
  None
)

# For internal operations
sovdev_log(
  SOVDEV_LOGLEVELS.INFO,
  'processData',
  'Processing batch',
  PEER_SERVICES['INTERNAL'],  # Internal operation
  {'count': 10},
  None
)
```

**Log Output:**
```json
{
  "service_name": "company-lookup-service",
  "service_version": "1.0.0",
  "session_id": "18df09dd-c321-43d8-aa24-19dd7c149a56",
  "peer_service": "SYS1234567",
  "function_name": "lookupCompany",
  "message": "Looking up company",
  "trace_id": "3f43a369-9cc2-4351-a472-c5d050ab9cbf",
  "event_id": "29319322-17a6-40bc-8ea6-ac0fc9771177",
  "log_type": "transaction"
}
```

### Logging Output Control

| Variable | Values | Default | Description |
|----------|--------|---------|-------------|
| `LOG_TO_CONSOLE` | `true`/`false` | Smart default* | Enable/disable console output |
| `LOG_TO_FILE` | `true`/`false` | `true` | Enable/disable file logging |
| `LOG_FILE_PATH` | file path | `./logs/dev.log` | Path for main log file |
| `ERROR_LOG_PATH` | file path | `./logs/error.log` | Path for error-only log file |

\* **Smart default for console**: Auto-enabled if no OTLP endpoint configured, otherwise disabled.

### OpenTelemetry (OTLP) Configuration

| Variable | Description | Example |
|----------|-------------|---------|
| `OTEL_EXPORTER_OTLP_LOGS_ENDPOINT` | OTLP logs endpoint | `http://127.0.0.1/v1/logs` |
| `OTEL_EXPORTER_OTLP_TRACES_ENDPOINT` | OTLP traces endpoint | `http://127.0.0.1/v1/traces` |
| `OTEL_EXPORTER_OTLP_HEADERS` | Custom headers (JSON) | `{"Host":"otel.localhost"}` |

### Runtime Environment

| Variable | Values | Default | Description |
|----------|--------|---------|-------------|
| `NODE_ENV` | `development`/`production` | `development` | Controls console format |

## Default Behavior

### Scenario 1: No Configuration (Developer Just Installed)

```bash
# No environment variables set
```

**Result**:
- ✅ **Console**: Enabled (colored, human-readable)
- ✅ **File**: Enabled (`./logs/dev.log` + `./logs/error.log`)
- ⚠️ **OTLP**: Falls back to localhost:4318 (may not reach anywhere)

**Use Case**: Developer installs library, sees logs immediately without configuration.

---

### Scenario 2: With OTLP Configured (Production with Observability)

```bash
OTEL_EXPORTER_OTLP_LOGS_ENDPOINT=http://otel-collector:4318/v1/logs
OTEL_EXPORTER_OTLP_TRACES_ENDPOINT=http://otel-collector:4318/v1/traces
NODE_ENV=production
```

**Result**:
- ❌ **Console**: Disabled (auto, logs go to OTLP)
- ✅ **File**: Enabled (always on unless explicitly disabled)
- ✅ **OTLP**: Configured endpoint

**Use Case**: Production deployment with observability stack, no noisy console output.

---

### Scenario 3: OTLP Only (Clean Production)

```bash
OTEL_EXPORTER_OTLP_LOGS_ENDPOINT=http://otel-collector:4318/v1/logs
OTEL_EXPORTER_OTLP_TRACES_ENDPOINT=http://otel-collector:4318/v1/traces
LOG_TO_FILE=false
LOG_TO_CONSOLE=false
NODE_ENV=production
```

**Result**:
- ❌ **Console**: Disabled (explicit)
- ❌ **File**: Disabled (explicit)
- ✅ **OTLP**: Configured endpoint (only output)

**Use Case**: Production with centralized observability, no local logging.

---

### Scenario 4: File Only (Development Without Observability)

```bash
LOG_TO_CONSOLE=false
# No OTEL_EXPORTER_OTLP_LOGS_ENDPOINT set
```

**Result**:
- ❌ **Console**: Disabled (explicit)
- ✅ **File**: Enabled (default)
- ⚠️ **OTLP**: Falls back to localhost:4318

**Use Case**: Developer wants quiet console but structured file logs for debugging.

---

### Scenario 5: Everything Enabled (Maximum Debugging)

```bash
LOG_TO_CONSOLE=true
LOG_TO_FILE=true
OTEL_EXPORTER_OTLP_LOGS_ENDPOINT=http://127.0.0.1/v1/logs
OTEL_EXPORTER_OTLP_TRACES_ENDPOINT=http://127.0.0.1/v1/traces
OTEL_EXPORTER_OTLP_HEADERS={"Host":"otel.localhost"}
```

**Result**:
- ✅ **Console**: Enabled (explicit)
- ✅ **File**: Enabled (explicit)
- ✅ **OTLP**: Configured endpoint
- **All three outputs active simultaneously**

**Use Case**: Troubleshooting issues with full visibility across all outputs.

---

## Configuration Decision Matrix

| OTLP Endpoint | LOG_TO_CONSOLE | LOG_TO_FILE | Console | File | OTLP | Use Case |
|---------------|----------------|-------------|---------|------|------|----------|
| Not set | Not set | Not set | ✅ Auto | ✅ Auto | ❌ | Developer default |
| Set | Not set | Not set | ❌ Auto | ✅ Auto | ✅ | Production with files |
| Set | `false` | `false` | ❌ | ❌ | ✅ | Clean production |
| Not set | `false` | `true` | ❌ | ✅ | ❌ | File-only logging |
| Set | `true` | `true` | ✅ | ✅ | ✅ | Full debugging |

## Console Output Formats

### Development Mode (NODE_ENV ≠ production)

Colored, human-readable output with timestamps:

```
12:34:56 [INFO] my-service:myFunction - Operation completed
12:34:57 [ERROR] my-service:errorHandler - Request failed
```

### Production Mode (NODE_ENV = production)

Structured JSON output for log aggregation:

```json
{"timestamp":"2025-10-03T12:34:56.789Z","level":"info","service_name":"my-service","service_version":"1.0.0","session_id":"18df09dd-c321-43d8-aa24-19dd7c149a56","peer_service":"INTERNAL","function_name":"myFunction","message":"Operation completed","trace_id":"uuid-here","event_id":"uuid-here","log_type":"transaction","input_json":"null","response_json":"null"}
```

## File Logging Features

### Two Separate Files (Winston Best Practice)

1. **Main Log** (`./logs/dev.log` or custom `LOG_FILE_PATH`):
   - All log levels (TRACE, DEBUG, INFO, WARN, ERROR, FATAL)
   - Structured JSON format
   - Max size: 50MB, keeps 5 rotated files

2. **Error Log** (`./logs/error.log` or custom `ERROR_LOG_PATH`):
   - ERROR and FATAL levels only
   - Structured JSON format
   - Max size: 10MB, keeps 3 rotated files

### File Rotation

Files automatically rotate when they reach max size:
- `dev.log` → `dev.log.1` → `dev.log.2` → ... → `dev.log.5`
- `error.log` → `error.log.1` → `error.log.2` → `error.log.3`

Oldest files are deleted when rotation limit is reached.

## OTLP Configuration Examples

### Local Development (sovdev-infrastructure)

```bash
# Use IP address 127.0.0.1 (Node.js cannot resolve .localhost domains)
OTEL_EXPORTER_OTLP_LOGS_ENDPOINT=http://127.0.0.1/v1/logs
OTEL_EXPORTER_OTLP_TRACES_ENDPOINT=http://127.0.0.1/v1/traces

# REQUIRED: Host header for Traefik routing
OTEL_EXPORTER_OTLP_HEADERS={"Host":"otel.localhost"}
```

### Kubernetes (Inside sovdev-infrastructure)

```bash
# Use Kubernetes internal service DNS
OTEL_EXPORTER_OTLP_LOGS_ENDPOINT=http://otel-collector-opentelemetry-collector.monitoring.svc.cluster.local:4318/v1/logs
OTEL_EXPORTER_OTLP_TRACES_ENDPOINT=http://otel-collector-opentelemetry-collector.monitoring.svc.cluster.local:4318/v1/traces

# NO Host header needed - direct connection
```

### Azure Application Insights

Azure Monitor supports OTLP ingestion natively. Choose between connection string or instrumentation key authentication.

**Option 1: Using Connection String (Recommended)**

```bash
# Azure Monitor OTLP ingestion endpoint (preview)
OTEL_EXPORTER_OTLP_LOGS_ENDPOINT=https://[your-region].in.applicationinsights.azure.com/v1/logs
OTEL_EXPORTER_OTLP_TRACES_ENDPOINT=https://[your-region].in.applicationinsights.azure.com/v1/traces

# Connection string from Application Insights resource
OTEL_EXPORTER_OTLP_HEADERS={"x-ms-qps-connection-string":"InstrumentationKey=12345678-1234-1234-1234-123456789012;IngestionEndpoint=https://[your-region].in.applicationinsights.azure.com/"}
```

**Option 2: Using Instrumentation Key**

```bash
# Azure Monitor OTLP endpoint
OTEL_EXPORTER_OTLP_LOGS_ENDPOINT=https://[your-region].in.applicationinsights.azure.com/v1/logs
OTEL_EXPORTER_OTLP_TRACES_ENDPOINT=https://[your-region].in.applicationinsights.azure.com/v1/traces

# Instrumentation key from Application Insights
OTEL_EXPORTER_OTLP_HEADERS={"x-ms-qps-instrumentation-key":"12345678-1234-1234-1234-123456789012"}
```

**Finding Your Azure Configuration:**

1. **Azure Portal** → Your Application Insights resource
2. **Connection String**: Overview blade → "Connection String" field
3. **Instrumentation Key**: Overview blade → "Instrumentation Key" field
4. **Region**: Check your resource location (e.g., `westeurope`, `northeurope`, `eastus`)

**Example for Norwegian Red Cross (Norway deployment):**

```bash
# Norway East region
OTEL_EXPORTER_OTLP_LOGS_ENDPOINT=https://norwayeast.in.applicationinsights.azure.com/v1/logs
OTEL_EXPORTER_OTLP_TRACES_ENDPOINT=https://norwayeast.in.applicationinsights.azure.com/v1/traces

# Use connection string (get from Azure Portal)
OTEL_EXPORTER_OTLP_HEADERS={"x-ms-qps-connection-string":"InstrumentationKey=YOUR_KEY;IngestionEndpoint=https://norwayeast.in.applicationinsights.azure.com/"}
```

**Notes:**
- Replace `[your-region]` with your Azure region (e.g., `norwayeast`, `westeurope`)
- Connection string method is recommended as it includes both key and endpoint
- OTLP support in Azure Monitor is in preview - check [Azure Monitor OpenTelemetry documentation](https://learn.microsoft.com/en-us/azure/azure-monitor/app/opentelemetry-enable) for updates
- Logs appear in the `traces` and `customEvents` tables in Application Insights

### Grafana Cloud

```bash
# Grafana Cloud OTLP endpoint
OTEL_EXPORTER_OTLP_LOGS_ENDPOINT=https://otlp-gateway-prod-eu-west-0.grafana.net/otlp/v1/logs
OTEL_EXPORTER_OTLP_TRACES_ENDPOINT=https://otlp-gateway-prod-eu-west-0.grafana.net/otlp/v1/traces

# Grafana Cloud authentication
OTEL_EXPORTER_OTLP_HEADERS={"Authorization":"Basic BASE64_ENCODED_CREDENTIALS"}
```

## Best Practices

### 1. Development

```bash
# Console + File (OTLP optional)
LOG_TO_CONSOLE=true
LOG_TO_FILE=true
NODE_ENV=development
```

**Why**: Immediate feedback via console, structured logs in files for debugging.

### 2. Staging/Testing

```bash
# File + OTLP (no console noise)
OTEL_EXPORTER_OTLP_LOGS_ENDPOINT=http://otel-collector:4318/v1/logs
OTEL_EXPORTER_OTLP_TRACES_ENDPOINT=http://otel-collector:4318/v1/traces
LOG_TO_FILE=true
NODE_ENV=production
```

**Why**: Centralized logs in observability stack, files for fallback/debugging.

### 3. Production

```bash
# OTLP only (clean, centralized)
OTEL_EXPORTER_OTLP_LOGS_ENDPOINT=https://your-observability-backend/v1/logs
OTEL_EXPORTER_OTLP_TRACES_ENDPOINT=https://your-observability-backend/v1/traces
OTEL_EXPORTER_OTLP_HEADERS={"Authorization":"Bearer YOUR_TOKEN"}
LOG_TO_FILE=false
LOG_TO_CONSOLE=false
NODE_ENV=production
```

**Why**: All logs go to centralized observability platform, no local disk usage.

### 4. Kubernetes/Cloud

```bash
# Console JSON + OTLP (stdout captured by platform)
LOG_TO_CONSOLE=true
LOG_TO_FILE=false  # Don't use pod filesystem
OTEL_EXPORTER_OTLP_LOGS_ENDPOINT=http://otel-collector:4318/v1/logs
OTEL_EXPORTER_OTLP_TRACES_ENDPOINT=http://otel-collector:4318/v1/traces
NODE_ENV=production
```

**Why**: Kubernetes/cloud platforms capture stdout, file logging unnecessary.

## Language-Specific Notes

### TypeScript/JavaScript

Environment variables are read via `process.env`.

### Python

Environment variables are read via `os.getenv()`.

### C#

Environment variables are read via `Environment.GetEnvironmentVariable()`.

### PHP

Environment variables are read via `getenv()`.

### Go

Environment variables are read via `os.Getenv()`.

### Rust

Environment variables are read via `std::env::var()`.

## Troubleshooting

### No Logs Appearing

**Check**:
1. Is at least one output enabled? (console, file, or OTLP)
2. If file logging: Does the process have write permissions to `./logs/`?
3. If OTLP: Is the endpoint reachable?

**Solution**:
```bash
# Enable console for immediate visibility
LOG_TO_CONSOLE=true
```

### OTLP Connection Refused

**Symptom**: Logs appear in console/file but not in observability platform.

**Check**:
1. Is OTLP collector running and reachable?
2. Test connection: `curl -X POST $OTEL_EXPORTER_OTLP_LOGS_ENDPOINT`
3. Check headers if using Traefik/proxy

**Solution**:
```bash
# Verify endpoint
echo $OTEL_EXPORTER_OTLP_LOGS_ENDPOINT

# Test with curl
curl -v -X POST http://127.0.0.1/v1/logs \
  -H "Host: otel.localhost" \
  -H "Content-Type: application/json" \
  -d '{}'
```

### File Permission Errors

**Symptom**: `EACCES: permission denied, open './logs/dev.log'`

**Solution**:
```bash
# Create logs directory with correct permissions
mkdir -p ./logs
chmod 755 ./logs

# Or change log path
LOG_FILE_PATH=/tmp/app.log
```

## Security Considerations

### Credential Removal

sovdev-logger automatically removes sensitive information from error logs:
- Authorization headers
- Bearer tokens
- API keys
- Password fields

**Example**:
```typescript
const error = new Error('API call failed');
error.config = {
  headers: { Authorization: 'Bearer secret-token' }
};

// Logged as:
// exception.message: "API call failed"
// exception.config.headers.Authorization: "[REDACTED]"
```

### Production Recommendations

1. **Never log to files in production** unless required for compliance
2. **Use OTLP with authentication** when sending to external collectors
3. **Set NODE_ENV=production** to disable colored console output
4. **Rotate logs frequently** if using file logging in production
5. **Monitor disk usage** if file logging is enabled

---

## Quick Reference

**Default (no config)**: Console + File
**Production**: OTLP only (`LOG_TO_FILE=false`, `LOG_TO_CONSOLE=false`)
**Development**: Console + File + OTLP (all enabled)
**Kubernetes**: Console JSON + OTLP (`LOG_TO_FILE=false`)

**Override any default**: Set environment variable explicitly to `true` or `false`.
