---
description: "Guide through the 6-step iterative development workflow for sovdev-logger. Optimized for fast feedback during active development."
version: "3.0.0"
last_updated: "2025-10-31"
references:
  - specification/09-development-loop.md
  - specification/10-code-quality.md
  - specification/llm-work-templates/validation-sequence.md
  - specification/tools/README.md
  - .claude/skills/_SHARED.md
---

# Development Loop Skill

When the user is actively developing sovdev-logger and wants to test changes, guide them through the 6-step development loop.

## ⚠️ IMPORTANT: Directory Restrictions

**See:** `.claude/skills/_SHARED.md` → "Directory Restrictions"

**Summary:** Only use `specification/` and `{language}/` directories. Do NOT access `terchris/` or `topsecret/`.

## 📚 Authoritative Documentation

**Primary:** `specification/09-development-loop.md`
- Complete 6-step development loop
- All commands with examples
- Fast vs thorough iteration strategies
- Best practices

**Linting:** `specification/10-code-quality.md`
- Linting philosophy
- Required rules
- Language-specific configurations

**Validation:** `specification/llm-work-templates/validation-sequence.md`
- Complete 8-step validation sequence
- When to run full validation vs quick validation

**Tools:** `specification/tools/README.md`
- Complete tool reference
- Debugging scenarios

## The 6-Step Loop (Summary)

**Read `specification/09-development-loop.md` for complete details and commands.**

1. **Edit Code** - Modify source or test files
2. **Lint Code** - MANDATORY, must pass before build
3. **Build** - When source changed
4. **Run Test** - Execute company-lookup test
5. **Validate Logs FIRST** - Fast feedback (0 seconds)
6. **Validate OTLP SECOND** - Thorough validation (periodically)

## Key Principles

**From specification/09-development-loop.md:**
- Validate log files FIRST (fast, local) before OTLP (slow, infrastructure)
- Run linting BEFORE build (catches issues early)
- Use fast iteration (Steps 1-5) most of the time
- Use thorough validation (complete 8-step sequence) periodically

## When to Use What

**Every code change:**
- Follow Steps 1-5 (fast loop, ~30-60 seconds)

**Every 3-5 iterations or before committing:**
- Follow complete 8-step validation sequence
- See `specification/llm-work-templates/validation-sequence.md`

**When debugging:**
- See `specification/tools/README.md` → "Common Debugging Scenarios"

## ⚠️ Execute Commands, Don't Describe Them

**See:** `.claude/skills/_SHARED.md` → "Execute Commands, Don't Describe Them"

**Critical Rule:** When you find commands in the documentation, EXECUTE them immediately using the Bash tool. Do NOT describe what you "should" or "will" do.

---

**Remember:** Skills are routers. Read `specification/09-development-loop.md` for actual commands and detailed workflow.
