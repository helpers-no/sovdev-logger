#!/bin/bash
# Supervisord wrapper for script_exporter
# This script runs in the FOREGROUND so supervisord can manage it

set -e

# Paths
SCRIPT_EXPORTER_CONFIG="/workspace/.devcontainer/additions/otel/script-exporter-config.yaml"

# Check if script_exporter is installed
if ! command -v script_exporter >/dev/null 2>&1; then
    echo "ERROR: script_exporter not found"
    echo "Run: bash .devcontainer/additions/install-otel-monitoring.sh"
    exit 1
fi

# Check if config exists
if [ ! -f "$SCRIPT_EXPORTER_CONFIG" ]; then
    echo "ERROR: Config file not found: $SCRIPT_EXPORTER_CONFIG"
    exit 1
fi

# Run script_exporter in FOREGROUND (no nohup, no &)
echo "Starting script_exporter..."
exec script_exporter --config.files="$SCRIPT_EXPORTER_CONFIG"
