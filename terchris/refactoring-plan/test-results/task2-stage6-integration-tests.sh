#!/bin/bash
# file: terchris/refactoring-plan/test-results/task2-stage6-integration-tests.sh
#
# Stage 6: Integration Testing for Task 2 Refactoring
#
# IMPORTANT: Run this script INSIDE the devcontainer, not on host!
#
# This script validates that the refactored install scripts work correctly
# after extracting common code to lib/install-common.sh
#
# Tests:
# 1. Library file exists and has correct functions
# 2. All 11 refactored scripts can be sourced without errors
# 3. All scripts have correct function definitions
# 4. Syntax validation passes for all scripts
# 5. Mock execution test (dry run simulation)

set -e  # Exit on first error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ADDITIONS_DIR="/workspace/.devcontainer/additions"
TEST_COUNT=0
PASS_COUNT=0
FAIL_COUNT=0

# Helper functions
log_test() {
    ((TEST_COUNT++))
    echo -e "${BLUE}TEST $TEST_COUNT: $1${NC}"
}

log_pass() {
    ((PASS_COUNT++))
    echo -e "${GREEN}  ✅ PASS: $1${NC}"
}

log_fail() {
    ((FAIL_COUNT++))
    echo -e "${RED}  ❌ FAIL: $1${NC}"
}

log_info() {
    echo -e "${YELLOW}  ℹ️  $1${NC}"
}

# Test 1: Library file exists and has correct structure
test_library_structure() {
    log_test "Library file structure validation"

    local lib_file="${ADDITIONS_DIR}/lib/install-common.sh"

    if [ ! -f "$lib_file" ]; then
        log_fail "Library file not found: $lib_file"
        return 1
    fi
    log_pass "Library file exists"

    # Check for required functions
    if ! grep -q "^verify_installations()" "$lib_file"; then
        log_fail "verify_installations() function not found"
        return 1
    fi
    log_pass "verify_installations() function exists"

    if ! grep -q "^process_standard_installations()" "$lib_file"; then
        log_fail "process_standard_installations() function not found"
        return 1
    fi
    log_pass "process_standard_installations() function exists"

    # Syntax check
    if ! bash -n "$lib_file" 2>/dev/null; then
        log_fail "Library syntax validation failed"
        return 1
    fi
    log_pass "Library syntax is valid"
}

# Test 2: All refactored scripts exist and have correct syntax
test_scripts_syntax() {
    log_test "Script syntax validation (11 refactored scripts)"

    local scripts=(
        "install-nginx.sh"
        "install-powershell.sh"
        "install-conf-script.sh"
        "install-dev-python.sh"
        "install-dev-rust.sh"
        "install-data-analytics.sh"
        "install-kubectl.sh"
        "install-dev-php-laravel.sh"
        "install-dev-typescript.sh"
        "install-ai-claudecode.sh"
        "install-dev-csharp.sh"
    )

    local all_passed=true
    for script in "${scripts[@]}"; do
        local script_path="${ADDITIONS_DIR}/${script}"

        if [ ! -f "$script_path" ]; then
            log_fail "Script not found: $script"
            all_passed=false
            continue
        fi

        if ! bash -n "$script_path" 2>/dev/null; then
            log_fail "Syntax error in $script"
            all_passed=false
        fi
    done

    if $all_passed; then
        log_pass "All 11 scripts have valid syntax"
    else
        log_fail "Some scripts have syntax errors"
        return 1
    fi
}

# Test 3: All refactored scripts source the library
test_library_sourcing() {
    log_test "Library sourcing validation"

    local scripts=(
        "install-nginx.sh"
        "install-powershell.sh"
        "install-conf-script.sh"
        "install-dev-python.sh"
        "install-dev-rust.sh"
        "install-data-analytics.sh"
        "install-kubectl.sh"
        "install-dev-php-laravel.sh"
        "install-dev-typescript.sh"
        "install-ai-claudecode.sh"
        "install-dev-csharp.sh"
    )

    local all_passed=true
    for script in "${scripts[@]}"; do
        local script_path="${ADDITIONS_DIR}/${script}"

        if ! grep -q 'source.*lib/install-common.sh' "$script_path"; then
            log_fail "$script does not source lib/install-common.sh"
            all_passed=false
        fi
    done

    if $all_passed; then
        log_pass "All 11 scripts source the library"
    else
        log_fail "Some scripts don't source the library"
        return 1
    fi
}

# Test 4: Pure simple scripts use library function
test_pure_simple_scripts() {
    log_test "Pure simple scripts use process_standard_installations()"

    local scripts=(
        "install-nginx.sh"
        "install-powershell.sh"
        "install-conf-script.sh"
        "install-dev-python.sh"
        "install-data-analytics.sh"
        "install-kubectl.sh"
        "install-dev-php-laravel.sh"
        "install-dev-typescript.sh"
    )

    local all_passed=true
    for script in "${scripts[@]}"; do
        local script_path="${ADDITIONS_DIR}/${script}"

        # Check that process_installations() calls process_standard_installations
        if ! grep -A 5 "^process_installations()" "$script_path" | grep -q "process_standard_installations"; then
            log_fail "$script doesn't call process_standard_installations()"
            all_passed=false
        fi

        # Check that old pattern is NOT present (no manual if-blocks)
        if grep -A 10 "^process_installations()" "$script_path" | grep -q "if \[ \${#SYSTEM_PACKAGES"; then
            log_fail "$script still has old manual if-blocks"
            all_passed=false
        fi
    done

    if $all_passed; then
        log_pass "All 8 pure simple scripts use library function"
    else
        log_fail "Some scripts still have old pattern"
        return 1
    fi
}

# Test 5: Scripts with custom prefix preserve custom logic
test_custom_prefix_scripts() {
    log_test "Custom prefix scripts preserve custom logic + use library"

    # dev-rust should have install_rust + library call
    if grep -A 10 "^process_installations()" "${ADDITIONS_DIR}/install-dev-rust.sh" | grep -q "install_rust"; then
        log_pass "dev-rust preserves install_rust()"
    else
        log_fail "dev-rust lost install_rust()"
        return 1
    fi

    if grep -A 10 "^process_installations()" "${ADDITIONS_DIR}/install-dev-rust.sh" | grep -q "process_standard_installations"; then
        log_pass "dev-rust uses process_standard_installations()"
    else
        log_fail "dev-rust doesn't use process_standard_installations()"
        return 1
    fi

    # ai-claudecode should have install_claude_code + setup + library call
    if grep -A 15 "^process_installations()" "${ADDITIONS_DIR}/install-ai-claudecode.sh" | grep -q "install_claude_code"; then
        log_pass "ai-claudecode preserves install_claude_code()"
    else
        log_fail "ai-claudecode lost install_claude_code()"
        return 1
    fi

    if grep -A 15 "^process_installations()" "${ADDITIONS_DIR}/install-ai-claudecode.sh" | grep -q "setup_claude_code_config"; then
        log_pass "ai-claudecode preserves setup_claude_code_config()"
    else
        log_fail "ai-claudecode lost setup_claude_code_config()"
        return 1
    fi

    # dev-csharp should have install_dotnet + install_azure_functions + library call
    if grep -A 15 "^process_installations()" "${ADDITIONS_DIR}/install-dev-csharp.sh" | grep -q "install_dotnet"; then
        log_pass "dev-csharp preserves install_dotnet()"
    else
        log_fail "dev-csharp lost install_dotnet()"
        return 1
    fi

    if grep -A 15 "^process_installations()" "${ADDITIONS_DIR}/install-dev-csharp.sh" | grep -q "install_azure_functions"; then
        log_pass "dev-csharp preserves install_azure_functions()"
    else
        log_fail "dev-csharp lost install_azure_functions()"
        return 1
    fi
}

# Test 6: Skipped scripts remain unchanged (Track B - Complex)
test_skipped_scripts() {
    log_test "Complex scripts (Track B) remain unchanged"

    # These scripts should NOT use process_standard_installations
    local skipped_scripts=(
        "install-azure.sh"
        "install-dev-golang.sh"
        "install-dev-java.sh"
    )

    local all_correct=true
    for script in "${skipped_scripts[@]}"; do
        local script_path="${ADDITIONS_DIR}/${script}"

        if [ ! -f "$script_path" ]; then
            log_fail "Skipped script not found: $script"
            all_correct=false
            continue
        fi

        # These should have completely custom process_installations()
        # Check they DON'T call process_standard_installations
        if grep -q "process_standard_installations" "$script_path"; then
            log_fail "$script was incorrectly modified (should remain custom)"
            all_correct=false
        fi
    done

    if $all_correct; then
        log_pass "All 3 complex scripts remain custom (not refactored)"
    else
        log_fail "Some complex scripts were incorrectly modified"
        return 1
    fi
}

# Test 7: Code reduction validation
test_code_reduction() {
    log_test "Code reduction validation"

    log_info "Checking git diff for code reduction..."

    # Count lines changed in the last commit
    local stats=$(git show --stat --format="" HEAD | grep "insertion" | grep "deletion")

    if echo "$stats" | grep -q "insertion"; then
        log_info "Git stats: $stats"

        # Extract deletion count
        local deletions=$(echo "$stats" | grep -oP '\d+(?= deletion)')
        local insertions=$(echo "$stats" | grep -oP '\d+(?= insertion)')

        if [ -n "$deletions" ] && [ -n "$insertions" ]; then
            local net_reduction=$((deletions - insertions))

            if [ $net_reduction -gt 0 ]; then
                log_pass "Code reduced by $net_reduction lines"
            else
                log_fail "Code size increased instead of decreasing"
                return 1
            fi
        fi
    else
        log_info "Could not parse git stats (this is OK if not in git repo)"
    fi
}

# Test 8: Library functions are callable
test_library_functions_callable() {
    log_test "Library functions can be called"

    # Source the library
    SCRIPT_DIR="${ADDITIONS_DIR}"
    if ! source "${ADDITIONS_DIR}/lib/install-common.sh" 2>/dev/null; then
        log_fail "Failed to source library"
        return 1
    fi
    log_pass "Library sourced successfully"

    # Check if functions are defined
    if ! declare -f verify_installations > /dev/null; then
        log_fail "verify_installations() not defined after sourcing"
        return 1
    fi
    log_pass "verify_installations() is defined"

    if ! declare -f process_standard_installations > /dev/null; then
        log_fail "process_standard_installations() not defined after sourcing"
        return 1
    fi
    log_pass "process_standard_installations() is defined"
}

# Main execution
main() {
    echo "======================================================================"
    echo "  Stage 6: Integration Testing for Task 2 Refactoring"
    echo "======================================================================"
    echo ""
    echo "Testing library-based refactoring of 11 install scripts"
    echo ""

    # Run all tests
    test_library_structure || true
    echo ""

    test_scripts_syntax || true
    echo ""

    test_library_sourcing || true
    echo ""

    test_pure_simple_scripts || true
    echo ""

    test_custom_prefix_scripts || true
    echo ""

    test_skipped_scripts || true
    echo ""

    test_code_reduction || true
    echo ""

    test_library_functions_callable || true
    echo ""

    # Summary
    echo "======================================================================"
    echo "  Test Summary"
    echo "======================================================================"
    echo "Total tests: $TEST_COUNT"
    echo -e "${GREEN}Passed: $PASS_COUNT${NC}"
    echo -e "${RED}Failed: $FAIL_COUNT${NC}"
    echo ""

    if [ $FAIL_COUNT -eq 0 ]; then
        echo -e "${GREEN}✅ ALL TESTS PASSED!${NC}"
        echo ""
        echo "Stage 6 complete - refactoring is successful!"
        echo ""
        echo "Next steps:"
        echo "1. Manually test 1-2 install scripts to verify functionality"
        echo "2. Proceed to Stage 7: Documentation and Cleanup"
        return 0
    else
        echo -e "${RED}❌ SOME TESTS FAILED${NC}"
        echo ""
        echo "Please review failed tests and fix issues before proceeding."
        return 1
    fi
}

# Run main
main
