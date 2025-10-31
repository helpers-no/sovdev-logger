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

## Step 2: Read Instructions

**Read these TWO files completely:**

```bash
# 1. Read CLAUDE.md - Workflow instructions
cat {language}/llm-work/CLAUDE.md

# 2. Read ROADMAP.md - 13-task checklist
cat {language}/llm-work/ROADMAP.md
```

**Then follow the process described in those files.**

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
