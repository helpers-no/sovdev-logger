#!/bin/bash
# Supervisord wrapper for OTel Lifecycle Collector
# This script runs in the FOREGROUND so supervisord can manage it

set -e

# Source identity file
if [ -f "$HOME/.devcontainer-identity" ]; then
    # shellcheck source=/dev/null
    source "$HOME/.devcontainer-identity"
fi

# Paths
OTEL_BINARY="otelcol-contrib"
CONFIG_FILE="/workspace/.devcontainer/additions/otel/otelcol-lifecycle-config.yaml"
LOG_FILE="/var/log/otelcol-lifecycle.log"

# Validate required variables
if [ -z "${DEVELOPER_ID:-}" ] || [ -z "${DEVELOPER_EMAIL:-}" ] || [ -z "${PROJECT_NAME:-}" ]; then
    echo "ERROR: Missing required environment variables (DEVELOPER_ID, DEVELOPER_EMAIL, PROJECT_NAME)"
    echo "Run: bash .devcontainer/additions/config-devcontainer-identity.sh"
    exit 1
fi

# Generate TS_HOSTNAME if not provided
if [ -z "${TS_HOSTNAME:-}" ]; then
    TS_HOSTNAME="dev-${DEVELOPER_ID}-${PROJECT_NAME}"
    export TS_HOSTNAME
fi

# Export env vars for OTel Collector
export DEVELOPER_ID
export DEVELOPER_EMAIL
export PROJECT_NAME
export TS_HOSTNAME

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")"

# Check if binary exists
if ! command -v "$OTEL_BINARY" >/dev/null 2>&1; then
    echo "ERROR: $OTEL_BINARY not found"
    echo "Run: bash .devcontainer/additions/install-otel-monitoring.sh"
    exit 1
fi

# Check if config exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERROR: Config file not found: $CONFIG_FILE"
    exit 1
fi

# Run collector in FOREGROUND (no nohup, no &)
echo "Starting OTel Lifecycle Collector..."
exec "$OTEL_BINARY" --config="$CONFIG_FILE"
