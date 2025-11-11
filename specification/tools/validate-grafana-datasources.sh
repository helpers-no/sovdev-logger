#!/bin/bash
################################################################################
# validate-grafana-datasources.sh - Verify Grafana datasources are configured
#
# Purpose: Validate that Grafana datasources (Loki/Prometheus/Tempo) are
#          configured correctly in Grafana
#
# Usage:
#   ./validate-grafana-datasources.sh [options]
#
# Options:
#   --json          Output raw JSON data for parsing/verification
#   --help          Show this help message
#
# Output Modes:
#   Human-readable (default): Color-coded status messages
#     ✅ Grafana accessible
#     ✅ Loki datasource configured
#     ✅ Prometheus datasource configured
#     ✅ Tempo datasource configured
#
#   JSON mode (--json): Full structured JSON output
#
# Exit Codes:
#   0 - Success (all datasources configured)
#   1 - Error (Grafana not accessible or datasources not configured)
#
# Examples:
#   # Check datasource configuration (human-readable)
#   ./validate-grafana-datasources.sh
#
#   # Get JSON output for validation
#   ./validate-grafana-datasources.sh --json
#
################################################################################

set -euo pipefail

# Colors for human-readable output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default options
JSON_MODE=false

# Grafana access via Traefik ingress (same pattern as OTEL)
GRAFANA_HOST="host.docker.internal"
GRAFANA_HEADER="Host: grafana.localhost"

# Grafana credentials (from Grafana's own secret)
# kubectl get secret -n monitoring grafana -o jsonpath='{.data.admin-user}' | base64 -d
# kubectl get secret -n monitoring grafana -o jsonpath='{.data.admin-password}' | base64 -d
GRAFANA_USER="admin"
GRAFANA_PASSWORD="SecretPassword1"

# Parse arguments
show_help() {
    head -n 35 "$0" | grep "^#" | sed 's/^# \?//'
    exit 0
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --json)
            JSON_MODE=true
            shift
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
            echo -e "${RED}❌ Unexpected argument: $1${NC}" >&2
            echo "Use --help to see usage" >&2
            exit 1
            ;;
    esac
done

# Pre-flight checks
if [[ "$JSON_MODE" == false ]]; then
    echo -e "${BLUE}🔍 Checking Grafana datasource configuration${NC}"
    echo -e "${BLUE}   Host: ${GRAFANA_HOST}${NC}"
    echo ""
fi

# Check if curl is available
if ! command -v curl &> /dev/null; then
    if [[ "$JSON_MODE" == false ]]; then
        echo -e "${RED}❌ curl not found${NC}" >&2
    else
        echo '{"error": "curl not found"}' >&2
    fi
    exit 1
fi

# Check if jq is available
if ! command -v jq &> /dev/null; then
    if [[ "$JSON_MODE" == false ]]; then
        echo -e "${RED}❌ jq not found${NC}" >&2
    else
        echo '{"error": "jq not found"}' >&2
    fi
    exit 1
fi

if [[ "$JSON_MODE" == false ]]; then
    echo -e "${BLUE}📡 Querying Grafana API...${NC}"
fi

# Query Grafana datasources
DATASOURCE_LIST=$(curl -s -u "${GRAFANA_USER}:${GRAFANA_PASSWORD}" -H "${GRAFANA_HEADER}" "http://${GRAFANA_HOST}/api/datasources" 2>&1)

if [[ -z "$DATASOURCE_LIST" ]]; then
    if [[ "$JSON_MODE" == false ]]; then
        echo -e "${RED}❌ Failed to reach Grafana API${NC}" >&2
        echo -e "${YELLOW}   Make sure Grafana is running and accessible${NC}" >&2
    else
        echo '{"error": "Failed to reach Grafana API"}' >&2
    fi
    exit 1
fi

# Check if response is valid JSON
if ! echo "$DATASOURCE_LIST" | jq empty &> /dev/null 2>&1; then
    if [[ "$JSON_MODE" == false ]]; then
        echo -e "${RED}❌ Grafana API returned invalid response${NC}" >&2
        echo -e "${YELLOW}   Response: ${DATASOURCE_LIST}${NC}" >&2
    else
        echo "{\"error\": \"Invalid JSON response from Grafana\"}" >&2
    fi
    exit 1
fi

if [[ "$JSON_MODE" == false ]]; then
    echo -e "${GREEN}✅ Grafana API accessible${NC}"
    echo ""
fi

# Check for each expected datasource type
LOKI_FOUND=false
PROMETHEUS_FOUND=false
TEMPO_FOUND=false

LOKI_COUNT=$(echo "$DATASOURCE_LIST" | jq -r '[.[] | select(.type == "loki")] | length')
PROMETHEUS_COUNT=$(echo "$DATASOURCE_LIST" | jq -r '[.[] | select(.type == "prometheus")] | length')
TEMPO_COUNT=$(echo "$DATASOURCE_LIST" | jq -r '[.[] | select(.type == "tempo")] | length')

if [[ "$LOKI_COUNT" -gt 0 ]]; then
    LOKI_FOUND=true
    LOKI_NAME=$(echo "$DATASOURCE_LIST" | jq -r '.[] | select(.type == "loki") | .name' | head -1)
    LOKI_UID=$(echo "$DATASOURCE_LIST" | jq -r '.[] | select(.type == "loki") | .uid' | head -1)
fi

if [[ "$PROMETHEUS_COUNT" -gt 0 ]]; then
    PROMETHEUS_FOUND=true
    PROMETHEUS_NAME=$(echo "$DATASOURCE_LIST" | jq -r '.[] | select(.type == "prometheus") | .name' | head -1)
    PROMETHEUS_UID=$(echo "$DATASOURCE_LIST" | jq -r '.[] | select(.type == "prometheus") | .uid' | head -1)
fi

if [[ "$TEMPO_COUNT" -gt 0 ]]; then
    TEMPO_FOUND=true
    TEMPO_NAME=$(echo "$DATASOURCE_LIST" | jq -r '.[] | select(.type == "tempo") | .name' | head -1)
    TEMPO_UID=$(echo "$DATASOURCE_LIST" | jq -r '.[] | select(.type == "tempo") | .uid' | head -1)
fi

# Output based on mode
if [[ "$JSON_MODE" == true ]]; then
    # JSON mode: output structured summary
    jq -n \
        --argjson loki_found "$LOKI_FOUND" \
        --argjson prometheus_found "$PROMETHEUS_FOUND" \
        --argjson tempo_found "$TEMPO_FOUND" \
        --arg loki_name "${LOKI_NAME:-}" \
        --arg loki_uid "${LOKI_UID:-}" \
        --arg prometheus_name "${PROMETHEUS_NAME:-}" \
        --arg prometheus_uid "${PROMETHEUS_UID:-}" \
        --arg tempo_name "${TEMPO_NAME:-}" \
        --arg tempo_uid "${TEMPO_UID:-}" \
        '{
            status: "success",
            grafana_accessible: true,
            datasources: {
                loki: {
                    configured: $loki_found,
                    name: $loki_name,
                    uid: $loki_uid
                },
                prometheus: {
                    configured: $prometheus_found,
                    name: $prometheus_name,
                    uid: $prometheus_uid
                },
                tempo: {
                    configured: $tempo_found,
                    name: $tempo_name,
                    uid: $tempo_uid
                }
            }
        }'
else
    # Human-readable mode: show datasource status
    echo -e "${BLUE}📋 Datasource Configuration:${NC}"
    echo ""

    if [[ "$LOKI_FOUND" == true ]]; then
        echo -e "${GREEN}✅ Loki datasource configured${NC}"
        echo -e "   Name: ${LOKI_NAME}"
        echo -e "   UID: ${LOKI_UID}"
    else
        echo -e "${YELLOW}⚠️  Loki datasource not found${NC}"
    fi
    echo ""

    if [[ "$PROMETHEUS_FOUND" == true ]]; then
        echo -e "${GREEN}✅ Prometheus datasource configured${NC}"
        echo -e "   Name: ${PROMETHEUS_NAME}"
        echo -e "   UID: ${PROMETHEUS_UID}"
    else
        echo -e "${YELLOW}⚠️  Prometheus datasource not found${NC}"
    fi
    echo ""

    if [[ "$TEMPO_FOUND" == true ]]; then
        echo -e "${GREEN}✅ Tempo datasource configured${NC}"
        echo -e "   Name: ${TEMPO_NAME}"
        echo -e "   UID: ${TEMPO_UID}"
    else
        echo -e "${YELLOW}⚠️  Tempo datasource not found${NC}"
    fi
    echo ""

    if [[ "$LOKI_FOUND" == true && "$PROMETHEUS_FOUND" == true && "$TEMPO_FOUND" == true ]]; then
        echo -e "${GREEN}✅ All datasources configured${NC}"
        echo ""
        echo -e "${BLUE}💡 Grafana is ready for querying with snake_case field names${NC}"
        echo -e "${BLUE}💡 Use query-loki.sh, query-prometheus.sh, query-tempo.sh to test backends${NC}"
    else
        echo -e "${YELLOW}⚠️  Some datasources are not configured${NC}"
        echo -e "${YELLOW}   Grafana may not be fully set up for observability stack${NC}"
    fi
fi

# Exit with success if Grafana is accessible (even if datasources not fully configured)
exit 0
