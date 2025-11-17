# Devcontainer Additions System

This folder contains a modular system for installing tools, configuring settings, and managing services in your devcontainer. The system uses automatic script discovery and provides a unified menu interface for easy management.

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Script Types](#script-types)
- [Using the Menu System](#using-the-menu-system)
- [Script Discovery and Metadata](#script-discovery-and-metadata)
- [Creating New Scripts](#creating-new-scripts)
- [Project Integration](#project-integration)
- [Directory Structure](#directory-structure)

---

## Overview

The additions system provides:

- **Automatic Script Discovery**: Scripts are automatically detected and listed in the menu based on metadata
- **Three Script Types**: Install components, configure settings, manage services
- **Status Indicators**: Visual status (✓/✗) shows what's installed, configured, or running
- **Category Organization**: Scripts are organized by category (DEV_TOOLS, INFRA_CONFIG, AI_TOOLS, etc.)
- **Menu Interface**: Interactive menu via `dev-setup.sh` for easy management
- **Project Integration**: Easily add scripts to your project's automated setup

---

## Quick Start

### Using the Interactive Menu

The easiest way to manage additions is through the interactive menu:

```bash
bash /workspace/.devcontainer/dev-setup.sh
```

This displays all available components, configurations, and services with their current status.

### Running Scripts Directly

You can also run scripts directly from the command line:

```bash
# Install a component
bash .devcontainer/additions/install-dev-python.sh

# Configure a setting
bash .devcontainer/additions/config-devcontainer-identity.sh

# Start a service
bash .devcontainer/additions/start-otel-monitoring.sh

# Stop a service
bash .devcontainer/additions/stop-otel-monitoring.sh
```

---

## Script Types

The additions system supports three types of scripts, each with specific naming conventions and purposes:

### 1. Install Scripts (`install-*.sh`)

Install components, tools, or dependencies.

**Naming Pattern**: `install-<component-name>.sh`

**Examples**:
- `install-dev-python.sh` - Python development tools
- `install-dev-golang.sh` - Go development environment
- `install-kubectl.sh` - Kubernetes CLI tools
- `install-otel-monitoring.sh` - OpenTelemetry monitoring

**Key Features**:
- Idempotent (safe to run multiple times)
- Status check command to detect if already installed
- Optional uninstall support via `--uninstall` flag
- Category-based organization

**Required Metadata**:
```bash
SCRIPT_NAME="Human-readable component name"
SCRIPT_DESCRIPTION="Brief description of what this installs"
SCRIPT_CATEGORY="DEV_TOOLS"  # or INFRA_CONFIG, AI_TOOLS, etc.
CHECK_INSTALLED_COMMAND="command -v python3 >/dev/null 2>&1"
```

### 2. Configuration Scripts (`config-*.sh`)

Configure settings, credentials, or environment variables.

**Naming Pattern**: `config-<setting-name>.sh`

**Examples**:
- `config-devcontainer-identity.sh` - Developer identity for monitoring

**Key Features**:
- Interactive configuration prompts
- Status check to detect if already configured
- Validation and verification
- Reconfiguration support

**Required Metadata**:
```bash
CONFIG_NAME="Human-readable configuration name"
CONFIG_DESCRIPTION="Brief description of what this configures"
CONFIG_CATEGORY="INFRA_CONFIG"  # or USER_CONFIG, etc.
CHECK_CONFIGURED_COMMAND="[ -f ~/.devcontainer-identity ] && grep -q '^export DEVELOPER_ID=' ~/.devcontainer-identity"
```

### 3. Service Scripts (`start-*.sh` and `stop-*.sh`)

Start and stop background services or daemons.

**Naming Pattern**: `start-<service-name>.sh` and `stop-<service-name>.sh`

**Examples**:
- `start-otel-monitoring.sh` / `stop-otel-monitoring.sh` - OpenTelemetry monitoring services

**Key Features**:
- Paired start/stop scripts
- Status check to detect if service is running
- Graceful shutdown support
- Service lifecycle management

**Required Metadata** (in `start-*.sh`):
```bash
SERVICE_NAME="Human-readable service name"
SERVICE_DESCRIPTION="Brief description of what this service does"
SERVICE_CATEGORY="INFRA_CONFIG"  # or MONITORING, DATABASE, etc.
CHECK_RUNNING_COMMAND="pgrep -f 'otelcol-contrib.*config' >/dev/null 2>&1"
```

**Optional Metadata** (in `stop-*.sh`):
```bash
SERVICE_NAME="Human-readable service name"
SERVICE_DESCRIPTION="Brief description"
SERVICE_CATEGORY="INFRA_CONFIG"
```

---

## Using the Menu System

The menu system (`dev-setup.sh`) provides an interactive interface for managing all additions.

### Menu Features

- **Automatic Discovery**: All scripts with proper metadata are automatically detected
- **Status Indicators**:
  - `✓` (green checkmark) - Component installed / Config completed / Service running
  - `✗` (red X) - Component not installed / Config not completed / Service not running
- **Category Organization**: Scripts grouped by category
- **One-click Execution**: Select and run scripts directly from the menu

### Status Checks

The menu system uses the check commands defined in each script's metadata:

```bash
# For install scripts
CHECK_INSTALLED_COMMAND="command -v python3 >/dev/null 2>&1"

# For config scripts
CHECK_CONFIGURED_COMMAND="[ -f ~/.config-file ]"

# For service scripts
CHECK_RUNNING_COMMAND="pgrep -f 'service-name' >/dev/null 2>&1"
```

These commands are evaluated by the component scanner library to determine status.

---

## Script Discovery and Metadata

### Component Scanner Library

The additions system uses a shared library for script discovery:

**Location**: `.devcontainer/additions/lib/component-scanner.sh` (v1.1.0)

**Key Functions**:
- `scan_install_scripts()` - Find and extract metadata from install scripts
- `scan_config_scripts()` - Find and extract metadata from config scripts
- `scan_service_scripts()` - Find and extract metadata from service scripts
- `check_component_installed()` - Execute status check commands
- `check_config_configured()` - Verify configuration status
- `extract_*_metadata()` - Extract individual metadata fields

### Metadata Format

All metadata must be defined at the top of each script (within the first ~50 lines) using this exact format:

```bash
#!/bin/bash
# file: .devcontainer/additions/install-example.sh
#
# DESCRIPTION: Brief description
# PURPOSE: Detailed purpose
#
# Usage: ./install-example.sh
#
#------------------------------------------------------------------------------
# SCRIPT METADATA - For dev-setup.sh menu discovery
#------------------------------------------------------------------------------

SCRIPT_NAME="Example Component"
SCRIPT_DESCRIPTION="Install example component with all dependencies"
SCRIPT_CATEGORY="DEV_TOOLS"
CHECK_INSTALLED_COMMAND="command -v example >/dev/null 2>&1"

#------------------------------------------------------------------------------

# Rest of script...
```

### Category Naming

Use consistent category names across scripts:

**Common Categories**:
- `DEV_TOOLS` - Development tools and language runtimes
- `INFRA_CONFIG` - Infrastructure and configuration
- `AI_TOOLS` - AI coding assistants and tools
- `MONITORING` - Monitoring and observability
- `DATABASE` - Database tools and clients
- `CLOUD` - Cloud provider CLI tools

You can define custom categories as needed.

### Check Command Guidelines

Check commands should:
- Return exit code `0` if installed/configured/running
- Return exit code `1` if not installed/configured/running
- Suppress all output (`>/dev/null 2>&1`)
- Be fast (run in < 1 second)
- Be idempotent (safe to run repeatedly)

**Good Examples**:
```bash
# Check if command exists
CHECK_INSTALLED_COMMAND="command -v python3 >/dev/null 2>&1"

# Check if file exists and contains content
CHECK_CONFIGURED_COMMAND="[ -f ~/.config ] && grep -q 'key=value' ~/.config"

# Check if process is running
CHECK_RUNNING_COMMAND="pgrep -f 'service-name' >/dev/null 2>&1"

# Check if package is installed (Debian/Ubuntu)
CHECK_INSTALLED_COMMAND="dpkg -l package-name 2>/dev/null | grep -q '^ii'"

# Check if directory exists
CHECK_INSTALLED_COMMAND="[ -d /opt/tool ]"

# Complex check with multiple conditions
CHECK_INSTALLED_COMMAND="[ -f /usr/bin/tool ] && tool --version >/dev/null 2>&1"
```

**Bad Examples**:
```bash
# Don't use variable substitution (not evaluated at scan time)
CHECK_INSTALLED_COMMAND="command -v $TOOL_NAME >/dev/null 2>&1"  # WRONG

# Don't output text (breaks menu display)
CHECK_INSTALLED_COMMAND="echo 'Checking...'; command -v python3"  # WRONG

# Don't use slow commands (delays menu)
CHECK_INSTALLED_COMMAND="apt-cache policy python3 | grep Installed"  # TOO SLOW
```

---

## Creating New Scripts

### Using Templates

Templates are provided for each script type:

- `_template-install-script.sh` - Template for install scripts
- `_template-config-script.sh` - Template for config scripts

**Steps to Create a New Script**:

1. **Copy the appropriate template**:
   ```bash
   cp .devcontainer/additions/_template-install-script.sh \
      .devcontainer/additions/install-my-tool.sh
   ```

2. **Update the metadata section**:
   - Change `SCRIPT_NAME` to your component name
   - Update `SCRIPT_DESCRIPTION` with a brief description
   - Set appropriate `SCRIPT_CATEGORY`
   - Define `CHECK_INSTALLED_COMMAND` to detect installation

3. **Implement the installation logic**:
   - Add your installation commands
   - Ensure idempotency (safe to run multiple times)
   - Add error handling
   - Provide user feedback

4. **Test the script**:
   ```bash
   # Test installation
   bash .devcontainer/additions/install-my-tool.sh

   # Verify it appears in menu with correct status
   bash /workspace/.devcontainer/dev-setup.sh

   # Test idempotency (run again)
   bash .devcontainer/additions/install-my-tool.sh
   ```

### Example: Simple Install Script

```bash
#!/bin/bash
# file: .devcontainer/additions/install-dev-nodejs.sh
#
# DESCRIPTION: Install Node.js development environment
# PURPOSE: Install Node.js, npm, and common global packages
#
# Usage: bash .devcontainer/additions/install-dev-nodejs.sh
#
#------------------------------------------------------------------------------
# SCRIPT METADATA - For dev-setup.sh menu discovery
#------------------------------------------------------------------------------

SCRIPT_NAME="Node.js Development"
SCRIPT_DESCRIPTION="Install Node.js runtime, npm, and essential tools"
SCRIPT_CATEGORY="DEV_TOOLS"
CHECK_INSTALLED_COMMAND="command -v node >/dev/null 2>&1"

#------------------------------------------------------------------------------

set -euo pipefail

main() {
    echo "Installing Node.js..."

    # Check if already installed
    if eval "$CHECK_INSTALLED_COMMAND"; then
        echo "✓ Node.js already installed"
        node --version
        return 0
    fi

    # Install Node.js
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt-get install -y nodejs

    # Install global packages
    npm install -g typescript eslint prettier

    echo "✓ Node.js installation complete"
    node --version
    npm --version
}

main "$@"
```

### Example: Configuration Script

```bash
#!/bin/bash
# file: .devcontainer/additions/config-git-user.sh
#
# DESCRIPTION: Configure Git user identity
# PURPOSE: Set up Git username and email for commits
#
# Usage: bash .devcontainer/additions/config-git-user.sh
#
#------------------------------------------------------------------------------
# CONFIG METADATA - For dev-setup.sh menu discovery
#------------------------------------------------------------------------------

CONFIG_NAME="Git User Identity"
CONFIG_DESCRIPTION="Configure your Git username and email"
CONFIG_CATEGORY="USER_CONFIG"
CHECK_CONFIGURED_COMMAND="git config --global user.name >/dev/null 2>&1 && git config --global user.email >/dev/null 2>&1"

#------------------------------------------------------------------------------

set -euo pipefail

main() {
    echo "Git User Configuration"
    echo "====================="
    echo ""

    # Check if already configured
    if eval "$CHECK_CONFIGURED_COMMAND"; then
        echo "Current Git configuration:"
        echo "  Name:  $(git config --global user.name)"
        echo "  Email: $(git config --global user.email)"
        echo ""
        read -p "Reconfigure? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 0
        fi
    fi

    # Prompt for user information
    read -p "Enter your name: " name
    read -p "Enter your email: " email

    # Configure Git
    git config --global user.name "$name"
    git config --global user.email "$email"

    echo ""
    echo "✓ Git user identity configured"
    echo "  Name:  $(git config --global user.name)"
    echo "  Email: $(git config --global user.email)"
}

main "$@"
```

---

## Project Integration

### Adding to Project-Specific Setup

To ensure team members have the same tools installed, add scripts to your project's automated setup:

**File**: `.devcontainer.extend/project-installs.sh`

```bash
#!/bin/bash
# Project-specific installations
# This script runs automatically when the container is rebuilt

set -euo pipefail

echo "Installing project dependencies..."

# Install required development tools
bash .devcontainer/additions/install-dev-python.sh
bash .devcontainer/additions/install-dev-typescript.sh

# Install project-specific tools
bash .devcontainer/additions/install-kubectl.sh

# Configure monitoring (optional)
if [ -f ~/.devcontainer-identity ]; then
    bash .devcontainer/additions/start-otel-monitoring.sh
fi

echo "✓ Project dependencies installed"
```

**Benefits**:
- New team members get a consistent development environment
- Reduces onboarding time
- Documents project dependencies as code
- Runs automatically on container rebuild

**See Also**: [.devcontainer.extend/readme-devcontainer-extend.md](../../.devcontainer.extend/readme-devcontainer-extend.md)

---

## Directory Structure

```
.devcontainer/additions/
│
├── README-additions.md              # This file
│
├── lib/                             # Shared libraries
│   └── component-scanner.sh         # Script discovery library (v1.1.0)
│
├── _template-install-script.sh      # Template for install scripts
├── _template-config-script.sh       # Template for config scripts
│
├── install-*.sh                     # Install scripts (components/tools)
│   ├── install-dev-python.sh
│   ├── install-dev-golang.sh
│   ├── install-kubectl.sh
│   └── install-otel-monitoring.sh
│
├── config-*.sh                      # Configuration scripts
│   └── config-devcontainer-identity.sh
│
├── start-*.sh / stop-*.sh           # Service management scripts
│   ├── start-otel-monitoring.sh
│   └── stop-otel-monitoring.sh
│
└── otel/                            # OTel monitoring system
    ├── README-otel.md               # OTel-specific documentation
    ├── otelcol-config.yaml          # OTel collector configuration
    ├── otelcol-metrics-config.yaml  # Metrics collector configuration
    ├── script-exporter-config.yaml  # Script exporter configuration
    │
    ├── adm/                         # Admin tools (not visible in menu)
    │   └── generate-devcontainer-identity.sh
    │
    └── scripts/                     # OTel helper scripts
        └── send-event-notification.sh
```

---

## Best Practices

### Script Development

1. **Use Templates**: Start with the provided templates for consistency
2. **Add Metadata**: Always include complete metadata for menu discovery
3. **Test Check Commands**: Verify check commands work correctly before and after installation
4. **Handle Errors**: Use `set -euo pipefail` and provide clear error messages
5. **Be Idempotent**: Scripts should be safe to run multiple times
6. **Provide Feedback**: Use clear output messages for user feedback
7. **Document Usage**: Include usage examples in script header comments

### Naming Conventions

1. **Install Scripts**: `install-<category>-<name>.sh`
   - Examples: `install-dev-python.sh`, `install-cloud-aws-cli.sh`
2. **Config Scripts**: `config-<setting>.sh`
   - Examples: `config-git-user.sh`, `config-devcontainer-identity.sh`
3. **Service Scripts**: `start-<service>.sh` / `stop-<service>.sh`
   - Examples: `start-otel-monitoring.sh`, `stop-database.sh`

### Metadata Guidelines

1. **Keep Names Concise**: 2-4 words maximum for SCRIPT_NAME
2. **Write Clear Descriptions**: One sentence explaining what the script does
3. **Use Standard Categories**: Stick to common category names for consistency
4. **Test Check Commands**: Verify they work in different states (installed/not installed)

---

## Troubleshooting

### Script Not Appearing in Menu

**Possible Causes**:
1. Missing or incorrect metadata fields
2. Script doesn't match naming pattern (`install-*.sh`, `config-*.sh`, `start-*.sh`)
3. Metadata not in first ~50 lines of script
4. Template file (contains `_template` in name)

**Solution**:
- Verify all required metadata fields are present
- Check exact spelling: `SCRIPT_NAME=` (not `SCRIPTNAME=` or `script_name=`)
- Move metadata section to top of file
- Ensure script name matches pattern

### Status Indicator Shows Wrong State

**Possible Causes**:
1. Check command doesn't accurately reflect state
2. Check command has syntax errors
3. Check command is too slow or hangs

**Solution**:
- Test check command manually: `eval "command -v python3 >/dev/null 2>&1" && echo "✓" || echo "✗"`
- Verify check command returns correct exit codes (0 = true, 1 = false)
- Simplify complex check commands
- Add timeout to slow commands

### Script Fails During Execution

**Possible Causes**:
1. Missing dependencies
2. Permission issues
3. Network connectivity problems
4. Incorrect paths

**Solution**:
- Check error messages carefully
- Verify prerequisites are installed
- Test commands individually
- Use absolute paths instead of relative paths

---

## Advanced Topics

### Creating Custom Categories

You can define custom categories for your organization:

```bash
# Enterprise categories
SCRIPT_CATEGORY="COMPANY_TOOLS"      # Company-specific tools
SCRIPT_CATEGORY="SECURITY_TOOLS"     # Security scanning tools
SCRIPT_CATEGORY="COMPLIANCE"         # Compliance and audit tools
```

### Uninstall Support

Add uninstall support to install scripts:

```bash
# Parse command-line arguments
UNINSTALL_MODE=0
if [ "${1:-}" = "--uninstall" ]; then
    UNINSTALL_MODE=1
fi

# Implement uninstall function
uninstall() {
    echo "Uninstalling component..."
    sudo apt-get remove -y package-name
    sudo apt-get autoremove -y
    echo "✓ Uninstall complete"
}

# Main execution
if [ $UNINSTALL_MODE -eq 1 ]; then
    uninstall
else
    install
fi
```

### Silent Mode

Support silent/non-interactive mode:

```bash
# Check for silent mode flag
SILENT_MODE=${SILENT_MODE:-0}
if [ "${1:-}" = "--silent" ]; then
    SILENT_MODE=1
fi

# Skip prompts in silent mode
if [ $SILENT_MODE -eq 0 ]; then
    read -p "Continue? (Y/n): " -n 1 -r
    echo
fi
```

---

## Related Documentation

- [OTel Monitoring System](otel/README-otel.md) - OpenTelemetry monitoring documentation
- [Devcontainer Extend](../../.devcontainer.extend/readme-devcontainer-extend.md) - Project-specific customization
- [Component Scanner Library](lib/component-scanner.sh) - Script discovery library documentation

---

## Support

For questions or issues:

1. Check script comments and inline documentation
2. Review examples in existing scripts
3. Test changes in a clean container
4. Consult related documentation above

---

**Last Updated**: 2025-11-17
**Component Scanner Version**: 1.1.0
