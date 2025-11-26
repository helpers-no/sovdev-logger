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
declare -a SERVICE_PREREQUISITE_CONFIGS=()

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
    SERVICE_PREREQUISITE_CONFIGS=()

    # Reset category organization
    SERVICES_BY_CATEGORY=()
    SERVICE_CATEGORY_COUNTS=()

    if [[ ! -d "$ADDITIONS_DIR" ]]; then
        dialog --title "Error" --msgbox "Services directory not found: $ADDITIONS_DIR" $DIALOG_HEIGHT $DIALOG_WIDTH
        clear
        return 1
    fi

    local found=0

    # Scan for service-*.sh scripts
    while IFS=$'\t' read -r script_basename service_name service_description service_category script_path prerequisite_configs; do
        # Add to arrays
        AVAILABLE_SERVICES+=("$service_name")
        SERVICE_SCRIPTS+=("$script_basename")
        SERVICE_DESCRIPTIONS+=("$service_description")
        SERVICE_CATEGORIES+=("$service_category")
        SERVICE_PREREQUISITE_CONFIGS+=("$prerequisite_configs")

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
    done < <(scan_service_scripts_new "$ADDITIONS_DIR")

    if [[ $found -eq 0 ]]; then
        dialog --title "No Services Found" --msgbox "No services found in $ADDITIONS_DIR" $DIALOG_HEIGHT $DIALOG_WIDTH
        clear
        return 1
    fi

    return 0
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
# CMD script discovery and management
#------------------------------------------------------------------------------

scan_available_cmds() {
    AVAILABLE_CMDS=()
    CMD_SCRIPTS=()
    CMD_DESCRIPTIONS=()
    CMD_CATEGORIES=()
    CMD_SCRIPT_PATHS=()
    CMD_PREREQUISITE_CONFIGS=()

    # Reset category organization
    CMDS_BY_CATEGORY=()
    CMD_CATEGORY_COUNTS=()

    if [[ ! -d "$ADDITIONS_DIR" ]]; then
        dialog --title "Error" --msgbox "Commands directory not found: $ADDITIONS_DIR" $DIALOG_HEIGHT $DIALOG_WIDTH
        clear
        return 1
    fi

    local found=0

    # Use library to scan cmd scripts
    while IFS=$'\t' read -r script_basename cmd_name cmd_description cmd_category script_path prerequisite_configs; do
        # Add to arrays
        AVAILABLE_CMDS+=("$cmd_name")
        CMD_SCRIPTS+=("$script_basename")
        CMD_DESCRIPTIONS+=("$cmd_description")
        CMD_CATEGORIES+=("$cmd_category")
        CMD_SCRIPT_PATHS+=("$script_path")
        CMD_PREREQUISITE_CONFIGS+=("$prerequisite_configs")

        # Track cmd index by category
        local cmd_index=$found
        if [[ -n "${CMDS_BY_CATEGORY[$cmd_category]}" ]]; then
            CMDS_BY_CATEGORY[$cmd_category]="${CMDS_BY_CATEGORY[$cmd_category]},$cmd_index"
        else
            CMDS_BY_CATEGORY[$cmd_category]="$cmd_index"
        fi

        # Increment category count
        CMD_CATEGORY_COUNTS[$cmd_category]=$((${CMD_CATEGORY_COUNTS[$cmd_category]:-0} + 1))

        ((found++))
    done < <(scan_cmd_scripts "$ADDITIONS_DIR")

    if [[ $found -eq 0 ]]; then
        dialog --title "No Command Scripts Found" --msgbox "No command scripts found in $ADDITIONS_DIR" $DIALOG_HEIGHT $DIALOG_WIDTH
        clear
        return 1
    fi

    return 0
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

                menu_options+=("$option_num" "$prefix $service_name" "$service_description")
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
# Service submenu - Show commands from selected service-*.sh script
#------------------------------------------------------------------------------

show_service_submenu() {
    local service_index=$1
    local service_name="${AVAILABLE_SERVICES[$service_index]}"
    local script_name="${SERVICE_SCRIPTS[$service_index]}"
    local script_path="$ADDITIONS_DIR/$script_name"
    local prerequisite_configs="${SERVICE_PREREQUISITE_CONFIGS[$service_index]}"

    # Check prerequisites first
    if [[ -n "$prerequisite_configs" ]]; then
        # Source prerequisite-check library
        source "$ADDITIONS_DIR/lib/prerequisite-check.sh"

        if ! check_prerequisite_configs "$prerequisite_configs" "$ADDITIONS_DIR"; then
            # Show missing prerequisites
            local missing_msg=$(show_missing_prerequisites "$prerequisite_configs" "$ADDITIONS_DIR")
            dialog --title "Prerequisites Not Met" \
                --msgbox "Cannot run $service_name. Prerequisites not met:\n\n$missing_msg\n\nPlease configure required items first." \
                20 70
            clear
            return 1
        fi
    fi

    while true; do
        # Extract COMMANDS array from the script
        local commands=()
        while IFS= read -r cmd_def; do
            commands+=("$cmd_def")
        done < <(extract_service_commands "$script_path")

        if [[ ${#commands[@]} -eq 0 ]]; then
            dialog --title "No Commands" --msgbox "No commands found in $service_name" $DIALOG_HEIGHT $DIALOG_WIDTH
            clear
            return 1
        fi

        # Build menu with category prefixes (like cmd-*.sh display)
        local menu_options=()
        local menu_actions=()
        local option_num=1

        for cmd_def in "${commands[@]}"; do
            IFS='|' read -r category flag description function requires_arg param_prompt <<< "$cmd_def"

            # Add command with category prefix
            local display_text="[$category] $description"
            menu_options+=("$option_num" "$display_text" "$flag")
            menu_actions[$option_num]="$flag|$requires_arg|$param_prompt"
            ((option_num++))
        done

        # Add back option
        menu_options+=("0" "Back to Service List" "")

        # Show submenu
        local choice
        choice=$(dialog --clear \
            --item-help \
            --title "$service_name" \
            --menu "Select a command (ESC to go back):" \
            $DIALOG_HEIGHT $DIALOG_WIDTH $MENU_HEIGHT \
            "${menu_options[@]}" \
            2>&1 >/dev/tty)

        # Check if user cancelled (ESC)
        if [[ $? -ne 0 ]]; then
            return 0
        fi

        # Handle back option
        if [[ $choice -eq 0 || -z "$choice" ]]; then
            return 0
        fi

        # Execute selected command
        local action_def="${menu_actions[$choice]}"
        if [[ -n "$action_def" ]]; then
            execute_service_cmd_action "$script_path" "$action_def"
        fi
    done
}

#------------------------------------------------------------------------------
# Service details and actions
#------------------------------------------------------------------------------

show_service_details_and_actions() {
    local service_index=$1
    # Show service-*.sh COMMANDS array menu
    show_service_submenu "$service_index"
}

execute_service_cmd_action() {
    local script_path="$1"
    local action_def="$2"

    IFS='|' read -r flag requires_arg param_prompt <<< "$action_def"

    local cmd_args=("$flag")

    # Prompt for parameter if needed
    if [[ "$requires_arg" = "true" ]]; then
        local param_value
        param_value=$(dialog --clear \
            --title "Parameter Required" \
            --inputbox "$param_prompt:" \
            8 60 \
            2>&1 >/dev/tty)

        # Check if user cancelled
        if [[ $? -ne 0 ]]; then
            return 0
        fi

        if [[ -n "$param_value" ]]; then
            cmd_args+=("$param_value")
        else
            dialog --msgbox "Parameter required - command cancelled" 6 40
            clear
            return 1
        fi
    fi

    # Execute command
    clear
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Executing: $(basename "$script_path") ${cmd_args[*]}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    bash "$script_path" "${cmd_args[@]}"

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    read -p "Press Enter to continue..." -r
    clear
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
# CMD submenu - Show commands from selected script
#------------------------------------------------------------------------------

show_cmd_submenu() {
    local cmd_index=$1
    local cmd_name="${AVAILABLE_CMDS[$cmd_index]}"
    local script_path="${CMD_SCRIPT_PATHS[$cmd_index]}"
    local prerequisite_configs="${CMD_PREREQUISITE_CONFIGS[$cmd_index]}"

    # Check prerequisites first
    if [[ -n "$prerequisite_configs" ]]; then
        # Source prerequisite-check library
        source "$ADDITIONS_DIR/lib/prerequisite-check.sh"

        if ! check_prerequisite_configs "$prerequisite_configs" "$ADDITIONS_DIR"; then
            # Show missing prerequisites
            local missing_msg=$(show_missing_prerequisites "$prerequisite_configs" "$ADDITIONS_DIR")
            dialog --title "Prerequisites Not Met" \
                --msgbox "Cannot run $cmd_name. Prerequisites not met:\n\n$missing_msg\n\nPlease configure required items first." \
                20 70
            clear
            return 1
        fi
    fi

    while true; do
        # Extract COMMANDS array from the script
        local commands=()
        while IFS= read -r cmd_def; do
            commands+=("$cmd_def")
        done < <(extract_cmd_commands "$script_path")

        if [[ ${#commands[@]} -eq 0 ]]; then
            dialog --title "No Commands" --msgbox "No commands found in $cmd_name" $DIALOG_HEIGHT $DIALOG_WIDTH
            clear
            return 1
        fi

        # Build menu with category prefixes (like services display)
        local menu_options=()
        local menu_actions=()
        local option_num=1

        for cmd_def in "${commands[@]}"; do
            IFS='|' read -r category flag description function requires_arg param_prompt <<< "$cmd_def"

            # Add command with category prefix
            local display_text="[$category] $description"
            menu_options+=("$option_num" "$display_text" "$flag")
            menu_actions[$option_num]="$flag|$requires_arg|$param_prompt"
            ((option_num++))
        done

        # Add back option
        menu_options+=("0" "Back to Command Tools" "")

        # Show submenu
        local choice
        choice=$(dialog --clear \
            --item-help \
            --title "$cmd_name" \
            --menu "Select a command (ESC to go back):" \
            $DIALOG_HEIGHT $DIALOG_WIDTH $MENU_HEIGHT \
            "${menu_options[@]}" \
            2>&1 >/dev/tty)

        # Check if user cancelled (ESC)
        if [[ $? -ne 0 ]]; then
            return 0
        fi

        # Handle back option
        if [[ $choice -eq 0 || -z "$choice" ]]; then
            return 0
        fi

        # Execute selected command
        local action_def="${menu_actions[$choice]}"
        if [[ -n "$action_def" ]]; then
            execute_cmd_action "$script_path" "$action_def"
        fi
    done
}

execute_cmd_action() {
    local script_path="$1"
    local action_def="$2"

    IFS='|' read -r flag requires_arg param_prompt <<< "$action_def"

    local cmd_args=("$flag")

    # Prompt for parameter if needed
    if [[ "$requires_arg" = "true" ]]; then
        local param_value
        param_value=$(dialog --clear \
            --title "Parameter Required" \
            --inputbox "$param_prompt:" \
            8 60 \
            2>&1 >/dev/tty)

        # Check if user cancelled
        if [[ $? -ne 0 ]]; then
            return 0
        fi

        if [[ -n "$param_value" ]]; then
            cmd_args+=("$param_value")
        else
            dialog --msgbox "Parameter required - command cancelled" 6 40
            clear
            return 1
        fi
    fi

    # Execute command
    clear
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Executing: $(basename "$script_path") ${cmd_args[*]}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    "$script_path" "${cmd_args[@]}"

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    read -p "Press Enter to continue..." -r
    clear
}

#------------------------------------------------------------------------------
# Config management main function
#------------------------------------------------------------------------------

manage_cmds() {
    if ! scan_available_cmds; then
        return 1
    fi

    while true; do
        # Build menu with all cmd scripts
        local menu_options=()
        local option_num=1

        for i in "${!AVAILABLE_CMDS[@]}"; do
            local cmd_name="${AVAILABLE_CMDS[$i]}"
            local cmd_description="${CMD_DESCRIPTIONS[$i]}"

            menu_options+=("$option_num" "$cmd_name" "$cmd_description")
            ((option_num++))
        done

        # Add back option
        menu_options+=("0" "Back to Main Menu" "")

        # Show command scripts menu
        local choice
        choice=$(dialog --clear \
            --item-help \
            --title "Command Tools" \
            --menu "Select a command tool (ESC to return to main menu):" \
            $DIALOG_HEIGHT $DIALOG_WIDTH $MENU_HEIGHT \
            "${menu_options[@]}" \
            2>&1 >/dev/tty)

        # Check if user cancelled (ESC)
        if [[ $? -ne 0 ]]; then
            return 0
        fi

        # Handle back option
        if [[ $choice -eq 0 ]]; then
            return 0
        fi

        # Convert choice to array index (choice 1 = index 0)
        local cmd_index=$((choice - 1))

        # Show command submenu for selected script
        show_cmd_submenu "$cmd_index"
    done
}

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
            "4" "Command Tools" \
            "5" "Create project from template" \
            "6" "Show Environment Info" \
            "7" "Exit" \
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
                manage_cmds
                ;;
            5)
                create_project_from_template
                ;;
            6)
                clear
                bash "$ADDITIONS_DIR/show-environment.sh"
                read -p "Press Enter to return to menu..." -r
                clear
                ;;
            7)
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
