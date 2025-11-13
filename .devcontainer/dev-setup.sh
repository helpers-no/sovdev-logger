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
SCRIPT_VERSION="3.3.0"
SCRIPT_NAME="DevContainer Setup"
DEVCONTAINER_DIR=".devcontainer"
ADDITIONS_DIR="$DEVCONTAINER_DIR/additions"
DEV_TEMPLATE_SCRIPT="$DEVCONTAINER_DIR/dev/dev-template.sh"

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
    
    # Scan for install scripts (excluding templates and subdirectories)
    for script in "$ADDITIONS_DIR"/install-*.sh; do
        # Skip if it's a directory or doesn't exist
        [[ ! -f "$script" ]] && continue
        
        # Skip template files
        [[ "$script" =~ _template ]] && continue
        
        local script_name=""
        local script_description=""
        local script_category=""
        
        # Extract metadata from the file
        script_name=$(grep -m 1 '^SCRIPT_NAME=' "$script" 2>/dev/null | sed 's/.*"\(.*\)".*/\1/')
        script_description=$(grep -m 1 '^SCRIPT_DESCRIPTION=' "$script" 2>/dev/null | sed 's/.*"\(.*\)".*/\1/')
        script_category=$(grep -m 1 '^SCRIPT_CATEGORY=' "$script" 2>/dev/null | sed 's/.*"\(.*\)".*/\1/')
        
        # Default category if not specified
        if [[ -z "$script_category" ]]; then
            script_category="UNCATEGORIZED"
        fi
        
        if [[ -n "$script_name" ]]; then
            AVAILABLE_TOOLS+=("$script_name")
            TOOL_SCRIPTS+=("$(basename "$script")")
            TOOL_DESCRIPTIONS+=("${script_description:-No description available}")
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
        else
            # Fallback to filename if no SCRIPT_NAME found
            local fallback_name=$(basename "$script" .sh)
            fallback_name=${fallback_name#install-}
            fallback_name=$(echo "$fallback_name" | sed 's/-/ /g' | sed 's/\b\w/\u&/g')
            
            AVAILABLE_TOOLS+=("$fallback_name")
            TOOL_SCRIPTS+=("$(basename "$script")")
            TOOL_DESCRIPTIONS+=("Generated from filename")
            TOOL_CATEGORIES+=("UNCATEGORIZED")
            
            # Track in UNCATEGORIZED
            local tool_index=$found
            if [[ -n "${TOOLS_BY_CATEGORY[UNCATEGORIZED]}" ]]; then
                TOOLS_BY_CATEGORY[UNCATEGORIZED]="${TOOLS_BY_CATEGORY[UNCATEGORIZED]},$tool_index"
            else
                TOOLS_BY_CATEGORY[UNCATEGORIZED]="$tool_index"
            fi
            
            CATEGORY_COUNTS[UNCATEGORIZED]=$((${CATEGORY_COUNTS[UNCATEGORIZED]:-0} + 1))
            
            ((found++))
        fi
    done
    
    if [[ $found -eq 0 ]]; then
        dialog --title "No Tools Found" --msgbox "No development tools found in $ADDITIONS_DIR" $DIALOG_HEIGHT $DIALOG_WIDTH
        clear
        return 1
    fi
    
    return 0
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
        --title "Development Tools - Select Category" \
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
            
            menu_options+=("$option_num" "$tool_name" "$tool_description")
            ((option_num++))
        done
        
        # Show tool selection menu with dynamic help
        local choice
        choice=$(dialog --clear \
            --item-help \
            --title "Development Tools - $category_name" \
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
    
    # Check if script exists
    if [[ ! -f "$script_path" ]]; then
        return 1
    fi
    
    # Extract CHECK_INSTALLED_COMMAND from the script
    local check_command=$(grep -m 1 '^CHECK_INSTALLED_COMMAND=' "$script_path" 2>/dev/null | sed 's/.*"\(.*\)".*/\1/')
    
    # If no CHECK_INSTALLED_COMMAND found, return false (not installed)
    if [[ -z "$check_command" ]]; then
        return 1
    fi
    
    # Execute the check command
    eval "$check_command" 2>/dev/null
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
    echo ""
    
    # Core tools - always installed
    echo "Core Tools:"
    command -v python3 >/dev/null && echo "  ✅ Python: $(python3 --version | cut -d' ' -f2)" || echo "  ❌ Python: not installed"
    command -v node >/dev/null && echo "  ✅ Node.js: $(node --version | sed 's/v//')" || echo "  ❌ Node.js: not installed"
    command -v npm >/dev/null && echo "  ✅ npm: $(npm --version)" || echo "  ❌ npm: not installed"
    command -v az >/dev/null && echo "  ✅ Azure CLI: $(az version 2>/dev/null | grep -o '\"azure-cli\": \"[^\"]*\"' | cut -d'"' -f4)" || echo "  ❌ Azure CLI: not installed"
    command -v pwsh >/dev/null && echo "  ✅ PowerShell: $(pwsh --version 2>/dev/null | cut -d' ' -f2)" || echo "  ❌ PowerShell: not installed"
    echo ""
    
    # Available development tools (both installed and not installed)
    if scan_available_tools >/dev/null 2>&1; then
        echo "Available Development Tools:"
        
        local installed_tools=()
        local not_installed_tools=()
        
        # Categorize tools
        for i in "${!AVAILABLE_TOOLS[@]}"; do
            local tool_name="${AVAILABLE_TOOLS[$i]}"
            local script_name="${TOOL_SCRIPTS[$i]}"
            
            if check_tool_installed "$script_name"; then
                installed_tools+=("  ✅ $tool_name")
            else
                not_installed_tools+=("  ❌ $tool_name")
            fi
        done
        
        # Display installed tools
        if [ ${#installed_tools[@]} -gt 0 ]; then
            echo ""
            echo "Installed (${#installed_tools[@]}):"
            for tool in "${installed_tools[@]}"; do
                echo "$tool"
            done
        fi
        
        # Display not installed tools
        if [ ${#not_installed_tools[@]} -gt 0 ]; then
            echo ""
            echo "Not Installed (${#not_installed_tools[@]}):"
            for tool in "${not_installed_tools[@]}"; do
                echo "$tool"
            done
        fi
    fi
    
    echo ""
    echo "═══════════════════════════════════════════════════════════════════"
    echo ""
    read -p "Press Enter to return to menu..." -r
    clear
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
            "1" "Install Development Tools" \
            "2" "Create project from template" \
            "3" "Show Environment Info" \
            "4" "Exit" \
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
                create_project_from_template
                ;;
            3)
                show_environment_info
                ;;
            4)
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
