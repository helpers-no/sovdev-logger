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
./specification/tools/in-devcontainer.sh -e "cd /workspace/typescript/test/e2e/company-lookup && ./run-test.sh"
./specification/tools/in-devcontainer.sh -e "cd /workspace/specification/tools && ./query-loki.sh sovdev-test-company-lookup-typescript"
./specification/tools/in-devcontainer.sh -e "cd /workspace/specification/tools && ./query-prometheus.sh sovdev-test-company-lookup-typescript"
./specification/tools/in-devcontainer.sh -e "cd /workspace/specification/tools && ./query-tempo.sh sovdev-test-company-lookup-typescript"
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

## Developer Workflows: Human vs LLM

**For environment architecture diagram**, see `05-environment-configuration.md` → **Architecture Diagram** section. This shows how Host Machine, DevContainer, and Kubernetes Cluster interact.

There are **two different ways** to work with sovdev-logger, depending on whether you're a human or an LLM:

### Human Developers (VSCode + DevContainer Extension)

**Environment:** VSCode with DevContainer extension installed and running

**How it works:**
- Open project in VSCode
- VSCode automatically starts the DevContainer
- **Terminal runs INSIDE the container** (automatically)
- Run commands directly without wrappers

**Example commands:**
```bash
# Run test (terminal is already inside container)
cd typescript/test/e2e/company-lookup
./run-test.sh

# Or use npm/python/go directly
npm test
python -m pytest
go test ./...

# Validate log files
../../../specification/tools/validate-log-format.sh typescript/test/e2e/company-lookup/logs/dev.log
```

**Key difference:** No need for `in-devcontainer.sh` wrapper - you're already inside!

---

### LLM Developers (Host Machine + Bash Tool)

**Environment:** LLM running on host machine, using Bash tool to execute commands

**How it works:**
- LLM edits files on host filesystem (Read/Edit/Write tools)
- LLM uses `in-devcontainer.sh` wrapper for ALL code execution
- Commands run inside container via wrapper
- Results returned to LLM

**Example commands:**
```bash
# Run test (call tool in container)
./specification/tools/in-devcontainer.sh -e "cd /workspace/specification/tools && ./run-company-lookup.sh typescript"

# Validate log files (call tool in container)
./specification/tools/in-devcontainer.sh -e "cd /workspace/specification/tools && ./validate-log-format.sh typescript/test/e2e/company-lookup/logs/dev.log"

# Custom commands (any command in container)
./specification/tools/in-devcontainer.sh -e "cd /workspace/typescript && npm install"
```

**Key difference:** ALWAYS use `in-devcontainer.sh -e "command"` - everything inside quotes executes in the container.

---

### Command Comparison

| Task | Human Developer (VSCode Terminal) | LLM Developer (Host + Bash Tool) |
|------|-----------------------------------|----------------------------------|
| **Lint TypeScript code** | `cd typescript && make lint` | `./specification/tools/in-devcontainer.sh -e "cd /workspace/typescript && make lint"` |
| **Lint TypeScript (auto-fix)** | `cd typescript && make lint-fix` | `./specification/tools/in-devcontainer.sh -e "cd /workspace/typescript && make lint-fix"` |
| **Build TypeScript library** | `cd typescript && ./build-sovdevlogger.sh` | `./specification/tools/in-devcontainer.sh -e "cd /workspace/typescript && ./build-sovdevlogger.sh"` |
| **Build Python library** | `cd python && ./build-sovdevlogger.sh` | `./specification/tools/in-devcontainer.sh -e "cd /workspace/python && ./build-sovdevlogger.sh"` |
| **Build Go library** | `cd go && ./build-sovdevlogger.sh` | `./specification/tools/in-devcontainer.sh -e "cd /workspace/go && ./build-sovdevlogger.sh"` |
| **Run TypeScript test** | `cd typescript/test/e2e/company-lookup && ./run-test.sh` | `./specification/tools/in-devcontainer.sh -e "cd /workspace/specification/tools && ./run-company-lookup.sh typescript"` |
| **Run Python test** | `cd python/test/e2e/company-lookup && ./run-test.sh` | `./specification/tools/in-devcontainer.sh -e "cd /workspace/specification/tools && ./run-company-lookup.sh python"` |
| **Install dependencies** | `cd typescript && npm install` | `./specification/tools/in-devcontainer.sh -e "cd /workspace/typescript && npm install"` |
| **Run unit tests** | `cd typescript && npm test` | `./specification/tools/in-devcontainer.sh -e "cd /workspace/typescript && npm test"` |
| **Validate log format** | `validate-log-format.sh logs/dev.log` | `./specification/tools/in-devcontainer.sh -e "cd /workspace/specification/tools && ./validate-log-format.sh typescript/.../logs/dev.log"` |
| **Query Loki** | `query-loki.sh sovdev-test-company-lookup-typescript` | `./specification/tools/in-devcontainer.sh -e "cd /workspace/specification/tools && ./query-loki.sh sovdev-test-company-lookup-typescript"` |

**Note:** LLMs must use `in-devcontainer.sh -e "command"` for ALL commands. Human developers run commands directly (terminal is already inside container).

---

## The Development Loop

The typical development cycle follows this **5-step pattern**:

1. **Edit** - Make code changes
2. **Lint** - Check code quality (MANDATORY - must pass before build)
3. **Build** - Compile/build the library
4. **Test** - Run E2E tests
5. **Validate** - Verify logs/metrics/traces

**Note on file editing:** Files are synchronized between host and container (bind mount). The distinction below is only about **where commands execute**. For architecture details, see `05-environment-configuration.md`.

---

### For LLMs: Task Management Integration

**⚠️ IMPORTANT:** Track implementation progress using the task management system.

**Progress Tracking:** `{language}/llm-work/ROADMAP.md` (13 tasks across 4 phases)

**For complete task management workflow**, see `specification/llm-work-templates/README.md`

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

**For complete linting philosophy and rules**, see: [`specification/10-code-quality.md`](./10-code-quality.md)

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
./specification/tools/in-devcontainer.sh -e "cd /workspace/typescript && make lint"
./specification/tools/in-devcontainer.sh -e "cd /workspace/typescript && make lint-fix"

# Or use npm directly:
./specification/tools/in-devcontainer.sh -e "cd /workspace/typescript && npm run lint"
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

**See:** `specification/10-code-quality.md` for Python-specific rules

---

#### Go, C#, PHP (Future Implementations)

Follow the same pattern:
1. Study `typescript/.eslintrc.json` (reference implementation)
2. Read `specification/10-code-quality.md` (universal rules)
3. Create language-specific configuration files
4. Create `Makefile` with `lint` and `lint-fix` targets
5. Ensure exit code 0 on success, non-zero on errors

---

#### For LLMs: How to Discover Linting

When implementing a new language:

1. **Read this step** - You'll see "Step 2: Lint Code (MANDATORY)"
2. **Read the specification** - `specification/10-code-quality.md` explains WHY and WHAT
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
./specification/tools/in-devcontainer.sh -e "cd /workspace/typescript && ./build-sovdevlogger.sh"
./specification/tools/in-devcontainer.sh -e "cd /workspace/typescript && ./build-sovdevlogger.sh clean"

# Python
./specification/tools/in-devcontainer.sh -e "cd /workspace/python && ./build-sovdevlogger.sh"
./specification/tools/in-devcontainer.sh -e "cd /workspace/python && ./build-sovdevlogger.sh wheel"

# Go
./specification/tools/in-devcontainer.sh -e "cd /workspace/go && ./build-sovdevlogger.sh"
./specification/tools/in-devcontainer.sh -e "cd /workspace/go && ./build-sovdevlogger.sh test"
```

**Build scripts:**
- `{language}/build-sovdevlogger.sh` - Language-specific build script
- Each language knows its own build process
- Handles dependencies, compilation, and verification

---

### Step 4: Run Test

**This is where Human vs LLM differs!**

**Human developers (VSCode terminal inside container):**
```bash
# Direct execution - you're already inside!
cd typescript/test/e2e/company-lookup
./run-test.sh

# Or
npm test
python -m pytest
go test ./...
```

**LLM developers (host machine):**
```bash
# Call the test tool (recommended)
./specification/tools/in-devcontainer.sh -e "cd /workspace/specification/tools && ./run-company-lookup.sh {language}"

# Or run test script directly:
./specification/tools/in-devcontainer.sh -e "cd /workspace/{language}/test/e2e/company-lookup && ./run-test.sh"
```

---

### Step 5: Validate Log Files FIRST ⚡ (Fast & Local)

**CRITICAL:** Always validate log files before checking OTLP backends.

**Human developers (VSCode terminal inside container):**
```bash
validate-log-format.sh {language}/test/e2e/company-lookup/logs/dev.log
```

**LLM developers (host machine - use wrapper):**
```bash
./specification/tools/in-devcontainer.sh -e "cd /workspace/specification/tools && ./validate-log-format.sh {language}/test/e2e/company-lookup/logs/dev.log"
```

**That's it!** The validation tool automatically checks:
- ✅ JSON schema compliance
- ✅ Log entry count (should be 17)
- ✅ Unique trace IDs (should be 13)
- ✅ Field naming (snake_case)
- ✅ Log type distribution (11 transaction, 2 job.status, 4 job.progress)
- ✅ Required fields present
- ✅ Correct data types

**If validation passes, you're ready for Step 4 (OTLP backends).**

**For debugging failures**, see manual inspection commands in the "Debugging Commands" section below.

**Why validate log files first?**

| Benefit | Description |
|---------|-------------|
| ⚡ **Instant feedback** | No waiting for backend propagation (0 seconds vs 5-10 seconds) |
| 🔧 **No dependencies** | Works without Kubernetes cluster running |
| 🎯 **Catches most issues** | ~90% of problems are format errors, field naming, missing data |
| 🚀 **Fast iteration** | Edit → Run → Check logs in seconds |
| 📊 **Full visibility** | See exact JSON structure and all fields |
| 🐛 **Easy debugging** | Direct file inspection with standard tools (jq, grep) |

**Common Issues Caught by Log File Validation:**
- ❌ Wrong field names (camelCase instead of snake_case)
- ❌ Missing required fields (trace_id, log_type, service_name)
- ❌ Incorrect log_type values
- ❌ Malformed JSON (syntax errors)
- ❌ Wrong number of log entries
- ❌ Missing trace_id correlation
- ❌ Incorrect timestamp format

---

### Step 6: Validate OTLP Backends SECOND 🔄 (After Log Files Pass)

Only after log files are correct, validate that telemetry reaches the observability backends.

**CRITICAL:** Follow the complete 8-step validation sequence documented in `specification/tools/README.md`.

**See:** **🔢 Validation Sequence (Step-by-Step)** section in `specification/tools/README.md`

This ensures:
- ⛔ Blocking points between steps (don't skip ahead)
- ✅ Progressive confidence building through Steps 1-8
- 🎯 Clear failure modes and remediation at each step

**Quick validation (automated Steps 1-7):**

**Human developers (VSCode terminal inside container):**
```bash
# Wait 5-10 seconds for logs to propagate to backends
sleep 10

# Run complete backend validation (Steps 1-7)
run-full-validation.sh {language}

# You MUST still do Step 8 manually:
# - Open http://grafana.localhost
# - Verify ALL 3 panels show data
```

**LLM developers (host machine - use wrapper):**
```bash
# Wait 5-10 seconds for logs to propagate to backends
sleep 10

# Run complete backend validation (Steps 1-7)
./specification/tools/in-devcontainer.sh -e "cd /workspace/specification/tools && ./run-full-validation.sh {language}"

# You MUST still do Step 8 manually:
# - Open http://grafana.localhost
# - Verify ALL 3 panels show data
```

**This validation checks (Steps 1-7):**
- ✅ Step 1: Logs in file (schema, count, trace IDs)
- ✅ Step 2: Logs in Loki (OTLP export working)
- ✅ Step 3: Metrics in Prometheus (OTLP export working, labels correct)
- ✅ Step 4: Traces in Tempo (OTLP export working)
- ✅ Step 5: Grafana-Loki connection (datasource working)
- ✅ Step 6: Grafana-Prometheus connection (datasource working)
- ✅ Step 7: Grafana-Tempo connection (datasource working)
- ⚠️ Step 8: Manual Grafana dashboard verification (YOU must do this)

**Or query backends directly:**

**Human developers:**
```bash
query-loki.sh sovdev-test-company-lookup-{language}
query-prometheus.sh sovdev-test-company-lookup-{language}
query-tempo.sh sovdev-test-company-lookup-{language}
```

**LLM developers:**
```bash
./specification/tools/in-devcontainer.sh -e "cd /workspace/specification/tools && ./query-loki.sh sovdev-test-company-lookup-{language}"
./specification/tools/in-devcontainer.sh -e "cd /workspace/specification/tools && ./query-prometheus.sh sovdev-test-company-lookup-{language}"
./specification/tools/in-devcontainer.sh -e "cd /workspace/specification/tools && ./query-tempo.sh sovdev-test-company-lookup-{language}"
```

**Why validate OTLP backends second?**
- Requires wait time for backend propagation (5-10 seconds)
- Depends on Kubernetes cluster being available
- Tests network connectivity and OTLP configuration
- Validates observability stack integration

---

## Complete Workflow Examples

**Key Difference:** Only **Step 4 (Run Test)** differs between Human and LLM developers. All other steps (Edit, Lint, Build, Validate Logs, Validate OTLP) work the same due to file synchronization.

### Example 1: Human Developer (VSCode Terminal)

Working inside VSCode with DevContainer extension - terminal is already inside container:

```bash
# ============================================
# Step 1: Edit code in VSCode
# ============================================
# (use VSCode editor to modify source files)

# ============================================
# Step 2: Lint code (MANDATORY - must pass before build)
# ============================================
cd python
make lint

# Exit code 0? ✅ Proceed
# Exit code non-zero? ⛔ Fix errors first

# ============================================
# Step 3: Build library (if needed)
# ============================================
./build-sovdevlogger.sh

# ============================================
# Step 4: Run test (terminal is inside container)
# ============================================
cd test/e2e/company-lookup
./run-test.sh

# ============================================
# Step 5: Validate log files (FAST - do this first!)
# ============================================
../../../specification/tools/validate-log-format.sh logs/dev.log

# That's it! Validation tool checks everything automatically.
# If it passes, move to Step 6.

# ============================================
# Step 6: If validation passes, check OTLP backends
# ============================================
sleep 10
../../../specification/tools/run-full-validation.sh python
```

---

### Example 2: LLM Developer (Host Machine)

Working on host machine - must use `in-devcontainer.sh -e "command"` for ALL code execution:

```bash
# ============================================
# Step 1: Edit code on host
# ============================================
# (LLM uses Read/Edit/Write tools to modify source files)

# ============================================
# Step 2: Lint code (MANDATORY - must pass before build)
# ============================================
./specification/tools/in-devcontainer.sh -e "cd /workspace/python && make lint"

# Exit code 0? ✅ Proceed
# Exit code non-zero? ⛔ Fix errors first

# ============================================
# Step 3: Build library (if needed)
# ============================================
./specification/tools/in-devcontainer.sh -e "cd /workspace/python && ./build-sovdevlogger.sh"

# ============================================
# Step 4: Run test in DevContainer (using wrapper)
# ============================================
./specification/tools/in-devcontainer.sh -e "cd /workspace/specification/tools && ./run-company-lookup.sh python"

# Or run test script directly:
# ./specification/tools/in-devcontainer.sh -e "cd /workspace/python/test/e2e/company-lookup && ./run-test.sh"

# ============================================
# Step 5: Validate log files (FAST - do this first!)
# ============================================
./specification/tools/in-devcontainer.sh -e "cd /workspace/specification/tools && ./validate-log-format.sh python/test/e2e/company-lookup/logs/dev.log"

# That's it! Validation tool checks everything automatically.
# If it passes, move to Step 6.

# ============================================
# Step 6: If validation passes, check OTLP backends
# ============================================
sleep 10
./specification/tools/in-devcontainer.sh -e "cd /workspace/specification/tools && ./run-full-validation.sh python"
```

---

## Quick Reference: Development Commands

### Essential Commands

**LLM developers (from host - use wrapper with -e flag for ALL commands):**
```bash
# Lint code (MANDATORY before build)
./specification/tools/in-devcontainer.sh -e "cd /workspace/{language} && make lint"

# Auto-fix linting issues
./specification/tools/in-devcontainer.sh -e "cd /workspace/{language} && make lint-fix"

# Build library
./specification/tools/in-devcontainer.sh -e "cd /workspace/{language} && ./build-sovdevlogger.sh"

# Run test
./specification/tools/in-devcontainer.sh -e "cd /workspace/specification/tools && ./run-company-lookup.sh {language}"

# Validate log files (instant)
./specification/tools/in-devcontainer.sh -e "cd /workspace/specification/tools && ./validate-log-format.sh {language}/test/e2e/company-lookup/logs/dev.log"

# Validate backends (after 10s wait)
./specification/tools/in-devcontainer.sh -e "cd /workspace/specification/tools && ./run-full-validation.sh {language}"
```

**Human developers (VSCode terminal inside container - run directly):**
```bash
# Lint code (MANDATORY before build)
cd {language} && make lint

# Auto-fix linting issues
cd {language} && make lint-fix

# Build library
cd {language} && ./build-sovdevlogger.sh

# Run test
cd {language}/test/e2e/company-lookup && ./run-test.sh

# Validate log files (instant)
validate-log-format.sh {language}/test/e2e/company-lookup/logs/dev.log

# Validate backends (after 10s wait)
run-full-validation.sh {language}
```


## Best Practices

### ✅ DO

1. **Always validate log files before OTLP backends**
   - Catches 90% of issues instantly
   - No waiting for infrastructure

2. **Use validation tools early and often**
   - Run `validate-log-format.sh` after every change
   - Catch issues immediately, not at the end

3. **Run complete validation before committing**
   - Linting passes (0 errors)
   - All log file checks pass
   - All backend validations pass

4. **Follow the 6-step loop consistently**
   - Edit → Lint → Build → Run → Validate Logs → Validate OTLP
   - Don't skip steps
   - Linting is MANDATORY before build
   - Only Step 4 (Run) differs between Human/LLM developers

### ❌ DON'T

1. **Don't skip log file validation**
   - "Just checking OTLP" wastes time waiting for propagation
   - You'll miss obvious format errors

2. **Don't wait for OTLP when developing**
   - Use log files for fast iteration
   - Only check OTLP periodically

3. **Don't run tests on host machine** (LLM developers)
   - Always use `in-devcontainer.sh` wrapper
   - Ensures consistent runtime environment
   - Note: Human developers work inside container already (VSCode terminal)

4. **Don't commit without full validation**
   - Both log files AND backends must pass
   - Use `run-full-validation.sh {language}`

### ⚠️ For LLMs Specifically

**CRITICAL:** Follow the examples in this document exactly, with no variations.

1. **Update your checklist as you work**
   - Checklist location: `{language}/llm-work/llm-checklist-{language}.md`
   - Mark items `in_progress` when starting, `completed` when done
   - Prevents forgetting critical steps
   - See "For LLMs: Track Your Progress with the Checklist" section above

2. **Use tool commands EXACTLY as shown in examples**
   - Do NOT add parameters (like `--limit`) unless example shows them
   - Do NOT use manual inspection tools (`jq`, `python -m json.tool`, `cat`)
   - Copy the command patterns character-for-character

3. **Trust the validation tools**
   - `validate-log-format.sh` checks everything automatically (schema, fields, types, trace IDs)
   - If you think you need to manually inspect, you're wrong
   - The tools give you all the information you need

4. **Follow the sequence**
   - Edit → Run → Validate Logs → Validate OTLP
   - Don't query backends before running tests (query tools READ data, they don't GENERATE data)
   - Run tests FIRST, then query results

5. **When in doubt, re-read the examples**
   - The examples in this document are complete and correct
   - If your command doesn't match an example, you're doing it wrong

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
- **[tools/README.md](./tools/README.md)** - Complete validation tool documentation

---

**Last Updated:** 2025-10-31
