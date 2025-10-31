# Task 1: Check OTEL SDK Maturity for [LANGUAGE]

**Parent task**: ROADMAP.md - Phase 0, Task 1
**Estimated time**: 5 minutes
**Prerequisites**: None (first task)

---

## Purpose

Verify that the OpenTelemetry SDK for [LANGUAGE] is mature enough to use for sovdev-logger implementation.

**Output**: Documented SDK maturity status for Traces, Metrics, and Logs

---

## Subtasks

### 1.1 Visit OpenTelemetry Languages Page

- [ ] Open browser to https://opentelemetry.io/docs/languages/
- [ ] Find [LANGUAGE] in the language list
- [ ] Click on [LANGUAGE] to open the language-specific documentation

**Expected result**: Language-specific OpenTelemetry documentation page

---

### 1.2 Check Signal Maturity Status

On the languages page, find the "Status and Releases" table.

- [ ] Locate [LANGUAGE] in the status table
- [ ] Record maturity status for each signal:
  - [ ] **Traces**: _________________ (Stable/Beta/Development)
  - [ ] **Metrics**: _________________ (Stable/Beta/Development)
  - [ ] **Logs**: _________________ (Stable/Beta/Development)

**Success criteria:**
- ✅ **All three signals are "Stable" or "Beta"** → Proceed with implementation
- ⚠️ **Any signal is "Development"** → Document risks and limitations below
- ❌ **Logs signal missing** → Escalate to user (cannot implement without logs)

---

### 1.3 Document Findings

Record the maturity status in your workspace:

**SDK Maturity Status for [LANGUAGE]:**
```
Source: https://opentelemetry.io/docs/languages/[language]
Date checked: [DATE]

Traces:  [Stable/Beta/Development]
Metrics: [Stable/Beta/Development]
Logs:    [Stable/Beta/Development]
```

**If any signal is Beta or Development, document known limitations:**
```
[List any known limitations from the documentation]
```

---

### 1.4 Verify GitHub Repository Exists

- [ ] Find GitHub repository link on the documentation page
- [ ] Expected format: https://github.com/open-telemetry/opentelemetry-[language]
- [ ] Verify repository exists and has activity (not abandoned)
- [ ] Record repository URL: _______________________________

**Success criteria:**
- ✅ Repository exists
- ✅ Recent commits (within last 6 months)
- ❌ No repository or abandoned → Escalate to user

---

## Success Criteria

**This task is complete when:**

- [ ] All subtasks checked off
- [ ] SDK maturity verified for all 3 signals (Traces, Metrics, Logs)
- [ ] All signals are "Stable" or "Beta" (no "Development")
- [ ] GitHub repository URL recorded
- [ ] Any limitations documented
- [ ] Ready to proceed to Task 2

**Do NOT mark complete if:**
- ❌ Any signal is missing or "Development"
- ❌ Cannot find [LANGUAGE] in OpenTelemetry documentation
- ❌ GitHub repository doesn't exist or is abandoned

---

## Common Issues

### Issue 1: Language Not Listed
**Problem**: Cannot find [LANGUAGE] in OpenTelemetry languages list
**Solution**: Language may not be officially supported. Check for community implementations or escalate to user.

### Issue 2: Logs Signal Not Supported
**Problem**: Logs signal is "Development" or missing
**Solution**: Cannot implement sovdev-logger without logs support. Escalate to user for alternative language.

### Issue 3: All Signals are Beta
**Problem**: Signals are Beta, not Stable
**Solution**: Beta is acceptable but document that APIs might change. Proceed with caution.

---

## Validation

**Before marking complete, verify:**

```bash
# No command needed - this is a documentation task
```

**All checks:**
- [ ] Traces, Metrics, Logs maturity documented
- [ ] GitHub repository URL recorded
- [ ] Decision made: Proceed or escalate

---

## Time Estimate

- Subtask 1.1: 1 minute (open page)
- Subtask 1.2: 2 minutes (check status)
- Subtask 1.3: 1 minute (document)
- Subtask 1.4: 1 minute (verify GitHub)

**Total**: ~5 minutes

---

**Parent task**: Return to ROADMAP.md when complete
**Next task**: Task 2 - Verify TypeScript baseline
