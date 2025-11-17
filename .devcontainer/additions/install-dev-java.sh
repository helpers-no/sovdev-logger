#!/bin/bash
# file: .devcontainer/additions/install-dev-java.sh
#
# Usage: ./install-dev-java.sh [options] [--version <java_version>]
#
# Options:
#   --debug     : Enable debug output for troubleshooting
#   --uninstall : Remove installed components instead of installing them
#   --force     : Force installation/uninstallation
#   --version X : Install a specific Java version (e.g., 11, 17, 21)
#                 Defaults to a predefined stable version if not specified.
#
# Examples:
#   ./install-dev-java.sh
#   ./install-dev-java.sh --version 17
#   ./install-dev-java.sh --version 11 --uninstall
#
#------------------------------------------------------------------------------
# CONFIGURATION - Modify this section for the Java script
#------------------------------------------------------------------------------

# --- Script Metadata ---
SCRIPT_NAME="Java Runtime & Development Tools"
SCRIPT_DESCRIPTION="Installs Java JDK, Maven, Gradle, and VS Code extensions for Java development."
SCRIPT_CATEGORY="LANGUAGE_DEV"
CHECK_INSTALLED_COMMAND="[ -f /usr/bin/java ] || [ -f /usr/lib/jvm/*/bin/java ] || command -v java >/dev/null 2>&1"

#------------------------------------------------------------------------------

# Source auto-enable library
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/tool-auto-enable.sh"

#------------------------------------------------------------------------------

# --- Default Configuration ---
DEFAULT_JAVA_VERSION="17" # Specify the default Java version to install
TARGET_JAVA_VERSION=""    # Will be set based on --version flag or default

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

get_installed_java_version() {
    if command -v java > /dev/null; then
        java -version 2>&1 | head -n 1 | grep -oP 'version "\K[^"]+' | cut -d. -f1
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
        echo "🔧 Preparing for Java uninstallation..."
        if [ -z "$TARGET_JAVA_VERSION" ]; then
            TARGET_JAVA_VERSION=$(get_installed_java_version)
            if [ -z "$TARGET_JAVA_VERSION" ]; then
                echo "⚠️ Could not detect installed Java version. Please specify with --version X to uninstall."
                exit 1
            else
                echo "ℹ️ Detected Java version $TARGET_JAVA_VERSION for uninstallation."
            fi
        fi

        declare -g JAVA_APT_PACKAGES=(
            "openjdk-${TARGET_JAVA_VERSION}-jdk"
            "openjdk-${TARGET_JAVA_VERSION}-jre"
            "maven"
            "gradle"
        )
    else
        echo "🔧 Performing pre-installation setup for Java..."
        SYSTEM_ARCH=$(detect_architecture)
        echo "🖥️ Detected system architecture: $SYSTEM_ARCH"

        if [ -z "$TARGET_JAVA_VERSION" ]; then
            TARGET_JAVA_VERSION="$DEFAULT_JAVA_VERSION"
            echo "ℹ️ No --version specified, using default: $TARGET_JAVA_VERSION"
        else
            echo "ℹ️ Target Java version specified: $TARGET_JAVA_VERSION"
        fi

        local current_version=$(get_installed_java_version)
        if [[ "$current_version" == "$TARGET_JAVA_VERSION" ]]; then
            echo "✅ Java $TARGET_JAVA_VERSION seems to be already installed."
        elif [ -n "$current_version" ]; then
            echo "⚠️ Java version $current_version is installed. This script will install $TARGET_JAVA_VERSION alongside it."
            echo "   You may need to use 'update-alternatives' to switch between them."
        fi

        # Add Adoptium repository for Java
        echo "➕ Adding Adoptium repository..."
        if ! grep -q "adoptium" /etc/apt/sources.list.d/adoptium.list 2>/dev/null; then
            wget -O - https://packages.adoptium.net/artifactory/api/gpg/key/public | sudo apt-key add -
            echo "deb https://packages.adoptium.net/artifactory/deb $(awk -F= '/^VERSION_CODENAME/{print$2}' /etc/os-release) main" | sudo tee /etc/apt/sources.list.d/adoptium.list
        else
            echo "ℹ️ Adoptium repository already added."
        fi
        
        echo "🔄 Updating package lists after adding repository..."
        sudo apt-get update -y > /dev/null

        declare -g JAVA_APT_PACKAGES=(
            "temurin-${TARGET_JAVA_VERSION}-jdk"
            "maven"
            "gradle"
        )
    fi
}

# --- Define VS Code extensions for Java Development ---
declare -A EXTENSIONS
EXTENSIONS["redhat.java"]="Language Support for Java|Core Java language support"
EXTENSIONS["vscjava.vscode-java-debug"]="Debugger for Java|Debugging support"
EXTENSIONS["vscjava.vscode-java-test"]="Test Runner for Java|Test runner and debugger"
EXTENSIONS["vscjava.vscode-maven"]="Maven for Java|Maven project support"
EXTENSIONS["vscjava.vscode-java-dependency"]="Dependency Viewer|View and manage dependencies"
EXTENSIONS["vscjava.vscode-java-pack"]="Extension Pack for Java|Collection of popular Java extensions"

# --- Define verification commands ---
VERIFY_COMMANDS=(
    "command -v java >/dev/null && java -version || echo '❌ Java not found'"
    "command -v javac >/dev/null && javac -version || echo '❌ Java compiler not found'"
    "command -v mvn >/dev/null && mvn --version || echo '❌ Maven not found'"
    "command -v gradle >/dev/null && gradle --version || echo '❌ Gradle not found'"
)

# --- Post-installation/Uninstallation Messages ---
post_installation_message() {
    local java_version
    local maven_version
    local gradle_version
    java_version=$(java -version 2>&1 | head -n 1)
    maven_version=$(mvn --version 2>/dev/null | head -n 1 || echo "not found")
    gradle_version=$(gradle --version 2>/dev/null | head -n 1 || echo "not found")

    echo
    echo "🎉 Installation process complete for: $SCRIPT_NAME!"
    echo "Purpose: $SCRIPT_DESCRIPTION"
    echo
    echo "Important Notes:"
    echo "1. Java: $java_version"
    echo "2. Maven: $maven_version"
    echo "3. Gradle: $gradle_version"
    echo "4. VS Code extensions for Java development suggested/installed."
    echo
    echo "Quick Start Commands:"
    echo "- Check Java version: java -version"
    echo "- Check Maven version: mvn --version"
    echo "- Check Gradle version: gradle --version"
    echo "- Compile Java file: javac HelloWorld.java"
    echo "- Run Java program: java HelloWorld"
    echo "- Create Maven project: mvn archetype:generate"
    echo "- Create Gradle project: gradle init"
    echo
    echo "Documentation Links:"
    echo "- Java Documentation: https://docs.oracle.com/en/java/"
    echo "- Maven Documentation: https://maven.apache.org/guides/"
    echo "- Gradle Documentation: https://docs.gradle.org/current/userguide/userguide.html"
    echo "- VS Code Java Extension Pack: https://marketplace.visualstudio.com/items?itemName=vscjava.vscode-java-pack"
    echo
    echo "Installation Status:"
    verify_installations
}

post_uninstallation_message() {
    echo
    echo "🏁 Uninstallation process complete for specified Java components."
    echo
    echo "Additional Notes:"
    echo "1. If other Java versions remain, they were not touched unless specified."
    echo "2. Maven and Gradle caches might remain in ~/.m2 and ~/.gradle"
    echo "3. Check VS Code extensions if they need manual removal."

    echo
    echo "Checking for remaining components..."
    if command -v java >/dev/null; then
        echo "⚠️ Java $(java -version 2>&1 | head -n 1) is still installed."
    else
        echo "✅ Java appears to be removed."
    fi
    if command -v mvn >/dev/null; then
        echo "⚠️ Maven $(mvn --version | head -n 1) is still installed."
    else
        echo "✅ Maven appears to be removed."
    fi
    if command -v gradle >/dev/null; then
        echo "⚠️ Gradle $(gradle --version | head -n 1) is still installed."
    else
        echo "✅ Gradle appears to be removed."
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
                TARGET_JAVA_VERSION="$2"
                shift 2
            else
                echo "Error: --version requires a value (e.g., 17, 21)" >&2
                exit 1
            fi
            ;;
        *)
            echo "Error: Unknown argument: $1" >&2
            echo "Usage: $0 [--debug] [--uninstall] [--force] [--version X]"
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
source "${CORE_SCRIPT_DIR}/core-install-apt.sh"
source "${CORE_SCRIPT_DIR}/core-install-extensions.sh"

#------------------------------------------------------------------------------
# HELPER FUNCTIONS
#------------------------------------------------------------------------------

# Function to process APT installations
process_apt_installations() {
    if [ "${UNINSTALL_MODE}" -eq 1 ]; then
        if [ ${#JAVA_APT_PACKAGES[@]} -gt 0 ]; then
            echo "🗑️ Uninstalling Java packages..."
            for package in "${JAVA_APT_PACKAGES[@]}"; do
                if dpkg -l "$package" 2>/dev/null | grep -q "^ii"; then
                    echo "  Removing $package..."
                    sudo apt-get remove -y "$package" > /dev/null 2>&1 || true
                fi
            done

            # Clean up
            sudo apt-get autoremove -y > /dev/null 2>&1 || true
            echo "✅ Java packages removed"
        fi
    else
        if [ ${#JAVA_APT_PACKAGES[@]} -gt 0 ]; then
            echo "📦 Installing Java packages..."
            for package in "${JAVA_APT_PACKAGES[@]}"; do
                echo "  Installing $package..."
                if sudo apt-get install -y "$package" > /dev/null 2>&1; then
                    echo "  ✅ Installed $package"
                else
                    echo "  ⚠️  Failed to install $package"
                fi
            done
        fi
    fi
}

# Function to setup JAVA_HOME
setup_java_environment() {
    local java_home=""

    # Find JAVA_HOME
    if command -v java >/dev/null 2>&1; then
        java_home=$(dirname $(dirname $(readlink -f $(which java))))
    fi

    if [ -n "$java_home" ]; then
        # Add JAVA_HOME to .bashrc if not already present
        if ! grep -q "JAVA_HOME" ~/.bashrc; then
            echo "" >> ~/.bashrc
            echo "# Java environment" >> ~/.bashrc
            echo "export JAVA_HOME=\"$java_home\"" >> ~/.bashrc
            echo "export PATH=\"\$JAVA_HOME/bin:\$PATH\"" >> ~/.bashrc
            echo "✅ Added JAVA_HOME to ~/.bashrc"
        else
            echo "ℹ️ JAVA_HOME already configured in ~/.bashrc"
        fi

        # Export for current session
        export JAVA_HOME="$java_home"
        export PATH="$JAVA_HOME/bin:$PATH"
    fi
}

# Function to process installations
process_installations() {
    # Process APT packages
    process_apt_installations

    # Setup environment if installing
    if [ "${UNINSTALL_MODE}" -eq 0 ]; then
        setup_java_environment
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
    auto_enable_tool "java-runtime-&-development-tools" "Java Runtime & Development Tools"
fi

echo "✅ Script execution finished."
exit 0 