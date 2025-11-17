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
        
        # CRITICAL: Ensure topsecret folder is gitignored before storing credentials there
        ensure_topsecret_gitignored
        
        # Create credentials directory in gitignored topsecret folder
        mkdir -p /workspace/topsecret/.claude-credentials
        
        # Create symlink from home to persistent location
        if [ ! -L "/home/vscode/.claude" ] && [ ! -d "/home/vscode/.claude" ]; then
            ln -sf /workspace/topsecret/.claude-credentials /home/vscode/.claude
            echo "✅ Claude credentials will persist in topsecret/ folder (gitignored)"
        elif [ -L "/home/vscode/.claude" ]; then
            echo "✅ Symlink already exists for Claude credentials"
        else
            echo "⚠️  /home/vscode/.claude already exists as directory (not symlink)"
        fi
        
        echo "✅ Pre-installation setup complete"
    fi
}

# Function to ensure topsecret/ is in .gitignore
ensure_topsecret_gitignored() {
    local gitignore_file="/workspace/.gitignore"
    
    # Create .gitignore if it doesn't exist
    if [ ! -f "$gitignore_file" ]; then
        echo "⚠️  No .gitignore found, creating one..."
        touch "$gitignore_file"
    fi
    
    # Check if topsecret/ is already in .gitignore
    if grep -q "^topsecret/" "$gitignore_file" 2>/dev/null || grep -q "^# Top secret folder" "$gitignore_file" 2>/dev/null; then
        echo "✅ topsecret/ already in .gitignore"
        return 0
    fi
    
    # Add topsecret/ to .gitignore with warning comment
    echo "" >> "$gitignore_file"
    echo "# Top secret folder - contains credentials (NEVER commit)" >> "$gitignore_file"
    echo "topsecret/" >> "$gitignore_file"
    
    echo "✅ Added topsecret/ to .gitignore for credential safety"
}

# Custom Claude Code installation function
install_claude_code() {
    if [ "${UNINSTALL_MODE}" -eq 1 ]; then
        echo "🗑️ Removing Claude Code installation..."
        
        # Remove symlink if it exists
        if [ -L "/home/vscode/.claude" ]; then
            rm -f "/home/vscode/.claude"
            echo "✅ Claude credentials symlink removed"
        fi
        
        # Note: We preserve credential files during uninstall
        echo "ℹ️  Credential files preserved in /workspace/topsecret/.claude-credentials/"
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
    
    # Create workspace .claude directory for project-specific settings and skills
    mkdir -p /workspace/.claude/skills
    
    # Create basic settings.json if it doesn't exist (for permission controls)
    local settings_file="/workspace/topsecret/.claude-credentials/settings.json"
    
    if [ ! -f "$settings_file" ]; then
        echo "🔧 Creating security-focused Claude Code configuration..."
        
        cat > "$settings_file" << 'EOF'
{
  "permissions": {
    "deny": [
      "Read(./.env)",
      "Read(./.env.*)",
      "Read(./secrets/**)",
      "Read(./topsecret/**)",
      "Read(./config/credentials.json)",
      "Read(**/*.key)",
      "Read(**/*.pem)",
      "Read(**/*_rsa)",
      "Read(**/*.p12)",
      "Read(**/*.pfx)"
    ]
  }
}
EOF
        echo "✅ Security configuration created with sensitive file protections"
    else
        echo "ℹ️  Configuration file already exists"
    fi
    
    # Create README in skills directory
    local skills_readme="/workspace/.claude/skills/README.md"
    if [ ! -f "$skills_readme" ]; then
        cat > "$skills_readme" << 'EOF'
# Claude Code Skills

This directory contains custom skills and agents for Claude Code.

## Directory Structure

- `/workspace/.claude/skills/` - Project-specific skills (committed to git)
- `/home/vscode/.claude/` - Personal credentials and settings (NOT in git, stored in topsecret/)

## Adding Custom Skills

Create markdown files in this directory to define custom skills and agents.
See Claude Code documentation: https://docs.claude.com/en/docs/claude-code

## Security Note

- ✅ This skills directory IS committed to git (shared with team)
- ❌ Credentials in /home/vscode/.claude/ are NOT committed (stored in topsecret/)
- ❌ /workspace/topsecret/ is gitignored and contains your API keys
EOF
        echo "✅ Created skills directory README"
    fi
}

# Define package arrays
SYSTEM_PACKAGES=(
    "curl"
    "git"
)

NODE_PACKAGES=(
    "@anthropic-ai/claude-code"
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
    "test -L /home/vscode/.claude && echo '✅ Claude credentials symlink exists' || echo '⚠️  Credentials symlink not found'"
    "test -d /workspace/topsecret/.claude-credentials && echo '✅ Credentials directory exists in topsecret/' || echo '❌ Credentials directory not found'"
    "test -d /workspace/.claude/skills && echo '✅ Skills directory exists' || echo '⚠️  Skills directory not found'"
    "grep -q 'topsecret/' /workspace/.gitignore && echo '✅ topsecret/ is gitignored' || echo '❌ topsecret/ NOT gitignored (SECURITY RISK!)'"
    "claude --version >/dev/null 2>&1 && echo '✅ Claude Code is functional' || echo '⚠️  Claude Code may need authentication setup'"
)

# Post-installation notes
post_installation_message() {
    echo
    echo "🎉 Installation process complete for: $SCRIPT_NAME!"
    echo "Purpose: $SCRIPT_DESCRIPTION"
    echo
    echo "🔐 Security Configuration:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Credentials → /workspace/topsecret/.claude-credentials/ (gitignored)"
    echo "  Symlinked to → /home/vscode/.claude/"
    echo "  Skills       → /workspace/.claude/skills/ (in git)"
    echo "  Protected by → .gitignore includes 'topsecret/'"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo
    echo "⚠️  IMPORTANT: Never remove 'topsecret/' from .gitignore!"
    echo
    echo "🚀 Quick Start Guide:"
    echo "1. Set up authentication:"
    echo "   claude login"
    echo "   OR"
    echo "   claude setup-token"
    echo
    echo "2. Navigate to your project:"
    echo "   cd /workspace"
    echo
    echo "3. Start Claude Code:"
    echo "   claude"
    echo
    echo "4. Ask Claude to help with your code!"
    echo
    echo "🔑 Authentication Details:"
    echo "- Your API key will be stored in: /workspace/topsecret/.claude-credentials/"
    echo "- This location is gitignored and will persist across container rebuilds"
    echo "- Project skills in /workspace/.claude/skills/ are shared with your team"
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
    echo "- Settings: /home/vscode/.claude/settings.json"
    echo "- Project skills: /workspace/.claude/skills/"
    echo "- Security rules: Already configured to deny access to sensitive files"
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
    echo "- ✅ Symlink from /home/vscode/.claude/"
    echo
    echo "📋 What was preserved:"
    echo "- ✅ Credential files in /workspace/topsecret/.claude-credentials/"
    echo "- ✅ Project skills in /workspace/.claude/skills/"
    echo "- ✅ Configuration and settings"
    echo
    echo "🧹 Complete Cleanup (optional):"
    echo "To remove all Claude Code data, run:"
    echo "  rm -rf /workspace/topsecret/.claude-credentials/"
    echo "  rm -rf /workspace/.claude/"
    echo
    echo "⚠️  Warning: This will delete your API keys and all configuration!"
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
source "$(dirname "$0")/core-install-apt.sh"
source "$(dirname "$0")/core-install-node.sh"
source "$(dirname "$0")/core-install-extensions.sh"
source "$(dirname "$0")/core-install-pwsh.sh"
source "$(dirname "$0")/core-install-python-packages.sh"

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
    auto_enable_tool "claude-code" "Claude Code"
fi
