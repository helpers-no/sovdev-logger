#!/bin/bash
# filename: tools/validation/uis/validate-log-format.sh
# description: Validate log files against strict snake_case JSON schema
#
# Purpose:
#   Validates sovdev-logger log files (dev.log, error.log) against the
#   strict snake_case JSON schema specification. Ensures all field names
#   use snake_case (service_name, function_name, etc.) and rejects old
#   camelCase or dotted notation (serviceName, service.name).
#
#   Can run from:
#   1. HOST: Connects to devcontainer and runs Python validator
#   2. DEVCONTAINER: Directly runs Python validator
#
# Usage:
#   ./validate-log-format.sh <log-file-path> [options]
#
#   From host:
#     cd sovdev-logger
#     ./tools/validation/uis/validate-log-format.sh typescript/test/e2e/company-lookup/logs/dev.log
#
#   From devcontainer:
#     cd /workspace
#     ./tools/validation/uis/validate-log-format.sh typescript/test/e2e/company-lookup/logs/dev.log
#
# Arguments:
#   log-file-path    Path to log file (relative to sovdev-logger root)
#
# Options:
#   --json           Output JSON format for automation/parsing
#   --error-log      Validate as error.log (ERROR logs only)
#   --help           Show detailed help message
#
# Environment:
#   - Requires devcontainer-toolbox container running (when called from host)
#   - Uses Python validator: tools/validation/validators/validate-log-format.py
#   - Uses JSON Schema: tools/validation/schemas/log-entry-schema.json
#   - Auto-detects if running inside devcontainer or on host
#
# Validation Checks:
#   1. JSON Schema compliance (all required fields, correct types, snake_case only)
#   2. Field naming: ONLY accepts snake_case (service_name, function_name, log_type)
#   3. Field naming: REJECTS camelCase (serviceName, functionName, logType)
#   4. Field naming: REJECTS dotted notation (service.name, peer.service)
#   5. UUID validation: trace_id and event_id must be valid UUID v4
#   6. Exception structure: type must be "Error" for cross-language consistency
#   7. Exception stack: limited to 350 characters
#   8. Trace ID consistency: found and unique across log entries
#   9. error.log specific: contains only ERROR severity logs (if --error-log)
#
# Exit Codes:
#   0 - Validation passed (all checks successful)
#   1 - Validation failed (schema violations, wrong field names)
#   2 - Usage error (missing parameter or invalid arguments)
#   3 - Devcontainer not running (when run from host)
#   4 - Log file not found or unreadable
#
# Output:
#   - Colored output with validation results
#   - Shows total logs, severities, log types
#   - Lists errors and warnings with line numbers
#   - JSON output available with --json flag
#
# Examples:
#   # Validate dev.log (TypeScript)
#   ./validate-log-format.sh typescript/test/e2e/company-lookup/logs/dev.log
#
#   # Validate error.log with strict ERROR-only check
#   ./validate-log-format.sh typescript/test/e2e/company-lookup/logs/error.log --error-log
#
#   # JSON output for CI/CD pipeline parsing
#   ./validate-log-format.sh python/test/e2e/company-lookup/logs/dev.log --json
#
# CI/CD Integration:
#   This script is designed for automated testing pipelines:
#   - Returns exit code 0 for success, non-zero for failure
#   - Provides JSON output for parsing results
#   - Auto-detects environment (host vs devcontainer)
#   - Validates strict snake_case naming convention
#
###############################################################################

set -e  # Exit on error
set -o pipefail  # Catch errors in pipes

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Constants
CONTAINER_NAME="devcontainer-toolbox"
VALIDATOR_SCRIPT="/workspace/tools/validation/validators/validate-log-format.py"

# Determine script directory and sovdev-logger root
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SOVDEV_LOGGER_ROOT="$( cd "${SCRIPT_DIR}/../.." && pwd )"

###############################################################################
# Functions
###############################################################################

print_usage() {
    echo "Usage: $0 <log-file-path> [options]"
    echo ""
    echo "Arguments:"
    echo "  log-file-path    Path to log file (relative to sovdev-logger root)"
    echo ""
    echo "Options:"
    echo "  --json           Output JSON format for automation"
    echo "  --error-log      Validate as error.log (ERROR logs only)"
    echo "  --help           Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 python/test/e2e/company-lookup/logs/dev.log"
    echo "  $0 python/test/e2e/company-lookup/logs/error.log --error-log"
    echo "  $0 typescript/test/e2e/company-lookup/logs/dev.log --json"
}

print_error() {
    echo -e "${RED}ERROR: $1${NC}" >&2
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

check_devcontainer() {
    if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        print_error "Devcontainer '${CONTAINER_NAME}' is not running"
        echo ""
        echo "Start the devcontainer first:"
        echo "  docker start ${CONTAINER_NAME}"
        return 1
    fi
    return 0
}

is_in_devcontainer() {
    # Check if we're running inside the devcontainer
    [ -f "/.dockerenv" ] || [ -n "$DEVCONTAINER" ]
}

run_validator() {
    local log_file=$1
    shift
    local options="$@"

    # Convert relative path to absolute path for devcontainer
    if [[ "$log_file" != /* ]]; then
        # Relative path - prepend /workspace/
        log_file="/workspace/${log_file}"
    fi

    if is_in_devcontainer; then
        # Running inside devcontainer - execute directly
        python3 "${VALIDATOR_SCRIPT}" "${log_file}" ${options}
    else
        # Running on host - execute in devcontainer
        docker exec "${CONTAINER_NAME}" bash -c \
            "cd /workspace && python3 ${VALIDATOR_SCRIPT} ${log_file} ${options}"
    fi
}

###############################################################################
# Main
###############################################################################

main() {
    # Check for help flag
    if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
        print_usage
        exit 0
    fi

    # Check parameters
    if [ $# -eq 0 ]; then
        print_error "Missing log file parameter"
        echo ""
        print_usage
        exit 2
    fi

    local log_file=$1
    shift
    local options="$@"

    # If running on host, check devcontainer
    if ! is_in_devcontainer; then
        if ! check_devcontainer; then
            exit 3
        fi
    fi

    # Run validator
    if run_validator "${log_file}" ${options}; then
        exit 0
    else
        exit 1
    fi
}

# Run main function
main "$@"
