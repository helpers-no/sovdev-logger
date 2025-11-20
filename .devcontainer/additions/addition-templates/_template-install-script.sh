#!/bin/bash
# file: .devcontainer/additions/_template-install-script.sh
#
# TEMPLATE: Copy this file when creating new installation scripts
# Rename to: install-[your-name].sh
# Example: install-dev-python.sh
#
# Usage: ./install-[name].sh [options]
#
# Options:
#   --debug     : Enable debug output for troubleshooting
#   --uninstall : Remove installed components instead of installing them
#   --force     : Force installation/uninstallation even if there are dependencies
#
#------------------------------------------------------------------------------
# METADATA PATTERN - Required for automatic script discovery
#------------------------------------------------------------------------------
#
# The dev-setup.sh menu system uses the component-scanner library to automatically
# discover and display all install scripts. To make your script visible in the menu,
# you must define these four metadata fields in the CONFIGURATION section below:
#
# SCRIPT_NAME - Human-readable name displayed in the menu (2-4 words)
#   Example: "Python Development Tools"
#
# SCRIPT_DESCRIPTION - Brief description of what the script installs (one sentence)
#   Example: "Install Python 3.11, pip, and essential Python development packages"
#
# SCRIPT_CATEGORY - Category for menu organization
#   Common options: DEV_TOOLS, INFRA_CONFIG, AI_TOOLS, MONITORING, DATABASE, CLOUD
#   Example: "DEV_TOOLS"
#
# CHECK_INSTALLED_COMMAND - Shell command to check if already installed
#   - Must return exit code 0 if installed, 1 if not installed
#   - Should suppress all output (use >/dev/null 2>&1)
#   - Should be fast (run in < 1 second)
#   - Should be idempotent (safe to run repeatedly)
#   - BEST PRACTICE: Check installation location OR PATH for better UX
#     This ensures the tool shows as installed immediately after installation,
#     even if the current shell's PATH hasn't been updated yet.
#   Examples:
#     "[ -f $HOME/.cargo/bin/rustc ] || command -v rustc >/dev/null 2>&1"
#     "[ -f /usr/local/bin/tool ] || command -v tool >/dev/null 2>&1"
#     "dpkg -l python3 2>/dev/null | grep -q '^ii'"
#     "[ -d /opt/tool ]"
#
# PREREQUISITE_CONFIGS - Space-separated list of config scripts required (OPTIONAL)
#   Use this field to declare configuration prerequisites that must exist before
#   your tool can be installed. The system will automatically check these and
#   block installation with a clear error if prerequisites are missing.
#
#   Format: Space-separated list of config script filenames
#   Example: "config-devcontainer-identity.sh config-aws-credentials.sh"
#
#   How it works:
#     1. project-installs.sh checks this field BEFORE running your install script
#     2. Uses lib/prerequisite-check.sh to verify each config is satisfied
#     3. If any prerequisite missing, shows error and skips installation
#     4. User fixes prerequisites, re-runs project-installs.sh
#
#   Two-Layer System:
#     Layer 1: Silent Restoration (restore_all_configurations)
#       - Runs BEFORE tool installation
#       - Attempts to restore ALL configs from topsecret
#       - SILENT for missing configs (no noise)
#
#     Layer 2: Loud Prerequisites (install_project_tools - uses this field!)
#       - Runs DURING tool installation for YOUR tool
#       - Checks YOUR PREREQUISITE_CONFIGS field
#       - LOUD error if required config missing
#       - Blocks installation until fixed
#
#   Example output when prerequisite missing:
#     ⚠️  My Tool - missing prerequisites
#       ❌ Developer Identity (run: bash .../config-devcontainer-identity.sh)
#
#     💡 To fix:
#        1. Run: check-configs
#        2. Then re-run: bash .../project-installs.sh
#
#   Leave empty if no prerequisites needed (most tools don't need this).
#
# AUTO-ENABLE PATTERN - Tools automatically add themselves to enabled-tools.conf
#   When a tool is successfully installed, it automatically adds itself to
#   .devcontainer.extend/enabled-tools.conf. This ensures the tool will be
#   reinstalled on container rebuild. This template includes the auto-enable
#   code - no changes needed unless you want custom behavior.
#
# For more details, see: .devcontainer/additions/README-additions.md
#
#------------------------------------------------------------------------------
# CONFIGURATION - Modify this section for each new script
#------------------------------------------------------------------------------

# Script metadata - Required for dev-setup.sh menu discovery
# These fields must be defined at the top of the configuration section
SCRIPT_NAME="[Name]"
SCRIPT_DESCRIPTION="[Brief description of what this script installs and its purpose]"
SCRIPT_CATEGORY="DEV_TOOLS"  # Options: DEV_TOOLS, INFRA_CONFIG, AI_TOOLS, MONITORING, DATABASE, CLOUD
CHECK_INSTALLED_COMMAND="command -v [tool-name] >/dev/null 2>&1"  # Command to check if already installed

# Optional: Prerequisite configurations required before installation
# Uncomment and modify if your tool requires specific configurations
# PREREQUISITE_CONFIGS="config-devcontainer-identity.sh"
# Multiple prerequisites: PREREQUISITE_CONFIGS="config-identity.sh config-aws-credentials.sh"

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

# Before running installation, we need to add any required repositories or setup
pre_installation_setup() {
    if [ "${UNINSTALL_MODE}" -eq 1 ]; then
        echo "🔧 Preparing for uninstallation..."
    else
        echo "🔧 Performing pre-installation setup..."
        # Add repository configurations, keys, or other setup steps here
        # Example:
        # curl -fsSL https://example.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/example-archive-keyring.gpg
    fi
}

# Define package arrays (remove any empty arrays that aren't needed)
SYSTEM_PACKAGES=(
    # "package1"
    # "package2"
)

NODE_PACKAGES=(
    # "package1"
    # "package2"
)

PYTHON_PACKAGES=(
    # "package1"
    # "package2"
)

PWSH_MODULES=(
    # "module1"
    # "module2"
)

# Define VS Code extensions
declare -A EXTENSIONS
# Format: "extension-id"="Display Name|Description"
# Example: EXTENSIONS["ms-python.python"]="Python|Python language support"

# Define verification commands to run after installation
VERIFY_COMMANDS=(
    # Add commands to verify successful installation
    # Examples:
    # "command -v tool >/dev/null && tool --version || echo '❌ tool not found'"
    # "test -f /path/to/file && echo '✅ File exists' || echo '❌ File not found'"
)

# Post-installation notes
post_installation_message() {
    echo
    echo "🎉 Installation process complete for: $SCRIPT_NAME!"
    echo "Purpose: $SCRIPT_DESCRIPTION"
    echo
    echo "Important Notes:"
    echo "1. [Important note 1]"
    echo "2. [Important note 2]"
    echo "3. [Important note 3]"
    echo
    echo "Documentation Links:"
    echo "- Local Guide: .devcontainer/howto/howto-[name].md"
    echo "- [Link description]: [URL]"
    echo "- [Link description]: [URL]"
}

# Post-uninstallation notes
post_uninstallation_message() {
    echo
    echo "🏁 Uninstallation process complete for: $SCRIPT_NAME!"
    echo
    echo "Additional Notes:"
    echo "1. [Cleanup note 1]"
    echo "2. [Cleanup note 2]"
    echo "3. See the local guide for additional cleanup steps if needed:"
    echo "   .devcontainer/howto/howto-[name].md"
    
    # Add any verification of uninstallation if needed
    # Example:
    # if command -v tool >/dev/null; then
    #     echo
    #     echo "⚠️  Warning: Some components may still be installed:"
    #     echo "- tool is still present"
    # fi
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
    # Convert SCRIPT_NAME to identifier (lowercase-with-dashes)
    # Example: "Python Development Tools" -> "python-development-tools"
    TOOL_ID=$(echo "$SCRIPT_NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
    auto_enable_tool "$TOOL_ID" "$SCRIPT_NAME"
fi