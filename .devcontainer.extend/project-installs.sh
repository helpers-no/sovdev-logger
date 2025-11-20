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
    echo ""
    echo "🔧 Running custom project-specific installations..."
    echo ""

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

    echo "✅ Custom project installations complete"
    echo ""
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

# Main execution flow
main() {
    echo "🚀 Starting project-installs setup..."

    # Create dev-setup symlink for easy access
    setup_dev_setup_command

    # Mark the git folder as safe
    mark_git_folder_as_safe

    # Configure Git user identity
    configure_git_identity

    # Restore all configurations from topsecret (non-interactive)
    echo "🔐 Restoring configurations from topsecret..."
    restore_all_configurations

    # Version checks
    echo "🔍 Verifying installed versions..."
    check_node_version
    check_python_version
    check_npm_packages

    # Install enabled tools automatically
    install_project_tools

    # Run custom project-specific installations
    install_custom_project_tools

    echo "🎉 Post-creation setup complete!"
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


# Configure Git user identity from repository or default values
configure_git_identity() {
    echo "🔑 Setting up Git identity..."

    # First try to extract Git identity from repository configuration
    REPO_USER_NAME=""
    REPO_USER_EMAIL=""
    
    # Check if .git/config exists and is readable
    if [ -f "/workspace/.git/config" ] && [ -r "/workspace/.git/config" ]; then
        echo "📚 Attempting to read Git identity from repository..."
        
        # Try to extract user.name from repository config
        if grep -q "name = " "/workspace/.git/config"; then
            REPO_USER_NAME=$(grep "name = " "/workspace/.git/config" | head -n 1 | cut -d= -f2 | tr -d '[:space:]')
            echo "   Found name in repo: ${REPO_USER_NAME}"
        fi
        
        # Try to extract user.email from repository config
        if grep -q "email = " "/workspace/.git/config"; then
            REPO_USER_EMAIL=$(grep "email = " "/workspace/.git/config" | head -n 1 | cut -d= -f2 | tr -d '[:space:]')
            echo "   Found email in repo: ${REPO_USER_EMAIL}"
        fi
    fi
    
    # Alternative approach - check repository's commit history
    if [ -z "$REPO_USER_NAME" ] || [ -z "$REPO_USER_EMAIL" ]; then
        echo "🔍 Checking repository commit history..."
        
        # Check for user info in last commit (if available)
        if git log -1 --pretty=format:"%an:%ae" > /dev/null 2>&1; then
            COMMIT_INFO=$(git log -1 --pretty=format:"%an:%ae")
            COMMIT_NAME=$(echo "$COMMIT_INFO" | cut -d: -f1)
            COMMIT_EMAIL=$(echo "$COMMIT_INFO" | cut -d: -f2)
            
            # Use commit info if available
            if [ -n "$COMMIT_NAME" ] && [ -z "$REPO_USER_NAME" ]; then
                REPO_USER_NAME="$COMMIT_NAME"
                echo "   Found name in commit: ${REPO_USER_NAME}"
            fi
            
            if [ -n "$COMMIT_EMAIL" ] && [ -z "$REPO_USER_EMAIL" ]; then
                REPO_USER_EMAIL="$COMMIT_EMAIL"
                echo "   Found email in commit: ${REPO_USER_EMAIL}"
            fi
        fi
    fi
    
    # If we found both name and email from repo, use them
    if [ -n "$REPO_USER_NAME" ] && [ -n "$REPO_USER_EMAIL" ]; then
        GIT_USER_NAME="$REPO_USER_NAME"
        GIT_USER_EMAIL="$REPO_USER_EMAIL"
        echo "✅ Using Git identity from repository"
    else
        # Fallback to environment variables as before
        echo "⚠️ Could not find complete Git identity in repository"
        echo "   Using default values based on system username"
        
        # For Mac users
        if [ -n "$DEV_MAC_USER" ]; then
            GIT_USER_NAME="${DEV_MAC_USER}"
            GIT_USER_EMAIL="${DEV_MAC_USER}@example.com"
        # For Windows users
        elif [ -n "$DEV_WIN_USERNAME" ]; then
            GIT_USER_NAME="${DEV_WIN_USERNAME}"
            GIT_USER_EMAIL="${DEV_WIN_USERNAME}@example.com"
        else
            # Last resort fallback values
            GIT_USER_NAME="VSCode User"
            GIT_USER_EMAIL="vscode@container"
        fi
    fi

    # Set Git user configuration
    git config --global user.name "${GIT_USER_NAME}"
    git config --global user.email "${GIT_USER_EMAIL}"
    
    # Verify configuration
    echo "✅ Git identity configured:"
    echo "   Name: $(git config --global user.name)"
    echo "   Email: $(git config --global user.email)"
    
    # Remind user to update if needed
    echo "📝 Note: You can update your Git identity by running:"
    echo "   git config --global user.name \"Your Name\""
    echo "   git config --global user.email \"your.email@example.com\""
}


# Create symlink for dev-setup command (without .sh extension)
setup_dev_setup_command() {
    echo "🔗 Setting up dev-setup command..."
    
    if [ -f "/workspace/.devcontainer/dev-setup.sh" ]; then
        # Create symlink without .sh extension
        ln -sf /workspace/.devcontainer/dev-setup.sh /workspace/.devcontainer/dev-setup
        
        if [ -L "/workspace/.devcontainer/dev-setup" ]; then
            echo "✅ dev-setup command is now available (type: dev-setup)"
        else
            echo "⚠️  Failed to create dev-setup symlink"
        fi
    else
        echo "⚠️  dev-setup.sh not found, skipping symlink creation"
    fi
}

mark_git_folder_as_safe() {
    echo "🔒 Setting up Git repository safety..."

    # Check current ownership
    local repo_owner=$(stat -c '%u' /workspace/.git)
    local container_user=$(id -u)
    echo "👤 Repository ownership:"
    echo "   Repository owner ID: $repo_owner"
    echo "   Container user ID: $container_user"
    ls -l /workspace/.git

    # Mark workspace as safe globally
    git config --global --add safe.directory /workspace
    git config --global --add safe.directory '*'

    # Additional git configurations for mounted volumes
    git config --global core.fileMode false  # Ignore file mode changes
    git config --global core.hideDotFiles false  # Show dotfiles

    # Verify the configuration
    if git config --global --get-all safe.directory | grep -q "/workspace"; then
        echo "✅ Git folder marked as safe: /workspace"
    else
        echo "❌ Failed to mark Git folder as safe"
        return 1
    fi

    # Test Git status to verify it works
    if git status &>/dev/null; then
        echo "✅ Git commands working correctly"
    else
        echo "❌ Git commands still having issues"
        return 1
    fi

    # Show final git config for verification
    echo "🔧 Current Git configuration:"
    git config --global --list | grep -E "safe|core"
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

    # Generate supervisor configs from enabled services
    if command -v supervisord >/dev/null 2>&1; then
        echo "🔧 Generating supervisor configuration..."
        set +e
        bash "$SCRIPT_DIR/../.devcontainer/additions/config-supervisor.sh"
        local supervisor_exit_code=$?
        set -e
        if [ $supervisor_exit_code -ne 0 ]; then
            echo "⚠️  Supervisor configuration failed (exit code: $supervisor_exit_code)"
        fi
        echo ""

        # Start supervisor if configs exist and it's not running
        if [ -d /etc/supervisor/conf.d ] && [ "$(ls -A /etc/supervisor/conf.d/*.conf 2>/dev/null)" ]; then
            if ! pgrep supervisord > /dev/null 2>&1; then
                echo "🚀 Starting supervisord..."
                sudo supervisord -c /etc/supervisor/supervisord.conf
                sleep 2
                if pgrep supervisord > /dev/null 2>&1; then
                    echo "✅ Supervisord started successfully"
                    # Count running services
                    local running_count=$(sudo supervisorctl status 2>/dev/null | grep -c "RUNNING" || echo "0")
                    echo "   Running services: $running_count"
                else
                    echo "⚠️  Failed to start supervisord - services will start on next shell"
                fi
            else
                echo "✅ Supervisord already running"
                # Reload to pick up any new configs
                sudo supervisorctl reread > /dev/null 2>&1
                sudo supervisorctl update > /dev/null 2>&1
            fi
        fi
        echo ""
    fi
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