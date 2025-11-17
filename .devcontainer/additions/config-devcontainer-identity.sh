#!/bin/bash
# file: .devcontainer/additions/config-devcontainer-identity.sh
#
# DESCRIPTION: Developer onboarding script - sets up identity for devcontainer monitoring
# PURPOSE: Decodes admin-provided identity string and configures environment
#
# Usage: ./config-devcontainer-identity.sh
#
# Interactive script - will prompt for identity string from admin
#
#------------------------------------------------------------------------------
# CONFIGURATION - Metadata for dev-setup.sh discovery
#------------------------------------------------------------------------------

CONFIG_NAME="Developer Identity"
CONFIG_DESCRIPTION="Configure your identity for devcontainer monitoring (required for tracking your activity in Grafana dashboards)"
CONFIG_CATEGORY="INFRA_CONFIG"
CHECK_CONFIGURED_COMMAND="[ -f ~/.devcontainer-identity ] && grep -q '^export DEVELOPER_ID=' ~/.devcontainer-identity"

#------------------------------------------------------------------------------

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Files
IDENTITY_FILE="$HOME/.devcontainer-identity"
BASHRC_FILE="$HOME/.bashrc"

#------------------------------------------------------------------------------
# FUNCTIONS
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

check_if_already_configured() {
    if [ -f "$IDENTITY_FILE" ]; then
        echo ""
        log_warn "Identity already configured!"
        echo ""
        echo "Current configuration:"
        if [ -r "$IDENTITY_FILE" ]; then
            # Source it temporarily to show values
            (
                source "$IDENTITY_FILE" 2>/dev/null
                echo "   Developer ID:    ${DEVELOPER_ID:-<not set>}"
                echo "   Email:           ${DEVELOPER_EMAIL:-<not set>}"
                echo "   Project:         ${PROJECT_NAME:-<not set>}"
            )
        fi
        echo ""
        read -p "Do you want to reconfigure? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo ""
            log_info "Keeping existing configuration"
            exit 0
        fi
        echo ""
        log_info "Reconfiguring identity..."
    fi
}

prompt_for_identity_string() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📋 Enter Identity String"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Paste the base64 string provided by your administrator:"
    echo "(It will be a long string of letters and numbers)"
    echo ""
    read -r IDENTITY_STRING

    # Trim whitespace
    IDENTITY_STRING=$(echo "$IDENTITY_STRING" | tr -d '[:space:]')

    if [ -z "$IDENTITY_STRING" ]; then
        log_error "No identity string provided"
        exit 1
    fi
}

decode_and_validate() {
    log_info "Decoding identity string..."

    # Decode base64
    if ! DECODED=$(echo "$IDENTITY_STRING" | base64 -d 2>/dev/null); then
        log_error "Failed to decode identity string"
        echo ""
        echo "The string may be corrupted or incomplete."
        echo "Please check with your administrator."
        exit 1
    fi

    # Validate it contains expected exports
    if ! echo "$DECODED" | grep -q "DEVELOPER_ID"; then
        log_error "Invalid identity string format"
        echo ""
        echo "The string does not contain valid identity information."
        echo "Please check with your administrator."
        exit 1
    fi

    log_success "Identity string decoded successfully"

    # Extract and display values for confirmation
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📝 Your Identity Configuration:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Source in subshell to extract values for display
    (
        eval "$DECODED"
        echo "   Developer ID:    ${DEVELOPER_ID:-<not set>}"
        echo "   Email:           ${DEVELOPER_EMAIL:-<not set>}"
        echo "   Project:         ${PROJECT_NAME:-<not set>}"
        echo "   Hostname:        ${TS_HOSTNAME:-<not set>}"
    )

    echo ""
    read -p "Does this look correct? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo ""
        log_warn "Setup cancelled"
        echo "Please contact your administrator for a new identity string."
        exit 1
    fi
}

write_identity_file() {
    log_info "Writing identity configuration..."

    # Write decoded identity to file
    echo "$DECODED" > "$IDENTITY_FILE"

    # Set permissions (readable only by user)
    chmod 600 "$IDENTITY_FILE"

    log_success "Identity file created: $IDENTITY_FILE"
}

update_bashrc() {
    log_info "Configuring shell environment..."

    # Check if already configured in .bashrc
    if grep -q "devcontainer-identity" "$BASHRC_FILE" 2>/dev/null; then
        log_info ".bashrc already configured (skipping)"
        return 0
    fi

    # Add source line to .bashrc
    cat >> "$BASHRC_FILE" <<'EOF'

# Devcontainer identity - managed by config-devcontainer-identity.sh
[ -f ~/.devcontainer-identity ] && source ~/.devcontainer-identity
EOF

    log_success ".bashrc updated"
}

load_identity_now() {
    log_info "Loading identity in current session..."

    # Source the identity file
    # shellcheck source=/dev/null
    source "$IDENTITY_FILE"

    log_success "Identity loaded"
}

check_otel_installed() {
    if command -v otelcol-contrib >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

install_otel_collector() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📦 Install Monitoring Service?"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "The OpenTelemetry Collector is not installed yet."
    echo "It's required for devcontainer monitoring."
    echo ""
    read -p "Install it now? (Y/n): " -n 1 -r
    echo

    if [[ $REPLY =~ ^[Nn]$ ]]; then
        echo ""
        log_info "Skipping installation"
        echo ""
        echo "To install later, run:"
        echo "   bash .devcontainer/additions/install-otel-monitoring.sh"
        return 1
    fi

    echo ""
    # Run the install script
    if bash /workspace/.devcontainer/additions/install-otel-monitoring.sh; then
        log_success "OTel Collector installed"
        return 0
    else
        log_error "Installation failed"
        echo ""
        echo "Please contact your administrator or check the logs."
        return 1
    fi
}

start_monitoring() {
    echo ""

    # Check if OTel Collector is installed
    if ! check_otel_installed; then
        # Offer to install it
        if ! install_otel_collector; then
            # User declined or installation failed
            return 0
        fi
    fi

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🚀 Start Monitoring Service?"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Monitoring services when connected to our network."
    echo ""
    read -p "Start monitoring now? (Y/n): " -n 1 -r
    echo

    if [[ $REPLY =~ ^[Nn]$ ]]; then
        echo ""
        log_info "Skipping monitoring start"
        echo ""
        echo "To start monitoring later, run:"
        echo "   bash .devcontainer/additions/start-otel-monitoring.sh"
        return 0
    fi

    echo ""
    # Start the OTel monitoring services (it will inherit env vars from this process)
    if bash /workspace/.devcontainer/additions/start-otel-monitoring.sh; then
        log_success "Monitoring services started"
    else
        log_error "Failed to start monitoring services"
        echo ""
        echo "You can try starting it manually:"
        echo "   bash .devcontainer/additions/start-otel-monitoring.sh"
    fi
}

show_completion() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🎉 Setup Complete!"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    log_success "Your identity is configured"
    log_success "New terminals will automatically load your identity"
    echo ""
    echo "📝 Important - Load Identity in Current Terminal:"
    echo ""
    echo "   Run this command now:"
    echo "   source ~/.devcontainer-identity"
    echo ""
    echo "   Or open a new terminal (identity loads automatically)"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "📋 Additional Info:"
    echo ""
    echo "• Your identity is stored in: ~/.devcontainer-identity"
    echo "  (This file is private to you, not committed to git)"
    echo ""
    echo "• To verify your identity anytime:"
    echo "  echo \$DEVELOPER_ID"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    log_success "You can now start working!"
    echo ""
}

#------------------------------------------------------------------------------
# MAIN
#------------------------------------------------------------------------------

main() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔐 Developer Identity Setup"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "This script will configure your identity for devcontainer monitoring."
    echo ""

    # Check if already configured
    check_if_already_configured

    # Prompt for identity string
    prompt_for_identity_string

    # Decode and validate
    decode_and_validate

    # Write identity file
    write_identity_file

    # Update .bashrc
    update_bashrc

    # Load in current session
    load_identity_now

    # Optionally start monitoring
    start_monitoring

    # Show completion
    show_completion
}

# Run main
main "$@"
