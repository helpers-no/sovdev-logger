# Task 9: Create E2E Test (Company-Lookup)

**Parent task**: ROADMAP.md - Phase 2, Task 9
**Estimated time**: 2-3 hours
**Prerequisites**: Task 8 complete (all 8 API functions implemented)

---

## Purpose

Implement the company-lookup E2E test program that demonstrates all 8 sovdev-logger API functions.

**Complete specification**: `specification/08-testprogram-company-lookup.md`

**TypeScript reference**: `typescript/test/e2e/company-lookup/company-lookup.ts`

---

## Prerequisites Check

Before starting, verify:
- [ ] Task 8 complete (all 8 API functions working)
- [ ] You have read `specification/08-testprogram-company-lookup.md` completely
- [ ] You have reviewed TypeScript reference implementation
- [ ] You understand the test scenario (batch company lookup)

**If ANY prerequisite missing → Go back and complete it first**

---

## What This Test Does

From `specification/08-testprogram-company-lookup.md`:

**The company-lookup test is a realistic batch processing scenario** that:
1. Initializes the logger
2. Logs application start
3. Starts a batch job (4 companies)
4. Processes each company with spans and metrics
5. Handles errors (one company fails intentionally)
6. Completes the batch job
7. Logs application finish
8. Flushes all telemetry

**This test exercises ALL 8 API functions** in a realistic way.

**Critical**: The test must produce **exactly 17 log entries** as specified.

---

## Subtasks

### 9.1 Read Test Specification Completely

**This is the MOST IMPORTANT step. Do not skip this.**

- [ ] Open `specification/08-testprogram-company-lookup.md`
- [ ] Read the complete document (full specification)
- [ ] Understand the test scenario (batch company lookup)
- [ ] Note the expected outputs (17 log entries, 4 metrics, 2 spans)
- [ ] Review TypeScript reference: `typescript/test/e2e/company-lookup/company-lookup.ts`
- [ ] Note the exact function calls and their order

**Understanding checkpoint**:
- Do you know how many log entries must be produced? (17)
- Do you know which 8 API functions to use?
- Do you understand the peer service pattern (cache, database, analytics)?

**If you cannot answer these → Re-read specification before proceeding**

---

### 9.2 Create Test Directory Structure

Set up the test program directory.

**From specification/08-testprogram-company-lookup.md:**

- [ ] Create directory: `[LANGUAGE]/test/e2e/company-lookup/`
- [ ] Create test program file (e.g., test.ts, test.py, main.go, Program.cs)
- [ ] Create .env file (copy from `typescript/test/e2e/company-lookup/.env`)
- [ ] Create run-test.sh script
- [ ] Make run-test.sh executable: `chmod +x run-test.sh`

**Directory structure should match:**
```
[LANGUAGE]/
└── test/
    └── e2e/
        └── company-lookup/
            ├── test.[ext]      # Main test program
            ├── .env            # Environment variables
            └── run-test.sh     # Test execution script
```

**Validation:**
- [ ] Directory exists
- [ ] Files created
- [ ] run-test.sh is executable

---

### 9.3 Implement Test Program According to Specification

**Implement the test program following `specification/08-testprogram-company-lookup.md`:**

- [ ] Import all 8 sovdev-logger functions
- [ ] Follow the test flow from the specification
- [ ] Use the EXACT function names from spec (snake_case)
- [ ] Produce exactly 17 log entries
- [ ] Generate 4 metrics (peer service recordings)
- [ ] Create 2 spans (cache_lookup, db_query)
- [ ] Compare behavior with TypeScript reference

**Key reminders:**
- **Use snake_case** functions (sovdev_initialize, sovdev_log, etc.)
- **Follow the spec exactly** - don't improvise
- **Check TypeScript** when unsure about behavior
- **Match the log messages** from the spec

**Example starting structure:**
```
# Import functions (use actual snake_case names from spec)
from sovdev_logger import (
    sovdev_initialize,
    sovdev_log,
    sovdev_log_job_status,
    sovdev_log_job_progress,
    sovdev_flush,
    sovdev_start_span,
    sovdev_end_span,
    create_peer_services
)

# Follow test flow from specification/08-testprogram-company-lookup.md
# 1. Initialize
# 2. Log application start
# 3. Start batch job
# ... etc
```

**Validation for implementation:**
- [ ] All 8 functions imported
- [ ] Test flow matches specification
- [ ] 17 log entries will be produced
- [ ] 4 peer service metrics recorded
- [ ] 2 spans created
- [ ] Code compiles/runs
- [ ] Code passes linting (make lint)

---

### 9.4 Create run-test.sh Script

Create the test execution script.

**Requirements:**
- Script runs the test program
- Uses DevContainer environment (called via in-devcontainer.sh)
- Cleans up logs before running
- Exits with test program's exit code

**Example run-test.sh:**
```bash
#!/bin/bash
set -e

# Clean up old logs
rm -rf logs/
mkdir -p logs

# Run test program
[language-specific-command]  # e.g., npm start, python test.py, go run ., dotnet run

# Test should exit 0 on success
exit $?
```

**Validation:**
- [ ] Script exists
- [ ] Script is executable
- [ ] Script cleans logs directory
- [ ] Script runs test program
- [ ] Script preserves exit code

---

### 9.5 Test Locally

Run the test and verify it works.

**Execution** (via DevContainer wrapper):
- [ ] Run: `./specification/tools/in-devcontainer.sh -e "cd /workspace/[LANGUAGE]/test/e2e/company-lookup && ./run-test.sh"`
- [ ] Check for errors (should exit 0)
- [ ] Check logs/ directory for log files

**Expected results:**
- [ ] Test exits successfully (exit code 0)
- [ ] Log file created in logs/ directory
- [ ] File contains 17 log entries
- [ ] No exceptions or errors

**Check log file:**
```bash
# Count log entries
cat [LANGUAGE]/test/e2e/company-lookup/logs/*.log | wc -l
# Should show: 17

# Verify log format (should be JSON)
head -1 [LANGUAGE]/test/e2e/company-lookup/logs/*.log
# Should show valid JSON
```

**Validation:**
- [ ] Test runs without errors
- [ ] 17 log entries created
- [ ] Logs are valid JSON
- [ ] All expected log messages present

---

## Success Criteria

**This task is complete when**:

- [ ] All 5 subtasks checked off
- [ ] Test program implements `specification/08-testprogram-company-lookup.md` completely
- [ ] All 8 API functions used correctly (snake_case names)
- [ ] Test produces exactly 17 log entries
- [ ] Test generates 4 peer service metrics
- [ ] Test creates 2 spans (cache_lookup, db_query)
- [ ] Test runs successfully (exit code 0)
- [ ] run-test.sh script works
- [ ] Code passes linting (make lint)
- [ ] Behavior matches TypeScript reference

**Do NOT mark complete if**:
- ❌ Test doesn't run
- ❌ Wrong number of log entries (not 17)
- ❌ Using wrong function names (camelCase instead of snake_case)
- ❌ Missing any of the 8 API function calls
- ❌ Test fails or throws exceptions
- ❌ Linting fails

---

## Common Pitfalls

### Pitfall 1: Wrong Function Names
**Problem**: Using camelCase or invented names (startSpan, recordPeerService)
**Impact**: Functions don't exist, test fails
**Solution**: Use exact names from specification/01-api-contract.md (sovdev_start_span, etc.)

### Pitfall 2: Wrong Log Count
**Problem**: Producing 15 or 20 log entries instead of 17
**Impact**: File validation fails
**Solution**: Follow specification/08-testprogram-company-lookup.md exactly

### Pitfall 3: Not Using All 8 Functions
**Problem**: Skipping some API functions
**Impact**: Incomplete test, doesn't validate full API
**Solution**: Verify all 8 functions called (check TypeScript reference)

### Pitfall 4: Improvising Instead of Following Spec
**Problem**: Creating a "similar" test instead of exact implementation
**Impact**: Output doesn't match, validation fails
**Solution**: Follow specification/08-testprogram-company-lookup.md line by line

### Pitfall 5: run-test.sh Not Executable
**Problem**: Forgot chmod +x run-test.sh
**Impact**: Test can't be run
**Solution**: chmod +x run-test.sh

### Pitfall 6: Not Comparing with TypeScript
**Problem**: Implementing without checking TypeScript behavior
**Impact**: Subtle differences in output
**Solution**: Review typescript/test/e2e/company-lookup/company-lookup.ts

---

## Validation

**Before marking complete, verify**:

```bash
# Test runs successfully
./specification/tools/in-devcontainer.sh -e "cd /workspace/[LANGUAGE]/test/e2e/company-lookup && ./run-test.sh"
echo $?  # Should print: 0

# Check log count
cat [LANGUAGE]/test/e2e/company-lookup/logs/*.log | wc -l
# Should show: 17

# Check log format
head -1 [LANGUAGE]/test/e2e/company-lookup/logs/*.log | python -m json.tool
# Should parse as valid JSON

# Check all 8 functions are imported/used
grep -r "sovdev_initialize\|sovdev_log\|sovdev_flush" [LANGUAGE]/test/
grep -r "sovdev_start_span\|sovdev_end_span" [LANGUAGE]/test/
grep -r "sovdev_log_job_status\|sovdev_log_job_progress" [LANGUAGE]/test/
grep -r "create_peer_services" [LANGUAGE]/test/

# Linting passes
cd [LANGUAGE] && make lint
```

**All checks must pass before claiming completion.**

---

## Reference Documents

**MUST READ:**
- **specification/08-testprogram-company-lookup.md**: Test specification (WHAT to implement)
- **typescript/test/e2e/company-lookup/company-lookup.ts**: Reference implementation (HOW it works)
- **specification/01-api-contract.md**: API functions to use

**Supporting docs:**
- **specification/09-development-loop.md**: How to run tests
- **typescript/test/e2e/company-lookup/.env**: Environment variables

---

## Time Estimate

- Subtask 9.1: 20 minutes (read spec + review TypeScript)
- Subtask 9.2: 10 minutes (create directory structure)
- Subtask 9.3: 1.5-2 hours (implement test program)
- Subtask 9.4: 10 minutes (create run-test.sh)
- Subtask 9.5: 20 minutes (test locally + debug)

**Total**: ~2-3 hours

---

## Next Steps

After completing this task:
- Task 10: Run test successfully and verify output
- Task 11: Validate log format with validation tools

**Parent task**: Return to ROADMAP.md when complete
