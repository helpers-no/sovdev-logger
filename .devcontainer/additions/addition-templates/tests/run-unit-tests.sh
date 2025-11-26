#!/bin/bash
# File: run-unit-tests.sh
# Purpose: Execute all unit tests for DevContainer Toolbox
# Usage: bash run-unit-tests.sh

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test results
PASSED=0
FAILED=0
TOTAL=0

# Test output directory
TEST_OUTPUT_DIR="/tmp/devcontainer-tests"
mkdir -p "$TEST_OUTPUT_DIR"

log_header() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${BLUE}$1${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

log_test() {
    echo -e "${YELLOW}▶ $1${NC}"
}

log_pass() {
    echo -e "${GREEN}✅ PASS: $1${NC}"
    PASSED=$((PASSED + 1))
}

log_fail() {
    echo -e "${RED}❌ FAIL: $1${NC}"
    FAILED=$((FAILED + 1))
}

run_test() {
    local test_name="$1"
    local test_function="$2"

    TOTAL=$((TOTAL + 1))
    log_test "Test $TOTAL: $test_name"

    local output_file="$TEST_OUTPUT_DIR/test-$TOTAL.log"

    if $test_function > "$output_file" 2>&1; then
        log_pass "$test_name"
        return 0
    else
        log_fail "$test_name"
        echo "    Output saved to: $output_file"
        echo "    Last 10 lines:"
        tail -10 "$output_file" | sed 's/^/    /'
        return 1
    fi
}

#------------------------------------------------------------------------------
# TEST 1.1: Component Scanner - Install Scripts
#------------------------------------------------------------------------------
test_1_1() {
    source /workspace/.devcontainer/additions/lib/component-scanner.sh

    local count=0
    while IFS=$'\t' read -r basename name desc cat check prereqs; do
        count=$((count + 1))
    done < <(scan_install_scripts /workspace/.devcontainer/additions)

    if [ $count -gt 10 ]; then
        echo "Discovered $count install scripts"
        return 0
    else
        echo "Only discovered $count install scripts (expected > 10)"
        return 1
    fi
}

#------------------------------------------------------------------------------
# TEST 1.2: Component Scanner - Config Scripts
#------------------------------------------------------------------------------
test_1_2() {
    source /workspace/.devcontainer/additions/lib/component-scanner.sh

    local count=0
    while IFS=$'\t' read -r basename name desc cat check; do
        count=$((count + 1))
    done < <(scan_config_scripts /workspace/.devcontainer/additions)

    if [ $count -ge 3 ]; then
        echo "Discovered $count config scripts"
        return 0
    else
        echo "Only discovered $count config scripts (expected >= 3)"
        return 1
    fi
}

#------------------------------------------------------------------------------
# TEST 1.3: Prerequisite Checking - Config Present
#------------------------------------------------------------------------------
test_1_3() {
    source /workspace/.devcontainer/additions/lib/prerequisite-check.sh

    if check_prerequisite_config "config-devcontainer-identity.sh" "/workspace/.devcontainer/additions"; then
        echo "Prerequisite check succeeded (identity configured)"
        return 0
    else
        echo "Prerequisite check failed (identity should be configured)"
        return 1
    fi
}

#------------------------------------------------------------------------------
# TEST 1.4: Prerequisite Checking - Config Missing
#------------------------------------------------------------------------------
test_1_4() {
    # Temporarily move identity file
    local backup_file="$HOME/.devcontainer-identity.test-backup-$(date +%s)"
    mv ~/.devcontainer-identity "$backup_file" 2>/dev/null || true

    source /workspace/.devcontainer/additions/lib/prerequisite-check.sh

    local result=0
    if check_prerequisite_config "config-devcontainer-identity.sh" "/workspace/.devcontainer/additions"; then
        echo "Prerequisite check succeeded (should have failed)"
        result=1
    else
        echo "Prerequisite check failed as expected"
        result=0
    fi

    # Restore identity file
    mv "$backup_file" ~/.devcontainer-identity 2>/dev/null || true

    return $result
}

#------------------------------------------------------------------------------
# TEST 1.5: --verify Handler Detection
#------------------------------------------------------------------------------
test_1_5() {
    local ADDITIONS_DIR="/workspace/.devcontainer/additions"
    local verified_count=0

    for script in "$ADDITIONS_DIR"/config-*.sh; do
        if grep -q '= "--verify"' "$script" 2>/dev/null; then
            verified_count=$((verified_count + 1))
        fi
    done

    if [ $verified_count -ge 1 ]; then
        echo "Found $verified_count scripts with --verify support"
        return 0
    else
        echo "No scripts with --verify support found"
        return 1
    fi
}

#------------------------------------------------------------------------------
# TEST 1.6: --verify Functionality
#------------------------------------------------------------------------------
test_1_6() {
    # Backup current identity
    local backup_file="$HOME/.devcontainer-identity.test-backup-$(date +%s)"
    cp ~/.devcontainer-identity "$backup_file" 2>/dev/null || true

    # Remove identity
    rm -f ~/.devcontainer-identity

    # Run --verify
    if bash /workspace/.devcontainer/additions/config-devcontainer-identity.sh --verify 2>/dev/null; then
        # Check if restored
        if [ -f ~/.devcontainer-identity ]; then
            echo "Identity file restored successfully"
            return 0
        else
            echo "Identity file not restored"
            return 1
        fi
    else
        echo "--verify failed"
        mv "$backup_file" ~/.devcontainer-identity 2>/dev/null || true
        return 1
    fi
}

#------------------------------------------------------------------------------
# TEST 1.7: Tool Auto-Enable Library
#------------------------------------------------------------------------------
test_1_7() {
    source /workspace/.devcontainer/additions/lib/tool-auto-enable.sh

    # Backup enabled-tools.conf
    cp /workspace/.devcontainer.extend/enabled-tools.conf /tmp/enabled-tools.conf.test-backup

    # Remove test tool if exists
    sed -i '/test-tool-automated-test-12345/d' /workspace/.devcontainer.extend/enabled-tools.conf

    # Test auto-enable
    if auto_enable_tool "test-tool-automated-test-12345" "Test Tool"; then
        # Check if added
        if grep -q "test-tool-automated-test-12345" /workspace/.devcontainer.extend/enabled-tools.conf; then
            # Test idempotency
            auto_enable_tool "test-tool-automated-test-12345" "Test Tool"

            # Count occurrences
            local count=$(grep -c "test-tool-automated-test-12345" /workspace/.devcontainer.extend/enabled-tools.conf)

            # Restore original
            cp /tmp/enabled-tools.conf.test-backup /workspace/.devcontainer.extend/enabled-tools.conf
            rm /tmp/enabled-tools.conf.test-backup

            if [ "$count" -eq 1 ]; then
                echo "Tool added and idempotent (1 occurrence)"
                return 0
            else
                echo "Tool duplicated ($count occurrences)"
                return 1
            fi
        else
            # Restore original
            cp /tmp/enabled-tools.conf.test-backup /workspace/.devcontainer.extend/enabled-tools.conf
            rm /tmp/enabled-tools.conf.test-backup
            echo "Tool not added"
            return 1
        fi
    else
        # Restore original
        cp /tmp/enabled-tools.conf.test-backup /workspace/.devcontainer.extend/enabled-tools.conf
        rm /tmp/enabled-tools.conf.test-backup
        echo "Auto-enable failed"
        return 1
    fi
}

#------------------------------------------------------------------------------
# TEST 1.8: Metadata Extraction Accuracy
#------------------------------------------------------------------------------
test_1_8() {
    source /workspace/.devcontainer/additions/lib/component-scanner.sh

    local EXPECTED_NAME="OTel Collector"
    local EXPECTED_PREREQ="config-devcontainer-identity.sh config-nginx.sh"
    local found=0

    while IFS=$'\t' read -r basename name desc cat check prereqs; do
        if [ "$basename" = "install-otel-monitoring.sh" ]; then
            found=1

            if [ "$name" != "$EXPECTED_NAME" ]; then
                echo "Name mismatch: expected '$EXPECTED_NAME', got '$name'"
                return 1
            fi

            if [ "$prereqs" != "$EXPECTED_PREREQ" ]; then
                echo "Prerequisites mismatch: expected '$EXPECTED_PREREQ', got '$prereqs'"
                return 1
            fi

            echo "Metadata extracted accurately for OTel script"
            return 0
        fi
    done < <(scan_install_scripts /workspace/.devcontainer/additions)

    if [ $found -eq 0 ]; then
        echo "OTel script not found in scan"
        return 1
    fi
}

#------------------------------------------------------------------------------
# TEST 1.9: CHECK_INSTALLED_COMMAND Logic
#------------------------------------------------------------------------------
test_1_9() {
    # Test with installed tool (python)
    local CHECK_CMD="command -v python3 >/dev/null 2>&1"
    if ! eval "$CHECK_CMD"; then
        echo "Python check failed (should succeed)"
        return 1
    fi

    # Test with non-existent tool
    CHECK_CMD="command -v nonexistent-tool-xyz-123 >/dev/null 2>&1"
    if eval "$CHECK_CMD"; then
        echo "Nonexistent tool check succeeded (should fail)"
        return 1
    fi

    echo "CHECK_INSTALLED_COMMAND logic works correctly"
    return 0
}

#------------------------------------------------------------------------------
# TEST 1.10: Show Missing Prerequisites
#------------------------------------------------------------------------------
test_1_10() {
    source /workspace/.devcontainer/additions/lib/prerequisite-check.sh

    # Temporarily move identity
    local backup_file="$HOME/.devcontainer-identity.test-backup-$(date +%s)"
    mv ~/.devcontainer-identity "$backup_file" 2>/dev/null || true

    # Get output
    local output=$(show_missing_prerequisites "config-devcontainer-identity.sh" "/workspace/.devcontainer/additions" 2>&1)

    # Restore
    mv "$backup_file" ~/.devcontainer-identity 2>/dev/null || true

    # Check format
    if ! echo "$output" | grep -q "❌"; then
        echo "Missing error symbol in output"
        return 1
    fi

    if ! echo "$output" | grep -q "Developer Identity"; then
        echo "Missing config name in output"
        return 1
    fi

    if ! echo "$output" | grep -q "bash /workspace/.devcontainer/additions"; then
        echo "Missing run command in output"
        return 1
    fi

    echo "Error message format is correct"
    return 0
}

#------------------------------------------------------------------------------
# MAIN
#------------------------------------------------------------------------------

log_header "DevContainer Toolbox - Unit Tests"
echo "Test output directory: $TEST_OUTPUT_DIR"
echo "Date: $(date)"
echo ""

# Run all tests
run_test "Component Scanner - Install Scripts" test_1_1
run_test "Component Scanner - Config Scripts" test_1_2
run_test "Prerequisite Checking - Config Present" test_1_3
run_test "Prerequisite Checking - Config Missing" test_1_4
run_test "--verify Handler Detection" test_1_5
run_test "--verify Functionality" test_1_6
run_test "Tool Auto-Enable Library" test_1_7
run_test "Metadata Extraction Accuracy" test_1_8
run_test "CHECK_INSTALLED_COMMAND Logic" test_1_9
run_test "Show Missing Prerequisites" test_1_10

# Summary
log_header "Test Results Summary"
echo ""
echo "Total Tests:  $TOTAL"
echo -e "Passed:       ${GREEN}$PASSED${NC}"
echo -e "Failed:       ${RED}$FAILED${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ ALL TESTS PASSED${NC}"
    exit 0
else
    echo -e "${RED}❌ SOME TESTS FAILED${NC}"
    echo ""
    echo "Check individual test logs in: $TEST_OUTPUT_DIR"
    exit 1
fi
