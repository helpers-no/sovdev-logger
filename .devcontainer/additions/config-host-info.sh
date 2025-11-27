#!/bin/bash
# File: .devcontainer/additions/config-host-info.sh
# Purpose: Detect and save host machine information for OTEL monitoring
# Usage: bash config-host-info.sh [--verify]

#------------------------------------------------------------------------------
# CONFIG METADATA - For dev-setup.sh integration
#------------------------------------------------------------------------------

CONFIG_NAME="Host Information"
CONFIG_DESCRIPTION="Detect host OS, user, and architecture for telemetry monitoring"
CONFIG_CATEGORY="INFRA_CONFIG"
CHECK_CONFIG_COMMAND="[ -f /workspace/topsecret/env-vars/.host-info ]"

#------------------------------------------------------------------------------

set -e

# Source logging library
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/logging.sh"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }

# Persistent storage paths
PERSISTENT_DIR="/workspace/topsecret/env-vars"
PERSISTENT_FILE="$PERSISTENT_DIR/.host-info"

#------------------------------------------------------------------------------
# PERSISTENT STORAGE FUNCTIONS
#------------------------------------------------------------------------------

setup_persistent_storage() {
    mkdir -p "$PERSISTENT_DIR"
}

detect_host_info() {
    log_info "Detecting host information for telemetry..."
    echo ""

    # Detect OS and user from environment variables
    # Note: Hostname only available for Windows (COMPUTERNAME env var)
    # Mac/Linux don't export hostname as env var by default, so we use "unknown"
    if [ -n "$DEV_MAC_USER" ]; then
        export HOST_OS="macOS"
        export HOST_USER="$DEV_MAC_USER"
        export HOST_HOSTNAME="unknown"
        export HOST_DOMAIN="none"
    elif [ -n "$DEV_LINUX_USER" ]; then
        export HOST_OS="Linux"
        export HOST_USER="$DEV_LINUX_USER"
        export HOST_HOSTNAME="unknown"
        export HOST_DOMAIN="none"
    elif [ -n "$DEV_WIN_USERNAME" ]; then
        export HOST_OS="Windows"
        export HOST_USER="$DEV_WIN_USERNAME"
        export HOST_HOSTNAME="${DEV_WIN_COMPUTERNAME:-unknown}"
        export HOST_DOMAIN="${DEV_WIN_USERDOMAIN:-none}"
    else
        export HOST_OS="unknown"
        export HOST_USER="unknown"
        export HOST_HOSTNAME="unknown"
        export HOST_DOMAIN="none"
    fi

    # Get architecture from container (which matches host architecture)
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64)
            export HOST_CPU_ARCH="amd64"
            ;;
        aarch64)
            export HOST_CPU_ARCH="arm64"
            ;;
        armv7l)
            export HOST_CPU_ARCH="arm32"
            ;;
        *)
            export HOST_CPU_ARCH="$ARCH"
            ;;
    esac

    # Save to environment file for persistence
    save_host_info_to_env

    # Display summary
    echo "  OS: $HOST_OS"
    echo "  User: $HOST_USER"
    echo "  Hostname: $HOST_HOSTNAME"
    [ -n "$HOST_DOMAIN" ] && echo "  Domain: $HOST_DOMAIN"
    echo "  Architecture: $HOST_CPU_ARCH"
    echo ""
    log_success "Host information detected"
}

save_host_info_to_env() {
    # Create environment file for host info
    setup_persistent_storage

    cat > "$PERSISTENT_FILE" <<EOF
# Host information - managed by config-host-info.sh
# This file is generated on container creation and sourced for OTEL
export HOST_OS="$HOST_OS"
export HOST_USER="$HOST_USER"
export HOST_HOSTNAME="$HOST_HOSTNAME"
export HOST_DOMAIN="$HOST_DOMAIN"
export HOST_CPU_ARCH="$HOST_CPU_ARCH"
EOF

    chmod 600 "$PERSISTENT_FILE"
}

#------------------------------------------------------------------------------
# VERIFY MODE - Non-interactive validation for container rebuild
#------------------------------------------------------------------------------

verify_host_info() {
    # Silent mode - just detect and save
    setup_persistent_storage

    # Always detect fresh (host info can change if user switches machines)
    # Detect without showing banner
    # Note: Hostname only available for Windows (COMPUTERNAME env var)
    # Mac/Linux don't export hostname as env var by default, so we use "unknown"
    if [ -n "$DEV_MAC_USER" ]; then
        export HOST_OS="macOS"
        export HOST_USER="$DEV_MAC_USER"
        export HOST_HOSTNAME="unknown"
        export HOST_DOMAIN="none"
    elif [ -n "$DEV_LINUX_USER" ]; then
        export HOST_OS="Linux"
        export HOST_USER="$DEV_LINUX_USER"
        export HOST_HOSTNAME="unknown"
        export HOST_DOMAIN="none"
    elif [ -n "$DEV_WIN_USERNAME" ]; then
        export HOST_OS="Windows"
        export HOST_USER="$DEV_WIN_USERNAME"
        export HOST_HOSTNAME="${DEV_WIN_COMPUTERNAME:-unknown}"
        export HOST_DOMAIN="${DEV_WIN_USERDOMAIN:-none}"
    else
        export HOST_OS="unknown"
        export HOST_USER="unknown"
        export HOST_HOSTNAME="unknown"
        export HOST_DOMAIN="none"
    fi

    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64) export HOST_CPU_ARCH="amd64" ;;
        aarch64) export HOST_CPU_ARCH="arm64" ;;
        armv7l) export HOST_CPU_ARCH="arm32" ;;
        *) export HOST_CPU_ARCH="$ARCH" ;;
    esac

    save_host_info_to_env

    return 0
}

#------------------------------------------------------------------------------
# MAIN
#------------------------------------------------------------------------------

main() {
    # Handle --verify flag for non-interactive validation
    if [ "${1:-}" = "--verify" ]; then
        verify_host_info
        exit $?
    fi

    # Interactive mode - show detailed info
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🖥️  Host Information Detection"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    detect_host_info

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_success "Host Information Saved"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "📝 Information stored in: $PERSISTENT_FILE"
    echo "   This will be included in all OTEL telemetry"
    echo ""
}

# Run main
main "$@"
