#!/bin/bash
# File: .devcontainer.extend/project-installs.sh
# Purpose: Post-creation setup script for development container
# Called after the devcontainer is created and installs the sw needed for a spesiffic project.
# So add you stuff here and they will go into your development container.

set -e




#------------------------------------------------------------------------------
# CUSTOM PROJECT INSTALLATIONS - DEVELOPERS: EDIT THIS FUNCTION
#------------------------------------------------------------------------------
# This is the ONLY function you should modify for project-specific installations.
# Do not modify the other functions - they handle the automatic setup.
#
# Use this function to install project-specific dependencies that are not
# covered by the standard install scripts or enabled-tools.conf.
#
# Examples:
#   - Project-specific npm packages
#   - Project-specific Python packages
#   - Database setup scripts
#   - API client generation
#   - Custom configuration
#------------------------------------------------------------------------------

install_custom_project_tools() {
    # Force carriage return before starting (in case terminal state is corrupted)
    printf "\r\n"
    printf "🔧 Running custom project-specific installations...\r\n"
    printf "\r\n"

    # === ADD YOUR CUSTOM INSTALLATIONS BELOW ===

    # Example: Installing Azure Functions Core Tools
    # echo "Installing Azure Functions Core Tools..."
    # npm install -g azure-functions-core-tools@4

    # Example: Installing specific Python packages
    # echo "Installing Python packages..."
    # pip install pandas numpy matplotlib

    # Example: Installing project dependencies
    # echo "Installing project dependencies..."
    # cd /workspace
    # npm install

    # Example: Running database setup
    # echo "Setting up database..."
    # bash /workspace/scripts/db-setup.sh

    # Example: Generating API clients
    # echo "Generating API clients..."
    # bash /workspace/scripts/generate-client.sh

    # === END CUSTOM INSTALLATIONS ===

    printf "✅ Custom project installations complete\r\n"
    printf "\r\n"
}
#------------------------------------------------------------------------------







# Restore all configurations from topsecret folder
restore_all_configurations() {
    local SCRIPT_DIR="$(dirname "$(realpath "$0")")"
    local ADDITIONS_DIR="$SCRIPT_DIR/../.devcontainer/additions"

    # Source component scanner library
    # shellcheck source=/dev/null
    source "$ADDITIONS_DIR/lib/component-scanner.sh"

    echo ""
    echo "📋 Scanning for configuration scripts..."

    local restored_count=0
    local scanned_count=0

    # Discover all config scripts
    while IFS=$'\t' read -r script_basename config_name config_desc config_cat check_cmd; do
        ((scanned_count++))

        local config_path="$ADDITIONS_DIR/$script_basename"

        # Check if script supports --verify flag (non-interactive restore)
        if grep -q '= "--verify"' "$config_path" 2>/dev/null; then
            # Run with --verify flag (non-interactive, just restore from topsecret)
            # Silent if not found - user might not need this config
            if bash "$config_path" --verify 2>/dev/null; then
                echo "   ✅ $config_name restored"
                ((restored_count++))
            fi
            # Else: Silent - don't warn about missing configs
            # Tool installation will warn if a REQUIRED config is missing
        fi
    done < <(scan_config_scripts "$ADDITIONS_DIR")

    echo ""
    if [ $scanned_count -eq 0 ]; then
        echo "ℹ️  No configuration scripts found"
    elif [ $restored_count -eq 0 ]; then
        echo "ℹ️  No configurations found in topsecret (this is normal for new users)"
    else
        echo "📊 Configuration Restoration Summary:"
        echo "   ✅ Restored: $restored_count"
    fi
    echo ""
}

# Check if critical configurations are missing and warn user
check_missing_configs() {
    local missing_configs=()

    # Check Git identity
    if ! git config --global user.name >/dev/null 2>&1 || ! git config --global user.email >/dev/null 2>&1; then
        missing_configs+=("Git Identity")
    fi

    # Show warning if any critical configs are missing
    if [ ${#missing_configs[@]} -gt 0 ]; then
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "⚠️  IMPORTANT: Required Configuration Missing"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "The following configurations need to be set up:"
        for config in "${missing_configs[@]}"; do
            echo "   ❌ $config"
        done
        echo ""
        echo "📋 To configure these settings, run:"
        echo "   check-configs"
        echo ""
        echo "This will guide you through setting up your developer identity"
        echo "and other required configurations."
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
    else
        echo ""
        echo "✅ All required configurations are set"
        echo ""
    fi
}

# Main execution flow
main() {
    echo "🚀 Starting project-installs setup..."

    # Setup PATH to include devcontainer commands
    setup_devcontainer_path

    # Create dev-setup symlink for easy access
    setup_dev_setup_command

    # Mark the git folder as safe
    mark_git_folder_as_safe

    # Restore all configurations from topsecret (non-interactive)
    echo "🔐 Restoring configurations from topsecret..."
    restore_all_configurations

    # Check if critical configurations are missing and warn user
    check_missing_configs

    # Version checks
    echo "🔍 Verifying installed versions..."
    check_node_version
    check_python_version
    check_npm_packages

    # Install enabled tools automatically
    install_project_tools

    # Force terminal reset before custom installations (supervisor may have corrupted it)
    printf "\r" && sleep 0.1

    # Run custom project-specific installations
    install_custom_project_tools

    # Reset terminal again before final message
    printf "\r\n"
    sleep 0.1

    # Show completion message with helpful commands
    printf "\r\n"
    printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\r\n"
    printf "🎉 Post-creation setup complete!\r\n"
    printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\r\n"
    printf "\r\n"
    printf "📋 Quick Start:\r\n"
    printf "\r\n"
    printf "   dev-setup                 Main menu - install tools, manage services\r\n"
    printf "   check-configs             Configure required settings (Git identity, etc.)\r\n"
    printf "   dev-template              Initialize project from template\r\n"
    printf "   show-environment          Show detailed environment status\r\n"
    printf "\r\n"
    printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\r\n"
    printf "\r\n"

    # Check if Git identity is configured and show warning at the BOTTOM
    if ! git config --global user.name >/dev/null 2>&1 || ! git config --global user.email >/dev/null 2>&1; then
        printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\r\n"
        printf "⚠️  FIRST TIME SETUP REQUIRED\r\n"
        printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\r\n"
        printf "\r\n"
        printf "   Your Git identity is not configured yet.\r\n"
        printf "   This is required before you can make Git commits.\r\n"
        printf "\r\n"
        printf "   Run this command to configure it:\r\n"
        printf "     check-configs\r\n"
        printf "\r\n"
        printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\r\n"
        printf "\r\n"
    fi
}

# Check Node.js version
check_node_version() {
    echo "Checking Node.js installation..."
    if command -v node >/dev/null 2>&1; then
        NODE_VERSION=$(node --version)
        echo "✅ Node.js is installed (version: $NODE_VERSION)"
    else
        echo "❌ Node.js is not installed"
        exit 1
    fi
}

# Check Python version
check_python_version() {
    echo "Checking Python installation..."
    if command -v python >/dev/null 2>&1; then
        PYTHON_VERSION=$(python --version)
        echo "✅ Python is installed (version: $PYTHON_VERSION)"
    else
        echo "❌ Python is not installed"
        exit 1
    fi
}

# Check global npm packages versions
check_npm_packages() {
    echo "📦 Installed npm global packages:"
    npm list -g --depth=0
}

# Setup PATH to include .devcontainer directory
setup_devcontainer_path() {
    echo "🔗 Setting up PATH for devcontainer commands..."

    # Check if PATH already includes /workspace/.devcontainer
    if ! grep -q 'export PATH="/workspace/.devcontainer:$PATH"' ~/.bashrc; then
        echo '' >> ~/.bashrc
        echo '# Add devcontainer commands to PATH' >> ~/.bashrc
        echo 'export PATH="/workspace/.devcontainer:$PATH"' >> ~/.bashrc
        echo "✅ Added /workspace/.devcontainer to PATH in ~/.bashrc"
    else
        echo "✅ /workspace/.devcontainer already in PATH"
    fi

    # Export for current session
    export PATH="/workspace/.devcontainer:$PATH"
}

# Create symlink for dev-setup command (without .sh extension)
setup_dev_setup_command() {
    echo "🔗 Setting up devcontainer command symlinks..."

    # Create all command symlinks
    local commands=("dev-setup" "dev-services" "dev-template" "check-configs" "clean-devcontainer" "show-environment")
    local created=0

    for cmd in "${commands[@]}"; do
        # Check if there's a corresponding script or symlink already
        if [ -f "/workspace/.devcontainer/$cmd" ] || [ -L "/workspace/.devcontainer/$cmd" ]; then
            ((created++))
        fi
    done

    if [ $created -gt 0 ]; then
        echo "✅ Devcontainer commands available: ${commands[*]}"
    else
        echo "⚠️  Some devcontainer commands may not be available"
    fi
}

#------------------------------------------------------------------------------
# Git Infrastructure Setup
#------------------------------------------------------------------------------
# NOTE: This is infrastructure setup, NOT user configuration (that's in config-git.sh)
#
# WHY THIS IS HERE AND NOT IN config-git.sh:
# - Must run BEFORE any git commands (including config-git.sh which uses git)
# - These are container infrastructure settings, not personal user preferences
# - Same for all users, not personal (unlike name/email in config-git.sh)
#
# WHAT IT DOES:
# - safe.directory: Allows git to work with mounted volumes (security requirement)
# - core.fileMode: Ignores file permission changes (mounted volumes issue)
# - core.hideDotFiles: Shows dotfiles properly (cross-platform compatibility)
#------------------------------------------------------------------------------
mark_git_folder_as_safe() {
    # Mark workspace as safe globally (required for mounted volumes)
    git config --global --add safe.directory /workspace >/dev/null 2>&1
    git config --global --add safe.directory '*' >/dev/null 2>&1

    # Container-specific git configurations for mounted volumes
    git config --global core.fileMode false >/dev/null 2>&1      # Ignore file mode changes
    git config --global core.hideDotFiles false >/dev/null 2>&1  # Show dotfiles

    # Verify git works
    if git status &>/dev/null; then
        echo "✅ Git repository configured"
    else
        echo "❌ Git setup failed"
        echo "   Repository owner ID: $(stat -c '%u' /workspace/.git 2>/dev/null || echo 'unknown')"
        echo "   Container user ID: $(id -u)"
        return 1
    fi
}



# Run project-specific installations
install_project_tools() {
    echo "🛠️ Installing project-specific tools..."
    echo ""

    # Get script directory for relative paths
    local SCRIPT_DIR="$(dirname "$(realpath "$0")")"
    local ADDITIONS_DIR="$SCRIPT_DIR/../.devcontainer/additions"
    local ENABLED_TOOLS_CONF="$SCRIPT_DIR/enabled-tools.conf"

    # Source component scanner library
    # shellcheck source=/dev/null
    source "$ADDITIONS_DIR/lib/component-scanner.sh"

    # Source prerequisite check library
    # shellcheck source=/dev/null
    source "$ADDITIONS_DIR/lib/prerequisite-check.sh"

    # Arrays for discovered tools
    local -a TOOL_NAMES=()
    local -a TOOL_SCRIPTS=()
    local -a TOOL_CHECK_COMMANDS=()
    local -a TOOL_PREREQUISITES=()

    # Load enabled tools list
    local -a ENABLED_TOOLS=()

    echo "📋 Loading enabled tools from enabled-tools.conf..."
    if [[ -f "$ENABLED_TOOLS_CONF" ]]; then
        while IFS= read -r line; do
            # Skip comments and empty lines
            [[ "$line" =~ ^#.*$ ]] && continue
            [[ -z "$line" ]] && continue
            ENABLED_TOOLS+=("$line")
        done < "$ENABLED_TOOLS_CONF"
        echo "   Found ${#ENABLED_TOOLS[@]} enabled tools"
    else
        echo "⚠️  No enabled-tools.conf found - skipping automated tool installation"
        return 0
    fi

    # Discover available install scripts using component-scanner library
    echo ""
    echo "🔍 Discovering available tools..."

    while IFS=$'\t' read -r script_basename script_name script_desc script_cat check_cmd prereq_configs; do
        # Convert to identifier (lowercase, no spaces)
        local tool_id=$(echo "$script_name" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')

        # Check if enabled
        local is_enabled=false
        for enabled in "${ENABLED_TOOLS[@]}"; do
            if [[ "$enabled" == "$tool_id" ]]; then
                is_enabled=true
                break
            fi
        done

        if [[ "$is_enabled" == true ]]; then
            TOOL_NAMES+=("$script_name")
            TOOL_SCRIPTS+=("$script_basename")
            TOOL_CHECK_COMMANDS+=("$check_cmd")
            TOOL_PREREQUISITES+=("$prereq_configs")
            echo "   ✅ $script_name - ENABLED"
        else
            echo "   ⏸️  $script_name - disabled"
        fi
    done < <(scan_install_scripts "$ADDITIONS_DIR")

    # Install enabled tools
    if [[ ${#TOOL_NAMES[@]} -eq 0 ]]; then
        echo ""
        echo "ℹ️  No tools enabled for installation"
        return 0
    fi

    echo ""
    echo "📦 Installing enabled tools..."
    echo ""

    local installed_count=0
    local skipped_count=0

    # Disable set -e for the entire loop to prevent early exit
    set +e

    for i in "${!TOOL_NAMES[@]}"; do
        local tool_name="${TOOL_NAMES[$i]}"
        local script_name="${TOOL_SCRIPTS[$i]}"
        local check_command="${TOOL_CHECK_COMMANDS[$i]}"
        local prerequisite_configs="${TOOL_PREREQUISITES[$i]}"

        # Check if already installed
        if [[ -n "$check_command" ]] && eval "$check_command" 2>/dev/null; then
            echo "✅ $tool_name - already installed (skipping)"
            ((skipped_count++))
        else
            # Check prerequisites before installing
            local prerequisites_met=true
            if [[ -n "$prerequisite_configs" ]]; then
                if ! check_prerequisite_configs "$prerequisite_configs" "$ADDITIONS_DIR"; then
                    echo "⚠️  $tool_name - missing prerequisites"
                    show_missing_prerequisites "$prerequisite_configs" "$ADDITIONS_DIR"
                    echo ""
                    echo "  💡 To fix:"
                    echo "     1. Run: check-configs (configures all missing items)"
                    echo "     2. Or run each config script listed above"
                    echo "     3. Then re-run: bash /workspace/.devcontainer.extend/project-installs.sh"
                    echo ""
                    echo "❌ $tool_name - installation skipped (prerequisites not met)"
                    echo ""
                    prerequisites_met=false
                fi
            fi

            # Only install if prerequisites are met
            if [[ "$prerequisites_met" == true ]]; then
                echo "📦 Installing $tool_name..."
                bash "$ADDITIONS_DIR/$script_name"
                local exit_code=$?

                if [ $exit_code -eq 0 ]; then
                    echo "✅ $tool_name - installed successfully"
                    ((installed_count++))
                else
                    echo "❌ $tool_name - installation failed (exit code: $exit_code)"
                fi
                echo ""
            fi
        fi
    done

    # Re-enable set -e after the loop
    set -e

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📊 Installation Summary:"
    echo "   Installed: $installed_count"
    echo "   Skipped (already installed): $skipped_count"
    echo "   Total enabled: ${#TOOL_NAMES[@]}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Generate supervisor configs and start services (silently)
    if command -v supervisord >/dev/null 2>&1; then
        set +e
        # Run config generation silently
        bash "$SCRIPT_DIR/../.devcontainer/additions/config-supervisor.sh" > /dev/null 2>&1

        # Start supervisor if configs exist and it's not running
        if [ -d /etc/supervisor/conf.d ] && [ "$(ls -A /etc/supervisor/conf.d/*.conf 2>/dev/null)" ]; then
            if ! pgrep supervisord > /dev/null 2>&1; then
                # Start supervisord in background
                sudo supervisord -c /etc/supervisor/supervisord.conf > /dev/null 2>&1 &
                sleep 3
            else
                # Reload to pick up any new configs
                sudo supervisorctl reread > /dev/null 2>&1
                sudo supervisorctl update > /dev/null 2>&1
            fi
        fi
        set -e
    fi

    # Reset terminal state completely (config-supervisor.sh uses tee which corrupts terminal)
    # The tee command in logging.sh leaves terminal without proper CR/LF
    # Send carriage return + newline to reset cursor position
    printf "\r\n"
    # Force terminal to process the reset
    sleep 0.1
}


# Execute main with error handling to prevent container creation failure
set +e
main
exit_code=$?
set -e

if [ $exit_code -ne 0 ]; then
    echo ""
    echo "⚠️  Setup completed with warnings/errors (exit code: $exit_code)"
    echo "🔍 Check the logs above for details"
    echo "🚀 Container creation will continue despite errors"
    echo ""
fi

# Always exit successfully to allow container creation to complete
exit 0