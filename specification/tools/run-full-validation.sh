#!/usr/bin/env bash
#
# Full E2E Validation Script (Run Inside Devcontainer)
#
# Runs complete validation workflow for sovdev-logger:
# A) Run program that creates log
# B) Validate log file using schema definition
# C) Loki: Validate if logs are sent to Loki via OTEL
#    C.1) Validate if Loki stores logs according to schema definition
#    C.2) Compare logs entries stored in Loki corresponds with logs entries in file
# D) Prometheus: Validate if logs are sent to Prometheus via OTEL
#    D.1) Validate if Prometheus stores logs according to schema definition
#    D.2) Compare logs entries stored in Prometheus corresponds with logs entries in file
# E) Tempo: Validate if traces are sent to Tempo via OTEL
#    E.1) Validate if Tempo stores traces according to schema definition
#    E.2) Compare trace_ids from log file match traces in Tempo (may show warning due to slow ingestion)
# F) Grafana: Validate queries via Grafana datasource proxy
#    F.1) Query Loki via Grafana and validate schema
#    F.2) Compare Grafana-Loki with log file
#    F.3) Query Prometheus via Grafana and validate schema
#    F.4) Compare Grafana-Prometheus with log file
#    F.5) Query Tempo via Grafana and validate schema
#    F.6) Compare Grafana-Tempo with log file
#
# This validates the complete observability stack:
# - File logging with snake_case fields
# - OTLP export to monitoring backends (Loki, Prometheus, Tempo)
# - Data consistency across all systems
# - Grafana datasource proxy queries with snake_case fields
#
# Usage (from inside devcontainer):
#   cd /workspace/specification/tools
#   ./run-full-validation.sh [typescript|python|go]
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
#   - Requires kubeconfig at /workspace/topsecret/.kube/config
#   - Uses /workspace paths (devcontainer workspace)
#
# Prerequisites:
#   - Monitoring stack deployed (Loki, Prometheus, Tempo, OTLP Collector, Grafana)
#   - kubectl configured and connected to cluster
#   - Service can send to http://host.docker.internal/v1/logs (OTLP endpoint)
#   - Grafana accessible at http://grafana.localhost (via host.docker.internal)

set -e

# Configure kubectl to use kubeconfig from workspace
if [ -f "/workspace/topsecret/.kube/config" ]; then
    export KUBECONFIG="/workspace/topsecret/.kube/config"
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
    echo "Expected location: /workspace/topsecret/.kube/config"
    echo ""
    echo "Current KUBECONFIG: ${KUBECONFIG:-not set}"
    echo ""
    exit 3
fi

print_success "kubectl configured and connected to cluster"
echo ""

# Check ROADMAP.md progress before allowing validation
print_step "Checking ROADMAP.md progress..."
echo ""

PROGRESS_CHECK_SCRIPT="$SCRIPT_DIR/../llm-work-templates/enforcement/check-progress.sh"

if [[ -f "$PROGRESS_CHECK_SCRIPT" ]]; then
    # Run progress check
    "$PROGRESS_CHECK_SCRIPT" "$LANGUAGE"
    PROGRESS_EXIT=$?

    if [[ $PROGRESS_EXIT -ne 0 ]]; then
        print_error "Progress check failed"
        echo ""
        echo "You must update ROADMAP.md before running validation."
        echo "See output above for details."
        echo ""
        exit 1
    fi

    print_success "Progress check passed"
    echo ""
else
    print_warning "Progress check script not found (skipping)"
    echo "  Expected: $PROGRESS_CHECK_SCRIPT"
    echo ""
fi

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
# STEP C: Loki Validation
#
print_header "Step C: Loki - Validate Logs Sent Via OTEL"

#
# STEP C.1: Validate Loki response using schema
#
print_header "Step C.1: Validate Loki Response Using Schema"
print_step "Waiting 10 seconds for logs to reach Loki..."
sleep 10
echo ""

# Count entries in file to determine limit
ENTRY_COUNT=$(wc -l < "$LOG_FILE" | tr -d ' ')
LIMIT=$((ENTRY_COUNT + 10))  # Add buffer

print_step "Querying Loki and validating against loki-response-schema.json..."
echo ""

# Query Loki and validate schema
./query-loki.sh "$SERVICE_NAME" --limit "$LIMIT" --json | \
    python3 "$TEST_SCRIPT_DIR/validate-loki-response.py" -

if [[ $? -ne 0 ]]; then
    print_error "Loki response validation failed"
    exit 1
fi

print_success "Loki response schema validation passed"

#
# STEP C.2: Compare log file with Loki response
#
print_header "Step C.2: Compare Log File With Loki Response"
print_step "Cross-validating file logs match Loki logs..."
echo ""

./query-loki.sh "$SERVICE_NAME" --limit "$LIMIT" --json | \
    python3 "$TEST_SCRIPT_DIR/validate-log-consistency.py" "$LOG_FILE" -

if [[ $? -ne 0 ]]; then
    print_error "Log consistency validation failed"
    exit 1
fi

print_success "Log consistency validation passed"

#
# STEP D: Prometheus Validation
#
print_header "Step D: Prometheus - Validate Logs Sent Via OTEL"

#
# STEP D.1: Validate Prometheus response using schema
#
print_header "Step D.1: Validate Prometheus Response Using Schema"
print_step "Querying Prometheus and validating against prometheus-response-schema.json..."
echo ""

# Query Prometheus and validate schema
timeout 30 ./query-prometheus.sh "$SERVICE_NAME" --json 2>/dev/null | \
    python3 "$TEST_SCRIPT_DIR/validate-prometheus-response.py" -

if [[ $? -eq 0 ]]; then
    print_success "Prometheus response validation passed"
else
    print_error "Prometheus response validation failed"
    exit 1
fi

#
# STEP D.2: Compare log file with Prometheus metrics
#
print_header "Step D.2: Compare Log File With Prometheus Metrics"
print_step "Cross-validating file logs match Prometheus metrics..."
echo ""

timeout 30 ./query-prometheus.sh "$SERVICE_NAME" --json 2>/dev/null | \
    python3 "$TEST_SCRIPT_DIR/validate-metrics-consistency.py" "$LOG_FILE" -

if [[ $? -eq 0 ]]; then
    print_success "Metrics consistency validation passed"
else
    print_error "Metrics consistency validation failed"
    exit 1
fi

#
# STEP E: Tempo Validation
#
print_header "Step E: Tempo - Validate Traces Sent Via OTEL"

#
# STEP E.1: Validate Tempo response using schema
#
print_header "Step E.1: Validate Tempo Response Using Schema"
print_step "Waiting 30 seconds for traces to reach Tempo..."
echo ""
echo "Note: Tempo trace ingestion can be slow. Waiting longer than Loki/Prometheus..."
sleep 30
echo ""

print_step "Querying Tempo and validating against tempo-response-schema.json..."
echo ""

# Query Tempo and validate schema
# Use higher limit to catch all traces from current run
timeout 30 ./query-tempo.sh "$SERVICE_NAME" --limit 50 --json 2>/dev/null | \
    python3 "$TEST_SCRIPT_DIR/validate-tempo-response.py" -

if [[ $? -ne 0 ]]; then
    print_error "Tempo response validation failed"
    exit 1
fi

print_success "Tempo response schema validation passed"

#
# STEP E.2: Compare log file with Tempo traces
#
print_header "Step E.2: Compare Log File With Tempo Traces"
print_step "Cross-validating file trace_ids match Tempo traces..."
echo ""

# Run trace consistency check
timeout 30 ./query-tempo.sh "$SERVICE_NAME" --limit 50 --json 2>/dev/null | \
    python3 "$TEST_SCRIPT_DIR/validate-trace-consistency.py" "$LOG_FILE" -

TEMPO_CONSISTENCY_EXIT=$?

if [[ $TEMPO_CONSISTENCY_EXIT -ne 0 ]]; then
    print_error "Trace consistency validation failed"
    echo ""
    echo "File trace_ids do not match Tempo trace IDs."
    echo "This indicates a problem with trace ID correlation between logs and OTEL spans."
    echo ""
    echo "Expected behavior: File logs and Tempo traces should share the same trace IDs."
    echo "This enables distributed tracing and log-trace correlation in Grafana."
    echo ""
    exit 1
else
    print_success "Trace consistency validation passed"
fi

#
# STEP F: Grafana Validation
#
print_header "Step F: Grafana - Validate Queries Via Grafana Datasource Proxy"

#
# STEP F.1: Query Loki via Grafana
#
print_header "Step F.1: Query Loki Via Grafana Datasource Proxy"
print_step "Querying Loki through Grafana and validating schema..."
echo ""

./query-grafana-loki.sh "$SERVICE_NAME" --limit "$LIMIT" --json | \
    python3 "$TEST_SCRIPT_DIR/validate-loki-response.py" -

if [[ $? -ne 0 ]]; then
    print_error "Grafana-Loki query validation failed"
    exit 1
fi

print_success "Grafana-Loki query validation passed"

#
# STEP F.2: Compare Grafana-Loki with log file
#
print_header "Step F.2: Compare Grafana-Loki Response With Log File"
print_step "Cross-validating Grafana-Loki logs match file logs..."
echo ""

./query-grafana-loki.sh "$SERVICE_NAME" --limit "$LIMIT" --json | \
    python3 "$TEST_SCRIPT_DIR/validate-log-consistency.py" "$LOG_FILE" -

if [[ $? -ne 0 ]]; then
    print_error "Grafana-Loki consistency validation failed"
    exit 1
fi

print_success "Grafana-Loki consistency validation passed"

#
# STEP F.3: Query Prometheus via Grafana
#
print_header "Step F.3: Query Prometheus Via Grafana Datasource Proxy"
print_step "Querying Prometheus through Grafana and validating schema..."
echo ""

timeout 30 ./query-grafana-prometheus.sh "$SERVICE_NAME" --json 2>/dev/null | \
    python3 "$TEST_SCRIPT_DIR/validate-prometheus-response.py" -

if [[ $? -ne 0 ]]; then
    print_error "Grafana-Prometheus query validation failed"
    exit 1
fi

print_success "Grafana-Prometheus query validation passed"

#
# STEP F.4: Compare Grafana-Prometheus with log file
#
print_header "Step F.4: Compare Grafana-Prometheus Response With Log File"
print_step "Cross-validating Grafana-Prometheus metrics match file logs..."
echo ""

timeout 30 ./query-grafana-prometheus.sh "$SERVICE_NAME" --json 2>/dev/null | \
    python3 "$TEST_SCRIPT_DIR/validate-metrics-consistency.py" "$LOG_FILE" -

if [[ $? -ne 0 ]]; then
    print_error "Grafana-Prometheus consistency validation failed"
    exit 1
fi

print_success "Grafana-Prometheus consistency validation passed"

#
# STEP F.5: Query Tempo via Grafana
#
print_header "Step F.5: Query Tempo Via Grafana Datasource Proxy"
print_step "Querying Tempo through Grafana and validating schema..."
echo ""

timeout 30 ./query-grafana-tempo.sh "$SERVICE_NAME" --limit 50 --json 2>/dev/null | \
    python3 "$TEST_SCRIPT_DIR/validate-tempo-response.py" -

if [[ $? -ne 0 ]]; then
    print_error "Grafana-Tempo query validation failed"
    exit 1
fi

print_success "Grafana-Tempo query validation passed"

#
# STEP F.6: Compare Grafana-Tempo with log file
#
print_header "Step F.6: Compare Grafana-Tempo Response With Log File"
print_step "Cross-validating Grafana-Tempo traces match file trace_ids..."
echo ""

timeout 30 ./query-grafana-tempo.sh "$SERVICE_NAME" --limit 50 --json 2>/dev/null | \
    python3 "$TEST_SCRIPT_DIR/validate-trace-consistency.py" "$LOG_FILE" -

if [[ $? -ne 0 ]]; then
    print_error "Grafana-Tempo consistency validation failed"
    exit 1
fi

print_success "Grafana-Tempo consistency validation passed"

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
echo "  A)   ✅ Run program that creates log"
echo "  B)   ✅ Validate log file using schema definition"
echo ""
echo "  C)   ✅ Loki: Validate if logs are sent to Loki via OTEL"
echo "  C.1) ✅ Validate if Loki stores logs according to schema definition"
echo "  C.2) ✅ Compare logs entries stored in Loki corresponds with logs entries in file"
echo ""
echo "  D)   ✅ Prometheus: Validate if logs are sent to Prometheus via OTEL"
echo "  D.1) ✅ Validate if Prometheus stores logs according to schema definition"
echo "  D.2) ✅ Compare logs entries stored in Prometheus corresponds with logs entries in file"
echo ""
echo "  E)   ✅ Tempo: Validate if traces are sent to Tempo via OTEL"
echo "  E.1) ✅ Validate if Tempo stores traces according to schema definition"
echo "  E.2) ✅ Compare trace_ids from log file match traces in Tempo"
echo ""
echo "  F)   ✅ Grafana: Validate queries via Grafana datasource proxy"
echo "  F.1) ✅ Query Loki via Grafana and validate schema"
echo "  F.2) ✅ Compare Grafana-Loki with log file"
echo "  F.3) ✅ Query Prometheus via Grafana and validate schema"
echo "  F.4) ✅ Compare Grafana-Prometheus with log file"
echo "  F.5) ✅ Query Tempo via Grafana and validate schema"
echo "  F.6) ✅ Compare Grafana-Tempo with log file"
echo ""

exit 0
