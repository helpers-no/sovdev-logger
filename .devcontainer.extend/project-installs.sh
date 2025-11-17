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







# Main execution flow
main() {
    echo "🚀 Starting project-installs setup..."

    # Create dev-setup symlink for easy access
    setup_dev_setup_command

    # Mark the git folder as safe
    mark_git_folder_as_safe

    # Configure Git user identity
    configure_git_identity

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

    # Arrays for discovered tools
    local -a TOOL_NAMES=()
    local -a TOOL_SCRIPTS=()
    local -a TOOL_CHECK_COMMANDS=()

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

    while IFS=$'\t' read -r script_basename script_name script_desc script_cat check_cmd; do
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

    for i in "${!TOOL_NAMES[@]}"; do
        local tool_name="${TOOL_NAMES[$i]}"
        local script_name="${TOOL_SCRIPTS[$i]}"
        local check_command="${TOOL_CHECK_COMMANDS[$i]}"

        # Check if already installed
        if [[ -n "$check_command" ]] && eval "$check_command" 2>/dev/null; then
            echo "✅ $tool_name - already installed (skipping)"
            ((skipped_count++))
        else
            echo "📦 Installing $tool_name..."
            if bash "$ADDITIONS_DIR/$script_name"; then
                echo "✅ $tool_name - installed successfully"
                ((installed_count++))
            else
                echo "❌ $tool_name - installation failed"
            fi
            echo ""
        fi
    done

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
        bash "$SCRIPT_DIR/../.devcontainer/additions/config-supervisor.sh"
        echo ""
    fi
}


main