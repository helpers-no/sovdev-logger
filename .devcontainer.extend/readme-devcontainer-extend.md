# DevContainer Extension System

This directory contains project-specific extensions and configuration for the DevContainer Toolbox.

## Overview

The `.devcontainer.extend` directory allows you to customize your devcontainer without modifying the base configuration. This ensures your project-specific setup is preserved while the base devcontainer remains reusable across projects.

## Directory Structure

```
.devcontainer.extend/
├── README-devcontainer-extend.md   # This file
├── enabled-tools.conf              # Auto-install tool configuration
├── project-installs.sh             # Custom installation script
└── README-supervisor.md            # Supervisor configuration guide
```

## Auto-Enable Tool System

### What is enabled-tools.conf?

The `enabled-tools.conf` file is a declarative configuration that lists which development tools should automatically install when the container is created or rebuilt.

**Example:**
```bash
# Enabled Tools for Auto-Install
supervisord
rust-development-tools
go-runtime-&-development-tools
java-runtime-&-development-tools
```

### How It Works

1. **Installation**: When you run an install script from `.devcontainer/additions/`, it automatically adds itself to `enabled-tools.conf`
2. **Container Rebuild**: When the container rebuilds, the `dev-setup.sh` script reads `enabled-tools.conf` and automatically reinstalls all listed tools
3. **Persistence**: Your development environment is automatically restored across container rebuilds

### Available Tools

**Language Development:**
- `rust-development-tools` - Rust compiler, Cargo, and VS Code extensions
- `go-runtime-&-development-tools` - Go runtime, gopls, dlv, staticcheck
- `java-runtime-&-development-tools` - Java JDK, Maven, Gradle
- `python-development-tools` - Python, pip, development libraries
- `c#-development-tools` - .NET SDK, C# tools
- `typescript-development-tools` - TypeScript, Node.js tools
- `php-development-tools` - PHP runtime and extensions
- `php-laravel-development-tools` - Laravel framework and tools

**Infrastructure & DevOps:**
- `supervisord` - Process manager for background services
- `otel-monitoring` - OpenTelemetry monitoring stack
- `kubectl` - Kubernetes command-line tool
- `powershell` - PowerShell for cross-platform scripting

**AI Assistants:**
- `claude-code` - Claude Code AI assistant
- `cline` - Cline AI coding assistant
- `opencode` - OpenCode AI assistant

**Configuration & Analytics:**
- `configuration-tools` - Bicep, Ansible, IaC tools
- `data-analytics-tools` - Data analysis and visualization tools

### Managing Tools

#### Add a Tool

**Option 1: Run the install script** (Recommended)
```bash
# The script automatically adds itself to enabled-tools.conf
bash .devcontainer/additions/install-dev-rust.sh
```

**Option 2: Manual addition**
```bash
# Edit enabled-tools.conf and add the tool identifier
echo "rust-development-tools" >> .devcontainer.extend/enabled-tools.conf
```

#### Remove a Tool

**Option 1: Uninstall with script**
```bash
bash .devcontainer/additions/install-dev-rust.sh --uninstall
```

**Option 2: Manual removal**
```bash
# Edit enabled-tools.conf and remove or comment out the tool line
sed -i '/rust-development-tools/d' .devcontainer.extend/enabled-tools.conf
```

#### View Enabled Tools
```bash
cat .devcontainer.extend/enabled-tools.conf | grep -v "^#" | grep -v "^$"
```

### Interactive Menu

Use the interactive development setup menu to manage tools:
```bash
bash .devcontainer/dev-setup.sh
```

This menu shows:
- ✅ Green checkmark = Tool is installed
- ❌ Red X = Tool is not installed
- Options to install, uninstall, or configure tools

## Custom Installation Script

The `project-installs.sh` script runs automatically during container creation. Use it for project-specific setup that isn't covered by the standard install scripts.

**Example:**
```bash
#!/bin/bash
# Install project-specific dependencies

# Install a specific Node.js version
nvm install 18.20.0
nvm use 18.20.0

# Install global npm packages
npm install -g pnpm typescript

# Clone project repositories
# git clone https://github.com/org/repo.git /workspace/repo

echo "✅ Project-specific setup complete"
```

## How Install Scripts Work

All install scripts in `.devcontainer/additions/` follow a standard pattern:

1. **Metadata Declaration**: Each script declares its name and installation check
2. **Auto-Enable Integration**: Sources the auto-enable library
3. **Installation Logic**: Installs packages, tools, VS Code extensions
4. **Auto-Registration**: Calls `auto_enable_tool()` on success

**Script Capabilities:**
- `--debug` - Enable verbose output
- `--uninstall` - Remove installed components
- `--force` - Force installation/uninstallation
- `--version X` - Install specific version (where supported)

## Best Practices

### ✅ Do:
- Use the auto-enable system for standard tools
- Run install scripts to automatically register tools
- Use `project-installs.sh` for project-specific setup
- Document any custom dependencies in comments
- Test your setup after container rebuild

### ❌ Don't:
- Edit `.devcontainer/devcontainer.json` directly (extend instead)
- Manually modify `enabled-tools.conf` unless necessary
- Install tools outside the standard scripts without documentation
- Commit sensitive credentials or API keys

## Architecture

### Auto-Enable System Components

```
.devcontainer/
├── dev-setup.sh                    # Interactive menu + auto-install on rebuild
├── additions/
│   ├── lib/
│   │   └── tool-auto-enable.sh     # Auto-enable library
│   ├── install-*.sh                # 17 install scripts with auto-enable
│   └── _template-install-script.sh # Template for new scripts
│
└── .devcontainer.extend/
    └── enabled-tools.conf          # Lists enabled tools
```

### Installation Flow

1. User runs: `bash .devcontainer/additions/install-dev-rust.sh`
2. Script installs Rust (rustc, cargo, clippy, rustfmt)
3. Script calls: `auto_enable_tool "rust-development-tools" "Rust Development Tools"`
4. Library adds entry to `enabled-tools.conf` (if not already present)
5. Script completes with success message

### Container Rebuild Flow

1. Container starts/rebuilds
2. User runs: `bash .devcontainer/dev-setup.sh` (or it runs automatically)
3. Script reads `enabled-tools.conf`
4. For each enabled tool:
   - Check if already installed (via CHECK_INSTALLED_COMMAND)
   - If not installed, run corresponding install script
   - Show progress and status
5. All enabled tools are restored

## Troubleshooting

### Tool shows as not installed after installation
**Cause**: Shell PATH not updated in current session

**Solution**: Reload your shell or source bashrc
```bash
source ~/.bashrc
# or
exec bash
```

### Tool doesn't auto-install on rebuild
**Cause**: Not listed in enabled-tools.conf

**Solution**: Run the install script again to register it
```bash
bash .devcontainer/additions/install-dev-rust.sh
```

### Installation script fails
**Cause**: Missing dependencies or network issues

**Solution**: Run with --debug flag to see detailed output
```bash
bash .devcontainer/additions/install-dev-rust.sh --debug
```

### Need to install specific version
**Cause**: Default version doesn't match requirements

**Solution**: Use --version flag (where supported)
```bash
bash .devcontainer/additions/install-dev-golang.sh --version 1.21.0
bash .devcontainer/additions/install-dev-java.sh --version 17
```

## Examples

### Example 1: Setting up a Go project
```bash
# Install Go development tools
bash .devcontainer/additions/install-dev-golang.sh --version 1.21.0

# Verify installation
go version

# Tool is now in enabled-tools.conf and will persist across rebuilds
```

### Example 2: Setting up a full-stack TypeScript project
```bash
# Install TypeScript/Node.js
bash .devcontainer/additions/install-dev-typescript.sh

# Install PostgreSQL client tools
bash .devcontainer/additions/install-data-analytics.sh

# Install supervisor for background processes
bash .devcontainer/additions/install-supervisor.sh

# All three tools now auto-install on rebuild
```

### Example 3: Custom project setup in project-installs.sh
```bash
#!/bin/bash
# File: .devcontainer.extend/project-installs.sh

# Let auto-enable system handle standard tools via enabled-tools.conf
# This script is for project-specific setup only

# Install project dependencies
cd /workspace
npm install

# Setup database
./scripts/db-setup.sh

# Generate API client
./scripts/generate-client.sh

echo "✅ Project setup complete"
```

## Additional Documentation

- **Install Scripts**: See `.devcontainer/additions/README-additions.md` for detailed guide
- **Supervisor Setup**: See `.devcontainer.extend/README-supervisor.md` for process manager configuration
- **OTel Monitoring**: See `.devcontainer/additions/otel/README-otel.md` for monitoring setup
- **Template Script**: See `.devcontainer/additions/_template-install-script.sh` for creating new install scripts

## Contributing

When creating new install scripts:

1. Copy `.devcontainer/additions/_template-install-script.sh`
2. Update metadata (SCRIPT_NAME, SCRIPT_DESCRIPTION, CHECK_INSTALLED_COMMAND)
3. Implement installation logic
4. Test with `--debug`, `--uninstall`, and normal installation
5. Verify auto-enable functionality works
6. Document in README-additions.md

## Summary

The auto-enable system provides:
- ✅ **Declarative Configuration**: enabled-tools.conf lists what to install
- ✅ **Automatic Persistence**: Tools auto-reinstall on container rebuild
- ✅ **Self-Registration**: Install scripts automatically add themselves
- ✅ **Immediate Detection**: Tools show as installed right away
- ✅ **17/18 Scripts**: 94% coverage across language and infrastructure tools
- ✅ **Interactive Management**: dev-setup.sh provides user-friendly menu

This system ensures consistent, reproducible development environments across team members and container rebuilds.
