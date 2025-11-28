#!/bin/bash
# file: .devcontainer/additions/install-srv-otel-monitoring.sh
#
# Install OpenTelemetry Collector for devcontainer monitoring when connected to our network.
# For usage information, run: ./install-srv-otel-monitoring.sh --help
#
#------------------------------------------------------------------------------
# CONFIGURATION - Modify this section for each new script
#------------------------------------------------------------------------------

# Script metadata - must be at the very top of the configuration section
SCRIPT_NAME="OpenTelemetry Monitoring"
SCRIPT_ID="srv-otel"
SCRIPT_DESCRIPTION="Install OpenTelemetry Collector for devcontainer monitoring when connected to our network"
SCRIPT_CATEGORY="INFRA_CONFIG"
CHECK_INSTALLED_COMMAND="([ -f /usr/bin/otelcol-contrib ] || command -v otelcol-contrib >/dev/null 2>&1) && ([ -f /usr/local/bin/script_exporter ] || command -v script_exporter >/dev/null 2>&1)"

# Optional: Custom usage text for --help
SCRIPT_USAGE="  $(basename "$0")              # Install OpenTelemetry Collector
  $(basename "$0") --help       # Show this help
  $(basename "$0") --uninstall  # Uninstall OpenTelemetry Collector
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

# Custom OpenTelemetry Collector installation function
install_otel_collector() {
    if [ "${UNINSTALL_MODE}" -eq 1 ]; then
        echo "=Ñ  Removing OpenTelemetry Collector..."

        # Stop and disable services
        sudo systemctl stop otelcol-contrib 2>/dev/null || true
        sudo systemctl disable otelcol-contrib 2>/dev/null || true

        # Remove binaries
        sudo rm -f /usr/bin/otelcol-contrib
        sudo rm -f /usr/local/bin/script_exporter

        # Remove configuration directories
        if [ -d "/etc/otelcol-contrib" ]; then
            sudo rm -rf /etc/otelcol-contrib
            echo " OpenTelemetry Collector configuration removed"
        fi

        return
    fi

    # Check if otelcol-contrib is already installed
    if command -v otelcol-contrib >/dev/null 2>&1; then
        echo " OpenTelemetry Collector is already installed"
        return
    fi

    echo "=æ Installing OpenTelemetry Collector..."

    # Install otelcol-contrib via curl
    # This is a placeholder - actual installation would depend on the specific method used
    # The user likely has custom installation scripts in .devcontainer/additions/
    echo "   Custom installation required - see .devcontainer/additions/ for setup scripts"
}

# Before running installation, we need to add any required repositories or setup
pre_installation_setup() {
    if [ "${UNINSTALL_MODE}" -eq 1 ]; then
        echo "=' Preparing for uninstallation..."
    else
        echo "=' Performing pre-installation setup..."

        # Check prerequisites
        if [ -f "${SCRIPT_DIR}/config-devcontainer-identity.sh" ]; then
            echo " Found prerequisite: config-devcontainer-identity.sh"
        else
            echo "   Prerequisite missing: config-devcontainer-identity.sh"
        fi

        if [ -f "${SCRIPT_DIR}/config-nginx.sh" ]; then
            echo " Found prerequisite: config-nginx.sh"
        else
            echo "   Prerequisite missing: config-nginx.sh"
        fi

        # Check if OpenTelemetry Collector is already installed
        if command -v otelcol-contrib >/dev/null 2>&1; then
            echo " OpenTelemetry Collector is already installed"
        fi

        # Update package lists
        sudo apt-get update -qq
    fi
}

# Define package arrays (remove any empty arrays that aren't needed)
PACKAGES_SYSTEM=(
    "curl"
    "ca-certificates"
)

PACKAGES_NODE=()

PACKAGES_PYTHON=()

# Define VS Code extensions (format: "Name (extension-id) - Description")
EXTENSIONS=()

# Define verification commands
VERIFY_COMMANDS=(
    "command -v otelcol-contrib >/dev/null && echo ' OpenTelemetry Collector is available' || echo '   OpenTelemetry Collector not found'"
    "command -v script_exporter >/dev/null && echo ' Script exporter is available' || echo '   Script exporter not found'"
    "test -d /etc/otelcol-contrib && echo ' OpenTelemetry Collector configuration directory exists' || echo '   Configuration directory not found'"
)

# Post-installation notes
post_installation_message() {

    echo
    echo "<‰ Installation process complete for: $SCRIPT_NAME!"
    echo "Purpose: $SCRIPT_DESCRIPTION"
    echo
    echo "Important Notes:"
    echo "1. OpenTelemetry Collector requires custom installation"
    echo "2. Prerequisites: config-devcontainer-identity.sh, config-nginx.sh"
    echo "3. See .devcontainer/additions/ for setup scripts"
    echo "4. Configuration files should be in /etc/otelcol-contrib/"
    echo
    echo "Quick Start:"
    echo "- Check installation: otelcol-contrib --version"
    echo "- Check script exporter: script_exporter --version"
    echo "- Start service: sudo systemctl start otelcol-contrib"
    echo "- Check status: sudo systemctl status otelcol-contrib"
    echo
    echo "Documentation Links:"
    echo "- OpenTelemetry Collector: https://opentelemetry.io/docs/collector/"
    echo "- OpenTelemetry Contrib: https://github.com/open-telemetry/opentelemetry-collector-contrib"
}

# Post-uninstallation notes
post_uninstallation_message() {

    # Remove from auto-enable config
    auto_disable_tool
    echo
    echo "<Á Uninstallation process complete for: $SCRIPT_NAME!"
    echo
    echo "Additional Notes:"
    echo "1. OpenTelemetry Collector has been removed"
    echo "2. Configuration files in /etc/otelcol-contrib/ have been removed"
    echo "3. Services have been stopped and disabled"
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
    # Custom OpenTelemetry Collector installation first
    install_otel_collector

    # Then use standard processing from lib/install-common.sh
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
