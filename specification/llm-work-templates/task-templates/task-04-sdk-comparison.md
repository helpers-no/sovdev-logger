# Task 4: Create SDK Comparison Document

**Parent task**: ROADMAP.md - Phase 0, Task 4
**Estimated time**: 30 minutes
**Prerequisites**: Task 3 complete (SDK research done)

---

## Purpose

Create a comprehensive comparison document that captures all findings from Task 3 (SDK research).

**Output**: `[LANGUAGE]/llm-work/otel-sdk-comparison.md`

**Why this matters:** This document becomes the reference for understanding how [LANGUAGE] SDK differs from TypeScript, preventing repeated research and capturing workarounds for future maintainers.

---

## Subtasks

### 4.1 Create Document File

- [ ] Create file: `[LANGUAGE]/llm-work/otel-sdk-comparison.md`
- [ ] Copy template structure from below
- [ ] Fill in [LANGUAGE] placeholder

---

### 4.2 Document SDK Maturity Status

From Task 1 findings:

- [ ] Copy maturity status (Traces, Metrics, Logs)
- [ ] Include source URL and date checked
- [ ] Document any limitations for Beta/Development signals

**Section content:**
```markdown
## SDK Maturity Status

Source: https://opentelemetry.io/docs/languages/[language]
Date checked: [DATE]

- **Traces**: [Stable/Beta/Development]
- **Metrics**: [Stable/Beta/Development]
- **Logs**: [Stable/Beta/Development]

### Known Limitations

[List any Beta/Development limitations]
```

---

### 4.3 Document Required Packages

From Task 3.3 findings:

- [ ] List all OTEL packages needed
- [ ] Include package names, versions, purpose
- [ ] Document installation commands

**Section content:**
```markdown
## Packages Required

| Package | Purpose | Installation |
|---------|---------|--------------|
| [package-name] | OTLP logs exporter | [install command] |
| [package-name] | OTLP metrics exporter | [install command] |
| [package-name] | OTLP traces exporter | [install command] |
| [package-name] | HTTP client (if custom needed) | [install command] |

**Installation:**
\`\`\`bash
[combined install command]
\`\`\`
```

---

### 4.4 Document OTLP Exporter Configuration

From Task 3.3 findings:

- [ ] Show how to configure OTLP exporters
- [ ] Include code example for each signal (logs, metrics, traces)
- [ ] Document endpoint configuration
- [ ] Document HTTP header configuration

**Section content:**
```markdown
## OTLP Exporter Configuration

### Logs Exporter
\`\`\`[language]
[Code example showing OTLP logs exporter configuration]
\`\`\`

### Metrics Exporter
\`\`\`[language]
[Code example showing OTLP metrics exporter configuration]
\`\`\`

### Traces Exporter
\`\`\`[language]
[Code example showing OTLP traces exporter configuration]
\`\`\`
```

---

### 4.5 Document HTTP Headers Configuration (CRITICAL)

From Task 3.4 findings:

- [ ] Document HOW to set custom HTTP headers
- [ ] Include code example with `Host: otel.localhost`
- [ ] Note if per-exporter or global configuration

**Section content:**
```markdown
## HTTP Headers Configuration ⚠️ CRITICAL

**Required header:** \`Host: otel.localhost\`

### How to Set Headers in [LANGUAGE]

\`\`\`[language]
[Code example showing how to set custom HTTP headers]
\`\`\`

**Notes:**
- [Per-exporter or global?]
- [Any SDK-specific quirks?]
- [Alternative approaches if needed]
```

---

### 4.6 Document Metric Attributes Pattern (CRITICAL)

From Task 3.5 findings:

- [ ] Document HOW to create metric attributes
- [ ] Show CORRECT pattern (underscores)
- [ ] Show WRONG pattern (dots) with warning
- [ ] Include code examples

**Section content:**
```markdown
## Metric Attributes Pattern ⚠️ CRITICAL

**MUST use underscores, NOT dots:**
- ✅ Correct: \`peer_service\`, \`log_type\`, \`log_level\`
- ❌ Wrong: \`peer.service\`, \`log.type\`, \`log.level\`

### How to Set Attributes in [LANGUAGE]

**Correct example:**
\`\`\`[language]
[Code showing underscore notation]
\`\`\`

**Wrong example (DO NOT USE):**
\`\`\`[language]
[Code showing dot notation with ❌ markers]
\`\`\`

**Why this matters:** Grafana filtering requires underscores. Dots will break dashboard queries.
```

---

### 4.7 Document Duration Handling (CRITICAL)

From Task 3 research:

- [ ] Document native time unit in [LANGUAGE]
- [ ] Show conversion to milliseconds
- [ ] Include code example

**Section content:**
```markdown
## Duration Recording ⚠️ CRITICAL

**MUST record in milliseconds, NOT seconds.**

### Native Time Unit in [LANGUAGE]

[LANGUAGE] measures time in: [nanoseconds/microseconds/milliseconds/seconds]

### Conversion to Milliseconds

\`\`\`[language]
[Code example showing time capture and conversion to milliseconds]
\`\`\`
```

---

### 4.8 Document Histogram Unit (CRITICAL)

From Task 3 research:

- [ ] Document HOW to specify histogram unit
- [ ] Show code example with \`unit: "ms"\`

**Section content:**
```markdown
## Histogram Unit Specification ⚠️ CRITICAL

**MUST specify unit as "ms" for duration histogram.**

### How to Set Unit in [LANGUAGE]

\`\`\`[language]
[Code example showing histogram creation with unit specification]
\`\`\`

**Why this matters:** Grafana expects milliseconds. Wrong unit causes values to display incorrectly (0.000538 instead of 0.538 ms).
```

---

### 4.9 Document Differences from TypeScript

From Task 3.6 findings:

- [ ] List key differences in API
- [ ] Note different patterns or idioms
- [ ] Document workarounds needed

**Section content:**
```markdown
## Differences from TypeScript

| Aspect | TypeScript | [LANGUAGE] | Notes |
|--------|-----------|------------|-------|
| HTTP headers | \`headers: {...}\` | [method] | [notes] |
| Metric attributes | \`{peer_service: "x"}\` | [method] | [notes] |
| Duration | \`Date.now()\` | [method] | [notes] |
| Histogram unit | \`unit: 'ms'\` | [method] | [notes] |
| Exporter config | [pattern] | [pattern] | [notes] |

### Key Differences Explained

1. **[Difference 1]**
   - TypeScript: [approach]
   - [LANGUAGE]: [approach]
   - Why: [explanation]

2. **[Difference 2]**
   - [Continue pattern]
```

---

### 4.10 Document Workarounds (if any)

If SDK has limitations:

- [ ] Document each workaround
- [ ] Explain why it's needed
- [ ] Show code example
- [ ] Reference issue/PR if applicable

**Section content:**
```markdown
## Workarounds Implemented

### Workaround 1: [Issue Description]

**Problem:** [What doesn't work out of the box]

**Solution:** [How we work around it]

\`\`\`[language]
[Code example]
\`\`\`

**Reference:** [Link to issue/PR/documentation]
```

---

### 4.11 Add References Section

- [ ] List all URLs consulted
- [ ] Include SDK documentation links
- [ ] Include GitHub repository links

**Section content:**
```markdown
## References

**Official Documentation:**
- [LANGUAGE] SDK: https://opentelemetry.io/docs/languages/[language]/
- Getting Started: [URL]
- OTLP Exporter: [URL]
- Metrics API: [URL]

**GitHub Repository:**
- Main repo: https://github.com/open-telemetry/opentelemetry-[language]
- Examples: [URL]
- Issues consulted: [URLs]

**Related:**
- TypeScript reference: \`typescript/src/logger.ts\`
- Specification: \`specification/01-api-contract.md\`
```

---

## Success Criteria

**This task is complete when:**

- [ ] All 11 subtasks checked off
- [ ] File `[LANGUAGE]/llm-work/otel-sdk-comparison.md` exists
- [ ] File has all sections with content (not just templates)
- [ ] Code examples are actual [LANGUAGE] code (not pseudocode)
- [ ] Critical sections documented (HTTP headers, metric attributes, duration, histogram unit)
- [ ] Differences from TypeScript clearly explained
- [ ] Document is > 100 lines (thorough research)

**Do NOT mark complete if:**
- ❌ File is empty or only has template headings
- ❌ Code examples are pseudocode or placeholders
- ❌ Missing critical information (HTTP headers, metric attributes)
- ❌ No differences from TypeScript documented

---

## Template Structure

**Complete template to copy:**

```markdown
# OpenTelemetry SDK Comparison - [LANGUAGE]

Date created: [DATE]
Last updated: [DATE]

---

## SDK Maturity Status

[Section 4.2 content]

---

## Packages Required

[Section 4.3 content]

---

## OTLP Exporter Configuration

[Section 4.4 content]

---

## HTTP Headers Configuration ⚠️ CRITICAL

[Section 4.5 content]

---

## Metric Attributes Pattern ⚠️ CRITICAL

[Section 4.6 content]

---

## Duration Recording ⚠️ CRITICAL

[Section 4.7 content]

---

## Histogram Unit Specification ⚠️ CRITICAL

[Section 4.8 content]

---

## Differences from TypeScript

[Section 4.9 content]

---

## Workarounds Implemented

[Section 4.10 content - if applicable]

---

## References

[Section 4.11 content]

---

**Document Status:** ✅ COMPLETE
**Ready for:** Implementation (Task 5+)
```

---

## Validation

**Before marking complete, verify:**

```bash
# File exists
ls [LANGUAGE]/llm-work/otel-sdk-comparison.md

# File has substance (>100 lines)
wc -l [LANGUAGE]/llm-work/otel-sdk-comparison.md

# Contains critical keywords
grep -i "header" [LANGUAGE]/llm-work/otel-sdk-comparison.md
grep -i "underscore" [LANGUAGE]/llm-work/otel-sdk-comparison.md
grep -i "millisecond" [LANGUAGE]/llm-work/otel-sdk-comparison.md
```

**All checks must pass.**

---

## Time Estimate

- Subtask 4.1: 2 minutes (create file)
- Subtask 4.2: 2 minutes (maturity status)
- Subtask 4.3: 3 minutes (packages)
- Subtask 4.4: 5 minutes (OTLP config)
- Subtask 4.5: 5 minutes (HTTP headers)
- Subtask 4.6: 5 minutes (metric attributes)
- Subtask 4.7: 3 minutes (duration)
- Subtask 4.8: 2 minutes (histogram unit)
- Subtask 4.9: 5 minutes (differences)
- Subtask 4.10: 3 minutes (workarounds - if any)
- Subtask 4.11: 2 minutes (references)

**Total**: ~30 minutes (assumes research from Task 3 is complete)

---

**Parent task**: Return to ROADMAP.md when complete
**Next task**: Task 5 - Setup project structure
