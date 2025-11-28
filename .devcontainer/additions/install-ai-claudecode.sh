#!/bin/bash
# file: .devcontainer/additions/install-ai-claudecode.sh
#
# Usage: ./install-ai-claudecode.sh [options]
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
SCRIPT_NAME="Claude Code"
SCRIPT_DESCRIPTION="Installs Claude Code, Anthropic's terminal-based AI coding assistant with agentic capabilities and LSP integration"
SCRIPT_CATEGORY="AI_TOOLS"
CHECK_INSTALLED_COMMAND="[ -f $HOME/.local/bin/claude ] || [ -f /usr/local/bin/claude ] || command -v claude >/dev/null 2>&1"

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

        # Ensure curl is available for any future needs
        if ! command -v curl >/dev/null 2>&1; then
            echo "❌ curl is required but not installed. Installing curl..."
            sudo apt-get update -qq && sudo apt-get install -y curl
        fi

        # CRITICAL: Ensure .devcontainer.secrets folder is gitignored before storing credentials there
        ensure_devcontainer_secrets_gitignored

        # Create env-vars directory for environment configuration
        mkdir -p /workspace/.devcontainer.secrets/env-vars

        echo "✅ Pre-installation setup complete"
    fi
}

# Function to ensure .devcontainer.secrets/ is in .gitignore
ensure_devcontainer_secrets_gitignored() {
    local gitignore_file="/workspace/.gitignore"
    
    # Create .gitignore if it doesn't exist
    if [ ! -f "$gitignore_file" ]; then
        echo "⚠️  No .gitignore found, creating one..."
        touch "$gitignore_file"
    fi
    
    # Check if .devcontainer.secrets/ is already in .gitignore
    if grep -q "^.devcontainer.secrets/" "$gitignore_file" 2>/dev/null || grep -q "^# Top secret folder" "$gitignore_file" 2>/dev/null; then
        echo "✅ .devcontainer.secrets/ already in .gitignore"
        return 0
    fi
    
    # Add .devcontainer.secrets/ to .gitignore with warning comment
    echo "" >> "$gitignore_file"
    echo "# Top secret folder - contains credentials (NEVER commit)" >> "$gitignore_file"
    echo ".devcontainer.secrets/" >> "$gitignore_file"
    
    echo "✅ Added .devcontainer.secrets/ to .gitignore for credential safety"
}

# Custom Claude Code installation function
install_claude_code() {
    if [ "${UNINSTALL_MODE}" -eq 1 ]; then
        echo "🗑️ Removing Claude Code installation..."

        # Note: We preserve environment configuration files during uninstall
        echo "ℹ️  Environment configuration preserved in /workspace/.devcontainer.secrets/env-vars/"
        return
    fi
    
    # Check if Claude Code is already installed
    if command -v claude >/dev/null 2>&1; then
        local current_version=$(claude --version 2>/dev/null || echo "unknown")
        echo "✅ Claude Code is already installed (version: ${current_version})"
        return
    fi
    
    echo "📦 Installing Claude Code via npm..."
    
    # Install Claude Code globally via npm
    if npm install -g @anthropic-ai/claude-code; then
        echo "✅ Claude Code installed successfully"
    else
        echo "❌ Failed to install Claude Code via npm"
        return 1
    fi
    
    # Verify installation
    if command -v claude >/dev/null 2>&1; then
        echo "✅ Claude Code is now available: $(claude --version 2>/dev/null || echo 'installed')"
    else
        echo "❌ Claude Code installation failed - not found in PATH"
        echo "ℹ️  You may need to restart your shell or add the binary to PATH manually"
        return 1
    fi
}

# Custom configuration setup for Claude Code
setup_claude_code_config() {
    if [ "${UNINSTALL_MODE}" -eq 1 ]; then
        return
    fi

    # Note: Bashrc configuration is handled by config-ai-claudecode.sh --verify
    # which runs automatically during container startup via project-installs.sh

    # Create workspace .claude directory for project-specific settings and skills
    mkdir -p /workspace/.claude/skills

    # Create README in skills directory
    local skills_readme="/workspace/.claude/skills/README.md"
    if [ ! -f "$skills_readme" ]; then
        cat > "$skills_readme" << 'EOF'
# Claude Code Skills

This directory contains custom skills and agents for Claude Code.

## Directory Structure

- `/workspace/.claude/skills/` - Project-specific skills (committed to git)
- `/workspace/.devcontainer.secrets/env-vars/.claude-code-env` - Environment configuration (NOT in git)

## Adding Custom Skills

Create markdown files in this directory to define custom skills and agents.
See Claude Code documentation: https://docs.claude.com/en/docs/claude-code

## Authentication

Claude Code uses environment variables for authentication:
- `ANTHROPIC_BASE_URL` - LiteLLM proxy endpoint (http://localhost:8080)
- `ANTHROPIC_AUTH_TOKEN` - Your LiteLLM client API key

Configuration is managed by `config-ai-claudecode.sh` script.

## Security Note

- ✅ This skills directory IS committed to git (shared with team)
- ❌ /workspace/.devcontainer.secrets/ is gitignored and contains your API keys
EOF
        echo "✅ Created skills directory README"
    fi
}

# Define package arrays
# Note: curl and git are already in the base Docker image, no need to reinstall
SYSTEM_PACKAGES=(
    # No additional system packages needed - curl and git are in base image
)

NODE_PACKAGES=(
    # Claude Code is installed via custom function, not through standard npm process
    # This avoids double-installation
)

PYTHON_PACKAGES=(
    # No Python packages needed for Claude Code
)

PWSH_MODULES=(
    # No PowerShell modules needed for Claude Code
)

# Define VS Code extensions - Claude Code is terminal-based, no extensions needed
declare -A EXTENSIONS
# No VS Code extensions needed for this tool

# Define verification commands to run after installation
VERIFY_COMMANDS=(
    "command -v claude >/dev/null && echo '✅ Claude Code binary is available' || echo '❌ Claude Code binary not found'"
    "test -L /home/vscode/.claude-code-env && echo '✅ Environment config symlink exists' || echo '⚠️  Environment config symlink not found'"
    "test -d /workspace/.devcontainer.secrets/env-vars && echo '✅ Environment directory exists in .devcontainer.secrets/' || echo '❌ Environment directory not found'"
    "test -d /workspace/.claude/skills && echo '✅ Skills directory exists' || echo '⚠️  Skills directory not found'"
    "grep -q '.devcontainer.secrets/' /workspace/.gitignore && echo '✅ .devcontainer.secrets/ is gitignored' || echo '❌ .devcontainer.secrets/ NOT gitignored (SECURITY RISK!)'"
    "grep -q 'Claude Code environment' /home/vscode/.bashrc && echo '✅ Environment loading added to bashrc' || echo '⚠️  bashrc not configured'"
    "claude --version >/dev/null 2>&1 && echo '✅ Claude Code is functional' || echo '⚠️  Claude Code installed'"
)

# Post-installation notes
post_installation_message() {
    echo
    echo "🎉 Installation process complete for: $SCRIPT_NAME!"
    echo "Purpose: $SCRIPT_DESCRIPTION"
    echo
    echo "🔐 Configuration:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Environment  → /workspace/.devcontainer.secrets/env-vars/ (gitignored)"
    echo "  Skills       → /workspace/.claude/skills/ (in git)"
    echo "  Protected by → .gitignore includes '.devcontainer.secrets/'"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo
    echo "⚠️  IMPORTANT: Never remove '.devcontainer.secrets/' from .gitignore!"
    echo
    echo "🚀 Quick Start Guide:"
    echo "1. Configure Claude Code to use LiteLLM proxy:"
    echo "   bash .devcontainer/additions/config-ai-claudecode.sh"
    echo
    echo "2. This will prompt for your LiteLLM client API key and configure:"
    echo "   - ANTHROPIC_BASE_URL=http://localhost:8080 (nginx proxy)"
    echo "   - ANTHROPIC_AUTH_TOKEN=<your-litellm-key>"
    echo
    echo "3. After configuration, start Claude Code:"
    echo "   claude"
    echo
    echo "🔑 Authentication Details:"
    echo "- Uses LiteLLM proxy (not direct Anthropic API)"
    echo "- Environment stored in: /workspace/.devcontainer.secrets/env-vars/.claude-code-env"
    echo "- Configuration persists across container rebuilds"
    echo "- Automatically loaded in new terminals via .bashrc"
    echo
    echo "📚 Key Features:"
    echo "- ✅ Terminal-native AI assistant with agentic capabilities"
    echo "- ✅ Automatic codebase understanding and context"
    echo "- ✅ File modification and shell command execution"
    echo "- ✅ Git workflow automation"
    echo "- ✅ LSP integration for code intelligence"
    echo "- ✅ Custom skills and agents support"
    echo
    echo "⚡ Useful Commands:"
    echo "- claude --help              # Show all options"
    echo "- claude --no-auto-approve   # Require approval for each action"
    echo "- claude --dangerously-skip-permissions  # Auto-approve (use with caution)"
    echo
    echo "🎨 Customization:"
    echo "- Environment: ~/.claude-code-env (symlink to /workspace/.devcontainer.secrets/env-vars/)"
    echo "- Project skills: /workspace/.claude/skills/"
    echo "- Configuration script: .devcontainer/additions/config-ai-claudecode.sh"
    echo
    echo "📖 Documentation Links:"
    echo "- Official Documentation: https://docs.claude.com/en/docs/claude-code"
    echo "- GitHub Repository: https://github.com/anthropics/claude-code"
    echo "- Anthropic Console: https://console.anthropic.com"
    echo
    if ! command -v claude >/dev/null 2>&1; then
        echo "⚠️  Note: If 'claude' command is not found, try:"
        echo "- Restart your shell: exec \$SHELL"
        echo "- Check PATH includes: /usr/local/bin"
        echo "- Manual install: npm install -g @anthropic-ai/claude-code"
    fi
}

# Post-uninstallation notes
post_uninstallation_message() {
    echo
    echo "🏁 Uninstallation process complete for: $SCRIPT_NAME!"
    echo
    echo "📋 What was removed:"
    echo "- ✅ Claude Code npm package"
    echo
    echo "📋 What was preserved:"
    echo "- ✅ Environment configuration in /workspace/.devcontainer.secrets/env-vars/"
    echo "- ✅ Project skills in /workspace/.claude/skills/"
    echo "- ✅ Configuration and settings"
    echo
    echo "🧹 Complete Cleanup (optional):"
    echo "To remove all Claude Code data, run:"
    echo "  rm -rf /workspace/.devcontainer.secrets/env-vars/.claude-code-env"
    echo "  rm -rf /workspace/.claude/"
    echo
    echo "⚠️  Warning: This will delete your environment configuration!"
    echo
    # Verify uninstallation
    if command -v claude >/dev/null; then
        echo "⚠️  Warning: Claude Code is still accessible:"
        echo "- Location: $(which claude)"
        echo "- This may be a different installation"
    else
        echo "✅ Claude Code successfully removed from PATH"
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
    # Custom Claude Code installation first
    install_claude_code
    
    # Set up configuration
    setup_claude_code_config
    
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
    auto_enable_tool "claude-code" "Claude Code"
fi
