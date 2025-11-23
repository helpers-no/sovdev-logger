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
CHECK_INSTALLED_COMMAND="command -v nginx >/dev/null && [ -f /etc/nginx/sites-enabled/litellm-proxy ]"

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

        # Create directory structure
        echo "→ Creating configuration directories..."
        sudo mkdir -p /etc/nginx/sites-available
        sudo mkdir -p /etc/nginx/sites-enabled
        sudo mkdir -p /etc/nginx/conf.d

        # Copy configuration files
        echo "→ Installing nginx configuration files..."
        sudo cp "${SCRIPT_DIR}/nginx/nginx.conf" /etc/nginx/nginx.conf
        sudo cp "${SCRIPT_DIR}/nginx/litellm-proxy.conf" /etc/nginx/sites-available/litellm-proxy

        # Enable site
        echo "→ Enabling litellm-proxy site..."
        sudo ln -sf /etc/nginx/sites-available/litellm-proxy /etc/nginx/sites-enabled/litellm-proxy

        # Remove default site if exists
        if [ -f /etc/nginx/sites-enabled/default ]; then
            echo "→ Removing default site..."
            sudo rm /etc/nginx/sites-enabled/default
        fi
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

    # Test nginx configuration
    echo "→ Testing nginx configuration..."
    if sudo nginx -t 2>&1 | grep -q "successful"; then
        echo "✅ Nginx configuration is valid"
    else
        echo "❌ Nginx configuration test failed"
        sudo nginx -t
        return 1
    fi

    # Start nginx
    echo "→ Starting nginx service..."
    if sudo service nginx start 2>&1; then
        echo "✅ Nginx started successfully"
    else
        echo "⚠️  Nginx may already be running or needs manual start"
    fi

    echo
    echo "Testing nginx proxy:"
    echo "  curl http://localhost:8080/nginx-health"
    echo
    echo "Expected response:"
    echo "  'nginx proxy is running'"
    echo
    echo "Architecture:"
    echo "  Claude Code → http://localhost:8080 → nginx → Traefik → LiteLLM"
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

    # Cleanup configuration files
    echo "→ Cleaning up nginx configuration..."
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
source "$(dirname "$0")/core-install-apt.sh"
source "$(dirname "$0")/core-install-node.sh"
source "$(dirname "$0")/core-install-extensions.sh"
source "$(dirname "$0")/core-install-pwsh.sh"
source "$(dirname "$0")/core-install-python-packages.sh"

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
verify_installations() {
    if [ ${#VERIFY_COMMANDS[@]} -gt 0 ]; then
        echo
        echo "🔍 Verifying installations..."
        for cmd in "${VERIFY_COMMANDS[@]}"; do
            echo "Running: $cmd"
            if ! eval "$cmd"; then
                echo "❌ Verification failed for: $cmd"
            fi
        done
    fi
}

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
