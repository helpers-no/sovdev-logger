#!/bin/bash
# file: .devcontainer/additions/install-otel-monitoring.sh
#
# DESCRIPTION: Installation script for OpenTelemetry monitoring tools
# PURPOSE: Installs OTel Collector and script_exporter for devcontainer monitoring
#
# Usage: ./install-otel-monitoring.sh [options]
#
# Options:
#   --debug     : Enable debug output for troubleshooting
#   --uninstall : Remove installed components instead of installing them
#   --force     : Force installation/uninstallation even if there are dependencies
#
#------------------------------------------------------------------------------
# CONFIGURATION - Metadata for dev-setup.sh discovery
#------------------------------------------------------------------------------

# Script metadata - must be at the very top of the configuration section
SCRIPT_NAME="OTel Collector"
SCRIPT_DESCRIPTION="Install OpenTelemetry Collector for devcontainer monitoring when connected to our network"
SCRIPT_CATEGORY="INFRA_CONFIG"
CHECK_INSTALLED_COMMAND="([ -f /usr/bin/otelcol-contrib ] || command -v otelcol-contrib >/dev/null 2>&1) && ([ -f /usr/local/bin/script_exporter ] || command -v script_exporter >/dev/null 2>&1) && [ -f /etc/supervisor/conf.d/otel-script-exporter.conf ] && [ -f /etc/supervisor/conf.d/otel-lifecycle.conf ] && [ -f /etc/supervisor/conf.d/otel-metrics.conf ]"
PREREQUISITE_CONFIGS="config-devcontainer-identity.sh config-nginx.sh"

#------------------------------------------------------------------------------

# Source auto-enable library
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/tool-auto-enable.sh"

# Source logging library
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/logging.sh"

#------------------------------------------------------------------------------
# INSTALLATION CONFIGURATION
#------------------------------------------------------------------------------

# OTel Collector configuration
OTEL_VERSION="0.113.0"  # Latest stable version as of 2025-01
OTEL_PACKAGE_NAME="otelcol-contrib"
OTEL_CONFIG_DIR="/workspace/.devcontainer/additions/otel"

# script_exporter configuration (for custom metrics collection)
SCRIPT_EXPORTER_VERSION="3.1.0"  # Latest stable version as of 2025-01
SCRIPT_EXPORTER_BINARY="/usr/local/bin/script_exporter"
SCRIPT_EXPORTER_CONFIG="${OTEL_CONFIG_DIR}/script-exporter-config.yaml"

# Before running installation, we need to add any required repositories or setup
pre_installation_setup() {
    if [ "${UNINSTALL_MODE}" -eq 1 ]; then
        echo "🔧 Preparing for uninstallation..."
    else
        echo "🔧 Performing pre-installation setup..."

        # Check if curl is available
        if ! command -v curl >/dev/null 2>&1; then
            echo "❌ curl is required but not installed"
            echo "   Installing curl..."
            sudo apt-get update && sudo apt-get install -y curl
        fi

        # Create config directory
        mkdir -p "$OTEL_CONFIG_DIR"
    fi
}

# Define package arrays (we don't use standard packages, custom install)
SYSTEM_PACKAGES=()
NODE_PACKAGES=()
PYTHON_PACKAGES=()
PWSH_MODULES=()
declare -A EXTENSIONS

# Custom installation logic for OTel Collector
install_otel_collector() {
    echo ""
    echo "📦 Installing OpenTelemetry Collector v${OTEL_VERSION}..."
    echo ""

    # Detect architecture (map to Debian package naming)
    ARCH=$(uname -m)
    case $ARCH in
        x86_64)
            DEB_ARCH="amd64"
            ;;
        aarch64|arm64)
            DEB_ARCH="arm64"
            ;;
        *)
            echo "❌ Unsupported architecture: $ARCH"
            return 1
            ;;
    esac

    echo "   Architecture: $DEB_ARCH"
    echo "   Version: $OTEL_VERSION"
    echo ""

    # Check if already installed
    if dpkg -l "$OTEL_PACKAGE_NAME" 2>/dev/null | grep -q "^ii"; then
        INSTALLED_VERSION=$(dpkg-query -W -f='${Version}' "$OTEL_PACKAGE_NAME" 2>/dev/null)
        if [ "$INSTALLED_VERSION" = "$OTEL_VERSION" ]; then
            echo "✅ OpenTelemetry Collector v${OTEL_VERSION} is already installed"
            return 0
        else
            echo "ℹ️  Found existing version: $INSTALLED_VERSION"
            echo "   Upgrading to: $OTEL_VERSION"
        fi
    fi

    # Construct download URL
    DEB_FILE="${OTEL_PACKAGE_NAME}_${OTEL_VERSION}_linux_${DEB_ARCH}.deb"
    URL="https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v${OTEL_VERSION}/${DEB_FILE}"

    echo "📥 Downloading Debian package from GitHub releases..."
    echo "   $URL"
    echo ""

    # Download to temp file
    TEMP_DEB=$(mktemp --suffix=.deb)
    if ! curl -L -o "$TEMP_DEB" "$URL"; then
        echo "❌ Failed to download OTel Collector package"
        rm -f "$TEMP_DEB"
        return 1
    fi

    echo "✅ Download complete"
    echo ""
    echo "📦 Installing Debian package..."

    # Install with dpkg
    if ! sudo dpkg -i "$TEMP_DEB"; then
        echo "⚠️  Package installation had issues, attempting to fix dependencies..."
        # Fix any dependency issues
        sudo apt-get install -f -y

        # Verify installation succeeded
        if ! dpkg -l "$OTEL_PACKAGE_NAME" 2>/dev/null | grep -q "^ii"; then
            echo "❌ Failed to install package"
            rm -f "$TEMP_DEB"
            return 1
        fi
    fi

    # Cleanup
    rm -f "$TEMP_DEB"

    echo "✅ Package installed successfully"
    echo ""

    # Verify installation
    if command -v otelcol-contrib >/dev/null 2>&1 && otelcol-contrib --version >/dev/null 2>&1; then
        VERSION_OUTPUT=$(otelcol-contrib --version 2>&1 | head -1)
        echo "✅ Installation verified: $VERSION_OUTPUT"
        return 0
    else
        echo "❌ Installation verification failed"
        return 1
    fi
}

# Install script_exporter for custom metrics collection
install_script_exporter() {
    echo ""
    echo "📦 Installing script_exporter v${SCRIPT_EXPORTER_VERSION}..."
    echo ""

    # Detect architecture
    ARCH=$(uname -m)
    case $ARCH in
        x86_64)
            BIN_ARCH="amd64"
            ;;
        aarch64|arm64)
            BIN_ARCH="arm64"
            ;;
        *)
            echo "❌ Unsupported architecture: $ARCH"
            return 1
            ;;
    esac

    echo "   Architecture: $BIN_ARCH"
    echo "   Version: $SCRIPT_EXPORTER_VERSION"
    echo ""

    # Check if already installed
    if [ -f "$SCRIPT_EXPORTER_BINARY" ]; then
        INSTALLED_VERSION=$("$SCRIPT_EXPORTER_BINARY" --version 2>&1 | grep -oP 'version=v\K[0-9.]+' || echo "unknown")
        if [ "$INSTALLED_VERSION" = "$SCRIPT_EXPORTER_VERSION" ]; then
            echo "✅ script_exporter v${SCRIPT_EXPORTER_VERSION} is already installed"
            return 0
        else
            echo "ℹ️  Found existing version: $INSTALLED_VERSION"
            echo "   Upgrading to: $SCRIPT_EXPORTER_VERSION"
        fi
    fi

    # Construct download URL
    ARCHIVE_NAME="script_exporter-linux-${BIN_ARCH}.tar.gz"
    URL="https://github.com/ricoberger/script_exporter/releases/download/v${SCRIPT_EXPORTER_VERSION}/${ARCHIVE_NAME}"

    echo "📥 Downloading archive from GitHub releases..."
    echo "   $URL"
    echo ""

    # Download to temp file
    TEMP_ARCHIVE=$(mktemp --suffix=.tar.gz)
    if ! curl -L -o "$TEMP_ARCHIVE" "$URL"; then
        echo "❌ Failed to download script_exporter archive"
        rm -f "$TEMP_ARCHIVE"
        return 1
    fi

    echo "✅ Download complete"
    echo ""
    echo "📦 Extracting and installing binary to $SCRIPT_EXPORTER_BINARY..."

    # Extract and install binary
    TEMP_DIR=$(mktemp -d)
    if ! tar -xzf "$TEMP_ARCHIVE" -C "$TEMP_DIR"; then
        echo "❌ Failed to extract archive"
        rm -f "$TEMP_ARCHIVE"
        rm -rf "$TEMP_DIR"
        return 1
    fi

    # Find the binary (should be script_exporter in the extracted directory)
    EXTRACTED_BINARY=$(find "$TEMP_DIR" -name "script_exporter" -type f | head -1)
    if [ -z "$EXTRACTED_BINARY" ]; then
        echo "❌ Could not find script_exporter binary in archive"
        rm -f "$TEMP_ARCHIVE"
        rm -rf "$TEMP_DIR"
        return 1
    fi

    # Install binary
    sudo mv "$EXTRACTED_BINARY" "$SCRIPT_EXPORTER_BINARY"
    sudo chmod +x "$SCRIPT_EXPORTER_BINARY"

    # Cleanup
    rm -f "$TEMP_ARCHIVE"
    rm -rf "$TEMP_DIR"

    echo "✅ Binary installed successfully"
    echo ""

    # Verify installation
    if command -v script_exporter >/dev/null 2>&1 && script_exporter --version >/dev/null 2>&1; then
        VERSION_OUTPUT=$(script_exporter --version 2>&1 | head -1)
        echo "✅ Installation verified: $VERSION_OUTPUT"
        return 0
    else
        echo "❌ Installation verification failed"
        return 1
    fi
}

# Remove supervisord configuration for OTel services
remove_supervisor_configs() {
    echo ""
    echo "🗑️  Removing supervisord configuration for OTel services..."
    echo ""

    # Stop services if supervisord is running
    if pgrep supervisord > /dev/null 2>&1; then
        echo "   Stopping OTel services..."
        sudo supervisorctl stop otel-script-exporter otel-lifecycle otel-metrics 2>/dev/null || true
        sleep 2
    fi

    # Remove supervisor config files
    local configs=("otel-script-exporter.conf" "otel-lifecycle.conf" "otel-metrics.conf")
    for config in "${configs[@]}"; do
        local config_path="/etc/supervisor/conf.d/${config}"
        if [ -f "$config_path" ]; then
            echo "   Removing: $config"
            sudo rm -f "$config_path"
        fi
    done

    # Remove from enabled services
    local enabled_services_conf="/workspace/.devcontainer.extend/enabled-services.conf"
    if [ -f "$enabled_services_conf" ]; then
        echo "   Removing from enabled services..."
        for service in "otel-script-exporter" "otel-lifecycle" "otel-metrics"; do
            sed -i "/^${service}$/d" "$enabled_services_conf" 2>/dev/null || true
        done
    fi

    # Reload supervisor if running
    if pgrep supervisord > /dev/null 2>&1; then
        echo "   Reloading supervisor configuration..."
        sudo supervisorctl reread 2>/dev/null || true
        sudo supervisorctl update 2>/dev/null || true
    fi

    echo "✅ Supervisord configuration removed"
    echo ""
}

# Uninstall script_exporter
uninstall_script_exporter() {
    echo ""
    echo "🗑️  Uninstalling script_exporter..."
    echo ""

    # Stop running script_exporter (in case it's running manually, not via supervisor)
    if pgrep -f "script_exporter.*--config" >/dev/null 2>&1; then
        echo "⚠️  Stopping running script_exporter..."
        sudo pkill -f "script_exporter.*--config" || true
        sleep 2
    fi

    # Remove binary
    if [ -f "$SCRIPT_EXPORTER_BINARY" ]; then
        echo "   Removing binary: $SCRIPT_EXPORTER_BINARY"
        if sudo rm -f "$SCRIPT_EXPORTER_BINARY"; then
            echo "✅ Binary removed successfully"
        else
            echo "❌ Failed to remove binary"
            return 1
        fi
    else
        echo "ℹ️  Binary not installed: $SCRIPT_EXPORTER_BINARY"
    fi

    # Remove log if exists
    if [ -f "/tmp/script-exporter.log" ]; then
        if [ "${FORCE_MODE}" -eq 1 ]; then
            sudo rm -f /tmp/script-exporter.log
            echo "   Removed log file"
        fi
    fi

    echo ""
}

# Uninstall OTel Collector
uninstall_otel_collector() {
    echo ""
    echo "🗑️  Uninstalling OpenTelemetry Collector..."
    echo ""

    # Stop running collector
    if pgrep -f "otelcol.*--config" >/dev/null 2>&1; then
        echo "⚠️  Stopping running collector..."
        sudo pkill -f "otelcol.*--config" || true
        sleep 2
    fi

    # Check if package is installed
    if dpkg -l "$OTEL_PACKAGE_NAME" 2>/dev/null | grep -q "^ii"; then
        echo "   Removing package: $OTEL_PACKAGE_NAME"

        if sudo apt-get remove -y "$OTEL_PACKAGE_NAME"; then
            echo "✅ Package removed successfully"

            # Clean up dependencies
            echo "   Cleaning up unused dependencies..."
            sudo apt-get autoremove -y
        else
            echo "❌ Failed to remove package"
            return 1
        fi
    else
        echo "ℹ️  Package not installed: $OTEL_PACKAGE_NAME"
    fi

    # Remove logs (optional - ask user)
    if [ -f "/var/log/otelcol.log" ]; then
        echo "   Found log file: /var/log/otelcol.log"
        if [ "${FORCE_MODE}" -eq 1 ]; then
            sudo rm -f /var/log/otelcol.log
            echo "   Removed log file"
        else
            echo "   To remove logs, run: sudo rm -f /var/log/otelcol.log"
        fi
    fi

    # Note: We don't remove config directory as it may have user customizations
    echo ""
    echo "ℹ️  Config directory preserved: $OTEL_CONFIG_DIR"
    echo "   To remove manually: rm -rf $OTEL_CONFIG_DIR"
    echo ""
}

#------------------------------------------------------------------------------
# PREREQUISITE CHECK
#------------------------------------------------------------------------------

check_identity() {
    local identity_met=true

    # Check 1: Identity file exists
    if [ ! -f "$HOME/.devcontainer-identity" ]; then
        echo ""
        log_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        log_error "❌ Required Configuration Missing: DevContainer Identity"
        log_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "This tool requires identity configuration before it can be installed."
        echo ""
        echo "OTel Collector uses your identity to label metrics in Grafana, enabling"
        echo "you to filter and identify your specific devcontainer's telemetry data."
        echo ""
        echo "📋 To fix this, follow these steps:"
        echo ""
        echo "STEP 1: Configure your identity"
        echo "  Run: bash /workspace/.devcontainer/additions/config-devcontainer-identity.sh"
        echo ""
        echo "  Or use the configuration checker to configure ALL missing items:"
        echo "  Run: check-configs"
        echo ""
        echo "STEP 2: Resume installation"
        echo "  Run: bash /workspace/.devcontainer.extend/project-installs.sh"
        echo ""
        echo "  This will:"
        echo "  - Re-run installation for all enabled tools"
        echo "  - Skip tools that are already installed"
        echo "  - Install tools that previously failed due to missing config"
        echo ""
        echo "  💡 Tip: Keep running project-installs.sh until all tools are installed"
        echo "      If another config is missing, repeat the process"
        echo ""
        log_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        identity_met=false
    fi

    # Check 2: Identity has required values
    if [ "$identity_met" = true ]; then
        # shellcheck source=/dev/null
        source "$HOME/.devcontainer-identity"

        local missing_vars=()
        [ -z "${DEVELOPER_ID:-}" ] && missing_vars+=("DEVELOPER_ID")
        [ -z "${DEVELOPER_EMAIL:-}" ] && missing_vars+=("DEVELOPER_EMAIL")
        [ -z "${PROJECT_NAME:-}" ] && missing_vars+=("PROJECT_NAME")

        if [ ${#missing_vars[@]} -gt 0 ]; then
            echo ""
            log_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            log_error "❌ Identity Configuration Incomplete"
            log_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo ""
            echo "Identity file exists but missing required variables:"
            for var in "${missing_vars[@]}"; do
                echo "  ❌ $var"
            done
            echo ""
            echo "📋 To fix this:"
            echo ""
            echo "STEP 1: Reconfigure identity"
            echo "  Run: bash /workspace/.devcontainer/additions/config-devcontainer-identity.sh"
            echo ""
            echo "STEP 2: Resume installation"
            echo "  Run: bash /workspace/.devcontainer.extend/project-installs.sh"
            echo ""
            log_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            identity_met=false
        fi
    fi

    if [ "$identity_met" = false ]; then
        log_error "Installation aborted - identity configuration required"
        return 1
    fi

    log_success "Prerequisites verified: DevContainer identity configured"
    return 0
}

#------------------------------------------------------------------------------
# OTEL CONFIGURATION GENERATION
#------------------------------------------------------------------------------

# Generate OTEL collector configs from templates
generate_otel_configs() {
    echo ""
    echo "📝 Generating OTEL collector configurations from templates..."
    echo ""

    # Load nginx backend configuration
    local NGINX_CONFIG_FILE="$HOME/.nginx-backend-config"
    if [ ! -f "$NGINX_CONFIG_FILE" ]; then
        log_error "Nginx backend config not found: $NGINX_CONFIG_FILE"
        log_error "Run: bash /workspace/.devcontainer/additions/config-nginx.sh"
        return 1
    fi

    # shellcheck source=/dev/null
    source "$NGINX_CONFIG_FILE"

    if [ -z "${NGINX_OTEL_PORT:-}" ]; then
        log_error "NGINX_OTEL_PORT not set in $NGINX_CONFIG_FILE"
        return 1
    fi

    local OTEL_DIR="/workspace/.devcontainer/additions/otel"

    # Generate lifecycle config
    if [ -f "$OTEL_DIR/otelcol-lifecycle-config.yaml.template" ]; then
        sed "s|NGINX_OTEL_PORT|${NGINX_OTEL_PORT}|g" \
            "$OTEL_DIR/otelcol-lifecycle-config.yaml.template" > \
            "$OTEL_DIR/otelcol-lifecycle-config.yaml"
        log_success "Generated otelcol-lifecycle-config.yaml (port: $NGINX_OTEL_PORT)"
    else
        log_warning "Template not found: otelcol-lifecycle-config.yaml.template"
    fi

    # Generate metrics config
    if [ -f "$OTEL_DIR/otelcol-metrics-config.yaml.template" ]; then
        sed "s|NGINX_OTEL_PORT|${NGINX_OTEL_PORT}|g" \
            "$OTEL_DIR/otelcol-metrics-config.yaml.template" > \
            "$OTEL_DIR/otelcol-metrics-config.yaml"
        log_success "Generated otelcol-metrics-config.yaml (port: $NGINX_OTEL_PORT)"
    else
        log_warning "Template not found: otelcol-metrics-config.yaml.template"
    fi

    echo ""
    log_success "OTEL configs generated - routing through nginx on port $NGINX_OTEL_PORT"
    return 0
}

#------------------------------------------------------------------------------
# SUPERVISOR CONFIGURATION
#------------------------------------------------------------------------------

# Generate supervisord configuration for OTel services
generate_supervisor_configs() {
    echo ""
    echo "📝 Generating supervisord configuration for OTel services..."
    echo ""

    # Load identity file to get environment variables
    # Note: check_identity() already validated this exists and has correct values
    IDENTITY_FILE="$HOME/.devcontainer-identity"
    # shellcheck source=/dev/null
    source "$IDENTITY_FILE"

    # Set default for TS_HOSTNAME if not present (optional variable)
    TS_HOSTNAME="${TS_HOSTNAME:-unknown}"

    # Config paths
    local supervisor_conf_dir="/etc/supervisor/conf.d"
    local script_exporter_conf="${supervisor_conf_dir}/otel-script-exporter.conf"
    local lifecycle_conf="${supervisor_conf_dir}/otel-lifecycle.conf"
    local metrics_conf="${supervisor_conf_dir}/otel-metrics.conf"

    # 1. Generate script-exporter config (base service, no dependencies)
    echo "   Creating: otel-script-exporter.conf"
    sudo tee "$script_exporter_conf" > /dev/null << EOF
# OpenTelemetry script_exporter Service
# Auto-generated by install-otel-monitoring.sh
# Exposes custom devcontainer metrics via Prometheus format

[program:otel-script-exporter]
command=/usr/local/bin/script_exporter --config.files=/workspace/.devcontainer/additions/otel/script-exporter-config.yaml
autostart=true
autorestart=true
priority=30
user=vscode
stdout_logfile=/var/log/supervisor/otel-script-exporter.log
stderr_logfile=/var/log/supervisor/otel-script-exporter-error.log
stdout_logfile_maxbytes=10MB
stderr_logfile_maxbytes=10MB
startsecs=5
stopwaitsecs=10
EOF

    # 2. Generate otel-lifecycle config (depends on script-exporter)
    echo "   Creating: otel-lifecycle.conf"
    sudo tee "$lifecycle_conf" > /dev/null << EOF
# OpenTelemetry Lifecycle Collector Service
# Auto-generated by install-otel-monitoring.sh
# Collects logs, events, and lifecycle telemetry

[program:otel-lifecycle]
command=/usr/bin/otelcol-contrib --config=/workspace/.devcontainer/additions/otel/otelcol-lifecycle-config.yaml
autostart=true
autorestart=true
priority=31
user=vscode
environment=DEVELOPER_ID="${DEVELOPER_ID:-}",DEVELOPER_EMAIL="${DEVELOPER_EMAIL:-}",PROJECT_NAME="${PROJECT_NAME:-}",TS_HOSTNAME="${TS_HOSTNAME}"
stdout_logfile=/var/log/supervisor/otel-lifecycle.log
stderr_logfile=/var/log/supervisor/otel-lifecycle-error.log
stdout_logfile_maxbytes=10MB
stderr_logfile_maxbytes=10MB
startsecs=5
stopwaitsecs=10
depends_on=otel-script-exporter
EOF

    # 3. Generate otel-metrics config (depends on script-exporter)
    echo "   Creating: otel-metrics.conf"
    sudo tee "$metrics_conf" > /dev/null << EOF
# OpenTelemetry Metrics Collector Service
# Auto-generated by install-otel-monitoring.sh
# Collects system metrics (CPU, memory, disk, network)

[program:otel-metrics]
command=/usr/bin/otelcol-contrib --config=/workspace/.devcontainer/additions/otel/otelcol-metrics-config.yaml
autostart=true
autorestart=true
priority=32
user=vscode
environment=DEVELOPER_ID="${DEVELOPER_ID:-}",DEVELOPER_EMAIL="${DEVELOPER_EMAIL:-}",PROJECT_NAME="${PROJECT_NAME:-}",TS_HOSTNAME="${TS_HOSTNAME}"
stdout_logfile=/var/log/supervisor/otel-metrics.log
stderr_logfile=/var/log/supervisor/otel-metrics-error.log
stdout_logfile_maxbytes=10MB
stderr_logfile_maxbytes=10MB
startsecs=5
stopwaitsecs=10
depends_on=otel-script-exporter
EOF

    echo ""
    echo "✅ Supervisord configuration generated successfully"
    echo ""
    echo "   Services configured:"
    echo "   • otel-script-exporter (priority 30) - Custom metrics exporter"
    echo "   • otel-lifecycle (priority 31) - Lifecycle & logs collector"
    echo "   • otel-metrics (priority 32) - System metrics collector"
    echo ""

    # Add to enabled services
    local enabled_services_conf="/workspace/.devcontainer.extend/enabled-services.conf"

    # Create config file if it doesn't exist
    if [ ! -f "$enabled_services_conf" ]; then
        mkdir -p "$(dirname "$enabled_services_conf")"
        cat > "$enabled_services_conf" << 'EOFCONF'
# Enabled Services for Auto-Start
# Services listed here will automatically start when the container starts
# Format: One service identifier per line (matches program name in supervisor config)
#
# Management:
#   dev-services enable <service>   - Enable a service
#   dev-services disable <service>  - Disable a service
#   dev-services list-enabled       - Show enabled services

EOFCONF
    fi

    # Add OTel services if not already present
    for service in "otel-script-exporter" "otel-lifecycle" "otel-metrics"; do
        if ! grep -q "^${service}$" "$enabled_services_conf" 2>/dev/null; then
            echo "$service" >> "$enabled_services_conf"
            echo "   ✅ Auto-enabled: $service"
        fi
    done

    echo ""
    echo "📋 Management commands:"
    echo "   dev-services status                  # Show service status"
    echo "   dev-services start                   # Start all services"
    echo "   dev-services restart otel-lifecycle  # Restart specific service"
    echo "   dev-services logs otel-metrics       # View service logs"
    echo ""
}

# Define verification commands to run after installation
VERIFY_COMMANDS=(
    "command -v otelcol-contrib >/dev/null && echo '✅ otelcol-contrib binary found in PATH' || echo '❌ otelcol-contrib not found'"
    "otelcol-contrib --version 2>&1 | head -1"
    "command -v script_exporter >/dev/null && echo '✅ script_exporter binary found in PATH' || echo '❌ script_exporter not found'"
    "script_exporter --version 2>&1 | head -1"
    "test -d '$OTEL_CONFIG_DIR' && echo '✅ Config directory exists' || echo '❌ Config directory not found'"
    "test -f '$SCRIPT_EXPORTER_CONFIG' && echo '✅ script_exporter config exists' || echo '⚠️  script_exporter config not found'"
)

# Post-installation notes
post_installation_message() {
    echo
    echo "🎉 Installation process complete for: $SCRIPT_NAME!"
    echo "Purpose: $SCRIPT_DESCRIPTION"
    echo
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📋 Next Steps:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo
    echo "1. Configure your identity (required for proper telemetry labeling):"
    echo "   bash .devcontainer/additions/config-devcontainer-identity.sh"
    echo
    echo "   This will prompt you for an identity string from your administrator"
    echo "   and configure: ~/.devcontainer-identity"
    echo
    echo "2. Start the monitoring services:"
    echo "   dev-services start"
    echo
    echo "   The services will auto-start on your next shell session."
    echo
    echo "3. Manage services:"
    echo "   dev-services status                  # Show service status"
    echo "   dev-services restart otel-lifecycle  # Restart specific service"
    echo "   dev-services logs otel-metrics       # View service logs"
    echo
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📚 Documentation:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo
    echo "• Main documentation: $OTEL_CONFIG_DIR/README-otel.md"
    echo "• Grafana dashboards: $OTEL_CONFIG_DIR/grafana/"
    echo "• Configuration files: $OTEL_CONFIG_DIR/"
    echo "• Supervisor configs: /etc/supervisor/conf.d/otel-*.conf"
    echo
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "ℹ️  Note:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo
    echo "Services are now managed by supervisord and will auto-start"
    echo "on container startup. Use 'dev-services' for all management."
    echo
}

# Post-uninstallation notes
post_uninstallation_message() {
    echo
    echo "🏁 Uninstallation process complete for: $SCRIPT_NAME!"
    echo
    echo "Additional Notes:"
    echo "1. Configuration directory preserved: $OTEL_CONFIG_DIR"
    echo "2. Identity config preserved: ~/.devcontainer-identity"
    echo "3. To remove everything:"
    echo "   rm -rf $OTEL_CONFIG_DIR"
    echo "   rm -f ~/.devcontainer-identity"
    echo "   sudo rm -f /var/log/otelcol.log"
    echo "   sudo rm -f /var/log/otelcol-metrics.log"
    echo
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

# Export mode flags
export DEBUG_MODE
export UNINSTALL_MODE
export FORCE_MODE

# Function to verify installations
verify_installations() {
    if [ ${#VERIFY_COMMANDS[@]} -gt 0 ]; then
        echo
        echo "🔍 Verifying installations..."
        for cmd in "${VERIFY_COMMANDS[@]}"; do
            eval "$cmd"
        done
    fi
}

# Main execution
if [ "${UNINSTALL_MODE}" -eq 1 ]; then
    echo "🔄 Starting uninstallation process for: $SCRIPT_NAME"
    echo "Purpose: $SCRIPT_DESCRIPTION"
    pre_installation_setup
    remove_supervisor_configs
    uninstall_script_exporter
    uninstall_otel_collector
    post_uninstallation_message
else
    echo "🔄 Starting installation process for: $SCRIPT_NAME"
    echo "Purpose: $SCRIPT_DESCRIPTION"
    pre_installation_setup
    install_otel_collector || exit 1
    install_script_exporter || exit 1
    verify_installations

    # Check prerequisites before generating configs
    check_identity || exit 1

    # Generate OTEL collector configs from templates (with nginx port)
    generate_otel_configs || exit 1

    # Generate supervisord configuration for the services
    generate_supervisor_configs

    post_installation_message

    # Auto-enable for container rebuild
    auto_enable_tool "otel-collector" "OTel Collector"
fi
