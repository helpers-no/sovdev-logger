#!/bin/bash
################################################################################
# query-prometheus.sh - Query Prometheus for metrics from a specific service
#
# Purpose: Query Prometheus backend to retrieve and verify metrics
#
# Usage:
#   ./query-prometheus.sh <service-name> [options]
#
# Arguments:
#   service-name    Required. The service name to query (e.g., sovdev-test-python)
#
# Options:
#   --json              Output raw JSON data for parsing/verification
#   --validate          Validate response against prometheus-response-schema.json
#   --compare-with FILE Compare Prometheus metrics with log file for consistency
#   --metric NAME       Specific metric to query (default: sovdev_operations_total)
#   --time-range R      Time range lookback: 1h, 30m, 5m, etc. (default: instant query)
#   --help              Show this help message
#
# Note on Time Range:
#   By default, queries Prometheus for current/instant metric values.
#   Use --time-range to query historical values from N time ago.
#   Example: --time-range 5m queries metrics from 5 minutes ago
#
# Validation Sequence:
#   The script performs validation in three sequential steps:
#
#   Step 1: Query Prometheus and verify response has data
#           → Ensures metrics exist in backend (exits if no data)
#
#   Step 2: Validate response against prometheus-response-schema.json (if --validate)
#           → Ensures Prometheus response structure is correct (exits if invalid)
#
#   Step 3: Compare with log file for consistency (if --compare-with)
#           → Ensures metric counts match log entries (exits if mismatch)
#
# Output Modes:
#   Human-readable (default): Color-coded status messages
#     ✅ Found 5 metric series for 'sovdev-test-python'
#     ✅ Total operations: 16
#
#   JSON mode (--json): Full structured JSON output
#     {
#       "status": "success",
#       "data": {
#         "resultType": "vector",
#         "result": [...]
#       }
#     }
#
# Exit Codes:
#   0 - Success (all validations passed)
#   1 - Error (query failed, validation failed, or consistency check failed)
#
# Examples:
#   # Step 1 only: Query and check for data (human-readable)
#   ./query-prometheus.sh sovdev-test-python
#
#   # Step 1 only: Query and get JSON output
#   ./query-prometheus.sh sovdev-test-python --json
#
#   # Steps 1+2: Query + validate schema
#   ./query-prometheus.sh sovdev-test-python --validate
#
#   # Steps 1+3: Query + compare with file (skip schema validation)
#   ./query-prometheus.sh sovdev-test-python --compare-with logs/dev.log
#
#   # Steps 1+2+3: Full validation (query + schema + consistency)
#   ./query-prometheus.sh sovdev-test-python --validate --compare-with logs/dev.log
#
#   # Advanced: Extract specific metric labels
#   ./query-prometheus.sh sovdev-test-python --json | jq '.data.result[0].metric'
#
#   # Advanced: Query specific metric
#   ./query-prometheus.sh sovdev-test-python --metric sovdev_errors_total
#
#   # Advanced: Query metrics from 5 minutes ago
#   ./query-prometheus.sh sovdev-test-python --time-range 5m
#
#   # Advanced: Save JSON evidence for later analysis
#   ./query-prometheus.sh sovdev-test-python --json > evidence/prometheus-output.json
#
################################################################################

set -euo pipefail

# Configure kubectl to use kubeconfig from workspace (devcontainer)
if [ -f "/workspace/.devcontainer.secrets/.kube/config" ]; then
    export KUBECONFIG="/workspace/.devcontainer.secrets/.kube/config"
elif [ -f "$HOME/.kube/config" ]; then
    export KUBECONFIG="$HOME/.kube/config"
fi

# Colors for human-readable output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default options
METRIC_NAME="sovdev_operations_total"
TIME_RANGE=""
JSON_MODE=false
VALIDATE_MODE=false
COMPARE_WITH_FILE=""
SERVICE_NAME=""

# Parse arguments
show_help() {
    head -n 82 "$0" | grep "^#" | sed 's/^# \?//'
    exit 0
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --json)
            JSON_MODE=true
            shift
            ;;
        --validate)
            VALIDATE_MODE=true
            JSON_MODE=true  # Validation requires JSON mode
            shift
            ;;
        --compare-with)
            COMPARE_WITH_FILE="$2"
            JSON_MODE=true  # Comparison requires JSON mode
            shift 2
            ;;
        --metric)
            METRIC_NAME="$2"
            shift 2
            ;;
        --time-range)
            TIME_RANGE="$2"
            shift 2
            ;;
        --help)
            show_help
            ;;
        -*)
            echo -e "${RED}❌ Unknown option: $1${NC}" >&2
            echo "Use --help to see available options" >&2
            exit 1
            ;;
        *)
            if [[ -z "$SERVICE_NAME" ]]; then
                SERVICE_NAME="$1"
            else
                echo -e "${RED}❌ Multiple service names provided. Only one allowed.${NC}" >&2
                exit 1
            fi
            shift
            ;;
    esac
done

# Validate required arguments
if [[ -z "$SERVICE_NAME" ]]; then
    echo -e "${RED}❌ Error: Service name is required${NC}" >&2
    echo "" >&2
    echo "Usage: $0 <service-name> [options]" >&2
    echo "Use --help for more information" >&2
    exit 1
fi

# Validate --compare-with file exists
if [[ -n "$COMPARE_WITH_FILE" ]]; then
    if [[ ! -f "$COMPARE_WITH_FILE" ]]; then
        echo -e "${RED}❌ Error: Log file not found: $COMPARE_WITH_FILE${NC}" >&2
        exit 1
    fi
fi

# Pre-flight checks
if [[ "$JSON_MODE" == false ]]; then
    echo -e "${BLUE}🔍 Querying Prometheus for service: ${SERVICE_NAME}${NC}"
    echo -e "${BLUE}   Metric: ${METRIC_NAME}${NC}"
    echo ""
fi

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    if [[ "$JSON_MODE" == false ]]; then
        echo -e "${RED}❌ kubectl not found${NC}" >&2
    else
        echo '{"error": "kubectl not found"}' >&2
    fi
    exit 1
fi

# Check if Prometheus service exists
if ! kubectl get svc -n monitoring prometheus-server &> /dev/null; then
    if [[ "$JSON_MODE" == false ]]; then
        echo -e "${RED}❌ Prometheus service not found in monitoring namespace${NC}" >&2
        echo -e "${YELLOW}   Make sure the monitoring stack is deployed${NC}" >&2
    else
        echo '{"error": "Prometheus service not found in monitoring namespace"}' >&2
    fi
    exit 1
fi

# Build PromQL query
PROMQL_QUERY="${METRIC_NAME}{service_name=\"${SERVICE_NAME}\"}"

# Calculate query time if time-range is specified
QUERY_TIME=""
if [[ -n "$TIME_RANGE" ]]; then
    # Parse time range (1h, 30m, 5m, etc.) and calculate unix timestamp
    DURATION_SECONDS=0
    if [[ $TIME_RANGE =~ ^([0-9]+)h$ ]]; then
        DURATION_SECONDS=$((${BASH_REMATCH[1]} * 3600))
    elif [[ $TIME_RANGE =~ ^([0-9]+)m$ ]]; then
        DURATION_SECONDS=$((${BASH_REMATCH[1]} * 60))
    elif [[ $TIME_RANGE =~ ^([0-9]+)s$ ]]; then
        DURATION_SECONDS=${BASH_REMATCH[1]}
    else
        echo -e "${RED}❌ Invalid time range format: $TIME_RANGE${NC}" >&2
        echo "Use format like: 1h, 30m, 5m" >&2
        exit 1
    fi

    # Calculate timestamp (current time - duration)
    QUERY_TIME=$(date -d "@$(($(date +%s) - DURATION_SECONDS))" +%s)
fi

# Query Prometheus
if [[ "$JSON_MODE" == false ]]; then
    echo -e "${BLUE}📡 Querying Prometheus...${NC}"
    if [[ -n "$QUERY_TIME" ]]; then
        echo -e "${BLUE}   Time: ${TIME_RANGE} ago${NC}"
    fi
fi

# Execute query using kubectl run with curl
if [[ -n "$QUERY_TIME" ]]; then
    # Query with time parameter (historical point in time)
    QUERY_RAW=$(kubectl run curl-prometheus-query --image=curlimages/curl --rm -i --restart=Never -n monitoring -- \
        curl -s -G \
        --data-urlencode "query=${PROMQL_QUERY}" \
        --data-urlencode "time=${QUERY_TIME}" \
        http://prometheus-server.monitoring.svc.cluster.local:80/api/v1/query 2>&1) || {
        if [[ "$JSON_MODE" == false ]]; then
            echo -e "${RED}❌ Failed to query Prometheus${NC}" >&2
            echo -e "${YELLOW}   Error: ${QUERY_RAW}${NC}" >&2
        else
            echo "{\"error\": \"Failed to query Prometheus\", \"details\": \"${QUERY_RAW}\"}" >&2
        fi
        exit 1
    }
else
    # Instant query (no time parameter)
    QUERY_RAW=$(kubectl run curl-prometheus-query --image=curlimages/curl --rm -i --restart=Never -n monitoring -- \
        curl -s -G \
        --data-urlencode "query=${PROMQL_QUERY}" \
        http://prometheus-server.monitoring.svc.cluster.local:80/api/v1/query 2>&1) || {
        if [[ "$JSON_MODE" == false ]]; then
            echo -e "${RED}❌ Failed to query Prometheus${NC}" >&2
            echo -e "${YELLOW}   Error: ${QUERY_RAW}${NC}" >&2
        else
            echo "{\"error\": \"Failed to query Prometheus\", \"details\": \"${QUERY_RAW}\"}" >&2
        fi
        exit 1
    }
fi

# Extract the JSON object from the raw output. `kubectl run -i` can prepend or
# append non-JSON noise (audit banners, "pod deleted" messages, TTY hints,
# and sometimes a duplicated replay of the output when it falls back from
# attach to streaming logs) — which noise appears is not deterministic, so
# rather than blacklist known strings, pull out the first complete JSON
# object wherever it starts.
QUERY_RESULT=$(printf '%s' "$QUERY_RAW" | python3 -c '
import sys, json
raw = sys.stdin.read()
start = raw.find("{")
if start == -1:
    print(raw, end="")
    sys.exit(1)
try:
    obj, _ = json.JSONDecoder().raw_decode(raw, start)
    print(json.dumps(obj))
except json.JSONDecodeError:
    print(raw, end="")
    sys.exit(1)
') || {
    if [[ "$JSON_MODE" == false ]]; then
        echo -e "${RED}❌ Failed to parse Prometheus response${NC}" >&2
        echo -e "${YELLOW}   Raw output: ${QUERY_RESULT}${NC}" >&2
    else
        echo "{\"error\": \"Failed to parse Prometheus response\", \"details\": \"${QUERY_RESULT}\"}" >&2
    fi
    exit 1
}

# Check if query was successful
if ! echo "$QUERY_RESULT" | jq -e '.status == "success"' &> /dev/null; then
    if [[ "$JSON_MODE" == false ]]; then
        echo -e "${RED}❌ Query failed${NC}" >&2
        echo -e "${YELLOW}   Response: ${QUERY_RESULT}${NC}" >&2
    else
        echo "$QUERY_RESULT" >&2
    fi
    exit 1
fi

# Output based on mode
if [[ "$JSON_MODE" == true ]]; then
    # JSON mode: Three-step validation sequence
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    # STEP 1: Verify Prometheus response has data (already done above at line 218-228)
    # Query was successful and returned data, proceed with validation if requested

    # STEP 2: Validate response against schema (if --validate flag provided)
    if [[ "$VALIDATE_MODE" == true ]]; then
        VALIDATOR_SCRIPT="$SCRIPT_DIR/../validators/validate-prometheus-response.py"

        if [[ ! -f "$VALIDATOR_SCRIPT" ]]; then
            echo -e "${RED}❌ Validator script not found: ${VALIDATOR_SCRIPT}${NC}" >&2
            exit 1
        fi

        # Pipe query result to schema validator
        echo "$QUERY_RESULT" | python3 "$VALIDATOR_SCRIPT" -
        VALIDATE_EXIT=$?

        if [[ $VALIDATE_EXIT -ne 0 ]]; then
            # Schema validation failed, exit before consistency check
            exit $VALIDATE_EXIT
        fi

        # If only validating (no --compare-with), exit successfully
        if [[ -z "$COMPARE_WITH_FILE" ]]; then
            exit 0
        fi
    fi

    # STEP 3: Compare with log file for consistency (if --compare-with flag provided)
    if [[ -n "$COMPARE_WITH_FILE" ]]; then
        CONSISTENCY_SCRIPT="$SCRIPT_DIR/../validators/validate-prometheus-consistency.py"

        if [[ ! -f "$CONSISTENCY_SCRIPT" ]]; then
            echo -e "${RED}❌ Consistency validator not found: ${CONSISTENCY_SCRIPT}${NC}" >&2
            exit 1
        fi

        # Pipe query result to consistency validator with log file
        echo "$QUERY_RESULT" | python3 "$CONSISTENCY_SCRIPT" "$COMPARE_WITH_FILE" -
        exit $?
    fi

    # No validation requested, just output raw JSON
    echo "$QUERY_RESULT"
else
    # Human-readable mode: parse and display
    RESULT_COUNT=$(echo "$QUERY_RESULT" | jq -r '.data.result | length')

    if [[ "$RESULT_COUNT" == "0" ]]; then
        echo -e "${YELLOW}⚠️  No metrics found for service: ${SERVICE_NAME}${NC}"
        echo -e "${YELLOW}   Metric: ${METRIC_NAME}${NC}"
        exit 1
    fi

    echo -e "${GREEN}✅ Found ${RESULT_COUNT} metric series for '${SERVICE_NAME}'${NC}"

    # Calculate total operations (sum of all metric values)
    TOTAL_OPS=$(echo "$QUERY_RESULT" | jq -r '[.data.result[].value[1] | tonumber] | add')
    echo -e "${GREEN}✅ Total operations: ${TOTAL_OPS}${NC}"

    # Show sample of first metric
    FIRST_METRIC=$(echo "$QUERY_RESULT" | jq '.data.result[0].metric' 2>/dev/null)

    if [[ -n "$FIRST_METRIC" && "$FIRST_METRIC" != "null" ]]; then
        echo ""
        echo -e "${BLUE}📋 Sample metric labels:${NC}"

        # Extract key labels (Prometheus uses snake_case)
        LOG_LEVEL=$(echo "$FIRST_METRIC" | jq -r '.log_level // "N/A"')
        LOG_TYPE=$(echo "$FIRST_METRIC" | jq -r '.log_type // "N/A"')
        PEER_SERVICE=$(echo "$FIRST_METRIC" | jq -r '.peer_service // "N/A"')

        echo -e "   log_level:    ${LOG_LEVEL}"
        echo -e "   log_type:     ${LOG_TYPE}"
        echo -e "   peer_service: ${PEER_SERVICE}"

        # Show label count
        LABEL_COUNT=$(echo "$FIRST_METRIC" | jq 'keys | length')
        echo -e "   (${LABEL_COUNT} total labels)"
    fi

    echo ""
    echo -e "${GREEN}✅ Prometheus query successful${NC}"
    echo ""
    echo -e "${BLUE}💡 Tip: Use --json flag to get full JSON output for verification${NC}"
fi

exit 0
