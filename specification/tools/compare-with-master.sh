#!/bin/bash
# filename: specification/tools/compare-with-master.sh
# description: Compare a candidate language's E2E output against TypeScript's (the master)
#
# Purpose:
#   Runs the master-comparison check: does <candidate-language>'s file log for
#   the fixed company-lookup E2E scenario match TypeScript's, field by field?
#   TypeScript's live output is always the answer key -- there is no stored
#   "golden" fixture to go stale. See:
#   website/docs/ai-developer/plans/active/PLAN-001-master-comparison-mode.md
#
#   Can run from:
#   1. HOST: Uses dct-exec (devcontainer-toolbox >= 1.8.0) to run inside the devcontainer
#   2. DEVCONTAINER: Runs the comparator directly
#
#   This tool does NOT run the E2E tests for you -- run both languages'
#   run-test.sh first (see Examples).
#
# Usage:
#   ./compare-with-master.sh <candidate-language> [options]
#
# Arguments:
#   candidate-language   Language directory name under sovdev-logger root (e.g. python)
#
# Options:
#   --json               Output JSON format for automation/parsing
#   --help               Show this help message
#
# Environment:
#   - Requires devcontainer-toolbox >= 1.8.0's dct-exec on PATH (when called from host)
#   - Uses comparator: specification/tests/compare-log-files.py
#
# Exit Codes:
#   0 - Match (candidate's output is identical to TypeScript's, per the normalization rules)
#   1 - Mismatch, or comparator error
#   2 - Usage error
#   3 - dct-exec not found (when run from host) or devcontainer not running
#   4 - A required log file (TypeScript's or the candidate's) was not found
#
# Examples:
#   # 1. Run both E2E tests first
#   cd typescript/test/e2e/company-lookup && ./run-test.sh
#   cd python/test/e2e/company-lookup && ./run-test.sh
#
#   # 2. Compare
#   cd specification/tools && ./compare-with-master.sh python
#
#   # JSON output for CI/CD pipeline parsing
#   ./compare-with-master.sh python --json
#
###############################################################################

set -e
set -o pipefail

RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

COMPARATOR_SCRIPT="/workspace/specification/tests/compare-log-files.py"

print_usage() {
    echo "Usage: $0 <candidate-language> [options]"
    echo ""
    echo "Arguments:"
    echo "  candidate-language   Language directory name (e.g. python)"
    echo ""
    echo "Options:"
    echo "  --json               Output JSON format for automation"
    echo "  --help               Show this help message"
    echo ""
    echo "Run both languages' E2E tests before comparing:"
    echo "  cd typescript/test/e2e/company-lookup && ./run-test.sh"
    echo "  cd <candidate-language>/test/e2e/company-lookup && ./run-test.sh"
    echo ""
    echo "Examples:"
    echo "  $0 python"
    echo "  $0 python --json"
}

print_error() {
    echo -e "${RED}ERROR: $1${NC}" >&2
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

is_in_devcontainer() {
    [ -f "/.dockerenv" ] || [ -n "$DEVCONTAINER" ]
}

run_comparator() {
    local master_log=$1
    local candidate_log=$2
    local options=$3

    if is_in_devcontainer; then
        python3 "${COMPARATOR_SCRIPT}" "${master_log}" "${candidate_log}" ${options}
    else
        if ! command -v dct-exec >/dev/null 2>&1; then
            print_error "dct-exec not found on PATH."
            echo "  Install/update devcontainer-toolbox (>= 1.8.0): https://dct.sovereignsky.no" >&2
            exit 3
        fi
        dct-exec bash -c "python3 ${COMPARATOR_SCRIPT} ${master_log} ${candidate_log} ${options}"
    fi
}

main() {
    if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
        print_usage
        exit 0
    fi

    if [ $# -eq 0 ]; then
        print_error "Missing candidate-language parameter"
        echo ""
        print_usage
        exit 2
    fi

    local candidate_lang=$1
    shift
    local options="$@"

    local master_log="/workspace/typescript/test/e2e/company-lookup/logs/dev.log"
    local candidate_log="/workspace/${candidate_lang}/test/e2e/company-lookup/logs/dev.log"

    # Resolve local (host-side) paths for the existence check, so the error
    # is clear before we ever try to exec into the container.
    local script_dir sovdev_root
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    sovdev_root="$(cd "${script_dir}/../.." && pwd)"

    if is_in_devcontainer; then
        local master_local="${master_log}"
        local candidate_local="${candidate_log}"
    else
        local master_local="${sovdev_root}/typescript/test/e2e/company-lookup/logs/dev.log"
        local candidate_local="${sovdev_root}/${candidate_lang}/test/e2e/company-lookup/logs/dev.log"
    fi

    if [ ! -f "${master_local}" ]; then
        print_error "TypeScript log not found: ${master_local}"
        echo "  Run: cd typescript/test/e2e/company-lookup && ./run-test.sh" >&2
        exit 4
    fi

    if [ ! -f "${candidate_local}" ]; then
        print_error "${candidate_lang} log not found: ${candidate_local}"
        echo "  Run: cd ${candidate_lang}/test/e2e/company-lookup && ./run-test.sh" >&2
        exit 4
    fi

    print_info "Comparing ${candidate_lang} against TypeScript (master)..."

    if run_comparator "${master_log}" "${candidate_log}" "${options}"; then
        exit 0
    else
        exit 1
    fi
}

main "$@"
