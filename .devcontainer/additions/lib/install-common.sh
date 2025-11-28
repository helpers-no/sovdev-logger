#!/bin/bash
# ============================================================================
# File: lib/install-common.sh
# Description: Common installation patterns shared across install-*.sh scripts
# Version: 1.0.0
# Date: 2025-11-28
# ============================================================================
#
# This library provides common functions used by install-*.sh scripts to
# reduce code duplication and ensure consistent behavior.
#
# Usage:
#   source "${SCRIPT_DIR}/lib/install-common.sh"
#
# Functions provided:
#   - verify_installations()             Verify installed tools/packages
#   - process_standard_installations()   Process standard package arrays
#
# Dependencies:
#   - core-install-*.sh (for package processing functions)
#   - VERIFY_COMMANDS array (defined in calling script)
#   - Package arrays: SYSTEM_PACKAGES, NODE_PACKAGES, etc.
#
# ============================================================================

# Ensure this script is sourced, not executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "❌ Error: This script must be sourced, not executed directly"
    echo "Usage: source \"\${SCRIPT_DIR}/lib/install-common.sh\""
    exit 1
fi

# ============================================================================
# Function: verify_installations
# Description: Execute verification commands for installed tools/packages
#
# Usage:
#   verify_installations                 # Silent mode (default)
#   verify_installations "true"          # Verbose mode (show commands)
#
# Parameters:
#   $1 (optional): Verbosity flag ("true"/"false", default: "false")
#
# Dependencies:
#   VERIFY_COMMANDS array must be defined in calling script
#
# Examples:
#   VERIFY_COMMANDS+=("command -v docker")
#   VERIFY_COMMANDS+=("docker --version")
#   verify_installations
# ============================================================================
verify_installations() {
    local verbose="${1:-false}"  # Optional: "true" to show commands, default "false"

    if [ ${#VERIFY_COMMANDS[@]} -gt 0 ]; then
        echo
        echo "🔍 Verifying installations..."

        for cmd in "${VERIFY_COMMANDS[@]}"; do
            if [ "$verbose" = "true" ]; then
                echo "  Running: $cmd"
            fi

            if ! eval "$cmd" 2>/dev/null; then
                echo "  ❌ Verification failed for: $cmd"
            fi
        done
    fi
}

# ============================================================================
# Function: process_standard_installations
# Description: Process standard package arrays (SYSTEM, NODE, PYTHON, PWSH, EXTENSIONS)
#
# Usage:
#   process_standard_installations
#
# Parameters: None
#
# Dependencies:
#   - Package arrays (optional, only processed if not empty):
#     * SYSTEM_PACKAGES - APT packages
#     * NODE_PACKAGES - NPM global packages
#     * PYTHON_PACKAGES - Python packages (pip/pipx)
#     * PWSH_MODULES - PowerShell modules
#     * EXTENSIONS - VS Code extensions
#   - Processing functions from core-install-*.sh:
#     * process_system_packages()
#     * process_node_packages()
#     * process_python_packages()
#     * process_pwsh_modules()
#     * process_extensions()
#
# Examples:
#   # Simple script - just call the function
#   process_installations() {
#       process_standard_installations
#   }
#
#   # Complex script - custom logic then standard processing
#   process_installations() {
#       install_custom_tool
#       setup_custom_config
#       process_standard_installations
#   }
# ============================================================================
process_standard_installations() {
    # Process each package type if array is not empty

    if [ ${#SYSTEM_PACKAGES[@]} -gt 0 ]; then
        process_system_packages "SYSTEM_PACKAGES"
    fi

    if [ ${#NODE_PACKAGES[@]} -gt 0 ]; then
        process_node_packages "NODE_PACKAGES"
    fi

    if [ ${#PYTHON_PACKAGES[@]} -gt 0 ]; then
        process_python_packages "PYTHON_PACKAGES"
    fi

    if [ ${#PWSH_MODULES[@]} -gt 0 ]; then
        process_pwsh_modules "PWSH_MODULES"
    fi

    if [ ${#EXTENSIONS[@]} -gt 0 ]; then
        process_extensions "EXTENSIONS"
    fi
}

# ============================================================================
# End of lib/install-common.sh
# ============================================================================
