#!/bin/bash
# file: .devcontainer/additions/install-dev-typescript.sh
#
# Usage: ./install-dev-typescript.sh [options]
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
SCRIPT_ID="dev-typescript"
SCRIPT_NAME="TypeScript Development Tools"
SCRIPT_DESCRIPTION="Installs Node.js LTS, npm, TypeScript, and essential development tools"
SCRIPT_CATEGORY="LANGUAGE_DEV"
CHECK_INSTALLED_COMMAND="command -v tsc >/dev/null 2>&1 || (test -f ~/.npm-global/bin/tsc || npm list -g --depth=0 2>/dev/null | grep -q typescript)"

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
        
        # Check if Node.js is already installed
        if command -v node >/dev/null 2>&1; then
            echo "✅ Node.js is already installed (version: $(node --version))"
        fi
        
        # Check if npm is already installed
        if command -v npm >/dev/null 2>&1; then
            echo "✅ npm is already installed (version: $(npm --version))"
        fi
        
        # Update package lists
        sudo apt-get update -qq
    fi
}

# Define package arrays (remove any empty arrays that aren't needed)
SYSTEM_PACKAGES=(
    "curl"
    "ca-certificates"
    "gnupg"
    "lsb-release"
    "build-essential"
    "git"
)

NODE_PACKAGES=(
    "typescript"
    "tsx"
    "@types/node"
    "nodemon"
    "ts-node"
    "eslint"
    "prettier"
    "@typescript-eslint/parser"
    "@typescript-eslint/eslint-plugin"
    "jest"
    "@types/jest"
    "ts-jest"
)

PYTHON_PACKAGES=(
    # No Python packages needed for TypeScript development
)

VSCODE_EXTENSIONS=(
    "ms-vscode.vscode-typescript-next"
    "bradlc.vscode-tailwindcss"
    "esbenp.prettier-vscode"
    "ms-vscode.vscode-eslint"
    "ms-vscode.vscode-json"
    "ms-vscode.vscode-npm"
)

# Custom Node.js installation function
install_nodejs() {
    if [ "${UNINSTALL_MODE}" -eq 1 ]; then
        echo "🗑️  Removing Node.js installation..."
        
        # Remove Node.js packages
        sudo apt-get remove -y nodejs npm >/dev/null 2>&1 || true
        
        # Remove NodeSource repository
        if [ -f "/etc/apt/sources.list.d/nodesource.list" ]; then
            sudo rm -f "/etc/apt/sources.list.d/nodesource.list"
            echo "✅ NodeSource repository removed"
        fi
        
        # Remove GPG key
        if [ -f "/usr/share/keyrings/nodesource.gpg" ]; then
            sudo rm -f "/usr/share/keyrings/nodesource.gpg"
            echo "✅ NodeSource GPG key removed"
        fi
        
        # Remove npm global packages directory
        if [ -d "$HOME/.npm-global" ]; then
            rm -rf "$HOME/.npm-global"
            echo "✅ Global npm packages directory removed"
        fi
        
        # Remove Node.js environment from bashrc if it exists
        if grep -q "NPM_CONFIG_PREFIX" ~/.bashrc; then
            sed -i '/NPM_CONFIG_PREFIX/d' ~/.bashrc
            sed -i '/# Node.js environment/d' ~/.bashrc
            sed -i '/export PATH=.*npm-global/d' ~/.bashrc
            echo "✅ Node.js environment removed from ~/.bashrc"
        fi
        return
    fi
    
    # Check if Node.js is already installed with suitable version
    if command -v node >/dev/null 2>&1; then
        local current_version=$(node --version | sed 's/v//')
        local major_version=$(echo $current_version | cut -d. -f1)
        
        if [ "$major_version" -ge 18 ]; then
            echo "✅ Node.js is already installed (version: $current_version)"
            setup_npm_global_directory
            return
        else
            echo "⚠️  Node.js version $current_version is too old, upgrading..."
        fi
    fi
    
    echo "📦 Installing Node.js LTS via NodeSource..."
    
    # Add NodeSource repository for latest LTS Node.js
    if ! command -v node >/dev/null 2>&1 || [ "$(node --version | cut -d. -f1 | sed 's/v//')" -lt 18 ]; then
        # Download and install NodeSource signing key
        curl -fsSL https://deb.nodesource.com/gpgkey/nodesource.gpg.key | sudo gpg --dearmor -o /usr/share/keyrings/nodesource.gpg
        
        # Add NodeSource repository
        echo "deb [signed-by=/usr/share/keyrings/nodesource.gpg] https://deb.nodesource.com/node_lts.x $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/nodesource.list
        
        # Update package lists
        sudo apt-get update -qq
        
        # Install Node.js
        if sudo DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs; then
            echo "✅ Node.js installed successfully"
        else
            echo "❌ Failed to install Node.js"
            return 1
        fi
    fi
    
    # Set up npm global directory
    setup_npm_global_directory
}

# Set up npm global directory to avoid permission issues
setup_npm_global_directory() {
    if [ "${UNINSTALL_MODE}" -eq 1 ]; then
        return
    fi
    
    # Create global npm directory
    mkdir -p "$HOME/.npm-global"
    
    # Configure npm to use it
    npm config set prefix "$HOME/.npm-global"
    
    # Add to PATH if not already there
    if ! grep -q "NPM_CONFIG_PREFIX" ~/.bashrc; then
        echo "" >> ~/.bashrc
        echo "# Node.js environment" >> ~/.bashrc
        echo "export NPM_CONFIG_PREFIX=\$HOME/.npm-global" >> ~/.bashrc
        echo "export PATH=\$PATH:\$HOME/.npm-global/bin" >> ~/.bashrc
        echo "✅ Node.js environment added to ~/.bashrc"
    fi
    
    # Set for current session
    export NPM_CONFIG_PREFIX="$HOME/.npm-global"
    export PATH="$PATH:$HOME/.npm-global/bin"
}

# Custom Node.js package installation function
install_node_packages() {
    if [ "${UNINSTALL_MODE}" -eq 1 ]; then
        echo "🗑️  Removing Node.js packages..."
        for package in "${NODE_PACKAGES[@]}"; do
            if npm list -g "$package" >/dev/null 2>&1; then
                npm uninstall -g "$package" >/dev/null 2>&1 || true
            fi
        done
        return
    fi
    
    if [ ${#NODE_PACKAGES[@]} -eq 0 ]; then
        return
    fi
    
    echo "📦 Installing Node.js packages..."
    
    # Update npm first
    npm install -g npm@latest
    
    # Install packages
    for package in "${NODE_PACKAGES[@]}"; do
        if ! npm list -g "$package" >/dev/null 2>&1; then
            if npm install -g "$package"; then
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
    
    # Check Node.js
    if command -v node >/dev/null 2>&1; then
        echo "✅ Node.js: $(node --version)"
    else
        echo "❌ Node.js not found"
        return 1
    fi
    
    # Check npm
    if command -v npm >/dev/null 2>&1; then
        echo "✅ npm: $(npm --version)"
    else
        echo "❌ npm not found"
        return 1
    fi
    
    # Check TypeScript
    if command -v tsc >/dev/null 2>&1; then
        echo "✅ TypeScript: $(tsc --version)"
    else
        echo "❌ TypeScript not found"
        return 1
    fi
    
    # Check tsx
    if command -v tsx >/dev/null 2>&1; then
        echo "✅ tsx: $(tsx --version)"
    else
        echo "❌ tsx not found"
        return 1
    fi
    
    # Check global npm directory
    if [ -d "$HOME/.npm-global" ]; then
        echo "✅ Global npm directory configured"
    else
        echo "⚠️  Global npm directory not configured"
    fi
}

# Custom post-installation function
post_installation_setup() {
    if [ "${UNINSTALL_MODE}" -eq 1 ]; then
        echo "🔧 Post-uninstallation cleanup..."
        return
    fi
    
    echo "🔧 Post-installation setup..."
    
    # Install Node.js
    install_nodejs
    
    # Install Node.js packages
    install_node_packages
    
    # Verify installation
    verify_installation
    
    echo ""
    echo "🎉 Installation process complete for: $SCRIPT_NAME!"
    echo "Purpose: $SCRIPT_DESCRIPTION"
    echo ""
    echo "Important Notes:"
    echo "1. Node.js LTS has been installed"
    echo "2. npm is configured with global directory at ~/.npm-global"
    echo "3. TypeScript and tsx are available globally"
    echo "4. Essential development tools are installed"
    echo "5. Restart your shell or run 'source ~/.bashrc' to use global packages"
    echo ""
    echo "Quick Start:"
    echo "- Check installation: node --version"
    echo "- Check npm: npm --version"
    echo "- Check TypeScript: tsc --version"
    echo "- Install packages: npm install package_name"
    echo "- Install globally: npm install -g package_name"
    echo "- Compile TypeScript: tsc file.ts"
    echo "- Run TypeScript: tsx file.ts"
    echo "- Create project: npm init"
    echo ""
    echo "Documentation Links:"
    echo "- Node.js Documentation: https://nodejs.org/en/docs/"
    echo "- npm Documentation: https://docs.npmjs.com/"
    echo "- TypeScript Documentation: https://www.typescriptlang.org/docs/"
    echo "- tsx Documentation: https://github.com/esbuild-kit/tsx"
}

# Post-installation notes
post_installation_message() {
    echo
    echo "🎉 Installation process complete for: $SCRIPT_NAME!"
    echo "Purpose: $SCRIPT_DESCRIPTION"
    echo
    echo "Important Notes:"
    echo "1. Node.js and TypeScript development environment is ready"
    echo "2. Essential npm packages are installed globally"
    echo "3. TypeScript compiler and tools are available"
    echo "4. VS Code TypeScript extensions will provide rich language support"
    echo
    echo "Quick Start:"
    echo "- Check installation: node --version && npm --version && tsc --version"
    echo "- Create TypeScript project: tsc --init"
    echo "- Compile TypeScript: tsc file.ts"
    echo "- Run with tsx: tsx file.ts"
    echo "- Install packages: npm install package-name"
    echo
}

# Post-uninstallation notes
post_uninstallation_message() {
    echo
    echo "🏁 Uninstallation process complete for: $SCRIPT_NAME!"
    echo
    echo "Additional Notes:"
    echo "1. TypeScript and Node.js packages have been removed"
    echo "2. Node.js runtime may still be installed"
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
    auto_enable_tool "typescript-development-tools" "TypeScript Development Tools"
fi