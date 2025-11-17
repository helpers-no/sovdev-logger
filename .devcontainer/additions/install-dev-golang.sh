#!/bin/bash
# file: .devcontainer/additions/install-dev-golang.sh
#
# Usage: ./install-dev-golang.sh [options] [--version <go_version>]
#
# Options:
#   --debug     : Enable debug output for troubleshooting
#   --uninstall : Remove installed components instead of installing them
#   --force     : Force installation/uninstallation
#   --version X.Y.Z : Install a specific Go version (e.g., 1.21.0)
#                     Defaults to a predefined stable version if not specified.
#
# Examples:
#   ./install-dev-golang.sh
#   ./install-dev-golang.sh --version 1.21.0
#   ./install-dev-golang.sh --version 1.20.0 --uninstall
#
#------------------------------------------------------------------------------
# CONFIGURATION - Modify this section for the Go script
#------------------------------------------------------------------------------

# --- Script Metadata ---
SCRIPT_NAME="Go Runtime & Development Tools"
SCRIPT_DESCRIPTION="Installs Go runtime, common tools, and VS Code extensions for Go development."
SCRIPT_CATEGORY="LANGUAGE_DEV"
CHECK_INSTALLED_COMMAND="[ -f /usr/local/go/bin/go ] || [ -f /usr/bin/go ] || command -v go >/dev/null 2>&1"

#------------------------------------------------------------------------------

# Source auto-enable library
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/tool-auto-enable.sh"

#------------------------------------------------------------------------------

# --- Default Configuration ---
DEFAULT_GO_VERSION="1.21.0" # Specify the default Go version to install
TARGET_GO_VERSION=""        # Will be set based on --version flag or default

# --- Utility Functions ---
detect_architecture() {
    if command -v dpkg > /dev/null 2>&1; then
        ARCH=$(dpkg --print-architecture)
    elif command -v uname > /dev/null 2>&1; then
        local unamem=$(uname -m)
        case "$unamem" in
            aarch64|arm64) ARCH="arm64" ;;
            x86_64) ARCH="amd64" ;;
            *) ARCH="$unamem" ;;
        esac
    else
        ARCH="unknown"
    fi
    echo "$ARCH"
}

get_installed_go_version() {
    if command -v go > /dev/null; then
        go version | grep -oP 'go\K[0-9.]+'
    else
        echo ""
    fi
}

# --- Pre-installation/Uninstallation Setup ---
pre_installation_setup() {
    echo "🔧 Preparing environment..."
    
    # Ensure essential tools are present
    if ! command -v sudo > /dev/null || ! command -v apt-get > /dev/null || ! command -v curl > /dev/null || ! command -v gpg > /dev/null; then
         echo "⏳ Installing prerequisites (sudo, curl, apt-transport-https, gpg)..."
         apt-get update -y > /dev/null
         apt-get install -y --no-install-recommends sudo curl apt-transport-https ca-certificates gnupg > /dev/null
    fi

    if [ "${UNINSTALL_MODE}" -eq 1 ]; then
        echo "🔧 Preparing for Go uninstallation..."
        if [ -z "$TARGET_GO_VERSION" ]; then
            TARGET_GO_VERSION=$(get_installed_go_version)
            if [ -z "$TARGET_GO_VERSION" ]; then
                echo "⚠️ Could not detect installed Go version. Please specify with --version X.Y.Z to uninstall."
                exit 1
            else
                echo "ℹ️ Detected Go version $TARGET_GO_VERSION for uninstallation."
            fi
        fi

        declare -g GO_PACKAGES=(
            "golang-go"
            "golang-go.tools"
            "golang-golang-x-tools"
        )
    else
        echo "🔧 Performing pre-installation setup for Go..."
        SYSTEM_ARCH=$(detect_architecture)
        echo "🖥️ Detected system architecture: $SYSTEM_ARCH"

        if [ -z "$TARGET_GO_VERSION" ]; then
            TARGET_GO_VERSION="$DEFAULT_GO_VERSION"
            echo "ℹ️ No --version specified, using default: $TARGET_GO_VERSION"
        else
            echo "ℹ️ Target Go version specified: $TARGET_GO_VERSION"
        fi

        local current_version=$(get_installed_go_version)
        if [[ "$current_version" == "$TARGET_GO_VERSION" ]]; then
            echo "✅ Go $TARGET_GO_VERSION seems to be already installed."
        elif [ -n "$current_version" ]; then
            echo "⚠️ Go version $current_version is installed. This script will install $TARGET_GO_VERSION alongside it."
            echo "   You may need to update your PATH to use the new version."
        fi

        # Set up Go installation directory
        GO_INSTALL_DIR="/usr/local/go"
        GO_BIN_DIR="/usr/local/go/bin"
        
        # Add Go binary directory to PATH if not already present
        if ! grep -q "$GO_BIN_DIR" ~/.bashrc; then
            echo "export PATH=\$PATH:$GO_BIN_DIR" >> ~/.bashrc
            source ~/.bashrc
        fi
    fi
}

# --- Define VS Code extensions for Go Development ---
declare -A EXTENSIONS
EXTENSIONS["golang.go"]="Go|Core Go language support"
EXTENSIONS["premparihar.gotestexplorer"]="Go Test Explorer|Test runner and debugger"
EXTENSIONS["zxh404.vscode-proto3"]="Protocol Buffers|Protocol Buffer support"
EXTENSIONS["redhat.vscode-yaml"]="YAML|YAML support for Go configuration"
EXTENSIONS["ms-azuretools.vscode-docker"]="Docker|Docker support for Go applications"

# --- Define verification commands ---
VERIFY_COMMANDS=(
    "command -v go >/dev/null && go version || echo '❌ Go not found'"
    "go env || echo '❌ Failed to get Go environment'"
    "go list -m all || echo '❌ Failed to list Go modules'"
)

# --- Post-installation/Uninstallation Messages ---
post_installation_message() {
    local go_version
    go_version=$(go version 2>/dev/null || echo "not found")

    echo
    echo "🎉 Installation process complete for: $SCRIPT_NAME!"
    echo "Purpose: $SCRIPT_DESCRIPTION"
    echo
    echo "Important Notes:"
    echo "1. Go: $go_version"
    echo "2. Go workspace: $GOPATH"
    echo "3. VS Code extensions for Go development suggested/installed."
    echo
    echo "Quick Start Commands:"
    echo "- Check Go version: go version"
    echo "- Check Go environment: go env"
    echo "- Create new module: go mod init example.com/hello"
    echo "- Build program: go build"
    echo "- Run program: go run main.go"
    echo "- Test program: go test ./..."
    echo "- Install dependencies: go get ./..."
    echo
    echo "Documentation Links:"
    echo "- Go Documentation: https://golang.org/doc/"
    echo "- Go Modules: https://golang.org/ref/mod"
    echo "- Go Standard Library: https://pkg.go.dev/std"
    echo "- VS Code Go Extension: https://marketplace.visualstudio.com/items?itemName=golang.go"
    echo
    echo "Installation Status:"
    verify_installations
}

post_uninstallation_message() {
    echo
    echo "🏁 Uninstallation process complete for specified Go components."
    echo
    echo "Additional Notes:"
    echo "1. If other Go versions remain, they were not touched unless specified."
    echo "2. Go workspace and modules might remain in $GOPATH"
    echo "3. Check VS Code extensions if they need manual removal."

    echo
    echo "Checking for remaining components..."
    if command -v go >/dev/null; then
        echo "⚠️ Go $(go version) is still installed."
    else
        echo "✅ Go appears to be removed."
    fi

    if [ ${#EXTENSIONS[@]} -gt 0 ]; then
        local remaining_ext=0
        for ext_id in "${!EXTENSIONS[@]}"; do
            if code --list-extensions 2>/dev/null | grep -qi "^${ext_id}$"; then
                if [ $remaining_ext -eq 0 ]; then
                    echo "⚠️ Some VS Code extensions might remain:"
                fi
                echo "   - ${EXTENSIONS[$ext_id]%%|*}"
                ((remaining_ext++))
            fi
        done
        if [ $remaining_ext -eq 0 ]; then
            echo "✅ No VS Code extensions remain."
        fi
    fi
}

#------------------------------------------------------------------------------
# ARGUMENT PARSING
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
        --version)
            if [[ -n "$2" && "$2" != --* ]]; then
                TARGET_GO_VERSION="$2"
                shift 2
            else
                echo "Error: --version requires a value (e.g., 1.21.0)" >&2
                exit 1
            fi
            ;;
        *)
            echo "Error: Unknown argument: $1" >&2
            echo "Usage: $0 [--debug] [--uninstall] [--force] [--version X.Y.Z]"
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
CORE_SCRIPT_DIR="$(dirname "$0")"
source "${CORE_SCRIPT_DIR}/core-install-extensions.sh"

#------------------------------------------------------------------------------
# HELPER FUNCTIONS
#------------------------------------------------------------------------------

# Function to install Go from official binaries
install_go_binary() {
    local version="$1"
    local arch="$2"
    local install_dir="$3"

    echo "📦 Downloading Go $version for $arch..."

    # Download Go binary
    local download_url="https://go.dev/dl/go${version}.linux-${arch}.tar.gz"
    local temp_file="/tmp/go${version}.linux-${arch}.tar.gz"

    if ! curl -fsSL "$download_url" -o "$temp_file"; then
        echo "❌ Failed to download Go from $download_url"
        return 1
    fi

    echo "📦 Extracting Go to $install_dir..."

    # Remove existing installation if present
    if [ -d "$install_dir" ]; then
        echo "🗑️  Removing existing Go installation..."
        sudo rm -rf "$install_dir"
    fi

    # Extract to /usr/local
    if ! sudo tar -C /usr/local -xzf "$temp_file"; then
        echo "❌ Failed to extract Go"
        rm -f "$temp_file"
        return 1
    fi

    rm -f "$temp_file"
    echo "✅ Go $version installed successfully"
    return 0
}

# Function to setup Go environment
setup_go_environment() {
    local go_bin_dir="$1"

    # Add Go to PATH in .bashrc if not already present
    if ! grep -q "$go_bin_dir" ~/.bashrc; then
        echo "" >> ~/.bashrc
        echo "# Go environment" >> ~/.bashrc
        echo "export PATH=\"$go_bin_dir:\$PATH\"" >> ~/.bashrc
        echo "✅ Added Go to PATH in ~/.bashrc"
    fi

    # Setup GOPATH
    local gopath="$HOME/go"
    if [ ! -d "$gopath" ]; then
        mkdir -p "$gopath"/{bin,src,pkg}
        echo "✅ Created GOPATH directory structure at $gopath"
    fi

    if ! grep -q "GOPATH" ~/.bashrc; then
        echo "export GOPATH=\"$gopath\"" >> ~/.bashrc
        echo "export PATH=\"\$GOPATH/bin:\$PATH\"" >> ~/.bashrc
        echo "✅ Added GOPATH to ~/.bashrc"
    fi
}

# Function to install Go tools
install_go_tools() {
    echo "📦 Installing common Go development tools..."

    local tools=(
        "golang.org/x/tools/gopls@latest"
        "github.com/go-delve/delve/cmd/dlv@latest"
        "honnef.co/go/tools/cmd/staticcheck@latest"
    )

    for tool in "${tools[@]}"; do
        echo "  Installing $tool..."
        if go install "$tool" 2>/dev/null; then
            echo "  ✅ Installed $(basename $tool)"
        else
            echo "  ⚠️  Failed to install $tool (non-critical)"
        fi
    done
}

# Function to process installations
process_installations() {
    if [ "${UNINSTALL_MODE}" -eq 1 ]; then
        # Uninstall Go
        if [ -d "$GO_INSTALL_DIR" ]; then
            echo "🗑️  Removing Go installation from $GO_INSTALL_DIR..."
            sudo rm -rf "$GO_INSTALL_DIR"
            echo "✅ Go removed"
        else
            echo "ℹ️  No Go installation found at $GO_INSTALL_DIR"
        fi

        # Note: We don't remove .bashrc entries to avoid breaking user's shell config
        echo "ℹ️  Note: PATH entries in ~/.bashrc were not removed"
    else
        # Install Go
        SYSTEM_ARCH=$(detect_architecture)

        # Map architecture names
        case "$SYSTEM_ARCH" in
            amd64|x86_64) SYSTEM_ARCH="amd64" ;;
            arm64|aarch64) SYSTEM_ARCH="arm64" ;;
        esac

        if ! install_go_binary "$TARGET_GO_VERSION" "$SYSTEM_ARCH" "$GO_INSTALL_DIR"; then
            echo "❌ Go installation failed"
            exit 1
        fi

        setup_go_environment "$GO_BIN_DIR"

        # Source the environment so we can use go commands
        export PATH="$GO_BIN_DIR:$PATH"
        export GOPATH="$HOME/go"

        # Install Go tools
        install_go_tools
    fi

    # Process VS Code extensions
    if [ ${#EXTENSIONS[@]} -gt 0 ]; then
        process_extensions "EXTENSIONS"
    fi
}

# Function to verify installations
verify_installations() {
    if [ ${#VERIFY_COMMANDS[@]} -gt 0 ]; then
        echo ""
        echo "🔍 Verifying installations..."
        # Source PATH updates to verify
        export PATH="/usr/local/go/bin:$PATH"
        for cmd in "${VERIFY_COMMANDS[@]}"; do
            eval "$cmd" || true
        done
    fi
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
    verify_installations
    post_installation_message

    # Auto-enable for container rebuild
    auto_enable_tool "go-runtime-&-development-tools" "Go Runtime & Development Tools"
fi

echo "✅ Script execution finished."
exit 0 