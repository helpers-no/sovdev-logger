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
CHECK_RUNNING_COMMAND="sudo supervisorctl status nginx-reverse-proxy 2>/dev/null | grep -q RUNNING"

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
# Try multiple locations for config file (handle different environments)
if [ -f "$HOME/.nginx-backend-config" ]; then
    NGINX_CONFIG_FILE="$HOME/.nginx-backend-config"
elif [ -f "/home/vscode/.nginx-backend-config" ]; then
    NGINX_CONFIG_FILE="/home/vscode/.nginx-backend-config"
elif [ -f "/workspace/topsecret/nginx-config/.nginx-backend-config" ]; then
    NGINX_CONFIG_FILE="/workspace/topsecret/nginx-config/.nginx-backend-config"
else
    NGINX_CONFIG_FILE=""
fi

NGINX_LITELLM_TEMPLATE="${SCRIPT_DIR}/nginx/litellm-proxy.conf.template"
NGINX_LITELLM_CONFIG="/etc/nginx/sites-available/litellm-proxy.conf"

# Default values (used if not configured)
DEFAULT_BACKEND_URL="http://host.docker.internal"
DEFAULT_LITELLM_PORT="8080"

#------------------------------------------------------------------------------
# Functions
#------------------------------------------------------------------------------

load_backend_config() {
    # Check if config file exists and is not empty
    if [ -n "$NGINX_CONFIG_FILE" ] && [ -f "$NGINX_CONFIG_FILE" ]; then
        log_info "Loading backend configuration from $NGINX_CONFIG_FILE"
        # shellcheck source=/dev/null
        source "$NGINX_CONFIG_FILE"
        log_success "Backend configured: $BACKEND_TYPE ($BACKEND_URL)"
        log_info "LiteLLM port: $NGINX_LITELLM_PORT, OTEL port: ${NGINX_OTEL_PORT:-not set}"
    else
        log_warning "No backend configuration found, using defaults"
        log_info "Run 'bash ${SCRIPT_DIR}/config-nginx.sh' to configure backend"
        BACKEND_URL="$DEFAULT_BACKEND_URL"
        BACKEND_TYPE="docker-internal-default"
        NGINX_LITELLM_PORT="$DEFAULT_LITELLM_PORT"
    fi
}

generate_nginx_config() {
    log_info "Generating nginx configurations from templates..."

    # Generate LiteLLM proxy config
    if [ ! -f "$NGINX_LITELLM_TEMPLATE" ]; then
        log_error "LiteLLM template not found: $NGINX_LITELLM_TEMPLATE"
        return 1
    fi

    sudo sed -e "s|BACKEND_URL|${BACKEND_URL}|g" \
             -e "s|NGINX_LITELLM_PORT|${NGINX_LITELLM_PORT}|g" \
             "$NGINX_LITELLM_TEMPLATE" | \
        sudo tee "$NGINX_LITELLM_CONFIG" >/dev/null

    # Enable LiteLLM site
    sudo ln -sf "$NGINX_LITELLM_CONFIG" /etc/nginx/sites-enabled/litellm-proxy.conf 2>/dev/null || true

    log_success "LiteLLM proxy config generated (port: $NGINX_LITELLM_PORT)"

    # Generate OTEL proxy config (if NGINX_OTEL_PORT is set)
    if [ -n "${NGINX_OTEL_PORT:-}" ]; then
        local NGINX_OTEL_TEMPLATE="${SCRIPT_DIR}/nginx/otel-proxy.conf.template"
        local NGINX_OTEL_CONFIG="/etc/nginx/sites-available/otel-proxy.conf"

        if [ -f "$NGINX_OTEL_TEMPLATE" ]; then
            sudo sed -e "s|BACKEND_URL|${BACKEND_URL}|g" \
                     -e "s|NGINX_OTEL_PORT|${NGINX_OTEL_PORT}|g" \
                     "$NGINX_OTEL_TEMPLATE" | \
                sudo tee "$NGINX_OTEL_CONFIG" >/dev/null

            # Enable OTEL site
            sudo ln -sf "$NGINX_OTEL_CONFIG" /etc/nginx/sites-enabled/otel-proxy.conf 2>/dev/null || true

            log_success "OTEL proxy config generated (port: $NGINX_OTEL_PORT)"
        else
            log_warning "OTEL template not found: $NGINX_OTEL_TEMPLATE (skipping)"
        fi
    fi

    # Generate Open WebUI proxy config (if NGINX_OPENWEBUI_PORT is set)
    if [ -n "${NGINX_OPENWEBUI_PORT:-}" ]; then
        local NGINX_OPENWEBUI_TEMPLATE="${SCRIPT_DIR}/nginx/openwebui-proxy.conf.template"
        local NGINX_OPENWEBUI_CONFIG="/etc/nginx/sites-available/openwebui-proxy.conf"

        if [ -f "$NGINX_OPENWEBUI_TEMPLATE" ]; then
            sudo sed -e "s|{{BACKEND_URL}}|${BACKEND_URL}|g" \
                     -e "s|8082|${NGINX_OPENWEBUI_PORT}|g" \
                     "$NGINX_OPENWEBUI_TEMPLATE" | \
                sudo tee "$NGINX_OPENWEBUI_CONFIG" >/dev/null

            # Enable Open WebUI site
            sudo ln -sf "$NGINX_OPENWEBUI_CONFIG" /etc/nginx/sites-enabled/openwebui-proxy.conf 2>/dev/null || true

            log_success "Open WebUI proxy config generated (port: $NGINX_OPENWEBUI_PORT)"
        else
            log_warning "Open WebUI template not found: $NGINX_OPENWEBUI_TEMPLATE (skipping)"
        fi
    fi

    log_success "Backend: $BACKEND_URL"
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
    local nginx_test_output
    nginx_test_output=$(sudo nginx -t 2>&1)
    local nginx_exit_code=$?

    if [ $nginx_exit_code -eq 0 ]; then
        log_success "Nginx configuration is valid"
        return 0
    else
        log_error "Nginx configuration has errors"
        echo "$nginx_test_output"
        return 1
    fi
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
