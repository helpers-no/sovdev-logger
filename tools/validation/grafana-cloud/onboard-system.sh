#!/bin/bash
# filename: tools/validation/grafana-cloud/onboard-system.sh
# description: Verify a new system's Grafana Cloud credentials, then write its handover file -- only if verification passed
#
# Purpose:
#   Closes the gap between "create Access Policies" and "hand credentials
#   to whoever owns the new system" with a single mechanical guarantee: the
#   handover file is only ever written by the same run that just proved the
#   credentials work, using the exact same values. There's no path to
#   handing over an untested config, because the file's existence *is* the
#   proof -- not a separate step someone could forget or skip.
#
#   1. Reads the 3 raw values a contributor gets after creating a system's
#      two Access Policies in the portal (see using/onboarding/index.md
#      steps 2-3): service_name, ingest token, verify token.
#   2. Computes everything else (the Basic Auth header, the full env var
#      set) -- stack-wide constants (OTLP/Loki/Prometheus/Tempo endpoints,
#      Instance IDs) are filled in automatically, confirmed identical for
#      every system on this stack.
#   3. Runs sovdev-selftest for real against those exact values -- the same
#      write+read-back check a real customer runs themselves.
#   4. Only if all 4 checks pass: writes the finished handover file, in the
#      same format as terchris/customer-template-grafana.env -- both the
#      app's own OTLP env vars and sovdev-selftest's own GRAFANA_CLOUD_*
#      vars, ready to send to whoever owns the new system's deploy.
#
# Usage:
#   ./onboard-system.sh <raw-input-file> <output-handover-file>
#
#   Raw input file format: see raw-input.env.example in this directory.
#
# Exit Codes:
#   0 - Verified for real; <output-handover-file> was written.
#   1 - Verification failed, or required input missing -- no handover file
#       written. Nothing to hand over until this passes.

set -o pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

print_step() { echo -e "${BLUE}▶ $1${NC}"; }
print_ok() { echo -e "${GREEN}✅ $1${NC}"; }
print_fail() { echo -e "${RED}❌ $1${NC}" >&2; }

if [ $# -ne 2 ]; then
  echo "Usage: $0 <raw-input-file> <output-handover-file>" >&2
  echo "  See raw-input.env.example for the input file format." >&2
  exit 1
fi

RAW_INPUT="$1"
OUTPUT_FILE="$2"

if [ ! -f "${RAW_INPUT}" ]; then
  print_fail "Raw input file not found: ${RAW_INPUT}"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOVDEV_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

# Stack-wide constants -- confirmed identical for every system on this
# stack (urbalurba). Overridable per raw-input-file, for the day a system
# is ever on a genuinely different stack.
DEFAULT_OTLP_ENDPOINT="https://otlp-gateway-prod-eu-west-0.grafana.net/otlp"
DEFAULT_OTLP_INSTANCE_ID="484308"
DEFAULT_LOKI_URL="https://logs-prod-eu-west-0.grafana.net"
DEFAULT_LOKI_INSTANCE_ID="333665"
DEFAULT_PROMETHEUS_URL="https://prometheus-prod-01-eu-west-0.grafana.net"
DEFAULT_PROMETHEUS_INSTANCE_ID="669389"
DEFAULT_TEMPO_URL="https://tempo-eu-west-0.grafana.net"
DEFAULT_TEMPO_INSTANCE_ID="330178"

set -a
source "${RAW_INPUT}"
set +a

if [ -z "${SERVICE_NAME}" ] || [ -z "${INGEST_TOKEN}" ] || [ -z "${VERIFY_TOKEN}" ]; then
  print_fail "SERVICE_NAME, INGEST_TOKEN, and VERIFY_TOKEN are all required in ${RAW_INPUT}"
  exit 1
fi

OTLP_ENDPOINT="${OVERRIDE_OTLP_ENDPOINT:-$DEFAULT_OTLP_ENDPOINT}"
OTLP_INSTANCE_ID="${OVERRIDE_OTLP_INSTANCE_ID:-$DEFAULT_OTLP_INSTANCE_ID}"
LOKI_URL="${OVERRIDE_LOKI_URL:-$DEFAULT_LOKI_URL}"
LOKI_INSTANCE_ID="${OVERRIDE_LOKI_INSTANCE_ID:-$DEFAULT_LOKI_INSTANCE_ID}"
PROMETHEUS_URL="${OVERRIDE_PROMETHEUS_URL:-$DEFAULT_PROMETHEUS_URL}"
PROMETHEUS_INSTANCE_ID="${OVERRIDE_PROMETHEUS_INSTANCE_ID:-$DEFAULT_PROMETHEUS_INSTANCE_ID}"
TEMPO_URL="${OVERRIDE_TEMPO_URL:-$DEFAULT_TEMPO_URL}"
TEMPO_INSTANCE_ID="${OVERRIDE_TEMPO_INSTANCE_ID:-$DEFAULT_TEMPO_INSTANCE_ID}"

HEADER_B64=$(echo -n "${OTLP_INSTANCE_ID}:${INGEST_TOKEN}" | base64 | tr -d '\n')

print_step "Building sovdev-logger (ensures sovdev-selftest reflects current source, not a stale dist/)"
(cd "${SOVDEV_ROOT}/typescript" && npm run build) > /tmp/onboard-system-build.log 2>&1
if [ $? -ne 0 ]; then
  print_fail "Build failed -- see /tmp/onboard-system-build.log"
  exit 1
fi
print_ok "Build clean"

print_step "Verifying ${SERVICE_NAME}'s credentials for real (sovdev-selftest)"
export OTEL_SERVICE_NAME="${SERVICE_NAME}"
export OTEL_EXPORTER_OTLP_LOGS_ENDPOINT="${OTLP_ENDPOINT}/v1/logs"
export OTEL_EXPORTER_OTLP_METRICS_ENDPOINT="${OTLP_ENDPOINT}/v1/metrics"
export OTEL_EXPORTER_OTLP_TRACES_ENDPOINT="${OTLP_ENDPOINT}/v1/traces"
export OTEL_EXPORTER_OTLP_HEADERS="Authorization=Basic ${HEADER_B64}"
export OTEL_EXPORTER_OTLP_PROTOCOL="http/protobuf"
export GRAFANA_CLOUD_INGEST_TOKEN="${INGEST_TOKEN}"
export GRAFANA_CLOUD_VERIFY_TOKEN="${VERIFY_TOKEN}"
export GRAFANA_CLOUD_OTLP_ENDPOINT="${OTLP_ENDPOINT}"
export GRAFANA_CLOUD_OTLP_INSTANCE_ID="${OTLP_INSTANCE_ID}"
export GRAFANA_CLOUD_LOKI_URL="${LOKI_URL}"
export GRAFANA_CLOUD_LOKI_INSTANCE_ID="${LOKI_INSTANCE_ID}"
export GRAFANA_CLOUD_PROMETHEUS_URL="${PROMETHEUS_URL}"
export GRAFANA_CLOUD_PROMETHEUS_INSTANCE_ID="${PROMETHEUS_INSTANCE_ID}"

node "${SOVDEV_ROOT}/typescript/dist/cli/selftest.js" --backend grafana-cloud
SELFTEST_EXIT=$?

if [ ${SELFTEST_EXIT} -ne 0 ]; then
  print_fail "sovdev-selftest failed -- ${OUTPUT_FILE} was NOT written. Nothing to hand over yet."
  echo "  Check: label selector regex on the verify policy, correct tokens pasted, correct realm." >&2
  exit 1
fi
print_ok "All 4 checks passed -- credentials genuinely work end-to-end"

print_step "Writing ${OUTPUT_FILE}"
cat > "${OUTPUT_FILE}" <<EOF
# Handover file for ${SERVICE_NAME} -- generated $(date -u +"%Y-%m-%dT%H:%M:%SZ") by onboard-system.sh
# after a real, passing sovdev-selftest run against these exact values.
# This file's existence is the proof it works -- onboard-system.sh only
# writes it after a successful verification run, never before.

# --- Group 1: the application's own OTLP export (goes in ${SERVICE_NAME}'s app config/secrets) ---
OTEL_SERVICE_NAME=${SERVICE_NAME}
OTEL_EXPORTER_OTLP_LOGS_ENDPOINT=${OTLP_ENDPOINT}/v1/logs
OTEL_EXPORTER_OTLP_METRICS_ENDPOINT=${OTLP_ENDPOINT}/v1/metrics
OTEL_EXPORTER_OTLP_TRACES_ENDPOINT=${OTLP_ENDPOINT}/v1/traces
OTEL_EXPORTER_OTLP_HEADERS="Authorization=Basic ${HEADER_B64}"
OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf

# --- Group 2: sovdev-selftest's own config (so ${SERVICE_NAME} can self-verify anytime) ---
GRAFANA_CLOUD_INGEST_TOKEN=${INGEST_TOKEN}
GRAFANA_CLOUD_VERIFY_TOKEN=${VERIFY_TOKEN}
GRAFANA_CLOUD_OTLP_ENDPOINT=${OTLP_ENDPOINT}
GRAFANA_CLOUD_OTLP_INSTANCE_ID=${OTLP_INSTANCE_ID}
GRAFANA_CLOUD_LOKI_URL=${LOKI_URL}
GRAFANA_CLOUD_LOKI_INSTANCE_ID=${LOKI_INSTANCE_ID}
GRAFANA_CLOUD_PROMETHEUS_URL=${PROMETHEUS_URL}
GRAFANA_CLOUD_PROMETHEUS_INSTANCE_ID=${PROMETHEUS_INSTANCE_ID}
GRAFANA_CLOUD_TEMPO_URL=${TEMPO_URL}
GRAFANA_CLOUD_TEMPO_INSTANCE_ID=${TEMPO_INSTANCE_ID}
EOF

print_ok "${OUTPUT_FILE} written -- safe to hand over through your secure channel"
