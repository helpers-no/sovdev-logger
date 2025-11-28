#!/bin/bash
# file: .devcontainer/additions/install-dev-powershell.sh
#
# Installs PowerShell runtime and modules for Azure and Microsoft Graph development.
# For usage information, run: ./install-dev-powershell.sh --help
#
#------------------------------------------------------------------------------
# CONFIGURATION - Modify this section for each new script
#------------------------------------------------------------------------------

# Script metadata - must be at the very top of the configuration section
SCRIPT_NAME="PowerShell"
SCRIPT_ID="dev-powershell"
SCRIPT_DESCRIPTION="Installs PowerShell runtime and modules for Azure and Microsoft Graph development"
SCRIPT_CATEGORY="INFRA_CONFIG"
CHECK_INSTALLED_COMMAND="[ -f /usr/bin/pwsh ] || [ -f /opt/microsoft/powershell/7/pwsh ] || command -v pwsh >/dev/null 2>&1"

# Optional: Custom usage text for --help
SCRIPT_USAGE="  $(basename "$0")              # Install PowerShell
  $(basename "$0") --help       # Show this help
  $(basename "$0") --uninstall  # Uninstall PowerShell
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

# Custom PowerShell installation function
install_powershell() {
    if [ "${UNINSTALL_MODE}" -eq 1 ]; then
        echo "=Ñ  Removing PowerShell installation..."

        # Remove PowerShell package
        sudo apt-get remove -y powershell >/dev/null 2>&1 || true

        # Remove Microsoft repository
        if [ -f "/etc/apt/sources.list.d/microsoft.list" ]; then
            sudo rm -f "/etc/apt/sources.list.d/microsoft.list"
            echo " Microsoft repository removed"
        fi

        # Remove GPG key
        if [ -f "/usr/share/keyrings/microsoft.gpg" ]; then
            sudo rm -f "/usr/share/keyrings/microsoft.gpg"
            echo " Microsoft GPG key removed"
        fi

        # Remove PowerShell modules directory
        if [ -d "$HOME/.local/share/powershell" ]; then
            rm -rf "$HOME/.local/share/powershell"
            echo " PowerShell modules directory removed"
        fi

        return
    fi

    # Check if PowerShell is already installed
    if command -v pwsh >/dev/null 2>&1; then
        local current_version=$(pwsh -Version 2>&1 | head -n 1)
        echo " PowerShell is already installed (${current_version})"
        return
    fi

    echo "=æ Installing PowerShell via Microsoft repository..."

    # Detect OS version
    source /etc/os-release
    local os_version=$VERSION_ID

    # Download and install Microsoft signing key
    curl -fsSL "https://packages.microsoft.com/keys/microsoft.asc" | sudo gpg --dearmor -o /usr/share/keyrings/microsoft.gpg

    # Add Microsoft repository
    echo "deb [signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/microsoft-debian-${os_version}-prod ${VERSION_CODENAME} main" | sudo tee /etc/apt/sources.list.d/microsoft.list

    # Update package lists
    sudo apt-get update -qq

    # Install PowerShell
    if sudo DEBIAN_FRONTEND=noninteractive apt-get install -y powershell; then
        echo " PowerShell installed successfully"
    else
        echo "L Failed to install PowerShell"
        return 1
    fi

    # Verify installation
    if command -v pwsh >/dev/null 2>&1; then
        echo " PowerShell is now available: $(pwsh -Version 2>&1 | head -n 1)"
    else
        echo "L PowerShell installation failed - not found in PATH"
        return 1
    fi
}

# Before running installation, we need to add any required repositories or setup
pre_installation_setup() {
    if [ "${UNINSTALL_MODE}" -eq 1 ]; then
        echo "=' Preparing for uninstallation..."
    else
        echo "=' Performing pre-installation setup..."

        # Check if PowerShell is already installed
        if command -v pwsh >/dev/null 2>&1; then
            echo " PowerShell is already installed (version: $(pwsh -Version 2>&1 | head -n 1))"
        fi

        # Update package lists
        sudo apt-get update -qq
    fi
}

# Define package arrays (remove any empty arrays that aren't needed)
PACKAGES_SYSTEM=(
    "curl"
    "ca-certificates"
    "gnupg"
)

PACKAGES_NODE=()

PACKAGES_PYTHON=()

PACKAGES_PWSH=(
    "Az"
    "Microsoft.Graph"
    "PSScriptAnalyzer"
)

# Define VS Code extensions (format: "Name (extension-id) - Description")
EXTENSIONS=(
    "PowerShell (ms-vscode.powershell) - PowerShell language support and debugging"
)

# Define verification commands
VERIFY_COMMANDS=(
    "command -v pwsh >/dev/null && pwsh -Version || echo 'L PowerShell not found'"
    "pwsh -NoProfile -NonInteractive -Command \"Get-Module -ListAvailable Az* | Select-Object Name, Version\" 2>/dev/null || echo '   Az module not found'"
    "pwsh -NoProfile -NonInteractive -Command \"Get-Module -ListAvailable Microsoft.Graph | Select-Object Name, Version\" 2>/dev/null || echo '   Microsoft.Graph module not found'"
    "pwsh -NoProfile -NonInteractive -Command \"Get-Module -ListAvailable PSScriptAnalyzer | Select-Object Name, Version\" 2>/dev/null || echo '   PSScriptAnalyzer not found'"
    "code --list-extensions 2>/dev/null | grep -q 'ms-vscode.powershell' && echo ' PowerShell extension is installed' || echo '   PowerShell extension is not installed'"
)

# Post-installation notes
post_installation_message() {

    echo
    echo "<‰ Installation process complete for: $SCRIPT_NAME!"
    echo "Purpose: $SCRIPT_DESCRIPTION"
    echo
    echo "Important Notes:"
    echo "1. PowerShell runtime has been installed"
    echo "2. PowerShell modules for Azure and Microsoft Graph are available"
    echo "3. PSScriptAnalyzer module provides script analysis and linting"
    echo
    echo "Quick Start:"
    echo "- Check installation: pwsh -Version"
    echo "- Launch PowerShell: pwsh"
    echo "- List modules: Get-Module -ListAvailable"
    echo "- Import Az module: Import-Module Az"
    echo "- Import Graph module: Import-Module Microsoft.Graph"
    echo
    echo "Documentation Links:"
    echo "- PowerShell Documentation: https://learn.microsoft.com/en-us/powershell/"
    echo "- Az PowerShell Module: https://learn.microsoft.com/en-us/powershell/azure/"
    echo "- Microsoft Graph PowerShell: https://learn.microsoft.com/en-us/powershell/microsoftgraph/"
}

# Post-uninstallation notes
post_uninstallation_message() {

    # Remove from auto-enable config
    auto_disable_tool
    echo
    echo "<Á Uninstallation process complete for: $SCRIPT_NAME!"
    echo
    echo "Additional Notes:"
    echo "1. PowerShell runtime has been removed"
    echo "2. PowerShell modules directory has been cleaned"
    echo "3. Microsoft repository has been removed"
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
    # Custom PowerShell runtime installation first
    install_powershell

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
