#!/bin/bash
################################################################################
# in-devcontainer.sh - Universal wrapper to run scripts and commands inside devcontainer
#
# Purpose:
#   1. Run specification/tools scripts inside devcontainer from host machine
#   2. Execute arbitrary commands inside devcontainer
#   Eliminates need for individual -host.sh wrapper files
#
# TWO MODES OF OPERATION:
#
# MODE 1: Run Scripts from specification/tools/ directory
#   Usage:
#     ./in-devcontainer.sh <script> [args...]
#     ./in-devcontainer.sh --help
#     ./in-devcontainer.sh --list
#
#   Examples:
#     ./in-devcontainer.sh query-loki.sh service-name --json
#     ./in-devcontainer.sh run-full-validation.sh python
#     ./in-devcontainer.sh validate-log-format.sh python/test/logs/dev.log
#
#   Shortcuts (auto-add .sh extension):
#     ./in-devcontainer.sh query-loki service-name
#     ./in-devcontainer.sh run-full-validation python
#
#   Common aliases:
#     loki           → query-loki.sh
#     prometheus     → query-prometheus.sh
#     tempo          → query-tempo.sh
#     validate       → run-full-validation.sh
#     validate-logs  → validate-log-format.sh
#
# MODE 2: Execute Arbitrary Commands (--exec or -e flag)
#   Usage:
#     ./in-devcontainer.sh --exec <command>
#     ./in-devcontainer.sh -e <command>
#
#   Examples:
#     # Simple commands
#     ./in-devcontainer.sh --exec whoami
#     ./in-devcontainer.sh -e pwd
#
#     # Complex commands (use quotes)
#     ./in-devcontainer.sh --exec "cd /workspace/typescript && npm test"
#     ./in-devcontainer.sh -e "ls -la /workspace"
#
#     # With dry-run to see what would execute
#     ./in-devcontainer.sh --dry-run --exec "cd /workspace && npm install"
#
#   Note: In exec mode, NO script resolution happens. The command runs as-is.
#         You must provide the full command exactly as you want it executed.
#
# Options:
#   --help, -h         Show this help message
#   --list, -l         List all available scripts in devcontainer
#   --dry-run          Show command without executing (works with both modes)
#   --interactive, -i  Open bash shell in tools directory
#   --exec, -e         Execute arbitrary command in container (MODE 2)
#
# Exit Codes:
#   0 - Success
#   1 - Script execution failed
#   2 - Usage error
#   3 - Container not running
#   4 - Script not found (MODE 1 only)
#
# Container Requirements:
#   - Container must be named: devcontainer-toolbox
#   - Container must be running (use: docker start devcontainer-toolbox)
#   - Container must have /workspace mounted
#
################################################################################

set -euo pipefail

# Configuration
CONTAINER_NAME="devcontainer-toolbox"
TOOLS_DIR="/workspace/specification/tools"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Flags
DRY_RUN=false
INTERACTIVE=false
EXEC_MODE=false

#------------------------------------------------------------------------------
# Helper Functions
#------------------------------------------------------------------------------

show_help() {
    cat << EOF
${BLUE}in-devcontainer.sh${NC} - Universal wrapper to run scripts and commands inside devcontainer

${YELLOW}TWO MODES OF OPERATION:${NC}

  ${GREEN}MODE 1: Run Scripts${NC} (from specification/tools/ directory)
    ./in-devcontainer.sh <script> [args...]

  ${GREEN}MODE 2: Execute Commands${NC} (arbitrary commands)
    ./in-devcontainer.sh --exec <command>
    ./in-devcontainer.sh -e <command>

${YELLOW}Usage:${NC}
  ./in-devcontainer.sh <script> [args...]        # MODE 1
  ./in-devcontainer.sh --exec <command>          # MODE 2
  ./in-devcontainer.sh [options]

${YELLOW}Examples:${NC}

  ${GREEN}MODE 1 - Run Scripts:${NC}
  ./in-devcontainer.sh query-loki.sh service-name --json
  ./in-devcontainer.sh run-full-validation.sh python
  ./in-devcontainer.sh validate-log-format.sh python/test/logs/dev.log

  ${GREEN}MODE 1 - Shortcuts (auto-add .sh extension):${NC}
  ./in-devcontainer.sh query-loki service-name
  ./in-devcontainer.sh validate python

  ${GREEN}MODE 2 - Execute Arbitrary Commands:${NC}
  ./in-devcontainer.sh --exec whoami
  ./in-devcontainer.sh --exec "cd /workspace/typescript && npm test"
  ./in-devcontainer.sh -e "ls -la /workspace"
  ./in-devcontainer.sh --dry-run --exec "cd /workspace && npm install"

${YELLOW}Common Aliases:${NC}
  loki, prometheus, tempo   → query-{name}.sh
  validate                  → run-full-validation.sh
  validate-logs             → validate-log-format.sh
  company-lookup            → run-company-lookup.sh

${YELLOW}Options:${NC}
  --help         Show this help message
  --list         List all available scripts in devcontainer
  --dry-run      Show command without executing
  --interactive  Open bash shell in tools directory (cd $TOOLS_DIR)
  --exec, -e     Execute arbitrary command in container (not just tools scripts)

${YELLOW}Exit Codes:${NC}
  0 - Success
  1 - Script execution failed
  2 - Usage error
  3 - Container not running
  4 - Script not found

${YELLOW}Notes:${NC}
  - Container must be running: docker start $CONTAINER_NAME
  - MODE 1: Scripts run from: $TOOLS_DIR
  - MODE 1: Script names auto-resolve (.sh extension, aliases)
  - MODE 2: Commands execute as-is, no script resolution
  - MODE 2: Use quotes for complex commands with spaces/special chars
  - All arguments are passed through to scripts/commands

${YELLOW}Quick Start:${NC}
  For full end-to-end validation:
    ./in-devcontainer.sh run-full-validation.sh python
    # or using alias:
    ./in-devcontainer.sh validate python

EOF
}

list_scripts() {
    echo -e "${BLUE}Available scripts in devcontainer:${NC}"
    echo ""

    # Check if container is running using docker exec
    if ! docker exec "$CONTAINER_NAME" true 2>/dev/null; then
        echo -e "${RED}❌ Error: Container '$CONTAINER_NAME' is not running${NC}"
        echo "Start with: docker start $CONTAINER_NAME"
        exit 3
    fi

    # List all .sh files in tools directory
    docker exec "$CONTAINER_NAME" bash -c "
        cd $TOOLS_DIR 2>/dev/null || { echo 'Tools directory not found'; exit 1; }
        ls -1 *.sh 2>/dev/null | while read file; do
            # Get first line of comment (description)
            desc=\$(head -5 \"\$file\" | grep -E '^# [A-Z]' | head -1 | sed 's/^# //')
            printf '  %-35s %s\n' \"\$file\" \"\$desc\"
        done
    " || {
        echo -e "${RED}❌ Error: Could not list scripts${NC}"
        exit 1
    }

    echo ""
    echo -e "${YELLOW}Usage:${NC} ./in-devcontainer.sh <script> [args...]"
}

check_container() {
    # Most reliable way: try to execute a command in the container
    # If this succeeds, the container is definitely running
    if ! docker exec "$CONTAINER_NAME" true 2>/dev/null; then
        echo -e "${RED}❌ Error: Container '$CONTAINER_NAME' is not running${NC}" >&2
        echo "" >&2
        echo "Start the container with:" >&2
        echo "  docker start $CONTAINER_NAME" >&2
        echo "" >&2
        echo "Or check container status:" >&2
        echo "  docker ps -a | grep devcontainer" >&2
        exit 3
    fi
}

resolve_script_name() {
    local input="$1"
    local script_name=""

    # Common aliases
    case "$input" in
        loki)
            script_name="query-loki.sh"
            ;;
        prometheus|prom)
            script_name="query-prometheus.sh"
            ;;
        tempo)
            script_name="query-tempo.sh"
            ;;
        grafana)
            script_name="validate-grafana-datasources.sh"
            ;;
        validate)
            script_name="run-full-validation.sh"
            ;;
        validate-logs)
            script_name="validate-log-format.sh"
            ;;
        company-lookup)
            script_name="run-company-lookup.sh"
            ;;
        *)
            # Not an alias - use as-is
            script_name="$input"
            ;;
    esac

    # Auto-add .sh if missing
    if [[ ! "$script_name" =~ \.sh$ ]]; then
        script_name="${script_name}.sh"
    fi

    echo "$script_name"
}

check_script_exists() {
    local script="$1"

    if ! docker exec "$CONTAINER_NAME" test -f "$TOOLS_DIR/$script" 2>/dev/null; then
        echo -e "${RED}❌ Error: Script not found: $script${NC}" >&2
        echo "" >&2
        echo "Available scripts:" >&2
        docker exec "$CONTAINER_NAME" bash -c "cd $TOOLS_DIR && ls -1 *.sh 2>/dev/null | head -10" >&2
        echo "" >&2
        echo "Use: ./in-devcontainer.sh --list   (to see all scripts)" >&2
        exit 4
    fi
}

run_interactive() {
    echo -e "${BLUE}Opening interactive shell in devcontainer...${NC}"
    echo "Location: $TOOLS_DIR"
    echo "Exit with: Ctrl+D or 'exit'"
    echo ""

    docker exec -it "$CONTAINER_NAME" bash -c "cd $TOOLS_DIR && exec bash"
}

run_command() {
    local cmd="$1"

    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}Dry run mode - would execute:${NC}"
        echo "docker exec $CONTAINER_NAME bash -c \"$cmd\""
        exit 0
    fi

    # Execute arbitrary command in container
    # Read and set KUBECONFIG from bashrc (avoids interactive shell requirement)
    local full_cmd="export KUBECONFIG=\$(grep '^export KUBECONFIG=' ~/.bashrc 2>/dev/null | sed 's/^export KUBECONFIG=//'); $cmd"
    docker exec "$CONTAINER_NAME" bash -c "$full_cmd"
}

run_script() {
    local script="$1"
    shift
    local args=("$@")

    # Build command
    local cmd="cd $TOOLS_DIR && ./$script"

    # Add arguments (properly quoted)
    if [ ${#args[@]} -gt 0 ]; then
        # Use printf %q for proper shell quoting
        for arg in "${args[@]}"; do
            cmd="$cmd $(printf '%q' "$arg")"
        done
    fi

    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}Dry run mode - would execute:${NC}"
        echo "docker exec $CONTAINER_NAME bash -c \"$cmd\""
        exit 0
    fi

    # Execute in container
    # Read and set KUBECONFIG from bashrc (avoids interactive shell requirement)
    local full_cmd="export KUBECONFIG=\$(grep '^export KUBECONFIG=' ~/.bashrc 2>/dev/null | sed 's/^export KUBECONFIG=//'); $cmd"
    docker exec "$CONTAINER_NAME" bash -c "$full_cmd"
}

#------------------------------------------------------------------------------
# Main Script
#------------------------------------------------------------------------------

# No arguments - show help
if [ $# -eq 0 ]; then
    show_help
    exit 2
fi

# Parse options
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help|-h)
            show_help
            exit 0
            ;;
        --list|-l)
            list_scripts
            exit 0
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --interactive|-i)
            INTERACTIVE=true
            shift
            ;;
        --exec|-e)
            EXEC_MODE=true
            shift
            ;;
        -*)
            echo -e "${RED}❌ Error: Unknown option: $1${NC}" >&2
            echo "Use --help for usage information" >&2
            exit 2
            ;;
        *)
            # First non-option argument is the script name
            break
            ;;
    esac
done

# Check container is running
check_container

# Interactive mode
if [ "$INTERACTIVE" = true ]; then
    run_interactive
    exit 0
fi

# Exec mode - run arbitrary command
if [ "$EXEC_MODE" = true ]; then
    if [ $# -eq 0 ]; then
        echo -e "${RED}❌ Error: No command specified${NC}" >&2
        echo "Usage: ./in-devcontainer.sh --exec <command>" >&2
        echo "Example: ./in-devcontainer.sh --exec whoami" >&2
        exit 2
    fi
    # Join all remaining arguments as the command
    run_command "$*"
    exit 0
fi

# Need at least script name
if [ $# -eq 0 ]; then
    echo -e "${RED}❌ Error: No script specified${NC}" >&2
    echo "Usage: ./in-devcontainer.sh <script> [args...]" >&2
    echo "Use --help for more information" >&2
    exit 2
fi

# Get script name and resolve aliases
SCRIPT_INPUT="$1"
shift
SCRIPT_NAME=$(resolve_script_name "$SCRIPT_INPUT")

# Verify script exists
check_script_exists "$SCRIPT_NAME"

# Run the script with all remaining arguments
run_script "$SCRIPT_NAME" "$@"
