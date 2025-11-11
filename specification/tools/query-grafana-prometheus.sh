#!/bin/bash
################################################################################
# query-grafana-prometheus.sh - Query Prometheus THROUGH Grafana datasource proxy
#
# Purpose: Query Prometheus via Grafana's datasource proxy API to validate
#          Grafana can correctly query Prometheus metrics with snake_case labels
#
# Usage:
#   ./query-grafana-prometheus.sh <service-name> [options]
#
# Arguments:
#   service-name    Required. The service name to query
#
# Options:
#   --json              Output raw JSON data for parsing/verification
#   --validate          Validate response against prometheus-response-schema.json
#   --compare-with FILE Compare Prometheus metrics with log file for consistency
#   --help              Show this help message
#
# Output:
#   Same JSON format as query-prometheus.sh (Prometheus API response)
#
# Datasource Proxy:
#   Queries: http://grafana/api/datasources/proxy/1/api/v1/query
#   Where: 1 = Prometheus datasource ID in Grafana
#
################################################################################

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Default options
JSON_MODE=false
VALIDATE_MODE=false
COMPARE_WITH_FILE=""
SERVICE_NAME=""

# Grafana access (via Traefik ingress)
GRAFANA_HOST="host.docker.internal"
GRAFANA_HEADER="Host: grafana.localhost"
GRAFANA_USER="admin"
GRAFANA_PASSWORD="SecretPassword1"
PROMETHEUS_DATASOURCE_ID="1"  # Prometheus is datasource 1 in Grafana

# Parse arguments
show_help() {
    head -n 25 "$0" | grep "^#" | sed 's/^# \?//'
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
        --help)
            show_help
            ;;
        -*)
            echo -e "${RED}❌ Unknown option: $1${NC}" >&2
            exit 1
            ;;
        *)
            if [[ -z "$SERVICE_NAME" ]]; then
                SERVICE_NAME="$1"
            else
                echo -e "${RED}❌ Multiple service names provided${NC}" >&2
                exit 1
            fi
            shift
            ;;
    esac
done

# Validate required arguments
if [[ -z "$SERVICE_NAME" ]]; then
    echo -e "${RED}❌ Error: Service name is required${NC}" >&2
    echo "Usage: $0 <service-name> [options]" >&2
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
    echo -e "${BLUE}🔍 Querying Prometheus via Grafana datasource proxy${NC}"
    echo -e "${BLUE}   Service: ${SERVICE_NAME}${NC}"
    echo ""
fi

# Check if curl is available
if ! command -v curl &> /dev/null; then
    echo -e "${RED}❌ curl not found${NC}" >&2
    exit 1
fi

# Build PromQL query (same as query-prometheus.sh)
PROMQL_QUERY="sovdev_operations_total{service_name=\"${SERVICE_NAME}\"}"

# Query Prometheus through Grafana datasource proxy
if [[ "$JSON_MODE" == false ]]; then
    echo -e "${BLUE}📡 Querying via Grafana datasource proxy...${NC}"
fi

# Grafana datasource proxy URL: /api/datasources/proxy/{datasource-id}/{backend-path}
QUERY_RESULT=$(curl -s -u "${GRAFANA_USER}:${GRAFANA_PASSWORD}" \
    -H "${GRAFANA_HEADER}" \
    -G \
    --data-urlencode "query=${PROMQL_QUERY}" \
    "http://${GRAFANA_HOST}/api/datasources/proxy/${PROMETHEUS_DATASOURCE_ID}/api/v1/query" 2>&1) || {
    echo -e "${RED}❌ Failed to query Prometheus via Grafana${NC}" >&2
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

    # STEP 1: Verify Prometheus response has data (already done above at line 129-137)
    # Query was successful and returned data, proceed with validation if requested

    # STEP 2: Validate response against schema (if --validate flag provided)
    if [[ "$VALIDATE_MODE" == true ]]; then
        VALIDATOR_SCRIPT="$SCRIPT_DIR/../tests/validate-prometheus-response.py"

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
        CONSISTENCY_SCRIPT="$SCRIPT_DIR/../tests/validate-prometheus-consistency.py"

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
    # Human-readable mode
    RESULT_COUNT=$(echo "$QUERY_RESULT" | jq -r '.data.result | length')

    if [[ "$RESULT_COUNT" == "0" ]]; then
        echo -e "${YELLOW}⚠️  No metrics found${NC}"
        exit 1
    fi

    echo -e "${GREEN}✅ Found ${RESULT_COUNT} metric series via Grafana${NC}"

    # Count total operations
    TOTAL_OPS=$(echo "$QUERY_RESULT" | jq -r '[.data.result[].value[1] | tonumber] | add')
    echo -e "${GREEN}✅ Total operations: ${TOTAL_OPS}${NC}"

    echo ""
    echo -e "${GREEN}✅ Prometheus query via Grafana successful${NC}"
fi

exit 0
