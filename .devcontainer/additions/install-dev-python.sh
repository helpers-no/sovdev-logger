#!/bin/bash
# file: .devcontainer/additions/install-dev-python.sh
#
# Installs Python development environment with pip, venv, and essential tools.
# For usage information, run: ./install-dev-python.sh --help
#
#------------------------------------------------------------------------------
# CONFIGURATION - Modify this section for each new script
#------------------------------------------------------------------------------

# --- Script Metadata ---
SCRIPT_ID="dev-python"
SCRIPT_NAME="Python Development Tools"
SCRIPT_DESCRIPTION="Adds pytest and VS Code extensions for Python development (Python already in devcontainer)"
SCRIPT_CATEGORY="LANGUAGE_DEV"
CHECK_INSTALLED_COMMAND="[ -f /usr/local/bin/python3 ] || [ -f /usr/bin/python3 ] || command -v python3 >/dev/null 2>&1"

# Optional: Custom usage text for --help
SCRIPT_USAGE="  $(basename "$0")              # Install Python development environment
  $(basename "$0") --help       # Show this help
  $(basename "$0") --uninstall  # Uninstall Python packages (system Python remains)
  $(basename "$0") --debug      # Install with debug output"

# Python packages
PACKAGES_PYTHON=(
    "pytest"  # Testing framework
)

# VS Code extensions
EXTENSIONS=(
    "Python (ms-python.python) - Python language support"
    "Pylance (ms-python.vscode-pylance) - Python language server"
    "Black Formatter (ms-python.black-formatter) - Python code formatter"
    "Flake8 (ms-python.flake8) - Python linter"
    "Mypy (ms-python.mypy-type-checker) - Python type checker"
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
        # Note: Python likely pre-installed in devcontainer
        echo "✅ Pre-installation setup complete"
    fi
}

# --- Custom Python Installation ---
install_python() {
    if [ "${UNINSTALL_MODE}" -eq 1 ]; then
        # Note: Aliases will remain in .bashrc (safe to leave)
        return
    fi

    # Check if Python is already installed (already in devcontainer)
    if command -v python3 >/dev/null 2>&1; then
        echo "✅ Python is already installed - configuring environment"
    fi

    # Set up Python aliases using library function
    # Only add if 'python' command doesn't already exist
    if ! command -v python >/dev/null 2>&1; then
        add_to_bashrc "alias python=" "# Python environment" \
            "alias python=python3" \
            "alias pip=pip3"
    else
        echo "✅ Python command already available"
    fi
}

# --- Post-installation/Uninstallation Messages ---
post_installation_message() {
    local python_version
    python_version=$(python3 --version 2>/dev/null || echo "not found")

    local pip_version
    pip_version=$(pip3 --version 2>/dev/null | head -n 1 || echo "not found")

    echo
    echo "🎉 Installation complete!"
    echo "   Python: $python_version"
    echo "   pip: $pip_version"
    echo
    echo "Quick start: python3 -m venv myenv && source myenv/bin/activate"
    echo "Docs: https://docs.python.org/"
    echo
}

post_uninstallation_message() {
    echo
    echo "🏁 Uninstallation complete!"
    if command -v python3 >/dev/null; then
        echo "   ⚠️  Python still found in PATH"
    else
        echo "   ✅ Python packages removed"
    fi
    echo
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
    # Install/configure Python environment
    install_python

    # Process standard installations (packages and extensions)
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
