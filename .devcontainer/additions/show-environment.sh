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
# Category definitions - Load from categories.sh
#------------------------------------------------------------------------------

# Source categories library to get all category definitions
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/categories.sh"

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
    # Output format: script_basename<TAB>SCRIPT_ID<TAB>SCRIPT_NAME<TAB>SCRIPT_DESCRIPTION<TAB>SCRIPT_CATEGORY<TAB>CHECK_INSTALLED_COMMAND<TAB>PREREQUISITE_CONFIGS
    while IFS=$'\t' read -r script_basename script_id script_name script_description script_category check_command prerequisite_configs; do
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

    # Scan for new service-*.sh scripts first
    while IFS=$'\t' read -r script_basename service_name service_description service_category script_path prerequisite_configs; do
        # Add to arrays
        AVAILABLE_SERVICES+=("$service_name")
        SERVICE_SCRIPTS+=("$script_basename")
        SERVICE_DESCRIPTIONS+=("$service_description")
        SERVICE_CATEGORIES+=("$service_category")
        SERVICE_START_SCRIPTS+=("$script_path")
        SERVICE_STOP_SCRIPTS+=("")

        # Check if service is running using the --is-running flag
        # This returns 0 if running, 1 if stopped, with no output
        # Suppress all output (stdout and stderr) to avoid logging messages
        local service_check="bash \"$script_path\" --is-running >/dev/null 2>&1"
        SERVICE_CHECK_COMMANDS+=("$service_check")

        ((found++))
    done < <(scan_service_scripts_new "$ADDITIONS_DIR" 2>/dev/null)

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

get_config_source() {
    local config_index="$1"
    local script_name="${CONFIG_SCRIPTS[$config_index]}"
    local script_path="$ADDITIONS_DIR/$script_name"

    # Extract PERSISTENT_FILE from the config script
    local persistent_file=$(grep -m1 "^PERSISTENT_FILE=" "$script_path" 2>/dev/null | cut -d'=' -f2 | tr -d '"' | sed 's/\$PERSISTENT_DIR/\/workspace\/.devcontainer.secrets\/env-vars/')

    # Check if persistent file exists
    if [[ -n "$persistent_file" ]] && [[ -f "$persistent_file" ]]; then
        echo "(from secrets)"
    else
        echo "(manual)"
    fi
}

#------------------------------------------------------------------------------
# Display functions
#------------------------------------------------------------------------------

get_container_name() {
    # Try multiple methods to get container name

    # Method 1: Try docker inspect if socket is available
    if command -v docker >/dev/null 2>&1; then
        local container_id=$(hostname)
        local name=$(docker inspect --format='{{.Name}}' "$container_id" 2>/dev/null | sed 's/^\///')
        if [[ -n "$name" ]]; then
            echo "$name"
            return 0
        fi
    fi

    # Method 2: Parse devcontainer.json
    if [[ -f /workspace/.devcontainer/devcontainer.json ]]; then
        local name=$(grep -o '"name"[[:space:]]*:[[:space:]]*"[^"]*"' /workspace/.devcontainer/devcontainer.json | cut -d'"' -f4)
        if [[ -n "$name" ]]; then
            # Convert to lowercase and replace spaces with hyphens (Docker container naming convention)
            name=$(echo "$name" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
            echo "$name"
            return 0
        fi
    fi

    # Method 3: Fallback to just container ID
    echo "$(hostname)"
}

get_docker_stats() {
    # Get Docker server statistics if Docker is available
    if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
        local docker_info=$(docker info 2>/dev/null)

        # Extract statistics
        local total=$(echo "$docker_info" | grep "^ Containers:" | awk '{print $2}')
        local running=$(echo "$docker_info" | grep "^  Running:" | awk '{print $2}')
        local stopped=$(echo "$docker_info" | grep "^  Stopped:" | awk '{print $2}')
        local paused=$(echo "$docker_info" | grep "^  Paused:" | awk '{print $2}')
        local images=$(echo "$docker_info" | grep "^ Images:" | awk '{print $2}')

        # Only output if we got valid data
        if [[ -n "$total" ]]; then
            echo "total=$total;running=$running;stopped=$stopped;paused=$paused;images=$images"
            return 0
        fi
    fi

    return 1
}

show_environment_info() {
    # Add buffer and ensure clean output
    echo ""
    echo ""

    echo "═══════════════════════════════════════════════════════════════════"
    echo "                    DEVELOPMENT ENVIRONMENT"
    echo "═══════════════════════════════════════════════════════════════════"
    echo ""

    echo "┌─────────────────────────────────────────────────────────────────┐"
    echo "│ HOST ENVIRONMENT                                                 │"
    echo "└─────────────────────────────────────────────────────────────────┘"

    # Host information (if available)
    if [ -f /workspace/.devcontainer.secrets/env-vars/.host-info ]; then
        # shellcheck source=/dev/null
        source /workspace/.devcontainer.secrets/env-vars/.host-info
        echo "  Operating System:  $HOST_OS"
        echo "  User:              $HOST_USER"
        echo "  Hostname:          $HOST_HOSTNAME"
        [ -n "$HOST_DOMAIN" ] && echo "  Domain:            $HOST_DOMAIN" || echo "  Domain:            none"
        echo "  Architecture:      $HOST_CPU_ARCH"
    else
        echo "  Host information not available"
    fi
    echo ""

    echo "┌─────────────────────────────────────────────────────────────────┐"
    echo "│ CONTAINER ENVIRONMENT                                            │"
    echo "└─────────────────────────────────────────────────────────────────┘"

    # Container info
    local container_name=$(get_container_name)
    echo "  Container Name:    $container_name"
    echo "  Container ID:      $(whoami)@$(hostname)"
    if [[ -f /etc/os-release ]]; then
        echo "  Base Image:        $(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)"
    fi
    # System resources
    local disk_info=$(df -h / | awk 'NR==2 {print $4 " free of " $2}')
    echo "  Disk Space:        $disk_info"
    echo "  Working Directory: $(pwd)"

    # Docker server statistics (if available)
    local docker_stats=$(get_docker_stats)
    if [[ -n "$docker_stats" ]]; then
        # Parse the statistics
        local total=$(echo "$docker_stats" | cut -d';' -f1 | cut -d'=' -f2)
        local running=$(echo "$docker_stats" | cut -d';' -f2 | cut -d'=' -f2)
        local stopped=$(echo "$docker_stats" | cut -d';' -f3 | cut -d'=' -f2)
        local paused=$(echo "$docker_stats" | cut -d';' -f4 | cut -d'=' -f2)
        local images=$(echo "$docker_stats" | cut -d';' -f5 | cut -d'=' -f2)

        echo "  Docker Server:"
        echo "    Containers:      $total (Running: $running, Stopped: $stopped, Paused: $paused)"
        echo "    Images:          $images"
    fi
    echo ""

    echo "┌─────────────────────────────────────────────────────────────────┐"
    echo "│ RUNTIME ENVIRONMENT                                              │"
    echo "└─────────────────────────────────────────────────────────────────┘"
    # Base tools from container image
    command -v python3 >/dev/null && echo "  ✅ Python $(python3 --version | cut -d' ' -f2)"
    command -v node >/dev/null && echo "  ✅ Node.js $(node --version | sed 's/v//')"
    command -v npm >/dev/null && echo "  ✅ npm $(npm --version)"
    command -v git >/dev/null && echo "  ✅ Git $(git --version | cut -d' ' -f3)"
    command -v docker >/dev/null && echo "  ✅ Docker CLI $(docker --version | cut -d' ' -f3 | sed 's/,//')"
    echo ""

    # Scan tools and services
    local total_tools=0
    local installed_count=0
    local total_services=0
    local running_services=0

    # Available tools organized by category
    scan_available_tools >/dev/null 2>&1 || true
    if [[ ${#AVAILABLE_TOOLS[@]} -gt 0 ]]; then
        echo "┌─────────────────────────────────────────────────────────────────┐"
        echo "│ INSTALLED TOOLS BY CATEGORY                                      │"
        echo "└─────────────────────────────────────────────────────────────────┘"
        echo ""

        total_tools=${#AVAILABLE_TOOLS[@]}

        # Iterate through all categories in sort order
        while IFS= read -r category_key; do
            local count=${CATEGORY_COUNTS[$category_key]:-0}

            # Skip empty categories
            if [[ $count -eq 0 ]]; then
                continue
            fi

            # Get display name from library
            local category_name=$(get_category_display_name "$category_key")
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
        done < <(get_all_category_ids)

        # Also check for UNCATEGORIZED tools
        if [[ ${CATEGORY_COUNTS["UNCATEGORIZED"]:-0} -gt 0 ]]; then
            echo "Other Tools:"
            local tool_indices="${TOOLS_BY_CATEGORY["UNCATEGORIZED"]}"
            IFS=',' read -ra INDICES <<< "$tool_indices"
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
        fi
    fi

    # Running services
    scan_available_services >/dev/null 2>&1 || true
    if [[ ${#AVAILABLE_SERVICES[@]} -gt 0 ]]; then
        echo "┌─────────────────────────────────────────────────────────────────┐"
        echo "│ SERVICES                                                         │"
        echo "└─────────────────────────────────────────────────────────────────┘"

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
        echo "┌─────────────────────────────────────────────────────────────────┐"
        echo "│ CONFIGURATIONS                                                   │"
        echo "└─────────────────────────────────────────────────────────────────┘"

        total_configs=${#AVAILABLE_CONFIGS[@]}

        if [[ $total_configs -gt 0 ]]; then
            for i in "${!AVAILABLE_CONFIGS[@]}"; do
                local config_name="${AVAILABLE_CONFIGS[$i]}"

                if check_config_configured "$i"; then
                    local source=$(get_config_source "$i")
                    echo "  ✅ $config_name $source"
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
    echo "SUMMARY"
    echo "─────────────────────────────────────────────────────────────────"
    if [[ $total_tools -gt 0 ]]; then
        local tools_pct=$((installed_count * 100 / total_tools))
        echo "  Tools:          $installed_count of $total_tools installed ($tools_pct%)"
    fi
    if [[ $total_services -gt 0 ]]; then
        echo "  Services:       $running_services of $total_services running"
    fi
    if [[ $total_configs -gt 0 ]]; then
        local configs_pct=$((configured_count * 100 / total_configs))
        echo "  Configurations: $configured_count of $total_configs configured ($configs_pct%)"
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
