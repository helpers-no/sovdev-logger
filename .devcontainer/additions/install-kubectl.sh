#!/bin/bash
# file: .devcontainer/additions/install-kubectl.sh
#
# Installs kubectl and sets up topsecret folder for credentials
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
SCRIPT_DESCRIPTION="Installs kubectl and sets up topsecret folder for credentials"
SCRIPT_CATEGORY="INFRA_CONFIG"
CHECK_INSTALLED_COMMAND="command -v kubectl >/dev/null 2>&1"

# Custom function BEFORE standard package installation
pre_installation_setup() {
    if [ "${UNINSTALL_MODE}" -eq 1 ]; then
        echo "🔧 Preparing for uninstallation..."
    else
        echo "🔧 Setting up topsecret folder structure..."
        setup_topsecret_folder
    fi
}

#------------------------------------------------------------------------------
# CUSTOM FUNCTIONS (kubectl-specific logic)
#------------------------------------------------------------------------------

# Function: setup_topsecret_folder
# Creates folder structure, README, .gitignore, helper scripts
setup_topsecret_folder() {
    echo "📁 Creating topsecret/ folder for sensitive files..."

    # 1. Add to root .gitignore
    add_to_gitignore

    # 2. Create folder
    mkdir -p /workspace/topsecret

    # 3. Create topsecret/README.md
    create_topsecret_readme

    # 4. Create topsecret/.gitignore
    create_topsecret_gitignore

    # 5. Create topsecret/copy-kubeconfig-mac.sh
    create_mac_helper_script

    # 6. Create topsecret/copy-kubeconfig-win.ps1
    create_windows_helper_script

    echo "✅ topsecret/ folder structure created"
}

# Function: add_to_gitignore
# Adds topsecret/ to root .gitignore if not already there
add_to_gitignore() {
    local gitignore_file="/workspace/.gitignore"
    local gitignore_line="topsecret/"

    if [ -f "$gitignore_file" ]; then
        if grep -q "^topsecret/" "$gitignore_file"; then
            echo "  ✅ topsecret/ already in .gitignore"
        else
            echo "" >> "$gitignore_file"
            echo "# Top secret folder - contains credentials (NEVER commit)" >> "$gitignore_file"
            echo "topsecret/" >> "$gitignore_file"
            echo "  ✅ Added topsecret/ to .gitignore"
        fi
    else
        echo "# Top secret folder - contains credentials (NEVER commit)" > "$gitignore_file"
        echo "topsecret/" >> "$gitignore_file"
        echo "  ✅ Created .gitignore with topsecret/"
    fi
}

# Function: create_topsecret_readme
# Creates README.md with heredoc
create_topsecret_readme() {
    cat > /workspace/topsecret/README.md <<'EOF'
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
./topsecret/copy-kubeconfig-mac.sh
```

**Windows (PowerShell):**
```powershell
.\topsecret\copy-kubeconfig-win.ps1
```

This script:
1. Copies `~/.kube/config` to `topsecret/.kube/config`
2. **Rewrites server URLs** for container networking (see below)

Then inside devcontainer:
```bash
export KUBECONFIG=/workspace/topsecret/.kube/config
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

# Rewritten (in topsecret/.kube/config):
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
topsecret/
```

**Local `topsecret/.gitignore`:**
```
*
!README.md
!.gitignore
!copy-kubeconfig-mac.sh
!copy-kubeconfig-win.ps1
```

Only documentation and helper scripts are tracked in git. Everything else is ignored.
EOF
    echo "  ✅ Created topsecret/README.md"
}

# Function: create_topsecret_gitignore
create_topsecret_gitignore() {
    cat > /workspace/topsecret/.gitignore <<'EOF'
# Ignore everything in topsecret/
*

# Except these files (documentation and helper scripts)
!README.md
!.gitignore
!copy-kubeconfig-mac.sh
!copy-kubeconfig-win.ps1
EOF
    echo "  ✅ Created topsecret/.gitignore"
}

# Function: create_mac_helper_script
create_mac_helper_script() {
    cat > /workspace/topsecret/copy-kubeconfig-mac.sh <<'EOF'
#!/bin/bash
# file: topsecret/copy-kubeconfig-mac.sh
# Copies ~/.kube/config to topsecret/.kube/config
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

echo "✅ Kubeconfig copied to topsecret/.kube/config"
echo "✅ Server URLs rewritten to use host.docker.internal"
echo ""
echo "Next steps:"
echo "1. If not already there, open this project in VSCode devcontainer"
echo "2. Inside container, add to ~/.bashrc:"
echo "     export KUBECONFIG=/workspace/topsecret/.kube/config"
echo "3. Reload: source ~/.bashrc"
echo "4. Test: kubectl get nodes"
echo ""
echo "Note: Server URLs have been rewritten for container networking."
echo "      Original: https://127.0.0.1:6443"
echo "      Rewritten: https://host.docker.internal:6443"
EOF
    chmod +x /workspace/topsecret/copy-kubeconfig-mac.sh
    echo "  ✅ Created topsecret/copy-kubeconfig-mac.sh"
}

# Function: create_windows_helper_script
create_windows_helper_script() {
    cat > /workspace/topsecret/copy-kubeconfig-win.ps1 <<'EOF'
# file: topsecret/copy-kubeconfig-win.ps1
# Copies %USERPROFILE%\.kube\config to topsecret\.kube\config
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

Write-Host "✅ Kubeconfig copied to topsecret\.kube\config" -ForegroundColor Green
Write-Host "✅ Server URLs rewritten to use host.docker.internal" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. If not already there, open this project in VSCode devcontainer"
Write-Host "2. Inside container, add to ~/.bashrc:"
Write-Host "     export KUBECONFIG=/workspace/topsecret/.kube/config"
Write-Host "3. Reload: source ~/.bashrc"
Write-Host "4. Test: kubectl get nodes"
Write-Host ""
Write-Host "Note: Server URLs have been rewritten for container networking." -ForegroundColor Yellow
Write-Host "      Original: https://127.0.0.1:6443" -ForegroundColor Yellow
Write-Host "      Rewritten: https://host.docker.internal:6443" -ForegroundColor Yellow
EOF
    echo "  ✅ Created topsecret/copy-kubeconfig-win.ps1"
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
    local kubeconfig_line='export KUBECONFIG=/workspace/topsecret/.kube/config'

    if ! grep -q "KUBECONFIG=/workspace/topsecret/.kube/config" "$bashrc" 2>/dev/null; then
        echo "" >> "$bashrc"
        echo "# kubectl configuration (auto-added by install-kubectl.sh)" >> "$bashrc"
        echo "$kubeconfig_line" >> "$bashrc"
        echo "✅ Configured KUBECONFIG in ~/.bashrc"
    else
        echo "✅ KUBECONFIG already configured in ~/.bashrc"
    fi

    if [ -f /workspace/topsecret/.kube/config ]; then
        echo "✅ Kubeconfig found at /workspace/topsecret/.kube/config"
        echo ""
        echo "kubectl is ready to use!"
        echo "  Current session: export KUBECONFIG=/workspace/topsecret/.kube/config"
        echo "  New sessions: automatically configured via ~/.bashrc"
        echo ""
        echo "Test with: kubectl get nodes"
    else
        echo "⚠️  Kubeconfig not found at /workspace/topsecret/.kube/config"
        echo ""
        echo "To enable kubectl access:"
        echo "1. Exit devcontainer (open host terminal)"
        echo "2. Navigate to project directory"
        echo "3. Run helper script:"
        echo ""
        echo "   Mac/Linux:"
        echo "     ./topsecret/copy-kubeconfig-mac.sh"
        echo ""
        echo "   Windows (PowerShell):"
        echo "     .\\topsecret\\copy-kubeconfig-win.ps1"
        echo ""
        echo "4. Reload shell or restart devcontainer"
        echo ""
        echo "kubectl will work automatically in new sessions!"
        echo "See: /workspace/topsecret/README.md for details"
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
    "test -f /workspace/topsecret/.kube/config && echo '✅ kubeconfig found' || echo '⚠️  kubeconfig not found'"
)

# Post-installation notes
post_installation_message() {
    echo ""
    echo "🎉 kubectl Installation Complete!"
    echo ""

    check_kubeconfig_and_guide

    echo ""
    echo "📚 Documentation:"
    echo "  - topsecret folder: /workspace/topsecret/README.md"
    echo "  - kubectl usage: .devcontainer/howto/howto-kubectl.md (to be created)"
}

# Post-uninstallation notes
post_uninstallation_message() {
    echo ""
    echo "🏁 Uninstallation process complete for: $SCRIPT_NAME!"
    echo ""
    echo "Additional Notes:"
    echo "1. kubectl binary has been removed"
    echo "2. topsecret/ folder is still present (manual cleanup if needed)"
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
source "$(dirname "$0")/core-install-apt.sh"
source "$(dirname "$0")/core-install-node.sh"
source "$(dirname "$0")/core-install-extensions.sh"
source "$(dirname "$0")/core-install-pwsh.sh"
source "$(dirname "$0")/core-install-python-packages.sh"

# Function to process installations
process_installations() {
    # Process each type of package if array is not empty
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

# Function to verify installations
verify_installations() {
    if [ ${#VERIFY_COMMANDS[@]} -gt 0 ]; then
        echo
        echo "🔍 Verifying installations..."
        for cmd in "${VERIFY_COMMANDS[@]}"; do
            echo "Running: $cmd"
            if ! eval "$cmd"; then
                echo "❌ Verification failed for: $cmd"
            fi
        done
    fi
}

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

    # Custom setup (creates topsecret/)
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
fi
