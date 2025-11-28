#!/bin/bash
# file: .devcontainer/additions/install-tool-azure.sh
#
# Installs Azure CLI and Azure VS Code extensions for comprehensive Azure cloud development.
# For usage information, run: ./install-tool-azure.sh --help
#
#------------------------------------------------------------------------------
# CONFIGURATION - Modify this section for each new script
#------------------------------------------------------------------------------

# Script metadata - must be at the very top of the configuration section
SCRIPT_NAME="Azure Development Tools"
SCRIPT_ID="tool-azure"
SCRIPT_DESCRIPTION="Installs Azure CLI and Azure VS Code extensions for comprehensive Azure cloud development"
SCRIPT_CATEGORY="CLOUD_TOOLS"
CHECK_INSTALLED_COMMAND="[ -f /usr/bin/az ] || [ -f /usr/local/bin/az ] || command -v az >/dev/null 2>&1"

# Optional: Custom usage text for --help
SCRIPT_USAGE="  $(basename "$0")              # Install Azure development tools
  $(basename "$0") --help       # Show this help
  $(basename "$0") --uninstall  # Uninstall Azure tools
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

# Custom Azure CLI installation function
install_azure_cli() {
    if [ "${UNINSTALL_MODE}" -eq 1 ]; then
        echo "=Ñ  Removing Azure CLI..."

        # Remove Azure CLI package
        sudo apt-get remove -y azure-cli >/dev/null 2>&1 || true

        # Remove Microsoft repository
        if [ -f "/etc/apt/sources.list.d/azure-cli.list" ]; then
            sudo rm -f "/etc/apt/sources.list.d/azure-cli.list"
            echo " Azure CLI repository removed"
        fi

        # Remove GPG key
        if [ -f "/etc/apt/trusted.gpg.d/microsoft.asc.gpg" ]; then
            sudo rm -f "/etc/apt/trusted.gpg.d/microsoft.asc.gpg"
            echo " Microsoft GPG key removed"
        fi

        return
    fi

    # Check if Azure CLI is already installed
    if command -v az >/dev/null 2>&1; then
        local current_version=$(az version --output json 2>/dev/null | grep -o '"azure-cli": "[^"]*"' | cut -d'"' -f4)
        echo " Azure CLI is already installed (version: ${current_version})"
        return
    fi

    echo "=æ Installing Azure CLI via Microsoft repository..."

    # Install prerequisites
    sudo apt-get install -y ca-certificates curl apt-transport-https lsb-release gnupg >/dev/null 2>&1

    # Download and install Microsoft signing key
    curl -sL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/microsoft.asc.gpg > /dev/null

    # Add Azure CLI repository
    echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/azure-cli.list

    # Update package lists
    sudo apt-get update -qq

    # Install Azure CLI
    if sudo DEBIAN_FRONTEND=noninteractive apt-get install -y azure-cli; then
        echo " Azure CLI installed successfully"
    else
        echo "L Failed to install Azure CLI"
        return 1
    fi

    # Verify installation
    if command -v az >/dev/null 2>&1; then
        local version=$(az version --output json 2>/dev/null | grep -o '"azure-cli": "[^"]*"' | cut -d'"' -f4)
        echo " Azure CLI is now available (version: ${version})"
    else
        echo "L Azure CLI installation failed - not found in PATH"
        return 1
    fi
}

# Before running installation, we need to add any required repositories or setup
pre_installation_setup() {
    if [ "${UNINSTALL_MODE}" -eq 1 ]; then
        echo "=' Preparing for uninstallation..."
    else
        echo "=' Performing pre-installation setup..."

        # Check if Azure CLI is already installed
        if command -v az >/dev/null 2>&1; then
            echo " Azure CLI is already installed"
        fi

        # Update package lists
        sudo apt-get update -qq
    fi
}

# Define package arrays (remove any empty arrays that aren't needed)
PACKAGES_SYSTEM=(
    "ca-certificates"
    "curl"
    "apt-transport-https"
    "lsb-release"
    "gnupg"
)

PACKAGES_NODE=()

PACKAGES_PYTHON=()

# Define VS Code extensions (format: "Name (extension-id) - Description")
EXTENSIONS=(
    "Azure Account (ms-vscode.azure-account) - Azure account management"
    "Azure Resources (ms-azuretools.vscode-azureresourcegroups) - View and manage Azure resources"
    "Azure App Service (ms-azuretools.vscode-azureappservice) - Deploy to Azure App Service"
    "Azure Functions (ms-azuretools.vscode-azurefunctions) - Create and deploy Azure Functions"
    "Azure Storage (ms-azuretools.vscode-azurestorage) - Manage Azure Storage accounts"
)

# Define verification commands
VERIFY_COMMANDS=(
    "command -v az >/dev/null && az version --output json | head -10 || echo 'L Azure CLI not found'"
    "az account list-locations --output table --query '[0:3]' 2>/dev/null || echo '9  Not logged in to Azure (run: az login)'"
)

# Post-installation notes
post_installation_message() {

    echo
    echo "<‰ Installation process complete for: $SCRIPT_NAME!"
    echo "Purpose: $SCRIPT_DESCRIPTION"
    echo
    echo "Important Notes:"
    echo "1. Azure CLI has been installed"
    echo "2. Azure VS Code extensions are available for cloud development"
    echo "3. You need to login to Azure to use Azure CLI"
    echo
    echo "Quick Start:"
    echo "- Check installation: az version"
    echo "- Login to Azure: az login"
    echo "- List subscriptions: az account list --output table"
    echo "- Set subscription: az account set --subscription <subscription-id>"
    echo "- List resources: az resource list --output table"
    echo
    echo "Documentation Links:"
    echo "- Azure CLI Documentation: https://docs.microsoft.com/en-us/cli/azure/"
    echo "- Azure CLI Reference: https://docs.microsoft.com/en-us/cli/azure/reference-index"
    echo "- Azure VS Code Extensions: https://marketplace.visualstudio.com/azuretools"
}

# Post-uninstallation notes
post_uninstallation_message() {

    # Remove from auto-enable config
    auto_disable_tool
    echo
    echo "<Á Uninstallation process complete for: $SCRIPT_NAME!"
    echo
    echo "Additional Notes:"
    echo "1. Azure CLI has been removed"
    echo "2. Azure CLI repository has been removed"
    echo "3. Microsoft GPG key has been removed"
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
    # Custom Azure CLI installation first
    install_azure_cli

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
