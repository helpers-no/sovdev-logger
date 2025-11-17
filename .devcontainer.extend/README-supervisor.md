# Supervisord Service Management

## Overview

This devcontainer uses **supervisord** to automatically manage critical services that need to run continuously. Services are auto-discovered from metadata and started/restarted automatically.

## Architecture

```
Container Start
    ↓
supervisord starts (via bashrc)
    ↓
Priority 10: Tailscale (CRITICAL - network foundation)
    ↓
Priority 20: script_exporter (provides container metrics)
    ↓
Priority 30: OTel Collectors (send to Grafana via Tailscale)
```

**Key Features:**
- ✅ Auto-start on container launch
- ✅ Auto-restart on crash
- ✅ Dependency management
- ✅ Centralized logging
- ✅ Simple management commands
- ✅ **Smart auto-enable** - services enable themselves on first start

---

## ⚠️ Current Status - Work In Progress

**What Works:**
- ✅ Supervisord installation and setup
- ✅ Auto-discovery of services from metadata
- ✅ Configuration generation from `enabled-services.conf`
- ✅ Dev-setup menu integration
- ✅ `dev-services` management commands
- ✅ Auto-enable on first service start
- ✅ Integration with `project-installs.sh`

**Known Issues:**
- ⚠️ **Complex multi-process services don't work well with supervisor**
  - Example: OTel Monitoring has 3 separate processes (lifecycle, metrics, script_exporter)
  - Start scripts are designed to daemonize and exit, supervisor expects long-running processes
  - Startup orchestration (validation, notifications, verification) is lost when managing processes directly

**What We Tried:**
1. ❌ Using start scripts as supervisor commands - scripts exit immediately, supervisor sees as "failed"
2. ❌ Running start scripts in foreground - would require significant refactoring and lose startup logic
3. ❌ Managing 3 OTel processes separately - loses unified management UX and startup orchestration

**Recommendation:**
- ✅ Use supervisor for **simple single-process services** (e.g., Tailscale when ready)
- ✅ Use **manual start/stop scripts** for complex multi-process services (e.g., OTel Monitoring)
- ✅ Both can auto-start on container restart via `project-installs.sh` or bashrc

**TODO:**
- [ ] Test supervisor with Tailscale (simpler single-process service)
- [ ] Consider alternative approaches for complex services:
  - Create foreground wrapper scripts specifically for supervisor
  - Use supervisor process groups with proper dependency chains
  - Or accept that complex services work better with their own management scripts
- [ ] Document best practices: when to use supervisor vs. manual scripts
- [ ] Consider if systemd would be better fit than supervisor for this use case

**Current Enabled Services:**
- `otel-monitoring` - Currently NOT managed by supervisor (uses manual start/stop scripts)

---

## Setup (One-Time)

### 1. Install Supervisor

Add to `.devcontainer.extend/project-installs.sh` in the `install_project_tools()` function:

```bash
install_project_tools() {
    echo "🛠️ Installing project-specific tools..."

    # Install supervisord for service management
    if ! command -v supervisord >/dev/null 2>&1; then
        bash "$SCRIPT_DIR/../.devcontainer/additions/install-supervisor.sh"
    fi

    # Generate supervisor configs from service metadata
    bash "$SCRIPT_DIR/../.devcontainer/additions/config-supervisor.sh"
}
```

### 2. Rebuild Container

```bash
# Rebuild devcontainer
Dev Containers: Rebuild Container
```

That's it! Services will now auto-start.

---

## How Service Enablement Works

### Auto-Enable on First Start

Services **automatically enable themselves** when you start them for the first time:

```bash
# Start a service manually
bash .devcontainer/additions/start-otel-monitoring.sh

# Output:
# ✅ OTel Monitoring started
# ✅ Auto-enabled 'OTel Monitoring' for container restart
# ℹ️  Disable with: dev-services disable otel-monitoring
```

The service is now added to `.devcontainer.extend/enabled-services.conf` and will auto-start on future container restarts.

### Manual Control

You can also manually enable/disable services:

```bash
# Enable a service for auto-start
dev-services enable otel-monitoring

# Disable auto-start (service keeps running)
dev-services disable otel-monitoring

# List all enabled services
dev-services list-enabled
```

### Enabled Services Configuration

The file `.devcontainer.extend/enabled-services.conf` lists which services auto-start:

```
# Enabled Services for Auto-Start
tailscale
otel-monitoring
```

**You can edit this file directly** if you prefer, then regenerate configs:

```bash
bash .devcontainer/additions/config-supervisor.sh
```

### Service Selection

Only services listed in `enabled-services.conf` are configured for auto-start. This allows you to:

- ✅ Have many services available in `.devcontainer/additions/`
- ✅ Only auto-start the ones this project needs
- ✅ Easily enable/disable services per project

---

## Adding New Services

To add a service that auto-starts, add metadata to your start script and include auto-enable:

```bash
#!/bin/bash
# File: .devcontainer/additions/start-myservice.sh

#------------------------------------------------------------------------------
# SERVICE METADATA
#------------------------------------------------------------------------------

SERVICE_NAME="My Service"
SERVICE_DESCRIPTION="What this service does"
SERVICE_CATEGORY="INFRA_CONFIG"
CHECK_RUNNING_COMMAND="pgrep -f 'myservice' >/dev/null 2>&1"

# Supervisord metadata
SERVICE_COMMAND="/path/to/start-myservice.sh"
SERVICE_PRIORITY="40"  # Higher = starts later
SERVICE_DEPENDS="tailscale"  # Optional: comma-separated dependencies
SERVICE_AUTO_RESTART="true"  # Auto-restart on crash

#------------------------------------------------------------------------------

set -euo pipefail

# Source auto-enable library
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
source "${SCRIPT_DIR}/lib/service-auto-enable.sh"

# ... your service implementation ...

main() {
    echo "Starting My Service..."
    # ... your startup logic ...
    echo "My Service started successfully"
}

# Run main and auto-enable on success
if main "$@"; then
    auto_enable_service "my-service" "My Service"
fi
```

**The service will auto-enable itself on first successful start.**

To manually regenerate supervisor configs:

```bash
bash .devcontainer/additions/config-supervisor.sh
```

---

## Service Priority Guidelines

| Priority | Purpose | Examples |
|----------|---------|----------|
| 10 | Critical network infrastructure | Tailscale |
| 20 | Core services (no network needed) | script_exporter |
| 30 | Services needing network | OTel Collectors |
| 40+ | Application services | LLM tools, APIs |

**Rule:** Lower number = starts first

---

## Management Commands

### Check Status

```bash
dev-services status

# Output:
# tailscaled                 RUNNING   pid 1234, uptime 1:23:45
# otel-monitoring            RUNNING   pid 1235, uptime 1:23:40
```

### Restart a Service

```bash
dev-services restart tailscaled
dev-services restart otel-monitoring
```

### View Logs

```bash
dev-services logs tailscaled
dev-services logs otel-monitoring
```

### Start/Stop Individual Services

```bash
dev-services stop otel-monitoring
dev-services start otel-monitoring
```

### Enable/Disable Auto-Start

```bash
# Enable a service for auto-start
dev-services enable otel-monitoring

# Disable auto-start (service keeps running until stopped)
dev-services disable otel-monitoring

# List all enabled services
dev-services list-enabled
```

---

## Current Services

### Tailscale (Priority 10)
- **Critical**: Provides network connectivity to Grafana, LLM services
- **Location**: `/workspace/.devcontainer/additions/start-tailscale.sh`
- **Install**: `/workspace/.devcontainer/additions/install-tailscale.sh`
- **Depends on**: Nothing (starts first)
- **Log**: `/var/log/supervisor/tailscale.log`

### OTel Monitoring (Priority 30)
- **Purpose**: Sends metrics/logs to Grafana via Tailscale
- **Location**: `/workspace/.devcontainer/additions/start-otel-monitoring.sh`
- **Depends on**: `tailscaled`
- **Logs**:
  - `/var/log/supervisor/otel-monitoring.log`
  - `/var/log/otelcol-lifecycle.log`
  - `/var/log/otelcol-metrics.log`

---

## Troubleshooting

### Service Won't Start

```bash
# Check supervisor status
dev-services status

# Check service logs
dev-services logs <service-name>

# Check supervisor main log
sudo tail -f /var/log/supervisor/supervisord.log
```

### Regenerate Configs

If you change service metadata:

```bash
bash .devcontainer/additions/config-supervisor.sh
```

### Restart All Services

```bash
# Restart supervisor (restarts all services)
sudo supervisorctl restart all
```

### Check Dependencies

```bash
# View generated config
cat /etc/supervisor/conf.d/auto-*.conf
```

---

## How It Works

1. **Container Creation**:
   - `project-installs.sh` installs supervisord
   - Generates configs from service metadata in `enabled-services.conf`
   - Adds bashrc hook to start supervisor

2. **Container Start**:
   - First shell → bashrc runs
   - Supervisor starts if not running
   - Supervisor reads configs and starts services in priority order
   - Only services listed in `enabled-services.conf` are started

3. **First Service Start** (manual):
   - Developer runs: `bash start-myservice.sh`
   - Service starts successfully
   - Auto-enable function adds service to `enabled-services.conf`
   - Regenerates supervisor config
   - Next container restart → service auto-starts

4. **Service Crashes**:
   - Supervisor detects crash
   - Waits 5 seconds
   - Restarts service automatically
   - Logs restart to `/var/log/supervisor/`

5. **Dependency Handling**:
   - Waits for dependencies to be in RUNNING state
   - Starts services in correct order
   - Example: OTel waits for Tailscale

---

## Advanced Configuration

### Disable Auto-Restart for a Service

```bash
# In service metadata:
SERVICE_AUTO_RESTART="unexpected"  # Only restart on unexpected exit
# or
SERVICE_AUTO_RESTART="false"  # Never restart
```

### Custom Startup Wait Time

Supervisor waits 5 seconds by default to consider a service "started". To customize, manually edit:

```bash
sudo nano /etc/supervisor/conf.d/auto-<service>.conf

# Add:
startsecs=10  # Wait 10 seconds before considering started
```

### Resource Limits

```bash
# In generated config file:
sudo nano /etc/supervisor/conf.d/auto-<service>.conf

# Add:
environment=GOMAXPROCS=2  # Limit to 2 CPU cores
```

---

## Uninstalling

To remove supervisord:

```bash
bash /workspace/.devcontainer/additions/install-supervisor.sh --uninstall
```

---

## Files

```
.devcontainer/
├── additions/
│   ├── install-supervisor.sh         # Install supervisord
│   ├── config-supervisor.sh          # Auto-generates configs
│   ├── start-tailscale.sh            # Tailscale service
│   ├── start-otel-monitoring.sh      # OTel service
│   └── lib/
│       └── service-auto-enable.sh    # Auto-enable library
│
.devcontainer.extend/
├── project-installs.sh               # Calls supervisor setup
├── enabled-services.conf             # Services to auto-start
└── README-supervisor.md              # This file
```

---

**Last Updated**: 2025-11-17
