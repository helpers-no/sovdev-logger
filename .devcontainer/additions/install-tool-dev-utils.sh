#!/bin/bash
# file: .devcontainer/additions/install-tool-dev-utils.sh
#
# Installs general development utilities useful across multiple programming languages.
# These tools are language-agnostic and can be used with PHP, Python, Node.js, Java, C#, etc.
# For usage information, run: ./install-tool-dev-utils.sh --help
#
#------------------------------------------------------------------------------
# CONFIGURATION - Modify this section for each new script
#------------------------------------------------------------------------------

# --- Script Metadata ---
SCRIPT_ID="tool-dev-utils"
SCRIPT_NAME="Development Utilities"
SCRIPT_DESCRIPTION="Database management (SQLTools) and API testing (REST Client) for multi-language development"
SCRIPT_CATEGORY="INFRA_CONFIG"

# NOTE: We check only the primary extension (SQLTools) instead of all extensions
# to avoid tight coupling between CHECK_INSTALLED_COMMAND and the EXTENSIONS array.
# This makes the script more maintainable - if someone adds/removes extensions,
# they don't need to update this check. The extension installer is idempotent anyway.
CHECK_INSTALLED_COMMAND="code --list-extensions 2>/dev/null | grep -q 'mtxr.sqltools'"

# Custom usage text for --help
SCRIPT_USAGE="  $(basename "$0")              # Install development utilities
  $(basename "$0") --help       # Show this help
  $(basename "$0") --uninstall  # Uninstall utilities
  $(basename "$0") --debug      # Install with debug output"

# System packages (all packages already in base devcontainer - see Dockerfile.base)
PACKAGES_SYSTEM=()

# VS Code extensions
EXTENSIONS=(
    "SQLTools (mtxr.sqltools) - Database management and SQL query tool for MySQL, PostgreSQL, SQLite, MSSQL, MongoDB, etc."
    "REST Client (humao.rest-client) - Send HTTP requests and view responses directly in VS Code (alternative to Postman/Insomnia)"
)

#------------------------------------------------------------------------------

# Source auto-enable library
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/tool-auto-enable.sh"

# Source logging library
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/logging.sh"

#------------------------------------------------------------------------------

# --- Pre-installation/Uninstallation Setup ---
pre_installation_setup() {
    if [ "${UNINSTALL_MODE}" -eq 1 ]; then
        echo "🔧 Preparing for uninstallation..."
    else
        echo "🔧 Performing pre-installation setup..."
        echo "✅ Pre-installation setup complete"
    fi
}

# --- Post-installation/Uninstallation Messages ---
post_installation_message() {
    echo
    echo "🎉 Installation complete!"
    echo
    echo "Installed Tools:"
    echo "  • SQLTools - Database management for multiple database types"
    echo "  • REST Client - API testing directly in VS Code"
    echo
    echo "SQLTools Features:"
    echo "  - Connects to: MySQL, PostgreSQL, SQLite, MSSQL, MongoDB, and more"
    echo "  - Query databases visually"
    echo "  - Browse tables and schemas"
    echo "  - Export query results"
    echo "  - Bookmark frequent queries"
    echo
    echo "REST Client Features:"
    echo "  - Test APIs without leaving VS Code"
    echo "  - Free, open-source alternative to Postman"
    echo "  - No account/signup required"
    echo "  - Save requests in .http or .rest files"
    echo "  - Environment variables support"
    echo
    echo "Quick start:"
    echo "  SQLTools: Click the database icon in VS Code sidebar"
    echo "  REST Client: Create a file with .http extension and write HTTP requests"
    echo
    echo "Example .http file:"
    echo "  GET https://api.github.com/users/octocat"
    echo "  ###"
    echo "  POST https://api.example.com/users"
    echo "  Content-Type: application/json"
    echo ""
    echo "  {"
    echo '    "name": "John Doe"'
    echo "  }"
    echo
    echo "Docs:"
    echo "  - SQLTools: https://marketplace.visualstudio.com/items?itemName=mtxr.sqltools"
    echo "  - REST Client: https://marketplace.visualstudio.com/items?itemName=humao.rest-client"
    echo
}

post_uninstallation_message() {
    echo
    echo "🏁 Uninstallation complete!"
    echo "   ✅ SQLTools extension removed"
    echo "   ✅ REST Client extension removed"
    echo
}

#------------------------------------------------------------------------------
# ARGUMENT PARSING
#------------------------------------------------------------------------------

# Initialize mode flags
DEBUG_MODE=0
UNINSTALL_MODE=0
FORCE_MODE=0

# Source common installation patterns library (needed for --help)
source "${SCRIPT_DIR}/lib/install-common.sh"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --help)
            show_script_help
            exit 0
            ;;
        --debug)
            DEBUG_MODE=1
            shift
            ;;
        --uninstall)
            UNINSTALL_MODE=1
            shift
            ;;
        --force)
            FORCE_MODE=1
            shift
            ;;
        *)
            echo "ERROR: Unknown option: $1" >&2
            echo "Usage: $0 [--help] [--debug] [--uninstall] [--force]" >&2
            echo "Description: $SCRIPT_DESCRIPTION"
            exit 1
            ;;
    esac
done

# Export mode flags
export DEBUG_MODE
export UNINSTALL_MODE
export FORCE_MODE

#------------------------------------------------------------------------------
# SOURCE CORE SCRIPTS
#------------------------------------------------------------------------------

# Source core installation scripts
source "${SCRIPT_DIR}/lib/core-install-extensions.sh"

#------------------------------------------------------------------------------
# HELPER FUNCTIONS
#------------------------------------------------------------------------------

# Function to process installations
process_installations() {
    # Use standard processing from lib/install-common.sh
    process_standard_installations
}

#------------------------------------------------------------------------------
# MAIN EXECUTION
#------------------------------------------------------------------------------

if [ "${UNINSTALL_MODE}" -eq 1 ]; then
    echo "🔄 Starting uninstallation process for: $SCRIPT_NAME"
    echo "Purpose: $SCRIPT_DESCRIPTION"
    pre_installation_setup
    process_installations
    post_uninstallation_message
else
    echo "🔄 Starting installation process for: $SCRIPT_NAME"
    echo "Purpose: $SCRIPT_DESCRIPTION"
    pre_installation_setup
    process_installations
    post_installation_message

    # Auto-enable for container rebuild
    auto_enable_tool "$SCRIPT_ID" "$SCRIPT_NAME"
fi

echo "✅ Script execution finished."
exit 0
