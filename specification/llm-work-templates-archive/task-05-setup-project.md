# Task 5: Setup Project Structure

**Phase**: 1 (Implementation)
**Expected Time**: 45 minutes
**Dependencies**: Phase 0 complete (4/4 tasks)

---

## Overview

Setup the complete project structure, build system, and configuration files for the {LANGUAGE} implementation. This task creates the foundation for all subsequent implementation work.

---

## Success Criteria

- [ ] Directory structure created
- [ ] Dependencies installed
- [ ] Makefile with 4 required targets working
- [ ] Linting configured and passing
- [ ] ⛔ **MANDATORY**: .env file created and validated
- [ ] Build succeeds without errors

---

## Subtasks

### 5.1: Create Directory Structure

Create the following directories:

```
{LANGUAGE}/
├── src/{LibraryName}/           # Main library
├── test/e2e/company-lookup/     # E2E test
│   └── .env                     # ⚠️ REQUIRED CONFIGURATION FILE
├── llm-work/                    # Implementation tracking
├── docs/                        # Documentation
└── logs/                        # Log file output (gitignored)
```

**Validation**: All directories exist

### 5.2: Install Dependencies

Install required packages:
- OpenTelemetry SDK (logs, metrics, traces)
- OTLP Exporter
- File logging library
- .env file loader (if needed for language)

**Validation**: Dependencies listed in package file

### 5.3: Configure Build System

Create `Makefile` with **4 REQUIRED targets**:

```makefile
lint:
	# Verify code quality without changes

lint-fix:
	# Auto-fix code quality issues

build:
	# Compile/build project

test:
	# Run tests
```

**Reference**: See `specification/10-code-quality.md` for linting standards

**Validation**: All 4 targets execute without errors

### 5.4: Setup Linting

Configure linting for {LANGUAGE}:
- Create `.editorconfig` (if applicable)
- Configure formatter/linter
- Run `make lint` - must pass

**Validation**: `make lint` exits with code 0

---

## 5.5: Create .env File ⛔ MANDATORY CHECKPOINT

**⚠️ CRITICAL: This subtask is MANDATORY and BLOCKING**

### Why This Is Critical

The .env file configures OpenTelemetry endpoints, headers, and service identification. **Without it, OTLP exporters will fail silently or use incorrect configuration**, leading to:
- Zero logs reaching Loki
- Zero metrics reaching Prometheus
- Hours of debugging configuration issues
- Implementation failure

**Recent example**: C# implementation spent 4+ hours debugging OTLP export issues, only to discover the .env file was never created.

### Location

Create file at: `{LANGUAGE}/test/e2e/company-lookup/.env`

### Content Template

Copy from TypeScript reference implementation and adapt:

```bash
# Service name (required - OpenTelemetry standard environment variable)
# Maps to service.name attribute in all telemetry (logs, metrics, traces)
OTEL_SERVICE_NAME=sovdev-test-company-lookup-{LANGUAGE}

# Console logging (optional - smart default: auto-enabled if no OTLP, otherwise disabled)
# LOG_TO_CONSOLE=true

# File logging (optional - default: true)
LOG_TO_FILE=true
# LOG_FILE_PATH=./logs/dev.log
# ERROR_LOG_PATH=./logs/error.log

# OpenTelemetry OTLP Endpoints
#
# Configure where to send telemetry data (logs, metrics, traces).
#
# REQUIRED: Set these three variables for OTLP export
OTEL_EXPORTER_OTLP_LOGS_ENDPOINT=http://host.docker.internal/v1/logs
OTEL_EXPORTER_OTLP_METRICS_ENDPOINT=http://host.docker.internal/v1/metrics
OTEL_EXPORTER_OTLP_TRACES_ENDPOINT=http://host.docker.internal/v1/traces

# OTLP Headers (Traefik routing - REQUIRED)
# Format varies by language:
#   - TypeScript/Python: '{"Host":"otel.localhost"}'
#   - C#/Java: Host=otel.localhost
#   - Go: Requires custom HTTP client (see task-06-implement-otlp.md)
OTEL_EXPORTER_OTLP_HEADERS=Host=otel.localhost

# Protocol configuration (optional - defaults to grpc)
OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf

# Deployment Environment
# Standard values: development, staging, production
{ENV_VAR_NAME}=development
```

**Language-Specific Adaptations**:
- **TypeScript/Node.js**: Use `NODE_ENV=development`
- **Python**: Use `PYTHON_ENV=development` or no variable (check logging library)
- **C#/.NET**: Use `DOTNET_ENVIRONMENT=development` and `ASPNETCORE_ENVIRONMENT=development`
- **Go**: No standard variable, read `DEPLOYMENT_ENV`
- **Java**: Use `SPRING_PROFILES_ACTIVE=development` or similar
- **PHP**: Use `APP_ENV=development`
- **Rust**: Read `RUST_ENV` or `APP_ENV`

### Reference Implementation

**Always check TypeScript first**: `typescript/test/e2e/company-lookup/.env`

The TypeScript .env file is the **reference implementation**. When in doubt:
1. Copy the TypeScript .env file
2. Replace `typescript` with `{LANGUAGE}` in service name
3. Adapt environment variable names for your language
4. Keep ALL comments and explanations

### Validation Checklist

Before marking this subtask complete:

- [ ] File exists at `{LANGUAGE}/test/e2e/company-lookup/.env`
- [ ] Service name includes language: `sovdev-test-company-lookup-{LANGUAGE}`
- [ ] All 3 OTLP endpoints configured (logs, metrics, traces)
- [ ] OTLP headers configured (format correct for language)
- [ ] Protocol set to `http/protobuf`
- [ ] Environment variable set (NODE_ENV, DOTNET_ENVIRONMENT, etc.)
- [ ] File committed to git (not in .gitignore)
- [ ] Comments preserved from TypeScript template

### Automated Validation

Run the enforcement script:

```bash
cd /workspace/specification/llm-work-templates/enforcement
./check-progress.sh {LANGUAGE}
```

This will verify:
- [ ] .env file exists
- [ ] .env contains OTEL_SERVICE_NAME
- [ ] .env contains all 3 OTLP endpoints
- [ ] .env contains OTLP_HEADERS

**If validation fails**: Task 5 is NOT complete. Fix issues before proceeding.

---

## 5.6: Test Build System

Run complete build cycle:

```bash
cd {LANGUAGE}
make lint        # Should pass
make lint-fix    # Should auto-fix any issues
make build       # Should succeed
```

**Validation**: All commands exit with code 0

---

## Completion Checklist

Before marking Task 5 complete, verify:

- [ ] All directories exist
- [ ] Dependencies installed
- [ ] Makefile has 4 working targets (lint, lint-fix, build, test)
- [ ] Linting configured and passing
- [ ] ⛔ **.env file created and validated** (blocking checkpoint)
- [ ] Build succeeds
- [ ] `./check-progress.sh {LANGUAGE}` passes

---

## ⛔ Blocking Rule

**Task 6 (Implement OTLP exporters) CANNOT start until Task 5 is complete, including .env file creation.**

Why? Because:
1. OTLP exporters need endpoints from .env
2. Without .env, exporters will fail silently
3. You'll waste hours debugging "why isn't data appearing in Loki?"
4. The answer will be: "You never created the .env file"

**Lesson learned from C# implementation**: Create .env file FIRST, debug OTLP SECOND.

---

## Common Mistakes

### ❌ Mistake 1: Skipping .env file creation
**Impact**: 4+ hours wasted debugging OTLP export failures
**Fix**: Create .env file as part of Task 5, not Task 6

### ❌ Mistake 2: Wrong .env file location
**Impact**: Environment variables not loaded, exporters use wrong configuration
**Fix**: Place in `test/e2e/company-lookup/.env` (where test runs from)

### ❌ Mistake 3: Wrong OTLP_HEADERS format
**Impact**: Traefik routing fails, 404 errors from OTLP collector
**Fix**: Check language-specific format (JSON string vs key=value)

### ❌ Mistake 4: Forgetting to load .env in test program
**Impact**: Environment variables not read, defaults used instead
**Fix**: Add .env loader at start of test program (DotNetEnv, python-dotenv, etc.)

---

## Next Steps

After Task 5 complete:
1. Update ROADMAP.md: Mark Task 5 as `[x] ✅ YYYY-MM-DD`
2. Verify .env file one more time
3. Start Task 6: Implement OTLP exporters (will read from .env)

---

**Template Version**: 2.0.0 (with mandatory .env checkpoint)
**Last Updated**: 2025-11-12
**Lesson Learned From**: C# implementation failure analysis
