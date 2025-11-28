#!/bin/bash
# file: .devcontainer/additions/install-tool-kubernetes.sh
#
# Installs kubectl, k9s, helm and sets up .devcontainer.secrets folder for kubeconfig.
# For usage information, run: ./install-tool-kubernetes.sh --help
#
#------------------------------------------------------------------------------
# CONFIGURATION - Modify this section for each new script
#------------------------------------------------------------------------------

# Script metadata - must be at the very top of the configuration section
SCRIPT_NAME="Kubernetes Development Tools"
SCRIPT_ID="tool-kubernetes"
SCRIPT_DESCRIPTION="Installs kubectl, k9s, helm and sets up .devcontainer.secrets folder for kubeconfig"
SCRIPT_CATEGORY="INFRA_CONFIG"
CHECK_INSTALLED_COMMAND="command -v kubectl >/dev/null 2>&1 || command -v k9s >/dev/null 2>&1 || command -v helm >/dev/null 2>&1"

# Optional: Custom usage text for --help
SCRIPT_USAGE="  $(basename "$0")              # Install Kubernetes development tools
  $(basename "$0") --help       # Show this help
  $(basename "$0") --uninstall  # Uninstall Kubernetes tools
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

# Custom kubectl installation function
install_kubectl() {
    if [ "${UNINSTALL_MODE}" -eq 1 ]; then
        echo "=Ñ  Removing kubectl..."
        sudo rm -f /usr/local/bin/kubectl
        echo " kubectl removed"
        return
    fi

    # Check if kubectl is already installed
    if command -v kubectl >/dev/null 2>&1; then
        local current_version=$(kubectl version --client --short 2>/dev/null | cut -d' ' -f3 || kubectl version --client -o json 2>/dev/null | grep -o '"gitVersion": "[^"]*"' | cut -d'"' -f4)
        echo " kubectl is already installed (version: ${current_version})"
        return
    fi

    echo "=æ Installing kubectl..."

    # Download latest stable kubectl
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

    # Install kubectl
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    rm kubectl

    # Verify installation
    if command -v kubectl >/dev/null 2>&1; then
        local version=$(kubectl version --client --short 2>/dev/null | cut -d' ' -f3 || kubectl version --client -o json 2>/dev/null | grep -o '"gitVersion": "[^"]*"' | cut -d'"' -f4)
        echo " kubectl installed successfully (version: ${version})"
    else
        echo "L kubectl installation failed"
        return 1
    fi
}

# Custom k9s installation function
install_k9s() {
    if [ "${UNINSTALL_MODE}" -eq 1 ]; then
        echo "=Ñ  Removing k9s..."
        sudo rm -f /usr/local/bin/k9s
        echo " k9s removed"
        return
    fi

    # Check if k9s is already installed
    if command -v k9s >/dev/null 2>&1; then
        local current_version=$(k9s version -s 2>/dev/null | grep Version | awk '{print $2}')
        echo " k9s is already installed (version: ${current_version})"
        return
    fi

    echo "=æ Installing k9s..."

    # Get latest k9s release
    local k9s_version=$(curl -s https://api.github.com/repos/derailed/k9s/releases/latest | grep -o '"tag_name": "[^"]*"' | cut -d'"' -f4)

    # Download and install k9s
    curl -sL "https://github.com/derailed/k9s/releases/download/${k9s_version}/k9s_Linux_amd64.tar.gz" | sudo tar xz -C /usr/local/bin k9s

    # Verify installation
    if command -v k9s >/dev/null 2>&1; then
        local version=$(k9s version -s 2>/dev/null | grep Version | awk '{print $2}')
        echo " k9s installed successfully (version: ${version})"
    else
        echo "L k9s installation failed"
        return 1
    fi
}

# Custom helm installation function
install_helm() {
    if [ "${UNINSTALL_MODE}" -eq 1 ]; then
        echo "=Ñ  Removing helm..."
        sudo rm -f /usr/local/bin/helm
        echo " helm removed"
        return
    fi

    # Check if helm is already installed
    if command -v helm >/dev/null 2>&1; then
        local current_version=$(helm version --short 2>/dev/null | cut -d'+' -f1)
        echo " helm is already installed (version: ${current_version})"
        return
    fi

    echo "=æ Installing helm..."

    # Download and install helm
    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

    # Verify installation
    if command -v helm >/dev/null 2>&1; then
        local version=$(helm version --short 2>/dev/null | cut -d'+' -f1)
        echo " helm installed successfully (version: ${version})"
    else
        echo "L helm installation failed"
        return 1
    fi
}

# Setup kubeconfig directory
setup_kubeconfig() {
    if [ "${UNINSTALL_MODE}" -eq 1 ]; then
        return
    fi

    echo "=Á Setting up kubeconfig directory..."

    # Create .devcontainer.secrets/.kube directory
    mkdir -p /workspace/.devcontainer.secrets/.kube

    # Create symlink from ~/.kube to .devcontainer.secrets/.kube
    if [ ! -L "$HOME/.kube" ]; then
        ln -sf /workspace/.devcontainer.secrets/.kube "$HOME/.kube"
        echo " Kubeconfig directory linked to .devcontainer.secrets/.kube"
    else
        echo " Kubeconfig symlink already exists"
    fi
}

# Before running installation, we need to add any required repositories or setup
pre_installation_setup() {
    if [ "${UNINSTALL_MODE}" -eq 1 ]; then
        echo "=' Preparing for uninstallation..."
    else
        echo "=' Performing pre-installation setup..."

        # Check if tools are already installed
        if command -v kubectl >/dev/null 2>&1; then
            echo " kubectl is already installed"
        fi
        if command -v k9s >/dev/null 2>&1; then
            echo " k9s is already installed"
        fi
        if command -v helm >/dev/null 2>&1; then
            echo " helm is already installed"
        fi

        # Update package lists
        sudo apt-get update -qq
    fi
}

# Define package arrays (remove any empty arrays that aren't needed)
PACKAGES_SYSTEM=(
    "curl"
    "ca-certificates"
)

PACKAGES_NODE=()

PACKAGES_PYTHON=()

# Define VS Code extensions (format: "Name (extension-id) - Description")
EXTENSIONS=(
    "Kubernetes (ms-kubernetes-tools.vscode-kubernetes-tools) - Develop, deploy and debug Kubernetes applications"
    "YAML (redhat.vscode-yaml) - YAML language support with Kubernetes schema"
)

# Define verification commands
VERIFY_COMMANDS=(
    "command -v kubectl >/dev/null && kubectl version --client || echo 'L kubectl not found'"
    "command -v k9s >/dev/null && k9s version -s || echo 'L k9s not found'"
    "command -v helm >/dev/null && helm version --short || echo 'L helm not found'"
    "test -f /workspace/.devcontainer.secrets/.kube/config && echo ' kubeconfig found' || echo '   kubeconfig not found'"
)

# Post-installation notes
post_installation_message() {

    echo
    echo "<‰ Installation process complete for: $SCRIPT_NAME!"
    echo "Purpose: $SCRIPT_DESCRIPTION"
    echo
    echo "Important Notes:"
    echo "1. kubectl, k9s, and helm have been installed"
    echo "2. Kubeconfig directory is linked to .devcontainer.secrets/.kube"
    echo "3. Place your kubeconfig file in /workspace/.devcontainer.secrets/.kube/config"
    echo "4. VS Code Kubernetes extension provides cluster management and YAML support"
    echo
    echo "Quick Start:"
    echo "- Check kubectl: kubectl version --client"
    echo "- Check k9s: k9s version"
    echo "- Check helm: helm version"
    echo "- View clusters: kubectl config get-contexts"
    echo "- Launch k9s: k9s"
    echo
    echo "Documentation Links:"
    echo "- kubectl Documentation: https://kubernetes.io/docs/reference/kubectl/"
    echo "- k9s Documentation: https://k9scli.io/"
    echo "- Helm Documentation: https://helm.sh/docs/"
    echo "- VS Code Kubernetes: https://marketplace.visualstudio.com/items?itemName=ms-kubernetes-tools.vscode-kubernetes-tools"
}

# Post-uninstallation notes
post_uninstallation_message() {

    # Remove from auto-enable config
    auto_disable_tool
    echo
    echo "<Á Uninstallation process complete for: $SCRIPT_NAME!"
    echo
    echo "Additional Notes:"
    echo "1. kubectl, k9s, and helm have been removed"
    echo "2. Kubeconfig directory in .devcontainer.secrets/ remains"
    echo "3. You can manually remove it with: rm -rf /workspace/.devcontainer.secrets/.kube"
}

#------------------------------------------------------------------------------
# MAIN SCRIPT EXECUTION - Do not modify below this line
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

# Note: lib/install-common.sh already sourced earlier (needed for --help)

# Function to process installations
process_installations() {
    # Custom Kubernetes tools installation
    install_kubectl
    install_k9s
    install_helm
    setup_kubeconfig

    # Then use standard processing from lib/install-common.sh
    process_standard_installations
}



# Main execution
if [ "${UNINSTALL_MODE}" -eq 1 ]; then
    echo "= Starting uninstallation process for: $SCRIPT_NAME"
    echo "Purpose: $SCRIPT_DESCRIPTION"
    pre_installation_setup
    process_installations
    post_uninstallation_message

    # Remove from auto-enable config
    auto_disable_tool
else
    echo "= Starting installation process for: $SCRIPT_NAME"
    echo "Purpose: $SCRIPT_DESCRIPTION"
    pre_installation_setup
    process_installations
    verify_installations
    post_installation_message

    # Auto-enable for container rebuild
    auto_enable_tool
fi
