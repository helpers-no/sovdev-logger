# Host Platform Monitoring

## Overview

The devcontainer automatically captures host machine information (OS, user, architecture) and includes it in all OpenTelemetry telemetry sent to Grafana. This enables platform visibility and usage analytics.

## What Information is Captured

### Automatically Detected:
- **Operating System**: macOS, Linux, or Windows
- **Username**: From host environment variables
- **CPU Architecture**: arm64 (Apple Silicon/ARM) or amd64 (Intel/AMD)

### Platform-Specific:
- **Hostname**: Available for Windows only (from `COMPUTERNAME` env var)
  - Mac/Linux: Shows "unknown" (hostname not exported as env var by default)
- **Domain**: Available for Windows only (corporate domain tracking)
  - Mac/Linux: Shows "none"

## How It Works

### 1. Container Build Time
Host environment variables are passed into the container via `devcontainer.json`:

```json
"args": {
  "DEV_MAC_USER": "${localEnv:USER}",
  "DEV_LINUX_USER": "${localEnv:USER}",
  "DEV_WIN_USERNAME": "${localEnv:USERNAME}",
  "DEV_WIN_COMPUTERNAME": "${localEnv:COMPUTERNAME}",
  ...
}
```

These become environment variables inside the container via `Dockerfile.base`.

### 2. Container Runtime (Auto-detection)
On container rebuild, `config-host-info.sh` automatically runs (via `project-installs.sh`):

```bash
# Auto-runs in --verify mode (silent)
bash .devcontainer/additions/config-host-info.sh --verify
```

**What it does:**
1. Detects host OS from which environment variables are set
2. Extracts username from environment
3. Detects CPU architecture using `uname -m`
4. Normalizes all values to standard HOST_* variables
5. Saves to persistent file: `/workspace/topsecret/env-vars/.host-info`

**Example output:**
```bash
export HOST_OS="macOS"
export HOST_USER="terje.christensen"
export HOST_HOSTNAME="unknown"
export HOST_DOMAIN="none"
export HOST_CPU_ARCH="arm64"
```

### 3. OTEL Integration
When OTEL collectors start, they source the host-info file:

```bash
# In service-otel-monitoring.sh
source /workspace/topsecret/env-vars/.host-info
```

OTEL configs then include these as resource attributes:

```yaml
processors:
  resource:
    attributes:
      - key: host.os
        value: ${HOST_OS}
        action: upsert
      - key: host.user
        value: ${HOST_USER}
        action: upsert
      # ... etc
```

### 4. Grafana Visualization
All telemetry sent to Grafana includes these labels, enabling queries like:

```promql
# OS distribution
count by (host_os) (system_memory_usage_bytes{service_name="devcontainer-monitor"})

# Architecture split
count by (host_cpu_arch) (system_memory_usage_bytes{service_name="devcontainer-monitor"})

# Filter by user
system_memory_usage_bytes{host_user="terje.christensen"}
```

## Files and Components

### Configuration Scripts
- **`.devcontainer/additions/config-host-info.sh`** - Host detection script
  - Run manually: `bash .devcontainer/additions/config-host-info.sh`
  - Run in verify mode: `bash .devcontainer/additions/config-host-info.sh --verify`
  - Auto-runs on container rebuild

### OTEL Templates
- **`.devcontainer/additions/otel/otelcol-lifecycle-config.yaml.template`** - Template file (committed to git)
- **`.devcontainer/additions/otel/otelcol-metrics-config.yaml.template`** - Template file (committed to git)

**Generated files (NOT committed to git):**
- `.devcontainer/additions/otel/otelcol-lifecycle-config.yaml` - Generated at runtime
- `.devcontainer/additions/otel/otelcol-metrics-config.yaml` - Generated at runtime

> **Important:** The `.yaml` files are generated from `.template` files at runtime with environment variables substituted. Only commit the `.template` files. The generated `.yaml` files will always show as modified in git - this is expected and should NOT be committed.

### Persistent Storage
- **`/workspace/topsecret/env-vars/.host-info`** - Persistent host information
  - Created automatically on container rebuild
  - Sourced by OTEL services
  - Recreated on each rebuild (to detect machine changes)

### Grafana Dashboard
- **`.devcontainer/additions/otel/grafana/host-platform-overview.yaml`** - Kubernetes ConfigMap
  - Dashboard name: "Host Platform Overview"
  - Location in Grafana: Devcontainer folder
  - Shows: OS distribution, architecture split, developer platforms table

## Manual Usage

### Check Host Information
```bash
# View current host information
cat /workspace/topsecret/env-vars/.host-info

# Or use show-environment command
show-environment
```

### Re-detect Host Information
```bash
# Run detection manually (interactive mode)
bash .devcontainer/additions/config-host-info.sh

# Or in silent/verify mode
bash .devcontainer/additions/config-host-info.sh --verify
```

### Check OTEL Status
```bash
# Verify OTEL services have host info
.devcontainer/additions/service-otel-monitoring.sh --status

# View OTEL logs
.devcontainer/additions/service-otel-monitoring.sh --logs
```

## Troubleshooting

### Host info not detected
```bash
# Check if file exists
ls -la /workspace/topsecret/env-vars/.host-info

# Re-run detection
bash .devcontainer/additions/config-host-info.sh

# Check environment variables are set
env | grep "^DEV_"
```

### OTEL not starting
```bash
# Check if HOST_ variables are available
env | grep "^HOST_"

# If empty, source the file manually
source /workspace/topsecret/env-vars/.host-info
env | grep "^HOST_"

# Check OTEL logs for errors
.devcontainer/additions/service-otel-monitoring.sh --logs-lifecycle
.devcontainer/additions/service-otel-monitoring.sh --logs-metrics
```

### Empty domain error
OTEL requires non-empty values. The script uses "none" for empty domains:
- Mac/Linux: `HOST_DOMAIN="none"`
- Windows without domain: `HOST_DOMAIN="none"`
- Windows with domain: `HOST_DOMAIN="corp.example.com"`

## Platform-Specific Notes

### macOS
- ✅ OS detection works
- ✅ Username works
- ✅ Architecture works (arm64 for Apple Silicon)
- ❌ Hostname not available (no env var exported by default)
- ❌ Domain not applicable

### Linux
- ✅ OS detection works
- ✅ Username works
- ✅ Architecture works (typically amd64)
- ❌ Hostname not available (no env var exported by default)
- ❌ Domain not applicable

### Windows
- ✅ OS detection works
- ✅ Username works
- ✅ Architecture works (typically amd64)
- ✅ Hostname works (from COMPUTERNAME env var)
- ✅ Domain works (if domain-joined)

## Privacy and Security

**Information collected:**
- Operating system type (not version details)
- Username (as set in host environment)
- Hostname (Windows only)
- Corporate domain (Windows only)
- CPU architecture type

**Storage:**
- Stored locally in `/workspace/topsecret/env-vars/.host-info`
- Sent to Grafana via OTEL as resource attributes
- No sensitive data or passwords collected

**Persistence:**
- Data is NOT persisted across container rebuilds
- Re-detected fresh on each rebuild
- Useful if developer switches machines

## See Also

- [OTEL Monitoring Setup](./otel-monitoring.md) - OTEL configuration guide
- [Grafana Dashboards](../additions/otel/grafana/) - Dashboard ConfigMaps
- [Environment Variables](./environment-variables.md) - Host env var passing
