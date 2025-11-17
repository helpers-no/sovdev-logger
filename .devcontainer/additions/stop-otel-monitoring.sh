#!/bin/bash
# file: .devcontainer/additions/stop-otel-monitoring.sh
#
# DESCRIPTION: Stop all OpenTelemetry monitoring services
# PURPOSE: Gracefully stops both OTel collectors and script_exporter
#
# Usage: bash .devcontainer/additions/stop-otel-monitoring.sh
#
#------------------------------------------------------------------------------
# SERVICE METADATA - For dev-setup.sh service management integration
#------------------------------------------------------------------------------

SERVICE_NAME="OTel Monitoring"
SERVICE_DESCRIPTION="Start devcontainer monitoring services when connected to our network"
SERVICE_CATEGORY="INFRA_CONFIG"

#------------------------------------------------------------------------------

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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
# SHUTDOWN NOTIFICATION
#------------------------------------------------------------------------------

send_shutdown_notification() {
    # Get script directory to locate the centralized notification script
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    # Call centralized notification script
    bash "${script_dir}/otel/scripts/send-event-notification.sh" \
        --event-type "monitoring.stopped" \
        --message "Devcontainer monitoring stopped" \
        --wait-for-flush \
        2>&1 | while IFS= read -r line; do
            # Reformat output to match our logging style
            if [[ "$line" == *"✅"* ]]; then
                log_success "${line#*✅ }"
            elif [[ "$line" == *"ℹ️"* ]]; then
                log_info "${line#*ℹ️  }"
            elif [[ "$line" == *"❌"* ]]; then
                log_warn "${line#*❌ }"
            fi
        done
}

#------------------------------------------------------------------------------
# STOP FUNCTIONS
#------------------------------------------------------------------------------

stop_lifecycle_collector() {
    log_info "Stopping Lifecycle Collector (port 4318)..."

    # Check if collector is running
    if ! pgrep -f 'otelcol-contrib.*otelcol-lifecycle-config.yaml' >/dev/null 2>&1; then
        log_info "Lifecycle Collector is not running"
        echo ""
        return 0
    fi

    # Send shutdown notification before stopping
    send_shutdown_notification

    # Get PID for informational purposes
    local pid
    pid=$(pgrep -f 'otelcol-contrib.*otelcol-lifecycle-config.yaml' | head -1)

    log_info "Found Lifecycle Collector process (PID: $pid)"
    log_info "Sending SIGTERM for graceful shutdown..."

    # Try graceful shutdown first (SIGTERM)
    if pkill -TERM -f 'otelcol-contrib.*otelcol-lifecycle-config.yaml'; then
        # Wait up to 5 seconds for graceful shutdown
        local count=0
        while [ $count -lt 5 ]; do
            if ! pgrep -f 'otelcol-contrib.*otelcol-lifecycle-config.yaml' >/dev/null 2>&1; then
                log_success "Lifecycle collector stopped gracefully"
                echo ""
                return 0
            fi
            sleep 1
            count=$((count + 1))
        done

        # If still running, force kill
        log_warn "Graceful shutdown timed out, forcing..."
        if pkill -9 -f 'otelcol-contrib.*otelcol-lifecycle-config.yaml'; then
            sleep 1
            if ! pgrep -f 'otelcol-contrib.*otelcol-lifecycle-config.yaml' >/dev/null 2>&1; then
                log_success "Lifecycle collector stopped (forced)"
                echo ""
                return 0
            fi
        fi
    fi

    # Check if still running
    if pgrep -f 'otelcol-contrib.*otelcol-lifecycle-config.yaml' >/dev/null 2>&1; then
        log_error "Failed to stop main collector"
        echo ""
        echo "Try manually:"
        echo "  sudo pkill -9 -f 'otelcol-contrib.*otelcol-lifecycle-config.yaml'"
        echo ""
        return 1
    fi
}

stop_metrics_collector() {
    log_info "Stopping metrics collector..."

    if pgrep -f "otelcol-contrib.*otelcol-metrics-config" >/dev/null 2>&1; then
        local pid
        pid=$(pgrep -f "otelcol-contrib.*otelcol-metrics-config" | head -1)
        log_info "Found metrics collector process (PID: $pid)"

        if pkill -TERM -f "otelcol-contrib.*otelcol-metrics-config"; then
            # Wait for graceful shutdown
            sleep 2
            if ! pgrep -f "otelcol-contrib.*otelcol-metrics-config" >/dev/null 2>&1; then
                log_success "Metrics collector stopped"
            else
                # Force kill if still running
                pkill -9 -f "otelcol-contrib.*otelcol-metrics-config"
                log_success "Metrics collector stopped (forced)"
            fi
            return 0
        else
            log_warn "Failed to stop metrics collector"
            return 1
        fi
    else
        log_info "Metrics collector not running"
        return 0
    fi
}

stop_script_exporter() {
    log_info "Stopping script_exporter..."

    if pgrep -f "script_exporter.*--config" >/dev/null 2>&1; then
        local pid
        pid=$(pgrep -f "script_exporter.*--config" | head -1)
        log_info "Found script_exporter process (PID: $pid)"

        if pkill -TERM -f "script_exporter.*--config"; then
            sleep 1
            if ! pgrep -f "script_exporter.*--config" >/dev/null 2>&1; then
                log_success "script_exporter stopped"
            else
                pkill -9 -f "script_exporter.*--config"
                log_success "script_exporter stopped (forced)"
            fi
            return 0
        else
            log_warn "Failed to stop script_exporter"
            return 1
        fi
    else
        log_info "script_exporter not running"
        return 0
    fi
}

show_status() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📊 Status"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "To start again:"
    echo "  bash .devcontainer/additions/start-otel-monitoring.sh"
    echo ""
    echo "To view logs:"
    echo "  tail -50 /var/log/otelcol.log"
    echo "  tail -50 /var/log/otelcol-metrics.log"
    echo ""
    echo "To uninstall completely:"
    echo "  bash .devcontainer/additions/install-otel-monitoring.sh --uninstall"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

#------------------------------------------------------------------------------
# MAIN
#------------------------------------------------------------------------------

main() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🛑 Stopping OpenTelemetry Monitoring Services"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    local failed=0

    # Stop lifecycle collector (includes shutdown notification)
    if ! stop_lifecycle_collector; then
        failed=1
    fi

    echo ""

    # Stop metrics collector
    if ! stop_metrics_collector; then
        failed=1
    fi

    echo ""

    # Stop script_exporter
    if ! stop_script_exporter; then
        failed=1
    fi

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    if [ $failed -eq 0 ]; then
        echo "✅ All Monitoring Services Stopped"
    else
        echo "⚠️  Some Services Failed to Stop (check manually)"
    fi
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    show_status

    log_success "Done"
    echo ""

    return $failed
}

# Run main function
main "$@"
