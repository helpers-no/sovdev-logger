#!/bin/bash
# file: .devcontainer/additions/install-tool-iac.sh
#
# Installs tools and extensions for Infrastructure as Code (IaC) and configuration management (Ansible).
# For usage information, run: ./install-tool-iac.sh --help
#
#------------------------------------------------------------------------------
# CONFIGURATION - Modify this section for each new script
#------------------------------------------------------------------------------

# Script metadata - must be at the very top of the configuration section
SCRIPT_NAME="Configuration Tools"
SCRIPT_ID="tool-iac"
SCRIPT_DESCRIPTION="Installs tools and extensions for Infrastructure as Code (IaC) and configuration management (Ansible)"
SCRIPT_CATEGORY="INFRA_CONFIG"
CHECK_INSTALLED_COMMAND="[ -f /usr/local/bin/ansible ] || [ -f /usr/bin/ansible ] || command -v ansible >/dev/null 2>&1"

# Optional: Custom usage text for --help
SCRIPT_USAGE="  $(basename "$0")              # Install IaC tools
  $(basename "$0") --help       # Show this help
  $(basename "$0") --uninstall  # Uninstall IaC tools
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
        # Here you add any required pre-installation steps
        # none needed for this script
        echo " Pre-installation setup complete"
    fi
}

# Define system packages
PACKAGES_SYSTEM=(
    "ansible"
    "ansible-lint"
)

# Define Python packages for pip installation
PACKAGES_PYTHON=()

# Define VS Code extensions
declare -A EXTENSIONS
EXTENSIONS["redhat.ansible"]="Ansible|Ansible language support and tools"

# Define verification commands to run after installation
VERIFY_COMMANDS=(
    "command -v ansible >/dev/null && ansible --version | head -n1 || echo 'L ansible not found'"
    "command -v ansible-lint >/dev/null && ansible-lint --version || echo 'L ansible-lint not found'"
    "code --list-extensions | grep -q redhat.ansible && echo ' Ansible extension is installed' || echo 'L Ansible extension is not installed'"
)

# Post-installation notes
post_installation_message() {
    # Note: Installation and verification already completed via verify_installations()
    local ansible_version=$(ansible --version 2>/dev/null | head -n1 || echo "unknown")
    local lint_version=$(ansible-lint --version 2>/dev/null || echo "unknown")

    echo
    echo "<‰ Installation process complete for: $SCRIPT_NAME!"
    echo "Purpose: $SCRIPT_DESCRIPTION"
    echo
    echo "Important Notes:"
    echo "1. Bicep CLI is installed and configured with the extension"
    echo "2. Ansible $ansible_version"
    echo "3. ansible-lint $lint_version"
    echo
    echo "Documentation Links:"
    echo "- Local Guide: .devcontainer/howto/howto-conf-script.md"
    echo "- Bicep: https://docs.microsoft.com/azure/azure-resource-manager/bicep"
    echo "- Ansible: https://docs.ansible.com"
    echo "- VS Code Bicep Extension: https://marketplace.visualstudio.com/items?itemName=ms-azuretools.vscode-bicep"
    echo "- VS Code Ansible Extension: https://marketplace.visualstudio.com/items?itemName=redhat.ansible"
}

# Post-uninstallation notes
post_uninstallation_message() {

    # Remove from auto-enable config
    auto_disable_tool
    echo
    echo "<Á Uninstallation process complete for: $SCRIPT_NAME!"
    echo
    echo "Additional Notes:"
    echo "1. Configuration files (.bicep, .yaml, etc.) remain unchanged"
    echo "2. Any custom Ansible configurations in ~/.ansible remain in place"
    echo "3. See the local guide for additional cleanup steps if needed:"
    echo "   .devcontainer/howto/howto-conf-script.md"

    # Verify uninstallation
    if command -v ansible >/dev/null || command -v ansible-lint >/dev/null; then
        echo
        echo "   Warning: Some components may still be installed:"
        command -v ansible >/dev/null && echo "- ansible is still present"
        command -v ansible-lint >/dev/null && echo "- ansible-lint is still present"
        echo "You may need to run with sudo or check package manager settings."
    fi
}


#------------------------------------------------------------------------------
# STANDARD SCRIPT LOGIC - Do not modify anything below this line
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

# Source common installation patterns library
source "${SCRIPT_DIR}/lib/install-common.sh"

# Function to process installations
process_installations() {
    # Use standard processing from lib/install-common.sh
    process_standard_installations
}

# Function to verify installations
# Note: Using common implementation from lib/install-common.sh (sourced above)
# No local definition needed - library function is used directly

# Main execution
if [ "${UNINSTALL_MODE}" -eq 1 ]; then
    echo "= Starting uninstallation process for: $SCRIPT_NAME"
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

    # Remove from auto-enable config
    auto_disable_tool
else
    echo "= Starting installation process for: $SCRIPT_NAME"
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
    auto_enable_tool
fi
