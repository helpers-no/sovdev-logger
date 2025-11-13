# LLM Work Templates - Task Management System

**Version:** 2.0.0
**Created:** 2025-10-31
**Purpose:** Hierarchical task management system for implementing sovdev-logger in new languages

---

## Overview

This directory contains templates and tools for systematic language implementation with enforced progress tracking.

**Goal:** Port the TypeScript reference implementation to any programming language while ensuring identical output.

**Approach:** Two-tier task hierarchy with enforcement, based on community best practices (ROADMAP.md pattern).

---

## What's in This Directory

```
specification/llm-work-templates/
├── README.md                           # This file - system overview
├── ROADMAP-template.md                 # Master checklist template (13 tasks, 4 phases)
├── CLAUDE-template.md                  # Workflow instructions template
│
├── task-templates/                     # Detailed task breakdowns
│   ├── task-03-research-otel-sdk.md   # 7 subtasks for OTEL research
│   ├── task-06-implement-otlp.md      # 10 subtasks for OTLP exporters
│   ├── task-07-implement-api.md       # 10 subtasks for API functions
│   ├── task-09-e2e-test.md            # 15 subtasks for E2E test
│   └── task-12-validation.md          # 10 subtasks for validation
│
├── enforcement/                        # Enforcement scripts
│   ├── init-language-workspace.sh     # Initialize {language}/llm-work/
│   └── check-progress.sh              # Validate ROADMAP.md progress
│
└── test/                               # Test scripts (future)
    └── (test scripts TBD)
```

---

## How It Works

### 1. Template → Instance Flow

**Templates** (in this directory):
- Generic, language-agnostic
- Contain placeholders: `[LANGUAGE]`, `[DATE]`
- Shared across all language implementations
- Improve over time, all languages benefit

**Instances** (in `{language}/llm-work/`):
- Language-specific copies
- Placeholders replaced: `[LANGUAGE]` → `go`, `[DATE]` → `2025-10-31`
- Updated by Claude Code during implementation
- Single source of truth for progress

### 2. Hierarchical Structure

**Two-tier hierarchy** (proven pattern from research):

**Tier 1: ROADMAP.md** (Master Checklist)
- 13 high-level tasks
- 4 phases with locking
- Progress tracking: `[ ]` → `[-]` → `[x]`
- Recently Completed section for archiving

**Tier 2: task-XX-name.md** (Detailed Tasks)
- 5-15 subtasks each
- Step-by-step instructions
- Success criteria per subtask
- Time estimates

**Why two tiers?**
- Not flat (overwhelming: 243 items)
- Not deep (complex: >3 levels hard to navigate)
- Just right (manageable + detailed when needed)

### 3. Enforcement

**Progress check runs before validation:**

```bash
cd /workspace/specification/tools && ./run-full-validation.sh go
  ↓
Calls: check-progress.sh go
  ↓
Checks: go/llm-work/ROADMAP.md exists and is being updated
  ↓
If fail: Block validation, show error
If pass: Continue with validation
```

**What enforcement checks:**
- ROADMAP.md exists
- At least 1 task marked complete (prevents ignoring checklist)
- Phases completed in order (no skipping)
- "Last updated" date is recent

**Why enforcement?**
- Without enforcement, checklists are optional
- Optional checklists get ignored
- Ignored checklists lead to bugs
- Enforcement ensures process is followed

### 4. Placeholder Replacement

`init-language-workspace.sh` uses `sed` to replace placeholders:

```bash
# Before (template):
# [LANGUAGE] Implementation Progress
**Last updated**: [DATE]

# After (instance for Go):
# Go Implementation Progress
**Last updated**: 2025-10-31
```

**Placeholders:**
- `[LANGUAGE]` → Language name (go, python, csharp, etc.)
- `[DATE]` → Current date in YYYY-MM-DD format

---

## Usage

### For Claude Code (LLM)

When user asks to implement a new language:

1. **Initialize workspace:**
   ```bash
   ./specification/llm-work-templates/enforcement/init-language-workspace.sh {language}
   ```

2. **Read instructions:**
   ```bash
   cat {language}/llm-work/CLAUDE.md
   cat {language}/llm-work/ROADMAP.md
   ```

3. **Follow ROADMAP.md systematically:**
   - Start with Phase 0, Task 1
   - Mark tasks in progress: `[ ]` → `[-] 🏗️ YYYY-MM-DD`
   - Complete tasks: `[-]` → `[x] ✅ YYYY-MM-DD`
   - Read task-XX.md for detailed instructions when linked
   - Update "Last updated" date after each session

4. **Validation runs with enforcement:**
   - check-progress.sh blocks if ROADMAP.md not updated
   - Must show progress before validation continues

**See:** `.claude/skills/implement-language/SKILL.md` for complete workflow

### For Humans (Project Maintainers)

**Adding a new language:**

```bash
# 1. Initialize workspace
./specification/llm-work-templates/enforcement/init-language-workspace.sh rust

# 2. Check created files
ls rust/llm-work/
# → ROADMAP.md, CLAUDE.md, task-*.md, otel-sdk-comparison.md, implementation-notes.md

# 3. Review ROADMAP.md
cat rust/llm-work/ROADMAP.md
# → See 13 tasks across 4 phases

# 4. Implement following ROADMAP.md
# 5. Update checkboxes as you complete tasks
```

**Checking progress:**

```bash
# Run progress check manually
cd /workspace/specification/llm-work-templates/enforcement && ./check-progress.sh rust"

# Or let validation script run it automatically (calls check-progress.sh internally)
cd /workspace/specification/tools && ./run-full-validation.sh rust"
```

**Improving templates:**

1. Edit templates in `specification/llm-work-templates/`
2. New languages automatically get improved templates
3. Existing languages can re-initialize (with confirmation prompt)

---

## Design Principles

### 1. Community-Proven Patterns

Based on research of Claude Code community practices:

- **ROADMAP.md pattern** (Ben Newton): Single living document, checkbox states with timestamps
- **Task file directories**: Two-tier with master + detailed specs
- **Enforcement mechanisms**: Like CI/CD pipelines (phase gates, blocking)
- **Make-style dependencies**: Tasks have prerequisites, phases lock

**Sources:**
- `terchris/plans-current/research-claude-code-task-management.md`
- `terchris/plans-current/research-hierarchical-task-management.md`

### 2. TypeScript is the Reference

**All implementations must match TypeScript:**
- TypeScript defines correct behavior
- New language = port of TypeScript
- Validation = verify identical output to TypeScript
- When in doubt, check what TypeScript does

**Key validations:**
- Same log messages (17 entries)
- Same metrics (4: cache:lookup, cache:update, db:query, analytics:event)
- Same spans (2: cache_lookup, db_query)
- Same attribute names (underscores: peer_service, operation_name)

### 3. Hierarchical Decomposition

LLMs naturally think in hierarchical decomposition (2024 research):
- Complex task → Break into phases
- Phase → Break into tasks
- Task → Break into subtasks (when needed)

**Our structure matches LLM reasoning patterns:**
- Phase 0: Planning (preparation)
- Phase 1: Implementation (building)
- Phase 2: Testing (E2E)
- Phase 3: Validation (proof)

### 4. Single Source of Truth

**ROADMAP.md is authoritative:**
- Progress tracked here
- Validation checks this
- TodoWrite is helper only
- If conflict → ROADMAP.md wins

**Why?**
- File persists across sessions
- User can see progress
- Git tracks changes
- Validation can enforce it

---

## Template Descriptions

### ROADMAP-template.md

**Master checklist** with 13 tasks across 4 phases.

**Key features:**
- Phase locking (🔒 until prerequisites complete)
- Progress tracking (0/4, 2/4, 4/4)
- Checkbox states: `[ ]` → `[-] 🏗️ date` → `[x] ✅ date`
- Recently Completed section (archive without losing context)
- Time estimates per task
- Links to detailed task files

**Phases:**
- Phase 0: Planning (4 tasks) - Research, verify baseline
- Phase 1: Implementation (4 tasks) - Setup (with linting), OTLP exporters, file logging, API functions
- Phase 2: Testing (2 tasks) - E2E test program
- Phase 3: Validation (3 tasks) - File validation, backend validation, Grafana verification

**Total time estimate:** 15-20 hours for complete implementation

### CLAUDE-template.md

**Workflow instructions** for Claude Code.

**Key sections:**
- Primary Directive: ALWAYS read ROADMAP.md first
- Workflow Rules (4 phases of work: starting, during, completing, transitions)
- Checkpoint Questions (validate before claiming complete)
- TodoWrite Integration (secondary to ROADMAP.md)
- Validation Rules (continuous, phase-specific)
- Common Pitfalls (prevent common mistakes)
- Progress Tracking Example (concrete workflow)

**Purpose:** Guides Claude's behavior without user needing to repeat instructions each session.

### task-03-research-otel-sdk.md

**OTEL SDK research** (7 subtasks, ~2 hours).

Guides research of language-specific OTEL SDK:
- SDK maturity check
- OTLP exporter configuration
- **Critical:** HTTP header method (`Host: otel.localhost`)
- **Critical:** Metric attribute pattern (underscores not dots)
- TypeScript comparison
- Output: otel-sdk-comparison.md

### task-06-implement-otlp.md

**OTLP exporters** (10 subtasks, ~3 hours).

Implements logs, metrics, and traces exporters:
- Install OTLP packages
- Configure 3 exporters with `Host: otel.localhost` header
- Resource attributes
- Initialization function
- Test each exporter
- **Critical:** Verify HTTP header present

### task-07-implement-api.md

**8 API functions** (10 subtasks, ~3.5 hours).

Implements public API:
- initLogger()
- log() / logWithContext()
- recordPeerService()
- startSpan() / endSpan()
- PeerServices.for() / PeerServices.record()
- Export all functions
- **Critical:** Underscores in metric/span attributes

### task-09-e2e-test.md

**E2E test** (15 subtasks, ~2.5 hours).

Implements company-lookup test scenario:
- 17 log entries (exact messages)
- 4 peer service metrics
- 2 spans (cache, database)
- Uses all 8 API functions
- run-test.sh script

### task-12-validation.md

**Backend validation** (10 subtasks, ~30 minutes).

Validates telemetry reaches backends:
- Loki (logs)
- Prometheus (metrics)
- Tempo (traces)
- Grafana dashboard (all panels)
- Side-by-side comparison with TypeScript
- **Critical:** Test metric label filtering (underscores!)

---

## Enforcement Scripts

### init-language-workspace.sh

**Purpose:** Initialize `{language}/llm-work/` from templates.

**Usage:**
```bash
./specification/llm-work-templates/enforcement/init-language-workspace.sh {language}
```

**What it does:**
1. Validates language name (alphanumeric + dashes)
2. Creates `{language}/llm-work/` directory
3. Copies templates (ROADMAP, CLAUDE, task-*)
4. Replaces placeholders (`[LANGUAGE]` → language, `[DATE]` → today)
5. Creates placeholder files (otel-sdk-comparison.md, implementation-notes.md)
6. Makes scripts executable
7. Shows next steps

**Safety:**
- Checks if directory exists (prompts before overwriting)
- Validates paths
- Creates backup-friendly structure

**Example:**
```bash
$ ./specification/llm-work-templates/enforcement/init-language-workspace.sh go

Initializing workspace for language: go
Project root: /workspace/sovdev-logger
Templates: /workspace/sovdev-logger/specification/llm-work-templates
Target: /workspace/sovdev-logger/go/llm-work

Creating directory structure...
✓ Created ROADMAP.md
✓ Created CLAUDE.md
✓ Copied 5 task template(s)

Replacing placeholders...
✓ Updated placeholders in ROADMAP.md
✓ Updated placeholders in CLAUDE.md
✓ Updated placeholders in task-03-research-otel-sdk.md
...

========================================
Workspace initialization complete!
========================================

Next steps:
  1. Read go/llm-work/CLAUDE.md for instructions
  2. Read go/llm-work/ROADMAP.md for your task list
  3. Start with Phase 0, Task 1 in ROADMAP.md

Always start each session by reading ROADMAP.md!
```

### check-progress.sh

**Purpose:** Validate ROADMAP.md progress before allowing validation.

**Usage:**
```bash
./specification/llm-work-templates/enforcement/check-progress.sh {language} [--phase N]
```

**What it checks:**
1. ROADMAP.md exists
2. `.env` file exists and is properly configured (for Task 6+)
3. At least one task marked complete (not 0/13)
4. Phases completed in order (optional, warns if violated)
5. "Last updated" date exists and is reasonably recent

**Recent Enhancements (2025-11-12):**
- Added `.env` file validation (required after Task 6 - OTLP exporters)
- Checks for all required OTLP environment variables
- Validates service name includes language identifier
- Prevents "missing .env" issue that cost 4+ hours in C# implementation
- Fixed: Support for decimal progress values (e.g., "1.5/4")
- Fixed: Arithmetic error when counting completed tasks (double-zero output)

**Exit codes:**
- 0 - Progress check passed, may proceed
- 1 - Progress check failed, must update ROADMAP.md
- 2 - Invalid arguments or missing files

**Called by:**
- `specification/tools/run-full-validation.sh` (automatically before validation)
- Can be called manually for progress review

**Example output (pass):**
```
========================================
Progress Check: go
========================================

✓ Found ROADMAP.md: /workspace/go/llm-work/ROADMAP.md

Phase Progress:

  Phase 0: 4/4 (100%) ✅ Complete
  Phase 1: 2/4 (50%) 🔄 In Progress
  Phase 2: 0/2 (0%) 🔒 Locked
  Phase 3: 0/3 (0%) 🔒 Locked

Last Updated Check:

  ✓ **Last updated**: 2025-10-31

========================================
✓ Progress check passed
========================================

Summary:
  • Total completed tasks: 6
  • ROADMAP.md exists and is being updated

You may proceed with validation.
```

**Example output (fail):**
```
========================================
Progress Check: go
========================================

✓ Found ROADMAP.md: /workspace/go/llm-work/ROADMAP.md

Phase Progress:

  Phase 0: 0/4 (0%) 📋 Not Started
  Phase 1: 0/4 (0%) 🔒 Locked
  Phase 2: 0/2 (0%) 🔒 Locked
  Phase 3: 0/3 (0%) 🔒 Locked

❌ PROGRESS CHECK FAILED

No tasks have been marked complete in ROADMAP.md

You MUST update ROADMAP.md as you work.

To fix:
  1. Open: /workspace/go/llm-work/ROADMAP.md
  2. Mark completed tasks: [ ] → [x] ✅ 2025-10-31
  3. Update 'Last updated' date at top of file
  4. Run this check again
```

---

## Integration Points

### 1. With `.claude/skills/implement-language/SKILL.md`

Skill file:
- Calls `init-language-workspace.sh` to create workspace
- Points Claude to read CLAUDE.md and ROADMAP.md
- Explains the system (why it exists, how it differs from v1)
- Does NOT contain implementation details (those are in templates)

### 2. With `specification/tools/run-full-validation.sh`

Validation script:
- Calls `check-progress.sh` before running validation
- If progress check fails → Blocks validation, shows error
- If progress check passes → Continues with validation
- Now language-agnostic (works with any `{language}/` directory)

### 3. With TodoWrite Tool

TodoWrite is Claude Code's built-in task tracking:
- **Optional**: Claude MAY use TodoWrite for session tracking
- **Secondary**: ROADMAP.md is authoritative
- **Sync required**: Before ending session, update ROADMAP.md from TodoWrite
- **Conflict resolution**: If mismatch, ROADMAP.md wins

**See:** CLAUDE-template.md section "Integration with TodoWrite" for details

### 4. With Git

ROADMAP.md is git-friendly:
- Plain text markdown
- Checkbox changes show in diffs
- Can track progress over time
- Timestamps provide audit trail

**Collaboration:**
- Multiple people can work on same language (see progress in ROADMAP.md)
- Can review which tasks completed when
- Easy to see if implementation stalled

---

## Customization

### Adding New Task Templates

If a task becomes complex enough to need detailed breakdown:

1. Create `specification/llm-work-templates/task-templates/task-XX-name.md`
2. Use existing task files as template
3. Include:
   - Purpose and prerequisites
   - Numbered subtasks with checkboxes
   - Success criteria
   - Common pitfalls
   - Time estimates
4. Link from ROADMAP-template.md: `→ [Details](task-XX-name.md)`
5. Test with init-language-workspace.sh

### Modifying ROADMAP Structure

If task breakdown needs adjustment:

1. Edit `ROADMAP-template.md`
2. Adjust number of tasks (currently 13)
3. Update "Progress Summary" calculations
4. Test placeholder replacement
5. Document changes in this README

**Guidelines:**
- Keep 10-20 high-level tasks (not 243!)
- Maintain 4-phase structure (works well)
- Phase locking is valuable (keep it)
- Test with new language to verify

### Language-Specific Adaptations

Templates are generic, but some languages may need special handling:

**In task files, add language-specific notes when discovered:**
```markdown
### Special Cases

**For [Language X]:**
- Enum pattern: [discovered pattern]
- OTLP: [discovered configuration method]
- Attributes: [discovered attribute handling]
```

**Don't fork templates per language** - keep one generic template with conditional sections added as implementations are completed.

---

## Testing

### Manual Testing

**Test template instantiation:**

```bash
# 1. Clean test
rm -rf test-language/

# 2. Initialize
./specification/llm-work-templates/enforcement/init-language-workspace.sh test-language

# 3. Verify placeholders replaced
grep "test-language" test-language/llm-work/ROADMAP.md
grep "2025-10-31" test-language/llm-work/ROADMAP.md  # Or today's date

# 4. Verify files created
ls test-language/llm-work/
# Should see: ROADMAP.md, CLAUDE.md, task-*.md, otel-sdk-comparison.md, implementation-notes.md

# 5. Clean up
rm -rf test-language/
```

**Test progress enforcement:**

```bash
# 1. Initialize test language
./specification/llm-work-templates/enforcement/init-language-workspace.sh test-lang

# 2. Run progress check (should fail - 0 tasks complete)
./specification/llm-work-templates/enforcement/check-progress.sh test-lang
# Expected: Exit code 1, error message

# 3. Mark one task complete
# Edit test-lang/llm-work/ROADMAP.md: Change one [ ] to [x] ✅ 2025-10-31

# 4. Run progress check again (should pass)
./specification/llm-work-templates/enforcement/check-progress.sh test-lang
# Expected: Exit code 0, success message

# 5. Clean up
rm -rf test-lang/
```

**Test validation integration:**

```bash
# 1. Test with real language (TypeScript)
cd /workspace/specification/tools && ./run-full-validation.sh typescript

# Should run progress check, then proceed with validation
# Check for "Checking ROADMAP.md progress..." message
```

---

## Troubleshooting

### Issue: init-language-workspace.sh fails with "sed: invalid command"

**Cause:** macOS vs Linux sed syntax differences

**Fix:** Script already handles this (lines 76-82 in init script):
```bash
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    sed -i '' "s/\[LANGUAGE\]/$LANGUAGE/g" "$file"
else
    # Linux
    sed -i "s/\[LANGUAGE\]/$LANGUAGE/g" "$file"
fi
```

**If still failing:** Check bash version, ensure script has execute permissions

---

### Issue: check-progress.sh reports "ROADMAP.md not found"

**Symptoms:**
```
❌ ROADMAP.md not found
Expected location: /workspace/{language}/llm-work/ROADMAP.md

Did you run init-language-workspace.sh?
```

**Cause:** Workspace not initialized

**Fix:**
```bash
./specification/llm-work-templates/enforcement/init-language-workspace.sh {language}
```

---

### Issue: Validation blocked with "Progress check failed"

**Symptoms:**
```
❌ PROGRESS CHECK FAILED

No tasks have been marked complete in ROADMAP.md
```

**Cause:** ROADMAP.md exists but no tasks checked off (0/13 complete)

**Fix:**
1. Open `{language}/llm-work/ROADMAP.md`
2. Mark completed tasks: Change `[ ]` to `[x] ✅ 2025-10-31`
3. Update "Last updated" date at top of file
4. Re-run validation

---

### Issue: Placeholders not replaced in instantiated files

**Symptoms:** `{language}/llm-work/ROADMAP.md` still contains `[LANGUAGE]` and `[DATE]`

**Cause:** sed replacement failed or script interrupted

**Fix:**
```bash
# Manual replacement
cd {language}/llm-work
sed -i 's/\[LANGUAGE\]/go/g' *.md
sed -i 's/\[DATE\]/2025-10-31/g' *.md

# Or re-run init script (confirm overwrite when prompted)
./specification/llm-work-templates/enforcement/init-language-workspace.sh {language}
```

---

## References

**Research documents:**
- `terchris/plans-current/research-claude-code-task-management.md` - Community practices
- `terchris/plans-current/research-hierarchical-task-management.md` - General patterns
- `terchris/plans-current/task-management-system-plan.md` - Implementation plan

**Related files:**
- `.claude/skills/implement-language/SKILL.md` - Integration point
- `specification/tools/run-full-validation.sh` - Enforcement integration
- `specification/09-development-loop.md` - Test-driven iterative workflow (6 steps: Edit → Lint → Build → Run → Validate → Iterate when fails). See "Test-Driven Development: The Iterative Feedback Loop" section for complete workflow.
- `specification/10-code-quality.md` - Linting standards (MANDATORY - must pass before build)
- `typescript/` - Reference implementation (source of truth)

**Community sources:**
- Ben Newton's ROADMAP.md pattern
- CCPM system (GitHub Issues + parallel agents)
- Task file directories approach
- Make/CI/CD phase gate patterns

---

## Contributing

When improving this system:

1. **Test changes** with init-language-workspace.sh
2. **Document in this README** (what changed, why)
3. **Update version number** in templates
4. **Test with new language** to verify templates work
5. **Consider backward compatibility** (existing languages)

**Philosophy:** Simple, enforced, community-proven patterns. Don't over-engineer.

---

**Last updated:** 2025-11-12
**Maintainer:** sovdev-logger project
**License:** Same as project
