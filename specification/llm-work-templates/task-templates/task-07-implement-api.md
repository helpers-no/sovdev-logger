# Task 7: Implement 8 API Functions

**Parent task**: ROADMAP.md - Phase 1, Task 7
**Prerequisites**: Task 6 complete (OTLP exporters implemented)

---

## Purpose

Implement all 8 API functions defined in `specification/01-api-contract.md`.

These functions provide the public interface for sovdev-logger.

---

## Prerequisites Check

Before starting, verify:
- [ ] Task 6 complete (OTLP exporters working)
- [ ] You have read `specification/01-api-contract.md` completely
- [ ] You understand all 8 function signatures

**Note:** Task 8 (file logging) can be implemented in parallel or after this task.

**If ANY prerequisite missing → Go back and complete it first**

---

## The 8 Functions

**From `specification/01-api-contract.md`:**

1. `sovdev_initialize` - Initialize the logger
2. `sovdev_log` - Log a message
3. `sovdev_log_job_status` - Log job status
4. `sovdev_log_job_progress` - Log job progress
5. `sovdev_flush` - Flush all pending logs
6. `sovdev_start_span` - Start a trace span
7. `sovdev_end_span` - End a trace span
8. `create_peer_services` - Create peer service helper

**⚠️ CRITICAL:**
- All function names use **snake_case** (see spec line 927)
- All attribute names use **underscores** (peer_service, operation_name)
- Read the spec for exact signatures - do NOT invent function names
- TypeScript is the reference implementation: `typescript/src/logger.ts`

---

## Subtasks

### 7.1 Read API Contract Specification Completely

**This is the MOST IMPORTANT step. Do not skip this.**

- [ ] Open `specification/01-api-contract.md`
- [ ] Read the complete document
- [ ] Identify all 8 functions with their exact names (all use snake_case)
- [ ] Note function signatures (parameters and return types)
- [ ] Note required vs optional parameters
- [ ] Note language-specific adaptations section (line ~924)
- [ ] Read `specification/07-anti-patterns.md` (common mistakes to avoid)
- [ ] Compare with TypeScript reference: `typescript/src/logger.ts`

**Understanding checkpoint**:
- Can you list all 8 function names correctly (snake_case)?
- Do you understand each function's purpose?
- Do you know which parameters are required vs optional?

**If you cannot answer these → Re-read specification before proceeding**

---

### 7.2 Implement Each Function According to Specification

**For each of the 8 functions:**

- [ ] Read the function's section in `specification/01-api-contract.md`
- [ ] Note the exact function name (snake_case)
- [ ] Note parameters (names, types, optional vs required)
- [ ] Note return type
- [ ] Note behavior requirements
- [ ] Compare with TypeScript implementation in `typescript/src/logger.ts`
- [ ] Implement the function in [LANGUAGE]
- [ ] Test the function works

**Key reminders:**
- **Use snake_case** for all function names (sovdev_initialize, sovdev_log, etc.)
- **Use underscores** in all attributes (peer_service, operation_name, NOT peer.service)
- **Follow the spec exactly** - don't invent new functions or parameters
- **Check TypeScript** when unsure about behavior
- **Avoid anti-patterns** - see `specification/07-anti-patterns.md`

**Example workflow for one function:**
```
1. Read: specification/01-api-contract.md → Section "1. sovdev_initialize"
2. Compare: typescript/src/logger.ts → function sovdev_initialize
3. Implement: [LANGUAGE] version following same behavior
4. Test: Call the function, verify it works
```

**Validation for each function:**
- [ ] Function name matches spec (snake_case)
- [ ] Parameters match spec (correct names, types)
- [ ] Return type matches spec
- [ ] Behavior matches TypeScript reference
- [ ] Code passes linting (make lint)

---

### 7.3 Export All Functions

Create the public API module that exports all 8 functions.

**Requirements from spec:**
- All function names use snake_case
- Export mechanism follows [LANGUAGE] conventions
- Functions can be imported by test programs

**Implementation:**
- [ ] Create main module file (e.g., index.ts, __init__.py, mod.go, Program.cs)
- [ ] Export/expose all 8 functions
- [ ] Verify functions can be imported
- [ ] Compare exports with TypeScript: `typescript/src/index.ts`

**Validation:**
- [ ] Module compiles
- [ ] All 8 functions exported
- [ ] Can import from external code
- [ ] Function names match spec (snake_case)
- [ ] Code passes linting (make lint)

---

## Success Criteria

**This task is complete when**:

- [ ] All 3 subtasks checked off
- [ ] All 8 API functions implemented according to `specification/01-api-contract.md`
- [ ] All function names use snake_case (sovdev_initialize, sovdev_log, etc.)
- [ ] All attribute names use underscores (peer_service, operation_name)
- [ ] All functions exported properly
- [ ] Code compiles/builds successfully
- [ ] Code passes linting (make lint)
- [ ] TypeScript reference consulted for behavior
- [ ] Anti-patterns avoided (see specification/07-anti-patterns.md)

**Do NOT mark complete if**:
- ❌ Any of the 8 functions missing
- ❌ Functions don't match API contract exactly
- ❌ Function names use camelCase instead of snake_case
- ❌ Attributes use dots instead of underscores
- ❌ Code doesn't compile
- ❌ Linting fails
- ❌ **End-to-end validation has not been run and passed**

---

## ⛔ MANDATORY VALIDATION BEFORE CLAIMING COMPLETE

**CRITICAL**: Do NOT mark this task complete without running end-to-end validation.

### Why This Matters

**Evidence from C# Session 3:**
- LLM claimed "Task 7 complete" without validation
- 5 user corrections required in next session
- Issues found: missing attributes, wrong initialization order, metrics not exporting
- Total debugging time: 3+ hours
- **Validation would have caught all issues in 2 minutes**

### Required Validation Steps

Before claiming Task 7 is complete, you MUST run the complete end-to-end test:

```bash
\1
```

**Success criteria:**
- ✅ All 8 validation steps pass (see `specification/tools/README.md`)
- ✅ Test script exits with status 0
- ✅ No errors in console output
- ✅ Logs appear in Loki with correct format
- ✅ Metrics appear in Prometheus with underscores in labels
- ✅ Traces appear in Tempo with correct spans

**If ANY step fails:**
- ⛔ Task 7 is NOT complete
- 🔍 Debug using `specification/tools/README.md` → validation tools section
- 🔁 Fix the issue and re-run full validation
- ⚠️ Do NOT skip steps - each validates different aspects

### Quick Validation Reference

**For detailed troubleshooting**, see `specification/tools/README.md`.

**Step 1**: File format validation (instant)
```bash
./specification/tools/validate-log-format.sh [language]/logs/test-file-logs-[language]-company-lookup.jsonl
```

**Step 2**: Loki logs validation
```bash
./specification/tools/query-loki.sh test-otlp-logs-[language] --json
```

**Step 3**: Prometheus metrics validation
```bash
./specification/tools/query-prometheus.sh test_counter_requests_total --json
```

**Step 4**: Tempo traces validation
```bash
./specification/tools/query-tempo.sh test-otlp-traces-[language]
```

**Why each step matters:**
- Step 1: Validates log schema, field naming (snake_case)
- Step 2: Confirms OTLP logs exporter works, `Host: otel.localhost` header present
- Step 3: Confirms metrics export, **verifies underscores in labels** (not dots)
- Step 4: Confirms trace export, span structure

### The "It Compiles" Trap

❌ **WRONG**: "Code compiles and builds → Task 7 complete"
✅ **CORRECT**: "Code compiles AND validation passes → Task 7 complete"

**Remember**:
- Compilation = syntax correct
- Validation = behavior correct
- We care about **behavior**, not just syntax

---

## Common Pitfalls

### Pitfall 1: Wrong Function Names
**Problem**: Using camelCase (logInfo) instead of snake_case (sovdev_log)
**Impact**: E2E test can't find functions
**Solution**: Read specification/01-api-contract.md line 927 - "ALL languages MUST use snake_case"

### Pitfall 2: Invented Functions
**Problem**: Creating functions not in the spec (like recordPeerService which doesn't exist)
**Impact**: Wrong API, doesn't match specification
**Solution**: Only implement the 8 functions defined in specification/01-api-contract.md

### Pitfall 3: Dots in Attributes
**Problem**: Using `peer.service` instead of `peer_service`
**Impact**: Grafana filtering breaks
**Solution**: Use underscores everywhere (see specification/03-implementation-patterns.md)

### Pitfall 4: Not Reading the Spec
**Problem**: Guessing function signatures instead of reading spec
**Impact**: Wrong parameters, wrong behavior
**Solution**: Read specification/01-api-contract.md completely before coding

### Pitfall 5: Ignoring TypeScript Reference
**Problem**: Implementing without checking TypeScript behavior
**Impact**: Subtle differences in behavior
**Solution**: Compare with typescript/src/logger.ts when unsure

### Pitfall 6: Anti-Patterns
**Problem**: Using module names for scope_name, or language-specific exception types
**Impact**: Breaks cross-language consistency
**Solution**: Read specification/07-anti-patterns.md before implementing

---

## Validation

**Before marking complete, verify**:

```bash
# Code builds successfully
cd [LANGUAGE]
make build  # or equivalent

# Linting passes
make lint  # Must exit 0

# Check for snake_case function names
grep -r "sovdev_initialize\|sovdev_log\|sovdev_flush" [LANGUAGE]/src/

# Check for underscores in attributes (should find many)
grep -r "peer_service" [LANGUAGE]/
grep -r "operation_name" [LANGUAGE]/

# Check for dots in attributes (should find NONE)
grep -r '"peer\.service"\|"operation\.name"' [LANGUAGE]/
# Should return nothing

# Compare with spec
echo "Did you implement all 8 functions from specification/01-api-contract.md?"
echo "1. sovdev_initialize"
echo "2. sovdev_log"
echo "3. sovdev_log_job_status"
echo "4. sovdev_log_job_progress"
echo "5. sovdev_flush"
echo "6. sovdev_start_span"
echo "7. sovdev_end_span"
echo "8. create_peer_services"
```

**All checks must pass before claiming completion.**

---

## Reference Documents

**MUST READ:**
- **specification/01-api-contract.md**: The 8 API functions (WHAT they must do)
- **specification/07-anti-patterns.md**: Common mistakes to avoid
- **typescript/src/logger.ts**: Reference implementation (HOW they behave)
- **typescript/src/index.ts**: Reference exports

**Supporting docs:**
- **specification/03-implementation-patterns.md**: snake_case requirement
- **specification/10-code-quality.md**: Linting standards

---

## Next Steps

After completing this task:
- Task 9: Create E2E test (company-lookup) that uses these 8 functions
- Task 10: Run test successfully

**Parent task**: Return to ROADMAP.md when complete
