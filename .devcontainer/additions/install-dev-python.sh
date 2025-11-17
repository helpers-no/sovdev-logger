#!/bin/bash
# file: .devcontainer/additions/install-dev-python.sh
#
# Usage: ./install-dev-python.sh [options]
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
SCRIPT_NAME="Python Development Tools"
SCRIPT_DESCRIPTION="Installs Python 3.11+, pip, venv, and essential development tools"
SCRIPT_CATEGORY="LANGUAGE_DEV"
CHECK_INSTALLED_COMMAND="[ -f /usr/local/bin/python3 ] || [ -f /usr/bin/python3 ] || command -v python3 >/dev/null 2>&1"

#------------------------------------------------------------------------------

# Source auto-enable library
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/tool-auto-enable.sh"

#------------------------------------------------------------------------------

# Before running installation, we need to add any required repositories or setup
pre_installation_setup() {
    if [ "${UNINSTALL_MODE}" -eq 1 ]; then
        echo "🔧 Preparing for uninstallation..."
    else
        echo "🔧 Performing pre-installation setup..."
        
        # Check if Python is already installed
        if command -v python3 >/dev/null 2>&1; then
            echo "✅ Python is already installed (version: $(python3 --version))"
        fi
        
        # Update package lists
        sudo apt-get update -qq
    fi
}

# Define package arrays (remove any empty arrays that aren't needed)
SYSTEM_PACKAGES=(
    "python3"
    "python3-pip"
    "python3-venv"
    "python3-dev"
    "python3-setuptools"
    "python3-wheel"
    "build-essential"
    "libffi-dev"
    "libssl-dev"
    "curl"
    "git"
)

NODE_PACKAGES=(
    # No Node.js packages needed for Python development
)

PYTHON_PACKAGES=(
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

VSCODE_EXTENSIONS=(
    "ms-python.python"
    "ms-python.vscode-pylance"
    "ms-python.black-formatter"
    "ms-python.flake8"
    "ms-python.mypy-type-checker"
)

# Custom Python installation function
install_python() {
    if [ "${UNINSTALL_MODE}" -eq 1 ]; then
        echo "🗑️  Removing Python installation..."
        
        # Remove python alias if it exists
        if grep -q "alias python=" ~/.bashrc; then
            sed -i '/alias python=/d' ~/.bashrc
            echo "✅ Python alias removed from ~/.bashrc"
        fi
        return
    fi
    
    # Check if Python is already installed
    if command -v python3 >/dev/null 2>&1; then
        local current_version=$(python3 --version | awk '{print $2}')
        echo "✅ Python is already installed (version: ${current_version})"
        
        # Ensure python command points to python3
        if ! command -v python >/dev/null 2>&1; then
            if ! grep -q "alias python=" ~/.bashrc; then
                echo "" >> ~/.bashrc
                echo "# Python environment" >> ~/.bashrc
                echo "alias python=python3" >> ~/.bashrc
                echo "alias pip=pip3" >> ~/.bashrc
                echo "✅ Python aliases added to ~/.bashrc"
            fi
        fi
        return
    fi
    
    echo "📦 Installing Python 3.11+ via apt..."
    
    # Try to install Python 3.11 or later
    if command -v python3.11 >/dev/null 2>&1; then
        echo "✅ Python 3.11 is already available"
    elif command -v python3.12 >/dev/null 2>&1; then
        echo "✅ Python 3.12 is already available"
    else
        # Install default Python 3 (usually 3.11 on modern systems)
        if sudo DEBIAN_FRONTEND=noninteractive apt-get install -y python3 python3-pip python3-venv; then
            echo "✅ Python installed successfully"
        else
            echo "❌ Failed to install Python"
            return 1
        fi
    fi
    
    # Set up Python environment
    if ! grep -q "alias python=" ~/.bashrc; then
        echo "" >> ~/.bashrc
        echo "# Python environment" >> ~/.bashrc
        echo "alias python=python3" >> ~/.bashrc
        echo "alias pip=pip3" >> ~/.bashrc
        echo "✅ Python aliases added to ~/.bashrc"
    fi
}

# Custom Python package installation function
install_python_packages() {
    if [ "${UNINSTALL_MODE}" -eq 1 ]; then
        echo "🗑️  Removing Python packages..."
        for package in "${PYTHON_PACKAGES[@]}"; do
            if python3 -m pip show "$package" >/dev/null 2>&1; then
                python3 -m pip uninstall -y "$package" >/dev/null 2>&1 || true
            fi
        done
        return
    fi
    
    if [ ${#PYTHON_PACKAGES[@]} -eq 0 ]; then
        return
    fi
    
    echo "📦 Installing Python packages..."
    
    # Upgrade pip first
    python3 -m pip install --upgrade pip --user
    
    # Install packages
    for package in "${PYTHON_PACKAGES[@]}"; do
        if ! python3 -m pip show "$package" >/dev/null 2>&1; then
            if python3 -m pip install "$package" --user; then
                echo "✅ $package installed"
            else
                echo "❌ Failed to install $package"
            fi
        else
            echo "✅ $package already installed"
        fi
    done
}

# Custom verification function
verify_installation() {
    echo "🔍 Verifying installations..."
    
    # Check Python
    if command -v python3 >/dev/null 2>&1; then
        echo "✅ Python: $(python3 --version)"
    else
        echo "❌ Python not found"
        return 1
    fi
    
    # Check pip
    if command -v pip3 >/dev/null 2>&1; then
        echo "✅ pip: $(pip3 --version)"
    else
        echo "❌ pip not found"
        return 1
    fi
    
    # Check virtual environment
    if python3 -c "import venv" >/dev/null 2>&1; then
        echo "✅ venv module available"
    else
        echo "❌ venv module not available"
        return 1
    fi
    
    # Check if python alias works
    if grep -q "alias python=" ~/.bashrc; then
        echo "✅ Python aliases configured"
    else
        echo "⚠️  Python aliases not configured (run 'source ~/.bashrc')"
    fi
}

# Custom post-installation function
post_installation_setup() {
    if [ "${UNINSTALL_MODE}" -eq 1 ]; then
        echo "🔧 Post-uninstallation cleanup..."
        return
    fi
    
    echo "🔧 Post-installation setup..."
    
    # Install Python packages
    install_python_packages
    
    # Verify installation
    verify_installation
    
    echo ""
    echo "🎉 Installation process complete for: $SCRIPT_NAME!"
    echo "Purpose: $SCRIPT_DESCRIPTION"
    echo ""
    echo "Important Notes:"
    echo "1. Python 3.11+ has been installed"
    echo "2. pip and venv are available for package management"
    echo "3. Essential development tools are installed"
    echo "4. Python aliases have been added to ~/.bashrc"
    echo "5. Restart your shell or run 'source ~/.bashrc' to use aliases"
    echo ""
    echo "Quick Start:"
    echo "- Check installation: python3 --version"
    echo "- Install packages: pip3 install package_name"
    echo "- Create virtual env: python3 -m venv myenv"
    echo "- Activate virtual env: source myenv/bin/activate"
    echo "- Run Python: python3 script.py"
    echo ""
    echo "Documentation Links:"
    echo "- Python Documentation: https://docs.python.org/"
    echo "- pip Documentation: https://pip.pypa.io/en/stable/"
    echo "- Virtual Environments: https://docs.python.org/3/tutorial/venv.html"
}

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
    echo "4. VS Code Python extensions will provide rich language support"
    echo
    echo "Quick Start:"
    echo "- Check installation: python3 --version && pip --version"
    echo "- Create virtual environment: python3 -m venv myenv"
    echo "- Activate environment: source myenv/bin/activate"
    echo "- Install packages: pip install requests"
    echo "- Run tests: pytest"
    echo
}

# Post-uninstallation notes
post_uninstallation_message() {
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

    # Auto-enable for container rebuild
    auto_enable_tool "python-development-tools" "Python Development Tools"
fi