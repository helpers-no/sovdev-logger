# Code Quality Standards - Linting Rules

**Version:** 1.0
**Last Updated:** 2025-10-30
**Status:** MANDATORY for all language implementations

---

## Purpose

Define **universal code quality standards** that prevent technical debt accumulation across all sovdev-logger language implementations. These standards are specifically designed for **systematic LLM-driven development**.

---

## Philosophy: Prevent LLMs from Going Off the Rails

### The Core Problem: Dead Code Accumulation

LLMs naturally accumulate dead code through common patterns:

1. **"I might need this"** - Imports libraries "just in case"
2. **"TODO that never happens"** - Declares variables for future features that never materialize
3. **"Copy-paste replication"** - Copies patterns from examples, including unused code

**Without strict linting, dead code multiplies exponentially across implementations.**

### Real Example from TypeScript Implementation

When we added linting to TypeScript, we found **8 issues immediately**:

#### Dead Code (4 issues)
```typescript
// ❌ Before linting:
import { context } from '@opentelemetry/api';  // Imported "just in case"
import { SOVDEV_LOGLEVELS } from './logLevels';  // Never used
let globalSessionId: string | null = null;  // Declared for "future feature"

// ✅ After linting:
// Unused imports removed
// TODO added: // globalSessionId - implement session tracking in future
```

#### Type Safety (2 issues)
```typescript
// ❌ Before linting:
log(info: any, callback: Function) {  // What does it return? What args?

// ✅ After linting:
log(info: any, callback: () => void): void {  // Clear contract
```

#### Best Practices (2 issues)
- Using `@ts-ignore` instead of `@ts-expect-error`
- Inconsistent code formatting

**Impact:** All 8 issues = Technical debt that would have propagated to Python, Go, C#, PHP!

---

## Universal Linting Principles

These principles apply to **all language implementations**, adapted to each language's ecosystem:

### 🔴 Principle 1: STRICT Dead Code Prevention (ERRORS - Block Build)

**Philosophy:** Dead code = confusion and technical debt. Block it immediately.

**Rules:**
- ❌ **ERROR:** Unused imports
- ❌ **ERROR:** Unused variables
- ❌ **ERROR:** Unused function parameters (except prefixed with `_`)
- ❌ **ERROR:** Unreachable code

**Why This is Critical for LLMs:**
```
Without strict rules:
TypeScript: import { UNUSED } from './lib';  // ❌ Ships
↓ LLM copies pattern
Python: from lib import UNUSED  # ❌ Dead code replicates
↓ LLM copies pattern
Go: import "lib/UNUSED"  // ❌ Dead code multiplies

With strict rules:
TypeScript: import { UNUSED } from './lib';  // ❌ Error: unused
↓ Fix immediately
TypeScript: // removed  // ✅ Clean
↓ LLM sees clean pattern
Python: # only needed imports  // ✅ Clean from start
```

**Language-Specific Examples:**

| Language | Tool | Rule Configuration |
|----------|------|-------------------|
| TypeScript | ESLint | `@typescript-eslint/no-unused-vars: "error"` |
| Python | Flake8 | `F401` (unused import), `F841` (unused variable) |
| Go | golangci-lint | `unused`, `deadcode` |
| C# | Roslyn | `CS0219` (unused variable), `CS8019` (unnecessary using) |
| PHP | PHPStan | `level: 6` (unused variables) |

---

### 🔴 Principle 2: STRICT Return Type Enforcement (ERRORS - Block Build)

**Philosophy:** Function contracts must be explicit. No implicit types.

**Rules:**
- ❌ **ERROR:** Missing return types on functions
- ❌ **ERROR:** Implicit return types
- ✅ **ALLOW:** Explicit `any` for flexible APIs (public functions only)

**Why This Matters:**
```typescript
// ❌ Before: Unclear contract
function process(data) {
  return data.filter(x => x.valid);
}
// What does it return? Array? Undefined?

// ✅ After: Clear contract
function process(data: any[]): any[] {
  return data.filter(x => x.valid);
}
// Returns array, TypeScript enforces it
```

**Language-Specific Examples:**

| Language | Tool | Rule Configuration |
|----------|------|-------------------|
| TypeScript | ESLint | `@typescript-eslint/explicit-function-return-type: "error"` |
| Python | mypy | `--disallow-untyped-defs` |
| Go | Built-in | Return types required by language |
| C# | Roslyn | `CS1737` (return type required) |
| PHP | PHPStan | `level: 5` (return type checking) |

---

### 🔴 Principle 3: STRICT Code Complexity Limits (ERRORS - Block Build)

**Philosophy:** Keep functions manageable. Complex functions = hard to test, maintain, understand.

**Rules:**
- ❌ **ERROR:** Cyclomatic complexity > 20
- ⚠️ **WARNING:** Functions > 200 lines

**Why This Prevents Issues:**
- LLMs can generate large, complex functions
- Complexity limits force decomposition
- Smaller functions = easier to test and understand

**Language-Specific Examples:**

| Language | Tool | Rule Configuration |
|----------|------|-------------------|
| TypeScript | ESLint | `complexity: ["error", 20]` |
| Python | flake8 | `mccabe` plugin, `max-complexity: 20` |
| Go | golangci-lint | `gocyclo`, `cyclop` |
| C# | Roslyn | Code metrics analyzer |
| PHP | PHPStan | Complexity rules |

---

### ⚠️ Principle 4: WARN on Type Safety Erosion (WARNINGS - Don't Block)

**Philosophy:** Track type safety issues without blocking flexible APIs.

**Rules:**
- ⚠️ **WARNING:** Use of `any` type (TypeScript)
- ⚠️ **WARNING:** Untyped function arguments (Python)
- ⚠️ **WARNING:** Interface{} usage (Go)

**Why Warnings, Not Errors:**
- Logging libraries need flexible APIs (accept any JSON)
- Warning = visibility without rigidity
- Track type safety erosion over time

**Language-Specific Examples:**

| Language | Warning Rule | Why Allow It |
|----------|--------------|--------------|
| TypeScript | `@typescript-eslint/no-explicit-any: "warn"` | Public API needs flexibility |
| Python | mypy `--warn-incomplete-stub` | Track, don't block |
| Go | `interface{}` usage | Flexible JSON handling |
| C# | `dynamic` usage | API flexibility |
| PHP | `mixed` type | Flexible input |

---

### ✅ Principle 5: ALLOW Pragmatic Exceptions (Context-Specific)

**Philosophy:** Some rules need exceptions based on project context.

**sovdev-logger Specific Exceptions:**

1. **Console logging allowed**
   - Reason: Logging library intentionally uses console output
   - TypeScript: `no-console: "off"`
   - Python: Allow `print()` statements

2. **Public API type flexibility**
   - Reason: Users pass various JSON structures
   - TypeScript: `explicit-module-boundary-types: "off"`
   - Python: Allow `Any` in public functions

3. **Test files may have looser rules**
   - Reason: Tests need flexibility
   - All languages: Separate lint config for `/test/` directories

---

## Pattern Replication Prevention

### The Multiplication Problem

**Without Linting:**
```
TypeScript implementation:
  import { UNUSED } from './lib';  // ❌ Dead code

LLM studies TypeScript → copies pattern to Python:
  from lib import UNUSED  # ❌ Dead code replicates

LLM studies both → copies pattern to Go:
  import "lib/UNUSED"  // ❌ Dead code multiplies (3x now!)

LLM studies all → copies pattern to C#:
  using Lib.UNUSED;  // ❌ Dead code multiplies (4x now!)

Result: One mistake → Four mistakes
```

**With Strict Linting:**
```
TypeScript implementation:
  import { UNUSED } from './lib';  // ❌ Error caught immediately
  Fix: Remove it

TypeScript (clean):
  // Only needed imports  // ✅ Clean pattern

LLM studies TypeScript → sees clean pattern:
  # Only needed imports  // ✅ Clean from start

LLM studies both → sees clean pattern:
  // Only needed imports  // ✅ Clean from start

Result: Zero mistakes propagate
```

**Key Insight:** TypeScript is the reference implementation. Linting ensures it's clean, so all other languages copy clean patterns.

---

## Integration with Development Loop

### The 5-Step Development Loop

Linting is **Step 2** (mandatory, blocking):

```
1. Edit   - Make code changes
2. Lint   - ⚠️ MANDATORY BLOCKING STEP ⚠️
3. Build  - Compile/build library
4. Test   - Run E2E tests
5. Validate - Check OTLP backends
```

### Why Lint is Step 2 (Before Build)

| Benefit | Description |
|---------|-------------|
| **Fast feedback** | Catches issues in seconds, not minutes |
| **Early prevention** | Before they compound in build/test cycles |
| **Clear errors** | Actionable messages for humans and LLMs |
| **Systematic** | Forces quality at every iteration |
| **Cost savings** | Cheaper to fix linting errors than test failures |

### Exit Code Requirements

**All linting implementations MUST follow these exit codes:**

- **Exit 0** - All checks passed (warnings allowed, don't block)
- **Exit non-zero** - Errors found (MUST fix before proceeding)

**Example:**
```bash
$ make lint
Running linting...
✖ 1 problem (1 error, 0 warnings)
$ echo $?
1  # ❌ Non-zero = Blocks development loop

$ make lint
✖ 23 problems (0 errors, 23 warnings)
$ echo $?
0  # ✅ Zero = Continues (warnings don't block)
```

---

## Language-Specific Implementation Guide

### Overview: Consistent Interface Pattern

**Key Decision: Use Makefile for Consistent Interface Across All Languages**

Each language has its own native way to run linting:
- TypeScript: `npm run lint`
- Python: `flake8 src/` or `black --check src/`
- Go: `golangci-lint run`
- C#: `dotnet format --verify-no-changes`

**Problem:** Different commands per language = harder for LLMs and developers to remember.

**Solution:** Makefile provides a **consistent wrapper interface**:
```bash
# Same command works for ALL languages:
make lint       # Check linting
make lint-fix   # Auto-fix issues
```

**Benefits:**
1. ✅ **LLM-friendly** - Learn one pattern: "all languages use `make lint`"
2. ✅ **Human-friendly** - Don't remember language-specific commands
3. ✅ **Consistent documentation** - Development loop shows `make lint` everywhere
4. ✅ **Optional** - Can still use native tools directly (`npm run lint`, etc.)

**The Makefile wraps language-native tools:**
- TypeScript Makefile calls `npm run lint` internally
- Python Makefile calls `flake8`, `black`, `mypy` internally
- Go Makefile calls `golangci-lint run` internally

---

### For Each Language Implementation, Create:

#### 1. Configuration Files

Store linting configuration in the language directory root:

| Language | Configuration Files | Location |
|----------|-------------------|----------|
| TypeScript | `.eslintrc.json`, `.prettierrc` | `typescript/` |
| Python | `.flake8`, `pyproject.toml`, `mypy.ini` | `python/` |
| Go | `.golangci.yml` | `go/` |
| C# | `.editorconfig`, `ruleset.xml` | `csharp/` |
| PHP | `phpstan.neon`, `phpcs.xml` | `php/` |

#### 2. Makefile Target

Every language MUST have a `lint` target:

```makefile
.PHONY: lint
lint:
	@echo "Running {language} linting..."
	# Run language-specific linters
	# Exit 0 on success, non-zero on error

.PHONY: lint-fix
lint-fix:
	@echo "Running {language} linting with auto-fix..."
	# Run linters with auto-fix enabled
```

#### 3. Package Dependencies

Document linting tools in standard dependency files:

| Language | Dependency File | Example |
|----------|----------------|---------|
| TypeScript | `package.json` devDependencies | `"eslint": "^8.57.0"` |
| Python | `requirements-dev.txt` | `black>=25.0.0` |
| Go | `go.mod` (tools) | `github.com/golangci/golangci-lint` |
| C# | `.csproj` | `<PackageReference>` analyzers |
| PHP | `composer.json` require-dev | `"phpstan/phpstan"` |

---

## Rule Configuration Templates

### TypeScript (Reference Implementation)

```json
{
  "rules": {
    // Dead Code Prevention (STRICT)
    "@typescript-eslint/no-unused-vars": "error",

    // Type Safety (STRICT)
    "@typescript-eslint/explicit-function-return-type": "error",

    // Type Safety (PRAGMATIC)
    "@typescript-eslint/no-explicit-any": "warn",
    "@typescript-eslint/explicit-module-boundary-types": "off",

    // Code Quality (STRICT)
    "complexity": ["error", 20],
    "max-lines-per-function": ["warn", 200],

    // Project-Specific Exceptions
    "no-console": "off"
  }
}
```

### Python (Equivalent Configuration)

```ini
# .flake8
[flake8]
max-complexity = 20
max-line-length = 100
ignore = E203,W503
per-file-ignores = __init__.py:F401

# pyproject.toml
[tool.mypy]
warn_unused_configs = true
disallow_untyped_defs = false  # Off for public API flexibility
warn_return_any = true

[tool.black]
line-length = 100
```

### Go (Equivalent Configuration)

```yaml
# .golangci.yml
linters:
  enable:
    - unused      # Dead code prevention
    - deadcode    # Unreachable code
    - gocyclo     # Complexity limit
    - ineffassign # Unused assignments

linters-settings:
  gocyclo:
    min-complexity: 20
```

### C# (Equivalent Configuration)

```xml
<!-- .editorconfig -->
[*.cs]
# Dead code
dotnet_diagnostic.CS0219.severity = error  # Unused variable
dotnet_diagnostic.CS8019.severity = error  # Unused using

# Complexity
dotnet_code_quality.CA1502.severity = warning  # Avoid excessive complexity
```

### PHP (Equivalent Configuration)

```neon
# phpstan.neon
parameters:
    level: 6  # Strict type checking
    paths:
        - src
    ignoreErrors:
        - '#Function .* has no return type#'  # Allow for public API
```

---

## Measuring Success

### Immediate Success (Implementation Phase)

- ✅ Linting passes with 0 errors on reference implementation (TypeScript)
- ✅ Configuration files created and documented
- ✅ Makefile `lint` target works
- ✅ Exit codes follow standard (0 = pass, non-zero = fail)

### Long-Term Success (Future Implementations)

When LLM implements new language (Go, C#, PHP):

- ✅ LLM reads this specification document
- ✅ LLM studies TypeScript configuration (reference)
- ✅ LLM creates equivalent configuration for new language
- ✅ LLM runs `make lint` before build/test
- ✅ No dead code propagates from TypeScript to new language

---

## Validation Checklist

For each language implementation, verify:

### Configuration
- [ ] Linting tool configured (eslint, flake8, golangci-lint, etc.)
- [ ] Configuration file created in language root directory
- [ ] Rules follow the 5 universal principles above
- [ ] Exit codes work correctly (0 = pass, non-zero = fail)

### Integration
- [ ] `Makefile` has `lint` and `lint-fix` targets
- [ ] `make lint` works from language directory
- [ ] Can run via `in-devcontainer.sh` wrapper
- [ ] Documented in language's README

### Quality
- [ ] Linting passes with 0 errors on clean code
- [ ] Intentional errors are caught and blocked
- [ ] Warnings are visible but don't block
- [ ] Auto-fix works where applicable (`lint-fix` target)

---

## Benefits Summary

### For Human Developers
1. ✅ Consistent code style across team
2. ✅ Catches bugs early (unused code, type errors)
3. ✅ Clear error messages
4. ✅ Auto-fix available for many issues

### For LLM Developers
1. ✅ **Prevents "going off the rails"** - Dead code caught immediately
2. ✅ **Clear boundaries** - Rules define what's acceptable
3. ✅ **Actionable feedback** - Error messages are explicit
4. ✅ **Pattern enforcement** - Clean code from reference implementation propagates

### For Multi-Language Projects
1. ✅ **Consistent quality** - Same principles across all languages
2. ✅ **No pattern replication** - Mistakes don't multiply
3. ✅ **Self-documenting** - Configuration files show standards
4. ✅ **Reusable** - Copy specification folder to other projects

---

## Key Insight

> **Strict linting = LLM guardrails**
>
> The stricter the dead code prevention, the better LLMs stay on track across all implementations.

**Proof:** TypeScript linting found 8 issues that would have propagated to 4+ languages = 32+ total issues prevented.

---

## References

- **Reference Implementation:** `typescript/.eslintrc.json` - Study this first
- **TypeScript Documentation:** `typescript/package.json` - See lint scripts
- **Development Loop:** `specification/09-development-loop.md` - Step 2: Lint
- **Implementation Workflow:** `specification/llm-work-templates/ROADMAP-template.md` - Task 5 (linting setup) & Task 8 (linting validation)

---

**Status:** ✅ MANDATORY for all implementations
**Applies to:** TypeScript ✅, Python (pending), Go (pending), C# (pending), PHP (pending)
**Last Validated:** 2025-10-30 (TypeScript)
