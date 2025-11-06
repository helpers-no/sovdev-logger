---
description: "Guide to validation and query tools for debugging sovdev-logger implementations. Directs you to the comprehensive tool documentation and helps select the right tool for your task."
version: "3.0.0"
last_updated: "2025-10-31"
references:
  - specification/tools/README.md
  - specification/llm-work-templates/validation-sequence.md
  - specification/09-development-loop.md
  - .claude/skills/_SHARED.md
---

# Validation Tools Skill

When you need to validate outputs, query backends, or debug issues, this skill guides you to the right documentation.

## 📚 Authoritative Documentation

**For validation:** `specification/llm-work-templates/validation-sequence.md`
- Complete 8-step validation sequence
- All commands with examples
- Step-by-step blocking points
- Success criteria

**For tools reference:** `specification/tools/README.md`
- Complete list of ALL tools
- Tool comparison tables
- Command syntax and examples
- Common debugging scenarios
- Troubleshooting workflows

**For development workflow:** `specification/09-development-loop.md`
- 6-step iterative development loop
- When to validate (fast vs thorough)
- Best practices

## When to Use Which Document

### During Active Development
**Read:** `specification/09-development-loop.md`
- Follow 6-step loop (Edit → Lint → Build → Run → Validate logs → Validate OTLP)
- Fast feedback workflow

### For Complete Validation (Before Claiming Complete)
**Read:** `specification/llm-work-templates/validation-sequence.md`
- Follow 8-step sequence exactly
- Do NOT skip steps
- Step 8 (Grafana) is MANDATORY

### For Debugging Issues
**Read:** `specification/tools/README.md`
- See "Common Debugging Scenarios" section
- Find the right query tool for your issue

### For Tool Comparisons
**Read:** `specification/tools/README.md`
- See "Quick Reference" table
- See "Validation Scripts Comparison" table

## ⚠️ Execute Commands, Don't Describe Them

**See:** `.claude/skills/_SHARED.md` → "Execute Commands, Don't Describe Them"

**Critical Rule:** When you find commands in the documentation, EXECUTE them immediately using the Bash tool. Do NOT describe what you "should" or "will" do.

---

**Remember:** Skills are routers. Read the referenced documentation for actual commands and procedures.
