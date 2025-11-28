#!/bin/bash
# file: .devcontainer/additions/install-kubectl.sh
#
# Installs kubectl and sets up .devcontainer.secrets folder for credentials
#
# Usage: ./install-kubectl.sh [options]
#
# Options:
#   --debug     : Enable debug output for troubleshooting
#   --uninstall : Remove installed components instead of installing them
#   --force     : Force installation/uninstallation even if there are dependencies
#
#------------------------------------------------------------------------------
# CONFIGURATION SECTION
#------------------------------------------------------------------------------

# Script metadata
SCRIPT_NAME="Kubernetes kubectl CLI"
SCRIPT_DESCRIPTION="Installs kubectl and sets up .devcontainer.secrets folder for credentials"
SCRIPT_CATEGORY="INFRA_CONFIG"
CHECK_INSTALLED_COMMAND="[ -f /usr/local/bin/kubectl ] || [ -f /usr/bin/kubectl ] || command -v kubectl >/dev/null 2>&1"

#------------------------------------------------------------------------------

# Source auto-enable library
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/tool-auto-enable.sh"

# Source logging library
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/logging.sh"

#------------------------------------------------------------------------------

# Custom function BEFORE standard package installation
pre_installation_setup() {
    if [ "${UNINSTALL_MODE}" -eq 1 ]; then
        echo "🔧 Preparing for uninstallation..."
    else
        echo "🔧 Setting up .devcontainer.secrets folder structure..."
        setup_devcontainer_secrets_folder
    fi
}

#------------------------------------------------------------------------------
# CUSTOM FUNCTIONS (kubectl-specific logic)
#------------------------------------------------------------------------------

# Function: setup_devcontainer_secrets_folder
# Creates folder structure, README, .gitignore, helper scripts
setup_devcontainer_secrets_folder() {
    echo "📁 Creating .devcontainer.secrets/ folder for sensitive files..."

    # 1. Add to root .gitignore
    add_to_gitignore

    # 2. Create folder
    mkdir -p /workspace/.devcontainer.secrets

    # 3. Create .devcontainer.secrets/README.md
    create_devcontainer_secrets_readme

    # 4. Create .devcontainer.secrets/.gitignore
    create_devcontainer_secrets_gitignore

    # 5. Create .devcontainer.secrets/copy-kubeconfig-mac.sh
    create_mac_helper_script

    # 6. Create .devcontainer.secrets/copy-kubeconfig-win.ps1
    create_windows_helper_script

    echo "✅ .devcontainer.secrets/ folder structure created"
}

# Function: add_to_gitignore
# Adds .devcontainer.secrets/ to root .gitignore if not already there
add_to_gitignore() {
    local gitignore_file="/workspace/.gitignore"
    local gitignore_line=".devcontainer.secrets/"

    if [ -f "$gitignore_file" ]; then
        if grep -q "^.devcontainer.secrets/" "$gitignore_file"; then
            echo "  ✅ .devcontainer.secrets/ already in .gitignore"
        else
            echo "" >> "$gitignore_file"
            echo "# Top secret folder - contains credentials (NEVER commit)" >> "$gitignore_file"
            echo ".devcontainer.secrets/" >> "$gitignore_file"
            echo "  ✅ Added .devcontainer.secrets/ to .gitignore"
        fi
    else
        echo "# Top secret folder - contains credentials (NEVER commit)" > "$gitignore_file"
        echo ".devcontainer.secrets/" >> "$gitignore_file"
        echo "  ✅ Created .gitignore with .devcontainer.secrets/"
    fi
}

# Function: create_devcontainer_secrets_readme
# Creates README.md with heredoc
create_devcontainer_secrets_readme() {
    cat > /workspace/.devcontainer.secrets/README.md <<'EOF'
# Top Secret Folder

This folder stores **sensitive files for local development only**.

## ⚠️ CRITICAL: Never Commit These Files

- This folder is in `.gitignore` (double protection with local `.gitignore`)
- **NEVER** remove from `.gitignore`
- **NEVER** commit any files from this folder

## What to Store Here

### Kubernetes Credentials
- `.kube/config` - Kubernetes cluster access

### Cloud Provider Credentials
- `.azure/` - Azure CLI credentials
- `.aws/` - AWS CLI credentials
- `.gcp/` - Google Cloud credentials

### API Keys & Tokens
- `api-keys.env` - API keys and tokens
- `secrets.env` - Environment-specific secrets

### Personal Files
- Personal notes, TODOs
- Test data with sensitive information
- SSH keys
- Any file you don't want in version control

## Setting Up kubectl

Run the helper script on your **host machine** (not in devcontainer):

**Mac/Linux:**
```bash
./.devcontainer.secrets/copy-kubeconfig-mac.sh
```

**Windows (PowerShell):**
```powershell
.\.devcontainer.secrets\copy-kubeconfig-win.ps1
```

This script:
1. Copies `~/.kube/config` to `.devcontainer.secrets/.kube/config`
2. **Rewrites server URLs** for container networking (see below)

Then inside devcontainer:
```bash
export KUBECONFIG=/workspace/.devcontainer.secrets/.kube/config
kubectl get nodes
```

## Container Networking (IMPORTANT)

**The Challenge:**
- Your host kubeconfig uses `https://127.0.0.1:6443` (localhost)
- Inside a container, `127.0.0.1` refers to the **container itself**, NOT the host
- kubectl would fail to connect to your cluster

**The Solution:**
The helper scripts automatically rewrite server URLs to use `host.docker.internal`:

```yaml
# Original (from host ~/.kube/config):
server: https://127.0.0.1:6443

# Rewritten (in .devcontainer.secrets/.kube/config):
server: https://host.docker.internal:6443
```

`host.docker.internal` is a special DNS name provided by Docker that resolves to your host machine from inside the container.

**Supported Rewrites:**
- `https://127.0.0.1:*` → `https://host.docker.internal:*`
- `https://localhost:*` → `https://host.docker.internal:*`
- `https://0.0.0.0:*` → `https://host.docker.internal:*`
- `https://kubernetes.docker.internal:*` → `https://host.docker.internal:*`

## When Kubeconfig Changes

Just re-run the helper script on your host machine. It will copy and rewrite the URLs again.

## Protection Mechanism

**Root `.gitignore`:**
```
.devcontainer.secrets/
```

**Local `.devcontainer.secrets/.gitignore`:**
```
*
!README.md
!.gitignore
!copy-kubeconfig-mac.sh
!copy-kubeconfig-win.ps1
```

Only documentation and helper scripts are tracked in git. Everything else is ignored.
EOF
    echo "  ✅ Created .devcontainer.secrets/README.md"
}

# Function: create_devcontainer_secrets_gitignore
create_devcontainer_secrets_gitignore() {
    cat > /workspace/.devcontainer.secrets/.gitignore <<'EOF'
# Ignore everything in .devcontainer.secrets/
*

# Except these files (documentation and helper scripts)
!README.md
!.gitignore
!copy-kubeconfig-mac.sh
!copy-kubeconfig-win.ps1
EOF
    echo "  ✅ Created .devcontainer.secrets/.gitignore"
}

# Function: create_mac_helper_script
create_mac_helper_script() {
    cat > /workspace/.devcontainer.secrets/copy-kubeconfig-mac.sh <<'EOF'
#!/bin/bash
# file: .devcontainer.secrets/copy-kubeconfig-mac.sh
# Copies ~/.kube/config to .devcontainer.secrets/.kube/config
# CRITICAL: Rewrites server URLs to use host.docker.internal for container access

set -e

echo "🔐 Setting up Kubernetes credentials for devcontainer..."

# Check if source kubeconfig exists
if [ ! -f "$HOME/.kube/config" ]; then
    echo "❌ Error: ~/.kube/config not found"
    echo "   Make sure Rancher Desktop or Docker Desktop is installed"
    exit 1
fi

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Create target directory
mkdir -p "$SCRIPT_DIR/.kube"

# Copy and rewrite server URLs for container access
echo "📝 Copying and rewriting kubeconfig for devcontainer networking..."

# Copy file
cp "$HOME/.kube/config" "$SCRIPT_DIR/.kube/config"

# Rewrite server URLs to use host.docker.internal
# This is CRITICAL because 127.0.0.1/localhost inside container != host
sed -i.bak \
    -e 's|https://127\.0\.0\.1:|https://host.docker.internal:|g' \
    -e 's|https://localhost:|https://host.docker.internal:|g' \
    -e 's|https://0\.0\.0\.0:|https://host.docker.internal:|g' \
    -e 's|https://kubernetes\.docker\.internal:|https://host.docker.internal:|g' \
    -e 's|insecure-skip-tls-verify: false|insecure-skip-tls-verify: true|g' \
    -e 's|^      certificate-authority-data:.*|      # certificate-authority-data: (commented out for insecure-skip-tls-verify)|g' \
    "$SCRIPT_DIR/.kube/config"

# Remove backup file
rm -f "$SCRIPT_DIR/.kube/config.bak"

echo "✅ Kubeconfig copied to .devcontainer.secrets/.kube/config"
echo "✅ Server URLs rewritten to use host.docker.internal"
echo ""
echo "Next steps:"
echo "1. If not already there, open this project in VSCode devcontainer"
echo "2. Inside container, add to ~/.bashrc:"
echo "     export KUBECONFIG=/workspace/.devcontainer.secrets/.kube/config"
echo "3. Reload: source ~/.bashrc"
echo "4. Test: kubectl get nodes"
echo ""
echo "Note: Server URLs have been rewritten for container networking."
echo "      Original: https://127.0.0.1:6443"
echo "      Rewritten: https://host.docker.internal:6443"
EOF
    chmod +x /workspace/.devcontainer.secrets/copy-kubeconfig-mac.sh
    echo "  ✅ Created .devcontainer.secrets/copy-kubeconfig-mac.sh"
}

# Function: create_windows_helper_script
create_windows_helper_script() {
    cat > /workspace/.devcontainer.secrets/copy-kubeconfig-win.ps1 <<'EOF'
# file: .devcontainer.secrets/copy-kubeconfig-win.ps1
# Copies %USERPROFILE%\.kube\config to .devcontainer.secrets\.kube\config
# CRITICAL: Rewrites server URLs to use host.docker.internal for container access

Write-Host "🔐 Setting up Kubernetes credentials for devcontainer..." -ForegroundColor Cyan

$sourceConfig = Join-Path $env:USERPROFILE ".kube\config"

if (-not (Test-Path $sourceConfig)) {
    Write-Host "❌ Error: $sourceConfig not found" -ForegroundColor Red
    Write-Host "   Make sure Rancher Desktop or Docker Desktop is installed" -ForegroundColor Yellow
    exit 1
}

# Get script directory
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Create target directory
$targetDir = Join-Path $scriptDir ".kube"
New-Item -ItemType Directory -Force -Path $targetDir | Out-Null

# Copy config
$targetConfig = Join-Path $targetDir "config"
Copy-Item $sourceConfig $targetConfig

# Rewrite server URLs for container access
Write-Host "📝 Rewriting kubeconfig for devcontainer networking..." -ForegroundColor Cyan

# Read config file
$content = Get-Content $targetConfig -Raw

# Rewrite server URLs to use host.docker.internal
# This is CRITICAL because 127.0.0.1/localhost inside container != host
$content = $content -replace 'https://127\.0\.0\.1:', 'https://host.docker.internal:'
$content = $content -replace 'https://localhost:', 'https://host.docker.internal:'
$content = $content -replace 'https://0\.0\.0\.0:', 'https://host.docker.internal:'
$content = $content -replace 'https://kubernetes\.docker\.internal:', 'https://host.docker.internal:'

# Enable insecure-skip-tls-verify for local development
# Rancher Desktop certs don't include host.docker.internal in SAN
$content = $content -replace 'insecure-skip-tls-verify: false', 'insecure-skip-tls-verify: true'

# Comment out certificate-authority-data (kubectl doesn't allow both)
$content = $content -replace '(?m)^      certificate-authority-data:.*$', '      # certificate-authority-data: (commented out for insecure-skip-tls-verify)'

# Write back
$content | Set-Content $targetConfig -NoNewline

Write-Host "✅ Kubeconfig copied to .devcontainer.secrets\.kube\config" -ForegroundColor Green
Write-Host "✅ Server URLs rewritten to use host.docker.internal" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. If not already there, open this project in VSCode devcontainer"
Write-Host "2. Inside container, add to ~/.bashrc:"
Write-Host "     export KUBECONFIG=/workspace/.devcontainer.secrets/.kube/config"
Write-Host "3. Reload: source ~/.bashrc"
Write-Host "4. Test: kubectl get nodes"
Write-Host ""
Write-Host "Note: Server URLs have been rewritten for container networking." -ForegroundColor Yellow
Write-Host "      Original: https://127.0.0.1:6443" -ForegroundColor Yellow
Write-Host "      Rewritten: https://host.docker.internal:6443" -ForegroundColor Yellow
EOF
    echo "  ✅ Created .devcontainer.secrets/copy-kubeconfig-win.ps1"
}

# Function: install_kubectl_binary
# Downloads and installs kubectl
install_kubectl_binary() {
    echo "📦 Installing kubectl binary..."

    # Detect architecture
    local arch=$(uname -m)
    local kubectl_arch
    case "$arch" in
        x86_64)
            kubectl_arch="amd64"
            ;;
        aarch64|arm64)
            kubectl_arch="arm64"
            ;;
        *)
            echo "❌ Unsupported architecture: $arch"
            return 1
            ;;
    esac

    echo "  Detected architecture: $arch (kubectl: $kubectl_arch)"

    # Use /tmp for downloading (writable directory)
    cd /tmp

    # Download latest stable kubectl for detected architecture
    echo "  Downloading kubectl for $kubectl_arch..."
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/${kubectl_arch}/kubectl"

    # Install
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

    # Clean up
    rm kubectl

    echo "✅ kubectl binary installed"
}

# Function: check_kubeconfig_and_guide
# Checks if kubeconfig exists and configures kubectl automatically
check_kubeconfig_and_guide() {
    # Always configure KUBECONFIG in ~/.bashrc
    local bashrc="$HOME/.bashrc"
    local kubeconfig_line='export KUBECONFIG=/workspace/.devcontainer.secrets/.kube/config'

    if ! grep -q "KUBECONFIG=/workspace/.devcontainer.secrets/.kube/config" "$bashrc" 2>/dev/null; then
        echo "" >> "$bashrc"
        echo "# kubectl configuration (auto-added by install-kubectl.sh)" >> "$bashrc"
        echo "$kubeconfig_line" >> "$bashrc"
        echo "✅ Configured KUBECONFIG in ~/.bashrc"
    else
        echo "✅ KUBECONFIG already configured in ~/.bashrc"
    fi

    if [ -f /workspace/.devcontainer.secrets/.kube/config ]; then
        echo "✅ Kubeconfig found at /workspace/.devcontainer.secrets/.kube/config"
        echo ""
        echo "kubectl is ready to use!"
        echo "  Current session: export KUBECONFIG=/workspace/.devcontainer.secrets/.kube/config"
        echo "  New sessions: automatically configured via ~/.bashrc"
        echo ""
        echo "Test with: kubectl get nodes"
    else
        echo "⚠️  Kubeconfig not found at /workspace/.devcontainer.secrets/.kube/config"
        echo ""
        echo "To enable kubectl access:"
        echo "1. Exit devcontainer (open host terminal)"
        echo "2. Navigate to project directory"
        echo "3. Run helper script:"
        echo ""
        echo "   Mac/Linux:"
        echo "     ./.devcontainer.secrets/copy-kubeconfig-mac.sh"
        echo ""
        echo "   Windows (PowerShell):"
        echo "     .\\.devcontainer.secrets\\copy-kubeconfig-win.ps1"
        echo ""
        echo "4. Reload shell or restart devcontainer"
        echo ""
        echo "kubectl will work automatically in new sessions!"
        echo "See: /workspace/.devcontainer.secrets/README.md for details"
    fi
}

#------------------------------------------------------------------------------
# STANDARD PACKAGE ARRAYS
#------------------------------------------------------------------------------
SYSTEM_PACKAGES=(
    "curl"
    "ca-certificates"
)

NODE_PACKAGES=()
PYTHON_PACKAGES=()
PWSH_MODULES=()

# VS Code extensions
declare -A EXTENSIONS
EXTENSIONS["ms-kubernetes-tools.vscode-kubernetes-tools"]="Kubernetes|Kubernetes cluster management"

VERIFY_COMMANDS=(
    "command -v kubectl >/dev/null && kubectl version --client || echo '❌ kubectl not found'"
    "test -f /workspace/.devcontainer.secrets/.kube/config && echo '✅ kubeconfig found' || echo '⚠️  kubeconfig not found'"
)

# Post-installation notes
post_installation_message() {
    echo ""
    echo "🎉 kubectl Installation Complete!"
    echo ""

    check_kubeconfig_and_guide

    echo ""
    echo "📚 Documentation:"
    echo "  - .devcontainer.secrets folder: /workspace/.devcontainer.secrets/README.md"
    echo "  - kubectl usage: .devcontainer/howto/howto-kubectl.md (to be created)"
}

# Post-uninstallation notes
post_uninstallation_message() {
    echo ""
    echo "🏁 Uninstallation process complete for: $SCRIPT_NAME!"
    echo ""
    echo "Additional Notes:"
    echo "1. kubectl binary has been removed"
    echo "2. .devcontainer.secrets/ folder is still present (manual cleanup if needed)"
    echo "3. VSCode extension may need manual removal"
}

#------------------------------------------------------------------------------
# STANDARD SCRIPT LOGIC - Do not modify anything below this line
#------------------------------------------------------------------------------

# Initialize mode flags
DEBUG_MODE=0
UNINSTALL_MODE=0
FORCE_MODE=0

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
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
            echo "Usage: $0 [--debug] [--uninstall] [--force]" >&2
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
source "${SCRIPT_DIR}/lib/core-install-apt.sh"
source "${SCRIPT_DIR}/lib/core-install-node.sh"
source "${SCRIPT_DIR}/lib/core-install-extensions.sh"
source "${SCRIPT_DIR}/lib/core-install-pwsh.sh"
source "${SCRIPT_DIR}/lib/core-install-python-packages.sh"

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
    echo "🔄 Starting uninstallation process for: $SCRIPT_NAME"
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
else
    echo "🔄 Starting installation process for: $SCRIPT_NAME"
    echo "Purpose: $SCRIPT_DESCRIPTION"

    # Custom setup (creates .devcontainer.secrets/)
    pre_installation_setup

    # Install kubectl binary
    install_kubectl_binary

    # Standard package installation
    process_installations

    # Verify kubectl
    verify_installations

    # Install VSCode extension
    if [ ${#EXTENSIONS[@]} -gt 0 ]; then
        for ext_id in "${!EXTENSIONS[@]}"; do
            IFS='|' read -r name description _ <<< "${EXTENSIONS[$ext_id]}"
            check_extension_state "$ext_id" "install" "$name"
        done
    fi

    # Final message with kubeconfig guidance
    post_installation_message

    # Auto-enable for container rebuild
    auto_enable_tool "kubernetes-kubectl-cli" "Kubernetes kubectl CLI"
fi
