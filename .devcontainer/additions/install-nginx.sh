#!/bin/bash
# file: .devcontainer/additions/install-nginx.sh
#
# DESCRIPTION: Install and configure nginx as reverse proxy for LiteLLM
# PURPOSE: Handle Host header injection for Claude Code
#
# Usage: ./install-nginx.sh [options]
#
# Options:
#   --debug     : Enable debug output for troubleshooting
#   --uninstall : Remove installed components instead of installing them
#   --force     : Force installation/uninstallation even if there are dependencies
#
#------------------------------------------------------------------------------
# CONFIGURATION - Modify this section for each new script
#------------------------------------------------------------------------------

# Script metadata - Required for dev-setup.sh menu discovery
SCRIPT_NAME="Nginx Reverse Proxy"
SCRIPT_DESCRIPTION="Install nginx as reverse proxy for Claude Code → LiteLLM with Host header injection"
SCRIPT_CATEGORY="INFRA_CONFIG"
CHECK_INSTALLED_COMMAND="command -v nginx >/dev/null 2>&1"

#------------------------------------------------------------------------------

# Source auto-enable library for automatic addition to enabled-tools.conf
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/tool-auto-enable.sh"

# Source logging library for automatic logging to /tmp/devcontainer-install/
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/logging.sh"

#------------------------------------------------------------------------------
# INSTALLATION FUNCTIONS
#------------------------------------------------------------------------------

# Before running installation, we need to configure nginx
pre_installation_setup() {
    if [ "${UNINSTALL_MODE}" -eq 1 ]; then
        echo "🔧 Preparing for nginx uninstallation..."

        # Stop nginx if running
        if command -v nginx >/dev/null 2>&1; then
            echo "→ Stopping nginx service..."
            sudo service nginx stop 2>/dev/null || true
        fi
    else
        echo "🔧 Performing pre-installation setup for nginx..."
        # Note: nginx.conf will be installed by nginx-light package
        # Note: Proxy configs will be generated from templates by start-nginx.sh
        echo "ℹ️  nginx.conf will be provided by nginx-light package"
        echo "ℹ️  Proxy configurations will be generated from templates on first start"
    fi
}

# Define system packages
SYSTEM_PACKAGES=(
    nginx-light
)

# No additional packages needed
NODE_PACKAGES=()
PYTHON_PACKAGES=()
PWSH_MODULES=()

# Define VS Code extensions
declare -A EXTENSIONS

# Define verification commands to run after installation
VERIFY_COMMANDS=(
    "nginx -v 2>&1 | head -1"
)

# Post-installation notes
post_installation_message() {
    if [ "${UNINSTALL_MODE}" -eq 1 ]; then
        return
    fi

    echo
    echo "🎉 Installation process complete for: $SCRIPT_NAME!"
    echo "Purpose: $SCRIPT_DESCRIPTION"
    echo

    # Remove default site (nginx-light installs one)
    if [ -f /etc/nginx/sites-enabled/default ]; then
        echo "→ Removing default nginx site..."
        sudo rm -f /etc/nginx/sites-enabled/default
    fi

    echo
    echo "Next steps:"
    echo "1. Configure backend: bash /workspace/.devcontainer/additions/config-nginx.sh"
    echo "2. Start nginx: bash /workspace/.devcontainer/additions/start-nginx.sh"
    echo "   (or nginx will auto-start via supervisord on next rebuild)"
    echo
    echo "Architecture:"
    echo "  Claude Code → http://localhost:8080 → nginx → Traefik → LiteLLM"
    echo "  OTEL Collector → http://localhost:8081 → nginx → Traefik → K8s OTel"
    echo
}

# Post-uninstallation notes
post_uninstallation_message() {
    echo
    echo "🏁 Uninstallation process complete for: $SCRIPT_NAME!"
    echo
    echo "Additional cleanup performed:"
    echo "1. Removed nginx configuration files"
    echo "2. Stopped nginx service"
    echo

    # Cleanup configuration files (both old and new formats)
    echo "→ Cleaning up nginx configuration..."
    sudo rm -f /etc/nginx/sites-available/litellm-proxy.conf
    sudo rm -f /etc/nginx/sites-enabled/litellm-proxy.conf
    sudo rm -f /etc/nginx/sites-available/otel-proxy.conf
    sudo rm -f /etc/nginx/sites-enabled/otel-proxy.conf
    # Old format (if any)
    sudo rm -f /etc/nginx/sites-available/litellm-proxy
    sudo rm -f /etc/nginx/sites-enabled/litellm-proxy

    # Check if nginx is still installed
    if command -v nginx >/dev/null; then
        echo
        echo "⚠️  Note: nginx binary is still installed (system package)"
        echo "   Run 'sudo apt-get remove nginx-light' to completely remove"
    fi
}

#------------------------------------------------------------------------------
# STANDARD SCRIPT LOGIC - Do not modify anything below this line
#------------------------------------------------------------------------------

# Initialize mode flags
DEBUG_MODE=0
UNINSTALL_MODE=0
FORCE_MODE=0

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --debug)
            DEBUG_MODE=1
            shift
            ;;
        --uninstall)
            UNINSTALL_MODE=1
            shift
            ;;
        --force)
            FORCE_MODE=1
            shift
            ;;
        *)
            echo "ERROR: Unknown option: $1" >&2
            echo "Usage: $0 [--debug] [--uninstall] [--force]" >&2
            echo "Description: $SCRIPT_DESCRIPTION"
            exit 1
            ;;
    esac
done

# Export mode flags for core scripts
export DEBUG_MODE
export UNINSTALL_MODE
export FORCE_MODE

# Source all core installation scripts
source "${SCRIPT_DIR}/lib/core-install-apt.sh"
source "${SCRIPT_DIR}/lib/core-install-node.sh"
source "${SCRIPT_DIR}/lib/core-install-extensions.sh"
source "${SCRIPT_DIR}/lib/core-install-pwsh.sh"
source "${SCRIPT_DIR}/lib/core-install-python-packages.sh"

# Source common installation patterns library
source "${SCRIPT_DIR}/lib/install-common.sh"

# Function to process installations
process_installations() {
    # Process each type of package if array is not empty
    if [ ${#SYSTEM_PACKAGES[@]} -gt 0 ]; then
        process_system_packages "SYSTEM_PACKAGES"
    fi

    if [ ${#NODE_PACKAGES[@]} -gt 0 ]; then
        process_node_packages "NODE_PACKAGES"
    fi

    if [ ${#PYTHON_PACKAGES[@]} -gt 0 ]; then
        process_python_packages "PYTHON_PACKAGES"
    fi

    if [ ${#PWSH_MODULES[@]} -gt 0 ]; then
        process_pwsh_modules "PWSH_MODULES"
    fi

    if [ ${#EXTENSIONS[@]} -gt 0 ]; then
        process_extensions "EXTENSIONS"
    fi
}

# Function to verify installations
# Note: Using common implementation from lib/install-common.sh (sourced above)
# No local definition needed - library function is used directly

# Main execution
if [ "${UNINSTALL_MODE}" -eq 1 ]; then
    echo "🔄 Starting uninstallation process for: $SCRIPT_NAME"
    echo "Purpose: $SCRIPT_DESCRIPTION"
    pre_installation_setup
    process_installations
    if [ ${#EXTENSIONS[@]} -gt 0 ]; then
        for ext_id in "${!EXTENSIONS[@]}"; do
            IFS='|' read -r name description _ <<< "${EXTENSIONS[$ext_id]}"
            check_extension_state "$ext_id" "uninstall" "$name"
        done
    fi
    post_uninstallation_message
else
    echo "🔄 Starting installation process for: $SCRIPT_NAME"
    echo "Purpose: $SCRIPT_DESCRIPTION"
    pre_installation_setup
    process_installations
    verify_installations
    if [ ${#EXTENSIONS[@]} -gt 0 ]; then
        for ext_id in "${!EXTENSIONS[@]}"; do
            IFS='|' read -r name description _ <<< "${EXTENSIONS[$ext_id]}"
            check_extension_state "$ext_id" "install" "$name"
        done
    fi
    post_installation_message

    # Auto-enable this tool for container rebuild
    TOOL_ID=$(echo "$SCRIPT_NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
    auto_enable_tool "$TOOL_ID" "$SCRIPT_NAME"
fi
