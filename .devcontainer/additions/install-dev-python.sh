#!/bin/bash
# file: .devcontainer/additions/install-dev-python.sh
#
# Installs Python development environment with pip, venv, and essential tools.
# For usage information, run: ./install-dev-python.sh --help
#
#------------------------------------------------------------------------------
# CONFIGURATION - Modify this section for each new script
#------------------------------------------------------------------------------

# Script metadata - must be at the very top of the configuration section
SCRIPT_NAME="Python Development Tools"
SCRIPT_ID="dev-python"
SCRIPT_DESCRIPTION="Installs Python 3.11+, pip, venv, and essential development tools"
SCRIPT_CATEGORY="LANGUAGE_DEV"
CHECK_INSTALLED_COMMAND="[ -f /usr/local/bin/python3 ] || [ -f /usr/bin/python3 ] || command -v python3 >/dev/null 2>&1"

# Optional: Custom usage text for --help
SCRIPT_USAGE="  $(basename "$0")              # Install Python development environment
  $(basename "$0") --help       # Show this help
  $(basename "$0") --uninstall  # Uninstall Python packages (system Python remains)
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
        echo "🔧 Preparing for uninstallation..."
    else
        echo "🔧 Performing pre-installation setup..."
        # Note: Python likely pre-installed in devcontainer
        echo "✅ Pre-installation setup complete"
    fi
}

# Define package arrays (remove any empty arrays that aren't needed)
PACKAGES_SYSTEM=(
    "python3"
    "python3-pip"
    "python3-venv"
    "python3-dev"
    "python3-setuptools"
    "python3-wheel"
    "build-essential"
    "libffi-dev"
    "libssl-dev"
)

PACKAGES_NODE=(
    # No Node.js packages needed for Python development
)

PACKAGES_PYTHON=(
    "pip"
    "setuptools"
    "wheel"
    "virtualenv"
    "requests"
    "pytest"
    "black"
    "flake8"
    "mypy"
)

# Define VS Code extensions (format: "Name (extension-id) - Description")
EXTENSIONS=(
    "Python (ms-python.python) - Python language support"
    "Pylance (ms-python.vscode-pylance) - Python language server"
    "Black Formatter (ms-python.black-formatter) - Python code formatter"
    "Flake8 (ms-python.flake8) - Python linter"
    "Mypy (ms-python.mypy-type-checker) - Python type checker"
)

# Custom Python installation function
install_python() {
    if [ "${UNINSTALL_MODE}" -eq 1 ]; then
        echo "⚠️  Note: Python uninstallation handled by SYSTEM_PACKAGES"
        # Note: Aliases will remain in .bashrc (safe to leave)
        return
    fi

    # Check if Python is already installed (likely in devcontainer)
    if command -v python3 >/dev/null 2>&1; then
        echo "✅ Python is already installed - configuring environment"
    else
        echo "📦 Python will be installed via SYSTEM_PACKAGES"
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

# Note: Python packages handled by library's process_python_packages() via PYTHON_PACKAGES array

# Define verification commands
VERIFY_COMMANDS=(
    "command -v python3 >/dev/null && python3 --version || echo '❌ Python not found'"
    "command -v pip3 >/dev/null && pip3 --version || echo '❌ pip not found'"
    "python3 -c 'import venv' 2>/dev/null && echo '✅ venv module available' || echo '❌ venv module not available'"
    "grep -q 'alias python=' ~/.bashrc && echo '✅ Python aliases configured' || echo 'ℹ️  Python aliases not yet active (restart shell)'"
)

# Post-installation notes
post_installation_message() {
    
    echo
    echo "🎉 Installation process complete for: $SCRIPT_NAME!"
    echo "Purpose: $SCRIPT_DESCRIPTION"
    echo
    echo "Important Notes:"
    echo "1. Python development environment is ready"
    echo "2. Essential Python packages are installed"
    echo "3. Virtual environment tools are available"
    echo "4. Python aliases configured (restart shell or: source ~/.bashrc)"
    echo
    echo "Quick Start:"
    echo "- Check installation: python3 --version && pip3 --version"
    echo "- Create virtual environment: python3 -m venv myenv"
    echo "- Activate environment: source myenv/bin/activate"
    echo "- Install packages: pip install requests"
    echo "- Run tests: pytest"
    echo
    echo "Documentation Links:"
    echo "- Python Documentation: https://docs.python.org/"
    echo "- pip Documentation: https://pip.pypa.io/en/stable/"
    echo "- Virtual Environments: https://docs.python.org/3/tutorial/venv.html"
}

# Post-uninstallation notes
post_uninstallation_message() {

    # Remove from auto-enable config
    auto_disable_tool
    echo
    echo "🏁 Uninstallation process complete for: $SCRIPT_NAME!"
    echo
    echo "Additional Notes:"
    echo "1. Python packages have been removed"
    echo "2. Virtual environments may still exist"
    echo "3. You may need to restart your shell for changes to take effect"
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



# Main execution
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
    verify_installations
    post_installation_message

    # Auto-enable for container rebuild
    auto_enable_tool
fi
