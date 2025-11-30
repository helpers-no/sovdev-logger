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

# System packages (all packages already in base devcontainer - see Dockerfile.base)
PACKAGES_SYSTEM=()

# Node.js packages
PACKAGES_NODE=(
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
        echo "✅ Pre-installation setup complete"
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

# --- Install Azure CLI ---
install_azure_cli() {
    if [ "${UNINSTALL_MODE}" -eq 1 ]; then
        if command -v az >/dev/null 2>&1; then
            echo "Removing Azure CLI..."
            sudo apt-get remove -y azure-cli 2>/dev/null || true
            echo "✅ Azure CLI removed"
        else
            echo "✅ Azure CLI not installed, skipping"
        fi
        return
    fi

    # Check if already installed
    if command -v az >/dev/null 2>&1; then
        local current_version=$(az version --output json 2>/dev/null | grep -o '"azure-cli": "[^"]*"' | cut -d'"' -f4)
        echo "✅ Azure CLI already installed (version: ${current_version})"
        return
    fi

    echo "Installing Azure CLI..."
    if sudo DEBIAN_FRONTEND=noninteractive apt-get install -y azure-cli 2>/dev/null; then
        local version=$(az version --output json 2>/dev/null | grep -o '"azure-cli": "[^"]*"' | cut -d'"' -f4)
        echo "✅ Azure CLI ${version} installed successfully"
    else
        echo "❌ Failed to install Azure CLI"
        return 1
    fi
}

# --- Install Azure Functions Core Tools ---
install_azure_functions() {
    if [ "${UNINSTALL_MODE}" -eq 1 ]; then
        if command -v func >/dev/null 2>&1; then
            echo "Removing Azure Functions Core Tools..."
            # Remove npm global installation
            npm uninstall -g azure-functions-core-tools 2>/dev/null || true
            sudo rm -f /usr/local/bin/func 2>/dev/null || true
            echo "✅ Azure Functions Core Tools removed"
        else
            echo "✅ Azure Functions Core Tools not installed, skipping"
        fi
        return
    fi

    # Check if already installed
    if command -v func >/dev/null 2>&1; then
        local current_version=$(func --version 2>/dev/null || echo "unknown")
        echo "✅ Azure Functions Core Tools already installed (version: ${current_version})"
        return
    fi

    echo "Installing Azure Functions Core Tools..."

    # Detect architecture
    local arch=$(uname -m)

    case $arch in
        x86_64)
            echo "Detected x86_64 architecture - using direct download"
            local func_version="4.0.7317"
            local download_url="https://github.com/Azure/azure-functions-core-tools/releases/download/${func_version}/Azure.Functions.Cli.linux-x64.${func_version}.zip"

            # Create temp directory
            local temp_dir=$(mktemp -d)
            cd "$temp_dir"

            # Download and extract
            if curl -L -o func.zip "$download_url" 2>/dev/null; then
                unzip -q func.zip 2>/dev/null
                sudo mv func /usr/local/bin/
                sudo chmod +x /usr/local/bin/func
                echo "✅ Azure Functions Core Tools installed for x86_64"
            else
                echo "⚠️  Failed to download, trying npm fallback..."
                if npm install -g azure-functions-core-tools@4 2>/dev/null; then
                    echo "✅ Azure Functions Core Tools installed via npm"
                else
                    echo "❌ All installation methods failed"
                fi
            fi

            # Cleanup
            cd - > /dev/null
            rm -rf "$temp_dir"
            ;;
        aarch64|arm64)
            echo "Detected ARM64 architecture - using npm preview version"
            echo "Note: ARM64 Linux support is in preview with some limitations"
            if npm install -g azure-functions-core-tools@4.0.7332-preview1 2>/dev/null; then
                echo "✅ Azure Functions Core Tools (ARM64 preview) installed via npm"
            else
                echo "⚠️  ARM64 preview failed, trying standard version"
                if npm install -g azure-functions-core-tools@4 2>/dev/null; then
                    echo "✅ Azure Functions Core Tools (standard) installed via npm"
                    echo "   Note: May have compatibility issues on ARM64"
                else
                    echo "❌ All installation methods failed"
                fi
            fi
            ;;
        *)
            echo "⚠️  Unsupported architecture: $arch"
            echo "   Trying npm installation..."
            if npm install -g azure-functions-core-tools@4 2>/dev/null; then
                echo "✅ Azure Functions Core Tools installed via npm"
            else
                echo "❌ Failed to install Azure Functions Core Tools"
            fi
            ;;
    esac
}

# --- Post-installation/Uninstallation Messages ---
post_installation_message() {
    local az_version
    local func_version
    local azurite_version

    az_version=$(az version --output json 2>/dev/null | grep -o '"azure-cli": "[^"]*"' | cut -d'"' -f4 || echo "not found")
    func_version=$(func --version 2>/dev/null || echo "not found")
    azurite_version=$(npm list -g azurite 2>/dev/null | grep azurite | cut -d'@' -f2 || echo "not found")

    echo
    echo "🎉 Installation complete!"
    echo "   Azure CLI: $az_version"
    echo "   Azure Functions Core Tools: $func_version"
    echo "   Azurite: $azurite_version"
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
    echo "   ✅ Azure CLI removed"
    echo "   ✅ Azure Functions Core Tools removed"
    echo "   ✅ Azurite removed"
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
    if [ "${UNINSTALL_MODE}" -eq 1 ]; then
        # Uninstall order: extensions → node packages → Azure Functions → Azure CLI
        if [ ${#EXTENSIONS[@]} -gt 0 ]; then
            process_extensions "EXTENSIONS"
        fi
        if [ ${#PACKAGES_NODE[@]} -gt 0 ]; then
            process_node_packages "PACKAGES_NODE"
        fi
        install_azure_functions
        install_azure_cli
    else
        # Install order: STEP 1 → 2 → 3 → 4 → 5 → 6

        # STEP 1: Install system prerequisites FIRST
        if [ ${#PACKAGES_SYSTEM[@]} -gt 0 ]; then
            process_system_packages "PACKAGES_SYSTEM"
        fi

        # STEP 2: Add Azure CLI repository (now we have curl and gnupg)
        add_azure_cli_repository

        # STEP 3: Install Azure CLI
        install_azure_cli

        # STEP 4: Install Azure Functions Core Tools
        install_azure_functions

        # STEP 5: Install Node.js packages (Azurite)
        if [ ${#PACKAGES_NODE[@]} -gt 0 ]; then
            process_node_packages "PACKAGES_NODE"
        fi

        # STEP 6: Process VS Code extensions
        if [ ${#EXTENSIONS[@]} -gt 0 ]; then
            process_extensions "EXTENSIONS"
        fi
    fi
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
else
    echo "🔄 Starting installation process for: $SCRIPT_NAME"
    echo "Purpose: $SCRIPT_DESCRIPTION"
    pre_installation_setup
    process_installations
    post_installation_message

    # Auto-enable for container rebuild
    auto_enable_tool "$SCRIPT_ID" "$SCRIPT_NAME"
fi

echo "✅ Script execution finished."
exit 0
