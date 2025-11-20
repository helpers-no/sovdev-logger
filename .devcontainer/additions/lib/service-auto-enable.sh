#!/bin/bash
# File: .devcontainer/additions/lib/service-auto-enable.sh
# Purpose: Shared library for service auto-enablement in supervisord
# Usage: Source this file from start-*.sh scripts and call auto_enable_service()

# Paths
readonly AUTO_ENABLE_CONF="/workspace/.devcontainer.extend/enabled-services.conf"
readonly AUTO_ENABLE_GENERATOR="/workspace/.devcontainer/additions/config-supervisor.sh"

# Colors for logging
readonly AUTO_ENABLE_GREEN='\033[0;32m'
readonly AUTO_ENABLE_BLUE='\033[0;34m'
readonly AUTO_ENABLE_YELLOW='\033[1;33m'
readonly AUTO_ENABLE_NC='\033[0m'

#------------------------------------------------------------------------------
# Auto-Enable Functions
#------------------------------------------------------------------------------

# Check if a service is already enabled
# Args: $1 - service identifier (lowercase-with-dashes)
# Returns: 0 if enabled, 1 if not
is_auto_enabled() {
    local service_id="$1"

    if [[ ! -f "$AUTO_ENABLE_CONF" ]]; then
        return 1
    fi

    # Check if service is in the config (skip comments)
    if grep -q "^${service_id}$" "$AUTO_ENABLE_CONF" 2>/dev/null; then
        return 0
    fi

    return 1
}

# Enable a service for auto-start
# Args: $1 - service identifier (lowercase-with-dashes)
#       $2 - service display name (optional, for logging)
enable_service_autostart() {
    local service_id="$1"
    local service_name="${2:-$service_id}"

    # Check if already enabled
    if is_auto_enabled "$service_id"; then
        return 0
    fi

    # Ensure config file exists
    if [[ ! -f "$AUTO_ENABLE_CONF" ]]; then
        echo -e "${AUTO_ENABLE_YELLOW}⚠️  Creating enabled-services.conf${AUTO_ENABLE_NC}"
        mkdir -p "$(dirname "$AUTO_ENABLE_CONF")"
        cat > "$AUTO_ENABLE_CONF" << 'EOF'
# Enabled Services for Auto-Start
# Services listed here will automatically start when the container starts
# Format: One service identifier per line (matches SERVICE_NAME in lowercase-with-dashes)
#
# Management:
#   dev-services enable <service>   - Enable a service
#   dev-services disable <service>  - Disable a service
#   dev-services list-enabled       - Show enabled services
#
# Note: Services auto-enable themselves when first started successfully

EOF
    fi

    # Add to config
    echo "$service_id" >> "$AUTO_ENABLE_CONF"
    echo -e "${AUTO_ENABLE_GREEN}✅ Auto-enabled '$service_name' for container restart${AUTO_ENABLE_NC}"
    echo -e "${AUTO_ENABLE_BLUE}ℹ️  Disable with: dev-services disable $service_id${AUTO_ENABLE_NC}"

    return 0
}

# Regenerate supervisor configuration
regenerate_supervisor_config() {
    if [[ -f "$AUTO_ENABLE_GENERATOR" ]]; then
        echo -e "${AUTO_ENABLE_BLUE}ℹ️  Regenerating supervisor configuration...${AUTO_ENABLE_NC}"
        bash "$AUTO_ENABLE_GENERATOR" > /dev/null 2>&1
        return $?
    else
        echo -e "${AUTO_ENABLE_YELLOW}⚠️  Supervisor config generator not found: $AUTO_ENABLE_GENERATOR${AUTO_ENABLE_NC}"
        return 1
    fi
}

# Main auto-enable function - call this from start scripts
# Args: $1 - service identifier (lowercase-with-dashes)
#       $2 - service display name (optional, for logging)
# Usage: auto_enable_service "otel-monitoring" "OTel Monitoring"
auto_enable_service() {
    local service_id="$1"
    local service_name="${2:-$service_id}"

    # Enable for auto-start
    if enable_service_autostart "$service_id" "$service_name"; then
        # Regenerate supervisor config if newly enabled
        if ! is_auto_enabled "$service_id"; then
            regenerate_supervisor_config
        fi
    fi
}

# Disable a service from auto-start
# Args: $1 - service identifier (lowercase-with-dashes)
disable_service_autostart() {
    local service_id="$1"

    if [[ ! -f "$AUTO_ENABLE_CONF" ]]; then
        echo -e "${AUTO_ENABLE_YELLOW}⚠️  No enabled-services.conf found${AUTO_ENABLE_NC}"
        return 1
    fi

    # Remove from config (preserve comments and other entries)
    local temp_file
    temp_file=$(mktemp)
    grep -v "^${service_id}$" "$AUTO_ENABLE_CONF" > "$temp_file"
    mv "$temp_file" "$AUTO_ENABLE_CONF"

    echo -e "${AUTO_ENABLE_GREEN}✅ Disabled auto-start for '$service_id'${AUTO_ENABLE_NC}"

    # Regenerate supervisor config
    regenerate_supervisor_config

    return 0
}

# List all enabled services
list_enabled_services() {
    if [[ ! -f "$AUTO_ENABLE_CONF" ]]; then
        echo "No enabled services"
        return 0
    fi

    echo "Enabled services:"
    grep -v '^#' "$AUTO_ENABLE_CONF" | grep -v '^$' | while read -r service; do
        echo "  - $service"
    done
}
