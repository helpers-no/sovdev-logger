#!/bin/bash
# File: .devcontainer/additions/install-supervisor.sh
# Purpose: Install and configure supervisord for devcontainer service management
# Usage: bash install-supervisor.sh [--uninstall]

#------------------------------------------------------------------------------
# CONFIGURATION - Metadata for dev-setup.sh discovery
#------------------------------------------------------------------------------

SCRIPT_NAME="Supervisord"
SCRIPT_DESCRIPTION="Process supervisor for auto-starting and managing services"
SCRIPT_CATEGORY="INFRA_CONFIG"
CHECK_INSTALLED_COMMAND="[ -f /usr/bin/supervisord ] || command -v supervisord >/dev/null 2>&1"

#------------------------------------------------------------------------------

set -e

# Source auto-enable library
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/tool-auto-enable.sh"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

# Paths
SUPERVISOR_CONFIG_DIR="/etc/supervisor"
SUPERVISOR_CONF_D="/etc/supervisor/conf.d"
LOG_DIR="/var/log/supervisor"

#------------------------------------------------------------------------------
# Installation
#------------------------------------------------------------------------------

install_supervisor() {
    log_info "Installing supervisord..."

    # Install supervisor
    sudo apt-get update -qq
    sudo apt-get install -y supervisor

    # Create directories
    sudo mkdir -p "$SUPERVISOR_CONF_D"
    sudo mkdir -p "$LOG_DIR"

    # Set permissions
    sudo chown -R vscode:vscode "$LOG_DIR"

    log_success "Supervisord installed"
}

configure_supervisor() {
    log_info "Configuring supervisord..."

    # Main supervisord config
    sudo tee "$SUPERVISOR_CONFIG_DIR/supervisord.conf" > /dev/null << 'EOF'
[unix_http_server]
file=/var/run/supervisor.sock
chmod=0700
chown=vscode:vscode

[supervisord]
logfile=/var/log/supervisor/supervisord.log
pidfile=/var/run/supervisord.pid
childlogdir=/var/log/supervisor
nodaemon=false

[rpcinterface:supervisor]
supervisor.rpcinterface_factory = supervisor.rpcinterface:make_main_rpcinterface

[supervisorctl]
serverurl=unix:///var/run/supervisor.sock

[include]
files = /etc/supervisor/conf.d/*.conf
EOF

    log_success "Supervisord configured"
}

setup_autostart() {
    log_info "Setting up supervisord autostart..."

    # Create systemd-style service file for supervisord
    sudo tee /etc/init.d/supervisord > /dev/null << 'EOF'
#!/bin/bash
### BEGIN INIT INFO
# Provides:          supervisord
# Required-Start:    $remote_fs $syslog
# Required-Stop:     $remote_fs $syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Start supervisord at boot
### END INIT INFO

case "$1" in
    start)
        echo "Starting supervisord..."
        /usr/bin/supervisord -c /etc/supervisor/supervisord.conf
        ;;
    stop)
        echo "Stopping supervisord..."
        /usr/bin/supervisorctl shutdown
        ;;
    restart)
        $0 stop
        sleep 2
        $0 start
        ;;
    status)
        /usr/bin/supervisorctl status
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status}"
        exit 1
        ;;
esac
EOF

    sudo chmod +x /etc/init.d/supervisord

    # Add to bashrc to start on container start
    if ! grep -q "supervisord autostart" ~/.bashrc; then
        cat >> ~/.bashrc << 'EOF'

# Auto-start supervisord on container start
if ! pgrep -x supervisord > /dev/null; then
    sudo /etc/init.d/supervisord start > /dev/null 2>&1
fi
EOF
    fi

    log_success "Autostart configured"
}

create_management_commands() {
    log_info "Creating management commands..."

    # Create dev-services command
    sudo tee /usr/local/bin/dev-services > /dev/null << 'EOF'
#!/bin/bash
# Simple wrapper for supervisorctl and service management

ENABLED_CONF="/workspace/.devcontainer.extend/enabled-services.conf"
AUTO_ENABLE_LIB="/workspace/.devcontainer/additions/lib/service-auto-enable.sh"

case "$1" in
    status|start|stop|restart)
        sudo supervisorctl "$@"
        ;;
    logs)
        if [ -n "$2" ]; then
            sudo tail -f "/var/log/supervisor/${2}.log"
        else
            echo "Usage: dev-services logs <service-name>"
        fi
        ;;
    enable)
        if [ -n "$2" ]; then
            # Source auto-enable library and enable service
            # shellcheck source=/dev/null
            source "$AUTO_ENABLE_LIB"
            enable_service_autostart "$2" "$2"
            regenerate_supervisor_config
        else
            echo "Usage: dev-services enable <service-name>"
        fi
        ;;
    disable)
        if [ -n "$2" ]; then
            # Source auto-enable library and disable service
            # shellcheck source=/dev/null
            source "$AUTO_ENABLE_LIB"
            disable_service_autostart "$2"
        else
            echo "Usage: dev-services disable <service-name>"
        fi
        ;;
    list-enabled)
        # Source auto-enable library and list enabled services
        # shellcheck source=/dev/null
        source "$AUTO_ENABLE_LIB"
        list_enabled_services
        ;;
    *)
        echo "Development Services Management"
        echo ""
        echo "Usage: dev-services <command> [args]"
        echo ""
        echo "Commands:"
        echo "  status              Show status of all services"
        echo "  start <service>     Start a service"
        echo "  stop <service>      Stop a service"
        echo "  restart <service>   Restart a service"
        echo "  logs <service>      Tail service logs"
        echo ""
        echo "  enable <service>    Enable service for auto-start"
        echo "  disable <service>   Disable service auto-start"
        echo "  list-enabled        List enabled services"
        echo ""
        echo "Examples:"
        echo "  dev-services status"
        echo "  dev-services restart tailscale"
        echo "  dev-services logs otel-monitoring"
        echo "  dev-services enable otel-monitoring"
        echo "  dev-services list-enabled"
        ;;
esac
EOF

    sudo chmod +x /usr/local/bin/dev-services

    log_success "Created 'dev-services' command"
}

#------------------------------------------------------------------------------
# Uninstallation
#------------------------------------------------------------------------------

uninstall_supervisor() {
    log_warn "Uninstalling supervisord..."

    # Stop supervisord
    sudo supervisorctl shutdown 2>/dev/null || true

    # Remove packages
    sudo apt-get remove -y supervisor
    sudo apt-get autoremove -y

    # Remove configs
    sudo rm -rf "$SUPERVISOR_CONFIG_DIR"
    sudo rm -rf "$LOG_DIR"
    sudo rm -f /etc/init.d/supervisord
    sudo rm -f /usr/local/bin/dev-services

    # Remove from bashrc
    sed -i '/# Auto-start supervisord/,+3d' ~/.bashrc

    log_success "Supervisord uninstalled"
}

#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------

main() {
    if [ "$1" = "--uninstall" ]; then
        uninstall_supervisor
        exit 0
    fi

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📦 Installing Supervisord Service Manager"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    install_supervisor
    configure_supervisor
    setup_autostart
    create_management_commands

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "✅ Supervisord Installation Complete"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "📋 Next Steps:"
    echo "   1. Run: bash .devcontainer/additions/config-supervisor.sh"
    echo "   2. Services will auto-start on container restart"
    echo ""
    echo "🔧 Management:"
    echo "   dev-services status          # Show all services"
    echo "   dev-services restart <name>  # Restart a service"
    echo "   dev-services logs <name>     # View service logs"
    echo ""

    # Auto-enable for container rebuild
    auto_enable_tool "supervisord" "Supervisord"
}

main "$@"
