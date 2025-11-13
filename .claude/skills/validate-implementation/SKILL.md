---
description: "Run complete validation suite for sovdev-logger implementation. Validates file logs, OTLP backends, and Grafana dashboard. Use when validating any language implementation."
version: "3.0.0"
last_updated: "2025-10-31"
references:
  - specification/llm-work-templates/validation-sequence.md
  - specification/tools/README.md
  - specification/llm-work-templates/research-otel-sdk-guide.md
  - .claude/skills/_SHARED.md
---

# Validate Implementation Skill

When the user asks to validate a sovdev-logger implementation, guide them through the complete 8-step validation sequence.

## ⚠️ IMPORTANT: Directory Restrictions

**See:** `.claude/skills/_SHARED.md` → "Directory Restrictions"

**Summary:** Only use `specification/`, `typescript/`, and `{language}/` directories. Do NOT access `terchris/` or `topsecret/`.

## 📚 Authoritative Documentation

**Primary:** `specification/llm-work-templates/validation-sequence.md`
- Complete 8-step validation sequence
- All commands with examples
- Step-by-step blocking points
- Success criteria
- Common issues and fixes

**Tools reference:** `specification/tools/README.md`
- Complete tool documentation
- Common debugging scenarios
- Query tools for debugging

**OTLP issues:** `specification/llm-work-templates/research-otel-sdk-guide.md`
- SDK-specific issues
- Common pitfalls (metric labels, HTTP headers)

## The 8-Step Validation Sequence

**Read `specification/llm-work-templates/validation-sequence.md` for complete details and commands.**

**The sequence:**
1. Validate Log Files (INSTANT) ⚡
2. Verify Logs in Loki (OTLP → Loki) 🔄
3. Verify Metrics in Prometheus (OTLP → Prometheus) 🔄
4. Verify Traces in Tempo (OTLP → Tempo) 🔄
5. Verify Grafana-Loki Connection (Grafana → Loki) 🔄
6. Verify Grafana-Prometheus Connection (Grafana → Prometheus) 🔄
7. Verify Grafana-Tempo Connection (Grafana → Tempo) 🔄
8. Verify Grafana Dashboard (Visual Verification) 👁️ MANDATORY

**⛔ DO NOT skip steps or proceed until each step passes**

## Success Criteria

Implementation is validated when:
- ✅ ALL 8 steps complete (each shows ✅ PASS)
- ✅ Grafana dashboard shows data in ALL 3 panels
- ✅ All checkboxes in validation-sequence.md are checked

**Do NOT claim complete until Step 8 (Grafana) is verified.**

## Debugging Failed Validation

**For debugging workflows:**
**Read:** `specification/tools/README.md` → "Common Debugging Scenarios"

**For OTLP issues:**
**Read:** `specification/llm-work-templates/research-otel-sdk-guide.md`

**For query tools:**
**Read:** `specification/tools/README.md` → "Query Scripts" section

## ⚠️ Execute Commands, Don't Describe Them

**See:** `.claude/skills/_SHARED.md` → "Execute Commands, Don't Describe Them"

**Critical Rule:** When you find commands in the documentation, EXECUTE them immediately using the Bash tool. Do NOT describe what you "should" or "will" do.

---

**Remember:** Skills are routers. Read `specification/llm-work-templates/validation-sequence.md` for the complete validation process with all commands.
