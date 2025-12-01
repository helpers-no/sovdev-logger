#!/bin/bash
# file: .devcontainer/additions/install-tool-azure.sh
#
# Installs Azure CLI, Azure Functions Core Tools, Azurite storage emulator,
# and Azure VS Code extensions for comprehensive Azure cloud development.
# For usage information, run: ./install-tool-azure.sh --help
#
#------------------------------------------------------------------------------
# CONFIGURATION - Modify this section for each new script
#------------------------------------------------------------------------------

# --- Script Metadata ---
SCRIPT_ID="tool-azure"
SCRIPT_NAME="Azure Development Tools"
SCRIPT_DESCRIPTION="Installs Azure CLI, Azure Functions Core Tools, Azurite storage emulator, and VS Code extensions for Azure development"
SCRIPT_CATEGORY="CLOUD_TOOLS"
CHECK_INSTALLED_COMMAND="[ -f /usr/bin/az ] || [ -f /usr/local/bin/az ] || command -v az >/dev/null 2>&1"

# Custom usage text for --help
SCRIPT_USAGE="  $(basename "$0")              # Install Azure development tools
  $(basename "$0") --help       # Show this help
  $(basename "$0") --uninstall  # Uninstall Azure tools
  $(basename "$0") --debug      # Install with debug output"

# System packages
PACKAGES_SYSTEM=(
    "azure-cli"  # Installed from Microsoft APT repository
)

# Node.js packages (cross-platform: works on x86_64 and ARM64)
PACKAGES_NODE=(
    "azure-functions-core-tools@4"  # Azure Functions runtime v4 (latest)
    "azurite"  # Azure Storage emulator for local development
)

# VS Code extensions
EXTENSIONS=(
    "Azure Account (ms-vscode.azure-account) - Azure account management"
    "Azure Resources (ms-azuretools.vscode-azureresourcegroups) - View and manage Azure resources"
    "Azure App Service (ms-azuretools.vscode-azureappservice) - Deploy to Azure App Service"
    "Azure Functions (ms-azuretools.vscode-azurefunctions) - Create and deploy Azure Functions"
    "Azure Storage (ms-azuretools.vscode-azurestorage) - Manage Azure Storage accounts"
)

#------------------------------------------------------------------------------

# Source auto-enable library
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/tool-auto-enable.sh"

# Source logging library
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/logging.sh"

#------------------------------------------------------------------------------

# --- Pre-installation/Uninstallation Setup ---
pre_installation_setup() {
    if [ "${UNINSTALL_MODE}" -eq 1 ]; then
        echo "🔧 Preparing for uninstallation..."
    else
        echo "🔧 Performing pre-installation setup..."

        # Add Azure CLI repository before package installation
        add_azure_cli_repository
    fi
}

# --- Add Azure CLI Repository ---
add_azure_cli_repository() {
    echo "➕ Adding Azure CLI repository..."

    local keyring_dir="/etc/apt/keyrings"
    local keyring_file="$keyring_dir/microsoft-azure-cli.gpg"
    local repo_file="/etc/apt/sources.list.d/azure-cli.list"

    # Check if repository already configured
    if [ -f "$repo_file" ] && grep -q "packages.microsoft.com/repos/azure-cli" "$repo_file" 2>/dev/null; then
        echo "✅ Azure CLI repository already configured"
        sudo apt-get update -y > /dev/null 2>&1
        return
    fi

    # Create keyrings directory if needed
    sudo mkdir -p "$keyring_dir"

    # Download and install Microsoft signing key
    curl -sL https://packages.microsoft.com/keys/microsoft.asc | \
        sudo gpg --dearmor -o "$keyring_file"

    # Add Azure CLI repository
    local distro_codename=$(lsb_release -cs)
    echo "deb [arch=amd64 signed-by=$keyring_file] https://packages.microsoft.com/repos/azure-cli/ ${distro_codename} main" | \
        sudo tee "$repo_file"

    # Update package lists
    sudo apt-get update -y > /dev/null 2>&1
    echo "✅ Azure CLI repository added successfully"
}

# --- Post-installation/Uninstallation Messages ---
post_installation_message() {
    echo
    echo "🎉 Installation complete!"
    echo
    echo "Quick start commands:"
    echo "  - Check Azure CLI:       az version"
    echo "  - Login to Azure:        az login"
    echo "  - List subscriptions:    az account list --output table"
    echo "  - Create Azure Function: func new"
    echo "  - Start Azurite:         azurite"
    echo
    echo "Note: Multi-language support for Azure Functions:"
    echo "  - C#:         func init --worker-runtime dotnet"
    echo "  - Python:     func init --worker-runtime python"
    echo "  - TypeScript: func init --worker-runtime node"
    echo "  - Java:       func init --worker-runtime java"
    echo
    echo "Docs: https://docs.microsoft.com/cli/azure/"
    echo "      https://learn.microsoft.com/azure/azure-functions/"
    echo
}

post_uninstallation_message() {
    echo
    echo "🏁 Uninstallation complete!"
    echo
}

#------------------------------------------------------------------------------
# ARGUMENT PARSING
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

# Export mode flags
export DEBUG_MODE
export UNINSTALL_MODE
export FORCE_MODE

#------------------------------------------------------------------------------
# SOURCE CORE SCRIPTS
#------------------------------------------------------------------------------

# Source core installation scripts
source "${SCRIPT_DIR}/lib/core-install-system.sh"
source "${SCRIPT_DIR}/lib/core-install-node.sh"
source "${SCRIPT_DIR}/lib/core-install-extensions.sh"

#------------------------------------------------------------------------------
# HELPER FUNCTIONS
#------------------------------------------------------------------------------

# Function to process installations
process_installations() {
    # Use standard processing from lib/install-common.sh
    process_standard_installations
}

#------------------------------------------------------------------------------
# MAIN EXECUTION
#------------------------------------------------------------------------------

if [ "${UNINSTALL_MODE}" -eq 1 ]; then
    echo "🔄 Starting uninstallation process for: $SCRIPT_NAME"
    echo "Purpose: $SCRIPT_DESCRIPTION"
    pre_installation_setup
    process_installations
    post_uninstallation_message

    # Remove from auto-enable config
    auto_disable_tool
else
    echo "🔄 Starting installation process for: $SCRIPT_NAME"
    echo "Purpose: $SCRIPT_DESCRIPTION"
    pre_installation_setup
    process_installations
    post_installation_message

    # Auto-enable for container rebuild
    auto_enable_tool
fi

echo "✅ Script execution finished."
exit 0
