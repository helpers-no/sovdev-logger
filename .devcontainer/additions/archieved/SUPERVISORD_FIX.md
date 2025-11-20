# Supervisord OTel Monitoring Fix

## Problem

The OTel monitoring service keeps failing with:
```
otel-monitoring    FATAL     Exited too quickly (process log may have details)
```

## Root Cause

The original `start-otel-monitoring.sh` script was designed to:
1. Run validation checks
2. Start services in the **background** with `nohup ... &`
3. Exit after starting

**This doesn't work with supervisord!** Supervisord expects a **foreground process** that keeps running. When the script exits after starting background processes, supervisord thinks the service crashed.

## Solution

Created three wrapper scripts that run the actual services in the foreground:

1. **`supervisor-wrappers/otel-lifecycle-wrapper.sh`** - Runs lifecycle collector
2. **`supervisor-wrappers/otel-metrics-wrapper.sh`** - Runs metrics collector  
3. **`supervisor-wrappers/script-exporter-wrapper.sh`** - Runs script_exporter

Plus a configuration script: **`start-otel-monitoring-supervisor.sh`**

## How to Fix

### Option 1: Run the new configuration script (Easiest)

```bash
# 1. Make the new script executable
chmod +x .devcontainer/additions/start-otel-monitoring-supervisor.sh
chmod +x .devcontainer/additions/supervisor-wrappers/*.sh

# 2. Run the configuration script
bash .devcontainer/additions/start-otel-monitoring-supervisor.sh

# 3. Check status
dev-services status
```

This will:
- Generate proper supervisord configuration with 3 separate programs
- Use the wrapper scripts that run in foreground
- Set up dependencies (lifecycle and metrics depend on script-exporter)

### Option 2: Manual fix

If you want to manually update the configuration:

```bash
# 1. Remove the old auto-generated config
sudo rm -f /etc/supervisor/conf.d/auto-otel-monitoring.conf

# 2. Make wrappers executable
chmod +x .devcontainer/additions/supervisor-wrappers/*.sh

# 3. Run the supervisor config script
bash .devcontainer/additions/start-otel-monitoring-supervisor.sh

# 4. Reload supervisor
sudo supervisorctl reread
sudo supervisorctl update

# 5. Check status
dev-services status
```

## Verification

After applying the fix, you should see:

```bash
$ dev-services status
script-exporter              RUNNING   pid 1234, uptime 0:00:15
otel-lifecycle               RUNNING   pid 1235, uptime 0:00:15
otel-metrics                 RUNNING   pid 1236, uptime 0:00:15
```

## View Logs

```bash
# Individual service logs
dev-services logs script-exporter
dev-services logs otel-lifecycle
dev-services logs otel-metrics

# Or directly
tail -f /var/log/supervisor/otel-lifecycle.log
tail -f /var/log/supervisor/otel-metrics.log
tail -f /var/log/supervisor/script-exporter.log
```

## What Changed

### Before (Broken)
```bash
# The script ran services in background and exited
nohup otelcol-contrib --config=... >> log.txt 2>&1 &
exit 0  # <-- supervisord sees this as a crash!
```

### After (Fixed)
```bash
# Wrapper runs the service in foreground
exec otelcol-contrib --config=...  # <-- stays running, supervisord is happy
```

## Architecture

The new setup creates a **supervisord group** with 3 programs:

```
[group:otel-monitoring]
├── [program:script-exporter]      (priority 30)
├── [program:otel-lifecycle]       (priority 31, depends on script-exporter)
└── [program:otel-metrics]         (priority 32, depends on script-exporter)
```

## Environment Variables

The wrappers automatically load environment variables from:
- `~/.devcontainer-identity`

Required variables:
- `DEVELOPER_ID`
- `DEVELOPER_EMAIL`
- `PROJECT_NAME`
- `TS_HOSTNAME` (auto-generated if missing)

## Troubleshooting

### Services still failing?

Check the error logs:
```bash
sudo cat /var/log/supervisor/otel-lifecycle-error.log
sudo cat /var/log/supervisor/otel-metrics-error.log
sudo cat /var/log/supervisor/script-exporter-error.log
```

Common issues:
1. **Missing identity**: Run `bash .devcontainer/additions/config-devcontainer-identity.sh`
2. **Missing binaries**: Run `bash .devcontainer/additions/install-otel-monitoring.sh`
3. **Missing config files**: Check that the YAML configs exist in `.devcontainer/additions/otel/`

### Restart individual services

```bash
# Restart just one service
dev-services restart otel-lifecycle

# Restart all OTel services
dev-services restart otel-monitoring:*

# Stop all OTel services
dev-services stop otel-monitoring:*
```

## Integration with config-supervisor.sh

The new setup **bypasses** the auto-discovery in `config-supervisor.sh` because it manually creates the supervisor configuration. This is intentional since OTel monitoring needs:
- Multiple programs in a group
- Dependencies between programs
- Environment variable passing

If you want to re-enable auto-discovery later, you would need to modify `config-supervisor.sh` to handle group configurations.

## Migration Path

If you want to keep both scripts working:

1. **Keep `start-otel-monitoring.sh`** for manual/interactive use
2. **Use `start-otel-monitoring-supervisor.sh`** for supervisord integration

The wrapper scripts work for both approaches.
