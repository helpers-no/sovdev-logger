#!/bin/bash

# Company Lookup Test - Python Implementation
# Runs the E2E test program that demonstrates all sovdev-logger functions
#
# Usage:
#   ./run-test.sh                              # Uses .env
#   ./run-test.sh --env-file .env.grafana-cloud # Load a different backend's config without overwriting .env

set -e  # Exit on error

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Parse arguments
ENV_FILE=".env"
while [[ $# -gt 0 ]]; do
  case "$1" in
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

echo "================================================"
echo "Company Lookup E2E Test - Python"
echo "================================================"
echo ""

# Clean logs directory
echo "🧹 Cleaning logs directory..."
rm -rf "$SCRIPT_DIR/logs"
mkdir -p "$SCRIPT_DIR/logs"
echo "✅ Logs directory cleaned"
echo ""

# Load the chosen env file if it exists (defaults to .env). python-dotenv's
# load_dotenv() (called by company-lookup.py) defaults to override=False, so
# variables already exported here take precedence over whatever it reads
# from the default .env — this lets --env-file work without touching
# company-lookup.py at all.
cd "$SCRIPT_DIR"
if [ -f "$ENV_FILE" ]; then
  echo "Loading environment variables from ${ENV_FILE}..."
  set -a
  source "$ENV_FILE"
  set +a
else
  echo "⚠️  Env file not found: ${ENV_FILE}" >&2
fi
echo ""

# Install dependencies
echo "📦 Installing dependencies..."
cd "$SCRIPT_DIR"
pip3 install -q -r requirements.txt
pip3 install -q -r ../../../requirements.txt
echo "✅ Dependencies installed"
echo ""

# Run the test
echo "🚀 Running company lookup test..."
echo ""
python3 "$SCRIPT_DIR/company-lookup.py"
echo ""

# Check if logs were created
if [ -f "$SCRIPT_DIR/logs/dev.log" ]; then
    LOG_COUNT=$(wc -l < "$SCRIPT_DIR/logs/dev.log" | tr -d ' ')
    echo "✅ Test completed successfully"
    echo "📝 Generated $LOG_COUNT log entries in logs/dev.log"
    echo ""

    if [ "$LOG_COUNT" -eq 17 ]; then
        echo "✅ PASS: Expected 17 log entries, got $LOG_COUNT"
    else
        echo "⚠️  WARNING: Expected 17 log entries, got $LOG_COUNT"
    fi
else
    echo "❌ FAIL: No log file created at logs/dev.log"
    exit 1
fi

echo ""
echo "================================================"
echo "Test complete"
echo "================================================"
