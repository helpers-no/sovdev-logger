#!/usr/bin/env bash
#
# Full E2E Validation Script (Run Inside Devcontainer)
#
# Runs complete validation workflow for sovdev-logger:
# A) Run program that creates log
# B) Validate log file using schema definition
# C) Loki: Combined schema + consistency validation via OTEL
#    • Validates if Loki stores logs according to schema definition
#    • Compares logs entries stored in Loki with logs entries in file
# D) Prometheus: Combined schema + consistency validation via OTEL
#    • Validates if Prometheus stores logs according to schema definition
#    • Compares logs entries stored in Prometheus with logs entries in file
# E) Tempo: Combined schema + consistency validation via OTEL
#    • Validates if Tempo stores traces according to schema definition
#    • Compares trace_ids from log file match traces in Tempo
# F) Grafana: Validate queries via Grafana datasource proxy
#    F.1-F.2) Loki via Grafana: Combined schema + consistency validation
#    F.3-F.4) Prometheus via Grafana: Combined schema + consistency validation
#    F.5-F.6) Tempo via Grafana: Combined schema + consistency validation
#
# This validates the complete observability stack:
# - File logging with snake_case fields
# - OTLP export to monitoring backends (Loki, Prometheus, Tempo)
# - Data consistency across all systems
# - Grafana datasource proxy queries with snake_case fields
#
# Note: All query scripts now use combined validation flags (--validate --compare-with)
#       which reduces queries from 12 to 6 (one per backend instead of two).
#
# Usage (from inside devcontainer):
#   cd /workspace/specification/tools
#   ./run-full-validation.sh [typescript|python|go|csharp]
#
# Exit codes:
#   0 - All validations passed
#   1 - Validation failed
#   2 - Usage error
#   3 - kubectl not configured
#
# Environment:
#   - Must run INSIDE devcontainer (not from host)
#   - Requires Kubernetes cluster with monitoring stack (Loki, Prometheus, Tempo)
#   - Requires kubeconfig at /workspace/.devcontainer.secrets/.kube/config
#   - Uses /workspace paths (devcontainer workspace)
#
# Prerequisites:
#   - Monitoring stack deployed (Loki, Prometheus, Tempo, OTLP Collector, Grafana)
#   - kubectl configured and connected to cluster
#   - Service can send to http://host.docker.internal/v1/logs (OTLP endpoint)
#   - Grafana accessible at http://grafana.localhost (via host.docker.internal)

set -e

# Configure kubectl to use kubeconfig from workspace
if [ -f "/workspace/.devcontainer.secrets/.kube/config" ]; then
    export KUBECONFIG="/workspace/.devcontainer.secrets/.kube/config"
elif [ -f "$HOME/.kube/config" ]; then
    export KUBECONFIG="$HOME/.kube/config"
fi

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

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_header() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# Parse arguments
LANGUAGE=${1:-typescript}

if [[ -z "$LANGUAGE" ]]; then
    print_error "Missing language argument"
    echo "Usage: $0 <language>"
    echo ""
    echo "Examples:"
    echo "  $0 typescript"
    echo "  $0 python"
    echo "  $0 go"
    echo "  $0 csharp"
    exit 2
fi

# Determine paths based on language (devcontainer paths)
# Generic path structure that works for any language
TEST_DIR="/workspace/$LANGUAGE/test/e2e/company-lookup"
SERVICE_NAME="sovdev-test-company-lookup-$LANGUAGE"
LOG_FILE="$TEST_DIR/logs/dev.log"

# Check if test directory exists
if [[ ! -d "$TEST_DIR" ]]; then
    print_error "Test directory not found: $TEST_DIR"
    echo ""
    echo "The directory '$LANGUAGE/test/e2e/company-lookup' does not exist."
    echo "Please ensure you have:"
    echo "  1. Implemented the E2E test for $LANGUAGE"
    echo "  2. Created the test directory structure"
    echo ""
    exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_SCRIPT_DIR="$(dirname "$SCRIPT_DIR")/tests"

# Check kubectl access before starting
print_step "Checking kubectl access to Kubernetes cluster..."

if ! command -v kubectl &> /dev/null; then
    print_error "kubectl not found in devcontainer"
    exit 3
fi

if ! kubectl cluster-info &> /dev/null; then
    print_error "kubectl cannot access Kubernetes cluster"
    echo ""
    echo "Kubeconfig not properly configured."
    echo "Expected location: /workspace/.devcontainer.secrets/.kube/config"
    echo ""
    echo "Current KUBECONFIG: ${KUBECONFIG:-not set}"
    echo ""
    exit 3
fi

print_success "kubectl configured and connected to cluster"
echo ""

print_header "FULL E2E VALIDATION - $LANGUAGE"

#
# STEP A: Run program that creates log
#
print_header "Step A: Run Program That Creates Log"
print_step "Running test program to generate logs..."
echo ""

cd "$TEST_DIR"
if [[ ! -f "./run-test.sh" ]]; then
    print_error "Test script not found: $TEST_DIR/run-test.sh"
    exit 2
fi

# Run test with --skip-validation flag (validation will be done in Step B)
./run-test.sh --skip-validation
if [[ $? -ne 0 ]]; then
    print_error "Test program failed"
    exit 1
fi

print_success "Test program completed"

#
# STEP B: Validate log file using schema
#
print_header "Step B: Validate Log File Using Schema"
print_step "Validating log file against log-entry-schema.json..."
echo ""

if [[ ! -f "$LOG_FILE" ]]; then
    print_error "Log file not found: $LOG_FILE"
    exit 2
fi

cd "$SCRIPT_DIR"
./validate-log-format.sh "$LOG_FILE"
if [[ $? -ne 0 ]]; then
    print_error "Log file validation failed"
    exit 1
fi

print_success "Log file schema validation passed"

#
# STEP C: Loki Validation (Combined Schema + Consistency)
#
print_header "Step C: Loki - Validate Logs Sent Via OTEL"
print_step "Waiting 10 seconds for logs to reach Loki..."
sleep 10
echo ""

print_step "Querying Loki with combined validation (schema + consistency)..."
echo ""

# Query Loki once with combined validation flags
# This validates both schema and consistency in a single query
./query-loki.sh "$SERVICE_NAME" --validate --compare-with "$LOG_FILE"

if [[ $? -ne 0 ]]; then
    print_error "Loki validation failed (schema or consistency)"
    exit 1
fi

print_success "Loki validation passed (schema + consistency)"

#
# STEP D: Prometheus Validation (Combined Schema + Consistency)
#
print_header "Step D: Prometheus - Validate Logs Sent Via OTEL"
print_step "Querying Prometheus with combined validation (schema + consistency)..."
echo ""

# Query Prometheus once with combined validation flags
# This validates both schema and consistency in a single query
timeout 30 ./query-prometheus.sh "$SERVICE_NAME" --validate --compare-with "$LOG_FILE" 2>/dev/null

if [[ $? -eq 0 ]]; then
    print_success "Prometheus validation passed (schema + consistency)"
else
    print_error "Prometheus validation failed (schema or consistency)"
    exit 1
fi

#
# STEP E: Tempo Validation (Combined Schema + Consistency)
#
print_header "Step E: Tempo - Validate Traces Sent Via OTEL"
print_step "Waiting 30 seconds for traces to reach Tempo..."
echo ""
echo "Note: Tempo trace ingestion can be slow. Waiting longer than Loki/Prometheus..."
sleep 30
echo ""

print_step "Querying Tempo with combined validation (schema + consistency)..."
echo ""

# Query Tempo once with combined validation flags
# This validates both schema and consistency in a single query
# Use higher limit to catch all traces from current run
timeout 30 ./query-tempo.sh "$SERVICE_NAME" --limit 50 --validate --compare-with "$LOG_FILE" 2>/dev/null

TEMPO_EXIT=$?

if [[ $TEMPO_EXIT -ne 0 ]]; then
    print_error "Tempo validation failed (schema or consistency)"
    echo ""
    echo "File trace_ids do not match Tempo trace IDs."
    echo "This indicates a problem with trace ID correlation between logs and OTEL spans."
    echo ""
    echo "Expected behavior: File logs and Tempo traces should share the same trace IDs."
    echo "This enables distributed tracing and log-trace correlation in Grafana."
    echo ""
    exit 1
else
    print_success "Tempo validation passed (schema + consistency)"
fi

#
# STEP F: Grafana Validation
#
print_header "Step F: Grafana - Validate Queries Via Grafana Datasource Proxy"

#
# STEP F.1-F.2: Query Loki via Grafana (Combined Schema + Consistency)
#
print_header "Step F.1-F.2: Loki Via Grafana - Combined Validation"
print_step "Querying Loki through Grafana with combined validation..."
echo ""

# Count entries in file for limit calculation
ENTRY_COUNT=$(wc -l < "$LOG_FILE" | tr -d ' ')
LIMIT=$((ENTRY_COUNT + 10))  # Add buffer

# Query Grafana-Loki once with combined validation flags
./query-grafana-loki.sh "$SERVICE_NAME" --limit "$LIMIT" --validate --compare-with "$LOG_FILE"

if [[ $? -ne 0 ]]; then
    print_error "Grafana-Loki validation failed (schema or consistency)"
    exit 1
fi

print_success "Grafana-Loki validation passed (schema + consistency)"

#
# STEP F.3-F.4: Query Prometheus via Grafana (Combined Schema + Consistency)
#
print_header "Step F.3-F.4: Prometheus Via Grafana - Combined Validation"
print_step "Querying Prometheus through Grafana with combined validation..."
echo ""

# Query Grafana-Prometheus once with combined validation flags
timeout 30 ./query-grafana-prometheus.sh "$SERVICE_NAME" --validate --compare-with "$LOG_FILE" 2>/dev/null

if [[ $? -ne 0 ]]; then
    print_error "Grafana-Prometheus validation failed (schema or consistency)"
    exit 1
fi

print_success "Grafana-Prometheus validation passed (schema + consistency)"

#
# STEP F.5-F.6: Query Tempo via Grafana (Combined Schema + Consistency)
#
print_header "Step F.5-F.6: Tempo Via Grafana - Combined Validation"
print_step "Querying Tempo through Grafana with combined validation..."
echo ""

# Query Grafana-Tempo once with combined validation flags
timeout 30 ./query-grafana-tempo.sh "$SERVICE_NAME" --limit 50 --validate --compare-with "$LOG_FILE" 2>/dev/null

if [[ $? -ne 0 ]]; then
    print_error "Grafana-Tempo validation failed (schema or consistency)"
    exit 1
fi

print_success "Grafana-Tempo validation passed (schema + consistency)"

#
# SUCCESS
#
echo ""
print_header "ALL VALIDATIONS PASSED"
echo -e "${GREEN}✅ E2E TEST SUCCESSFUL${NC}"
echo ""
echo "Summary:"
echo "  Language: $LANGUAGE"
echo "  Service: $SERVICE_NAME"
echo "  Log file: $LOG_FILE"
echo "  Entries validated: $ENTRY_COUNT"
echo ""
echo "Validation steps completed:"
echo "  A) ✅ Run program that creates log"
echo "  B) ✅ Validate log file using schema definition"
echo ""
echo "  C) ✅ Loki: Schema + consistency validation (combined)"
echo "     • Validates if Loki stores logs according to schema definition"
echo "     • Compares logs entries stored in Loki with logs entries in file"
echo ""
echo "  D) ✅ Prometheus: Schema + consistency validation (combined)"
echo "     • Validates if Prometheus stores logs according to schema definition"
echo "     • Compares logs entries stored in Prometheus with logs entries in file"
echo ""
echo "  E) ✅ Tempo: Schema + consistency validation (combined)"
echo "     • Validates if Tempo stores traces according to schema definition"
echo "     • Compares trace_ids from log file match traces in Tempo"
echo ""
echo "  F) ✅ Grafana: Validate queries via Grafana datasource proxy"
echo "     F.1-F.2) ✅ Loki via Grafana: Schema + consistency validation"
echo "     F.3-F.4) ✅ Prometheus via Grafana: Schema + consistency validation"
echo "     F.5-F.6) ✅ Tempo via Grafana: Schema + consistency validation"
echo ""

exit 0
