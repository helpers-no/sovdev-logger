#!/bin/bash
# file: .devcontainer/additions/install-tool-powershell.sh
#
# Installs PowerShell runtime and modules for Azure/Microsoft 365 cloud automation.
# PowerShell on Linux is primarily used for managing Azure resources and Microsoft Graph APIs.
# For usage information, run: ./install-tool-powershell.sh --help
#
#------------------------------------------------------------------------------
# CONFIGURATION - Modify this section for each new script
#------------------------------------------------------------------------------

# --- Script Metadata ---
SCRIPT_ID="tool-powershell"
SCRIPT_NAME="PowerShell for Azure/M365 Automation"
SCRIPT_DESCRIPTION="Installs PowerShell runtime with Az and Microsoft.Graph modules for Azure/Microsoft 365 cloud automation"
SCRIPT_CATEGORY="INFRA_CONFIG"
CHECK_INSTALLED_COMMAND="[ -f /usr/bin/pwsh ] || [ -f /opt/microsoft/powershell/7/pwsh ] || command -v pwsh >/dev/null 2>&1"

# Custom usage text for --help
SCRIPT_USAGE="  $(basename "$0")              # Install PowerShell with Azure modules
  $(basename "$0") --help       # Show this help
  $(basename "$0") --uninstall  # Uninstall PowerShell
  $(basename "$0") --debug      # Install with debug output"

# --- Default Configuration ---
DEFAULT_VERSION="7.5.4"  # PowerShell 7.5.4 (latest stable as of October 2025)
TARGET_VERSION=""        # Actual version to install (can be overridden with --version)

# System packages (all packages already in base devcontainer - see Dockerfile.base)
PACKAGES_SYSTEM=()

# Node.js packages (not needed for PowerShell)
PACKAGES_NODE=()

# Python packages (not needed for PowerShell)
PACKAGES_PYTHON=()

# PowerShell modules
PACKAGES_PWSH=(
    "Az"                          # Azure cloud automation (Resource Manager, Storage, Compute, etc.)
    "Microsoft.Graph"             # Microsoft 365 and Graph API automation
    "ExchangeOnlineManagement"    # Exchange Online management and connections
    "PSScriptAnalyzer"            # PowerShell script analysis and linting
)

# VS Code extensions
EXTENSIONS=(
    "PowerShell (ms-vscode.powershell) - PowerShell language support and debugging"
    "Azure Account (ms-vscode.azure-account) - Azure subscription management and sign-in"
    "Azure Resources (ms-azuretools.vscode-azureresourcegroups) - View and manage Azure resources"
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

# Custom PowerShell installation function
install_powershell() {
    if [ "${UNINSTALL_MODE}" -eq 1 ]; then
        echo "🗑️  Removing PowerShell installation..."

        # Remove symbolic links
        if [ -L "/usr/local/bin/pwsh" ]; then
            sudo rm -f /usr/local/bin/pwsh
            echo "✅ Removed /usr/local/bin/pwsh symlink"
        fi
        if [ -L "/usr/bin/pwsh" ]; then
            sudo rm -f /usr/bin/pwsh
            echo "✅ Removed /usr/bin/pwsh symlink"
        fi

        # Remove PowerShell installation directory
        if [ -d "/opt/microsoft/powershell" ]; then
            sudo rm -rf /opt/microsoft/powershell
            echo "✅ Removed PowerShell installation directory"
        fi

        # Remove PowerShell modules directory
        if [ -d "$HOME/.local/share/powershell" ]; then
            rm -rf "$HOME/.local/share/powershell"
            echo "✅ Removed PowerShell modules directory"
        fi

        return
    fi

    # Check if PowerShell is already installed
    if command -v pwsh >/dev/null 2>&1; then
        local current_version=$(pwsh -Version 2>&1 | head -n 1)
        echo "✅ PowerShell is already installed (${current_version})"
        return
    fi

    echo "📦 Installing PowerShell from GitHub releases..."

    # PowerShell version to install (latest stable as of 2025)
    local powershell_version="${TARGET_VERSION:-7.5.4}"

    # Detect system architecture
    local target_platform=$(uname -m)
    local ps_arch
    local ps_package_url

    echo "🖥️  Detected architecture: $target_platform"

    # Determine architecture-specific download URL
    case "$target_platform" in
        "x86_64"|"amd64")
            ps_arch="x64"
            ps_package_url="https://github.com/PowerShell/PowerShell/releases/download/v${powershell_version}/powershell-${powershell_version}-linux-x64.tar.gz"
            ;;
        "aarch64"|"arm64")
            ps_arch="arm64"
            ps_package_url="https://github.com/PowerShell/PowerShell/releases/download/v${powershell_version}/powershell-${powershell_version}-linux-arm64.tar.gz"
            ;;
        "armv7l"|"arm")
            ps_arch="arm32"
            ps_package_url="https://github.com/PowerShell/PowerShell/releases/download/v${powershell_version}/powershell-${powershell_version}-linux-arm32.tar.gz"
            ;;
        *)
            echo "❌ Unsupported architecture: $target_platform"
            return 1
            ;;
    esac

    echo "⬇️  Downloading PowerShell v${powershell_version} for $ps_arch..."
    local temp_tarball="/tmp/powershell.tar.gz"

    if ! curl -L -o "$temp_tarball" "$ps_package_url" 2>/dev/null; then
        echo "❌ Failed to download PowerShell from $ps_package_url"
        return 1
    fi

    echo "📦 Installing PowerShell..."
    # Create PowerShell installation directory
    sudo mkdir -p /opt/microsoft/powershell/7

    # Extract PowerShell to installation directory
    sudo tar zxf "$temp_tarball" -C /opt/microsoft/powershell/7

    # Set executable permissions
    sudo chmod +x /opt/microsoft/powershell/7/pwsh

    # Create symbolic links for maximum compatibility
    # Link to /usr/local/bin (preferred for user-installed software)
    sudo ln -sf /opt/microsoft/powershell/7/pwsh /usr/local/bin/pwsh
    # Link to /usr/bin (system-wide availability)
    sudo ln -sf /opt/microsoft/powershell/7/pwsh /usr/bin/pwsh

    # Clean up
    rm -f "$temp_tarball"

    echo "✅ PowerShell installed successfully"

    # Verify installation
    if command -v pwsh >/dev/null 2>&1; then
        echo "✅ PowerShell is now available: $(pwsh -Version 2>&1 | head -n 1)"
    else
        echo "❌ PowerShell installation failed - not found in PATH"
        return 1
    fi
}

#------------------------------------------------------------------------------

# --- Pre-installation/Uninstallation Setup ---
# Before running installation, we need to add any required repositories or setup
pre_installation_setup() {
    if [ "${UNINSTALL_MODE}" -eq 1 ]; then
        echo "🔧 Preparing for uninstallation..."
    else
        echo "🔧 Performing pre-installation setup..."

        # Check if PowerShell is already installed
        if command -v pwsh >/dev/null 2>&1; then
            echo "✅ PowerShell is already installed (version: $(pwsh -Version 2>&1 | head -n 1))"
        fi

        # Note: apt-get update is run by install_powershell after repository setup
        echo "✅ Pre-installation setup complete"
    fi
}

#------------------------------------------------------------------------------

# --- Post-installation/Uninstallation Messages ---

# Post-installation notes
post_installation_message() {
    local pwsh_version
    pwsh_version=$(pwsh -Version 2>&1 | head -n 1 || echo "not found")

    echo
    echo "🎉 Installation complete!"
    echo "   PowerShell: $pwsh_version"
    echo
    echo "Installed PowerShell modules:"
    echo "  • Az - Azure cloud automation (Resource Manager, Storage, Compute, etc.)"
    echo "  • Microsoft.Graph - Microsoft 365 and Graph API automation"
    echo "  • ExchangeOnlineManagement - Exchange Online management and connections"
    echo "  • PSScriptAnalyzer - PowerShell script analysis and linting"
    echo
    echo "Installed VS Code extensions:"
    echo "  • PowerShell - Language support and debugging"
    echo "  • Azure Account - Azure subscription management and sign-in"
    echo "  • Azure Resources - View and manage Azure resources"
    echo
    echo "Quick start:"
    echo "  - Launch PowerShell:      pwsh"
    echo "  - Check version:          pwsh -Version"
    echo "  - List modules:           Get-Module -ListAvailable"
    echo
    echo "Azure management:"
    echo "  - Import Az:              Import-Module Az"
    echo "  - Connect to Azure:       Connect-AzAccount"
    echo "  - List subscriptions:     Get-AzSubscription"
    echo "  - List resource groups:   Get-AzResourceGroup"
    echo "  - List VMs:               Get-AzVM"
    echo
    echo "Microsoft 365 management:"
    echo "  - Import Graph:           Import-Module Microsoft.Graph"
    echo "  - Connect to M365:        Connect-MgGraph"
    echo "  - List users:             Get-MgUser"
    echo "  - List groups:            Get-MgGroup"
    echo
    echo "Exchange Online management:"
    echo "  - Connect:                Connect-ExchangeOnline"
    echo "  - List mailboxes:         Get-Mailbox"
    echo "  - Get mail flow:          Get-MessageTrace"
    echo
    echo "Docs:"
    echo "  - PowerShell:             https://learn.microsoft.com/en-us/powershell/"
    echo "  - Az Module:              https://learn.microsoft.com/en-us/powershell/azure/"
    echo "  - Microsoft.Graph:        https://learn.microsoft.com/en-us/powershell/microsoftgraph/"
    echo "  - Exchange Online:        https://learn.microsoft.com/en-us/powershell/exchange/exchange-online-powershell"
    echo
}

post_uninstallation_message() {
    echo
    echo "🏁 Uninstallation complete!"
    echo "   ✅ PowerShell removed from /opt/microsoft/powershell"
    echo "   ✅ PowerShell modules removed from ~/.local/share/powershell"
    echo "   ✅ Symbolic links removed from /usr/local/bin and /usr/bin"
    echo "   ✅ VS Code extensions uninstalled"
    echo
    echo "Note: Run 'hash -r' or start a new shell to clear the command hash table"
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
source "${SCRIPT_DIR}/lib/core-install-pwsh.sh"
source "${SCRIPT_DIR}/lib/core-install-python.sh"

#------------------------------------------------------------------------------
# HELPER FUNCTIONS
#------------------------------------------------------------------------------

# Function to process installations
process_installations() {
    if [ "${UNINSTALL_MODE}" -eq 1 ]; then
        # During uninstall: only process VS Code extensions
        # PowerShell modules will be removed when we delete the directories
        if [ ${#EXTENSIONS[@]} -gt 0 ]; then
            process_extensions "EXTENSIONS"
        fi
        # Remove PowerShell runtime and all its modules
        install_powershell
    else
        # During install: install PowerShell runtime first
        install_powershell
        # Then install modules and extensions (now that PowerShell is available)
        process_standard_installations
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
