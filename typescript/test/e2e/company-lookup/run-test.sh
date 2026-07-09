#!/bin/bash
# filename: typescript/test/e2e/company-lookup/run-test.sh
# description: Run the company lookup example and validate log files
#
# Purpose:
#   Complete test workflow for TypeScript sovdev-logger implementation:
#   1. Clean old log files to ensure fresh test data
#   2. Load environment variables from .env file
#   3. Run company-lookup test application
#   4. Validate generated logs against strict snake_case schema
#   5. Return exit code for CI/CD integration
#
# Usage:
#   ./run-test.sh                              # From typescript/test/e2e/company-lookup/
#   ./run-test.sh --skip-validation             # Skip log validation (used by full validation script)
#   ./run-test.sh --env-file .env.grafana-cloud # Load a different backend's config without overwriting .env
#   npm test                                    # From typescript/ directory (recommended)
#
# Environment:
#   - Must run inside devcontainer (uses /workspace paths)
#   - Requires .env file with OTEL endpoints and OTEL_SERVICE_NAME
#   - Requires sovdev-logger TypeScript library built (npm run build)
#
# Exit Codes:
#   0 - All tests and validation passed
#   1 - Validation failed (logs don't match schema)
#   N - Test execution failed (exit code from company-lookup.ts)
#
# Output:
#   - Generates logs/dev.log (all log levels)
#   - Generates logs/error.log (error level only)
#   - Validates both files for snake_case field names
#   - Prints validation results and summary
#
# CI/CD Integration:
#   This script is designed for automated testing:
#   - Cleans state before each run
#   - Returns proper exit codes
#   - Continues to validation even if test fails
#   - Provides clear pass/fail summary

# Exit on error, but allow capturing exit codes
set -e
set -o pipefail

# Parse arguments
SKIP_VALIDATION=false
ENV_FILE=".env"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-validation)
      SKIP_VALIDATION=true
      shift
      ;;
    --env-file)
      ENV_FILE="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

# Track test results
TEST_EXIT=0
VALIDATION_EXIT=0

# Clean up old logs to ensure fresh test data
echo "Cleaning up old log files..."
rm -rf ./logs/*.log
echo ""

# Load the chosen env file if it exists (defaults to .env)
if [ -f "$ENV_FILE" ]; then
  echo "Loading environment variables from ${ENV_FILE}..."
  # Use set -a to automatically export all variables
  set -a
  source "$ENV_FILE"
  set +a
else
  echo "⚠️  Env file not found: ${ENV_FILE}" >&2
fi

# Run the company lookup example with OTLP configuration
# Capture exit code but continue to validation
set +e
npx tsx company-lookup.ts
TEST_EXIT=$?
set -e

# Validate generated log files (optional - skipped when run from full validation script)
if [ "$SKIP_VALIDATION" = false ]; then
  echo ""
  echo "Validating log file format..."

  # Detect if running in devcontainer or on host
  if [ -f "/.dockerenv" ] || [ -n "$DEVCONTAINER" ]; then
    # Running inside devcontainer - use /workspace paths
    VALIDATOR_SCRIPT="/workspace/specification/tools/validate-log-format.sh"
  else
    # Running on host - find script relative to this script's location
    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    VALIDATOR_SCRIPT="${SCRIPT_DIR}/../../../specification/tools/validate-log-format.sh"
  fi

  # Validate dev.log
  set +e
  "${VALIDATOR_SCRIPT}" typescript/test/e2e/company-lookup/logs/dev.log
  DEV_LOG_EXIT=$?
  set -e

  echo ""

  # Validate error.log
  set +e
  "${VALIDATOR_SCRIPT}" typescript/test/e2e/company-lookup/logs/error.log
  ERROR_LOG_EXIT=$?
  set -e

  # Determine overall validation exit code
  if [ $DEV_LOG_EXIT -ne 0 ] || [ $ERROR_LOG_EXIT -ne 0 ]; then
    VALIDATION_EXIT=1
  fi
fi

# Print summary
echo ""
if [ "$SKIP_VALIDATION" = true ]; then
  # When validation is skipped, only report test execution status
  if [ $TEST_EXIT -eq 0 ]; then
    echo "✅ Test program completed successfully"
    exit 0
  else
    echo "❌ Test execution failed (exit code: $TEST_EXIT)"
    exit $TEST_EXIT
  fi
else
  # When validation is included, report both test and validation status
  if [ $TEST_EXIT -eq 0 ] && [ $VALIDATION_EXIT -eq 0 ]; then
    echo "✅ All tests passed"
    exit 0
  elif [ $TEST_EXIT -ne 0 ]; then
    echo "❌ Test execution failed (exit code: $TEST_EXIT)"
    exit $TEST_EXIT
  else
    echo "❌ Validation failed"
    exit $VALIDATION_EXIT
  fi
fi
