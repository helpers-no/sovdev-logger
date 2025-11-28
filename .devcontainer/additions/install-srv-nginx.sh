#!/bin/bash
# file: .devcontainer/additions/install-srv-nginx.sh
#
# Install nginx as reverse proxy for Claude Code ’ LiteLLM with Host header injection.
# For usage information, run: ./install-srv-nginx.sh --help
#
#------------------------------------------------------------------------------
# CONFIGURATION - Modify this section for each new script
#------------------------------------------------------------------------------

# Script metadata - must be at the very top of the configuration section
SCRIPT_NAME="Nginx Reverse Proxy"
SCRIPT_ID="srv-nginx"
SCRIPT_DESCRIPTION="Install nginx as reverse proxy for Claude Code ’ LiteLLM with Host header injection"
SCRIPT_CATEGORY="INFRA_CONFIG"
CHECK_INSTALLED_COMMAND="command -v nginx >/dev/null 2>&1"

# Optional: Custom usage text for --help
SCRIPT_USAGE="  $(basename "$0")              # Install nginx
  $(basename "$0") --help       # Show this help
  $(basename "$0") --uninstall  # Uninstall nginx
  $(basename "$0") --debug      # Install with debug output"

#------------------------------------------------------------------------------

# Source auto-enable library
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/tool-auto-enable.sh"

# Source logging library
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/logging.sh"

#------------------------------------------------------------------------------

# Before running installation, we need to add any required repositories or setup
pre_installation_setup() {
    if [ "${UNINSTALL_MODE}" -eq 1 ]; then
        echo "=' Preparing for uninstallation..."
    else
        echo "=' Performing pre-installation setup..."

        # Check if nginx is already installed
        if command -v nginx >/dev/null 2>&1; then
            echo " Nginx is already installed (version: $(nginx -v 2>&1 | cut -d'/' -f2))"
        fi

        # Update package lists
        sudo apt-get update -qq
    fi
}

# Define package arrays (remove any empty arrays that aren't needed)
PACKAGES_SYSTEM=(
    "nginx-light"
)

PACKAGES_NODE=()

PACKAGES_PYTHON=()

# Define VS Code extensions (format: "Name (extension-id) - Description")
EXTENSIONS=()

# Define verification commands
VERIFY_COMMANDS=(
    "command -v nginx >/dev/null && echo ' Nginx binary is available' || echo 'L Nginx binary not found'"
    "nginx -v 2>&1 || echo 'L Nginx version check failed'"
    "test -d /etc/nginx && echo ' Nginx configuration directory exists' || echo 'L Nginx configuration directory not found'"
    "test -f /etc/nginx/nginx.conf && echo ' Nginx main configuration file exists' || echo 'L Nginx configuration file not found'"
)

# Post-installation notes
post_installation_message() {

    echo
    echo "<‰ Installation process complete for: $SCRIPT_NAME!"
    echo "Purpose: $SCRIPT_DESCRIPTION"
    echo
    echo "Important Notes:"
    echo "1. Nginx has been installed as a lightweight reverse proxy"
    echo "2. Configuration files are located in /etc/nginx/"
    echo "3. Use nginx configuration scripts in .devcontainer/additions/ for setup"
    echo
    echo "Quick Start:"
    echo "- Check installation: nginx -v"
    echo "- Check configuration: nginx -t"
    echo "- Start nginx: sudo systemctl start nginx"
    echo "- Stop nginx: sudo systemctl stop nginx"
    echo "- Restart nginx: sudo systemctl restart nginx"
    echo "- Check status: sudo systemctl status nginx"
    echo
    echo "Documentation Links:"
    echo "- Nginx Documentation: https://nginx.org/en/docs/"
    echo "- Nginx Reverse Proxy: https://docs.nginx.com/nginx/admin-guide/web-server/reverse-proxy/"
}

# Post-uninstallation notes
post_uninstallation_message() {

    # Remove from auto-enable config
    auto_disable_tool
    echo
    echo "<Á Uninstallation process complete for: $SCRIPT_NAME!"
    echo
    echo "Additional Notes:"
    echo "1. Nginx has been removed"
    echo "2. Configuration files in /etc/nginx/ may remain"
    echo "3. You can manually remove them with: sudo rm -rf /etc/nginx/"
}

#------------------------------------------------------------------------------
# MAIN SCRIPT EXECUTION - Do not modify below this line
#------------------------------------------------------------------------------

# Initialize mode flags
DEBUG_MODE=0
UNINSTALL_MODE=0
FORCE_MODE=0

# Source common installation patterns library (needed for --help)
source "${SCRIPT_DIR}/lib/install-common.sh"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --help)
            show_script_help
            exit 0
            ;;
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
            echo "Usage: $0 [--help] [--debug] [--uninstall] [--force]" >&2
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
source "${SCRIPT_DIR}/lib/core-install-system.sh"
source "${SCRIPT_DIR}/lib/core-install-node.sh"
source "${SCRIPT_DIR}/lib/core-install-extensions.sh"
source "${SCRIPT_DIR}/lib/core-install-pwsh.sh"
source "${SCRIPT_DIR}/lib/core-install-python.sh"

# Note: lib/install-common.sh already sourced earlier (needed for --help)

# Function to process installations
process_installations() {
    # Process standard installations (packages and extensions)
    process_standard_installations
}



# Main execution
if [ "${UNINSTALL_MODE}" -eq 1 ]; then
    echo "= Starting uninstallation process for: $SCRIPT_NAME"
    echo "Purpose: $SCRIPT_DESCRIPTION"
    pre_installation_setup
    process_installations
    post_uninstallation_message

    # Remove from auto-enable config
    auto_disable_tool
else
    echo "= Starting installation process for: $SCRIPT_NAME"
    echo "Purpose: $SCRIPT_DESCRIPTION"
    pre_installation_setup
    process_installations
    verify_installations
    post_installation_message

    # Auto-enable for container rebuild
    auto_enable_tool
fi
