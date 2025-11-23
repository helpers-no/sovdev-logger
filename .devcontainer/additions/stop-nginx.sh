#!/bin/bash
# File: .devcontainer/additions/stop-nginx.sh
#
# DESCRIPTION: Stop nginx reverse proxy service
# PURPOSE: Gracefully stops nginx reverse proxy
#
# Usage: bash .devcontainer/additions/stop-nginx.sh
#
#------------------------------------------------------------------------------
# SERVICE METADATA - For dev-setup.sh service management integration
#------------------------------------------------------------------------------

SERVICE_NAME="Nginx Reverse Proxy"
SERVICE_DESCRIPTION="Stop nginx reverse proxy for LiteLLM"
SERVICE_CATEGORY="INFRA_CONFIG"

#------------------------------------------------------------------------------

set -euo pipefail

# Source logging library
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/logging.sh"

#------------------------------------------------------------------------------
# STOP NGINX
#------------------------------------------------------------------------------

stop_nginx() {
    log_info "Stopping nginx reverse proxy..."

    if ! pgrep -x nginx >/dev/null 2>&1; then
        log_info "Nginx is not running"
        return 0
    fi

    # Try graceful shutdown first
    if sudo nginx -s quit 2>/dev/null; then
        log_success "Nginx stopped gracefully"
        return 0
    fi

    # Force kill if graceful shutdown fails
    log_warning "Graceful shutdown failed, forcing stop..."
    if sudo pkill -9 nginx 2>/dev/null; then
        log_success "Nginx stopped (forced)"
        return 0
    fi

    log_error "Failed to stop nginx"
    return 1
}

#------------------------------------------------------------------------------
# MAIN
#------------------------------------------------------------------------------

main() {
    echo ""
    log_info "=========================================="
    log_info "Stopping Nginx Reverse Proxy"
    log_info "=========================================="
    echo ""

    stop_nginx

    echo ""
    log_success "Nginx reverse proxy stopped"
    echo ""
}

main "$@"
