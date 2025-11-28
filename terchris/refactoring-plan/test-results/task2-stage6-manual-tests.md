# Stage 6: Manual Integration Testing Guide

This guide provides manual tests to verify the refactored install scripts work correctly.

## Prerequisites

**IMPORTANT:** These tests must be run **INSIDE the devcontainer**, not on the host machine.

## Automated Test Suite

First, run the automated integration tests:

```bash
cd /workspace
bash terchris/refactoring-plan/test-results/task2-stage6-integration-tests.sh
```

This will validate:
- Library structure and functions
- Script syntax
- Library sourcing
- Function usage patterns
- Code reduction metrics

## Manual Functional Testing

After automated tests pass, manually test 2-3 scripts to verify actual functionality:

### Test 1: Simple Script (nginx)

Test a pure simple script that only uses the library function:

```bash
cd /workspace/.devcontainer/additions

# Test syntax
bash -n install-nginx.sh && echo "✅ Syntax OK"

# Test help/usage (should show description)
bash install-nginx.sh --help || echo "Script ran"

# Test dry run (won't actually install, but will show what would happen)
# Note: This will fail if nginx is already installed, which is expected
bash install-nginx.sh --debug 2>&1 | head -20
```

**Expected output:**
- No syntax errors
- Script shows "Nginx Reverse Proxy" in output
- Script sources lib/install-common.sh
- No errors about missing functions

### Test 2: Script with Custom Prefix (dev-rust)

Test a script that has custom logic + library function:

```bash
cd /workspace/.devcontainer/additions

# Test syntax
bash -n install-dev-rust.sh && echo "✅ Syntax OK"

# Verify custom function is present
grep -A 5 "install_rust()" install-dev-rust.sh | head -6

# Verify it calls library function
grep -A 5 "process_installations()" install-dev-rust.sh | grep "process_standard_installations" && echo "✅ Uses library"
```

**Expected output:**
- Syntax OK
- install_rust() function exists (custom logic)
- process_installations() calls process_standard_installations (library)

### Test 3: Complex Script Unchanged (dev-golang)

Verify that complex scripts were NOT modified:

```bash
cd /workspace/.devcontainer/additions

# Verify it does NOT use library function
! grep "process_standard_installations" install-dev-golang.sh && echo "✅ Not refactored (correct)"

# Verify it still has custom logic
grep -A 20 "process_installations()" install-dev-golang.sh | grep -q "GO_INSTALL_DIR" && echo "✅ Custom Go logic preserved"
```

**Expected output:**
- Does NOT use process_standard_installations
- Still has custom Go installation logic

### Test 4: Library Functions Work

Test that the library functions are callable:

```bash
cd /workspace/.devcontainer/additions

# Source the library and core scripts
source lib/logging.sh
source lib/core-install-apt.sh
source lib/core-install-node.sh
source lib/core-install-extensions.sh
source lib/core-install-pwsh.sh
source lib/core-install-python-packages.sh
source lib/install-common.sh

# Check functions are defined
declare -f verify_installations > /dev/null && echo "✅ verify_installations defined"
declare -f process_standard_installations > /dev/null && echo "✅ process_standard_installations defined"

# Create test arrays and call functions (dry run)
declare -a SYSTEM_PACKAGES=()
declare -a NODE_PACKAGES=()
declare -a PYTHON_PACKAGES=()
declare -a PWSH_MODULES=()
declare -A EXTENSIONS=()
declare -a VERIFY_COMMANDS=("echo '✅ Test verification command'")

# Test verify_installations
verify_installations

# Test process_standard_installations with empty arrays
process_standard_installations
echo "✅ Functions callable without errors"
```

**Expected output:**
- Both functions defined
- Functions run without errors
- Test verification command executes

## Verification Checklist

After running all tests, verify:

- [ ] Automated test suite passes (all green)
- [ ] Pure simple scripts work (nginx example)
- [ ] Custom prefix scripts preserve custom logic (dev-rust example)
- [ ] Complex scripts remain unchanged (dev-golang example)
- [ ] Library functions are callable
- [ ] No syntax errors in any script
- [ ] Code reduction confirmed (194 lines removed)

## Success Criteria

**Stage 6 is complete when:**

1. ✅ All automated tests pass
2. ✅ Manual functional tests confirm scripts work
3. ✅ No syntax errors
4. ✅ Library functions are properly integrated
5. ✅ Custom logic preserved where needed
6. ✅ Code reduction confirmed

## If Tests Fail

If any tests fail:

1. Review the specific failure message
2. Check the script in question
3. Verify correct function usage
4. Run bash -n on the script to check syntax
5. Review git diff to see what changed
6. Consult the original plan: `terchris/refactoring-plan/test-results/task2-stage2-library-design.md`

## Next Steps

Once all tests pass:

1. Mark Stage 6 as complete
2. Proceed to **Stage 7: Documentation and Cleanup**
3. Update template script with new patterns
4. Update task documentation

## Troubleshooting

### Common Issues

**Issue:** "Library not found"
- **Solution:** Ensure you're in `/workspace/.devcontainer/additions/` directory
- Run: `ls -la lib/install-common.sh` to verify file exists

**Issue:** "Function not defined"
- **Solution:** Make sure you source all dependencies in order:
  1. logging.sh
  2. core-install-*.sh files
  3. install-common.sh

**Issue:** "Syntax error"
- **Solution:** Run `bash -n script.sh` to get detailed error
- Check for missing quotes, brackets, or incorrect variable expansion

**Issue:** "process_standard_installations not found"
- **Solution:** Verify script sources `lib/install-common.sh`
- Check SCRIPT_DIR variable is set correctly

## Report Results

After completing tests, report results:

```bash
# Generate test results summary
echo "# Stage 6 Test Results" > /tmp/stage6-results.txt
echo "" >> /tmp/stage6-results.txt
echo "Date: $(date)" >> /tmp/stage6-results.txt
echo "" >> /tmp/stage6-results.txt
echo "## Automated Tests" >> /tmp/stage6-results.txt
bash terchris/refactoring-plan/test-results/task2-stage6-integration-tests.sh 2>&1 | tee -a /tmp/stage6-results.txt
echo "" >> /tmp/stage6-results.txt
echo "## Manual Tests" >> /tmp/stage6-results.txt
echo "✅ Manual tests completed successfully" >> /tmp/stage6-results.txt
cat /tmp/stage6-results.txt
```

Save results for documentation.
