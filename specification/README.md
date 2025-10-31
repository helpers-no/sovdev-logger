# Sovdev Logger Specification

## Purpose

This specification enables **implementation of sovdev-logger in any programming language** while ensuring **identical output** across all implementations.

**Target Audience:**
- LLM assistants implementing sovdev-logger in new languages
- Human developers creating or maintaining language implementations

**Goal:** Any developer (human or LLM) should be able to read this specification, the TypeScript reference implementation, and create a correct implementation in their target language that produces identical output.

---

## Using Claude Code Skills (Recommended for LLM-Assisted Development)

If you're using Claude Code, you can leverage automatic skills that guide you through the implementation process systematically.

### Available Skills

**1. implement-language** - Systematic 4-phase implementation
- **Invoke**: "implement sovdev-logger in {language}"
- Automatically initializes workspace with ROADMAP.md (13 tasks, 4 phases)
- Prevents common mistakes (toolchain, SDK comparison, Grafana validation)
- Enforces completion criteria before claiming "complete"
- Uses hierarchical task management (v2.0) with enforcement

**2. validate-implementation** - Complete validation suite
- **Invoke**: "validate the implementation"
- Runs file logs → OTLP → Grafana → labels sequence
- Ensures ALL 3 Grafana panels show data (often skipped!)
- Compares metric labels with TypeScript

**3. development-loop** - Iterative 4-step workflow
- **Invoke**: "test changes" or "run the development loop"
- Guides: Build → Run → Validate logs FIRST → Validate OTLP SECOND
- Optimized for fast feedback (file validation is instant)

**See**: `.claude/skills/README.md` for complete skills documentation

### When to Use Skills

- ✅ **Implementing new language**: Use `implement-language` skill
- ✅ **Testing changes**: Use `development-loop` skill
- ✅ **Validating implementation**: Use `validate-implementation` skill
- ✅ **First time implementing**: Skills prevent skipping critical steps

**Benefits**: Skills codify the systematic approach from this specification, making it harder to skip steps or claim completion prematurely.

---

## Quick Start: Implementing a New Language

### For Claude Code Users

Ask Claude Code: `"Implement sovdev-logger in {language}"`

The implement-language skill will guide you through the systematic process.

### Manual Approach

**Complete implementation workflow**: See `specification/llm-work-templates/README.md`

**Quick version:**
```bash
# 1. Initialize workspace
./specification/llm-work-templates/enforcement/init-language-workspace.sh {language}

# 2. Read instructions
cat {language}/llm-work/CLAUDE.md
cat {language}/llm-work/ROADMAP.md

# 3. Follow ROADMAP.md systematically (13 tasks, 4 phases)
```

---

## Specification Documents

### Core Documents (Read in Order)

| Document | Purpose |
|----------|---------|
| **[00-design-principles.md](./00-design-principles.md)** | Core philosophy and design goals |
| **[llm-work-templates/research-otel-sdk-guide.md](./llm-work-templates/research-otel-sdk-guide.md)** ⚠️ **CRITICAL** | OpenTelemetry SDK differences between languages |
| **[llm-work-templates/](./llm-work-templates/)** ⚠️ **CRITICAL** | Task management templates (ROADMAP, task files, enforcement) |
| **[01-api-contract.md](./01-api-contract.md)** | Public API that all languages MUST implement |
| **[09-development-loop.md](./09-development-loop.md)** | Iterative development workflow |

### Supporting Documents

| Document | Purpose |
|----------|---------|
| **[02-field-definitions.md](./02-field-definitions.md)** | Required fields in all log outputs |
| **[03-implementation-patterns.md](./03-implementation-patterns.md)** | Required patterns (snake_case, directory structure) |
| **[04-error-handling.md](./04-error-handling.md)** | Exception handling, credential removal, stack trace limits |
| **[05-environment-configuration.md](./05-environment-configuration.md)** | Environment variables, DevContainer setup, language toolchain |
| **[06-test-scenarios.md](./06-test-scenarios.md)** | Test scenarios and verification procedures |
| **[07-anti-patterns.md](./07-anti-patterns.md)** | Common mistakes to avoid |
| **[08-testprogram-company-lookup.md](./08-testprogram-company-lookup.md)** | E2E test specification (MUST implement) |
| **[10-code-quality.md](./10-code-quality.md)** | Code linting standards and quality rules (MANDATORY) |

---

## Development Environment

**⚠️ CRITICAL:** All code execution MUST use DevContainer via `in-devcontainer.sh`.

**Architecture Overview:**
- **Host Machine:** Where you edit files (LLM tools or VSCode)
- **DevContainer:** Where code executes (language runtimes, tests, OTLP export)
- **Kubernetes Cluster:** Monitoring stack (Loki, Prometheus, Tempo, Grafana via Traefik)

**For architecture diagram and complete details**, see:
- `05-environment-configuration.md` → **Architecture Diagram** section (visual overview)
- `05-environment-configuration.md` → Component 1 & 2 (detailed configuration)
- `tools/README.md` - Validation tool usage and examples

**Key principle:** File operations on host, code execution in DevContainer.

---

## Implementation Workflow

**For detailed workflow**, see `09-development-loop.md` and `llm-work-templates/README.md`.

### Quick Reference

**1. Pre-Implementation Setup**
```bash
# Create workspace
mkdir -p {language}/llm-work {language}/test/e2e/company-lookup

# Initialize workspace with templates
./specification/llm-work-templates/enforcement/init-language-workspace.sh {language}

# Copy .env template
cp typescript/test/e2e/company-lookup/.env {language}/test/e2e/company-lookup/
```

**Read before coding:**
- `llm-work-templates/research-otel-sdk-guide.md` - Understand OTEL SDK differences
- `05-environment-configuration.md` - Verify language toolchain installed
- TypeScript reference: `typescript/src/logger.ts`
- Target language OTEL SDK documentation

**2. Implementation**
- Follow `01-api-contract.md` for 8 API functions
- Document SDK differences in `{language}/llm-work/otel-sdk-comparison.md`
- Update ROADMAP.md checkboxes as you progress

**3. Testing**
- Implement E2E test per `08-testprogram-company-lookup.md`
- Validate: `./specification/tools/run-full-validation.sh {language}`

---

## Validation & Success Criteria

### Main Validation Command
```bash
./specification/tools/run-full-validation.sh {language}
```

### Success Criteria

An implementation is **complete and correct** when:

1. ✅ All validation tools pass
2. ✅ **CRITICAL:** Grafana dashboard shows data in ALL 3 panels (TypeScript + new language)
3. ✅ Metric labels match TypeScript exactly (peer_service, log_type, log_level with underscores)
4. ✅ Duration values in milliseconds (histogram unit specified)
5. ✅ Output structure identical to TypeScript reference
6. ✅ All tasks in ROADMAP.md marked complete (13/13, 100%)

**For detailed validation procedures**, see:
- `09-development-loop.md` - Validation workflow
- `llm-work-templates/research-otel-sdk-guide.md` - Cross-language Grafana validation
- `llm-work-templates/task-templates/task-12-validation.md` - Backend validation procedures

---

## Key Resources

### 1. Claude Code Skills (For LLM-Assisted Development)
- **Location:** `.claude/skills/`
- **Documentation:** `.claude/skills/README.md`
- **Main skills:** `implement-language`, `validate-implementation`, `development-loop`
- **Purpose:** Automatic guidance through implementation process

### 2. Reference Implementation
- **Location:** `typescript/` directory
- **Key files:** `typescript/src/logger.ts`, `typescript/test/e2e/company-lookup/company-lookup.ts`
- **Purpose:** Shows HOW to meet specification requirements

### 3. Validation Tools
- **Location:** `specification/tools/`
- **Documentation:** `specification/tools/README.md`
- **Main tool:** `run-full-validation.sh {language}`

### 4. JSON Schemas
- **Location:** `specification/schemas/`
- **Documentation:** `specification/schemas/README.md`
- **Purpose:** Defines exact log format structure

---

## Key Principles

1. **Language-Agnostic Consistency** - All implementations MUST produce identical output
2. **Specification is Source of Truth** - TypeScript shows HOW, specification defines WHAT
3. **OTEL SDK Differences** - Each language SDK behaves differently; study both before coding
4. **Grafana Validation is Critical** - File logs passing ≠ implementation complete
5. **Systematic Progress Tracking** - ROADMAP.md with enforcement prevents premature "complete" claims
6. **DevContainer for All Execution** - Ensures consistent environment across all developers

---

## Common Pitfalls

**For complete list**, see `llm-work-templates/research-otel-sdk-guide.md` Common Pitfalls section.

**Top 3 issues from Go implementation:**
1. ❌ Not verifying language toolchain installed first
2. ❌ Using semantic convention defaults (dots) instead of underscores (peer_service, log_type, log_level)
3. ❌ Claiming "complete" without Grafana dashboard validation (all 3 panels must show data)

**Prevention:** Read `llm-work-templates/research-otel-sdk-guide.md` and follow ROADMAP.md systematically (task-03 guides SDK research).

---

## Getting Help

- **Specification issues:** Check `specification/` documents (00-09, 12)
- **Tool usage:** See `specification/tools/README.md`
- **DevContainer problems:** See `05-environment-configuration.md`
- **OTEL SDK issues:** See `llm-work-templates/research-otel-sdk-guide.md` Language-Specific Known Issues

---

**Specification Status:** ✅ v2.0.0 COMPLETE
**Last Updated:** 2025-10-31
**Reference Implementation:** TypeScript (`typescript/`)
**Development Environment:** DevContainer Toolbox (required)
**New in v2.0.0:** Hierarchical task management system (`llm-work-templates/`) with enforcement. Uses 13-task ROADMAP.md + detailed task files for systematic implementation. Progress enforcement blocks validation if checklist not followed.
