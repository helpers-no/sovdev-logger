---
title: Environment configuration
sidebar_label: Environment configuration
sidebar_position: 9
description: "Environment variables, DevContainer setup, language toolchain."
---

# Development Environment Configuration

## Overview

This document describes the **complete development environment** required for developing and testing sovdev-logger implementations. The environment consists of two main components:

1. **DevContainer Toolbox** - Provides all programming language runtimes
2. **Local Kubernetes Cluster** - Runs the observability stack (Loki, Prometheus, Tempo, Grafana)

Both components are **required** for developing and testing any language implementation.

---

## Architecture Diagram

This diagram shows the complete development environment architecture and how components interact:

```
┌─────────────────────────────────────────────────────────────────────────┐
│ HOST MACHINE (Mac/Windows/Linux)                                        │
│                                                                          │
│  Human developers (optional):                                           │
│  • File editing with VSCode                                             │
│  • Work inside DevContainer for full toolchain access                  │
│                                                                          │
│  Project Files: /Users/.../sovdev-logger/                               │
│         ↕ [bind mount - bidirectional, real-time sync]                  │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │ DEVCONTAINER (Docker Container)                                   │  │
│  │                                                                    │  │
│  │  Workspace: /workspace/ (same files as host via bind mount)      │  │
│  │                                                                    │  │
│  │  🤖 LLM Execution Context (Claude Code runs here):               │  │
│  │  • File editing (Read/Edit/Write at /workspace/)                 │  │
│  │  • Command execution (direct)                                     │  │
│  │                                                                    │  │
│  │  Code executes here:                                              │  │
│  │  • Language runtimes (Node.js ✅, Python ✅, Go*, Rust*, etc.)   │  │
│  │  • Test programs run                                              │  │
│  │  • Validation tools run                                           │  │
│  │  • OTLP export originates FROM here                              │  │
│  │                                                                    │  │
│  │  Your Test Program                                                │  │
│  │  └─ sovdev_log() ───┐                                            │  │
│  │                      │                                            │  │
│  │                      ↓                                            │  │
│  │              ┌──────────────────┐                                │  │
│  │              │ OpenTelemetry SDK│                                │  │
│  │              │ OTLP Exporter    │                                │  │
│  │              └────────┬─────────┘                                │  │
│  │                       │                                           │  │
│  │                       │ HTTP POST with header:                   │  │
│  │                       │ Host: otel.localhost                     │  │
│  │                       │                                           │  │
│  └───────────────────────┼───────────────────────────────────────────┘  │
│                          │                                              │
└──────────────────────────┼──────────────────────────────────────────────┘
                           │
                           │ http://host.docker.internal/v1/logs
                           │ http://host.docker.internal/v1/metrics
                           │ http://host.docker.internal/v1/traces
                           │ Header: Host=otel.localhost ⚠️ REQUIRED
                           │
                           ↓
┌─────────────────────────────────────────────────────────────────────────┐
│ KUBERNETES CLUSTER (Local K3s via Rancher Desktop)                      │
│                                                                          │
│  Traefik Ingress (Port 80)                                              │
│  ┌────────────────────────────────────────────────────────────────┐    │
│  │ Routes based on Host header:                                    │    │
│  │                                                                  │    │
│  │  Host: otel.localhost     → OTLP Collector (port 4318)         │    │
│  │  Host: grafana.localhost  → Grafana (port 80)                  │    │
│  │  Host: loki.localhost     → Loki (port 80) [optional]          │    │
│  │  (No Host header)         → 404 Not Found ❌                   │    │
│  └────────────────────────────────────────────────────────────────┘    │
│                           │                                              │
│                           ↓                                              │
│  ┌────────────────────────────────────────────────────────────────┐    │
│  │ OTLP Collector (otel-collector-opentelemetry-collector)        │    │
│  │                                                                  │    │
│  │  Receives: Logs, Metrics, Traces via OTLP/HTTP                 │    │
│  │  Exports to: Loki, Prometheus, Tempo                           │    │
│  └──────────┬──────────────────┬──────────────────┬────────────────┘    │
│             │                  │                  │                      │
│      ┌──────┘                  │                  └──────┐               │
│      ↓                         ↓                         ↓               │
│  ┌────────┐            ┌──────────────┐            ┌─────────┐          │
│  │ LOKI   │            │ PROMETHEUS   │            │  TEMPO  │          │
│  │        │            │              │            │         │          │
│  │ Stores │            │ Stores       │            │ Stores  │          │
│  │ Logs   │            │ Metrics      │            │ Traces  │          │
│  └────┬───┘            └──────┬───────┘            └────┬────┘          │
│       │                       │                         │                │
│       │                       │                         │                │
│       └───────────────────────┼─────────────────────────┘                │
│                               ↓                                          │
│                        ┌─────────────┐                                  │
│                        │   GRAFANA   │                                  │
│                        │             │                                  │
│                        │ Dashboards  │                                  │
│                        │ Queries all │                                  │
│                        │ 3 backends  │                                  │
│                        └─────────────┘                                  │
│                                                                          │
│  Access from browser: http://grafana.localhost                          │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

**Validation:** See [`tools/validation/uis/README.md`](https://github.com/helpers-no/sovdev-logger/blob/main/tools/validation/uis/README.md) for the complete tool reference, and [`09-development-loop.md`](./09-development-loop.md) for the workflow.

**Key Architecture:**

1. **Files**: Host project directory bind-mounted to `/workspace/` in container
2. **Execution**: Code runs inside DevContainer at `/workspace/`
3. **OTLP**: DevContainer → `http://host.docker.internal/v1/{logs,metrics,traces}` with `Host: otel.localhost` header → Traefik → OTLP Collector
4. **Storage**: OTLP Collector → Loki (logs), Prometheus (metrics), Tempo (traces)
5. **Visualization**: Grafana queries all backends at `http://grafana.localhost`

**Traefik requires `Host` header for routing** - without it, requests return 404.

---

## Component 1: DevContainer Toolbox

### Purpose

The DevContainer provides a **standardized development environment** with all programming language runtimes pre-installed. This eliminates "works on my machine" problems and ensures consistent behavior across Mac, Windows, and Linux.

### Architecture

```
Host Machine (Mac/Windows/Linux)
├── Project Files (editable from host)
└── DevContainer (running in Docker)
    ├── All Language Runtimes (Node.js, Python, Go, Java, PHP, C#, Rust)
    ├── Development Tools (git, curl, wget, etc.)
    └── Workspace Mount: /workspace → Host Project Root
```

### Key Specifications

| Property | Value | Notes |
|----------|-------|-------|
| **Container Name** | `devcontainer-toolbox` | Fixed name, always use this |
| **Base Image** | Debian 12 (bookworm) | Stable, well-supported |
| **User** | `vscode` (UID 1000) | Non-root user |
| **Workspace Mount** | `/workspace` → Host project root | Bidirectional read-write; changes on host instantly visible in container and vice versa |
| **Network Mode** | Bridge with host gateway | Can access host services via `host.docker.internal` |

**Workspace Mount**

Host project directory is bind-mounted to `/workspace/` in container:
- Changes in container appear on host instantly (same filesystem, not a copy)
- Use `/workspace/` prefix for all file paths inside container
- Example: `/workspace/typescript/src/logger.ts` maps to `<project-root>/typescript/src/logger.ts` on host

### Language Runtimes

**Pre-installed:** Node.js, Python, PowerShell

**Other languages:** Install from `/workspace/.devcontainer/additions/install-dev-*.sh`

Each installation script has metadata at the top:
```bash
SCRIPT_NAME="C# Development Tools"
SCRIPT_DESCRIPTION="Complete .NET 8.0 development environment..."
CHECK_INSTALLED_COMMAND="command -v dotnet >/dev/null 2>&1"
```

**To install a language:**
```bash
# List available installers
ls /workspace/.devcontainer/additions/install-dev-*.sh

# Check if already installed (example: C#)
dotnet --version

# Install if not found
/workspace/.devcontainer/additions/install-dev-csharp.sh
```

### Command Execution

All commands execute at `/workspace/` inside the DevContainer. Validation tools are in `/workspace/tools/validation/uis/` (local UIS backend) and `/workspace/tools/validation/grafana-cloud/` (Grafana Cloud backend).

### Network Access

**From DevContainer to host services:**

Use `host.docker.internal` DNS name to access services on the host machine (Kubernetes cluster):

```bash
# OTLP endpoints
http://host.docker.internal/v1/logs
http://host.docker.internal/v1/metrics
http://host.docker.internal/v1/traces

# All require: Host: otel.localhost header
```

**Note:** OTLP endpoint details covered in Component 2 section below.

---

## Component 2: Local Kubernetes Cluster

### Purpose

Runs the observability stack (Loki, Prometheus, Tempo, Grafana) that receives and stores telemetry during testing.

### OTLP Endpoints (For Implementation)

**Send telemetry to:**
```
Endpoint: http://host.docker.internal/v1/{logs,metrics,traces}
Required Header: Host: otel.localhost
Protocol: HTTP/Protobuf
```

**Environment variable:**
```bash
OTEL_EXPORTER_OTLP_HEADERS=Host=otel.localhost
```

**⚠️ CRITICAL:** The `Host: otel.localhost` header is required for Traefik routing. Without it, requests fail with 404 errors.

**Format note:** `OTEL_EXPORTER_OTLP_HEADERS` is a standard OpenTelemetry env var — comma-separated `key=value` pairs (e.g. `Host=otel.localhost,Authorization=Basic ...`), **not JSON**. The OTel SDK reads this env var natively; a JSON value collides with that native parsing (see [`INVESTIGATE-otlp-headers-standard-compliance.md`](../ai-developer/plans/completed/INVESTIGATE-otlp-headers-standard-compliance.md)).

**Troubleshooting:** Some HTTP clients (e.g., Go) override custom Host headers. See `task-06-implement-otlp.md` subsection 6.12 for language-specific workarounds.

### Validation

**Use validation tools instead of direct queries:**
```bash
cd /workspace/tools/validation/uis

# Query individual backends (add --compare-with LOGFILE for exact-match validation)
./query-loki.sh <service-name>
./query-prometheus.sh <service-name>
./query-tempo.sh <service-name>

# Cross-language conformance (the completion gate)
./compare-with-master.sh <language>
```

**Complete tool documentation:** See [`tools/validation/uis/README.md`](https://github.com/helpers-no/sovdev-logger/blob/main/tools/validation/uis/README.md)

### Visualization

**View results in Grafana:**
- **URL:** `http://grafana.localhost`
- **Credentials:** admin/admin
- **Dashboards:** Pre-configured for sovdev-logger

**For troubleshooting:** See [Testing against UIS](./testing/uis.md) → Troubleshooting section

---
## Environment Variables

### For Application Code (Inside DevContainer)

**Required for OTLP Export:**
```bash
# OTLP Endpoints (from container to host)
export OTEL_EXPORTER_OTLP_LOGS_ENDPOINT=http://host.docker.internal/v1/logs
export OTEL_EXPORTER_OTLP_METRICS_ENDPOINT=http://host.docker.internal/v1/metrics
export OTEL_EXPORTER_OTLP_TRACES_ENDPOINT=http://host.docker.internal/v1/traces

# OTLP Headers (Traefik routing) — key=value, not JSON (see above)
export OTEL_EXPORTER_OTLP_HEADERS=Host=otel.localhost
```

**Service Identification:**
```bash
# Service name (OpenTelemetry standard - appears in Grafana)
export OTEL_SERVICE_NAME="sovdev-test-company-lookup-typescript"

# Service version (optional)
export SERVICE_VERSION="1.0.0"
```

**Logging Configuration:**
```bash
# Enable console logging
export LOG_TO_CONSOLE=true

# Enable file logging
export LOG_TO_FILE=true
export LOG_FILE_PATH=./logs/dev.log
export ERROR_LOG_PATH=./logs/error.log

# Environment mode
export NODE_ENV=development  # or production
```

**File Rotation Configuration:**

All implementations MUST implement log rotation to prevent disk space exhaustion:

| Log Type | Max Size | Max Files | Total Disk Usage |
|----------|----------|-----------|------------------|
| Main log | 50 MB | 5 files | ~250 MB max |
| Error log | 10 MB | 3 files | ~30 MB max |
| **Total** | - | - | **~280 MB max** |

**Implementation Requirements:**
- MUST rotate log files when size limit is reached
- MUST keep only the specified number of rotated files
- MUST delete oldest files when max files limit is reached
- SHOULD use platform-appropriate file rotation libraries

**Language-Specific Implementations:**

**TypeScript/JavaScript (Winston):**
```typescript
new winston.transports.File({
  filename: logFilePath,
  maxsize: 50 * 1024 * 1024, // 50MB
  maxFiles: 5,                // Keep 5 files
  tailable: true              // Use rotating file names
})
```

**Python (logging.handlers.RotatingFileHandler):**
```python
from logging.handlers import RotatingFileHandler

handler = RotatingFileHandler(
    filename='logs/dev.log',
    maxBytes=50 * 1024 * 1024,  # 50MB
    backupCount=5                 # Keep 5 backups
)
```

**Go (lumberjack):**
```go
import "gopkg.in/natefinch/lumberjack.v2"

&lumberjack.Logger{
    Filename:   "logs/dev.log",
    MaxSize:    50,    // MB
    MaxBackups: 5,     // files
    MaxAge:     0,     // days (0 = no age limit)
}
```

**Java (Log4j2 RollingFileAppender):**
```xml
<RollingFile name="file" fileName="logs/dev.log"
             filePattern="logs/dev-%i.log.gz">
  <Policies>
    <SizeBasedTriggeringPolicy size="50MB"/>
  </Policies>
  <DefaultRolloverStrategy max="5"/>
</RollingFile>
```

**C# (Serilog FileSizeLimitBytes):**
```csharp
Log.Logger = new LoggerConfiguration()
    .WriteTo.File(
        "logs/dev.log",
        fileSizeLimitBytes: 50 * 1024 * 1024,  // 50MB
        rollOnFileSizeLimit: true,
        retainedFileCountLimit: 5
    )
    .CreateLogger();
```

**PHP (Monolog RotatingFileHandler):**
```php
use Monolog\Handler\RotatingFileHandler;

$handler = new RotatingFileHandler(
    'logs/dev.log',
    5,                          // maxFiles
    Logger::INFO,
    true,                       // bubble
    null,                       // filePermission
    false                       // useLocking
);
$handler->setFilenameFormat('{filename}-{date}', 'Y-m-d');
```

**Rust (tracing-appender):**
```rust
use tracing_appender::rolling::{RollingFileAppender, Rotation};

let file_appender = RollingFileAppender::new(
    Rotation::NEVER,          // Rotation based on size, not time
    "logs",
    "dev.log"
);
// Note: Rust ecosystem may require custom size-based rotation
```

### Example .env File (TypeScript)

```bash
# Service Configuration
OTEL_SERVICE_NAME=sovdev-test-company-lookup-typescript
SERVICE_VERSION=1.0.0

# OTLP Configuration (DevContainer → Host → Kubernetes)
OTEL_EXPORTER_OTLP_LOGS_ENDPOINT=http://host.docker.internal/v1/logs
OTEL_EXPORTER_OTLP_METRICS_ENDPOINT=http://host.docker.internal/v1/metrics
OTEL_EXPORTER_OTLP_TRACES_ENDPOINT=http://host.docker.internal/v1/traces
OTEL_EXPORTER_OTLP_HEADERS=Host=otel.localhost

# Logging Configuration
LOG_TO_CONSOLE=true
LOG_TO_FILE=true
LOG_FILE_PATH=./logs/dev.log
NODE_ENV=development
```

### Example .env File (Python)

```bash
# Service Configuration
OTEL_SERVICE_NAME=sovdev-test-company-lookup-python
SERVICE_VERSION=1.0.0

# OTLP Configuration
OTEL_EXPORTER_OTLP_LOGS_ENDPOINT=http://host.docker.internal/v1/logs
OTEL_EXPORTER_OTLP_METRICS_ENDPOINT=http://host.docker.internal/v1/metrics
OTEL_EXPORTER_OTLP_TRACES_ENDPOINT=http://host.docker.internal/v1/traces
OTEL_EXPORTER_OTLP_HEADERS=Host=otel.localhost

# Logging Configuration
LOG_TO_CONSOLE=true
LOG_TO_FILE=true
LOG_FILE_PATH=./logs/dev.log
```


## Troubleshooting

### DevContainer Issues

**Container not running:**
```bash
# Check Docker is running
docker ps

# Rebuild container
# In VSCode: Cmd/Ctrl+Shift+P → "Dev Containers: Rebuild Container"
```

**Cannot execute commands:**
```bash
pwd  # Should show: /workspace
ls -la /workspace  # Should show project files
```

### Kubernetes Cluster Issues

**Pods not running:**
```bash
# Check pod status
kubectl get pods -n monitoring

# Check pod logs
kubectl logs -n monitoring <pod-name>

# Describe pod for events
kubectl describe pod -n monitoring <pod-name>
```

**Services not accessible:**
```bash
# Check services
kubectl get svc -n monitoring

# Check ingress
kubectl get ingressroute -A
```

**OTLP connection fails:**
```bash
# Test OTLP collector from inside cluster
kubectl run curl-otel-test --image=curlimages/curl --rm -i --restart=Never -n monitoring -- \
  curl -v http://otel-collector-opentelemetry-collector.monitoring.svc.cluster.local:13133/

# Check collector logs
kubectl logs -n monitoring -l app.kubernetes.io/name=opentelemetry-collector --tail=50
```

**Grafana not accessible:**
```bash
# Check Grafana pod
kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana

# Port-forward as alternative
kubectl port-forward -n monitoring svc/grafana 3000:80
open http://localhost:3000
```

### Network Issues

**DevContainer cannot reach host:**
```bash
curl -v http://host.docker.internal/  # Should return Traefik response
```

**Logs not appearing in Loki:**
1. Check OTLP collector is receiving data: `kubectl logs -n monitoring -l app.kubernetes.io/name=opentelemetry-collector`
2. Verify OTLP endpoint in application: `echo $OTEL_EXPORTER_OTLP_LOGS_ENDPOINT`
3. Check OTLP headers: `echo $OTEL_EXPORTER_OTLP_HEADERS`
4. Verify application calls `sovdev_shutdown()` before exit (not `sovdev_flush()`, which never terminates the SDK)

---

## Summary

### Complete Environment Components

1. **DevContainer** - All language runtimes (Node.js, Python, Go, Java, PHP, C#, Rust)
2. **Kubernetes Cluster** - Observability stack (Loki, Prometheus, Tempo, Grafana)
3. **Traefik Ingress** - Routes traffic to services via `*.localhost` domains
4. **OTLP Collector** - Receives telemetry from applications

### Key Connections

```
Application (DevContainer)
    → OTLP over HTTP (host.docker.internal)
        → Traefik Ingress (127.0.0.1:80)
            → OTLP Collector (Kubernetes)
                → Loki (logs) + Prometheus (metrics) + Tempo (traces)
                    → Grafana (visualization)
```

### Development Loop

**For complete development workflow documentation**, see **[09-development-loop.md](./09-development-loop.md)**.

**Quick Reference:**
1. **Edit code** on host (fast file operations)
2. **Run test** in DevContainer (consistent runtimes)
3. **Validate log files FIRST** ⚡ (instant, local, catches 90% of issues)
4. **Validate OTLP backends SECOND** 🔄 (after log files pass, requires wait)

**Key Principle:** Always validate log files before checking OTLP backends - this provides instant feedback and catches most issues without waiting for infrastructure.

This environment ensures **consistent behavior** across all developers and **reliable testing** of all language implementations.

---

**Document Status:** ✅ v1.0.0 COMPLETE
**Last Updated:** 2025-10-27
**Part of:** sovdev-logger specification v1.1.0
