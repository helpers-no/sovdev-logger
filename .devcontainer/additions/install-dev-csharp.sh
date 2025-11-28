#!/bin/bash
# file: .devcontainer/additions/install-dev-csharp.sh
#
# Usage: ./install-dev-csharp.sh [options]
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
SCRIPT_ID="dev-csharp"
SCRIPT_NAME="C# Development Tools"
SCRIPT_DESCRIPTION="Complete .NET 8.0 development environment with Azure Functions, Bicep IaC, storage emulation, and VS Code extensions"
SCRIPT_CATEGORY="LANGUAGE_DEV"
CHECK_INSTALLED_COMMAND="[ -f $HOME/.dotnet/dotnet ] || [ -f /usr/bin/dotnet ] || command -v dotnet >/dev/null 2>&1"

#------------------------------------------------------------------------------

# Source auto-enable library
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/tool-auto-enable.sh"

# Source logging library
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/logging.sh"

#------------------------------------------------------------------------------

# Before running installation, we need to add any required repositories
pre_installation_setup() {
    if [ "${UNINSTALL_MODE}" -eq 1 ]; then
        echo "🔧 Preparing for uninstallation..."
    else
        echo "🔧 Performing pre-installation setup..."

        # Add Microsoft repository manually (container-friendly approach)
        local repo_file="/etc/apt/sources.list.d/microsoft-prod.list"
        
        # Remove old repository file if it exists with incorrect content
        if [ -f "$repo_file" ] && grep -q "microsoft-ubuntu-bookworm-prod" "$repo_file"; then
            echo "Removing incorrect repository configuration..."
            sudo rm -f "$repo_file"
        fi
        
        if [ ! -f "$repo_file" ]; then
            echo "Adding Microsoft repository..."
            sudo DEBIAN_FRONTEND=noninteractive apt-get update -qq
            sudo DEBIAN_FRONTEND=noninteractive apt-get install -y software-properties-common curl gnupg2 lsb-release
            
            # Add Microsoft repository key (force overwrite to avoid prompts)
            curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | sudo gpg --yes --dearmor -o /etc/apt/trusted.gpg.d/microsoft.gpg
            
            # Add repository source (use Debian repository for Debian-based containers)
            local distro_id=$(lsb_release -is | tr '[:upper:]' '[:lower:]')
            local distro_version=$(lsb_release -rs)
            local distro_codename=$(lsb_release -cs)
            
            if [[ "$distro_id" == "debian" ]]; then
                # Use Debian repository
                echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/trusted.gpg.d/microsoft.gpg] https://packages.microsoft.com/debian/${distro_version%%.*}/prod ${distro_codename} main" | sudo tee "$repo_file"
            else
                # Use Ubuntu repository
                echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/trusted.gpg.d/microsoft.gpg] https://packages.microsoft.com/repos/microsoft-ubuntu-${distro_codename}-prod ${distro_codename} main" | sudo tee "$repo_file"
            fi
            
            # Update package lists
            sudo DEBIAN_FRONTEND=noninteractive apt-get update -qq
            echo "✅ Microsoft repository added successfully"
        else
            echo "✅ Microsoft repository already configured"
        fi

        # Ensure package lists are up to date
        echo "Updating package lists..."
        sudo apt-get update

        # Display current .NET version if installed
        if command -v dotnet >/dev/null 2>&1; then
            echo ".NET SDK version:"
            dotnet --info | grep -E "Version|OS|RID"
        fi
    fi
}

# Custom function to install Azure Functions Core Tools (cross-platform)
install_azure_functions() {
    if [ "${UNINSTALL_MODE}" -eq 1 ]; then
        if command -v func >/dev/null 2>&1; then
            echo "Removing Azure Functions Core Tools..."
            # Remove npm global installation
            npm uninstall -g azure-functions-core-tools 2>/dev/null || true
            sudo rm -f /usr/local/bin/func
            echo "✅ Azure Functions Core Tools removed"
        fi
    else
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
                if curl -L -o func.zip "$download_url"; then
                    unzip -q func.zip
                    sudo mv func /usr/local/bin/
                    sudo chmod +x /usr/local/bin/func
                    echo "✅ Azure Functions Core Tools installed for x86_64"
                else
                    echo "⚠️  Failed to download Azure Functions Core Tools"
                    echo "   Trying npm fallback..."
                    if npm install -g azure-functions-core-tools@4; then
                        echo "✅ Azure Functions Core Tools installed via npm fallback"
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
                if npm install -g azure-functions-core-tools@4.0.7332-preview1; then
                    echo "✅ Azure Functions Core Tools (ARM64 preview) installed via npm"
                else
                    echo "⚠️  ARM64 preview installation failed, trying standard version"
                    if npm install -g azure-functions-core-tools@4; then
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
                if npm install -g azure-functions-core-tools@4; then
                    echo "✅ Azure Functions Core Tools installed via npm"
                else
                    echo "❌ Failed to install Azure Functions Core Tools"
                fi
                ;;
        esac
    fi
}

# Custom function to ensure .NET is properly installed
install_dotnet() {
    if [ "${UNINSTALL_MODE}" -eq 1 ]; then
        if command -v dotnet >/dev/null 2>&1; then
            echo "Removing .NET SDK..."
            sudo apt-get remove -y dotnet-sdk-8.0 aspnetcore-runtime-8.0 || true
            # Also remove user installation if it exists
            rm -rf ~/.dotnet 2>/dev/null || true
            echo "✅ .NET SDK removed"
        fi
    else
        echo "Installing .NET SDK 8.0..."
        
        # Method 1: Try apt installation first
        if sudo DEBIAN_FRONTEND=noninteractive apt-get install -y dotnet-sdk-8.0 aspnetcore-runtime-8.0; then
            echo "✅ .NET SDK installed via apt"
        else
            echo "⚠️  apt installation failed, trying Microsoft install script..."
            
            # Method 2: Fallback to Microsoft install script
            curl -sSL https://dot.net/v1/dotnet-install.sh | bash /dev/stdin --channel 8.0
            
            # Add to PATH for current session and future sessions
            export DOTNET_ROOT=$HOME/.dotnet
            export PATH=$PATH:$HOME/.dotnet:$HOME/.dotnet/tools
            
            # Add to bashrc if not already there
            if ! grep -q "DOTNET_ROOT" ~/.bashrc; then
                echo 'export DOTNET_ROOT=$HOME/.dotnet' >> ~/.bashrc
                echo 'export PATH=$PATH:$HOME/.dotnet:$HOME/.dotnet/tools' >> ~/.bashrc
            fi
            
            echo "✅ .NET SDK installed via Microsoft script"
        fi
        
        # Verify installation
        if command -v dotnet >/dev/null 2>&1; then
            echo "✅ .NET SDK verification successful: $(dotnet --version)"
        else
            echo "❌ .NET SDK installation failed"
            exit 1
        fi
    fi
}

# Define system packages (empty since we handle .NET custom)
SYSTEM_PACKAGES=()

# Define Node.js packages (for Azure Functions Core Tools)
NODE_PACKAGES=(
    "azurite"
)

# Define VS Code extensions (format: "Name (extension-id) - Description")
EXTENSIONS=(
    "C# Dev Kit (ms-dotnettools.csdevkit) - Complete C# development experience"
    "C# (ms-dotnettools.csharp) - C# language support"
    ".NET Runtime (ms-dotnettools.vscode-dotnet-runtime) - .NET runtime support"
)

# Define verification commands (using proper command substitution to avoid early evaluation)
VERIFY_COMMANDS=(
    'if command -v dotnet >/dev/null; then echo "✅ .NET SDK: $(dotnet --version)"; else echo "❌ .NET SDK not found"; fi'
    'if dotnet --list-sdks | grep -q "8.0"; then echo "✅ .NET SDK 8.0 is installed"; else echo "❌ .NET SDK 8.0 not found"; fi'
    'if command -v func >/dev/null; then echo "✅ Azure Functions Core Tools: $(func --version)"; else echo "❌ Azure Functions Core Tools not found"; fi'
    'if code --list-extensions | grep -q ms-dotnettools.csdevkit; then echo "✅ C# Dev Kit is installed"; else echo "❌ C# Dev Kit not installed"; fi'
)

# Post-installation notes
post_installation_message() {
    local dotnet_version
    local func_version

    # Ensure .NET is in PATH for this session
    export DOTNET_ROOT=$HOME/.dotnet
    export PATH=$PATH:$HOME/.dotnet:$HOME/.dotnet/tools

    if command -v dotnet >/dev/null 2>&1; then
        dotnet_version=$(dotnet --version)
    else
        dotnet_version="not installed"
    fi

    if command -v func >/dev/null 2>&1; then
        func_version=$(func --version)
    else
        func_version="not installed"
    fi

    echo
    echo "🎉 Installation process complete for: $SCRIPT_NAME!"
    echo "Purpose: $SCRIPT_DESCRIPTION"
    echo
    echo "Important Notes:"
    echo "1. .NET SDK $dotnet_version is installed"
    echo "2. Azure Functions Core Tools $func_version is installed"
    echo "3. C# Dev Kit and required extensions are ready to use"
    echo "4. ASP.NET Core Runtime 8.0 is installed for hosting web apps"
    echo
    echo "Quick Start Commands:"
    echo "- Create new console app: dotnet new console"
    echo "- Create new web API: dotnet new webapi"
    echo "- Create new Azure Function: func new"
    echo "- Run project: dotnet run"
    echo "- Build project: dotnet build"
    echo "- Run tests: dotnet test"
    echo
    echo "Documentation Links:"
    echo "- Local Guide: .devcontainer/howto/howto-dev-csharp.md"
    echo "- .NET Documentation: https://learn.microsoft.com/dotnet/"
    echo "- Azure Functions: https://learn.microsoft.com/azure/azure-functions/"
    echo "- C# Dev Kit: https://marketplace.visualstudio.com/items?itemName=ms-dotnettools.csdevkit"
    echo "- Azure Functions Core Tools: https://github.com/Azure/azure-functions-core-tools"

    # Show detailed installation status
    echo
    echo "Installation Status:"
    echo "1. .NET Information:"
    dotnet --info | grep -E "Version|OS|RID"
    echo
    echo "2. Installed SDKs:"
    dotnet --list-sdks
    echo
    echo "3. Installed Runtimes:"
    dotnet --list-runtimes
    echo
    echo "4. Azure Functions Core Tools:"
    func --version
}

# Post-uninstallation notes
post_uninstallation_message() {
    echo
    echo "🏁 Uninstallation process complete for: $SCRIPT_NAME!"
    echo
    echo "Additional Notes:"
    echo "1. Global .NET tools remain in ~/.dotnet/tools"
    echo "2. NuGet package cache remains in ~/.nuget"
    echo "3. User settings and configurations remain unchanged"
    echo "4. See the local guide for additional cleanup steps:"
    echo "   .devcontainer/howto/howto-dev-csharp.md"

    # Check for remaining components
    echo
    echo "Checking for remaining components..."

    if command -v dotnet >/dev/null 2>&1; then
        echo
        echo "⚠️  Warning: .NET SDK is still installed"
        echo "To completely remove .NET, run:"
        echo "  sudo apt-get remove dotnet* aspnetcore*"
        echo "  sudo apt-get autoremove"
        echo "Optional: remove user directories:"
        echo "  rm -rf ~/.dotnet"
        echo "  rm -rf ~/.nuget"
    fi

    if command -v func >/dev/null 2>&1; then
        echo
        echo "⚠️  Warning: Azure Functions Core Tools is still installed"
        echo "To remove it, run: npm uninstall -g azure-functions-core-tools"
    fi

    # Check for remaining VS Code extensions
    local extensions=(
        "ms-dotnettools.csdevkit"
        "ms-dotnettools.csharp"
        "ms-dotnettools.vscode-dotnet-runtime"
        "ms-azuretools.vscode-azurefunctions"
        "ms-azuretools.azure-dev"
    )

    local has_extensions=0
    for ext in "${extensions[@]}"; do
        if code --list-extensions | grep -q "$ext"; then
            if [ $has_extensions -eq 0 ]; then
                echo
                echo "⚠️  Note: Some VS Code extensions are still installed:"
                has_extensions=1
            fi
            echo "- $ext"
        fi
    done

    if [ $has_extensions -eq 1 ]; then
        echo "To remove them, run:"
        for ext in "${extensions[@]}"; do
            echo "code --uninstall-extension $ext"
        done
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

# Note: lib/install-common.sh already sourced earlier (needed for --help)

# Function to process installations
process_installations() {
    # Install .NET SDK first (custom function with fallback)
    install_dotnet

    # Install Azure Functions Core Tools for ARM64
    install_azure_functions

    # Then use standard processing from lib/install-common.sh
    process_standard_installations
}

# Function to verify installations
verify_installations() {
    # Ensure .NET is in PATH for verification
    export DOTNET_ROOT=$HOME/.dotnet
    export PATH=$PATH:$HOME/.dotnet:$HOME/.dotnet/tools

    # Use common verification from lib/install-common.sh
    # (imported above via source)
    if [ ${#VERIFY_COMMANDS[@]} -gt 0 ]; then
        echo
        echo "🔍 Verifying installations..."
        for cmd in "${VERIFY_COMMANDS[@]}"; do
            if ! eval "$cmd" 2>/dev/null; then
                echo "  ❌ Verification failed for: $cmd"
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
    # Extension state check removed - extensions are properly handled by process_extensions
    post_uninstallation_message
else
    echo "🔄 Starting installation process for: $SCRIPT_NAME"
    echo "Purpose: $SCRIPT_DESCRIPTION"
    pre_installation_setup
    process_installations
    verify_installations
    # Extension state check removed - extensions are properly handled by process_extensions
    post_installation_message

    # Auto-enable for container rebuild
    auto_enable_tool "c#-development-tools" "C# Development Tools"
fi
