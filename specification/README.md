# Sovdev Logger Specification

## Purpose

This specification enables **implementation of sovdev-logger in any programming language** while ensuring **identical output** across all implementations.

**Target Audience:**
- LLM assistants implementing sovdev-logger in new languages
- Human developers creating or maintaining language implementations

**Goal:** Any developer (human or LLM) should be able to read this specification, the TypeScript reference implementation, and create a correct implementation in their target language that produces identical output.

---

## Quick Start: Implementing a New Language

Read [`implementation-guide.md`](./implementation-guide.md) — it's the short version of everything below: read the contract, study TypeScript, check the anti-patterns table, implement, run `compare-with-master.sh {language}` until it passes, then promote it in the root `README.md`.

There is no automatically-invoked workflow or per-language ROADMAP file anymore (see [PLAN-003](../website/docs/ai-developer/plans/backlog/PLAN-003-spec-scaffolding-cleanup.md) for why) — `compare-with-master.sh` is the actual completion gate, not a checklist someone has to trust was honestly followed.

---

## Specification Documents

### Core Documents (Read in Order)

| Document | Purpose |
|----------|---------|
| **[implementation-guide.md](./implementation-guide.md)** | Start here — the end-to-end process |
| **[00-design-principles.md](./00-design-principles.md)** | Core philosophy and design goals |
| **[research-otel-sdk-guide.md](./research-otel-sdk-guide.md)** | OpenTelemetry SDK differences between languages |
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
| **[07-anti-patterns.md](./07-anti-patterns.md)** | Common mistakes to avoid (table) |
| **[08-testprogram-company-lookup.md](./08-testprogram-company-lookup.md)** | E2E test specification (MUST implement) |
| **[10-code-quality.md](./10-code-quality.md)** | Code linting standards and quality rules (MANDATORY) |

---

## Development Environment

**⚠️ CRITICAL for Claude Code (LLM):** You run **inside** the DevContainer at `/workspace/`. Execute all commands directly.

**Architecture Overview:**
- **Host Machine:** Where files physically exist (project repository)
- **DevContainer:** Where Claude Code and code both execute (language runtimes, tests, OTLP export)
- **Kubernetes Cluster:** Monitoring stack (Loki, Prometheus, Tempo, Grafana via Traefik)
- **Bind Mount:** Host project directory → `/workspace/` in container (same filesystem, instant sync)

**For architecture diagram and complete details**, see:
- `05-environment-configuration.md` → **Architecture Diagram** section (visual overview)
- `05-environment-configuration.md` → Component 1 & 2 (detailed configuration)
- `tools/README.md` - Validation tool usage and examples

**Key principle:** You (Claude Code) work at `/workspace/` inside the container. Files are bind-mounted from host.

---

## Validation & Success Criteria

### Main Validation Commands
```bash
./specification/tools/run-full-validation.sh {language}
./specification/tools/compare-with-master.sh {language}
```

### Success Criteria

An implementation is **complete and correct** when:

1. ✅ All validation tools pass
2. ✅ **CRITICAL:** Grafana dashboard shows data in ALL 3 panels (TypeScript + new language)
3. ✅ Metric labels match TypeScript exactly (peer_service, log_type, log_level with underscores)
4. ✅ Duration values in milliseconds (histogram unit specified)
5. ✅ **`compare-with-master.sh {language}` passes** — output is field-for-field identical to TypeScript's for the same E2E run, not just visually similar. This is the automated, re-runnable check for "identical output across languages"; Grafana dashboard checks (criterion 2) confirm the observability pipeline works, they don't confirm the output itself matches.

**For detailed validation procedures**, see `09-development-loop.md` and `tools/README.md` (the 9-step validation sequence, including master-comparison as Step 9).

---

## Key Resources

### 1. Reference Implementation
- **Location:** `typescript/` directory
- **Key files:** `typescript/src/logger.ts`, `typescript/test/e2e/company-lookup/company-lookup.ts`
- **Purpose:** Shows HOW to meet specification requirements

### 2. Validation Tools
- **Location:** `specification/tools/`
- **Documentation:** `specification/tools/README.md`
- **Main tools:** `run-full-validation.sh {language}`, `compare-with-master.sh {language}`

### 3. JSON Schemas
- **Location:** `specification/schemas/`
- **Documentation:** `specification/schemas/README.md`
- **Purpose:** Defines exact log format structure

---

## Key Principles

1. **Language-Agnostic Consistency** - All implementations MUST produce identical output
2. **Specification is Source of Truth** - TypeScript shows HOW, specification defines WHAT
3. **OTEL SDK Differences** - Each language SDK behaves differently; study both before coding
4. **Grafana Validation is Critical** - File logs passing ≠ implementation complete
5. **Automated Completion Gate** - `compare-with-master.sh` passing is what "done" means, not a self-reported checklist
6. **DevContainer for All Execution** - Ensures consistent environment across all developers

---

## Common Pitfalls

**For complete list**, see `research-otel-sdk-guide.md` Common Pitfalls section, and `07-anti-patterns.md` for code-level gotchas.

**Top 3 issues from past implementation attempts:**
1. ❌ Not verifying language toolchain installed first
2. ❌ Using semantic convention defaults (dots) instead of underscores (peer_service, log_type, log_level) — note: this doesn't apply to OTel metric names themselves, which the Prometheus exporter sanitizes automatically; see `07-anti-patterns.md` row 12
3. ❌ Claiming "complete" without running `compare-with-master.sh` and the Grafana dashboard check (all 3 panels must show data)

---

## Getting Help

- **Specification issues:** Check `specification/` documents (00-10)
- **Tool usage:** See `specification/tools/README.md`
- **DevContainer problems:** See `05-environment-configuration.md`
- **OTEL SDK issues:** See `research-otel-sdk-guide.md` Language-Specific Known Issues

---

**Specification Status:** ✅ v2.1.0 COMPLETE
**Last Updated:** 2026-07-08
**Reference Implementation:** TypeScript (`typescript/`)
**Development Environment:** DevContainer Toolbox (required)
**New in v2.1.0:** Cut the `llm-work-templates/` ROADMAP/checklist system and `.claude/skills/` — both were scaffolding to compensate for not having automated cross-implementation verification. `specification/tools/compare-with-master.sh` (added in v2.0.0) is now the actual completion gate; see `implementation-guide.md` and [PLAN-003](../website/docs/ai-developer/plans/backlog/PLAN-003-spec-scaffolding-cleanup.md).
