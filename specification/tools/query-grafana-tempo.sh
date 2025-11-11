#!/bin/bash
################################################################################
# query-grafana-tempo.sh - Query Tempo THROUGH Grafana datasource proxy
#
# Purpose: Query Tempo via Grafana's datasource proxy API to validate
#          Grafana can correctly query Tempo traces
#
# Usage:
#   ./query-grafana-tempo.sh <service-name> [options]
#
# Arguments:
#   service-name    Required. The service name to query
#
# Options:
#   --json              Output raw JSON data for parsing/verification
#   --validate          Validate response against tempo-response-schema.json
#   --compare-with FILE Compare Tempo traces with log file for consistency
#   --limit N           Limit results to N traces (default: 20)
#   --help              Show this help message
#
# Output:
#   Same JSON format as query-tempo.sh (Tempo API response)
#
# Datasource Proxy:
#   Queries: http://grafana/api/datasources/proxy/3/api/search
#   Where: 3 = Tempo datasource ID in Grafana
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
LIMIT=20
JSON_MODE=false
VALIDATE_MODE=false
COMPARE_WITH_FILE=""
SERVICE_NAME=""

# Grafana access (via Traefik ingress)
GRAFANA_HOST="host.docker.internal"
GRAFANA_HEADER="Host: grafana.localhost"
GRAFANA_USER="admin"
GRAFANA_PASSWORD="SecretPassword1"
TEMPO_DATASOURCE_ID="3"  # Tempo is datasource 3 in Grafana

# Parse arguments
show_help() {
    head -n 27 "$0" | grep "^#" | sed 's/^# \?//'
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
        --limit)
            LIMIT="$2"
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

# Validate --compare-with file exists and increase limit
if [[ -n "$COMPARE_WITH_FILE" ]]; then
    if [[ ! -f "$COMPARE_WITH_FILE" ]]; then
        echo -e "${RED}❌ Error: Log file not found: $COMPARE_WITH_FILE${NC}" >&2
        exit 1
    fi

    # For Tempo, we need enough limit to capture all traces
    # Set a higher limit to ensure we get all traces for validation
    if [[ $LIMIT -lt 50 ]]; then
        LIMIT=50
    fi
fi

# Pre-flight checks
if [[ "$JSON_MODE" == false ]]; then
    echo -e "${BLUE}🔍 Querying Tempo via Grafana datasource proxy${NC}"
    echo -e "${BLUE}   Service: ${SERVICE_NAME}${NC}"
    echo -e "${BLUE}   Limit: ${LIMIT}${NC}"
    echo ""
fi

# Check if curl is available
if ! command -v curl &> /dev/null; then
    echo -e "${RED}❌ curl not found${NC}" >&2
    exit 1
fi

# Calculate time range (last 1 hour)
NOW=$(date +%s)
START=$((NOW - 3600))

# Build TraceQL query (Tempo search uses service.name attribute)
# Note: Tempo uses 'service.name' internally, but our logs use 'service_name'
TEMPO_QUERY="{.service.name=\"${SERVICE_NAME}\"}"

# Query Tempo through Grafana datasource proxy
if [[ "$JSON_MODE" == false ]]; then
    echo -e "${BLUE}📡 Querying via Grafana datasource proxy...${NC}"
fi

# Grafana datasource proxy URL: /api/datasources/proxy/{datasource-id}/{backend-path}
QUERY_RESULT=$(curl -s -u "${GRAFANA_USER}:${GRAFANA_PASSWORD}" \
    -H "${GRAFANA_HEADER}" \
    -G \
    --data-urlencode "q=${TEMPO_QUERY}" \
    --data-urlencode "start=${START}" \
    --data-urlencode "end=${NOW}" \
    --data-urlencode "limit=${LIMIT}" \
    "http://${GRAFANA_HOST}/api/datasources/proxy/${TEMPO_DATASOURCE_ID}/api/search" 2>&1) || {
    echo -e "${RED}❌ Failed to query Tempo via Grafana${NC}" >&2
    exit 1
}

# Check if response is valid JSON
if ! echo "$QUERY_RESULT" | jq empty &> /dev/null 2>&1; then
    if [[ "$JSON_MODE" == false ]]; then
        echo -e "${RED}❌ Invalid JSON response${NC}" >&2
        echo -e "${YELLOW}   Response: ${QUERY_RESULT}${NC}" >&2
    else
        echo '{"error": "Invalid JSON response"}' >&2
    fi
    exit 1
fi

# Check if traces array exists
if ! echo "$QUERY_RESULT" | jq -e '.traces' &> /dev/null; then
    if [[ "$JSON_MODE" == false ]]; then
        echo -e "${RED}❌ No traces field in response${NC}" >&2
        echo -e "${YELLOW}   Response: ${QUERY_RESULT}${NC}" >&2
    else
        echo "$QUERY_RESULT" >&2
    fi
    exit 1
fi

# Helper function: Convert base64 to hex using Python
base64_to_hex() {
    python3 -c "import base64, sys; print(base64.b64decode(sys.argv[1]).hex())" "$1" 2>/dev/null
}

# Fetch full trace details with spans (required for deep validation)
# The search API only returns metadata, we need to fetch each trace individually
if [[ "$JSON_MODE" == true ]] && { [[ "$VALIDATE_MODE" == true ]] || [[ -n "$COMPARE_WITH_FILE" ]]; }; then
    # Get original trace metadata
    ORIGINAL_TRACES=$(echo "$QUERY_RESULT" | jq '.traces')
    TRACE_COUNT=$(echo "$ORIGINAL_TRACES" | jq 'length')

    # Skip trace details if no traces found
    if [[ "$TRACE_COUNT" != "0" ]]; then
        # Build detailed traces array
        DETAILED_TRACES="[]"
        TRACE_INDEX=0

        # Extract all trace IDs
        TRACE_IDS=$(echo "$QUERY_RESULT" | jq -r '.traces[].traceID')

        for TRACE_ID in $TRACE_IDS; do
            # Get original trace metadata for this trace
            ORIGINAL_TRACE=$(echo "$ORIGINAL_TRACES" | jq ".[$TRACE_INDEX]")

            # Fetch full trace details with spans THROUGH GRAFANA PROXY
            TRACE_DETAIL=$(curl -s -u "${GRAFANA_USER}:${GRAFANA_PASSWORD}" \
                -H "${GRAFANA_HEADER}" \
                "http://${GRAFANA_HOST}/api/datasources/proxy/${TEMPO_DATASOURCE_ID}/api/traces/${TRACE_ID}" 2>&1) || {
                # If fetch fails, keep original trace without spans
                DETAILED_TRACES=$(echo "$DETAILED_TRACES" | jq ". += [$ORIGINAL_TRACE]")
                TRACE_INDEX=$((TRACE_INDEX + 1))
                continue
            }

            # Transform Tempo API response to validator-expected format
            # Convert base64 IDs to hex for comparison with log files
            if echo "$TRACE_DETAIL" | jq -e '.batches' &> /dev/null; then
                # First extract span data with base64 IDs
                SPANS_JSON=$(echo "$TRACE_DETAIL" | jq -c '.batches[].scopeSpans[].spans[]')

                # Build spans array with hex IDs
                SPANS_ARRAY="[]"
                while IFS= read -r span; do
                    [[ -z "$span" ]] && continue

                    SPAN_ID_B64=$(echo "$span" | jq -r '.spanId')
                    TRACE_ID_B64=$(echo "$span" | jq -r '.traceId')

                    # Convert base64 to hex
                    SPAN_ID_HEX=$(base64_to_hex "$SPAN_ID_B64")
                    TRACE_ID_HEX=$(base64_to_hex "$TRACE_ID_B64")

                    # Build span with hex IDs (durationNanos as string for schema compliance)
                    SPAN_TRANSFORMED=$(echo "$span" | jq --arg sid "$SPAN_ID_HEX" --arg tid "$TRACE_ID_HEX" '{
                        spanID: $sid,
                        traceID: $tid,
                        operationName: .name,
                        startTimeUnixNano: .startTimeUnixNano,
                        durationNanos: ((((.endTimeUnixNano | tonumber) - (.startTimeUnixNano | tonumber)) | tostring)),
                        attributes: .attributes,
                        status: (if .status.code == "STATUS_CODE_ERROR" then {code: 2} else {code: 0} end)
                    }')

                    SPANS_ARRAY=$(echo "$SPANS_ARRAY" | jq ". += [$SPAN_TRANSFORMED]")
                done <<< "$SPANS_JSON"

                # Add spanSets to original trace metadata
                TRACE_WITH_SPANS=$(echo "$ORIGINAL_TRACE" | jq --argjson spans "$SPANS_ARRAY" '. + {spanSets: [{spans: $spans}]}')
                DETAILED_TRACES=$(echo "$DETAILED_TRACES" | jq ". += [$TRACE_WITH_SPANS]")
            else
                # No batches, keep original trace
                DETAILED_TRACES=$(echo "$DETAILED_TRACES" | jq ". += [$ORIGINAL_TRACE]")
            fi

            TRACE_INDEX=$((TRACE_INDEX + 1))
        done

        # Replace search result with detailed traces
        QUERY_RESULT=$(echo "$QUERY_RESULT" | jq --argjson traces "$DETAILED_TRACES" '.traces = $traces')
    fi
fi

# Output based on mode
if [[ "$JSON_MODE" == true ]]; then
    # JSON mode: Three-step validation sequence
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    # STEP 1: Verify Tempo response has data (already done above at line 178-191)
    # Query was successful and returned data, proceed with validation if requested

    # STEP 2: Validate response against schema (if --validate flag provided)
    if [[ "$VALIDATE_MODE" == true ]]; then
        VALIDATOR_SCRIPT="$SCRIPT_DIR/../tests/validate-tempo-response.py"

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
        CONSISTENCY_SCRIPT="$SCRIPT_DIR/../tests/validate-tempo-consistency.py"

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
    TRACE_COUNT=$(echo "$QUERY_RESULT" | jq -r '.traces | length')

    if [[ "$TRACE_COUNT" == "0" ]]; then
        echo -e "${YELLOW}⚠️  No traces found${NC}"
        exit 1
    fi

    echo -e "${GREEN}✅ Found ${TRACE_COUNT} traces via Grafana${NC}"

    echo ""
    echo -e "${GREEN}✅ Tempo query via Grafana successful${NC}"
fi

exit 0
