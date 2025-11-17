#!/bin/bash
# file: .devcontainer/additions/_template-config-script.sh
#
# TEMPLATE: Copy this file when creating new configuration scripts
# Rename to: config-[setting-name].sh
# Example: config-git-user.sh, config-aws-credentials.sh
#
# Usage: bash .devcontainer/additions/config-[name].sh
#
# Configuration scripts should be:
#   - Interactive (prompt user for input)
#   - Idempotent (safe to run multiple times)
#   - Support reconfiguration (allow updating existing config)
#   - Validate user input
#   - Provide clear feedback
#
#------------------------------------------------------------------------------
# METADATA PATTERN - Required for automatic script discovery
#------------------------------------------------------------------------------
#
# The dev-setup.sh menu system uses the component-scanner library to automatically
# discover and display all config scripts. To make your script visible in the menu,
# you must define these four metadata fields in the CONFIGURATION section below:
#
# CONFIG_NAME - Human-readable name displayed in the menu (2-4 words)
#   Example: "Developer Identity"
#
# CONFIG_DESCRIPTION - Brief description of what this configures (one sentence)
#   Example: "Configure your identity for devcontainer monitoring"
#
# CONFIG_CATEGORY - Category for menu organization
#   Common options: INFRA_CONFIG, USER_CONFIG, SECURITY, CREDENTIALS
#   Example: "INFRA_CONFIG"
#
# CHECK_CONFIGURED_COMMAND - Shell command to check if already configured
#   - Must return exit code 0 if configured, 1 if not configured
#   - Should suppress all output (use >/dev/null 2>&1)
#   - Should be fast (run in < 1 second)
#   - Should check actual configuration state, not just file existence
#   Examples:
#     "[ -f ~/.config-file ] && grep -q '^key=value' ~/.config-file"
#     "git config --global user.name >/dev/null 2>&1 && git config --global user.email >/dev/null 2>&1"
#     "[ -f ~/.aws/credentials ] && grep -q '^\[default\]' ~/.aws/credentials"
#
# For more details, see: .devcontainer/additions/README-additions.md
#
#------------------------------------------------------------------------------
# CONFIGURATION METADATA - For dev-setup.sh menu discovery
#------------------------------------------------------------------------------

CONFIG_NAME="[Configuration Name]"
CONFIG_DESCRIPTION="Configure [setting/credential/identity] for [purpose]"
CONFIG_CATEGORY="USER_CONFIG"  # Options: INFRA_CONFIG, USER_CONFIG, SECURITY, CREDENTIALS
CHECK_CONFIGURED_COMMAND="[ -f ~/.config-file ] && grep -q '^key=value' ~/.config-file"

#------------------------------------------------------------------------------

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration file paths
CONFIG_FILE="$HOME/.your-config-file"
# Add other files as needed

#------------------------------------------------------------------------------
# HELPER FUNCTIONS
#------------------------------------------------------------------------------

log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warn() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

#------------------------------------------------------------------------------
# CONFIGURATION FUNCTIONS
#------------------------------------------------------------------------------

check_if_already_configured() {
    # Check if configuration already exists
    if eval "$CHECK_CONFIGURED_COMMAND"; then
        echo ""
        log_warn "Configuration already exists!"
        echo ""
        echo "Current configuration:"
        # Display current configuration values
        # Example:
        # echo "   Setting 1: $(get_config_value 'setting1')"
        # echo "   Setting 2: $(get_config_value 'setting2')"
        echo ""
        read -p "Do you want to reconfigure? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo ""
            log_info "Keeping existing configuration"
            exit 0
        fi
        echo ""
        log_info "Reconfiguring..."
    fi
}

prompt_for_configuration() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📋 Configuration Input"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Prompt for configuration values
    # Example:
    # read -p "Enter setting name: " SETTING_NAME
    # read -p "Enter value: " SETTING_VALUE
    # read -s -p "Enter password (hidden): " PASSWORD
    # echo ""

    # Validate inputs
    # if [ -z "$SETTING_NAME" ]; then
    #     log_error "Setting name is required"
    #     exit 1
    # fi
}

validate_configuration() {
    log_info "Validating configuration..."

    # Add validation logic
    # Examples:
    # - Check for required fields
    # - Validate format (email, URL, etc.)
    # - Test connectivity if applicable
    # - Verify credentials if applicable

    # if ! validate_format "$EMAIL"; then
    #     log_error "Invalid email format"
    #     exit 1
    # fi

    log_success "Configuration validated"
}

show_configuration_summary() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📝 Configuration Summary"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Display configuration summary (without sensitive data)
    # Example:
    # echo "   Setting 1:    ${SETTING_1}"
    # echo "   Setting 2:    ${SETTING_2}"
    # echo "   Password:     ********"

    echo ""
    read -p "Does this look correct? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo ""
        log_warn "Configuration cancelled"
        echo "Please run the script again to reconfigure."
        exit 1
    fi
}

write_configuration() {
    log_info "Writing configuration..."

    # Create configuration file
    # Example:
    # cat > "$CONFIG_FILE" <<EOF
    # SETTING_1="${SETTING_1}"
    # SETTING_2="${SETTING_2}"
    # EOF

    # Set appropriate permissions
    # chmod 600 "$CONFIG_FILE"  # For sensitive files
    # chmod 644 "$CONFIG_FILE"  # For non-sensitive files

    log_success "Configuration saved: $CONFIG_FILE"
}

update_shell_environment() {
    # Optional: Add configuration to shell profile
    # This section is only needed if configuration should be loaded in every shell

    log_info "Updating shell environment..."

    # Example: Add source line to .bashrc
    # local BASHRC_FILE="$HOME/.bashrc"
    # if grep -q "your-config-file" "$BASHRC_FILE" 2>/dev/null; then
    #     log_info ".bashrc already configured (skipping)"
    #     return 0
    # fi
    #
    # cat >> "$BASHRC_FILE" <<'EOF'
    #
    # # Your configuration - managed by config-your-name.sh
    # [ -f ~/.your-config-file ] && source ~/.your-config-file
    # EOF

    log_success "Shell environment updated"
}

run_post_configuration_tasks() {
    # Optional: Run any post-configuration tasks
    # Examples:
    # - Test the configuration
    # - Initialize related services
    # - Create additional required files/directories

    log_info "Running post-configuration tasks..."

    # Add your post-configuration logic here

    log_success "Post-configuration tasks complete"
}

show_completion_message() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🎉 Configuration Complete!"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    log_success "Your configuration has been saved"
    echo ""

    # Add specific completion messages
    # Example:
    # echo "📝 Important Notes:"
    # echo ""
    # echo "• Configuration file: $CONFIG_FILE"
    # echo "• To verify your configuration:"
    # echo "  [command to verify]"
    # echo ""
    # echo "• To update your configuration, run this script again"
    # echo ""

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    log_success "You can now use your configured settings!"
    echo ""
}

#------------------------------------------------------------------------------
# MAIN
#------------------------------------------------------------------------------

main() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔧 $CONFIG_NAME"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "$CONFIG_DESCRIPTION"
    echo ""

    # Check if already configured
    check_if_already_configured

    # Prompt for configuration values
    prompt_for_configuration

    # Validate the configuration
    validate_configuration

    # Show summary and confirm
    show_configuration_summary

    # Write configuration to file
    write_configuration

    # Update shell environment (optional)
    # update_shell_environment

    # Run post-configuration tasks (optional)
    # run_post_configuration_tasks

    # Show completion message
    show_completion_message
}

# Run main function
main "$@"
