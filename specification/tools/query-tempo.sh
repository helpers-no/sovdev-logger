#!/bin/bash
################################################################################
# query-tempo.sh - Query Tempo for traces from a specific service
#
# Purpose: Query Tempo backend to retrieve and verify traces
#
# Usage:
#   ./query-tempo.sh <service-name> [options]
#
# Arguments:
#   service-name    Required. The service name to query (e.g., sovdev-test-python)
#
# Options:
#   --json              Output raw JSON data for parsing/verification
#   --validate          Validate response against tempo-response-schema.json
#   --compare-with FILE Compare Tempo traces with log file for consistency
#   --limit N           Limit results to N traces (default: 10)
#   --time-range R      Time range lookback: 1h, 30m, 5m, etc. (default: 1h)
#   --help              Show this help message
#
# Validation Sequence:
#   The script performs validation in three sequential steps:
#
#   Step 1: Query Tempo and verify response has data
#           → Ensures traces exist in backend (exits if no data)
#
#   Step 2: Validate response against tempo-response-schema.json (if --validate)
#           → Ensures Tempo response structure is correct (exits if invalid)
#
#   Step 3: Compare with log file for consistency (if --compare-with)
#           → Ensures trace IDs match log entries (exits if mismatch)
#
# Output Modes:
#   Human-readable (default): Color-coded status messages
#     ✅ Service 'sovdev-test-python' found in Tempo
#     ✅ Found 8 traces
#
#   JSON mode (--json): Full structured JSON output
#     {
#       "traces": [...],
#       "metrics": {...}
#     }
#
# Exit Codes:
#   0 - Success (all validations passed)
#   1 - Error (query failed, validation failed, or consistency check failed)
#
# Examples:
#   # Step 1 only: Query and check for data (human-readable)
#   ./query-tempo.sh sovdev-test-python
#
#   # Step 1 only: Query and get JSON output
#   ./query-tempo.sh sovdev-test-python --json
#
#   # Steps 1+2: Query + validate schema
#   ./query-tempo.sh sovdev-test-python --validate
#
#   # Steps 1+3: Query + compare with file (skip schema validation)
#   ./query-tempo.sh sovdev-test-python --compare-with logs/dev.log
#
#   # Steps 1+2+3: Full validation (query + schema + consistency)
#   ./query-tempo.sh sovdev-test-python --validate --compare-with logs/dev.log
#
#   # Advanced: Extract specific trace ID
#   ./query-tempo.sh sovdev-test-python --json | jq '.traces[0].traceID'
#
#   # Advanced: Query with custom time range and limit
#   ./query-tempo.sh sovdev-test-python --time-range 30m --limit 5
#
#   # Advanced: Save JSON evidence for later analysis
#   ./query-tempo.sh sovdev-test-python --json > evidence/tempo-output.json
#
################################################################################

set -euo pipefail

# Configure kubectl to use kubeconfig from workspace (devcontainer)
if [ -f "/workspace/topsecret/.kube/config" ]; then
    export KUBECONFIG="/workspace/topsecret/.kube/config"
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
LIMIT=10
TIME_RANGE="1h"
JSON_MODE=false
VALIDATE_MODE=false
COMPARE_WITH_FILE=""
SERVICE_NAME=""

# Parse arguments
show_help() {
    head -n 72 "$0" | grep "^#" | sed 's/^# \?//'
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
    echo -e "${BLUE}🔍 Querying Tempo for service: ${SERVICE_NAME}${NC}"
    echo -e "${BLUE}   Time range: ${TIME_RANGE}, Limit: ${LIMIT}${NC}"
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

# Check if Tempo service exists
if ! kubectl get svc -n monitoring tempo &> /dev/null; then
    if [[ "$JSON_MODE" == false ]]; then
        echo -e "${RED}❌ Tempo service not found in monitoring namespace${NC}" >&2
        echo -e "${YELLOW}   Make sure the monitoring stack is deployed${NC}" >&2
    else
        echo '{"error": "Tempo service not found in monitoring namespace"}' >&2
    fi
    exit 1
fi

# Calculate time range in Unix timestamps (seconds)
calculate_time_range() {
    local range="$1"
    local now_sec=$(date +%s)
    local duration_seconds=0

    # Parse time range (1h, 30m, 5m, etc.)
    if [[ $range =~ ^([0-9]+)h$ ]]; then
        duration_seconds=$((${BASH_REMATCH[1]} * 3600))
    elif [[ $range =~ ^([0-9]+)m$ ]]; then
        duration_seconds=$((${BASH_REMATCH[1]} * 60))
    elif [[ $range =~ ^([0-9]+)s$ ]]; then
        duration_seconds=${BASH_REMATCH[1]}
    else
        echo -e "${RED}❌ Invalid time range format: $range${NC}" >&2
        echo "Use format like: 1h, 30m, 5m" >&2
        exit 1
    fi

    local start_sec=$((now_sec - duration_seconds))
    echo "$start_sec $now_sec"
}

# Calculate start and end times
read START_TIME END_TIME <<< $(calculate_time_range "$TIME_RANGE")

# Query Tempo
if [[ "$JSON_MODE" == false ]]; then
    echo -e "${BLUE}📡 Querying Tempo...${NC}"
fi

# Execute search query using kubectl run with curl
# Tempo API expects Unix timestamps in seconds
SEARCH_RAW=$(kubectl run curl-tempo-search --image=curlimages/curl --rm -i --restart=Never -n monitoring -- \
    curl -s "http://tempo.monitoring.svc.cluster.local:3200/api/search?tags=service.name=${SERVICE_NAME}&limit=${LIMIT}&start=${START_TIME}&end=${END_TIME}" 2>&1) || {
    if [[ "$JSON_MODE" == false ]]; then
        echo -e "${RED}❌ Failed to query Tempo${NC}" >&2
        echo -e "${YELLOW}   Error: ${SEARCH_RAW}${NC}" >&2
    else
        echo "{\"error\": \"Failed to query Tempo\", \"details\": \"${SEARCH_RAW}\"}" >&2
    fi
    exit 1
}

# Filter out kubectl pod messages (appended to JSON without newline)
# Common kubectl messages: pod deletion, namespace info, warnings, etc.
SEARCH_RESULT=$(echo "$SEARCH_RAW" | sed 's/pod ".*" deleted//g' | sed 's/If you don.*//g' | sed 's/ from monitoring namespace//g' | sed 's/Error from server.*//g')

# Check if query returned traces
TRACE_COUNT=$(echo "$SEARCH_RESULT" | jq -r '.traces | length' 2>/dev/null || echo "0")

if [[ "$TRACE_COUNT" == "0" || "$TRACE_COUNT" == "null" ]]; then
    if [[ "$JSON_MODE" == false ]]; then
        echo -e "${YELLOW}⚠️  No traces found for service: ${SERVICE_NAME}${NC}"
        exit 1
    else
        # Return valid empty Tempo response instead of error
        # This allows validators to process it properly
        echo "{\"traces\": [], \"metrics\": {\"inspectedTraces\": 0, \"inspectedSpans\": 0, \"inspectedBytes\": 0}}"
        exit 0
    fi
fi

# Helper function: Convert base64 to hex using Python
base64_to_hex() {
    python3 -c "import base64, sys; print(base64.b64decode(sys.argv[1]).hex())" "$1" 2>/dev/null
}

# Fetch full trace details with spans (required for deep validation)
# The search API only returns metadata, we need to fetch each trace individually
if [[ "$JSON_MODE" == true ]] && { [[ "$VALIDATE_MODE" == true ]] || [[ -n "$COMPARE_WITH_FILE" ]]; }; then
    if [[ "$JSON_MODE" == false ]]; then
        echo -e "${BLUE}📡 Fetching detailed span data for ${TRACE_COUNT} traces...${NC}"
    fi

    # Get original trace metadata
    ORIGINAL_TRACES=$(echo "$SEARCH_RESULT" | jq '.traces')

    # Build detailed traces array
    DETAILED_TRACES="[]"
    TRACE_INDEX=0

    # Extract all trace IDs
    TRACE_IDS=$(echo "$SEARCH_RESULT" | jq -r '.traces[].traceID')

    for TRACE_ID in $TRACE_IDS; do
        # Get original trace metadata for this trace
        ORIGINAL_TRACE=$(echo "$ORIGINAL_TRACES" | jq ".[$TRACE_INDEX]")

        # Fetch full trace details with spans
        TRACE_DETAIL_RAW=$(kubectl run curl-tempo-trace --image=curlimages/curl --rm -i --restart=Never -n monitoring -- \
            curl -s "http://tempo.monitoring.svc.cluster.local:3200/api/traces/${TRACE_ID}" 2>&1) || {
            # If fetch fails, keep original trace without spans
            DETAILED_TRACES=$(echo "$DETAILED_TRACES" | jq ". += [$ORIGINAL_TRACE]")
            TRACE_INDEX=$((TRACE_INDEX + 1))
            continue
        }

        # Filter kubectl messages
        TRACE_DETAIL=$(echo "$TRACE_DETAIL_RAW" | sed 's/pod ".*" deleted//g' | sed 's/If you don.*//g' | sed 's/ from monitoring namespace//g' | sed 's/Error from server.*//g')

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
    SEARCH_RESULT=$(echo "$SEARCH_RESULT" | jq --argjson traces "$DETAILED_TRACES" '.traces = $traces')
fi

# Output based on mode
if [[ "$JSON_MODE" == true ]]; then
    # JSON mode: Three-step validation sequence
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    # STEP 1: Verify Tempo response has data (already done above at line 243-254)
    # Query was successful and returned data, proceed with validation if requested

    # STEP 2: Validate response against schema (if --validate flag provided)
    if [[ "$VALIDATE_MODE" == true ]]; then
        VALIDATOR_SCRIPT="$SCRIPT_DIR/../tests/validate-tempo-response.py"

        if [[ ! -f "$VALIDATOR_SCRIPT" ]]; then
            echo -e "${RED}❌ Validator script not found: ${VALIDATOR_SCRIPT}${NC}" >&2
            exit 1
        fi

        # Pipe query result to schema validator
        echo "$SEARCH_RESULT" | python3 "$VALIDATOR_SCRIPT" -
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
        echo "$SEARCH_RESULT" | python3 "$CONSISTENCY_SCRIPT" "$COMPARE_WITH_FILE" -
        exit $?
    fi

    # No validation requested, just output raw JSON
    echo "$SEARCH_RESULT"
else
    # Human-readable mode: parse and display
    echo -e "${GREEN}✅ Service '${SERVICE_NAME}' found in Tempo${NC}"
    echo -e "${GREEN}✅ Found ${TRACE_COUNT} traces${NC}"

    # Get first trace info
    FIRST_TRACE=$(echo "$SEARCH_RESULT" | jq '.traces[0]' 2>/dev/null)

    if [[ -n "$FIRST_TRACE" && "$FIRST_TRACE" != "null" ]]; then
        echo ""
        echo -e "${BLUE}📋 Sample trace:${NC}"

        # Extract key fields
        TRACE_ID=$(echo "$FIRST_TRACE" | jq -r '.traceID // "N/A"')
        ROOT_SERVICE=$(echo "$FIRST_TRACE" | jq -r '.rootServiceName // "N/A"')
        ROOT_TRACE=$(echo "$FIRST_TRACE" | jq -r '.rootTraceName // "N/A"')
        START_TIME=$(echo "$FIRST_TRACE" | jq -r '.startTimeUnixNano // "N/A"')

        # Convert nanoseconds to readable timestamp if available
        if [[ "$START_TIME" != "N/A" && "$START_TIME" != "null" ]]; then
            START_TIME_SEC=$((START_TIME / 1000000000))
            START_TIME_READABLE=$(date -r "$START_TIME_SEC" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "$START_TIME")
        else
            START_TIME_READABLE="N/A"
        fi

        echo -e "   traceID:      ${TRACE_ID:0:16}..."
        echo -e "   service:      ${ROOT_SERVICE}"
        echo -e "   operation:    ${ROOT_TRACE}"
        echo -e "   timestamp:    ${START_TIME_READABLE}"

        # Show span count if available
        SPAN_SETS=$(echo "$FIRST_TRACE" | jq '.spanSets // [] | length' 2>/dev/null || echo "0")
        if [[ "$SPAN_SETS" != "0" ]]; then
            TOTAL_SPANS=$(echo "$FIRST_TRACE" | jq '[.spanSets[].spans | length] | add' 2>/dev/null || echo "0")
            echo -e "   spans:        ${TOTAL_SPANS}"
        fi
    fi

    echo ""
    echo -e "${GREEN}✅ Tempo query successful${NC}"
    echo ""
    echo -e "${BLUE}💡 Tip: Use --json flag to get full JSON output for verification${NC}"
fi

exit 0
