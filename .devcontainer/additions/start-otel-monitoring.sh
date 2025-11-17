#!/bin/bash
# file: .devcontainer/additions/start-otel-monitoring.sh
#
# DESCRIPTION: Combined startup script for all OpenTelemetry monitoring services
# PURPOSE: Starts both OTel collectors (main + metrics) and script_exporter
#
# Usage: bash .devcontainer/additions/start-otel-monitoring.sh
#
# Requirements:
#   - OTel Collector binary installed (run install-otel-monitoring.sh first)
#   - Identity configuration file: ~/.devcontainer-identity
#
#------------------------------------------------------------------------------
# SERVICE METADATA - For future dev-setup.sh service management integration
#------------------------------------------------------------------------------

SERVICE_NAME="OTel Monitoring"
SERVICE_DESCRIPTION="Start devcontainer monitoring services when connected to our network"
SERVICE_CATEGORY="INFRA_CONFIG"
CHECK_RUNNING_COMMAND="pgrep -f 'otelcol-contrib.*--config' >/dev/null 2>&1"
SERVICE_LOG_PATH_LIFECYCLE="/var/log/otelcol-lifecycle.log"
SERVICE_LOG_PATH_METRICS="/var/log/otelcol-metrics.log"
SERVICE_CONFIG_PATH="$HOME/.devcontainer-identity"

# Supervisord metadata
SERVICE_COMMAND="/workspace/.devcontainer/additions/start-otel-monitoring.sh"
SERVICE_PRIORITY="30"
SERVICE_DEPENDS=""  # No dependencies - can test independently
SERVICE_AUTO_RESTART="true"

#------------------------------------------------------------------------------
# CONFIGURATION
#------------------------------------------------------------------------------

set -euo pipefail

# Source auto-enable library
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/service-auto-enable.sh"

# Paths
OTEL_BINARY="otelcol-contrib"  # Installed via .deb package to /usr/bin/otelcol-contrib
CONFIG_FILE_LIFECYCLE="/workspace/.devcontainer/additions/otel/otelcol-lifecycle-config.yaml"
CONFIG_FILE_METRICS="/workspace/.devcontainer/additions/otel/otelcol-metrics-config.yaml"
LOG_FILE_LIFECYCLE="/var/log/otelcol-lifecycle.log"
LOG_FILE_METRICS="/var/log/otelcol-metrics.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Source identity file automatically if it exists
IDENTITY_FILE="$HOME/.devcontainer-identity"
if [ -f "$IDENTITY_FILE" ]; then
    # shellcheck source=/dev/null
    source "$IDENTITY_FILE"
fi

#------------------------------------------------------------------------------
# HELPER FUNCTIONS
#------------------------------------------------------------------------------

log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warn() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

#------------------------------------------------------------------------------
# VALIDATION FUNCTIONS
#------------------------------------------------------------------------------

check_binary_installed() {
    if ! command -v otelcol-contrib >/dev/null 2>&1; then
        log_error "OTel Collector binary not found"
        echo ""
        echo "Please install it first:"
        echo "  bash .devcontainer/additions/install-otel-monitoring.sh"
        echo ""
        return 1
    fi
    return 0
}

check_config_exists() {
    if [ ! -f "$CONFIG_FILE_LIFECYCLE" ]; then
        log_error "Lifecycle config file not found: $CONFIG_FILE_LIFECYCLE"
        echo ""
        echo "This file should have been created during installation."
        echo "Try reinstalling:"
        echo "  bash .devcontainer/additions/install-otel-monitoring.sh"
        echo ""
        return 1
    fi

    if [ ! -f "$CONFIG_FILE_METRICS" ]; then
        log_error "Metrics config file not found: $CONFIG_FILE_METRICS"
        return 1
    fi

    return 0
}

validate_required_variables() {
    local missing=()

    if [ -z "${DEVELOPER_ID:-}" ]; then
        missing+=("DEVELOPER_ID")
    fi

    if [ -z "${DEVELOPER_EMAIL:-}" ]; then
        missing+=("DEVELOPER_EMAIL")
    fi

    if [ -z "${PROJECT_NAME:-}" ]; then
        missing+=("PROJECT_NAME")
    fi

    if [ ${#missing[@]} -gt 0 ]; then
        log_error "Missing required environment variables"
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "📋 Identity Not Configured"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "Missing environment variables:"
        for var in "${missing[@]}"; do
            echo "  - $var"
        done
        echo ""
        echo "Please run the identity setup script:"
        echo "  bash .devcontainer/additions/config-devcontainer-identity.sh"
        echo ""
        echo "If you've already set up your identity, open a new terminal"
        echo "to load the environment variables."
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        return 1
    fi

    # Generate TS_HOSTNAME if not provided
    if [ -z "${TS_HOSTNAME:-}" ]; then
        TS_HOSTNAME="dev-${DEVELOPER_ID}-${PROJECT_NAME}"
        export TS_HOSTNAME
        log_info "Generated TS_HOSTNAME: $TS_HOSTNAME"
    fi

    log_success "All required variables present"
    return 0
}

check_lifecycle_collector_already_running() {
    if pgrep -f 'otelcol-contrib.*otelcol-lifecycle-config.yaml' >/dev/null 2>&1; then
        local pid
        pid=$(pgrep -f 'otelcol-contrib.*otelcol-lifecycle-config.yaml' | head -1)
        log_warn "Lifecycle Collector is already running (PID: $pid)"
        return 0
    fi
    return 1
}

check_metrics_collector_already_running() {
    if pgrep -f "otelcol-contrib.*otelcol-metrics-config.yaml" >/dev/null 2>&1; then
        local pid
        pid=$(pgrep -f "otelcol-contrib.*otelcol-metrics-config.yaml" | head -1)
        log_warn "Metrics collector is already running (PID: $pid)"
        return 0
    fi
    return 1
}

check_script_exporter_already_running() {
    if pgrep -f "script_exporter" >/dev/null 2>&1; then
        local pid
        pid=$(pgrep -f "script_exporter" | head -1)
        log_warn "script_exporter is already running (PID: $pid)"
        return 0
    fi
    return 1
}

#------------------------------------------------------------------------------
# SERVICE FUNCTIONS - LIFECYCLE COLLECTOR
#------------------------------------------------------------------------------

start_lifecycle_collector() {
    log_info "Starting Lifecycle Collector (port 4318 - lifecycle events)..."

    # Ensure log directory exists
    sudo mkdir -p "$(dirname "$LOG_FILE_LIFECYCLE")"
    sudo touch "$LOG_FILE_LIFECYCLE"
    sudo chmod 666 "$LOG_FILE_LIFECYCLE" 2>/dev/null || true

    # Export env vars so OTel Collector can read them from config
    export DEVELOPER_ID
    export DEVELOPER_EMAIL
    export PROJECT_NAME
    export TS_HOSTNAME

    # Start collector in background
    # Note: OTel Collector will expand ${ENV_VAR} in the config file natively
    nohup "$OTEL_BINARY" --config="$CONFIG_FILE_LIFECYCLE" >> "$LOG_FILE_LIFECYCLE" 2>&1 &
    local pid=$!

    # Wait a moment for startup
    sleep 2

    # Check if process is still running
    if ! kill -0 "$pid" 2>/dev/null; then
        log_error "Lifecycle collector failed to start"
        echo ""
        echo "Check logs for details:"
        echo "  tail -20 $LOG_FILE_LIFECYCLE"
        echo ""
        return 1
    fi

    log_success "Lifecycle collector started successfully (PID: $pid)"
    return 0
}

send_startup_notification() {
    log_info "Sending startup notification to monitoring system..."

    # Wait for collector to be fully ready
    sleep 2

    # Get current timestamp in nanoseconds
    local timestamp_nano
    timestamp_nano=$(date +%s%N)

    # Send structured log through the collector
    # Note: Using underscores in attribute keys to match Loki ingestion format
    local response
    response=$(curl -s -X POST http://localhost:4318/v1/logs \
        -H "Content-Type: application/json" \
        -d "{
            \"resourceLogs\": [{
                \"resource\": {
                    \"attributes\": [
                        {\"key\": \"service.name\", \"value\": {\"stringValue\": \"devcontainer-monitor\"}},
                        {\"key\": \"developer_id\", \"value\": {\"stringValue\": \"${DEVELOPER_ID}\"}},
                        {\"key\": \"developer_email\", \"value\": {\"stringValue\": \"${DEVELOPER_EMAIL}\"}},
                        {\"key\": \"project_name\", \"value\": {\"stringValue\": \"${PROJECT_NAME}\"}},
                        {\"key\": \"host_name\", \"value\": {\"stringValue\": \"${TS_HOSTNAME}\"}}
                    ]
                },
                \"scopeLogs\": [{
                    \"logRecords\": [{
                        \"timeUnixNano\": \"${timestamp_nano}\",
                        \"severityText\": \"INFO\",
                        \"severityNumber\": 9,
                        \"body\": {\"stringValue\": \"Devcontainer monitoring initialized\"},
                        \"attributes\": [
                            {\"key\": \"event_type\", \"value\": {\"stringValue\": \"monitoring.started\"}},
                            {\"key\": \"event_category\", \"value\": {\"stringValue\": \"devcontainer.lifecycle\"}},
                            {\"key\": \"collector_version\", \"value\": {\"stringValue\": \"0.113.0\"}}
                        ]
                    }]
                }]
            }]
        }" 2>&1)

    if echo "$response" | grep -q "partialSuccess"; then
        log_success "Startup notification sent to local collector"
    else
        log_warn "Startup notification may have failed (but collector is running)"
    fi
}

verify_backend_delivery() {
    echo ""
    log_info "Verifying end-to-end delivery to k8s backend..."

    # Step 1: Check for export errors in collector logs
    log_info "Checking collector logs for export errors..."
    sleep 2  # Wait for batch to be sent

    if tail -50 "$LOG_FILE_LIFECYCLE" | grep -qi "error.*export\|failed.*export\|refused\|timeout.*export"; then
        log_warn "Found potential export errors in collector logs"
        echo ""
        echo "Recent export-related messages:"
        tail -50 "$LOG_FILE_LIFECYCLE" | grep -i "export\|error\|failed" | tail -5
        echo ""
        log_warn "Logs may not be reaching k8s backend"
        return 1
    else
        log_success "No export errors detected in collector logs"
    fi

    # Step 2: Try to verify log reached Loki
    log_info "Attempting to verify log delivery to Loki..."
    echo ""
    echo "Waiting 5 seconds for log to reach Loki..."
    sleep 5

    # Check if query-loki.sh exists
    if [ -f "/workspace/specification/tools/query-loki.sh" ]; then
        log_info "Querying Loki for recent startup notification..."

        # Query Loki for our service with SHORT time range to avoid finding old logs
        # Using --time-range 1m to only search the last minute (avoids false positives from previous starts)
        local loki_result
        loki_result=$(/workspace/specification/tools/query-loki.sh "devcontainer-monitor" --limit 5 --time-range 1m 2>&1 | grep -i "initialized\|monitoring.started" || true)

        if [ -n "$loki_result" ]; then
            log_success "Startup notification found in Loki!"
            echo ""
            echo "Log successfully delivered to k8s backend"
            return 0
        else
            log_warn "Startup notification not found in Loki yet"
            echo ""
            echo "This could be normal if:"
            echo "  • Log is still in transit (try checking Grafana in 30 seconds)"
            echo "  • K8s OTel Collector is not running"
            echo "  • Traefik routing is not configured"
            echo ""
            echo "To manually verify, check Grafana/Loki with query:"
            echo "  {service_name=\"devcontainer-monitor\"}"
            return 1
        fi
    else
        log_info "Skipping Loki verification (query script not available)"
        echo ""
        echo "To manually verify delivery, check Grafana/Loki with query:"
        echo "  {service_name=\"devcontainer-monitor\"}"
        echo "  {developer_id=\"${DEVELOPER_ID}\"}"
        return 0
    fi
}

#------------------------------------------------------------------------------
# SERVICE FUNCTIONS - METRICS COLLECTOR
#------------------------------------------------------------------------------

start_metrics_collector() {
    log_info "Starting OTel Metrics Collector (system + cgroup metrics)..."

    # Ensure log directory exists
    sudo mkdir -p "$(dirname "$LOG_FILE_METRICS")"
    sudo touch "$LOG_FILE_METRICS"
    sudo chmod 666 "$LOG_FILE_METRICS" 2>/dev/null || true

    # Export env vars so OTel Collector can read them from config
    export DEVELOPER_ID
    export DEVELOPER_EMAIL
    export PROJECT_NAME
    export TS_HOSTNAME

    # Start collector in background
    nohup "$OTEL_BINARY" --config="$CONFIG_FILE_METRICS" >> "$LOG_FILE_METRICS" 2>&1 &
    local pid=$!

    # Wait a moment for startup
    sleep 3

    # Check if process is still running
    if ! kill -0 "$pid" 2>/dev/null; then
        log_error "Metrics collector failed to start"
        echo ""
        echo "Check logs for details:"
        echo "  tail -20 $LOG_FILE_METRICS"
        echo ""
        return 1
    fi

    log_success "Metrics collector started successfully (PID: $pid)"
    return 0
}

verify_metrics_collection() {
    log_info "Waiting for first metrics collection..."

    # Wait for at least one collection cycle (60s + processing time)
    sleep 65

    log_info "Checking if metrics are being collected..."

    # Check logs for hostmetrics receiver activity
    if grep -q "hostmetrics" "$LOG_FILE_METRICS" 2>/dev/null; then
        log_success "Hostmetrics receiver is active"
    else
        log_warn "Unable to confirm hostmetrics activity from logs"
    fi

    echo ""
    log_info "Metrics should now be flowing to Prometheus with these labels:"
    echo "  - developer_id: $DEVELOPER_ID"
    echo "  - project_name: $PROJECT_NAME"
    echo "  - service.name: devcontainer-monitor"
    echo ""
    echo "Available metrics:"
    echo "  - system_cpu_time_seconds_total"
    echo "  - system_memory_usage_bytes"
    echo "  - system_disk_io_bytes_total"
    echo "  - system_network_io_bytes_total"
    echo "  - container_uptime_seconds"
    echo "  - container_cpu_usage_seconds_total"
}

#------------------------------------------------------------------------------
# SERVICE FUNCTIONS - SCRIPT EXPORTER
#------------------------------------------------------------------------------

start_script_exporter() {
    log_info "Starting script_exporter (container metrics provider)..."

    local SCRIPT_EXPORTER_CONFIG="/workspace/.devcontainer/additions/otel/script-exporter-config.yaml"
    local SCRIPT_EXPORTER_LOG="/var/log/script-exporter.log"

    # Ensure log directory exists
    sudo mkdir -p "$(dirname "$SCRIPT_EXPORTER_LOG")"
    sudo touch "$SCRIPT_EXPORTER_LOG"
    sudo chmod 666 "$SCRIPT_EXPORTER_LOG" 2>/dev/null || true

    # Start script_exporter in background
    nohup script_exporter --config.files="$SCRIPT_EXPORTER_CONFIG" >> "$SCRIPT_EXPORTER_LOG" 2>&1 &
    local pid=$!

    # Wait a moment for startup
    sleep 2

    # Check if process is still running
    if ! kill -0 "$pid" 2>/dev/null; then
        log_error "script_exporter failed to start"
        echo ""
        echo "Check logs for details:"
        echo "  tail -20 $SCRIPT_EXPORTER_LOG"
        echo ""
        return 1
    fi

    log_success "script_exporter started successfully (PID: $pid)"
    return 0
}

verify_script_exporter() {
    log_info "Verifying script_exporter is serving container metrics..."

    # Wait a moment for script_exporter to be ready
    sleep 2

    # Test the cgroup_metrics endpoint
    if curl -s -f "http://localhost:9469/probe?script=cgroup_metrics" >/dev/null 2>&1; then
        log_success "script_exporter is serving container metrics on port 9469"

        # Show a sample of the metrics
        echo ""
        log_info "Container metrics available:"
        curl -s "http://localhost:9469/probe?script=cgroup_metrics" | grep "^# HELP container_" | head -4 | sed 's/^# HELP /  - /'
    else
        log_warn "Unable to verify script_exporter metrics endpoint"
        echo ""
        echo "Try manually:"
        echo "  curl http://localhost:9469/probe?script=cgroup_metrics"
    fi
}

#------------------------------------------------------------------------------
# STATUS DISPLAY
#------------------------------------------------------------------------------

show_final_status() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🎉 All Monitoring Services Started Successfully"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "📊 Identity:"
    echo "   Developer:  $DEVELOPER_ID ($DEVELOPER_EMAIL)"
    echo "   Project:    $PROJECT_NAME"
    echo "   Hostname:   $TS_HOSTNAME"
    echo ""
    echo "📈 Collecting:"
    echo "   Lifecycle Collector (A7 - port 4318):"
    echo "     - Devcontainer lifecycle events"
    echo "     - Monitoring notifications"
    echo "   Script Exporter (A6 - port 9469):"
    echo "     - Container uptime"
    echo "     - Container CPU usage (from cgroup)"
    echo "     - Container memory usage (from cgroup)"
    echo "     - Devcontainer component info"
    echo "   Metrics Collector (A8):"
    echo "     - System CPU usage (per core, per state)"
    echo "     - System memory usage (used, free, cached, etc.)"
    echo "     - System disk I/O (read/write bytes)"
    echo "     - System network I/O (send/receive bytes)"
    echo ""
    echo "📁 Files:"
    echo "   Lifecycle Config:  $CONFIG_FILE_LIFECYCLE"
    echo "   Metrics Config:    $CONFIG_FILE_METRICS"
    echo "   Lifecycle Logs:    $LOG_FILE_LIFECYCLE"
    echo "   Metrics Logs:      $LOG_FILE_METRICS"
    echo "   Script Exp Logs:   /var/log/script-exporter.log"
    echo ""
    echo "📊 View dashboards at: http://grafana.localhost"
    echo "   Navigate to: Dashboards → Devcontainer folder"
    echo ""
    echo "🔧 Management:"
    echo "   View lifecycle logs: tail -f $LOG_FILE_LIFECYCLE"
    echo "   View metrics logs:   tail -f $LOG_FILE_METRICS"
    echo "   View exporter logs:  tail -f /var/log/script-exporter.log"
    echo "   Stop all:            bash .devcontainer/additions/stop-otel-monitoring.sh"
    echo ""
    echo "📡 Telemetry:"
    echo "   Endpoint:   http://host.docker.internal (via otel.localhost)"
    echo "   Status:     Connected to monitoring service"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

cleanup_on_exit() {
    # Note: We intentionally DON'T delete the config files
    # as they contain the runtime configuration for the running collectors
    # They will be cleaned up on next start or container restart
    :
}

#------------------------------------------------------------------------------
# MAIN EXECUTION
#------------------------------------------------------------------------------

main() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🚀 Starting OpenTelemetry Monitoring Services"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Pre-flight checks
    check_binary_installed || exit 1
    check_config_exists || exit 1

    # Check if services already running (idempotent)
    local lifecycle_running=false
    local metrics_running=false
    local script_exporter_running=false

    if check_lifecycle_collector_already_running; then
        lifecycle_running=true
    fi

    if check_metrics_collector_already_running; then
        metrics_running=true
    fi

    if check_script_exporter_already_running; then
        script_exporter_running=true
    fi

    if [ "$lifecycle_running" = true ] && [ "$metrics_running" = true ] && [ "$script_exporter_running" = true ]; then
        echo ""
        echo "All monitoring services are already running"
        echo ""
        echo "To restart the services:"
        echo "  1. Stop: bash .devcontainer/additions/stop-otel-monitoring.sh"
        echo "  2. Start: bash .devcontainer/additions/start-otel-monitoring.sh"
        echo ""
        echo "To view logs:"
        echo "  tail -f $LOG_FILE_LIFECYCLE"
        echo "  tail -f $LOG_FILE_METRICS"
        echo "  tail -f /var/log/script-exporter.log"
        echo ""
        exit 0
    fi

    # Validate environment variables
    validate_required_variables || exit 1

    echo ""

    # Start lifecycle collector if not running
    if [ "$lifecycle_running" = false ]; then
        start_lifecycle_collector || exit 1
        send_startup_notification
        verify_backend_delivery || log_info "Backend verification skipped or incomplete"
    else
        log_info "Lifecycle collector already running, skipping start"
    fi

    echo ""

    # Start script_exporter if not running (MUST start before metrics collector)
    if [ "$script_exporter_running" = false ]; then
        start_script_exporter || exit 1
        verify_script_exporter || log_info "script_exporter verification skipped"
    else
        log_info "script_exporter already running, skipping start"
    fi

    echo ""

    # Start metrics collector if not running
    if [ "$metrics_running" = false ]; then
        start_metrics_collector || exit 1
        verify_metrics_collection || log_info "Metrics verification skipped"
    else
        log_info "Metrics collector already running, skipping start"
    fi

    # Show final status
    show_final_status

    log_success "Setup complete"
    echo ""
}

# Trap cleanup on exit
trap cleanup_on_exit EXIT

# Run main function
if main "$@"; then
    # Auto-enable service for future container starts
    auto_enable_service "otel-monitoring" "OTel Monitoring"
fi
