#!/bin/bash
# File: .devcontainer/additions/start-nginx.sh
#
# Usage: /workspace/.devcontainer/additions/start-nginx.sh
# Purpose:
#   Starts nginx reverse proxy for LiteLLM Host header injection
#   Proxies Claude Code requests to Traefik/LiteLLM with proper headers
#
# Author: Terje Christensen
# Created: November 2024
#

#------------------------------------------------------------------------------
# SERVICE METADATA - For supervisord auto-start
#------------------------------------------------------------------------------

SERVICE_NAME="Nginx Reverse Proxy"
SERVICE_DESCRIPTION="Nginx reverse proxy for LiteLLM (adds Host header)"
SERVICE_CATEGORY="INFRA_CONFIG"
CHECK_RUNNING_COMMAND="pgrep -x nginx >/dev/null 2>&1 && curl -s http://localhost:8080/nginx-health >/dev/null 2>&1"

# Supervisord metadata
SERVICE_COMMAND="/workspace/.devcontainer/additions/start-nginx.sh"
SERVICE_PRIORITY="20"
SERVICE_DEPENDS=""
SERVICE_AUTO_RESTART="true"

#------------------------------------------------------------------------------

set -euo pipefail

# Source logging library
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/logging.sh"

# Source auto-enable library
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/service-auto-enable.sh"

#------------------------------------------------------------------------------
# Configuration
#------------------------------------------------------------------------------

# Config file locations
NGINX_CONFIG_FILE="$HOME/.nginx-backend-config"
NGINX_LITELLM_TEMPLATE="${SCRIPT_DIR}/nginx/litellm-proxy.conf.template"
NGINX_LITELLM_CONFIG="/etc/nginx/sites-available/litellm-proxy.conf"

# Default values (used if not configured)
DEFAULT_BACKEND_URL="http://host.docker.internal"
DEFAULT_LITELLM_PORT="8080"

#------------------------------------------------------------------------------
# Functions
#------------------------------------------------------------------------------

load_backend_config() {
    # Check if config file exists
    if [ -f "$NGINX_CONFIG_FILE" ]; then
        log_info "Loading backend configuration from $NGINX_CONFIG_FILE"
        # shellcheck source=/dev/null
        source "$NGINX_CONFIG_FILE"
        log_success "Backend configured: $BACKEND_TYPE ($BACKEND_URL)"
    else
        log_warning "No backend configuration found, using defaults"
        log_info "Run 'bash ${SCRIPT_DIR}/config-nginx.sh' to configure backend"
        BACKEND_URL="$DEFAULT_BACKEND_URL"
        BACKEND_TYPE="docker-internal-default"
        NGINX_LITELLM_PORT="$DEFAULT_LITELLM_PORT"
    fi
}

generate_nginx_config() {
    log_info "Generating nginx configuration from template..."

    # Check if template exists
    if [ ! -f "$NGINX_LITELLM_TEMPLATE" ]; then
        log_error "Template not found: $NGINX_LITELLM_TEMPLATE"
        return 1
    fi

    # Generate config from template (replace placeholders)
    sudo sed -e "s|BACKEND_URL|${BACKEND_URL}|g" \
             -e "s|NGINX_LITELLM_PORT|${NGINX_LITELLM_PORT}|g" \
             "$NGINX_LITELLM_TEMPLATE" | \
        sudo tee "$NGINX_LITELLM_CONFIG" >/dev/null

    log_success "Configuration generated with backend: $BACKEND_URL (port: $NGINX_LITELLM_PORT)"
    return 0
}

check_nginx_installed() {
    if ! command -v nginx >/dev/null 2>&1; then
        log_error "Nginx is not installed"
        log_info "Run: bash ${SCRIPT_DIR}/install-nginx.sh"
        return 1
    fi
    return 0
}

check_nginx_config() {
    log_info "Checking nginx configuration..."
    if ! sudo nginx -t 2>&1 | grep -q "syntax is ok"; then
        log_error "Nginx configuration has errors"
        sudo nginx -t
        return 1
    fi
    log_success "Nginx configuration is valid"
    return 0
}

stop_nginx() {
    log_info "Stopping nginx if running..."
    if pgrep -x nginx >/dev/null 2>&1; then
        sudo nginx -s quit 2>/dev/null || sudo pkill -9 nginx || true
        sleep 2
    fi
}

start_nginx() {
    log_info "Starting nginx..."

    # Start nginx in foreground mode (required for supervisor)
    exec sudo nginx -g "daemon off;"
}

#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------

main() {
    log_info "=========================================="
    log_info "Starting Nginx Reverse Proxy"
    log_info "=========================================="

    # Check nginx is installed
    if ! check_nginx_installed; then
        exit 1
    fi

    # Load backend configuration
    load_backend_config

    # Generate nginx config from template with configured backend
    if ! generate_nginx_config; then
        exit 1
    fi

    # Validate configuration
    if ! check_nginx_config; then
        exit 1
    fi

    # Stop any existing nginx process
    stop_nginx

    # Start nginx (this will exec and replace this process)
    log_info "Starting nginx in foreground mode..."
    start_nginx

    # This line will never be reached due to exec
    exit 0
}

# Run main function
main "$@"
