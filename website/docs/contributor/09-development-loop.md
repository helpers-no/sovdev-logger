---
title: Development loop
sidebar_label: Development loop
sidebar_position: 5
description: "Iterative development workflow."
---

# Development Loop

---

## Purpose

This document describes the **iterative development workflow** for implementing and testing sovdev-logger in any programming language.

**Key Principle:** Validate log files FIRST (fast, local), then validate OTLP backends SECOND (slow, requires infrastructure).

---

## Validation-First Development

**Critical Principle:** Validation is not a phase at the end. Validation is continuous throughout development.

### Two-Level Validation Strategy

#### Level 1: System-Wide Health Check (TypeScript Baseline)

**ALWAYS verify TypeScript works before starting new language implementation.** TypeScript is the reference implementation that proves the observability stack is healthy — if TypeScript's validation fails, it's an infrastructure problem (fix UIS/Loki/Prometheus/Tempo), not a new-language bug.

```bash
cd /workspace/typescript/test/e2e/company-lookup && ./run-test.sh
cd /workspace/tools/validation/uis && ./query-loki.sh sovdev-test-company-lookup-typescript
cd /workspace/tools/validation/uis && ./query-prometheus.sh sovdev-test-company-lookup-typescript
cd /workspace/tools/validation/uis && ./query-tempo.sh sovdev-test-company-lookup-typescript
```

#### Level 2: Continuous Language-Specific Validation

Validate your implementation at these checkpoints during development:

**1. File Format Validation** (fastest, local, no infrastructure)
- **After**: Implementing file logger and running a simple test
- **Action**: Run test → `./validate-log-format.sh {language}/test/e2e/company-lookup/logs/dev.log`
- Why first: Catches format issues without needing OTLP infrastructure at all

**2. OTLP Connectivity Test** (fast, infrastructure)
- **After**: Implementing OTLP exporters
- **Action**: Create simple test with SDK → Send test data → Verify appears in backends
- Method: Use OTEL SDK's built-in functions (not bash scripts) — language-idiomatic testing, C# tests in C#, Go tests in Go, etc.
- Why second: Isolates connectivity issues (headers, TLS, auth) from logic issues

**3. Backend Data Validation** (requires full E2E test)
- **After**: E2E test runs successfully
- **Action**: Run E2E test → `query-loki.sh`/`query-tempo.sh`/`query-prometheus.sh`, each with `--compare-with` against the log file
- Why `--compare-with`, not just presence: a query that only checks "is this service name present" can be a false positive — it doesn't distinguish this run's data from a stale one. `--compare-with` cross-checks every entry by `trace_id`/`event_id`, so a real mismatch fails loudly.
- **Complete tool documentation**: [`tools/README.md`](https://github.com/helpers-no/sovdev-logger/blob/main/tools/README.md), [`tools/validation/uis/README.md`](https://github.com/helpers-no/sovdev-logger/blob/main/tools/validation/uis/README.md)

**4. Cross-Language Conformance** (the actual completion gate)
- **After**: Backend data validation passes
- **Action**: `cd /workspace/tools/validation/uis && ./compare-with-master.sh {language}`
- Why last: confirms the candidate's output is field-by-field identical to TypeScript's for the same fixed scenario — this, not a visual Grafana check, is the authoritative "does it match the reference implementation" answer. See [PLAN-001](../ai-developer/plans/completed/PLAN-001-master-comparison-mode.md).

### Key Principle

**TypeScript validates the system. Your language validates its integration with the system.**

If TypeScript works but your language doesn't:
- Check OTLP endpoint configuration and headers (see [`01-api-contract.md`](./01-api-contract.md) for the real `OTEL_EXPORTER_OTLP_HEADERS` format)
- Check metric labels (use underscores, not dots)
- Check log format (must match the schema exactly)

### Rule for Task Completion

**You cannot claim a task is "complete" without running applicable validation tools.**

- Task "Implement OTLP exporters": write code → create a connectivity test → verify it reaches Loki/Prometheus/Tempo → mark complete
- Task "Implement file logging": write code → run `validate-log-format.sh` → verify it passes → mark complete

---

## Developer Workflows

**For environment architecture diagram**, see `05-environment-configuration.md` → **Architecture Diagram** section.

**⚠️ CRITICAL:** All developers (human and LLM) work **inside the DevContainer** at `/workspace/`. Execute commands directly.

**Example commands:**
```bash
# Run tests
cd typescript/test/e2e/company-lookup && ./run-test.sh
cd python/test/e2e/company-lookup && ./run-test.sh

# Build libraries
cd typescript && ./build-sovdevlogger.sh
cd python && ./build-sovdevlogger.sh

# Validate log files
cd /workspace/tools/validation/uis && ./validate-log-format.sh typescript/test/e2e/company-lookup/logs/dev.log

# Query backends
cd /workspace/tools/validation/uis && ./query-loki.sh sovdev-test-company-lookup-typescript
cd /workspace/tools/validation/uis && ./query-prometheus.sh sovdev-test-company-lookup-typescript
```

### Common Commands Reference

| Task | Command (from `/workspace/`) |
|------|------------------------------|
| **Lint TypeScript code** | `cd typescript && make lint` |
| **Lint TypeScript (auto-fix)** | `cd typescript && make lint-fix` |
| **Build TypeScript library** | `cd typescript && ./build-sovdevlogger.sh` |
| **Build Python library** | `cd python && ./build-sovdevlogger.sh` |
| **Run TypeScript test** | `cd typescript/test/e2e/company-lookup && ./run-test.sh` |
| **Run Python test** | `cd python/test/e2e/company-lookup && ./run-test.sh` |
| **Validate log format** | `cd /workspace/tools/validation/uis && ./validate-log-format.sh {language}/test/e2e/company-lookup/logs/dev.log` |
| **Query Loki (exact match)** | `cd /workspace/tools/validation/uis && ./query-loki.sh sovdev-test-company-lookup-{language} --compare-with {language}/test/e2e/company-lookup/logs/dev.log` |
| **Cross-language conformance** | `cd /workspace/tools/validation/uis && ./compare-with-master.sh {language}` |

---

## The Development Loop

The typical development cycle follows this **6-step pattern**:

1. **Edit** - Make code changes
2. **Lint** - Check code quality (MANDATORY - must pass before build)
3. **Build** - Compile/build the library
4. **Run/Test** - Execute code (start with simple tests, work up to E2E)
5. **Validate Logs** - Check file format (FAST - instant feedback)
6. **Validate OTLP** - Check backends (SLOWER - requires infrastructure)

**Key principle:** Validate incrementally as you build. Don't wait until the end to run the full E2E test.

**Note on file editing:** Files are synchronized between host and container (bind mount). The distinction here is only about **where commands execute**. For architecture details, see `05-environment-configuration.md`.

---

## Test-Driven Development: The Iterative Feedback Loop

**⚠️ CRITICAL FOR LLMs:** This is NOT a one-time sequence. This is **iterative test-driven development**.

```
┌─────────────────────────────────────────┐
│  1. Edit code                            │
│  2. Lint (must pass)                     │
│  3. Build                                │
│  4. Run test                             │
│  5. Validate (file → backends → conformance) │
│     │                                    │
│     ├─ ✅ PASS → Next task               │
│     │                                    │
│     └─ ❌ FAIL → Read error              │
│              ↓                           │
│         Understand what's broken         │
│              ↓                           │
│         Go back to Step 1 (Edit)         │
│              ↓                           │
│         Fix the issue                    │
│              ↓                           │
│         Run through loop again           │
│              ↓                           │
│         Repeat until validation passes   │
└─────────────────────────────────────────┘
```

### Example Iteration: Implementing OTLP Log Exporter

**Iteration 1:**
1. Edit: Implement OTLP log exporter
2. Lint/Build/Run: ✅ all pass
3. Validate: File logs ❌ **FAIL** — "Missing required field: trace_id"
   **STOP HERE — fix before proceeding**

**Iteration 2:**
1. Edit: Add trace_id to log entries
2. Lint/Build/Run: ✅ all pass
3. Validate: File logs ✅ PASS (17 entries, all fields correct); Loki ❌ **FAIL** — "No logs found in Loki"
   **STOP HERE — fix before proceeding**

**Iteration 3:**
1. Edit: Fix OTLP header configuration (see `01-api-contract.md` for the real spec format)
2. Lint/Build/Run: ✅ all pass
3. Validate: File logs ✅, Loki ✅ (17 entries match), Tempo ✅ (4 spans match), Prometheus ✅ (5 metric groups match), `compare-with-master.sh` ✅ **MATCH**

**Task complete!** ✅

### Key Principles

1. **Validation tools tell you what's broken** — read error messages carefully
2. **Each failure teaches you something** — understand the error before fixing
3. **Fix one thing at a time** — don't change multiple things between iterations
4. **Follow the sequence** — file format first (instant), then backends (slower), then conformance
5. **Iterate until it works** — this is normal, expected, and how development works

---

### For LLMs: Tracking Progress

There's no per-language ROADMAP file to maintain anymore — `tools/validation/uis/compare-with-master.sh {language}` is the completion gate (see [PLAN-003](../ai-developer/plans/completed/PLAN-003-spec-scaffolding-cleanup.md)). Use your own task-tracking tooling if useful; there's no repo-enforced checklist to update.

---

### Step 1: Edit Code

Edit source files using your preferred tools. Files are synchronized between host and container — edit anywhere.

---

### Step 2: Lint Code (MANDATORY)

**⛔ BLOCKING STEP:** Linting MUST pass (exit code 0) before proceeding to build/test. Catches dead code, enforces type safety, and — critically for LLM-generated code — stops bad patterns from propagating across language implementations.

**For complete linting philosophy and rules**, see: [`10-code-quality.md`](./10-code-quality.md)

**TypeScript (reference implementation):**
```bash
cd /workspace/typescript && make lint       # check
cd /workspace/typescript && make lint-fix   # auto-fix
```
Exit 0 (warnings OK) → proceed to build. Non-zero → stop, fix errors.

**Python and future languages:** follow the same pattern — study `typescript/.eslintrc.json` and `typescript/Makefile`, adapt to language-appropriate tools (flake8/black/mypy for Python), expose the same `make lint`/`make lint-fix` interface. See `10-code-quality.md` for the universal rules.

---

### Step 3: Build Library (When Needed)

After editing library source code, build before running tests:

```bash
# TypeScript
cd /workspace/typescript && ./build-sovdevlogger.sh

# Python
cd /workspace/python && ./build-sovdevlogger.sh
```

Each language's `build-sovdevlogger.sh` knows its own build process (compilation, dependency install, editable-mode setup).

---

### Step 4: Run/Test (Incremental Approach)

**⚠️ Don't jump straight to the E2E test.** Build and validate incrementally: connectivity test after OTLP exporters, unit tests after API functions, only then the full E2E test.

```bash
cd /workspace/{language}/test/e2e/company-lookup && ./run-test.sh
```

Generates log files in `{language}/test/e2e/company-lookup/logs/` and sends OTLP data to Loki/Prometheus/Tempo (takes a few seconds to propagate).

---

### Step 5 & 6: Validate

```bash
# File format — instant, do this first
cd /workspace/tools/validation/uis && ./validate-log-format.sh {language}/test/e2e/company-lookup/logs/dev.log

# Backends — exact match against the log file, not just presence
LOG_FILE="/workspace/{language}/test/e2e/company-lookup/logs/dev.log"
cd /workspace/tools/validation/uis
./query-loki.sh sovdev-test-company-lookup-{language} --compare-with "$LOG_FILE"
./query-tempo.sh sovdev-test-company-lookup-{language} --compare-with "$LOG_FILE"
./query-prometheus.sh sovdev-test-company-lookup-{language} --compare-with "$LOG_FILE"

# Cross-language conformance — the completion gate
./compare-with-master.sh {language}
```

---

## Related Documentation

- **[05-environment-configuration.md](./05-environment-configuration.md)** - DevContainer setup and configuration
- **[06-test-scenarios.md](./06-test-scenarios.md)** - Test scenarios and verification procedures
- **[08-testprogram-company-lookup.md](./08-testprogram-company-lookup.md)** - Company-lookup E2E test specification
- **[tools/README.md](https://github.com/helpers-no/sovdev-logger/blob/main/tools/README.md)** - Validation tooling overview
- **[Testing against UIS](./testing/uis.md)** - the verified, end-to-end walkthrough of everything above

---

**Last Updated:** 2026-07-11
