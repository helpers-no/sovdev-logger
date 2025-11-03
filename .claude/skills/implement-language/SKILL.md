---
description: "Systematically implement sovdev-logger in a new programming language. INCLUDES MANDATORY VALIDATION - you must run validation tools before claiming complete. Use when implementing Python, Go, Rust, C#, PHP, or other languages."
version: "3.0.0"
last_updated: "2025-10-31"
references:
  - specification/llm-work-templates/
  - specification/tools/README.md
  - specification/01-api-contract.md
  - .claude/skills/_SHARED.md
---

# Implement Language Skill

When the user asks to implement sovdev-logger in a new programming language, initialize the workspace and follow the systematic process.

## ⚠️ IMPORTANT: Directory Restrictions

**See:** `.claude/skills/_SHARED.md` → "Directory Restrictions"

**Summary:** Only use `specification/`, `typescript/`, `{language}/`, and `.claude/skills/` directories. Do NOT access `terchris/` or `topsecret/`.

---

## Step 0: Understand Environment (CRITICAL - Read First!)

**🔴 MANDATORY: Read these files BEFORE doing anything else:**

### 0.1 Read Environment Configuration

```bash
Read specification/05-environment-configuration.md (complete file)
```

**You MUST understand:**
- DevContainer architecture (/workspace mount point)
- How commands execute (host machine vs inside container)
- Network endpoints (host.docker.internal, otel.localhost, Host headers)
- Language installation process (what's pre-installed, what needs installation)
- File operations (read/write on host, execute in container)

### 0.2 Read Command Wrapper Script

```bash
Read specification/tools/in-devcontainer.sh (read the actual script file)
```

**You MUST understand:**
- **MODE 1**: Run scripts from specification/tools/ directory
  - Example: `./specification/tools/in-devcontainer.sh query-loki.sh service-name`
- **MODE 2**: Execute arbitrary commands with `-e` flag
  - Example: `./specification/tools/in-devcontainer.sh -e "cd /workspace/typescript && npm test"`
- All paths inside container start with `/workspace/`
- Script installation paths: `/workspace/.devcontainer/additions/install-dev-{language}.sh`

### 0.3 Checkpoint Questions

**Before proceeding, you MUST be able to answer these:**

1. **Q:** How do you run arbitrary commands inside the DevContainer?
   **A:** `./specification/tools/in-devcontainer.sh -e "command"`

2. **Q:** What is the workspace path inside the container?
   **A:** `/workspace` (maps to project root on host)

3. **Q:** How do you install .NET/C# in the DevContainer?
   **A:** `./specification/tools/in-devcontainer.sh -e "/workspace/.devcontainer/additions/install-dev-csharp.sh"`

4. **Q:** What Host header is required for OTLP exports?
   **A:** `Host: otel.localhost`

5. **Q:** What endpoint do you use for OTLP exports from inside container?
   **A:** `http://host.docker.internal/v1/logs` (with Host header)

**If you CANNOT answer all these questions correctly → STOP and re-read the files above.**

### Why This Matters

**90% of early implementation mistakes come from environment misunderstanding:**
- ❌ Wrong command patterns → "command not found" errors
- ❌ Wrong file paths → "No such file or directory" errors
- ❌ Wrong endpoints → "connection refused" errors
- ❌ Missing Host headers → 404 errors from Traefik
- ❌ Wrong script names → Installation failures

**Understanding the environment FIRST saves hours of debugging later.**

---

## Step 1: Initialize Workspace

**Extract the language** from the user's request:
- "Implement in Go" → language = `go`
- "Add Python support" → language = `python`
- "Create C# implementation" → language = `csharp` (lowercase, no special chars)

**Check if workspace exists:**
```bash
ls {language}/llm-work/
```

**If directory does NOT exist:**
```bash
./specification/llm-work-templates/enforcement/init-language-workspace.sh {language}
```

This creates:
- `{language}/llm-work/ROADMAP.md` - 13-task checklist
- `{language}/llm-work/CLAUDE.md` - Workflow instructions
- `{language}/llm-work/task-*.md` - Task details
- `{language}/llm-work/otel-sdk-comparison.md` - SDK research template
- `{language}/llm-work/implementation-notes.md` - Notes template

---

## Step 2: Read Instructions and Update ROADMAP (MANDATORY)

**🔴 CRITICAL: You MUST execute these steps IN ORDER. Do NOT skip.**

### 2.1: Read ROADMAP.md

Execute this command NOW (use Bash tool):

```bash
cat {language}/llm-work/ROADMAP.md
```

**After reading, you MUST be able to answer:**
- What is the first uncompleted task marked `[ ]`?
- What phase is it in?
- What does the task require?

### 2.2: Update ROADMAP.md - Mark Task In Progress

**Before doing ANY work, update ROADMAP.md:**

Use the Edit tool to:
1. Find the first uncompleted task: `[ ]`
2. Change it to: `[-] 🏗️ 2025-11-03` (use today's date)
3. Update "Last updated" date at the top of ROADMAP.md

**Example edit:**
```markdown
BEFORE:
- [ ] 11. File validation passes

AFTER:
- [-] 🏗️ 2025-11-03 - 11. File validation passes
```

**This is NOT optional. If you skip this, you violate the core process.**

### 2.3: Read CLAUDE.md

Execute this command NOW (use Bash tool):

```bash
cat {language}/llm-work/CLAUDE.md
```

**This file contains the complete workflow instructions. Read it thoroughly.**

### 2.4: Checkpoint - Confirm You Understand

**Before proceeding, confirm:**
- [ ] I have READ ROADMAP.md
- [ ] I have UPDATED ROADMAP.md to mark the current task as in progress `[-]`
- [ ] I have UPDATED "Last updated" date in ROADMAP.md
- [ ] I have READ CLAUDE.md
- [ ] I know which task I'm working on
- [ ] I know what that task requires

**If ANY answer is NO → STOP and go back to 2.1**

---

## Step 2.5: Critical Process Rules (DO NOT SKIP)

**Based on lessons from C# implementation sessions 3 & 4.**

These rules prevent the most common mistakes that lead to user corrections:

### Rule 1: Always Check Latest Stable Version First (Phase 0, Task 1)

- **Before starting implementation**, check for latest stable or RC version on package repository
- Document version selection rationale in your notes
- **Never** use versions older than 6 months without documented justification
- **Example mistake**: C# Session 4 used OpenTelemetry 1.13.1, but 1.14.0-rc.1 had critical histogram export fixes
- **Task 1 now enforces**: Mandatory version check before proceeding to Task 2

### Rule 2: Always Verify TypeScript Baseline Before Debugging (Phase 0, Task 2)

- **Before debugging [LANGUAGE] issues**, run TypeScript test to verify infrastructure health
- **Decision tree**:
  - ✅ TypeScript test passes → Infrastructure is healthy → [LANGUAGE] code has a bug
  - ❌ TypeScript test fails → Infrastructure is broken → Fix Docker/Loki/Prometheus/Tempo first
- **Never** debug code when infrastructure is broken (wasted time)
- **Command**: `./specification/tools/in-devcontainer.sh -e "cd /workspace/typescript/test/e2e/company-lookup && ./run-test.sh"`
- **Task 2 now enforces**: TypeScript baseline verification before proceeding

### Rule 3: Never Claim Completion Without Validation

**Task completion requires PROOF, not just claims:**

- **Task 6 complete** = OTLP exporters implemented AND connectivity verified in Loki/Prometheus/Tempo
- **Task 7 complete** = File logging implemented AND `validate-log-format.sh` passes
- **Task 8 complete** = All 8 API functions implemented AND E2E test passes AND full validation passes

**Evidence from C# Session 3:**
- LLM claimed "Task 8 complete" without validation
- Result: 5 user corrections required (missing attributes, wrong initialization order, metrics not exporting)
- Total debugging time: 3+ hours
- **Validation would have caught all issues in 2 minutes**

**Task 8 now enforces**: Mandatory end-to-end validation section before claiming complete

### Rule 4: Research Official SDK Examples (Phase 0, Task 3)

- **Before implementing**, search GitHub for official SDK examples
- **Critical for**: Instrument creation order (Counter, Histogram, UpDownCounter)
- **Example mistake**: C# requires creating instruments BEFORE MeterProvider.Build()
- Creating instruments AFTER Build() = instruments don't export (hours of debugging)
- **Task 3 now includes**: Subtask to research instrument lifecycle patterns

### Rule 5: Follow the Development Loop (specification/09-development-loop.md)

**6-step iterative workflow:**
1. Edit code
2. **Lint** (MANDATORY - must pass before Step 3)
3. Build
4. Run/Test
5. Validate Logs (fast, local)
6. Validate OTLP (slow, requires infrastructure)

**Key points:**
- Linting is **BLOCKING** - if linting fails, you cannot proceed to build
- Validate logs FIRST (instant feedback), then OTLP SECOND (slower)
- Make small changes, validate frequently (not one big change at end)

**Complete details**: `specification/09-development-loop.md`

### Rule 6: Consult TypeScript Reference When Unsure

- **TypeScript is the reference implementation** - defines correct behavior
- When unsure about API behavior, check `typescript/src/index.ts` and `typescript/src/logger.ts`
- Compare your implementation side-by-side with TypeScript
- **Task 6 now enforces**: Check TypeScript reference before implementing OTLP exporters

---

## If You Get Stuck

**Problem:** Don't know what to do next
**Solution:** Read ROADMAP.md - it tells you the next task

**Problem:** Don't know how to do a task
**Solution:** Read the linked task file (task-XX-name.md) - it has detailed steps

**Problem:** Validation failing
**Solution:**
1. Read `{language}/llm-work/task-12-validation.md` for troubleshooting
2. Read `specification/tools/README.md` for tool usage
3. Check ROADMAP.md is updated (enforcement blocks if not)

---

## ⚠️ Execute Commands, Don't Describe Them

**See:** `.claude/skills/_SHARED.md` → "Execute Commands, Don't Describe Them"

**Critical Rule:** Execute commands immediately using Bash tool. Do NOT describe what you "should" or "will" do.

---

**Remember:** Skills are routers. The actual instructions are in CLAUDE.md and ROADMAP.md. Read those files.
