#!/bin/bash
# filename: specification/tools/run-company-lookup.sh
# description: Run company-lookup E2E test for any language implementation
#
# Purpose:
#   Orchestrates the company-lookup example test for a specific language
#   implementation (TypeScript, Python, Go, etc.). This script:
#   1. Checks that devcontainer-toolbox is running
#   2. Verifies the language has a test/e2e/company-lookup/run-test.sh
#   3. Executes the test inside the devcontainer
#   4. Returns the test exit code
#
#   The test application:
#   - Looks up Norwegian companies via Brønnøysund registry API
#   - Demonstrates job status tracking, progress logging, error handling
#   - Sends telemetry (logs, metrics, traces) to OTLP endpoints
#   - Generates local log files (dev.log, error.log) for validation
#
#   For COMPLETE E2E verification including backend queries (Loki, Prometheus,
#   Tempo), use run-full-validation.sh instead.
#
# Usage:
#   ./run-company-lookup.sh <language>
#
#   From sovdev-logger root:
#     ./specification/tools/run-company-lookup.sh typescript
#     ./specification/tools/run-company-lookup.sh python
#     ./specification/tools/run-company-lookup.sh go
#
# Arguments:
#   language    Implementation language (typescript, python, go, etc.)
#
# Environment:
#   - Must run from HOST (not inside devcontainer)
#   - Requires devcontainer-toolbox container running
#   - Each language must have: <language>/test/e2e/company-lookup/run-test.sh
#   - Test uses .env file in test directory for configuration
#
# What the Test Does:
#   1. Cleans old log files
#   2. Loads environment variables from .env
#   3. Runs company-lookup application (looks up 4 Norwegian companies)
#   4. Validates generated log files for snake_case compliance
#   5. Returns exit code (0 = success, non-zero = failure)
#
# Exit Codes:
#   0 - Test passed (logs generated and validated)
#   1 - Test failed (execution error or validation failed)
#   2 - Usage error (missing language parameter)
#   3 - Devcontainer not running
#   4 - Test script not found (language not implemented yet)
#
# Output:
#   - Colored output showing test progress
#   - Logs generated in: <language>/test/e2e/company-lookup/logs/
#     - dev.log: All log levels
#     - error.log: Error logs only
#   - Validation results for both log files
#
# Examples:
#   # Run TypeScript test
#   ./run-company-lookup.sh typescript
#
#   # Run Python test
#   ./run-company-lookup.sh python
#
#   # Run from any directory
#   cd /path/to/sovdev-logger
#   ./specification/tools/run-company-lookup.sh typescript
#
# CI/CD Integration:
#   - Returns proper exit codes for pipeline integration
#   - Auto-validates log format (snake_case)
#   - Can be run in parallel for multiple languages
#   - Self-contained (doesn't require backend queries)
#
# Related Scripts:
#   - run-full-validation.sh: Full E2E with backend verification
#   - validate-log-format.sh: Standalone log validation
#   - <language>/test/e2e/company-lookup/run-test.sh: Language-specific test
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
TEST_PATH="test/e2e/company-lookup"
TEST_SCRIPT="run-test.sh"

# Detect if we're running inside the container or on the host
# If /workspace exists and we're in it, we're inside the container
if [ -d "/workspace" ] && [ "$(pwd | grep -c "^/workspace")" -gt 0 ]; then
    RUNNING_IN_CONTAINER=true
else
    RUNNING_IN_CONTAINER=false
fi

###############################################################################
# Functions
###############################################################################

print_usage() {
    echo "Usage: $0 <language>"
    echo ""
    echo "Examples:"
    echo "  $0 python"
    echo "  $0 typescript"
    echo "  $0 go"
    echo ""
    echo "This script runs the E2E test for a language implementation by executing:"
    echo "  cd /workspace/<language>/test/e2e/company-lookup && ./run-test.sh"
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

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

check_devcontainer() {
    # If we're already inside the container, skip this check
    if [ "$RUNNING_IN_CONTAINER" = true ]; then
        print_info "Running inside devcontainer - skipping container check"
        return 0
    fi

    print_info "Checking if devcontainer is running..."

    if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        print_error "Devcontainer '${CONTAINER_NAME}' is not running"
        echo ""
        echo "Start the devcontainer first:"
        echo "  docker start ${CONTAINER_NAME}"
        echo ""
        echo "Or create it if it doesn't exist:"
        echo "  docker run -d --name ${CONTAINER_NAME} -v \$(pwd):/workspace <image>"
        return 1
    fi

    print_success "Devcontainer '${CONTAINER_NAME}' is running"
    return 0
}

check_test_script_exists() {
    local language=$1
    local full_path="/workspace/${language}/${TEST_PATH}/${TEST_SCRIPT}"

    print_info "Checking if test script exists: ${full_path}"

    # Check if file exists - method depends on where we're running
    if [ "$RUNNING_IN_CONTAINER" = true ]; then
        # Inside container - check directly
        if [ ! -f "${full_path}" ]; then
            print_error "Test script not found: ${full_path}"
            echo ""
            echo "Expected file structure:"
            echo "  ${language}/"
            echo "  └── ${TEST_PATH}/"
            echo "      └── ${TEST_SCRIPT}"
            echo ""
            echo "See https://sovdev-logger.sovereignsky.no/contributor/test-scenarios for required structure"
            return 1
        fi
    else
        # On host - use docker exec
        if ! docker exec "${CONTAINER_NAME}" bash -c "test -f ${full_path}"; then
            print_error "Test script not found: ${full_path}"
            echo ""
            echo "Expected file structure:"
            echo "  ${language}/"
            echo "  └── ${TEST_PATH}/"
            echo "      └── ${TEST_SCRIPT}"
            echo ""
            echo "See https://sovdev-logger.sovereignsky.no/contributor/test-scenarios for required structure"
            return 1
        fi
    fi

    print_success "Test script found"
    return 0
}

run_test() {
    local language=$1
    local test_dir="/workspace/${language}/${TEST_PATH}"

    print_info "Running company-lookup example for ${language}..."
    echo ""
    echo "═════════════════════════════════════════════════════════════════"
    echo "  Test: Company Lookup Example"
    echo "  Language: ${language}"
    echo "  Directory: ${test_dir}"
    echo "  Script: ./${TEST_SCRIPT}"
    echo "═════════════════════════════════════════════════════════════════"
    echo ""

    # Run the test - method depends on where we're running
    local exit_code
    if [ "$RUNNING_IN_CONTAINER" = true ]; then
        # Inside container - run directly
        (cd "${test_dir}" && ./${TEST_SCRIPT})
        exit_code=$?
    else
        # On host - use docker exec
        docker exec "${CONTAINER_NAME}" bash -c "cd ${test_dir} && ./${TEST_SCRIPT}"
        exit_code=$?
    fi

    echo ""
    echo "═════════════════════════════════════════════════════════════════"

    if [ $exit_code -eq 0 ]; then
        print_success "Test PASSED for ${language}"
        return 0
    else
        print_error "Test FAILED for ${language} (exit code: ${exit_code})"
        return $exit_code
    fi
}

###############################################################################
# Main
###############################################################################

main() {
    # Check parameters
    if [ $# -eq 0 ]; then
        print_error "Missing language parameter"
        echo ""
        print_usage
        exit 2
    fi

    local language=$1

    print_info "Starting company-lookup example for ${language}"
    echo ""

    # Pre-flight checks
    if ! check_devcontainer; then
        exit 3
    fi

    if ! check_test_script_exists "${language}"; then
        exit 4
    fi

    echo ""

    # Run the test
    if run_test "${language}"; then
        exit 0
    else
        exit 1
    fi
}

# Run main function
main "$@"
