#!/bin/bash
# file: .devcontainer/additions/install-dev-rust.sh
#
# Usage: ./install-dev-rust.sh [options]
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
SCRIPT_NAME="Rust Development Tools"
SCRIPT_DESCRIPTION="Installs Rust (latest stable via rustup), cargo, and sets up Rust development environment"
SCRIPT_CATEGORY="LANGUAGE_DEV"
CHECK_INSTALLED_COMMAND="[ -f $HOME/.cargo/bin/rustc ] || command -v rustc >/dev/null 2>&1"

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

        # Check if Rust is already installed
        if command -v rustc >/dev/null 2>&1; then
            echo "✅ Rust is already installed (version: $(rustc --version))"
        fi

        # Create Rust workspace directories
        mkdir -p $HOME/.cargo/bin
        echo "✅ Rust workspace directories created"
    fi
}

# Custom Rust installation function
install_rust() {
    if [ "${UNINSTALL_MODE}" -eq 1 ]; then
        echo "🗑️  Removing Rust installation..."
        
        # Remove rustup if it exists
        if command -v rustup >/dev/null 2>&1; then
            rustup self uninstall -y
            echo "✅ Rustup uninstalled"
        fi
        
        # Remove Rust environment from bashrc if it exists
        if grep -q "export RUST_HOME" ~/.bashrc; then
            sed -i '/export RUST_HOME/d' ~/.bashrc
            sed -i '/# Rust environment/d' ~/.bashrc
            sed -i '/export PATH=.*\.cargo\/bin/d' ~/.bashrc
            echo "✅ Rust environment removed from ~/.bashrc"
        fi
        
        # Remove cargo directory
        if [ -d "$HOME/.cargo" ]; then
            rm -rf "$HOME/.cargo"
            echo "✅ Cargo directory removed"
        fi
        
        # Remove rustup directory
        if [ -d "$HOME/.rustup" ]; then
            rm -rf "$HOME/.rustup"
            echo "✅ Rustup directory removed"
        fi
        
        return
    fi
    
    # Check if Rust is already installed
    if command -v rustc >/dev/null 2>&1 && command -v cargo >/dev/null 2>&1; then
        local current_version=$(rustc --version | awk '{print $2}')
        echo "✅ Rust is already installed (version: ${current_version})"
        
        # Ensure PATH is set
        if [ -d "$HOME/.cargo/bin" ] && [[ ":$PATH:" != *":$HOME/.cargo/bin:"* ]]; then
            if ! grep -q "export PATH.*\.cargo/bin" ~/.bashrc; then
                echo "" >> ~/.bashrc
                echo "# Rust environment" >> ~/.bashrc
                echo "export PATH=\"\$HOME/.cargo/bin:\$PATH\"" >> ~/.bashrc
                echo "✅ Rust PATH added to ~/.bashrc"
            fi
        fi
        return
    fi
    
    echo "📦 Installing latest stable Rust via rustup..."
    
    # Download and install rustup
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable
    
    # Source the cargo environment
    source $HOME/.cargo/env
    
    # Add to PATH in bashrc if not already there
    if ! grep -q "export PATH.*\.cargo/bin" ~/.bashrc; then
        echo "" >> ~/.bashrc
        echo "# Rust environment" >> ~/.bashrc
        echo "export PATH=\"\$HOME/.cargo/bin:\$PATH\"" >> ~/.bashrc
        echo "✅ Rust environment added to ~/.bashrc"
    fi
    
    # Verify installation
    if command -v rustc >/dev/null 2>&1 && command -v cargo >/dev/null 2>&1; then
        echo "✅ Rust is now available: $(rustc --version)"
        echo "✅ Cargo is now available: $(cargo --version)"
    else
        echo "❌ Rust installation failed - not found in PATH"
        return 1
    fi
    
    # Install useful cargo tools
    echo "📦 Installing useful cargo tools..."
    
    # Install cargo tools one by one with proper output handling
    local tools=("cargo-edit" "cargo-watch" "cargo-outdated")
    for tool in "${tools[@]}"; do
        echo "  Installing $tool..."
        if cargo install "$tool" >/dev/null 2>&1; then
            echo "  ✅ $tool installed successfully"
        else
            echo "  ⚠️  $tool installation failed (continuing...)"
        fi
    done
    
    echo "✅ Cargo tools installation completed"
}

# Define package arrays (remove any empty arrays that aren't needed)
SYSTEM_PACKAGES=(
    "build-essential"
    "pkg-config"
    "libssl-dev"
)

NODE_PACKAGES=(
    # No Node.js packages needed for Rust development
)

PYTHON_PACKAGES=(
    # No Python packages needed for Rust development  
)

PWSH_MODULES=(
    # No PowerShell modules needed for Rust development
)

# Define VS Code extensions
declare -A EXTENSIONS
EXTENSIONS["rust-lang.rust-analyzer"]="Rust Analyzer|Rust language support with rust-analyzer"
EXTENSIONS["vadimcn.vscode-lldb"]="CodeLLDB|Native debugger for Rust"
EXTENSIONS["serayuzgur.crates"]="Crates|Helps manage Rust dependencies"

# Define verification commands to run after installation
VERIFY_COMMANDS=(
    "command -v rustc >/dev/null && echo '✅ Rust compiler is available' || echo '❌ Rust compiler not found'"
    "command -v cargo >/dev/null && echo '✅ Cargo is available' || echo '❌ Cargo not found'"
    "command -v rustup >/dev/null && echo '✅ Rustup is available' || echo '❌ Rustup not found'"
    "test -d \$HOME/.cargo && echo '✅ Cargo directory exists' || echo '❌ Cargo directory not found'"
)

# Post-installation notes
post_installation_message() {
    echo
    echo "🎉 Installation process complete for: $SCRIPT_NAME!"
    echo "Purpose: $SCRIPT_DESCRIPTION"
    echo
    echo "Important Notes:"
    echo "1. Rust stable has been installed via rustup"
    echo "2. Cargo (package manager) is available"
    echo "3. Rust tools are available in \$HOME/.cargo/bin"
    echo "4. VS Code Rust extensions will provide rich language support"
    echo "5. Additional cargo tools installed: cargo-edit, cargo-watch, cargo-outdated"
    echo
    echo "Quick Start:"
    echo "- Check installation: rustc --version && cargo --version"
    echo "- Create a new project: cargo new my_project"
    echo "- Build project: cargo build"
    echo "- Run project: cargo run"
    echo "- Add dependency: cargo add serde"
    echo "- Update dependencies: cargo update"
    echo
    echo "Documentation Links:"
    echo "- Rust Documentation: https://doc.rust-lang.org/"
    echo "- Cargo Book: https://doc.rust-lang.org/cargo/"
    echo "- Rust By Example: https://doc.rust-lang.org/rust-by-example/"
    echo "- VS Code Rust Extension: https://marketplace.visualstudio.com/items?itemName=rust-lang.rust-analyzer"
}

# Post-uninstallation notes
post_uninstallation_message() {
    echo
    echo "🏁 Uninstallation process complete for: $SCRIPT_NAME!"
    echo
    echo "Additional Notes:"
    echo "1. Rustup has been uninstalled"
    echo "2. Rust environment variables have been removed from ~/.bashrc"
    echo "3. Cargo and rustup directories have been removed"
    echo "4. You may need to restart your shell for changes to take effect"
    
    # Check if Rust is still accessible
    if command -v rustc >/dev/null; then
        echo
        echo "⚠️  Warning: Rust is still accessible in PATH:"
        echo "- Location: $(which rustc)"
        echo "- This may be a different Rust installation"
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
source "${SCRIPT_DIR}/lib/core-install-node.sh"
source "${SCRIPT_DIR}/lib/core-install-extensions.sh"
source "${SCRIPT_DIR}/lib/core-install-pwsh.sh"
source "${SCRIPT_DIR}/lib/core-install-python-packages.sh"

# Source common installation patterns library
source "${SCRIPT_DIR}/lib/install-common.sh"

# Function to process installations
process_installations() {
    # Custom Rust installation first
    install_rust
    
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
    auto_enable_tool "rust-development-tools" "Rust Development Tools"
fi