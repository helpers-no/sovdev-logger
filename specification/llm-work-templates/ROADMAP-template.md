# [LANGUAGE] Implementation Progress

**Last updated**: [DATE]
**Language**: [LANGUAGE]
**Target directory**: [LANGUAGE]/

---

## Phase 0: Planning (0/4 complete) 📋

- [ ] 1. Check OTEL SDK maturity → [Details](task-01-check-otel-maturity.md)
  - Visit https://opentelemetry.io/docs/languages/
  - Document maturity status for [LANGUAGE]
  - Expected: 5 minutes

- [ ] 2. Verify TypeScript baseline → [Details](task-02-verify-typescript.md)
  - Ensure monitoring stack works before starting
  - Run TypeScript validation to confirm infrastructure
  - Expected: 10 minutes

- [ ] 3. Research OTEL SDK for [LANGUAGE] → [Details](task-03-research-otel-sdk.md)
  - Study [LANGUAGE] SDK documentation
  - Find HTTP header configuration method
  - Find metric attribute pattern (underscores!)
  - Document differences from TypeScript
  - Expected: 1-2 hours

- [ ] 4. Create SDK comparison doc → [Details](task-04-sdk-comparison.md)
  - Output: `otel-sdk-comparison.md`
  - Document findings from Task 3
  - Expected: 30 minutes

---

## Phase 1: Implementation (0/4 complete) 🔒 LOCKED

**Unlocked after Phase 0: 4/4 complete**

- [ ] 5. Setup project structure → [Details](task-05-setup-project.md)
  - Create directory structure
  - Install dependencies
  - Configure build system (Makefile with lint, lint-fix, build, test targets)
  - Setup linting (see specification/10-code-quality.md)
  - ⚠️ **MANDATORY**: Create .env file in test/e2e/company-lookup/.env
  - ⛔ **BLOCKING**: Task 6 cannot start without .env file
  - Expected: 45 minutes

- [ ] 6. Implement OTLP exporters → [Details](task-06-implement-otlp.md)
  - ⛔ **PREREQUISITE**: .env file must exist (from Task 5)
  - OTLP logs exporter
  - OTLP metrics exporter
  - OTLP traces exporter
  - All with `Host: otel.localhost` header
  - Expected: 2-3 hours

- [ ] 7. Implement 8 API functions → [Details](task-07-implement-api.md)
  - initLogger, startSpan, endSpan, log, etc.
  - Full API contract implementation
  - Expected: 3-4 hours

- [ ] 8. Implement file logging → [Details](task-08-file-logging.md)
  - Choose logging library
  - Configure log rotation
  - Format as spec-compliant JSON
  - Expected: 1-2 hours

---

## Phase 2: Testing (0/2 complete) 🔒 LOCKED

**Unlocked after Phase 1: 4/4 complete**

- [ ] 9. Create E2E test → [Details](task-09-e2e-test.md)
  - Implement company-lookup test
  - Follows specification/08-testprogram-company-lookup.md
  - Tests all 8 API functions
  - Expected: 2-3 hours

- [ ] 10. Run test successfully
  - Test executes without errors
  - Log files created in logs/ directory
  - 17 log entries as specified
  - Expected: 30 minutes (includes debugging)

---

## Phase 3: Validation (0/3 complete) 🔒 LOCKED

**Unlocked after Phase 2: 2/2 complete**

- [ ] 11. File validation passes
  - Run: `cd /workspace/specification/tools && ./validate-log-format.sh`
  - All checks pass
  - Expected: 5 minutes

- [ ] 12. Backend validation passes → [Details](task-12-validation.md)
  - Logs in Loki
  - Metrics in Prometheus (with correct labels!)
  - Traces in Tempo
  - All Grafana connections work
  - Expected: 30 minutes

- [ ] 13. Grafana visual verification ✅
  - Open http://grafana.localhost
  - ALL panels show data for [LANGUAGE]
  - Compare with TypeScript (reference implementation)
  - Verify metric filtering works
  - Expected: 15 minutes

---

## ✅ Recently Completed

[Completed tasks moved here automatically with completion timestamps]

---

## Progress Summary

- **Total**: 0/13 tasks (0%)
- **Phase 0**: 0/4 (0%) 📋
- **Phase 1**: 0/4 (0%) 🔒 LOCKED
- **Phase 2**: 0/2 (0%) 🔒 LOCKED
- **Phase 3**: 0/3 (0%) 🔒 LOCKED

---

## Notes

**Checkbox States**:
- `[ ]` = Todo (no timestamp)
- `[-]` = In Progress (add: 🏗️ YYYY-MM-DD when started)
- `[x]` = Completed (add: ✅ YYYY-MM-DD when done)

**Phase Gates**:
- Each phase must be 100% complete before next unlocks
- Validation scripts enforce this
- Cannot skip phases

**Task Files**:
- Simple tasks: No detail file needed
- Complex tasks: Link to `task-XX-name.md` with subtasks

**See Also**:
- Instructions: `CLAUDE.md` (read this at start of each session!)
- Templates: `../../specification/llm-work-templates/`
- Validation tools: `../../specification/tools/`
