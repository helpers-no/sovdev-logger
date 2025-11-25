#!/bin/bash
# file: .devcontainer/dev-setup.sh
# Description: Simple development environment setup and tool selection
# Purpose: Central setup script for devcontainer development tools and templates
#
# Usage: dev-setup [--help] [--version]
#
# Exit Codes:
#   0 - Success or user exit
#   1 - Error in script execution
#   2 - Required directory not found
#   3 - User cancelled operation
#
#------------------------------------------------------------------------------

set -e

# Script metadata
SCRIPT_VERSION="3.4.0"
SCRIPT_NAME="DevContainer Setup"
DEVCONTAINER_DIR=".devcontainer"
ADDITIONS_DIR="$DEVCONTAINER_DIR/additions"
DEV_TEMPLATE_SCRIPT="$DEVCONTAINER_DIR/dev/dev-template.sh"

# Source component scanner library
LIB_DIR="$DEVCONTAINER_DIR/additions/lib"
if [[ -f "$LIB_DIR/component-scanner.sh" ]]; then
    source "$LIB_DIR/component-scanner.sh"
else
    echo "Error: component-scanner.sh library not found" >&2
    exit 1
fi

# Category definitions
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

# Category organization
declare -A TOOLS_BY_CATEGORY  # Maps category to comma-separated tool indices
declare -A CATEGORY_COUNTS     # Maps category to tool count

# Global arrays for services
declare -a AVAILABLE_SERVICES=()
declare -a SERVICE_SCRIPTS=()
declare -a SERVICE_DESCRIPTIONS=()
declare -a SERVICE_CATEGORIES=()
declare -a SERVICE_START_SCRIPTS=()
declare -a SERVICE_STOP_SCRIPTS=()
declare -a SERVICE_CHECK_COMMANDS=()

# Service category organization
declare -A SERVICES_BY_CATEGORY  # Maps category to comma-separated service indices
declare -A SERVICE_CATEGORY_COUNTS  # Maps category to service count

# Global arrays for configs
declare -a AVAILABLE_CONFIGS=()
declare -a CONFIG_SCRIPTS=()
declare -a CONFIG_DESCRIPTIONS=()
declare -a CONFIG_CATEGORIES=()
declare -a CONFIG_CHECK_COMMANDS=()

# Config category organization
declare -A CONFIGS_BY_CATEGORY  # Maps category to comma-separated config indices
declare -A CONFIG_CATEGORY_COUNTS  # Maps category to config count

# Whiptail dimensions
DIALOG_HEIGHT=20
DIALOG_WIDTH=80
MENU_HEIGHT=12

#------------------------------------------------------------------------------
# Utility functions
#------------------------------------------------------------------------------

show_help() {
    cat << EOF
$SCRIPT_NAME v$SCRIPT_VERSION

USAGE:
    dev-setup [OPTIONS]

OPTIONS:
    --help          Show this help message
    --version       Show version information

DESCRIPTION:
    Simple setup script for development environment tools and project templates.
    Uses dialog for a clean, user-friendly interface with live descriptions.

EOF
}

show_version() {
    echo "$SCRIPT_NAME v$SCRIPT_VERSION"
}

# Check if dialog is available
check_dialog() {
    if ! command -v dialog >/dev/null 2>&1; then
        echo "❌ Error: dialog is not installed"
        echo ""
        echo "Please install dialog first:"
        echo "  sudo apt-get update"
        echo "  sudo apt-get install dialog"
        echo ""
        exit 2
    fi
}

# Check if we're in a devcontainer project
check_environment() {
    if [[ ! -d "$DEVCONTAINER_DIR" ]]; then
        dialog --title "Error" --msgbox "Not in a devcontainer project.\n\nNo $DEVCONTAINER_DIR directory found.\nPlease run this script from the root of your devcontainer project." $DIALOG_HEIGHT $DIALOG_WIDTH
        clear
        exit 2
    fi
}

#------------------------------------------------------------------------------
# Tool discovery and management
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
        dialog --title "Error" --msgbox "Tools directory not found: $ADDITIONS_DIR" $DIALOG_HEIGHT $DIALOG_WIDTH
        clear
        return 1
    fi

    local found=0

    # Use library to scan install scripts
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
    done < <(scan_install_scripts "$ADDITIONS_DIR")

    if [[ $found -eq 0 ]]; then
        dialog --title "No Tools Found" --msgbox "No development tools found in $ADDITIONS_DIR" $DIALOG_HEIGHT $DIALOG_WIDTH
        clear
        return 1
    fi

    return 0
}

#------------------------------------------------------------------------------
# Service discovery and management
#------------------------------------------------------------------------------

scan_available_services() {
    AVAILABLE_SERVICES=()
    SERVICE_SCRIPTS=()
    SERVICE_DESCRIPTIONS=()
    SERVICE_CATEGORIES=()
    SERVICE_START_SCRIPTS=()
    SERVICE_STOP_SCRIPTS=()
    SERVICE_CHECK_COMMANDS=()

    # Reset category organization
    SERVICES_BY_CATEGORY=()
    SERVICE_CATEGORY_COUNTS=()

    if [[ ! -d "$ADDITIONS_DIR" ]]; then
        dialog --title "Error" --msgbox "Services directory not found: $ADDITIONS_DIR" $DIALOG_HEIGHT $DIALOG_WIDTH
        clear
        return 1
    fi

    local found=0

    # Use library to scan service scripts
    while IFS=$'\t' read -r start_script stop_script service_name service_description service_category check_running_command; do
        # Add to arrays
        AVAILABLE_SERVICES+=("$service_name")
        SERVICE_SCRIPTS+=("$start_script")
        SERVICE_DESCRIPTIONS+=("$service_description")
        SERVICE_CATEGORIES+=("$service_category")
        SERVICE_START_SCRIPTS+=("$start_script")
        SERVICE_STOP_SCRIPTS+=("$stop_script")
        SERVICE_CHECK_COMMANDS+=("$check_running_command")

        # Track service index by category
        local service_index=$found
        if [[ -n "${SERVICES_BY_CATEGORY[$service_category]}" ]]; then
            SERVICES_BY_CATEGORY[$service_category]="${SERVICES_BY_CATEGORY[$service_category]},$service_index"
        else
            SERVICES_BY_CATEGORY[$service_category]="$service_index"
        fi

        # Increment category count
        SERVICE_CATEGORY_COUNTS[$service_category]=$((${SERVICE_CATEGORY_COUNTS[$service_category]:-0} + 1))

        ((found++))
    done < <(scan_service_scripts "$ADDITIONS_DIR")

    if [[ $found -eq 0 ]]; then
        dialog --title "No Services Found" --msgbox "No services found in $ADDITIONS_DIR" $DIALOG_HEIGHT $DIALOG_WIDTH
        clear
        return 1
    fi

    return 0
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

#------------------------------------------------------------------------------
# Config discovery and management
#------------------------------------------------------------------------------

scan_available_configs() {
    AVAILABLE_CONFIGS=()
    CONFIG_SCRIPTS=()
    CONFIG_DESCRIPTIONS=()
    CONFIG_CATEGORIES=()
    CONFIG_CHECK_COMMANDS=()

    # Reset category organization
    CONFIGS_BY_CATEGORY=()
    CONFIG_CATEGORY_COUNTS=()

    if [[ ! -d "$ADDITIONS_DIR" ]]; then
        dialog --title "Error" --msgbox "Configs directory not found: $ADDITIONS_DIR" $DIALOG_HEIGHT $DIALOG_WIDTH
        clear
        return 1
    fi

    local found=0

    # Use library to scan config scripts
    while IFS=$'\t' read -r script_basename config_name config_description config_category check_command; do
        # Add to arrays
        AVAILABLE_CONFIGS+=("$config_name")
        CONFIG_SCRIPTS+=("$script_basename")
        CONFIG_DESCRIPTIONS+=("$config_description")
        CONFIG_CATEGORIES+=("$config_category")
        CONFIG_CHECK_COMMANDS+=("$check_command")

        # Track config index by category
        local config_index=$found
        if [[ -n "${CONFIGS_BY_CATEGORY[$config_category]}" ]]; then
            CONFIGS_BY_CATEGORY[$config_category]="${CONFIGS_BY_CATEGORY[$config_category]},$config_index"
        else
            CONFIGS_BY_CATEGORY[$config_category]="$config_index"
        fi

        # Increment category count
        CONFIG_CATEGORY_COUNTS[$config_category]=$((${CONFIG_CATEGORY_COUNTS[$config_category]:-0} + 1))

        ((found++))
    done < <(scan_config_scripts "$ADDITIONS_DIR")

    if [[ $found -eq 0 ]]; then
        dialog --title "No Configurations Found" --msgbox "No configuration scripts found in $ADDITIONS_DIR" $DIALOG_HEIGHT $DIALOG_WIDTH
        clear
        return 1
    fi

    return 0
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
# Service category menu
#------------------------------------------------------------------------------

show_service_category_menu() {
    local menu_options=()
    local option_num=1

    # Build menu with categories that have services, in order
    for category_key in "AI_TOOLS" "LANGUAGE_DEV" "INFRA_CONFIG" "DATA_ANALYTICS" "UNCATEGORIZED"; do
        local count=${SERVICE_CATEGORY_COUNTS[$category_key]:-0}

        # Skip empty categories
        if [[ $count -eq 0 ]]; then
            continue
        fi

        local category_name="${CATEGORIES[$category_key]}"
        local help_text="$count service(s) available in this category"

        menu_options+=("$option_num" "$category_name" "$help_text")
        ((option_num++))
    done

    # If no services found in any category
    if [[ ${#menu_options[@]} -eq 0 ]]; then
        dialog --title "No Services" --msgbox "No services found in any category." $DIALOG_HEIGHT $DIALOG_WIDTH
        clear
        return 1
    fi

    # Show category selection menu with dynamic help
    local choice
    choice=$(dialog --clear \
        --item-help \
        --title "Service Management - Select Category" \
        --menu "Choose a category (ESC to return to main menu):" \
        $DIALOG_HEIGHT $DIALOG_WIDTH $MENU_HEIGHT \
        "${menu_options[@]}" \
        2>&1 >/dev/tty)

    # Check if user cancelled (ESC)
    if [[ $? -ne 0 ]]; then
        return 1
    fi

    # Map choice back to category key
    local selected_index=1
    for category_key in "AI_TOOLS" "LANGUAGE_DEV" "INFRA_CONFIG" "DATA_ANALYTICS" "UNCATEGORIZED"; do
        local count=${SERVICE_CATEGORY_COUNTS[$category_key]:-0}
        if [[ $count -eq 0 ]]; then
            continue
        fi

        if [[ $selected_index -eq $choice ]]; then
            echo "$category_key"
            return 0
        fi
        ((selected_index++))
    done

    return 1
}

#------------------------------------------------------------------------------
# Show all services in one menu with category emoji prefixes
#------------------------------------------------------------------------------

show_all_services_menu() {
    while true; do
        # Build menu with ALL services, grouped by category with emoji prefixes
        local menu_options=()
        local option_num=1
        declare -A MENU_TO_SERVICE_INDEX

        # Define category prefix mapping (using text since some emojis don't render in dialog)
        local -A CATEGORY_PREFIX=(
            ["AI_TOOLS"]="[AI]"
            ["LANGUAGE_DEV"]="[DEV]"
            ["INFRA_CONFIG"]="[INFRA]"
            ["DATA_ANALYTICS"]="[DATA]"
            ["UNCATEGORIZED"]="[OTHER]"
        )

        # Iterate through categories in order
        for category_key in "AI_TOOLS" "LANGUAGE_DEV" "INFRA_CONFIG" "DATA_ANALYTICS" "UNCATEGORIZED"; do
            local service_indices="${SERVICES_BY_CATEGORY[$category_key]}"

            # Skip empty categories
            if [[ -z "$service_indices" ]]; then
                continue
            fi

            # Convert comma-separated indices to array
            IFS=',' read -ra INDICES <<< "$service_indices"

            # Add services from this category
            for service_index in "${INDICES[@]}"; do
                local service_name="${AVAILABLE_SERVICES[$service_index]}"
                local service_description="${SERVICE_DESCRIPTIONS[$service_index]}"
                local prefix="${CATEGORY_PREFIX[$category_key]}"

                # Check if service is running
                local status_icon="⏸️"
                if check_service_running "$service_index"; then
                    status_icon="✅"
                fi

                menu_options+=("$option_num" "$status_icon $prefix $service_name" "$service_description")
                MENU_TO_SERVICE_INDEX[$option_num]=$service_index
                ((option_num++))
            done
        done

        # If no services found
        if [[ ${#menu_options[@]} -eq 0 ]]; then
            dialog --title "No Services" --msgbox "No services found." $DIALOG_HEIGHT $DIALOG_WIDTH
            clear
            return 1
        fi

        # Show service selection menu
        local choice
        choice=$(dialog --clear \
            --item-help \
            --title "Service Management" \
            --menu "Choose a service to manage (ESC to go back):\n\n✅=Running  ⏸️=Stopped" \
            $DIALOG_HEIGHT $DIALOG_WIDTH $MENU_HEIGHT \
            "${menu_options[@]}" \
            2>&1 >/dev/tty)

        # Check if user cancelled (ESC)
        if [[ $? -ne 0 ]]; then
            return 0
        fi

        # Get the actual service index from the menu choice
        local selected_service_index=${MENU_TO_SERVICE_INDEX[$choice]}

        # Show service details and actions
        show_service_details_and_actions "$selected_service_index"
    done
}

#------------------------------------------------------------------------------
# Services in category menu (DEPRECATED - kept for backward compatibility)
#------------------------------------------------------------------------------

show_services_in_category() {
    local category_key=$1
    local category_name="${CATEGORIES[$category_key]}"

    # Get service indices for this category
    local service_indices="${SERVICES_BY_CATEGORY[$category_key]}"

    if [[ -z "$service_indices" ]]; then
        dialog --title "No Services" --msgbox "No services found in category: $category_name" $DIALOG_HEIGHT $DIALOG_WIDTH
        clear
        return 1
    fi

    while true; do
        # Build menu with services in this category
        local menu_options=()
        local option_num=1

        # Convert comma-separated indices to array
        IFS=',' read -ra INDICES <<< "$service_indices"

        for service_index in "${INDICES[@]}"; do
            local service_name="${AVAILABLE_SERVICES[$service_index]}"
            local service_description="${SERVICE_DESCRIPTIONS[$service_index]}"

            # Check if service is running
            local status_icon="⏸️"
            if check_service_running "$service_index"; then
                status_icon="✅"
            fi

            menu_options+=("$option_num" "$status_icon $service_name" "$service_description")
            ((option_num++))
        done

        # Show service selection menu with dynamic help
        local choice
        choice=$(dialog --clear \
            --item-help \
            --title "Service Management - $category_name" \
            --menu "Choose a service to manage (ESC to go back):" \
            $DIALOG_HEIGHT $DIALOG_WIDTH $MENU_HEIGHT \
            "${menu_options[@]}" \
            2>&1 >/dev/tty)

        # Check if user cancelled (ESC - go back to category menu)
        if [[ $? -ne 0 ]]; then
            return 0
        fi

        # Map choice to actual service index
        local selected_service_index=${INDICES[$((choice - 1))]}

        # Show service details and actions
        show_service_details_and_actions "$selected_service_index"
    done
}

#------------------------------------------------------------------------------
# Service details and actions
#------------------------------------------------------------------------------

show_service_details_and_actions() {
    local service_index=$1
    local service_name="${AVAILABLE_SERVICES[$service_index]}"
    local service_description="${SERVICE_DESCRIPTIONS[$service_index]}"
    local stop_script="${SERVICE_STOP_SCRIPTS[$service_index]}"

    # Check if service is running
    local is_running=false
    if check_service_running "$service_index"; then
        is_running=true
    fi

    # Build menu based on current state
    local menu_options=()
    local status_text

    if [[ "$is_running" = true ]]; then
        status_text="Status: Running ✅"
        menu_options+=("1" "Stop service")

        # Only show Restart if stop script exists
        if [[ -n "$stop_script" ]]; then
            menu_options+=("2" "Restart service")
        fi

        menu_options+=("3" "Back to service list")
    else
        status_text="Status: Stopped ⏸️"
        menu_options+=("1" "Start service")
        menu_options+=("2" "Back to service list")
    fi

    # Show service details with available actions
    local user_choice
    user_choice=$(dialog --clear \
        --title "Service: $service_name" \
        --menu "$service_description\n\n$status_text\n\nWhat would you like to do?" \
        $DIALOG_HEIGHT $DIALOG_WIDTH 6 \
        "${menu_options[@]}" \
        2>&1 >/dev/tty)

    # Handle user choice
    if [[ $? -ne 0 ]]; then
        # User pressed ESC - go back
        return 0
    fi

    if [[ "$is_running" = true ]]; then
        case $user_choice in
            1)
                execute_service_action "$service_index" "stop"
                ;;
            2)
                if [[ -n "$stop_script" ]]; then
                    execute_service_action "$service_index" "restart"
                fi
                ;;
            3|"")
                # Go back to service list
                ;;
        esac
    else
        case $user_choice in
            1)
                execute_service_action "$service_index" "start"
                ;;
            2|"")
                # Go back to service list
                ;;
        esac
    fi
}

execute_service_action() {
    local service_index=$1
    local action=$2
    local service_name="${AVAILABLE_SERVICES[$service_index]}"
    local start_script="${SERVICE_START_SCRIPTS[$service_index]}"
    local stop_script="${SERVICE_STOP_SCRIPTS[$service_index]}"

    clear
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    case $action in
        start)
            echo "Starting: $service_name"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo ""

            local start_path="$ADDITIONS_DIR/$start_script"
            if [[ ! -f "$start_path" ]]; then
                echo "❌ Error: Start script not found: $start_path"
            else
                chmod +x "$start_path"
                if bash "$start_path"; then
                    echo ""
                    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                    echo "✅ Successfully started: $service_name"
                    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                else
                    echo ""
                    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                    echo "❌ Failed to start: $service_name"
                    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                fi
            fi
            ;;
        stop)
            echo "Stopping: $service_name"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo ""

            if [[ -z "$stop_script" ]]; then
                echo "❌ Error: No stop script available for this service"
            else
                local stop_path="$ADDITIONS_DIR/$stop_script"
                if [[ ! -f "$stop_path" ]]; then
                    echo "❌ Error: Stop script not found: $stop_path"
                else
                    chmod +x "$stop_path"
                    if bash "$stop_path"; then
                        echo ""
                        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                        echo "✅ Successfully stopped: $service_name"
                        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                    else
                        echo ""
                        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                        echo "❌ Failed to stop: $service_name"
                        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                    fi
                fi
            fi
            ;;
        restart)
            echo "Restarting: $service_name"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo ""

            if [[ -z "$stop_script" ]]; then
                echo "❌ Error: No stop script available for restart"
            else
                local stop_path="$ADDITIONS_DIR/$stop_script"
                local start_path="$ADDITIONS_DIR/$start_script"

                # Stop first
                echo "Stopping service..."
                chmod +x "$stop_path"
                bash "$stop_path"

                echo ""
                echo "Waiting 2 seconds..."
                sleep 2
                echo ""

                # Then start
                echo "Starting service..."
                chmod +x "$start_path"
                if bash "$start_path"; then
                    echo ""
                    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                    echo "✅ Successfully restarted: $service_name"
                    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                else
                    echo ""
                    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                    echo "❌ Failed to restart: $service_name"
                    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                fi
            fi
            ;;
    esac

    echo ""
    read -p "Press Enter to continue..." -r
}

#------------------------------------------------------------------------------
# Show auto-start enabled services
#------------------------------------------------------------------------------

show_autostart_services() {
    local enabled_conf="/workspace/.devcontainer.extend/enabled-services.conf"

    # Read enabled services
    local enabled_services=()
    if [[ -f "$enabled_conf" ]]; then
        while IFS= read -r line; do
            # Skip comments and empty lines
            [[ "$line" =~ ^#.*$ ]] && continue
            [[ -z "$line" ]] && continue
            enabled_services+=("$line")
        done < "$enabled_conf"
    fi

    # Build message
    local message="Services configured to auto-start on container restart:\n\n"

    if [[ ${#enabled_services[@]} -eq 0 ]]; then
        message+="No services enabled for auto-start.\n\n"
        message+="Services will auto-enable themselves when first started successfully."
    else
        for service_id in "${enabled_services[@]}"; do
            message+="  ✅ $service_id\n"
        done
        message+="\nThese services will automatically start when the container restarts.\n\n"
        message+="Manage: dev-services enable/disable <service>"
    fi

    dialog --title "Auto-Start Services" --msgbox "$message" $DIALOG_HEIGHT $DIALOG_WIDTH
    clear
}

#------------------------------------------------------------------------------
# Service management main function
#------------------------------------------------------------------------------

manage_services() {
    if ! scan_available_services; then
        return 1
    fi

    while true; do
        # Show service management menu
        local choice
        choice=$(dialog --clear \
            --title "Service Management" \
            --menu "Choose an option (ESC to return to main menu):" \
            $DIALOG_HEIGHT $DIALOG_WIDTH $MENU_HEIGHT \
            "1" "Start/Stop Services" \
            "2" "View Auto-Start Services" \
            "3" "Back to Main Menu" \
            2>&1 >/dev/tty)

        # Check if user cancelled (ESC)
        if [[ $? -ne 0 ]]; then
            return 0
        fi

        case $choice in
            1)
                # Show all services in one menu with emoji category prefixes
                show_all_services_menu
                ;;
            2)
                show_autostart_services
                ;;
            3|"")
                return 0
                ;;
        esac
    done
}

#------------------------------------------------------------------------------
# Config category menu
#------------------------------------------------------------------------------

show_config_category_menu() {
    local menu_options=()
    local option_num=1

    # Build menu with categories that have configs, in order
    for category_key in "AI_TOOLS" "LANGUAGE_DEV" "INFRA_CONFIG" "DATA_ANALYTICS" "UNCATEGORIZED"; do
        local count=${CONFIG_CATEGORY_COUNTS[$category_key]:-0}

        # Skip empty categories
        if [[ $count -eq 0 ]]; then
            continue
        fi

        local category_name="${CATEGORIES[$category_key]}"
        local help_text="$count configuration(s) available in this category"

        menu_options+=("$option_num" "$category_name" "$help_text")
        ((option_num++))
    done

    # If no configs found in any category
    if [[ ${#menu_options[@]} -eq 0 ]]; then
        dialog --title "No Configurations" --msgbox "No configurations found in any category." $DIALOG_HEIGHT $DIALOG_WIDTH
        clear
        return 1
    fi

    # Show category selection menu with dynamic help
    local choice
    choice=$(dialog --clear \
        --item-help \
        --title "Setup & Configuration - Select Category" \
        --menu "Choose a category (ESC to return to main menu):" \
        $DIALOG_HEIGHT $DIALOG_WIDTH $MENU_HEIGHT \
        "${menu_options[@]}" \
        2>&1 >/dev/tty)

    # Check if user cancelled (ESC)
    if [[ $? -ne 0 ]]; then
        return 1
    fi

    # Map choice back to category key
    local selected_index=1
    for category_key in "AI_TOOLS" "LANGUAGE_DEV" "INFRA_CONFIG" "DATA_ANALYTICS" "UNCATEGORIZED"; do
        local count=${CONFIG_CATEGORY_COUNTS[$category_key]:-0}
        if [[ $count -eq 0 ]]; then
            continue
        fi

        if [[ $selected_index -eq $choice ]]; then
            echo "$category_key"
            return 0
        fi
        ((selected_index++))
    done

    return 1
}

#------------------------------------------------------------------------------
# Configs in category menu
#------------------------------------------------------------------------------

show_configs_in_category() {
    local category_key=$1
    local category_name="${CATEGORIES[$category_key]}"

    # Get config indices for this category
    local config_indices="${CONFIGS_BY_CATEGORY[$category_key]}"

    if [[ -z "$config_indices" ]]; then
        dialog --title "No Configurations" --msgbox "No configurations found in category: $category_name" $DIALOG_HEIGHT $DIALOG_WIDTH
        clear
        return 1
    fi

    while true; do
        # Build menu with configs in this category
        local menu_options=()
        local option_num=1

        # Convert comma-separated indices to array
        IFS=',' read -ra INDICES <<< "$config_indices"

        for config_index in "${INDICES[@]}"; do
            local config_name="${AVAILABLE_CONFIGS[$config_index]}"
            local config_description="${CONFIG_DESCRIPTIONS[$config_index]}"

            # Check if config is configured
            local status_icon="❌"
            if check_config_configured "$config_index"; then
                status_icon="✅"
            fi

            menu_options+=("$option_num" "$status_icon $config_name" "$config_description")
            ((option_num++))
        done

        # Show config selection menu with dynamic help
        local choice
        choice=$(dialog --clear \
            --item-help \
            --title "Setup & Configuration - $category_name" \
            --menu "Choose a configuration to run (ESC to go back):" \
            $DIALOG_HEIGHT $DIALOG_WIDTH $MENU_HEIGHT \
            "${menu_options[@]}" \
            2>&1 >/dev/tty)

        # Check if user cancelled (ESC - go back to category menu)
        if [[ $? -ne 0 ]]; then
            return 0
        fi

        # Map choice to actual config index
        local selected_config_index=${INDICES[$((choice - 1))]}

        # Show config details and actions
        show_config_details_and_actions "$selected_config_index"
    done
}

#------------------------------------------------------------------------------
# Config details and actions
#------------------------------------------------------------------------------

show_config_details_and_actions() {
    local config_index=$1
    local config_name="${AVAILABLE_CONFIGS[$config_index]}"
    local config_description="${CONFIG_DESCRIPTIONS[$config_index]}"

    # Check if config is configured
    local is_configured=false
    if check_config_configured "$config_index"; then
        is_configured=true
    fi

    # Build menu based on current state
    local menu_options=()
    local status_text

    if [[ "$is_configured" = true ]]; then
        status_text="Status: Configured ✅"
        menu_options+=("1" "Reconfigure")
        menu_options+=("2" "Back to configuration list")
    else
        status_text="Status: Not configured ❌"
        menu_options+=("1" "Configure now")
        menu_options+=("2" "Back to configuration list")
    fi

    # Show config details with available actions
    local user_choice
    user_choice=$(dialog --clear \
        --title "Configuration: $config_name" \
        --menu "$config_description\n\n$status_text\n\nWhat would you like to do?" \
        $DIALOG_HEIGHT $DIALOG_WIDTH 6 \
        "${menu_options[@]}" \
        2>&1 >/dev/tty)

    # Handle user choice
    if [[ $? -ne 0 ]]; then
        # User pressed ESC - go back
        return 0
    fi

    case $user_choice in
        1)
            execute_config_script "$config_index"
            ;;
        2|"")
            # Go back to config list
            ;;
    esac
}

execute_config_script() {
    local config_index=$1
    local config_name="${AVAILABLE_CONFIGS[$config_index]}"
    local script_name="${CONFIG_SCRIPTS[$config_index]}"

    clear
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Running Configuration: $config_name"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    local script_path="$ADDITIONS_DIR/$script_name"
    if [[ ! -f "$script_path" ]]; then
        echo "❌ Error: Configuration script not found: $script_path"
    else
        chmod +x "$script_path"
        if bash "$script_path"; then
            echo ""
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "✅ Configuration completed: $config_name"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        else
            echo ""
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "❌ Configuration failed: $config_name"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        fi
    fi

    echo ""
    read -p "Press Enter to continue..." -r
}

#------------------------------------------------------------------------------
# Config management main function
#------------------------------------------------------------------------------

manage_configs() {
    if ! scan_available_configs; then
        return 1
    fi

    while true; do
        # Step 1: Show category menu
        local selected_category
        selected_category=$(show_config_category_menu)

        # If user cancelled or error, exit
        if [[ $? -ne 0 || -z "$selected_category" ]]; then
            return 0
        fi

        # Step 2: Show configs in selected category
        show_configs_in_category "$selected_category"
    done
}

#------------------------------------------------------------------------------
# Category menu
#------------------------------------------------------------------------------

show_category_menu() {
    local menu_options=()
    local option_num=1
    
    # Build menu with categories that have tools, in order
    for category_key in "AI_TOOLS" "LANGUAGE_DEV" "INFRA_CONFIG" "DATA_ANALYTICS" "UNCATEGORIZED"; do
        local count=${CATEGORY_COUNTS[$category_key]:-0}
        
        # Skip empty categories (except UNCATEGORIZED if it has tools)
        if [[ $count -eq 0 ]]; then
            continue
        fi
        
        local category_name="${CATEGORIES[$category_key]}"
        local help_text="$count tool(s) available in this category"
        
        menu_options+=("$option_num" "$category_name" "$help_text")
        ((option_num++))
    done
    
    # If no tools found in any category
    if [[ ${#menu_options[@]} -eq 0 ]]; then
        dialog --title "No Tools" --msgbox "No development tools found in any category." $DIALOG_HEIGHT $DIALOG_WIDTH
        clear
        return 1
    fi
    
    # Show category selection menu with dynamic help
    local choice
    choice=$(dialog --clear \
        --item-help \
        --title "Tools - Select Category" \
        --menu "Choose a category (ESC to return to main menu):" \
        $DIALOG_HEIGHT $DIALOG_WIDTH $MENU_HEIGHT \
        "${menu_options[@]}" \
        2>&1 >/dev/tty)
    
    # Check if user cancelled (ESC)
    if [[ $? -ne 0 ]]; then
        return 1
    fi
    
    # Map choice back to category key
    local selected_index=1
    for category_key in "AI_TOOLS" "LANGUAGE_DEV" "INFRA_CONFIG" "DATA_ANALYTICS" "UNCATEGORIZED"; do
        local count=${CATEGORY_COUNTS[$category_key]:-0}
        if [[ $count -eq 0 ]]; then
            continue
        fi
        
        if [[ $selected_index -eq $choice ]]; then
            echo "$category_key"
            return 0
        fi
        ((selected_index++))
    done
    
    return 1
}

#------------------------------------------------------------------------------
# Tools in category menu
#------------------------------------------------------------------------------

show_tools_in_category() {
    local category_key=$1
    local category_name="${CATEGORIES[$category_key]}"
    
    # Get tool indices for this category
    local tool_indices="${TOOLS_BY_CATEGORY[$category_key]}"
    
    if [[ -z "$tool_indices" ]]; then
        dialog --title "No Tools" --msgbox "No tools found in category: $category_name" $DIALOG_HEIGHT $DIALOG_WIDTH
        clear
        return 1
    fi
    
    while true; do
        # Build menu with tools in this category
        local menu_options=()
        local option_num=1
        
        # Convert comma-separated indices to array
        IFS=',' read -ra INDICES <<< "$tool_indices"
        
        for tool_index in "${INDICES[@]}"; do
            local tool_name="${AVAILABLE_TOOLS[$tool_index]}"
            local tool_description="${TOOL_DESCRIPTIONS[$tool_index]}"
            local tool_script="${TOOL_SCRIPTS[$tool_index]}"

            # Check if tool is installed
            local status_icon="❌"
            if check_tool_installed "$tool_script"; then
                status_icon="✅"
            fi

            menu_options+=("$option_num" "$status_icon $tool_name" "$tool_description")
            ((option_num++))
        done
        
        # Show tool selection menu with dynamic help
        local choice
        choice=$(dialog --clear \
            --item-help \
            --title "Tools - $category_name" \
            --menu "Choose a tool to install (ESC to go back):" \
            $DIALOG_HEIGHT $DIALOG_WIDTH $MENU_HEIGHT \
            "${menu_options[@]}" \
            2>&1 >/dev/tty)
        
        # Check if user cancelled (ESC - go back to category menu)
        if [[ $? -ne 0 ]]; then
            return 0
        fi
        
        # Map choice to actual tool index
        local selected_tool_index=${INDICES[$((choice - 1))]}
        
        # Show tool details and confirm installation
        show_tool_details_and_confirm "$selected_tool_index"
    done
}

#------------------------------------------------------------------------------
# Tool installation
#------------------------------------------------------------------------------

install_tools() {
    if ! scan_available_tools; then
        return 1
    fi
    
    while true; do
        # Step 1: Show category menu
        local selected_category
        selected_category=$(show_category_menu)
        
        # If user cancelled or error, exit
        if [[ $? -ne 0 || -z "$selected_category" ]]; then
            return 0
        fi
        
        # Step 2: Show tools in selected category
        show_tools_in_category "$selected_category"
    done
}

# Show tool details and get user decision
show_tool_details_and_confirm() {
    local tool_index=$1
    local tool_name="${AVAILABLE_TOOLS[$tool_index]}"
    local tool_description="${TOOL_DESCRIPTIONS[$tool_index]}"
    
    # Show tool details with Install/Back options
    local user_choice
    user_choice=$(dialog --clear \
        --title "Tool Details: $tool_name" \
        --menu "$tool_description\n\nWhat would you like to do?" \
        $DIALOG_HEIGHT $DIALOG_WIDTH 4 \
        "1" "Install this tool" \
        "2" "Back to tool list" \
        2>&1 >/dev/tty)
    
    case $user_choice in
        1)
            execute_tool_installation "$tool_index"
            ;;
        2|"")
            # Go back to tool list (do nothing, loop will continue)
            ;;
    esac
}

execute_tool_installation() {
    local tool_index=$1
    local tool_name="${AVAILABLE_TOOLS[$tool_index]}"
    local script_name="${TOOL_SCRIPTS[$tool_index]}"
    local script_path="$ADDITIONS_DIR/$script_name"
    
    if [[ ! -f "$script_path" ]]; then
        dialog --title "Error" --msgbox "Installation script not found: $script_path" $DIALOG_HEIGHT $DIALOG_WIDTH
        clear
        return 1
    fi
    
    # Clear screen and show installation
    clear
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Installing: $tool_name"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    # Make script executable and run it
    chmod +x "$script_path"
    
    if bash "$script_path"; then
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "✅ Successfully installed: $tool_name"
        echo ""
        echo "💡 To make this permanent for your team:"
        echo "   Add this line to your setup documentation:"
        echo "   bash .devcontainer/additions/$script_name"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    else
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "❌ Failed to install: $tool_name"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    fi
    
    echo ""
    read -p "Press Enter to continue..." -r
}

#------------------------------------------------------------------------------
# Template management
#------------------------------------------------------------------------------

# Create project from template - calls dev-template.sh
create_project_from_template() {
    clear
    
    if [[ ! -f "$DEV_TEMPLATE_SCRIPT" ]]; then
        echo "❌ Error: dev-template.sh not found at $DEV_TEMPLATE_SCRIPT"
        echo ""
        read -p "Press Enter to return to menu..." -r
        return 1
    fi
    
    # Make script executable
    chmod +x "$DEV_TEMPLATE_SCRIPT"
    
    # Run dev-template.sh which handles everything:
    # - Clones templates from GitHub
    # - Shows categorized menu
    # - Processes selected template
    bash "$DEV_TEMPLATE_SCRIPT" --skip-update
    
    echo ""
    read -p "Press Enter to continue..." -r
}

#------------------------------------------------------------------------------
# Environment information
#------------------------------------------------------------------------------

# Function to check if a tool is installed by reading CHECK_INSTALLED_COMMAND from the script
check_tool_installed() {
    local script_name="$1"
    local script_path="$ADDITIONS_DIR/$script_name"

    # Extract check command using library
    local check_command=$(extract_script_metadata "$script_path" "CHECK_INSTALLED_COMMAND")

    # Check using library
    check_component_installed "$check_command"
    return $?
}

show_environment_info() {
    clear
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
    if scan_available_tools >/dev/null 2>&1; then
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
    if scan_available_services >/dev/null 2>&1; then
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

    if scan_available_configs >/dev/null 2>&1; then
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
    read -p "Press Enter to return to menu..." -r
    clear
}

# Non-interactive version for use in startup scripts
show_environment_info_non_interactive() {
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
    if scan_available_tools >/dev/null 2>&1; then
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
    if scan_available_services >/dev/null 2>&1; then
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

    if scan_available_configs >/dev/null 2>&1; then
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
# Main menu and execution
#------------------------------------------------------------------------------

show_main_menu() {
    # Disable exit-on-error for interactive menus
    set +e

    while true; do
        local choice
        choice=$(dialog --clear \
            --title "$SCRIPT_NAME v$SCRIPT_VERSION" \
            --menu "Choose an option:" \
            $DIALOG_HEIGHT $DIALOG_WIDTH $MENU_HEIGHT \
            "1" "Browse & Install Tools" \
            "2" "Manage Services" \
            "3" "Setup & Configuration" \
            "4" "Create project from template" \
            "5" "Show Environment Info" \
            "6" "Exit" \
            2>&1 >/dev/tty)

        # Check if user cancelled (ESC or Cancel button)
        if [[ $? -ne 0 ]]; then
            if dialog --title "Confirm Exit" --yesno "Are you sure you want to exit?" 8 50; then
                clear
                echo ""
                echo "✅ Thanks for using $SCRIPT_NAME! 🚀"
                exit 0
            fi
            continue
        fi

        # Handle menu choice
        case $choice in
            1)
                install_tools
                ;;
            2)
                manage_services
                ;;
            3)
                manage_configs
                ;;
            4)
                create_project_from_template
                ;;
            5)
                show_environment_info
                ;;
            6)
                clear
                echo ""
                echo "✅ Thanks for using $SCRIPT_NAME! 🚀"
                exit 0
                ;;
            *)
                dialog --title "Error" --msgbox "Invalid selection: $choice" 8 50
                clear
                ;;
        esac
    done
}

#------------------------------------------------------------------------------
# Main execution
#------------------------------------------------------------------------------

main() {
    # Parse command line arguments
    case "${1:-}" in
        --help|-h)
            show_help
            exit 0
            ;;
        --version|-v)
            show_version
            exit 0
            ;;
        "")
            # No arguments - run interactive mode
            ;;
        *)
            echo "❌ Error: Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
    
    # Check requirements and environment
    check_dialog
    check_environment
    
    # Start main menu
    show_main_menu
}

# Trap interrupts for clean exit
trap 'echo ""; echo "ℹ️  Operation cancelled by user"; exit 3' INT TERM

# Execute main function
main "$@"
