#!/bin/bash
# file: .devcontainer/additions/install-ai-opencode.sh
#
# Usage: ./install-ai-opencode.sh [options]
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
SCRIPT_NAME="OpenCode AI Assistant"
SCRIPT_DESCRIPTION="Installs OpenCode, a powerful terminal-based AI coding assistant with LSP integration and multi-provider support"
SCRIPT_CATEGORY="AI_TOOLS"
CHECK_INSTALLED_COMMAND="[ -f $HOME/.local/bin/opencode ] || [ -f /usr/local/bin/opencode ] || command -v opencode >/dev/null 2>&1"

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
        
        # Ensure curl is available for installation
        if ! command -v curl >/dev/null 2>&1; then
            echo "❌ curl is required but not installed. Installing curl..."
            sudo apt-get update -qq && sudo apt-get install -y curl
        fi
        
        # Create configuration directories
        mkdir -p "$HOME/.config/opencode/commands"
        mkdir -p "$HOME/.local/share/opencode"
        echo "✅ OpenCode configuration directories created"
    fi
}

# Custom OpenCode installation function
install_opencode() {
    if [ "${UNINSTALL_MODE}" -eq 1 ]; then
        echo "🗑️ Removing OpenCode installation..."
        
        # Remove binary if it exists in common locations
        if [ -f "/usr/local/bin/opencode" ]; then
            sudo rm -f "/usr/local/bin/opencode"
            echo "✅ OpenCode binary removed from /usr/local/bin/"
        fi
        
        if [ -f "$HOME/.local/bin/opencode" ]; then
            rm -f "$HOME/.local/bin/opencode"
            echo "✅ OpenCode binary removed from ~/.local/bin/"
        fi
        
        # Remove npm global package if installed via npm
        if command -v npm >/dev/null 2>&1; then
            if npm list -g opencode-ai >/dev/null 2>&1; then
                npm uninstall -g opencode-ai >/dev/null 2>&1
                echo "✅ OpenCode npm package removed"
            fi
        fi
        
        # Note: We preserve config files during uninstall
        echo "ℹ️  Configuration files preserved in ~/.config/opencode/ and ~/.local/share/opencode/"
        return
    fi
    
    # Check if OpenCode is already installed
    if command -v opencode >/dev/null 2>&1; then
        local current_version=$(opencode --version 2>/dev/null || echo "unknown")
        echo "✅ OpenCode is already installed (version: ${current_version})"
        return
    fi
    
    echo "📦 Installing OpenCode via official installer..."
    
    # Download and execute the official installation script
    if curl -fsSL https://opencode.ai/install | bash; then
        echo "✅ OpenCode installed successfully"
    else
        echo "❌ Failed to install OpenCode via installer. Trying npm fallback..."
        
        # Fallback to npm installation if available
        if command -v npm >/dev/null 2>&1; then
            if npm install -g opencode-ai@latest; then
                echo "✅ OpenCode installed successfully via npm"
            else
                echo "❌ Failed to install OpenCode via npm"
                return 1
            fi
        else
            echo "❌ npm not available for fallback installation"
            return 1
        fi
    fi
    
    # Verify installation
    if command -v opencode >/dev/null 2>&1; then
        echo "✅ OpenCode is now available: $(opencode --version 2>/dev/null || echo 'installed')"
    else
        echo "❌ OpenCode installation failed - not found in PATH"
        echo "ℹ️  You may need to restart your shell or add the binary to PATH manually"
        return 1
    fi
}

# Custom configuration setup
setup_opencode_config() {
    if [ "${UNINSTALL_MODE}" -eq 1 ]; then
        return
    fi
    
    local config_file="$HOME/.config/opencode/.opencode.json"
    
    # Only create config if it doesn't exist
    if [ ! -f "$config_file" ]; then
        echo "🔧 Creating basic OpenCode configuration..."
        
        cat > "$config_file" << 'EOF'
{
  "data": {
    "directory": ".opencode"
  },
  "providers": {
    "anthropic": {
      "disabled": false
    },
    "openai": {
      "disabled": false
    },
    "google": {
      "disabled": false
    },
    "groq": {
      "disabled": false
    }
  },
  "agents": {
    "primary": {
      "model": "claude-3.5-sonnet",
      "maxTokens": 5000
    },
    "task": {
      "model": "claude-3.5-sonnet", 
      "maxTokens": 5000
    },
    "title": {
      "model": "claude-3.5-sonnet",
      "maxTokens": 80
    }
  },
  "lsp": {
    "go": {
      "disabled": false,
      "command": "gopls"
    },
    "typescript": {
      "disabled": false,
      "command": "typescript-language-server",
      "args": ["--stdio"]
    },
    "python": {
      "disabled": false,
      "command": "pylsp"
    }
  },
  "tui": {
    "theme": "opencode"
  },
  "shell": {
    "path": "/bin/bash",
    "args": ["-l"]
  },
  "debug": false,
  "debugLSP": false
}
EOF
        echo "✅ Basic configuration created at $config_file"
    else
        echo "ℹ️  Configuration file already exists at $config_file"
    fi
    
    # Create example custom command
    local example_command="$HOME/.config/opencode/commands/project-overview.md"
    if [ ! -f "$example_command" ]; then
        cat > "$example_command" << 'EOF'
# Project Overview Command

Please analyze this project and provide a comprehensive overview:

RUN find . -name "*.md" -type f | head -10
RUN find . -name "package.json" -o -name "go.mod" -o -name "requirements.txt" -o -name "composer.json" -o -name "pom.xml" | head -5
RUN ls -la

Based on the files above, please provide:
1. Project structure overview
2. Main programming languages and frameworks used
3. Key dependencies identified
4. Suggested next steps for understanding the codebase
EOF
        echo "✅ Example custom command created: user:project-overview"
    fi
}

# Define package arrays (remove any empty arrays that aren't needed)
SYSTEM_PACKAGES=(
    "curl"
    "wget"
    "git"
)

NODE_PACKAGES=(
    # Node.js packages are not required but npm might be used as fallback
)

PYTHON_PACKAGES=(
    # No Python packages needed for OpenCode
)

PWSH_MODULES=(
    # No PowerShell modules needed for OpenCode
)

# Define VS Code extensions - OpenCode is terminal-based, no extensions needed
declare -A EXTENSIONS
# No VS Code extensions needed for this tool

# Define verification commands to run after installation
VERIFY_COMMANDS=(
    "command -v opencode >/dev/null && echo '✅ OpenCode binary is available' || echo '❌ OpenCode binary not found'"
    "test -d \$HOME/.config/opencode && echo '✅ OpenCode config directory exists' || echo '❌ OpenCode config directory not found'"
    "test -f \$HOME/.config/opencode/.opencode.json && echo '✅ OpenCode configuration file exists' || echo '❌ OpenCode configuration file not found'"
    "opencode --version >/dev/null 2>&1 && echo '✅ OpenCode is functional' || echo '⚠️  OpenCode may need authentication setup'"
)

# Post-installation notes
post_installation_message() {
    echo
    echo "🎉 Installation process complete for: $SCRIPT_NAME!"
    echo "Purpose: $SCRIPT_DESCRIPTION"
    echo
    echo "🚀 Quick Start Guide:"
    echo "1. Set up authentication: opencode auth login"
    echo "2. Navigate to your project: cd /path/to/your/project"
    echo "3. Start OpenCode: opencode"
    echo "4. Type your coding questions or requests"
    echo
    echo "🔑 Authentication Setup:"
    echo "Run 'opencode auth login' and choose from:"
    echo "- Anthropic (Claude) - Recommended for Claude Pro/Max users"
    echo "- OpenAI (GPT models)"
    echo "- Google (Gemini models)"
    echo "- Groq (Fast inference)"
    echo "- And 70+ other providers via Models.dev"
    echo
    echo "📚 Key Features:"
    echo "- ✅ Terminal-native AI assistant with beautiful TUI"
    echo "- ✅ Automatic LSP integration for code intelligence"
    echo "- ✅ Multi-session support for parallel work"
    echo "- ✅ File modification and shell command execution"
    echo "- ✅ Custom commands (try: Ctrl+K → user:project-overview)"
    echo "- ✅ Shareable session links for collaboration"
    echo
    echo "⚡ Useful Commands:"
    echo "- opencode --help           # Show all options"
    echo "- opencode -c /path         # Start in specific directory"
    echo "- opencode -p \"question\"    # Non-interactive mode"
    echo "- opencode auth logout      # Remove stored credentials"
    echo
    echo "🎨 Customization:"
    echo "- Config file: ~/.config/opencode/.opencode.json"
    echo "- Custom commands: ~/.config/opencode/commands/"
    echo "- Available themes: opencode, catppuccin, dracula, gruvbox, tokyonight"
    echo
    echo "📖 Documentation Links:"
    echo "- Official Documentation: https://opencode.ai/docs/"
    echo "- GitHub Repository: https://github.com/sst/opencode"
    echo "- Models.dev (Provider List): https://models.dev"
    echo
    if ! command -v opencode >/dev/null 2>&1; then
        echo "⚠️  Note: If 'opencode' command is not found, try:"
        echo "- Restart your shell: exec \$SHELL"
        echo "- Check PATH includes the installation directory"
        echo "- Manual install via npm: npm install -g opencode-ai@latest"
    fi
}

# Post-uninstallation notes
post_uninstallation_message() {
    echo
    echo "🏁 Uninstallation process complete for: $SCRIPT_NAME!"
    echo
    echo "📋 What was removed:"
    echo "- ✅ OpenCode binary from system PATH"
    echo "- ✅ npm global package (if installed via npm)"
    echo
    echo "📋 What was preserved:"
    echo "- ✅ Configuration files in ~/.config/opencode/"
    echo "- ✅ Data directory in ~/.local/share/opencode/"
    echo "- ✅ Custom commands and session history"
    echo
    echo "🧹 Complete Cleanup (optional):"
    echo "To remove all OpenCode data, run:"
    echo "  rm -rf ~/.config/opencode/"
    echo "  rm -rf ~/.local/share/opencode/"
    echo
    # Verify uninstallation
    if command -v opencode >/dev/null; then
        echo "⚠️  Warning: OpenCode is still accessible:"
        echo "- Location: $(which opencode)"
        echo "- This may be a different installation (homebrew, manual, etc.)"
        echo "- Consider checking: brew list | grep opencode"
    else
        echo "✅ OpenCode successfully removed from PATH"
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
source "$(dirname "$0")/core-install-apt.sh"
source "$(dirname "$0")/core-install-node.sh"
source "$(dirname "$0")/core-install-extensions.sh"
source "$(dirname "$0")/core-install-pwsh.sh"
source "$(dirname "$0")/core-install-python-packages.sh"

# Function to process installations
process_installations() {
    # Custom OpenCode installation first
    install_opencode
    
    # Set up configuration
    setup_opencode_config
    
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

    # Auto-enable for container rebuild
    auto_enable_tool "opencode-ai-assistant" "OpenCode AI Assistant"
fi