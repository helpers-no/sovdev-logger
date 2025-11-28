#!/bin/bash
# file: .devcontainer/additions/install-azure.sh
#
# Usage: ./install-azure.sh [options]
#
# Options:
#   --debug     : Enable debug output for troubleshooting
#   --uninstall : Remove installed components instead of installing them
#   --force     : Force installation/uninstallation even if there are dependencies
#
#------------------------------------------------------------------------------
# CONFIGURATION - Modify this section for each new script
#------------------------------------------------------------------------------

# Script metadata - must be at the very top of the configuration section
SCRIPT_NAME="Azure Development Tools"
SCRIPT_DESCRIPTION="Installs Azure CLI and all Azure VS Code extensions for comprehensive Azure cloud development"
SCRIPT_CATEGORY="CLOUD_TOOLS"
CHECK_INSTALLED_COMMAND="[ -f /usr/bin/az ] || [ -f /usr/local/bin/az ] || command -v az >/dev/null 2>&1"

#------------------------------------------------------------------------------

# Source auto-enable library
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/tool-auto-enable.sh"

# Source logging library
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/logging.sh"

#------------------------------------------------------------------------------

# Before running installation, we need to add any required repositories
pre_installation_setup() {
    if [ "${UNINSTALL_MODE}" -eq 1 ]; then
        echo "🔧 Preparing for Azure tools uninstallation..."
    else
        echo "🔧 Performing pre-installation setup for Azure tools..."

        # Check if already installed
        if command -v az >/dev/null 2>&1; then
            local current_version=$(az version --output json 2>/dev/null | grep -oP '"azure-cli": "\K[^"]+' || echo "unknown")
            echo "✅ Azure CLI $current_version is already installed"
            echo "ℹ️  Proceeding to extension installation..."
            return 0
        fi

        echo "📦 Installing Azure CLI..."

        # Install using Microsoft's official installation script
        if ! curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash; then
            echo "❌ Failed to install Azure CLI"
            exit 1
        fi

        # Verify installation
        if command -v az >/dev/null 2>&1; then
            echo "✅ Azure CLI installation completed!"
            az version --output json | head -5
        else
            echo "❌ Azure CLI installation failed - az command not found"
            exit 1
        fi
    fi
}

# Define system packages (none needed - Azure CLI installer handles everything)
SYSTEM_PACKAGES=()

# Define VS Code extensions - Complete Azure development suite
declare -A EXTENSIONS
EXTENSIONS["ms-vscode.azure-account"]="Azure Account|Azure account management and subscriptions"
EXTENSIONS["ms-azuretools.vscode-azurecli"]="Azure CLI Tools|Azure CLI IntelliSense and code snippets"
EXTENSIONS["ms-azuretools.vscode-azureresourcegroups"]="Azure Resources|View and manage Azure resources"
EXTENSIONS["ms-azuretools.vscode-azurefunctions"]="Azure Functions|Create, debug, and deploy Azure Functions"
EXTENSIONS["ms-azuretools.vscode-azurestorage"]="Azure Storage|Manage Azure Storage accounts and blobs"
EXTENSIONS["ms-azuretools.azure-dev"]="Azure Developer CLI|Project scaffolding and management"
EXTENSIONS["ms-azuretools.vscode-bicep"]="Bicep|Azure Bicep language support for Infrastructure as Code"

# Define verification commands
VERIFY_COMMANDS=(
    "command -v az >/dev/null && az version --output json | head -10 || echo '❌ Azure CLI not found'"
    "az account list-locations --output table --query '[0:3]' 2>/dev/null || echo 'ℹ️  Not logged in to Azure (run: az login)'"
)

# Post-installation notes
post_installation_message() {
    local az_version

    if command -v az >/dev/null 2>&1; then
        az_version=$(az version --output json 2>/dev/null | grep -oP '"azure-cli": "\K[^"]+' || echo "unknown")
    else
        az_version="not installed"
    fi

    echo
    echo "🎉 Installation process complete for: $SCRIPT_NAME!"
    echo "Purpose: $SCRIPT_DESCRIPTION"
    echo
    echo "Important Notes:"
    echo "1. Azure CLI version: $az_version"
    echo "2. All Azure VS Code extensions have been installed"
    echo "3. Use 'az login' to authenticate with your Azure account"
    echo "4. Use 'az login --use-device-code' for browser-less authentication"
    echo "5. Use 'az account set --subscription <name>' to set active subscription"
    echo
    echo "Quick Start Commands:"
    echo "- Login to Azure:           az login"
    echo "- Login (device code):      az login --use-device-code"
    echo "- List subscriptions:       az account list --output table"
    echo "- Set subscription:         az account set --subscription <name>"
    echo "- List resource groups:     az group list --output table"
    echo "- Get account info:         az account show --output table"
    echo "- Install extensions:       az extension add --name <extension-name>"
    echo "- Update Azure CLI:         az upgrade"
    echo
    echo "VS Code Extensions Installed:"
    echo "- Azure Account:            Authentication and subscription management"
    echo "- Azure CLI Tools:          CLI IntelliSense and snippets"
    echo "- Azure Resources:          Browse and manage Azure resources"
    echo "- Azure Functions:          Develop and deploy serverless functions"
    echo "- Azure Storage:            Work with Azure Storage accounts"
    echo "- Azure Developer CLI:      azd command for project scaffolding"
    echo "- Bicep:                    Infrastructure as Code for Azure"
    echo
    echo "Documentation Links:"
    echo "- Azure CLI Documentation: https://learn.microsoft.com/cli/azure/"
    echo "- Azure CLI Reference:     https://learn.microsoft.com/cli/azure/reference-index"
    echo "- Get Started Guide:       https://learn.microsoft.com/cli/azure/get-started-with-azure-cli"
    echo "- Azure Functions:         https://learn.microsoft.com/azure/azure-functions/"
    echo "- Bicep Documentation:     https://learn.microsoft.com/azure/azure-resource-manager/bicep/"
    echo
    echo "Authentication Options:"
    echo "- Interactive browser:     az login"
    echo "- Device code:             az login --use-device-code"
    echo "- Service principal:       az login --service-principal --username <app-id> --password <password> --tenant <tenant-id>"
    echo "- Managed identity:        az login --identity"
}

# Post-uninstallation notes
post_uninstallation_message() {
    echo
    echo "🏁 Uninstallation process complete for: $SCRIPT_NAME!"
    echo
    echo "Additional Notes:"
    echo "1. Azure CLI configuration remains in ~/.azure"
    echo "2. Cached credentials remain in ~/.azure"
    echo "3. To completely remove Azure data:"
    echo "   rm -rf ~/.azure"
    echo
    echo "Checking for remaining components..."

    if command -v az >/dev/null; then
        echo "⚠️  Azure CLI is still present: $(az version --output json | grep -oP '\"azure-cli\": \"\\K[^\"]+' || echo 'version unknown')"
        echo "To remove manually:"
        echo "  sudo apt-get remove -y azure-cli"
        echo "  sudo apt-get autoremove -y"
        echo "  sudo rm -rf /etc/apt/sources.list.d/azure-cli.list"
    else
        echo "✅ Azure CLI appears to be removed"
    fi

    if [ ${#EXTENSIONS[@]} -gt 0 ]; then
        local remaining_ext=0
        for ext_id in "${!EXTENSIONS[@]}"; do
            if code --list-extensions 2>/dev/null | grep -qi "^${ext_id}$"; then
                if [ $remaining_ext -eq 0 ]; then
                    echo
                    echo "⚠️  Some VS Code extensions might remain:"
                fi
                echo "   - ${EXTENSIONS[$ext_id]%%|*}"
                ((remaining_ext++))
            fi
        done
        if [ $remaining_ext -eq 0 ]; then
            echo "✅ No Azure VS Code extensions remain"
        fi
    fi
}

#------------------------------------------------------------------------------
# UNINSTALL HANDLER
#------------------------------------------------------------------------------

# Handle Azure CLI uninstallation
handle_uninstall() {
    if command -v az >/dev/null 2>&1; then
        echo "🗑️  Removing Azure CLI..."

        # Remove Azure CLI package
        if sudo apt-get remove -y azure-cli 2>/dev/null; then
            echo "✅ Azure CLI package removed"
        else
            echo "⚠️  Failed to remove Azure CLI package (may not be installed via apt)"
        fi

        # Autoremove dependencies
        sudo apt-get autoremove -y 2>/dev/null

        # Remove repository configuration
        if [ -f "/etc/apt/sources.list.d/azure-cli.list" ]; then
            sudo rm -f /etc/apt/sources.list.d/azure-cli.list
            echo "✅ Azure CLI repository configuration removed"
        fi

        echo "✅ Azure CLI uninstalled"
        echo "ℹ️  Azure configuration in ~/.azure was not removed"
    else
        echo "ℹ️  Azure CLI is not installed"
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
source "${SCRIPT_DIR}/lib/core-install-extensions.sh"

# Source common installation patterns library
source "${SCRIPT_DIR}/lib/install-common.sh"

# Function to process installations
process_installations() {
    if [ "${UNINSTALL_MODE}" -eq 1 ]; then
        handle_uninstall
    fi

    # Process VS Code extensions
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

    # Auto-enable for container rebuild
    auto_enable_tool "azure" "Azure Development Tools"
fi

echo "✅ Script execution finished."
exit 0
