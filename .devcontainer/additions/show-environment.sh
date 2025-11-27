#!/bin/bash
# File: .devcontainer/additions/show-environment.sh
#
# Purpose: Display comprehensive development environment information
# Usage: bash show-environment.sh [--short]
#
# Shows:
#   - System information (container, OS, disk space)
#   - Core tools (Python, Node.js, npm, Azure CLI, PowerShell)
#   - Available tools by category with installation status
#   - Running services status
#   - Configuration status
#   - Summary statistics

# Don't use set -e - we want to continue even if scans fail

#------------------------------------------------------------------------------
# Metadata
#------------------------------------------------------------------------------

SCRIPT_NAME="Show Environment Info"
SCRIPT_DESCRIPTION="Display development environment status and configuration"
SCRIPT_CATEGORY="INFRA_CONFIG"

#------------------------------------------------------------------------------
# Configuration
#------------------------------------------------------------------------------

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
ADDITIONS_DIR="$SCRIPT_DIR"

# Source component scanner library
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/component-scanner.sh"

#------------------------------------------------------------------------------
# Category definitions
#------------------------------------------------------------------------------

declare -A CATEGORIES
CATEGORIES["AI_TOOLS"]="AI & Coding Assistants"
CATEGORIES["LANGUAGE_DEV"]="Language Development"
CATEGORIES["INFRA_CONFIG"]="Infrastructure & Configuration"
CATEGORIES["DATA_ANALYTICS"]="Data & Analytics"
CATEGORIES["UNCATEGORIZED"]="Other Tools"

# Global arrays for tools
declare -a AVAILABLE_TOOLS=()
declare -a TOOL_SCRIPTS=()
declare -a TOOL_DESCRIPTIONS=()
declare -a TOOL_CATEGORIES=()
declare -A TOOLS_BY_CATEGORY=()
declare -A CATEGORY_COUNTS=()

# Global arrays for services
declare -a AVAILABLE_SERVICES=()
declare -a SERVICE_SCRIPTS=()
declare -a SERVICE_DESCRIPTIONS=()
declare -a SERVICE_CATEGORIES=()
declare -a SERVICE_START_SCRIPTS=()
declare -a SERVICE_STOP_SCRIPTS=()
declare -a SERVICE_CHECK_COMMANDS=()

# Global arrays for configs
declare -a AVAILABLE_CONFIGS=()
declare -a CONFIG_SCRIPTS=()
declare -a CONFIG_DESCRIPTIONS=()
declare -a CONFIG_CATEGORIES=()
declare -a CONFIG_CHECK_COMMANDS=()

#------------------------------------------------------------------------------
# Scanning functions
#------------------------------------------------------------------------------

scan_available_tools() {
    AVAILABLE_TOOLS=()
    TOOL_SCRIPTS=()
    TOOL_DESCRIPTIONS=()
    TOOL_CATEGORIES=()

    # Reset category organization
    TOOLS_BY_CATEGORY=()
    CATEGORY_COUNTS=()

    if [[ ! -d "$ADDITIONS_DIR" ]]; then
        return 1
    fi

    local found=0

    # Use library to scan install scripts (suppress errors)
    while IFS=$'\t' read -r script_basename script_name script_description script_category check_command; do
        # Add to arrays
        AVAILABLE_TOOLS+=("$script_name")
        TOOL_SCRIPTS+=("$script_basename")
        TOOL_DESCRIPTIONS+=("$script_description")
        TOOL_CATEGORIES+=("$script_category")

        # Track tool index by category
        local tool_index=$found
        if [[ -n "${TOOLS_BY_CATEGORY[$script_category]}" ]]; then
            TOOLS_BY_CATEGORY[$script_category]="${TOOLS_BY_CATEGORY[$script_category]},$tool_index"
        else
            TOOLS_BY_CATEGORY[$script_category]="$tool_index"
        fi

        # Increment category count
        CATEGORY_COUNTS[$script_category]=$((${CATEGORY_COUNTS[$script_category]:-0} + 1))

        ((found++))
    done < <(scan_install_scripts "$ADDITIONS_DIR" 2>/dev/null)

    if [[ $found -eq 0 ]]; then
        return 1
    fi

    return 0
}

scan_available_services() {
    AVAILABLE_SERVICES=()
    SERVICE_SCRIPTS=()
    SERVICE_DESCRIPTIONS=()
    SERVICE_CATEGORIES=()
    SERVICE_START_SCRIPTS=()
    SERVICE_STOP_SCRIPTS=()
    SERVICE_CHECK_COMMANDS=()

    if [[ ! -d "$ADDITIONS_DIR" ]]; then
        return 1
    fi

    local found=0

    # Use library to scan service scripts (suppress errors)
    while IFS=$'\t' read -r start_script stop_script service_name service_description service_category check_running_command; do
        # Add to arrays
        AVAILABLE_SERVICES+=("$service_name")
        SERVICE_SCRIPTS+=("$start_script")
        SERVICE_DESCRIPTIONS+=("$service_description")
        SERVICE_CATEGORIES+=("$service_category")
        SERVICE_START_SCRIPTS+=("$start_script")
        SERVICE_STOP_SCRIPTS+=("$stop_script")
        SERVICE_CHECK_COMMANDS+=("$check_running_command")

        ((found++))
    done < <(scan_service_scripts "$ADDITIONS_DIR" 2>/dev/null)

    if [[ $found -eq 0 ]]; then
        return 1
    fi

    return 0
}

scan_available_configs() {
    AVAILABLE_CONFIGS=()
    CONFIG_SCRIPTS=()
    CONFIG_DESCRIPTIONS=()
    CONFIG_CATEGORIES=()
    CONFIG_CHECK_COMMANDS=()

    if [[ ! -d "$ADDITIONS_DIR" ]]; then
        return 1
    fi

    local found=0

    # Use library to scan config scripts (suppress errors)
    while IFS=$'\t' read -r script_basename config_name config_description config_category check_command; do
        # Add to arrays
        AVAILABLE_CONFIGS+=("$config_name")
        CONFIG_SCRIPTS+=("$script_basename")
        CONFIG_DESCRIPTIONS+=("$config_description")
        CONFIG_CATEGORIES+=("$config_category")
        CONFIG_CHECK_COMMANDS+=("$check_command")

        ((found++))
    done < <(scan_config_scripts "$ADDITIONS_DIR" 2>/dev/null)

    if [[ $found -eq 0 ]]; then
        return 1
    fi

    return 0
}

#------------------------------------------------------------------------------
# Check functions
#------------------------------------------------------------------------------

check_tool_installed() {
    local script_name="$1"
    local script_path="$ADDITIONS_DIR/$script_name"

    # Extract check command using library
    local check_command=$(extract_script_metadata "$script_path" "CHECK_INSTALLED_COMMAND")

    # Check using library
    check_component_installed "$check_command"
    return $?
}

check_service_running() {
    local service_index=$1
    local check_command="${SERVICE_CHECK_COMMANDS[$service_index]}"

    # If no check command, assume not running
    if [[ -z "$check_command" ]]; then
        return 1
    fi

    # Execute the check command
    eval "$check_command" 2>/dev/null
    return $?
}

check_config_configured() {
    local config_index=$1
    local check_command="${CONFIG_CHECK_COMMANDS[$config_index]}"

    # If no check command, assume not configured
    if [[ -z "$check_command" ]]; then
        return 1
    fi

    # Execute the check command
    eval "$check_command" 2>/dev/null
    return $?
}

#------------------------------------------------------------------------------
# Display functions
#------------------------------------------------------------------------------

show_environment_info() {
    # Add buffer and ensure clean output
    echo ""
    echo ""

    echo "═══════════════════════════════════════════════════════════════════"
    echo "                    ENVIRONMENT INFORMATION"
    echo "═══════════════════════════════════════════════════════════════════"
    echo ""

    # System info
    echo "System Information:"
    echo "  • Container: $(whoami)@$(hostname)"
    if [[ -f /etc/os-release ]]; then
        echo "  • OS: $(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)"
    fi
    # System resources
    local disk_info=$(df -h / | awk 'NR==2 {print $4 " free of " $2}')
    echo "  • Disk Space: $disk_info"
    echo ""

    # Host information (if available)
    if [ -f /workspace/.devcontainer.secrets/env-vars/.host-info ]; then
        # shellcheck source=/dev/null
        source /workspace/.devcontainer.secrets/env-vars/.host-info
        echo "Host Information:"
        echo "  • Operating System: $HOST_OS"
        echo "  • User: $HOST_USER"
        echo "  • Hostname: $HOST_HOSTNAME"
        [ -n "$HOST_DOMAIN" ] && echo "  • Domain: $HOST_DOMAIN"
        echo "  • Architecture: $HOST_CPU_ARCH"
        echo ""
    fi

    # Core tools - always installed
    echo "Core Tools:"
    command -v python3 >/dev/null && echo "  ✅ Python: $(python3 --version | cut -d' ' -f2)" || echo "  ❌ Python: not installed"
    command -v node >/dev/null && echo "  ✅ Node.js: $(node --version | sed 's/v//')" || echo "  ❌ Node.js: not installed"
    command -v npm >/dev/null && echo "  ✅ npm: $(npm --version)" || echo "  ❌ npm: not installed"
    command -v az >/dev/null && echo "  ✅ Azure CLI: $(az version 2>/dev/null | grep -o '\"azure-cli\": \"[^\"]*\"' | cut -d'"' -f4)" || echo "  ❌ Azure CLI: not installed"
    command -v pwsh >/dev/null && echo "  ✅ PowerShell: $(pwsh --version 2>/dev/null | cut -d' ' -f2)" || echo "  ❌ PowerShell: not installed"
    echo ""

    # Scan tools and services
    local total_tools=0
    local installed_count=0
    local total_services=0
    local running_services=0

    # Available tools organized by category
    scan_available_tools >/dev/null 2>&1 || true
    if [[ ${#AVAILABLE_TOOLS[@]} -gt 0 ]]; then
        echo "Available Tools (by category):"
        echo ""

        total_tools=${#AVAILABLE_TOOLS[@]}

        # Iterate through categories in order
        for category_key in "AI_TOOLS" "LANGUAGE_DEV" "INFRA_CONFIG" "DATA_ANALYTICS" "UNCATEGORIZED"; do
            local count=${CATEGORY_COUNTS[$category_key]:-0}

            # Skip empty categories
            if [[ $count -eq 0 ]]; then
                continue
            fi

            local category_name="${CATEGORIES[$category_key]}"
            echo "$category_name:"

            # Get tool indices for this category
            local tool_indices="${TOOLS_BY_CATEGORY[$category_key]}"
            IFS=',' read -ra INDICES <<< "$tool_indices"

            # Display tools in this category
            for tool_index in "${INDICES[@]}"; do
                local tool_name="${AVAILABLE_TOOLS[$tool_index]}"
                local script_name="${TOOL_SCRIPTS[$tool_index]}"

                if check_tool_installed "$script_name"; then
                    echo "  ✅ $tool_name"
                    ((installed_count++))
                else
                    echo "  ❌ $tool_name"
                fi
            done
            echo ""
        done
    fi

    # Running services
    scan_available_services >/dev/null 2>&1 || true
    if [[ ${#AVAILABLE_SERVICES[@]} -gt 0 ]]; then
        echo "Services:"
        echo ""

        total_services=${#AVAILABLE_SERVICES[@]}

        if [[ $total_services -gt 0 ]]; then
            for i in "${!AVAILABLE_SERVICES[@]}"; do
                local service_name="${AVAILABLE_SERVICES[$i]}"

                if check_service_running "$i"; then
                    echo "  ✅ $service_name (running)"
                    ((running_services++))
                else
                    echo "  ⏸️  $service_name (stopped)"
                fi
            done
        else
            echo "  No services available"
        fi
        echo ""
    fi

    # Configuration status
    local total_configs=0
    local configured_count=0

    scan_available_configs >/dev/null 2>&1 || true
    if [[ ${#AVAILABLE_CONFIGS[@]} -gt 0 ]]; then
        echo "Configurations:"
        echo ""

        total_configs=${#AVAILABLE_CONFIGS[@]}

        if [[ $total_configs -gt 0 ]]; then
            for i in "${!AVAILABLE_CONFIGS[@]}"; do
                local config_name="${AVAILABLE_CONFIGS[$i]}"

                if check_config_configured "$i"; then
                    echo "  ✅ $config_name (configured)"
                    ((configured_count++))
                else
                    echo "  ❌ $config_name (not configured)"
                fi
            done
        else
            echo "  No configurations available"
        fi
        echo ""
    fi

    # Summary statistics
    echo "─────────────────────────────────────────────────────────────────"
    echo "Summary:"
    if [[ $total_tools -gt 0 ]]; then
        local tools_pct=$((installed_count * 100 / total_tools))
        echo "  • Tools: $installed_count of $total_tools installed ($tools_pct%)"
    fi
    if [[ $total_services -gt 0 ]]; then
        echo "  • Services: $running_services of $total_services running"
    fi
    if [[ $total_configs -gt 0 ]]; then
        local configs_pct=$((configured_count * 100 / total_configs))
        echo "  • Configurations: $configured_count of $total_configs configured ($configs_pct%)"
    fi
    echo "═══════════════════════════════════════════════════════════════════"
    echo ""
}

#------------------------------------------------------------------------------
# Main execution
#------------------------------------------------------------------------------

main() {
    # Parse command line arguments
    case "${1:-}" in
        --short)
            # TODO: Implement short format
            show_environment_info
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Display development environment status and configuration"
            echo ""
            echo "OPTIONS:"
            echo "  --short     Show brief summary only"
            echo "  --help      Show this help message"
            echo ""
            exit 0
            ;;
        *)
            show_environment_info
            ;;
    esac
}

# Execute main function
main "$@"
