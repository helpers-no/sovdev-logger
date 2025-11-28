#!/bin/bash
# file: .devcontainer/additions/install-tool-dataanalytics.sh
#
# Installs Python data analysis libraries, Jupyter notebooks, and related VS Code extensions.
# For usage information, run: ./install-tool-dataanalytics.sh --help
#
#------------------------------------------------------------------------------
# CONFIGURATION - Modify this section for each new script
#------------------------------------------------------------------------------

# Script metadata - must be at the very top of the configuration section
SCRIPT_NAME="Data & Analytics Tools"
SCRIPT_ID="tool-dataanalytics"
SCRIPT_DESCRIPTION="Installs Python data analysis libraries, Jupyter notebooks, and related VS Code extensions"
SCRIPT_CATEGORY="DATA_ANALYTICS"
CHECK_INSTALLED_COMMAND="[ -f /usr/local/bin/jupyter ] || [ -f $HOME/.local/bin/jupyter ] || command -v jupyter >/dev/null 2>&1"

# Optional: Custom usage text for --help
SCRIPT_USAGE="  $(basename "$0")              # Install data analytics tools
  $(basename "$0") --help       # Show this help
  $(basename "$0") --uninstall  # Uninstall analytics tools
  $(basename "$0") --debug      # Install with debug output"

#------------------------------------------------------------------------------

# Source auto-enable library
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/tool-auto-enable.sh"

# Source logging library
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/logging.sh"

#------------------------------------------------------------------------------

# Before running installation, we need to add any required repositories or setup
pre_installation_setup() {
    if [ "${UNINSTALL_MODE}" -eq 1 ]; then
        echo "=' Preparing for uninstallation..."
    else
        echo "=' Performing pre-installation setup..."

        # Verify Python is installed (prerequisite check)
        if ! command -v python >/dev/null 2>&1; then
            echo "L Error: Python not found. It should have been installed in the Dockerfile."
            echo "Please verify the container was built correctly."
            exit 1
        fi

        # Verify pip is installed (prerequisite check)
        if ! command -v pip >/dev/null 2>&1; then
            echo "   Warning: pip not found. Installing pip..."
            python -m ensurepip --default-pip
        fi

        # Note: Version verification handled by verify_installations() using VERIFY_COMMANDS
        echo " Pre-installation setup complete"
    fi
}

# Define Python packages
PACKAGES_PYTHON=(
    "pandas"
    "numpy"
    "matplotlib"
    "seaborn"
    "scikit-learn"
    "jupyter"
    "jupyterlab"
    "notebook"
    "dbt-core"
    "dbt-postgres"
)

# Define VS Code extensions
declare -A EXTENSIONS
EXTENSIONS["ms-python.python"]="Python|Python language support"
EXTENSIONS["ms-toolsai.jupyter"]="Jupyter|Jupyter notebook support"
EXTENSIONS["ms-python.vscode-pylance"]="Pylance|Python language server"
EXTENSIONS["bastienboutonnet.vscode-dbt"]="DBT|DBT language support"
EXTENSIONS["innoverio.vscode-dbt-power-user"]="DBT Power User|Enhanced DBT support"
EXTENSIONS["databricks.databricks"]="Databricks|Databricks integration"

# Define verification commands
VERIFY_COMMANDS=(
    "python --version || echo 'L Python not found'"
    "pip --version || echo 'L pip not found'"
    "python -c 'import pandas' 2>/dev/null && echo ' pandas is installed' || echo 'L pandas not found'"
    "python -c 'import numpy' 2>/dev/null && echo ' numpy is installed' || echo 'L numpy not found'"
    "python -c 'import matplotlib' 2>/dev/null && echo ' matplotlib is installed' || echo 'L matplotlib not found'"
    "python -c 'import seaborn' 2>/dev/null && echo ' seaborn is installed' || echo 'L seaborn not found'"
    "python -c 'import sklearn' 2>/dev/null && echo ' scikit-learn is installed' || echo 'L scikit-learn not found'"
    "jupyter --version >/dev/null 2>&1 && echo ' jupyter is installed' || echo 'L jupyter not found'"
    "dbt --version >/dev/null 2>&1 && echo ' dbt is installed' || echo 'L dbt not found'"
)

# Post-installation notes
post_installation_message() {
    # Note: Installation and verification already completed via verify_installations()
    local python_version=$(python --version 2>&1 || echo "unknown")
    local jupyter_version=$(jupyter --version 2>/dev/null | head -n1 || echo "unknown")
    local dbt_version=$(dbt --version 2>/dev/null | head -n1 || echo "unknown")

    echo
    echo "<‰ Installation process complete for: $SCRIPT_NAME!"
    echo "Purpose: $SCRIPT_DESCRIPTION"
    echo
    echo "Important Notes:"
    echo "1. Python: $python_version"
    echo "2. Jupyter: $jupyter_version"
    echo "3. DBT: $dbt_version"
    echo "4. All data science packages are installed in the Python environment"
    echo "5. Jupyter notebooks can be created and run directly in VS Code"
    echo
    echo "Quick Start Commands:"
    echo "- Start Jupyter Lab: jupyter lab"
    echo "- Start Jupyter Notebook: jupyter notebook"
    echo "- Initialize DBT project: dbt init [project_name]"
    echo "- Python data analysis example:"
    echo "    import pandas as pd"
    echo "    import matplotlib.pyplot as plt"
    echo "    import seaborn as sns"
    echo
    echo "Documentation Links:"
    echo "- Local Guide: .devcontainer/howto/howto-data-analytics.md"
    echo "- pandas: https://pandas.pydata.org/docs/"
    echo "- scikit-learn: https://scikit-learn.org/stable/"
    echo "- Jupyter: https://jupyter.org/documentation"
    echo "- DBT: https://docs.getdbt.com/"
}

# Post-uninstallation notes
post_uninstallation_message() {

    # Remove from auto-enable config
    auto_disable_tool
    echo
    echo "<Á Uninstallation process complete for: $SCRIPT_NAME!"
    echo
    echo "Additional Notes:"
    echo "1. Python remains installed as it's part of the base container"
    echo "2. Some configuration files may remain in ~/.jupyter/"
    echo "3. DBT project files and configurations remain unchanged"

}

#------------------------------------------------------------------------------
# STANDARD SCRIPT LOGIC - Do not modify anything below this line
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

# Export mode flags for core scripts
export DEBUG_MODE
export UNINSTALL_MODE
export FORCE_MODE

# Source all core installation scripts
source "${SCRIPT_DIR}/lib/core-install-system.sh"
source "${SCRIPT_DIR}/lib/core-install-node.sh"
source "${SCRIPT_DIR}/lib/core-install-extensions.sh"
source "${SCRIPT_DIR}/lib/core-install-pwsh.sh"
source "${SCRIPT_DIR}/lib/core-install-python.sh"

# Source common installation patterns library
source "${SCRIPT_DIR}/lib/install-common.sh"

# Function to process installations
process_installations() {
    # Use standard processing from lib/install-common.sh
    process_standard_installations
}

# Function to verify installations
# Note: Using common implementation from lib/install-common.sh (sourced above)
# No local definition needed - library function is used directly

# Main execution
if [ "${UNINSTALL_MODE}" -eq 1 ]; then
    echo "= Starting uninstallation process for: $SCRIPT_NAME"
    echo "Purpose: $SCRIPT_DESCRIPTION"
    pre_installation_setup
    process_installations
    if [ ${#EXTENSIONS[@]} -gt 0 ]; then
        for ext_id in "${!EXTENSIONS[@]}"; do
            IFS='|' read -r name description _ <<< "${EXTENSIONS[$ext_id]}"
            check_extension_state "$ext_id" "uninstall" "$name"
        done
    fi
    post_uninstallation_message

    # Remove from auto-enable config
    auto_disable_tool
else
    echo "= Starting installation process for: $SCRIPT_NAME"
    echo "Purpose: $SCRIPT_DESCRIPTION"
    pre_installation_setup
    process_installations
    verify_installations
    if [ ${#EXTENSIONS[@]} -gt 0 ]; then
        for ext_id in "${!EXTENSIONS[@]}"; do
            IFS='|' read -r name description _ <<< "${EXTENSIONS[$ext_id]}"
            check_extension_state "$ext_id" "install" "$name"
        done
    fi
    post_installation_message

    # Auto-enable for container rebuild
    auto_enable_tool
fi
