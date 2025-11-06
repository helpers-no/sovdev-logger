# Shared Skill Components

**Purpose:** Common content used by all sovdev-logger skills to avoid duplication.

**Usage:** Skills reference sections from this file instead of duplicating content.

---

## Directory Restrictions

**⚠️ IMPORTANT: Directory Access Rules**

When implementing or validating sovdev-logger, follow these directory access restrictions:

**DO NOT access these directories:**
- ❌ `terchris/` - Personal working directory (not part of specification)
- ❌ `topsecret/` - Contains credentials (never access)

**ONLY use these directories:**
- ✅ `specification/` - Specification documents (source of truth)
- ✅ `typescript/` - Reference implementation
- ✅ `go/`, `python/` - Example implementations (for reference)
- ✅ `{language}/` - Where new implementations are created
- ✅ `.claude/skills/` - These skills

**Rationale:**
- Personal directories (`terchris/`) may contain experimental or outdated code
- Credentials directories (`topsecret/`) must never be accessed for security
- Only official specification and reference implementations should guide development

**If you find code in personal folders, IGNORE IT.** Only use the official specification and reference implementations.

---

## Execute Commands, Don't Describe Them

**⚠️ CRITICAL: When you see a command in a skill, EXECUTE it immediately using the Bash tool.**

**Wrong approach:** ❌
```
"I should run validate-log-format.sh to check the logs..."
"Next, I'll validate the OTLP export..."
"I would recommend running the full validation suite..."
```

**Correct approach:** ✅
```
[Actually invoke Bash tool with the command shown]
```

**Why this matters:**
- Skills are designed for Claude Code's automated execution
- Describing actions wastes time and doesn't accomplish the task
- Users expect immediate action, not plans to act

**Rule:** If you find yourself typing "I should..." or "Next, I'll..." or "I would...", **STOP** and execute the command instead.

**Every validation step, build command, and test run MUST be a real tool call, not a description.**

---

## Common Cross-References

**These specification documents are frequently referenced:**

| Reference | Full Path | Purpose |
|-----------|-----------|---------|
| Validation Sequence | `specification/llm-work-templates/validation-sequence.md` | Authoritative 8-step validation workflow |
| Tool Documentation | `specification/tools/README.md` | Complete reference for all validation and query tools |
| OTEL SDK Differences | `specification/llm-work-templates/research-otel-sdk-guide.md` | Language-specific SDK implementation guidance |
| Development Loop | `specification/09-development-loop.md` | Iterative development workflow |
| API Contract | `specification/01-api-contract.md` | 8 API functions to implement |
| Design Principles | `specification/00-design-principles.md` | Core philosophy |

**Usage in skills:**
- Use consistent formatting: `specification/[file].md` → "[Section]" (if applicable)
- Always provide context: Why is this reference relevant?
- Link at point of use: Reference docs when the user needs them

---

## Version History

**v1.0.0** (2025-10-27)
- Initial creation as part of Phase 2 (Content Deduplication)
- Extracted: Directory Restrictions, Execute Commands warning, Common Cross-References
- Eliminates ~95 lines of duplication across 4 skills

---

**Document Status:** ✅ v1.0.0 Active
**Part of:** sovdev-logger Claude Code skills v1.1.0
**Maintained by:** Skills maintenance process
