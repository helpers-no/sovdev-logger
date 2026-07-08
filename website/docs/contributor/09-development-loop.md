---
title: Development loop
sidebar_label: Development loop
sidebar_position: 5
description: "Iterative development workflow."
---

# Development Loop

---

## Purpose

This document describes the **iterative development workflow** for implementing and testing sovdev-logger in any programming language.

**Key Principle:** Validate log files FIRST (fast, local), then validate OTLP backends SECOND (slow, requires infrastructure).

---

## Validation-First Development

**Critical Principle:** Validation is not a phase at the end. Validation is continuous throughout development.

### Two-Level Validation Strategy

When implementing sovdev-logger in any programming language, use this two-level approach:

#### Level 1: System-Wide Health Check (TypeScript Baseline)

**ALWAYS verify TypeScript works before starting new language implementation**

TypeScript is the reference implementation that proves the observability stack is healthy:
- If TypeScript validation fails → Infrastructure problem (fix Docker, Loki, Prometheus, Tempo)
- If TypeScript validation passes → Infrastructure is healthy (new language issues are code-specific)

```bash
# Run TypeScript validation to verify system health (Phase 0, Task 2)
cd /workspace/typescript/test/e2e/company-lookup && ./run-test.sh
cd /workspace/specification/tools && ./query-loki.sh sovdev-test-company-lookup-typescript
cd /workspace/specification/tools && ./query-prometheus.sh sovdev-test-company-lookup-typescript
cd /workspace/specification/tools && ./query-tempo.sh sovdev-test-company-lookup-typescript
```

**This is Phase 0, Task 2: "Verify TypeScript baseline"** - it's MANDATORY, not optional.

#### Level 2: Continuous Language-Specific Validation

Validate your implementation at these checkpoints during development:

**1. File Format Validation** (fastest, local, no infrastructure)
- **After**: Implementing file logger and running a simple test
- **Action**: Run test → Check log files created → Run `validate-log-format.sh`
- Tool: `validate-log-format.sh`
- When: Phase 1, Task 7 (Implement file logging)
- Why first: Catches format issues without needing OTLP infrastructure

**2. OTLP Connectivity Test** (fast, infrastructure)
- **After**: Implementing OTLP exporters
- **Action**: Create simple test with SDK → Send test data → Verify appears in backends
- Method: Use OTEL SDK's built-in functions (not bash scripts)
- When: Phase 1, Task 6 (Implement OTLP exporters)
- Why second: Isolates connectivity issues (headers, TLS, auth) from logic issues
- Note: Language-idiomatic testing - C# tests in C#, Go tests in Go, etc.

**3. Backend Data Validation** (slow, requires full E2E test)
- **After**: E2E test runs successfully
- **Action**: Run E2E test → Wait 10s → Run `run-full-validation.sh` → Verify all pass
- Tools: Automated validation script runs Steps 1-7 automatically
- When: Phase 2, Task 10 (Run test successfully)
- Why third: Verifies end-to-end data flow with correct format
- **Complete tool documentation**: `specification/tools/README.md`

**4. Grafana Visual Validation** (manual, requires full stack)
- **After**: Automated validation (`run-full-validation.sh`) passes
- **Action**: Open Grafana → Verify ALL 3 panels show data → Compare with TypeScript
- When: Phase 3, Task 11 (Grafana visual verification)
- Why last: Verifies complete observability experience in UI
- **Critical**: Don't open Grafana until automated validation passes

### Key Principle

**TypeScript validates the system. Your language validates its integration with the system.**

If TypeScript works but your language doesn't:
- Check OTLP endpoint configuration
- Check Host header (must be "Host: otel.localhost")
- Check metric labels (use underscores, not dots)
- Check log format (must match specification exactly)

### Rule for Task Completion

**You cannot claim a task is "complete" without running applicable validation tools.**

Examples:
- Task 6: "Implement OTLP exporters"
  - ❌ Wrong: Write code → mark complete
  - ✅ Correct: Write code → create connectivity test → verify connects to Loki/Prometheus/Tempo → mark complete

- Task 7: "Implement file logging"
  - ❌ Wrong: Write code → mark complete
  - ✅ Correct: Write code → run validate-log-format.sh → verify passes → mark complete

---

## Developer Workflows

**For environment architecture diagram**, see `05-environment-configuration.md` → **Architecture Diagram** section.

**⚠️ CRITICAL:** All developers (human and LLM) now work **inside the DevContainer** at `/workspace/`. Execute commands directly.

### Working in the DevContainer

**Environment:** Commands execute inside the DevContainer at `/workspace/`

**How it works:**
- Host project directory is bind-mounted to `/workspace/` in container (same filesystem)
- Files edited via Read/Edit/Write tools or VSCode affect the same files
- Commands execute inside container with access to all installed runtimes
- Results are immediate

**Example commands:**
```bash
# Run tests
cd typescript/test/e2e/company-lookup && ./run-test.sh
cd python/test/e2e/company-lookup && ./run-test.sh

# Build libraries
cd typescript && ./build-sovdevlogger.sh
cd python && ./build-sovdevlogger.sh

# Validate log files
cd /workspace/specification/tools && ./validate-log-format.sh typescript/test/e2e/company-lookup/logs/dev.log

# Query backends
cd /workspace/specification/tools && ./query-loki.sh sovdev-test-company-lookup-typescript
cd /workspace/specification/tools && ./query-prometheus.sh sovdev-test-company-lookup-typescript
```

### Common Commands Reference

| Task | Command (from `/workspace/`) |
|------|------------------------------|
| **Lint TypeScript code** | `cd typescript && make lint` |
| **Lint TypeScript (auto-fix)** | `cd typescript && make lint-fix` |
| **Build TypeScript library** | `cd typescript && ./build-sovdevlogger.sh` |
| **Build Python library** | `cd python && ./build-sovdevlogger.sh` |
| **Build Go library** | `cd go && ./build-sovdevlogger.sh` |
| **Run TypeScript test** | `cd typescript/test/e2e/company-lookup && ./run-test.sh` |
| **Run Python test** | `cd python/test/e2e/company-lookup && ./run-test.sh` |
| **Install dependencies** | `cd typescript && npm install` |
| **Validate log format** | `cd /workspace/specification/tools && ./validate-log-format.sh {language}/test/e2e/company-lookup/logs/dev.log` |
| **Query Loki** | `cd /workspace/specification/tools && ./query-loki.sh sovdev-test-company-lookup-{language}` |
| **Full validation** | `cd /workspace/specification/tools && ./run-full-validation.sh {language}` |

---

## The Development Loop

The typical development cycle follows this **6-step pattern**:

1. **Edit** - Make code changes
2. **Lint** - Check code quality (MANDATORY - must pass before build)
3. **Build** - Compile/build the library
4. **Run/Test** - Execute code (start with simple tests, work up to E2E)
5. **Validate Logs** - Check file format (FAST - instant feedback)
6. **Validate OTLP** - Check backends (SLOW - requires infrastructure)

**Key principle:** Validate incrementally as you build. Don't wait until the end to run full E2E test.

**Validation order matters:**
- If Step 5 fails (file logs incorrect) → Steps 6-7 will also fail
- Validate file logs FIRST (instant), then OTLP backends SECOND (slower)
- See `specification/tools/README.md` for complete 8-step validation sequence

**Note on file editing:** Files are synchronized between host and container (bind mount). The distinction below is only about **where commands execute**. For architecture details, see `05-environment-configuration.md`.

---

## Test-Driven Development: The Iterative Feedback Loop

**⚠️ CRITICAL FOR LLMs:** This is NOT a one-time sequence. This is **iterative test-driven development**.

### The Feedback Loop

```
┌─────────────────────────────────────────┐
│  1. Edit code                            │
│  2. Lint (must pass)                     │
│  3. Build                                │
│  4. Run test                             │
│  5. Validate (use 8-step sequence)       │
│     │                                    │
│     ├─ ✅ PASS → Next task               │
│     │                                    │
│     └─ ❌ FAIL → Read error              │
│              ↓                           │
│         Understand what's broken         │
│              ↓                           │
│         Go back to Step 1 (Edit)         │
│              ↓                           │
│         Fix the issue                    │
│              ↓                           │
│         Run through loop again           │
│              ↓                           │
│         Repeat until validation passes   │
└─────────────────────────────────────────┘
```

### The 8-Step Validation Sequence (MUST FOLLOW IN ORDER)

**Complete documentation:** `specification/tools/README.md` → **Validation Sequence (Step-by-Step)**

**⛔ BLOCKING POINTS:** Each step has a blocking point. You CANNOT skip to the next step until the current step passes.

**The sequence:**

1. **Step 1: Validate Log Files** (INSTANT - file format)
   - Tool: `validate-log-format.sh`
   - **⛔ DO NOT PROCEED to Step 2 until this passes**
   - If fails → Go back to Edit, fix log format

2. **Step 2: Verify Logs in Loki** (OTLP export working)
   - Tool: `query-loki.sh`
   - **⛔ DO NOT PROCEED to Step 3 until logs are in Loki**
   - If fails → Go back to Edit, fix OTLP log exporter

3. **Step 3: Verify Metrics in Prometheus** (OTLP export working)
   - Tool: `query-prometheus.sh`
   - **⛔ DO NOT PROCEED to Step 4 until metrics are in Prometheus**
   - If fails → Go back to Edit, fix OTLP metrics exporter

4. **Step 4: Verify Traces in Tempo** (OTLP export working)
   - Tool: `query-tempo.sh`
   - **⛔ DO NOT PROCEED to Step 5 until traces are in Tempo**
   - If fails → Go back to Edit, fix OTLP trace exporter

5. **Step 5: Verify Grafana-Loki Connection**
   - Tool: `query-grafana-loki.sh`
   - **⛔ DO NOT PROCEED to Step 6 until Grafana can query Loki**

6. **Step 6: Verify Grafana-Prometheus Connection**
   - Tool: `query-grafana-prometheus.sh`
   - **⛔ DO NOT PROCEED to Step 7 until Grafana can query Prometheus**

7. **Step 7: Verify Grafana-Tempo Connection**
   - Tool: `query-grafana-tempo.sh`
   - **⛔ DO NOT PROCEED to Step 8 until Grafana can query Tempo**

8. **Step 8: Manual Grafana Dashboard Verification**
   - Open: http://grafana.localhost
   - Verify ALL 3 panels show data for your language

**Automated validation (Steps 1-7):**
```bash
cd /workspace/specification/tools && ./run-full-validation.sh {language}
```

This runs Steps 1-7 automatically. You MUST still do Step 8 manually.

### Example Iteration: Implementing OTLP Log Exporter

**Iteration 1:**
1. Edit: Implement OTLP log exporter
2. Lint: ✅ Passes
3. Build: ✅ Compiles
4. Run: ✅ Test executes
5. Validate:
   - Step 1 (File logs): ❌ **FAILS** - "Missing required field: trace_id"
   - **STOP HERE - Do not proceed to Step 2**

**Iteration 2:**
1. Edit: Add trace_id to log entries
2. Lint: ✅ Passes
3. Build: ✅ Compiles
4. Run: ✅ Test executes
5. Validate:
   - Step 1 (File logs): ✅ **PASSES** - 17 entries, all fields correct
   - Step 2 (Loki): ❌ **FAILS** - "No logs found in Loki"
   - **STOP HERE - Do not proceed to Step 3**

**Iteration 3:**
1. Edit: Fix OTLP endpoint (was missing Host: otel.localhost header)
2. Lint: ✅ Passes
3. Build: ✅ Compiles
4. Run: ✅ Test executes
5. Validate:
   - Step 1 (File logs): ✅ **PASSES**
   - Step 2 (Loki): ✅ **PASSES** - 17 logs found
   - Step 3 (Prometheus): ✅ **PASSES** - 4 metrics found
   - Step 4 (Tempo): ✅ **PASSES** - 2 traces found
   - Step 5-7 (Grafana connections): ✅ **ALL PASS**
   - Step 8 (Dashboard): ✅ **PASS** - All 3 panels show data

**Task complete!** ✅

### Key Principles

1. **Validation tools tell you what's broken** - Read error messages carefully
2. **Each failure teaches you something** - Understand the error before fixing
3. **Fix one thing at a time** - Don't change multiple things between iterations
4. **Follow the sequence** - Don't skip validation steps
5. **Iterate until it works** - This is normal, expected, and how development works

**For complete validation sequence details:** `specification/tools/README.md`

---

### For LLMs: Tracking Progress

There's no per-language ROADMAP file to maintain anymore — `specification/tools/compare-with-master.sh {language}` is the completion gate (see [PLAN-003](../ai-developer/plans/completed/PLAN-003-spec-scaffolding-cleanup.md)). Use your own task-tracking tooling if useful; there's no repo-enforced checklist to update.

---

### Step 1: Edit Code

Edit source files using your preferred tools:
- Human developers: Use VSCode editor
- LLM developers: Use Read/Edit/Write tools on host filesystem

**Important:** Files are synchronized between host and container - edit anywhere.

---

### Step 2: Lint Code (MANDATORY - NEW)

**Purpose:** Ensure code quality and catch issues early (dead code, type safety, formatting)

**⛔ BLOCKING STEP:** Linting MUST pass (exit code 0) before proceeding to build/test.

**Why this is mandatory:**
- ✅ Catches dead code immediately (unused imports, variables)
- ✅ Enforces type safety (return types, function signatures)
- ✅ Prevents technical debt from accumulating
- ✅ Stops bad patterns from propagating across language implementations
- ✅ **Critical for LLM-generated code** - prevents "going off the rails"

**For complete linting philosophy and rules**, see: [`10-code-quality.md`](./10-code-quality.md)

---

#### TypeScript (Reference Implementation)

**Human developers (VSCode terminal inside container):**
```bash
cd typescript
make lint              # Check linting
make lint-fix          # Auto-fix issues

# Or use npm directly:
npm run lint
npm run lint:fix
```

**LLM developers (host machine):**
```bash
cd /workspace/typescript && make lint
cd /workspace/typescript && make lint-fix

# Or use npm directly:
cd /workspace/typescript && npm run lint
```

**Exit codes:**
- **Exit 0** - Linting passed (warnings OK, proceed to build)
- **Exit non-zero** - Linting failed with errors (⛔ STOP, fix issues)

**Example output when passing:**
```
✖ 23 problems (0 errors, 23 warnings)

Checking formatting...
All matched files use Prettier code style!

Exit code: 0  ✅ Proceed to build
```

**Example output when failing:**
```
✖ 4 problems (4 errors, 0 warnings)
  - 'unused_import' is defined but never used
  - 'deadVariable' is assigned but never used
  - Missing return type on function

Exit code: 1  ⛔ STOP - Fix errors before proceeding
```

---

#### Python (Pattern to Follow)

When implementing Python linting, follow the TypeScript pattern:

**Create:**
- `python/.flake8` - Flake8 configuration
- `python/pyproject.toml` - Black/mypy configuration
- `python/Makefile` - With `lint` and `lint-fix` targets

**Commands:**
```bash
cd python && make lint       # Runs flake8, black --check, mypy
cd python && make lint-fix   # Runs black (auto-format)
```

**See:** `10-code-quality.md` for Python-specific rules

---

#### Go, C#, PHP (Future Implementations)

Follow the same pattern:
1. Study `typescript/.eslintrc.json` (reference implementation)
2. Read `10-code-quality.md` (universal rules)
3. Create language-specific configuration files
4. Create `Makefile` with `lint` and `lint-fix` targets
5. Ensure exit code 0 on success, non-zero on errors

---

#### For LLMs: How to Discover Linting

When implementing a new language:

1. **Read this step** - You'll see "Step 2: Lint Code (MANDATORY)"
2. **Read the specification** - `10-code-quality.md` explains WHY and WHAT
3. **Study TypeScript** - Look at `typescript/.eslintrc.json` and `typescript/Makefile`
4. **Adapt to your language** - Use language-appropriate tools (flake8 for Python, golangci-lint for Go, etc.)
5. **Create Makefile** - Consistent interface: `make lint` works for all languages
6. **Verify exit codes** - Test that errors block (non-zero exit), warnings don't (exit 0)

**Key files to examine:**
- `typescript/.eslintrc.json` - Configuration example
- `typescript/Makefile` - Interface pattern
- `typescript/package.json` - devDependencies and scripts

---

### Step 3: Build Library (When Needed)

After editing library source code, you need to build the library before running tests.

**When to build:**
- After modifying TypeScript source files (must compile to JavaScript)
- After modifying Python package files (install in editable mode)
- After modifying Go source files (download dependencies)
- After pulling updates from git
- After initial clone

**Human developers (VSCode terminal inside container):**
```bash
# TypeScript
cd typescript
./build-sovdevlogger.sh              # Standard build
./build-sovdevlogger.sh clean        # Clean build
./build-sovdevlogger.sh watch        # Watch mode for development

# Python
cd python
./build-sovdevlogger.sh              # Install in editable mode
./build-sovdevlogger.sh wheel        # Build distribution wheel
./build-sovdevlogger.sh clean        # Clean build artifacts

# Go
cd go
./build-sovdevlogger.sh              # Download dependencies and verify build
./build-sovdevlogger.sh test         # Run tests
./build-sovdevlogger.sh clean        # Clean build cache
```

**LLM developers (host machine):**
```bash
# TypeScript
cd /workspace/typescript && ./build-sovdevlogger.sh
cd /workspace/typescript && ./build-sovdevlogger.sh clean

# Python
cd /workspace/python && ./build-sovdevlogger.sh
cd /workspace/python && ./build-sovdevlogger.sh wheel

# Go
cd /workspace/go && ./build-sovdevlogger.sh
cd /workspace/go && ./build-sovdevlogger.sh test
```

**Build scripts:**
- `{language}/build-sovdevlogger.sh` - Language-specific build script
- Each language knows its own build process
- Handles dependencies, compilation, and verification

---

### Step 4: Run/Test (Incremental Approach)

**⚠️ IMPORTANT:** Don't jump straight to E2E test. Build and validate incrementally.

**Development progression:**
1. **After Task 6 (OTLP exporters)** → Create simple connectivity tests (emit test log/metric/trace)
2. **After Task 7 (API functions)** → Test individual functions with unit tests
3. **After Task 8 (File logging)** → Run E2E test to generate log files
4. **Only then** → Proceed to validation steps 5 & 6

**Run E2E test:**
```bash
# From inside DevContainer
cd /workspace/{language}/test/e2e/company-lookup && ./run-test.sh

# Or using convenience script
cd /workspace/specification/tools && ./run-company-lookup.sh {language}
```

**What this generates:**
- Log files in `{language}/test/e2e/company-lookup/logs/`
- OTLP data sent to Loki/Prometheus/Tempo (takes 5-10s to propagate)

---

### Step 5 & 6: Validate Using 8-Step Sequence

**After running tests, validate using the iterative feedback loop described above.**

**See the complete validation workflow in:**
- **Test-Driven Development section** (above) - Shows the iterative feedback loop with examples
- **specification/tools/README.md** - Complete 8-step validation sequence with all tools

**Quick reference:**
```bash
# Step 1: Validate log files (INSTANT - do this first!)
cd /workspace/specification/tools && ./validate-log-format.sh {language}/test/e2e/company-lookup/logs/dev.log

# Steps 2-7: Run full validation (after log files pass)
sleep 10  # Wait for OTLP propagation
cd /workspace/specification/tools && ./run-full-validation.sh {language}

# Step 8: Manual Grafana dashboard check
# Open http://grafana.localhost and verify all 3 panels show data
```

**⚠️ CRITICAL:** Follow the 8-step sequence in order. Each step has blocking points - you cannot skip ahead.

---

## Complete Workflow Example

**See the "Test-Driven Development: The Iterative Feedback Loop" section above for a detailed example with 3 iterations.**

**Quick workflow:**

```bash
# 1. Edit code (using your editor)

# 2. Lint code (MANDATORY - must pass before build)
cd /workspace/{language} && make lint

# 3. Build library (if needed)
cd /workspace/{language} && ./build-sovdevlogger.sh

# 4. Run test
cd /workspace/{language}/test/e2e/company-lookup && ./run-test.sh

# 5-6. Validate using 8-step sequence (see TDD section above)
cd /workspace/specification/tools && ./validate-log-format.sh {language}/test/e2e/company-lookup/logs/dev.log
sleep 10
cd /workspace/specification/tools && ./run-full-validation.sh {language}

# If validation fails → Go back to Step 1, fix the issue, iterate
# If validation passes → Task complete!
```

---

## Quick Reference: Development Commands

### Essential Commands

**All developers (working inside DevContainer at `/workspace/`):**

```bash
# Lint code (MANDATORY before build)
cd /workspace/{language} && make lint

# Auto-fix linting issues
cd /workspace/{language} && make lint-fix

# Build library
cd /workspace/{language} && ./build-sovdevlogger.sh

# Run test
cd /workspace/{language}/test/e2e/company-lookup && ./run-test.sh

# Validate log files (instant)
cd /workspace/specification/tools && ./validate-log-format.sh {language}/test/e2e/company-lookup/logs/dev.log

# Validate backends (after 10s wait)
cd /workspace/specification/tools && ./run-full-validation.sh {language}
```


## Best Practices

**See the "Test-Driven Development: The Iterative Feedback Loop" section above for complete workflow guidance.**

### ⚠️ For LLMs Specifically

**CRITICAL:** This is iterative test-driven development. When validation fails, go back to Edit and iterate.

1. **Follow the 8-step validation sequence in order**
   - Step 1 (file logs) MUST pass before Step 2 (Loki)
   - Do NOT skip steps or proceed when validation fails
   - See TDD section above for complete sequence

2. **Use tool commands EXACTLY as shown**
   - Do NOT add parameters (like `--limit`) unless shown in examples
   - Do NOT use manual inspection tools (`jq`, `python -m json.tool`, `cat`)
   - Copy command patterns character-for-character from TDD section

3. **Trust the validation tools**
   - `validate-log-format.sh` checks everything automatically
   - `run-full-validation.sh` runs Steps 1-7 automatically
   - If you think you need manual inspection, you're wrong

4. **Iterate when validation fails**
   - Read error messages carefully
   - Go back to Step 1 (Edit)
   - Fix ONE thing at a time
   - Run through loop again
   - Repeat until validation passes

---

## Integration with Validation Tools

All validation tools support this workflow:

| Tool | Purpose | Speed | When to Use |
|------|---------|-------|-------------|
| `validate-log-format.sh` | Check log file structure | Instant | After every test run |
| `run-company-lookup.sh` | Run test program | 2-5 seconds | During development |
| `run-full-validation.sh` | Complete validation | 15-20 seconds | Before committing |
| `query-loki.sh` | Query Loki backend | 5-10 seconds | Debugging OTLP issues |
| `query-prometheus.sh` | Query Prometheus | 5-10 seconds | Debugging metrics |
| `query-tempo.sh` | Query Tempo | 5-10 seconds | Debugging traces |

**For complete tool documentation**, see `specification/tools/README.md`.

---

## Related Documentation

- **[05-environment-configuration.md](./05-environment-configuration.md)** - DevContainer setup and configuration
- **[06-test-scenarios.md](./06-test-scenarios.md)** - Test scenarios and verification procedures
- **[08-testprogram-company-lookup.md](./08-testprogram-company-lookup.md)** - Company-lookup E2E test specification
- **[tools/README.md](https://github.com/helpers-no/sovdev-logger/blob/main/specification/tools/README.md)** - Complete validation tool documentation

---

**Last Updated:** 2025-10-31
