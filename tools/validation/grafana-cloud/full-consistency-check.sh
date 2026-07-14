#!/bin/bash
# filename: tools/validation/grafana-cloud/full-consistency-check.sh
# description: The single command for "does this actually work end-to-end against Grafana Cloud"
#
# Purpose:
#   Runs the complete verification flow in one command, matching how this
#   project's maintainer originally verified changes by hand: write to a
#   local file first (ground truth), validate the file, then read back from
#   each backend (Loki, Prometheus, Tempo) and diff the response against
#   that same file, field by field. A tool's own "found it" report is not
#   proof by itself -- only a field-by-field match against a known-good
#   local record is.
#
#   1. Run typescript/test/e2e/company-lookup's E2E test against Grafana
#      Cloud -- generates logs/dev.log (the ground truth).
#   2. Validate dev.log's format against the JSON Schema.
#   3. Query Loki, Prometheus, and Tempo, each with --compare-with against
#      that same dev.log -- fails loudly on any mismatch, not just "no data
#      found".
#
# Usage:
#   ./full-consistency-check.sh [--env-file PATH]
#
#   --env-file PATH   Passed through to run-test.sh's own --env-file (path
#                      relative to typescript/test/e2e/company-lookup/).
#                      Defaults to .env.grafana-cloud (the maintainer's own
#                      personal dev credentials). Use this to point at a
#                      different backend's credentials (e.g. CI's own) --
#                      see terchris/sovdev-ci-grafana.env for that file's
#                      Group 1 half.
#
# Environment:
#   The GRAFANA_CLOUD_* vars (see .env.example) must already be present in
#   the environment before calling this script -- either by sourcing
#   tools/validation/grafana-cloud/.env yourself first (the maintainer's own
#   personal dev credentials), or by exporting a different backend's values
#   (e.g. CI's own, from terchris/sovdev-ci-grafana.env's Group 2 half, or
#   from real GitHub Actions secrets). This script never sources a .env file
#   itself, specifically so it can't silently override credentials the
#   caller already set up on purpose.
#
# Exit Codes:
#   0 - Every step passed: the library's real behavior, end-to-end against
#       a real backend, matches the local log file exactly.
#   1 - Some step failed -- see output for which one, or required env vars
#       were never set.
#
# This is the gate referenced in CLAUDE.md / PLANS.md: before a change to
# typescript/src/**.ts is pushed to main, this script must exit 0.

set -o pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

print_step() { echo -e "${BLUE}▶ $1${NC}"; }
print_ok() { echo -e "${GREEN}✅ $1${NC}"; }
print_fail() { echo -e "${RED}❌ $1${NC}" >&2; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOVDEV_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
E2E_DIR="${SOVDEV_ROOT}/typescript/test/e2e/company-lookup"
LOG_FILE="${E2E_DIR}/logs/dev.log"

ENV_FILE_ARG=".env.grafana-cloud"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --env-file)
      ENV_FILE_ARG="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

REQUIRED_VARS=(GRAFANA_CLOUD_INGEST_TOKEN GRAFANA_CLOUD_VERIFY_TOKEN GRAFANA_CLOUD_OTLP_ENDPOINT GRAFANA_CLOUD_OTLP_INSTANCE_ID GRAFANA_CLOUD_LOKI_URL GRAFANA_CLOUD_LOKI_INSTANCE_ID GRAFANA_CLOUD_PROMETHEUS_URL GRAFANA_CLOUD_PROMETHEUS_INSTANCE_ID GRAFANA_CLOUD_TEMPO_URL GRAFANA_CLOUD_TEMPO_INSTANCE_ID)
MISSING=()
for v in "${REQUIRED_VARS[@]}"; do
  [ -z "${!v}" ] && MISSING+=("$v")
done
if [ ${#MISSING[@]} -ne 0 ]; then
  print_fail "Missing required env vars: ${MISSING[*]}"
  echo "  Source tools/validation/grafana-cloud/.env (your own dev credentials) yourself" >&2
  echo "  first, or export a different backend's values (e.g. CI's) before calling this" >&2
  echo "  script -- it never sources a .env file on its own." >&2
  exit 1
fi

FAILED=0

print_step "Step 1/3: running the E2E test against Grafana Cloud (writing ${LOG_FILE})"
(cd "${E2E_DIR}" && ./run-test.sh --skip-validation --env-file "${ENV_FILE_ARG}")
if [ $? -ne 0 ]; then
  print_fail "E2E test execution failed"
  exit 1
fi
print_ok "E2E test ran, log file written"
echo ""

print_step "Step 2/3: validating ${LOG_FILE}'s format against the schema"
python3 "${SOVDEV_ROOT}/tools/validation/validators/validate-log-format.py" "${LOG_FILE}"
if [ $? -ne 0 ]; then
  print_fail "Log file format validation failed"
  exit 1
fi
print_ok "Log file format valid"
echo ""

SERVICE_NAME=$(grep -h '^OTEL_SERVICE_NAME=' "${E2E_DIR}/${ENV_FILE_ARG}" 2>/dev/null | tail -1 | cut -d= -f2)
if [ -z "${SERVICE_NAME}" ]; then
  # Env file didn't exist or had no OTEL_SERVICE_NAME (e.g. CI, which
  # exports vars directly rather than via a checked-in file) -- fall back
  # to whatever's already in the environment.
  SERVICE_NAME="${OTEL_SERVICE_NAME}"
fi
if [ -z "${SERVICE_NAME}" ]; then
  print_fail "Could not determine OTEL_SERVICE_NAME (checked ${E2E_DIR}/${ENV_FILE_ARG} and the environment)"
  exit 1
fi

print_step "Step 3/3: reading back from Loki, Prometheus, and Tempo, diffing each against the file"
cd "${SCRIPT_DIR}"

echo ""
echo "--- Loki (logs) ---"
npx tsx query-loki.ts "${SERVICE_NAME}" --compare-with "${LOG_FILE}"
[ $? -ne 0 ] && { print_fail "Loki consistency check failed"; FAILED=1; }

echo ""
echo "--- Prometheus (metrics) ---"
npx tsx query-prometheus.ts "${SERVICE_NAME}" --compare-with "${LOG_FILE}"
[ $? -ne 0 ] && { print_fail "Prometheus consistency check failed"; FAILED=1; }

echo ""
echo "--- Tempo (traces) ---"
# Tempo's search index lags behind Loki/Prometheus (confirmed empirically,
# unlike those two, query-tempo.ts has no built-in retry) -- poll with
# backoff rather than fail on the first attempt, which reliably races a
# fresh write's indexing delay.
TEMPO_OK=1
for attempt in 1 2 3 4 5 6; do
  TEMPO_OUTPUT=$(npx tsx query-tempo.ts "${SERVICE_NAME}" --compare-with "${LOG_FILE}" 2>&1)
  TEMPO_EXIT=$?
  if [ ${TEMPO_EXIT} -eq 0 ]; then
    TEMPO_OK=0
    break
  fi
  echo "  (attempt ${attempt}/6: not all spans indexed yet, waiting 10s...)"
  sleep 10
done
echo "${TEMPO_OUTPUT}"
[ ${TEMPO_OK} -ne 0 ] && { print_fail "Tempo consistency check failed after 6 attempts (~60s)"; FAILED=1; }

echo ""
if [ ${FAILED} -eq 0 ]; then
  print_ok "ALL CHECKS PASSED — verified end-to-end against real Grafana Cloud data"
  exit 0
else
  print_fail "One or more consistency checks failed — see above"
  exit 1
fi
