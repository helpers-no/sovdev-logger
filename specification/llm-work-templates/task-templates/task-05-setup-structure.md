# Task 5: Setup Project Structure

**Parent task**: ROADMAP.md - Phase 1, Task 5
**Prerequisites**: Phase 0 complete (all 4 tasks)

---

## Purpose

Set up the complete project structure for [LANGUAGE] implementation including:
- Directory structure
- Language toolchain verification
- Dependencies installation
- Build system (Makefile)
- Linting configuration

**Output**: Complete project skeleton ready for coding

---

## Subtasks

### 5.1 Verify Language Toolchain (CRITICAL FIRST STEP)

**Before creating any files, verify the language is available:**

- [ ] Check language is installed:
  ```bash
  [language-command] --version
  ```

  Examples:
  - Python: `python3 --version`
  - Go: `go version`
  - C#: `dotnet --version`
  - Rust: `rustc --version`
  - Java: `java --version`

**Expected result:** Version number displayed (not "command not found")

**If language not installed:**
- [ ] Check if installer script exists: `.devcontainer/additions/install-dev-[language].sh`
- [ ] If exists, run installer:
  ```bash
  ./.devcontainer/additions/install-dev-[language].sh
  ```
- [ ] If no installer, escalate to user (language not available)

**Verification:**
- [ ] Language version: _______________________________
- [ ] Installation path: _______________________________
- [ ] Ready to proceed: ✅ YES / ❌ NO

**⛔ DO NOT PROCEED until language is verified installed**

---

### 5.2 Create Directory Structure

Create the standard sovdev-logger directory layout:

```bash
mkdir -p [LANGUAGE]/src
mkdir -p [LANGUAGE]/test/e2e/company-lookup
mkdir -p [LANGUAGE]/test/unit
mkdir -p [LANGUAGE]/llm-work
mkdir -p [LANGUAGE]/docs
```

**Checklist:**
- [ ] Created `[LANGUAGE]/src/` - Source code
- [ ] Created `[LANGUAGE]/test/e2e/company-lookup/` - E2E test
- [ ] Created `[LANGUAGE]/test/unit/` - Unit tests (optional)
- [ ] Created `[LANGUAGE]/llm-work/` - Implementation tracking
- [ ] Created `[LANGUAGE]/docs/` - Documentation (optional)

**Verify:**
```bash
ls -la [LANGUAGE]/
# Should show: src/, test/, llm-work/, docs/
```

---

### 5.3 Initialize Language Package/Project

Create language-specific project files:

**For Python:**
```bash
cd [LANGUAGE]
# Create pyproject.toml, setup.py, or requirements.txt
```

**For Go:**
```bash
cd [LANGUAGE]
go mod init sovdev-logger-go
```

**For C#:**
```bash
cd [LANGUAGE]
dotnet new classlib -n SovdevLogger
```

**For Rust:**
```bash
cd [LANGUAGE]
cargo init --lib
```

**For Java:**
```bash
cd [LANGUAGE]
# Create pom.xml or build.gradle
```

**Checklist:**
- [ ] Project/package initialized
- [ ] Project file created (e.g., go.mod, package.json, Cargo.toml, etc.)
- [ ] Project name follows convention: `sovdev-logger-[language]`

---

### 5.4 Install OTEL Dependencies

From Task 4 (otel-sdk-comparison.md), install all required packages:

**Example command structure:**
```bash
\1
```

**Install:**
- [ ] OTLP logs exporter package
- [ ] OTLP metrics exporter package
- [ ] OTLP traces exporter package
- [ ] Any additional dependencies from Task 4

**Verification:**
- [ ] All packages installed successfully
- [ ] No errors in installation output
- [ ] Dependencies recorded in project file

---

### 5.5 Install Logging Library

Choose and install an appropriate logging library for file output:

**Recommended libraries by language:**
- Python: `logging` (built-in) + `python-json-logger`
- Go: `go.uber.org/zap` or `github.com/sirupsen/logrus`
- C#: `Serilog` or `NLog`
- Rust: `tracing` or `log` + `env_logger`
- Java: `logback` or `log4j2`

**Checklist:**
- [ ] Logging library installed
- [ ] Library supports JSON formatting
- [ ] Library supports log rotation
- [ ] Library is production-ready (not experimental)

---

### 5.6 Create Makefile (MANDATORY)

Create `[LANGUAGE]/Makefile` with required targets:

**See:** `specification/10-code-quality.md` for linting requirements

**Required targets:**
- `lint` - Run linter/formatter in check mode
- `lint-fix` - Run linter/formatter in fix mode
- `build` - Compile/prepare code
- `test` - Run tests

**Template:**
```makefile
# [LANGUAGE] Makefile for sovdev-logger

.PHONY: lint lint-fix build test

lint:
	@echo "Running linter..."
	# [language-specific lint command in check mode]

lint-fix:
	@echo "Running linter with auto-fix..."
	# [language-specific lint command in fix mode]

build:
	@echo "Building project..."
	# [language-specific build command]

test:
	@echo "Running tests..."
	# [language-specific test command]

.DEFAULT_GOAL := build
```

**Language-specific examples:**

**Python:**
```makefile
lint:
	flake8 src/ test/
	black --check src/ test/
	mypy src/

lint-fix:
	black src/ test/
	isort src/ test/

build:
	python -m py_compile src/**/*.py

test:
	pytest test/
```

**Go:**
```makefile
lint:
	golangci-lint run

lint-fix:
	gofmt -w .
	goimports -w .

build:
	go build ./...

test:
	go test ./...
```

**Checklist:**
- [ ] Makefile created at `[LANGUAGE]/Makefile`
- [ ] All 4 required targets defined (lint, lint-fix, build, test)
- [ ] Commands are correct for [LANGUAGE]

---

### 5.7 Setup Linting Configuration

**See:** `specification/10-code-quality.md` for complete linting standards

Create linter configuration file:

**For Python:** `.flake8`, `pyproject.toml`, `.pylintrc`
**For Go:** `.golangci.yml`
**For C#:** `.editorconfig`, analyzer config
**For Rust:** `rustfmt.toml`, `clippy.toml`

**Required rules (from 10-code-quality.md):**
- [ ] Enforce consistent code style
- [ ] Detect unused code (dead code, unused variables/imports)
- [ ] Check complexity limits
- [ ] Enforce type safety (if applicable)
- [ ] Check for common errors

**Study TypeScript example:**
```bash
cat typescript/.eslintrc.json
cat typescript/package.json
# See "lint" and "lint-fix" scripts
```

**Checklist:**
- [ ] Linter configuration file created
- [ ] Rules configured per specification/10-code-quality.md
- [ ] Linter installed (dependency added)
- [ ] `make lint` command works (even if no code yet)

---

### 5.8 Test Makefile Targets

Verify all Makefile targets work:

```bash
\1
# Should run successfully (no code yet, but linter runs)

\1
# Should run successfully

\1
# Should run successfully (might be no-op if no code)

\1
# Should run successfully (no tests yet, might be no-op)
```

**Checklist:**
- [ ] `make lint` works without errors
- [ ] `make lint-fix` works without errors
- [ ] `make build` works without errors
- [ ] `make test` works without errors

---

### 5.9 Create .gitignore

Create `[LANGUAGE]/.gitignore` to exclude generated files:

**Common patterns:**
```gitignore
# Language-specific (add based on language)
# Python: __pycache__/, *.pyc, .pytest_cache/, venv/
# Go: bin/, vendor/
# C#: bin/, obj/, *.dll, *.exe
# Rust: target/, Cargo.lock (for libraries)

# sovdev-logger specific
logs/
*.log
.env
otel-sdk-comparison.md
implementation-notes.md

# IDE
.idea/
.vscode/
*.swp
.DS_Store
```

**Checklist:**
- [ ] .gitignore created
- [ ] Language-specific patterns added
- [ ] sovdev-logger patterns added
- [ ] IDE patterns added

---

## Success Criteria

**This task is complete when:**

- [ ] All 9 subtasks checked off
- [ ] ✅ Language toolchain verified (5.1)
- [ ] ✅ Directory structure created (5.2)
- [ ] ✅ Language project initialized (5.3)
- [ ] ✅ OTEL dependencies installed (5.4)
- [ ] ✅ Logging library installed (5.5)
- [ ] ✅ Makefile created with 4 required targets (5.6)
- [ ] ✅ Linting configured per specification/10-code-quality.md (5.7)
- [ ] ✅ All Makefile targets tested and working (5.8)
- [ ] ✅ .gitignore created (5.9)

**Do NOT mark complete if:**
- ❌ Language toolchain not verified
- ❌ Makefile missing required targets (lint, lint-fix, build, test)
- ❌ Linting not configured
- ❌ `make lint` doesn't work

---

## Common Issues

### Issue 1: Language Not Available
**Problem:** `[language] --version` returns "command not found"
**Solution:**
- Check `.devcontainer/additions/` for installer script
- If no installer, escalate to user to add language to environment

### Issue 2: Package Installation Fails
**Problem:** Cannot install OTEL packages
**Solution:**
- Check package names are correct (from Task 4)
- Check network access
- Check package registry is accessible

### Issue 3: Makefile Doesn't Work
**Problem:** `make lint` returns errors
**Solution:**
- Verify linter is installed (check dependencies)
- Verify commands are correct for [LANGUAGE]
- Test commands manually first, then add to Makefile

---

**Parent task**: Return to ROADMAP.md when complete
**Next task**: Task 6 - Implement OTLP exporters
