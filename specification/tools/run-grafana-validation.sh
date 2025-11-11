#!/usr/bin/env bash
################################################################################
# run-grafana-validation.sh - Validate Grafana datasource queries
#
# Purpose: Query through Grafana's datasource proxy API and validate against
#          log file to ensure Grafana can correctly query all backends
#
# Usage (from inside devcontainer):
#   cd /workspace/specification/tools
#   ./run-grafana-validation.sh <service-name> <log-file>
#
# Arguments:
#   service-name    Service name to query (e.g., sovdev-test-company-lookup-typescript)
#   log-file        Path to log file for comparison
#
# This validates that:
#   1. Grafana can query Loki via datasource proxy
#   2. Grafana can query Prometheus via datasource proxy
#   3. Grafana can query Tempo via datasource proxy
#   4. Data retrieved via Grafana matches log file (same as direct backend queries)
#
# Exit codes:
#   0 - All validations passed
#   1 - Validation failed
#   2 - Usage error
#
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Helper functions
print_step() {
    echo -e "${BLUE}==>${NC} $1"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}" >&2
}

print_header() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# Parse arguments
if [[ $# -lt 2 ]]; then
    print_error "Usage: $0 <service-name> <log-file>"
    exit 2
fi

SERVICE_NAME="$1"
LOG_FILE="$2"

# Validate log file exists
if [[ ! -f "$LOG_FILE" ]]; then
    print_error "Log file not found: $LOG_FILE"
    exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_SCRIPT_DIR="$(dirname "$SCRIPT_DIR")/tests"

# Count entries in file
ENTRY_COUNT=$(wc -l < "$LOG_FILE" | tr -d ' ')
LIMIT=$((ENTRY_COUNT + 10))  # Add buffer

print_header "TASK 3.4: GRAFANA DATASOURCE QUERY VALIDATION"

#
# STEP 3.4.1-2: Loki via Grafana
#
print_header "Steps 3.4.1-2: Query Loki Via Grafana + Validate Consistency"
print_step "Querying Loki through Grafana with validation..."
echo ""

./query-grafana-loki.sh "$SERVICE_NAME" --limit "$LIMIT" --validate --compare-with "$LOG_FILE"

if [[ $? -ne 0 ]]; then
    print_error "Loki validation via Grafana failed"
    exit 1
fi

print_success "Loki query and consistency validated via Grafana"

#
# STEP 3.4.3-4: Prometheus via Grafana
#
print_header "Steps 3.4.3-4: Query Prometheus Via Grafana + Validate Consistency"
print_step "Querying Prometheus through Grafana with validation..."
echo ""

timeout 30 ./query-grafana-prometheus.sh "$SERVICE_NAME" --validate --compare-with "$LOG_FILE" 2>/dev/null

if [[ $? -ne 0 ]]; then
    print_error "Prometheus validation via Grafana failed"
    exit 1
fi

print_success "Prometheus query and consistency validated via Grafana"

#
# STEP 3.4.5-6: Tempo via Grafana
#
print_header "Steps 3.4.5-6: Query Tempo Via Grafana + Validate Consistency"
print_step "Querying Tempo through Grafana with validation..."
echo ""

timeout 30 ./query-grafana-tempo.sh "$SERVICE_NAME" --limit 50 --validate --compare-with "$LOG_FILE" 2>/dev/null

if [[ $? -ne 0 ]]; then
    print_error "Tempo validation via Grafana failed"
    exit 1
fi

print_success "Tempo query and consistency validated via Grafana"

#
# SUCCESS
#
echo ""
print_header "GRAFANA VALIDATION COMPLETE"
echo -e "${GREEN}✅ ALL GRAFANA DATASOURCE QUERIES VALIDATED${NC}"
echo ""
echo "Summary:"
echo "  Service: $SERVICE_NAME"
echo "  Log file: $LOG_FILE"
echo "  Entries: $ENTRY_COUNT"
echo ""
echo "Validation steps completed:"
echo "  3.4.1-2) ✅ Loki: Query + Schema + Consistency"
echo "  3.4.3-4) ✅ Prometheus: Query + Schema + Consistency"
echo "  3.4.5-6) ✅ Tempo: Query + Schema + Consistency"
echo ""
echo "✅ Grafana can correctly query all backends with snake_case fields"
echo ""

exit 0
