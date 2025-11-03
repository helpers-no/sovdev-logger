# Instructions for Claude Code - [LANGUAGE] Implementation

**Last updated**: [DATE]
**Language**: [LANGUAGE]
**Working directory**: [LANGUAGE]/llm-work/

---

┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃ 🛑 MANDATORY FIRST STEPS - DO THESE NOW BEFORE READING FURTHER    ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

**Execute these steps IN ORDER using the Bash and Edit tools:**

### Step 1: Read ROADMAP.md
```bash
cat [LANGUAGE]/llm-work/ROADMAP.md
```

### Step 2: Update ROADMAP.md
Use the **Edit tool** to:
1. Find the first uncompleted task: `[ ]`
2. Change to: `[-] 🏗️ YYYY-MM-DD` (today's date)
3. Update "Last updated" date at top of file

**Example:**
```diff
- [ ] 11. File validation passes
+ [-] 🏗️ 2025-11-03 - 11. File validation passes
```

### Step 3: Confirm
- [ ] I have READ ROADMAP.md
- [ ] I have UPDATED ROADMAP.md to mark task in progress
- [ ] I have UPDATED "Last updated" date

**Only after completing Steps 1-3 may you continue reading this file.**

---

┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃ 📘 CRITICAL: TypeScript is the Reference Implementation           ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

**Before implementing ANYTHING in [LANGUAGE], check TypeScript FIRST:**

### When to Check TypeScript:

1. **Before implementing** → Check TypeScript for file structure, .env configuration
2. **When stuck** → Compare your code to TypeScript implementation
3. **Before claiming complete** → Compare output to TypeScript output

### Key TypeScript Files:
- `typescript/src/logger.ts` - Main implementation
- `typescript/test/e2e/company-lookup/` - E2E test structure
- `typescript/test/e2e/company-lookup/.env` - Configuration pattern

### Critical Patterns to Copy from TypeScript:
- ✅ .env file structure and variables
- ✅ OTLP endpoint configuration
- ✅ File logging structure
- ✅ Metrics implementation
- ✅ Test program structure

**Rule: When unsure, copy TypeScript's approach. Do NOT invent your own.**

---

## 🎯 Primary Directive

**ROADMAP.md is your master checklist**

This is not optional. This is not a suggestion. ROADMAP.md is the FIRST thing you read and the LAST thing you update.

```bash
# At session start: Read it
# During work: Update it
# At session end: Mark tasks complete
Read [LANGUAGE]/llm-work/ROADMAP.md
```

---

## 📋 Your Working Documents

### Master Checklist
- **File**: `ROADMAP.md`
- **Purpose**: Single source of truth for implementation progress
- **Structure**: 13 high-level tasks across 4 phases
- **Status tracking**: Checkbox states with timestamps

### Detailed Task Files
- **Location**: `task-*.md` files in same directory
- **Purpose**: Step-by-step instructions for complex tasks
- **When to use**: When ROADMAP links to `[Details](task-XX-name.md)`

### Progress Tracking
- **ROADMAP.md**: Master checklist (YOU update this)
- **TodoWrite**: Internal tool (YOU may use for session tracking)
- **Single source of truth**: ROADMAP.md is authoritative

---

## 🚦 Workflow Rules

### 1. Starting Work

When you start a session:

```markdown
1. ✅ READ ROADMAP.md first
2. ✅ Identify next uncompleted task: `[ ]`
3. ✅ If task links to [Details](task-XX.md) → Read that file
4. ✅ Understand success criteria before starting
5. ✅ Mark task in progress: `[-] 🏗️ YYYY-MM-DD`
6. ✅ Update "Last updated" date at top of ROADMAP.md
```

**Example edit**:
```markdown
Before:
- [ ] 3. Research OTEL SDK for [LANGUAGE]

After:
- [-] 🏗️ 2025-10-31 - 3. Research OTEL SDK for C#
```

**Tool to use**: `Edit` tool to update ROADMAP.md

### 2. During Work

**Progress updates**:
- Update ROADMAP.md when completing significant milestones
- If task has detailed file (task-XX.md), update checkboxes there too
- Keep "Last updated" date current

**TodoWrite integration** (optional):
- You MAY create TodoWrite list for session tracking
- TodoWrite is SECONDARY to ROADMAP.md
- Before claiming session complete → Update ROADMAP.md from TodoWrite

**Reading order** (for subtasks):
```
Read: task-XX-name.md
  ↓
Extract: Subtasks 1-10
  ↓
Optional: Create TodoWrite from subtasks
  ↓
Execute: Follow subtasks in order
  ↓
Update: Check off subtasks in task-XX-name.md
  ↓
Complete: Check off parent task in ROADMAP.md
```

### 3. Completing Tasks

**Before marking task complete `[x]`**:

Check ALL success criteria from task description:
- ✅ All subtasks completed (if task has detail file)
- ✅ Code written and tested
- ✅ Validation scripts pass (if applicable)
- ✅ Files created in correct locations
- ✅ No errors or warnings

**Marking complete**:
```markdown
Before:
- [-] 🏗️ 2025-10-31 - 3. Research OTEL SDK for C#

After:
- [x] ✅ 2025-10-31 - 3. Research OTEL SDK for C#
```

**Moving to Recently Completed**:
- When a phase completes, move all tasks to "Recently Completed" section
- Preserve timestamps and notes
- Keeps active view clean while maintaining history

### 4. Phase Transitions

**Phase Locking Rules**:
- Phases show 🔒 LOCKED until previous phase 100% complete
- Cannot start Phase 1 tasks until Phase 0 is 4/4 complete
- Cannot start Phase 2 tasks until Phase 1 is 4/4 complete
- Etc.

**When phase completes**:
```markdown
1. ✅ Update phase progress: "Phase 0: Planning (4/4 complete) ✅"
2. ✅ Move tasks to "Recently Completed" section
3. ✅ Unlock next phase: Change "🔒 LOCKED" to "🔄 IN PROGRESS"
4. ✅ Update Progress Summary at bottom
5. ✅ Update "Last updated" date
```

**Example**:
```markdown
Before:
## Phase 0: Planning (3/4 complete) 📋
- [x] ✅ 2025-10-31 - 1. Check OTEL SDK maturity
- [x] ✅ 2025-10-31 - 2. Verify TypeScript baseline
- [x] ✅ 2025-10-31 - 3. Research OTEL SDK
- [-] 🏗️ 2025-10-31 - 4. Create SDK comparison doc

## Phase 1: Implementation (0/4 complete) 🔒 LOCKED
[Unlocked after Phase 0: 4/4 complete]

After (when task 4 completes):
## Phase 0: Planning (4/4 complete) ✅
[All tasks moved to Recently Completed section]

## Phase 1: Implementation (0/4 complete) 🔄 IN PROGRESS
- [ ] 5. Setup project structure
...

## ✅ Recently Completed
### Phase 0: Planning (Completed 2025-10-31)
- [x] ✅ 2025-10-31 - 1. Check OTEL SDK maturity
- [x] ✅ 2025-10-31 - 2. Verify TypeScript baseline
- [x] ✅ 2025-10-31 - 3. Research OTEL SDK
- [x] ✅ 2025-10-31 - 4. Create SDK comparison doc
```

---

## 🎯 Checkpoint Questions

**Before claiming ANY task complete, ask yourself**:

### Task Completion
- [ ] Did I READ the task description completely?
- [ ] Did I READ the detailed task file (if linked)?
- [ ] Did I complete ALL subtasks (if any)?
- [ ] Did I run validation scripts (if applicable)?
- [ ] Did I verify output matches expectations?
- [ ] Did I update ROADMAP.md checkbox?
- [ ] Did I update "Last updated" date?

### Code Quality
- [ ] Does the code compile/build without errors?
- [ ] Does the code follow [LANGUAGE] conventions?
- [ ] Are all 8 API functions implemented (if applicable)?
- [ ] Do OTLP exporters have `Host: otel.localhost` header?
- [ ] Are metric labels using underscores (not dots)?

### Validation
- [ ] Did I run validation via DevContainer? (e.g., `./specification/tools/in-devcontainer.sh -e "./specification/tools/validate-log-format.sh"`)
- [ ] Did I check logs appear in Loki?
- [ ] Did I check metrics appear in Prometheus?
- [ ] Did I check traces appear in Tempo?
- [ ] Did I verify Grafana dashboard shows data?

### Process
- [ ] Did I follow the recommended reading order?
- [ ] Did I use provided validation tools (not kubectl)?
- [ ] Did I update task-XX.md checkboxes (if applicable)?
- [ ] Did I document findings in otel-sdk-comparison.md (if Phase 0)?

**If ANY answer is "No" → Task is NOT complete**

---

## 🔄 Integration with TodoWrite

### TodoWrite Purpose
- **Session-level tracking**: Track work within current session
- **NOT authoritative**: ROADMAP.md is the single source of truth
- **Synchronization required**: Update ROADMAP.md before ending session

### Recommended Pattern

**At session start**:
```
1. Read ROADMAP.md
2. Identify next task (e.g., "Task 3: Research OTEL SDK")
3. Read task-03-research-otel-sdk.md
4. (Optional) Create TodoWrite with subtasks from task-03
5. Mark task as in progress in ROADMAP.md
```

**During session**:
```
1. Work through TodoWrite items (if created)
2. Update task-03-research-otel-sdk.md checkboxes
3. Make progress
```

**Before ending session**:
```
1. Check TodoWrite completion status
2. Update task-03-research-otel-sdk.md with final status
3. If ALL subtasks complete → Mark task complete in ROADMAP.md
4. If PARTIAL → Keep task as "in progress" in ROADMAP.md
5. Update "Last updated" date
```

### TodoWrite vs ROADMAP.md

| Aspect | ROADMAP.md | TodoWrite |
|--------|------------|-----------|
| **Authority** | ✅ Source of truth | ❌ Session helper only |
| **Persistence** | ✅ Survives sessions | ❌ Session-specific |
| **Visibility** | ✅ User sees progress | ❌ Internal to Claude |
| **Structure** | ✅ 4 phases, 13 tasks | ✅ Flexible |
| **Subtasks** | ❌ Links to task files | ✅ Native support |
| **Update** | ✅ You MUST update | ⚠️ Optional helper |

**Rule**: If conflict between TodoWrite and ROADMAP.md → ROADMAP.md wins

---

## ✅ Validation Rules

### Critical Principle: Validation-First Development

**Validation is not a phase at the end. Validation is continuous throughout development.**

### Two-Level Validation Strategy

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
- Tools: Automated validation script (`run-full-validation.sh`) runs Steps 1-7
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

### Continuous Validation
Throughout implementation:
- Run validation scripts early and often
- Don't wait until "end" to validate
- Fix issues immediately when found

### Validation Tools

**Complete validation tool documentation**: See `specification/tools/README.md`

This includes:
- Two-level validation strategy (TypeScript baseline + language-specific)
- Complete 8-step validation sequence
- Tool usage examples for all languages
- Troubleshooting guide

**Quick reference - Tool locations**:
```bash
./specification/tools/validate-log-format.sh         # File validation
./specification/tools/query-loki.sh                  # Query Loki backend
./specification/tools/query-prometheus.sh            # Query Prometheus backend
./specification/tools/query-tempo.sh                 # Query Tempo backend
./specification/tools/run-full-validation.sh         # Complete validation
./specification/tools/in-devcontainer.sh             # DevContainer wrapper
```

### Phase-Specific Validation

**Phase 0: Planning**
- Validation: Check OTEL SDK maturity table
- Validation: Run TypeScript E2E test successfully
- Output: otel-sdk-comparison.md document

**Phase 1: Implementation**
- Validation: Code passes linting (make lint exits 0)
- Validation: Code compiles/builds
- Validation: Dependencies installed
- Validation: All 8 API functions present

**Phase 2: Testing**
- Validation: E2E test runs without errors
- Validation: 17 log entries created
- Validation: Log files in logs/ directory

**Phase 3: Validation** (MANDATORY - DO NOT SKIP)
- Validation: `validate-log-format.sh` passes
- Validation: Logs visible in Loki
- Validation: Metrics visible in Prometheus
- Validation: Traces visible in Tempo
- Validation: Grafana dashboard shows [LANGUAGE] data
- Validation: Side-by-side comparison with TypeScript

### Enforcement
- ⛔ Cannot claim Phase 2 complete without E2E test passing
- ⛔ Cannot claim Phase 3 complete without ALL validations passing
- ⛔ Cannot claim success without Grafana showing data

**If validation fails**:
1. DO NOT mark task complete
2. Document the failure
3. Debug and fix
4. Re-run validation
5. Only mark complete when ALL checks pass

---

## 🚫 Common Pitfalls - DO NOT

### Process Violations
- ❌ DO NOT skip reading ROADMAP.md at session start
- ❌ DO NOT mark tasks complete without updating ROADMAP.md
- ❌ DO NOT start Phase 1 before Phase 0 is 100% complete
- ❌ DO NOT claim success without running validation scripts
- ❌ DO NOT use kubectl directly (use provided validation tools)

### Technical Mistakes
- ❌ DO NOT forget `Host: otel.localhost` header in OTLP exporters
- ❌ DO NOT use dots in metric labels (use underscores)
- ❌ DO NOT skip TypeScript baseline verification (Phase 0, Task 2)
- ❌ DO NOT assume SDK works like TypeScript (check [LANGUAGE] docs)
- ❌ DO NOT skip linting step (make lint MUST pass before build)
- ❌ DO NOT proceed to build if linting fails (⛔ BLOCKING)

### Documentation Failures
- ❌ DO NOT leave ROADMAP.md checkboxes unchecked
- ❌ DO NOT forget to update "Last updated" date
- ❌ DO NOT leave tasks marked "in progress" when actually complete
- ❌ DO NOT forget to update Progress Summary

### Validation Shortcuts
- ❌ DO NOT skip file format validation (`validate-log-format.sh`)
- ❌ DO NOT skip backend validation (Loki, Prometheus, Tempo)
- ❌ DO NOT skip Grafana visual verification
- ❌ DO NOT claim "it works" without proof

---

## 📊 Progress Tracking Example

**Correct workflow** for Task 3:

```markdown
1. Session starts
   → Read ROADMAP.md
   → See: "[ ] 3. Research OTEL SDK for C#"
   → Read: task-03-research-otel-sdk.md

2. Start work
   → Edit ROADMAP.md: "[-] 🏗️ 2025-10-31 - 3. Research OTEL SDK for C#"
   → Update "Last updated: 2025-10-31"

3. During work
   → Check off subtasks in task-03-research-otel-sdk.md
   → Create otel-sdk-comparison.md document
   → Verify findings

4. Complete work
   → Verify ALL subtasks checked in task-03-research-otel-sdk.md
   → Edit ROADMAP.md: "[x] ✅ 2025-10-31 - 3. Research OTEL SDK for C#"
   → Update "Last updated: 2025-10-31"
   → Update Progress Summary: "Phase 0: 3/4 complete"

5. Move to next task
   → Read ROADMAP.md
   → See: "[ ] 4. Create SDK comparison doc"
   → Repeat process
```

---

## 🎓 Key Principles

**Always use latest stable versions:**
- **Policy**: Always check for and use the latest stable (or latest RC if critical fixes needed) version of OpenTelemetry SDK
- **Rationale**: Bug fixes accumulate in newer versions; using outdated versions means debugging already-fixed issues
- **Example**: C# Session 4 used 1.13.1, but 1.14.0-rc.1 had critical histogram export fixes
- **How to check**: See Phase 0, Task 1 for package repository links; record version selection in documentation
- **Never**: Use versions older than 6 months without documented rationale; skip version checking
- **Enforcement**: Task 1 now includes mandatory version check before proceeding

**TypeScript is the reference implementation:**
- TypeScript defines the correct behavior
- Your implementation must match TypeScript output exactly
- When in doubt, check what TypeScript does

**Process is enforced:**
- ✅ ROADMAP.md is MANDATORY, not optional
- ✅ TodoWrite is HELPER, not replacement
- ✅ Validation tools are REQUIRED, not shortcuts
- ✅ Success requires PROOF, not claims
- ✅ Enforcement: check-progress.sh blocks validation if ROADMAP.md not updated

**Key insight:**
> "Without enforcement, checklists become optional. Optional checklists get ignored. Ignored checklists lead to bugs."

**This system:**
- Enforcement: check-progress.sh blocks validation if ROADMAP.md not updated
- Simplicity: 13 tasks (not 243)
- Clarity: Clear success criteria per task
- Integration: TodoWrite loads from markdown
- Accountability: Single source of truth (ROADMAP.md)

---

## 📖 Reference Documents

### Core Specification (read in Phase 0)
```
specification/01-api-contract.md              # The 8 functions
specification/02-log-format.md                # JSON log format
specification/03-metrics-specification.md     # Metrics with underscores
specification/04-traces-specification.md      # Trace spans
specification/05-environment-configuration.md # DevContainer setup
specification/06-otel-backend-config.md       # OTLP endpoints
specification/07-grafana-dashboard.md         # Visualization
specification/08-testprogram-company-lookup.md # E2E test spec
specification/09-development-loop.md          # 6-step iterative workflow (MANDATORY)
specification/10-code-quality.md              # Linting standards (MANDATORY)
```

### LLM Working Documents (you create/update)
```
[LANGUAGE]/llm-work/ROADMAP.md                      # Your master checklist
[LANGUAGE]/llm-work/task-*.md                       # Detailed task files
[LANGUAGE]/llm-work/otel-sdk-comparison.md          # Phase 0 output
[LANGUAGE]/llm-work/implementation-notes.md         # Your notes
```

### Validation Tools
```
./specification/tools/validate-log-format.sh         # Phase 3
./specification/tools/check-otel-backend.sh          # Phase 3
./specification/tools/validate-grafana.sh            # Phase 3
./specification/tools/in-devcontainer.sh             # Wrapper
```

---

## 🎉 Success Criteria

**You can claim [LANGUAGE] implementation complete when**:

### ROADMAP.md Status
- [ ] All 13 tasks marked complete: `[x] ✅ YYYY-MM-DD`
- [ ] All phases at 100%: Phase 0 (4/4), Phase 1 (4/4), Phase 2 (2/2), Phase 3 (3/3)
- [ ] Progress Summary shows: "Total: 13/13 tasks (100%)"
- [ ] "Last updated" date is recent

### Code Status
- [ ] All 8 API functions implemented
- [ ] E2E test program (company-lookup) runs successfully
- [ ] 17 log entries created in logs/ directory
- [ ] JSON format matches specification/02-log-format.md

### Validation Status
- [ ] `validate-log-format.sh` passes (exit code 0)
- [ ] Logs visible in Loki with correct labels
- [ ] Metrics visible in Prometheus with underscores in labels
- [ ] Traces visible in Tempo with correct spans
- [ ] Grafana dashboard shows ALL panels with [LANGUAGE] data
- [ ] Side-by-side comparison with TypeScript shows parity

### Documentation Status
- [ ] otel-sdk-comparison.md created and accurate
- [ ] implementation-notes.md documents key decisions
- [ ] README.md in [LANGUAGE]/ directory explains how to run

### Rating
- [ ] Self-assessment ≥ 8/10

**Only when ALL criteria met → Implementation is complete**

---

## 💡 Tips for Success

### Read First, Code Later
- Spend 60 minutes reading specs (Phase 0)
- This saves hours of debugging later
- Understanding before implementing = fewer bugs

### Verify Continuously
- Run validation after each phase, not just at end
- Fix issues immediately when found
- "Works on my machine" ≠ "Passes validation"

### Follow the Process
- ROADMAP.md is your friend, not your enemy
- Checking boxes feels good and prevents mistakes
- Trust the process (it was designed from C# failures)

### Follow the Development Loop
- Use the **6-step iterative workflow**: Edit → Lint → Build → Run → Validate Logs → Validate OTLP
- **Linting is MANDATORY** (Step 2 must pass before Step 3)
- Validate logs FIRST (fast, local), then OTLP SECOND (slow, requires infrastructure)
- **Complete details:** `specification/09-development-loop.md`

### Use Validation Tools
- `validate-log-format.sh` is faster than manual checking
- `check-otel-backend.sh` is more reliable than kubectl
- `make lint` catches dead code and type errors early
- Tools exist to help you succeed

### When in Doubt
- Re-read ROADMAP.md
- Re-read task-XX.md
- Re-read specification document
- Ask user before proceeding if unclear

---

## 🔚 Final Reminder

**ROADMAP.md is not optional documentation.**
**ROADMAP.md is the PROCESS you follow.**
**Update it. Follow it. Trust it.**

**Good luck with [LANGUAGE] implementation!**

---

**Template created**: 2025-10-31
**Based on**: Claude Code community patterns, ROADMAP.md best practices, hierarchical task management research
**See also**: specification/llm-work-templates/README.md
