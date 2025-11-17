#!/bin/bash
# File: .devcontainer/additions/lib/tool-auto-enable.sh
# Purpose: Shared library for tool auto-enablement in project-installs.sh
# Usage: Source this file from install-*.sh scripts and call auto_enable_tool()

# Paths
readonly AUTO_ENABLE_TOOLS_CONF="/workspace/.devcontainer.extend/enabled-tools.conf"

# Colors for logging
readonly TOOL_AUTO_ENABLE_GREEN='\033[0;32m'
readonly TOOL_AUTO_ENABLE_BLUE='\033[0;34m'
readonly TOOL_AUTO_ENABLE_YELLOW='\033[1;33m'
readonly TOOL_AUTO_ENABLE_NC='\033[0m'

#------------------------------------------------------------------------------
# Auto-Enable Functions
#------------------------------------------------------------------------------

# Check if a tool is already enabled
# Args: $1 - tool identifier (lowercase-with-dashes)
# Returns: 0 if enabled, 1 if not
is_tool_auto_enabled() {
    local tool_id="$1"

    if [[ ! -f "$AUTO_ENABLE_TOOLS_CONF" ]]; then
        return 1
    fi

    # Check if tool is in the config (skip comments)
    if grep -q "^${tool_id}$" "$AUTO_ENABLE_TOOLS_CONF" 2>/dev/null; then
        return 0
    fi

    return 1
}

# Enable a tool for auto-install
# Args: $1 - tool identifier (lowercase-with-dashes)
#       $2 - tool display name (optional, for logging)
enable_tool_autoinstall() {
    local tool_id="$1"
    local tool_name="${2:-$tool_id}"

    # Check if already enabled
    if is_tool_auto_enabled "$tool_id"; then
        return 0
    fi

    # Ensure config file exists
    if [[ ! -f "$AUTO_ENABLE_TOOLS_CONF" ]]; then
        echo -e "${TOOL_AUTO_ENABLE_YELLOW}⚠️  Creating enabled-tools.conf${TOOL_AUTO_ENABLE_NC}"
        mkdir -p "$(dirname "$AUTO_ENABLE_TOOLS_CONF")"
        cat > "$AUTO_ENABLE_TOOLS_CONF" << 'EOF'
# Enabled Tools for Auto-Install
# Tools listed here will automatically install when the container is created/rebuilt
# Format: One tool identifier per line (matches SCRIPT_NAME in lowercase-with-dashes)
#
# Management:
#   Add tool name to enable auto-install
#   Remove or comment out to disable
#
# Available tools are auto-discovered from .devcontainer/additions/install-*.sh
# Each install script has SCRIPT_NAME metadata that maps to the identifier
#
# Note: Tools auto-enable themselves when first installed successfully

EOF
    fi

    # Add to config
    echo "$tool_id" >> "$AUTO_ENABLE_TOOLS_CONF"
    echo -e "${TOOL_AUTO_ENABLE_GREEN}✅ Auto-enabled '$tool_name' for container rebuild${TOOL_AUTO_ENABLE_NC}"
    echo -e "${TOOL_AUTO_ENABLE_BLUE}ℹ️  Remove from enabled-tools.conf to disable: $tool_id${TOOL_AUTO_ENABLE_NC}"

    return 0
}

# Main auto-enable function - call this from install scripts
# Args: $1 - tool identifier (lowercase-with-dashes)
#       $2 - tool display name (optional, for logging)
# Usage: auto_enable_tool "otel-collector" "OTel Collector"
auto_enable_tool() {
    local tool_id="$1"
    local tool_name="${2:-$tool_id}"

    # Enable for auto-install on container rebuild
    enable_tool_autoinstall "$tool_id" "$tool_name"
}

# Disable a tool from auto-install
# Args: $1 - tool identifier (lowercase-with-dashes)
disable_tool_autoinstall() {
    local tool_id="$1"

    if [[ ! -f "$AUTO_ENABLE_TOOLS_CONF" ]]; then
        echo -e "${TOOL_AUTO_ENABLE_YELLOW}⚠️  No enabled-tools.conf found${TOOL_AUTO_ENABLE_NC}"
        return 1
    fi

    # Remove from config (preserve comments and other entries)
    local temp_file
    temp_file=$(mktemp)
    grep -v "^${tool_id}$" "$AUTO_ENABLE_TOOLS_CONF" > "$temp_file"
    mv "$temp_file" "$AUTO_ENABLE_TOOLS_CONF"

    echo -e "${TOOL_AUTO_ENABLE_GREEN}✅ Disabled auto-install for '$tool_id'${TOOL_AUTO_ENABLE_NC}"

    return 0
}

# List all enabled tools
list_enabled_tools() {
    if [[ ! -f "$AUTO_ENABLE_TOOLS_CONF" ]]; then
        echo "No enabled tools"
        return 0
    fi

    echo "Enabled tools:"
    grep -v '^#' "$AUTO_ENABLE_TOOLS_CONF" | grep -v '^$' | while read -r tool; do
        echo "  - $tool"
    done
}
