# Task 3: Research OTEL SDK for [LANGUAGE]

**Parent task**: ROADMAP.md - Phase 0, Task 3
**Prerequisites**: Tasks 1 and 2 complete

---

## Purpose

Research the OpenTelemetry SDK for [LANGUAGE] to understand:
- How to configure OTLP exporters
- How to set custom HTTP headers
- How to create metric labels (underscores vs dots)
- Differences from TypeScript SDK

**Background**: Read `specification/llm-work-templates/research-otel-sdk-guide.md` for WHAT to look for (SDK differences across languages)

**Output**: Understanding documented in `otel-sdk-comparison.md`

---

## Subtasks

### 3.1 Visit OpenTelemetry Documentation

- [ ] Go to https://opentelemetry.io/docs/languages/
- [ ] Find [LANGUAGE] in the language list
- [ ] Open the [LANGUAGE] documentation page
- [ ] Bookmark the page for reference

**Expected**: Official SDK documentation URL

---

### 3.2 Check SDK Signal Status

- [ ] Read the "Status and Releases" table on the languages page
- [ ] Verify status for [LANGUAGE]:
  - Traces: _______ (Development/Beta/Stable)
  - Metrics: _______ (Development/Beta/Stable)
  - Logs: _______ (Development/Beta/Stable)
- [ ] If ANY signal is "Development" → Document risks
- [ ] If ANY signal is "Beta" → Document limitations

**Success criteria**: All three signals are "Stable" or "Beta"

**If not stable**: Document workarounds or alternative approaches

---

### 3.3 Find OTLP Exporter Configuration

Research how to configure OTLP exporters in [LANGUAGE].

- [ ] Search docs for "OTLP exporter" or "OTLP configuration"
- [ ] Find code examples for:
  - OTLP Logs Exporter
  - OTLP Metrics Exporter
  - OTLP Traces Exporter
- [ ] Identify configuration object/struct/class
- [ ] Document package/module names needed

**Key questions to answer**:
- What package provides OTLP exporters?
- How do you instantiate an exporter?
- Where does endpoint URL configuration go?

**Example research output**:
```
Language: C#
Package: OpenTelemetry.Exporter.OpenTelemetryProtocol
Classes: OtlpLogExporter, OtlpMetricExporter, OtlpTraceExporter
Configuration: Via OtlpExporterOptions class
Endpoint: OtlpExporterOptions.Endpoint property
```

---

### 3.4 Find HTTP Header Configuration Method

**Critical**: All OTLP exporters MUST send `Host: otel.localhost` header.

Research how to add custom HTTP headers in [LANGUAGE] OTLP exporters.

- [ ] Search docs for "custom headers" or "HTTP headers"
- [ ] Find configuration option for headers
- [ ] Document exact API/method/property name
- [ ] Check if headers are per-exporter or global

**Key questions to answer**:
- How do you add a custom HTTP header?
- Is it `Headers`, `HttpHeaders`, `CustomHeaders`, or something else?
- Is the format a dictionary, map, list, or object?
- Can you set different headers per exporter?

**Example research output**:
```
Language: C#
Method: OtlpExporterOptions.Headers property
Type: Dictionary<string, string>
Usage: options.Headers.Add("Host", "otel.localhost")
Per-exporter: Yes, set separately for logs, metrics, traces
```

**Red flag**: If SDK doesn't support custom headers → Escalate to user

---

### 3.5 Find Metric Label/Attribute Pattern

**Critical**: Metrics MUST use underscores in labels, NOT dots.

Research how [LANGUAGE] SDK handles metric attributes.

- [ ] Search docs for "metric attributes" or "metric labels"
- [ ] Find code examples of creating metrics
- [ ] Identify how attributes/labels are added
- [ ] Check if SDK enforces naming convention

**Key questions to answer**:
- What's the method to add attributes to metrics?
- Does SDK accept dots in attribute names?
- Does SDK automatically convert dots to underscores?
- What's the [LANGUAGE] idiomatic naming style?

**Example research output**:
```
Language: C#
Method: meter.CreateCounter<T>("name", "unit", "description")
Attributes: Added via KeyValuePair<string, object> or TagList
Naming: SDK accepts any characters (no automatic conversion)
Convention: Use underscores (peer_service, operation_name)
WARNING: Dots will break Grafana filtering - must use underscores
```

**Test code example**:
```csharp
// CORRECT - Uses underscores
counter.Add(1, new KeyValuePair<string, object>("peer_service", "db"));

// WRONG - Uses dots (will break Grafana)
counter.Add(1, new KeyValuePair<string, object>("peer.service", "db"));
```

---

### 3.6 Research Instrument Creation Patterns

**Context**: Different languages have different patterns for when instruments (Counter, Histogram, UpDownCounter) should be created relative to provider initialization.

Research instrument lifecycle in [LANGUAGE].

- [ ] Search GitHub for official examples: `site:github.com/open-telemetry opentelemetry-[language] counter example`
- [ ] Find example code in official repository (https://github.com/open-telemetry/opentelemetry-[language])
- [ ] Look for examples showing:
  - When to create Meter
  - When to create instruments (Counter, Histogram, UpDownCounter)
  - When to initialize MeterProvider
  - Order of operations
- [ ] Check if instruments must be created BEFORE or AFTER provider initialization
- [ ] Document the standard pattern for [LANGUAGE]

**Key questions to answer**:
- Is there a standard initialization order?
- Do instruments need to be registered before provider.Build()?
- Are there language-specific lifecycle requirements?
- What happens if instruments are created in wrong order?

**Example research output**:
```
Language: C#
Pattern: Meter and instruments MUST be created BEFORE MeterProvider.Build()
Source: https://github.com/open-telemetry/opentelemetry-dotnet/blob/main/examples/metrics/Program.cs
Order:
  1. Create Meter
  2. Create instruments (counter, histogram, updowncounter)
  3. Build MeterProvider
  4. Use instruments

Rationale: .NET SDK requires instruments to exist for provider registration
What breaks: Creating instruments AFTER Build() = instruments won't export
```

**Why this matters**:
- Incorrect initialization order = instruments don't appear in OTLP exports
- Each language has different lifecycle requirements
- Official examples show the correct pattern
- Saves hours of "why aren't my metrics showing up" debugging

**Where to search**:
- Official SDK repository: https://github.com/open-telemetry/opentelemetry-[language]
- Look for `/examples/` or `/docs/` directories
- Search for "metrics example" or "counter example"

---

### 3.7 Compare with TypeScript SDK

Read the TypeScript reference implementation: `typescript/src/index.ts`

- [ ] Open `typescript/src/index.ts`
- [ ] Study how TypeScript configures OTLP exporters
- [ ] Note TypeScript's approach to HTTP headers
- [ ] Note TypeScript's metric attribute pattern
- [ ] Identify differences in [LANGUAGE] SDK

**Key differences to document**:
- Configuration syntax (TypeScript vs [LANGUAGE])
- Package organization (TypeScript vs [LANGUAGE])
- Header setup (TypeScript vs [LANGUAGE])
- Metric attribute API (TypeScript vs [LANGUAGE])

**Example comparison**:
```
TypeScript:
- Headers: OTLPExporterConfigBase.headers (object)
- Metrics: meter.createCounter(...).add(value, { peer_service: "db" })

C#:
- Headers: OtlpExporterOptions.Headers (Dictionary<string, string>)
- Metrics: counter.Add(value, new KeyValuePair<string, object>("peer_service", "db"))

Key difference: C# uses KeyValuePair, TypeScript uses plain object
```

---

### 3.8 Create Initial Research Notes

Create `[LANGUAGE]/llm-work/otel-sdk-comparison.md` with initial research findings.

**Note:** This is a rough draft. Task 4 will complete and structure this document with critical implementation details (duration handling, histogram units, workarounds).

- [ ] Create file: `[LANGUAGE]/llm-work/otel-sdk-comparison.md`
- [ ] Document SDK maturity status
- [ ] Document OTLP exporter packages
- [ ] Document HTTP header configuration method
- [ ] Document metric attribute pattern
- [ ] Document key differences from TypeScript
- [ ] Include code examples
- [ ] List packages/dependencies needed

**Template structure**:
```markdown
# OpenTelemetry SDK Comparison - [LANGUAGE]

## SDK Maturity Status
- Traces: [Status]
- Metrics: [Status]
- Logs: [Status]
- Source: https://opentelemetry.io/docs/languages/

## Packages Required
- Package 1: [name] - [purpose]
- Package 2: [name] - [purpose]

## OTLP Exporter Configuration
[Code example]

## HTTP Headers Configuration
[Code example showing Host: otel.localhost]

## Metric Attributes Pattern
[Code example showing underscores]

## Differences from TypeScript
1. [Difference 1]
2. [Difference 2]

## Dependencies
[List of packages to install]

## References
- [Link to SDK docs]
- [Link to OTLP exporter docs]
- [Link to metrics docs]
```

---

## Success Criteria

**This task is complete when**:

- [ ] All 8 subtasks checked off
- [ ] SDK maturity verified (all signals Beta or Stable)
- [ ] HTTP header configuration method researched
- [ ] Metric attribute pattern researched (underscores!)
- [ ] Instrument creation pattern researched (initialization order!)
- [ ] Initial otel-sdk-comparison.md file created with basic research findings
- [ ] File contains code examples from SDK documentation
- [ ] Key differences from TypeScript noted

**Note:** This creates initial research notes. Task 4 will add critical implementation details (duration handling, histogram units, workarounds).

**Do NOT mark complete if**:
- ❌ otel-sdk-comparison.md file not created
- ❌ HTTP header method unclear/unknown
- ❌ Metric attribute pattern unclear/unknown
- ❌ No code examples from SDK docs

---

## Common Pitfalls

### Pitfall 1: Assuming SDK Works Like TypeScript
**Problem**: Each language SDK has different APIs
**Solution**: Read [LANGUAGE] docs specifically, don't assume

### Pitfall 2: Missing HTTP Headers Method
**Problem**: Not documenting HOW to add `Host: otel.localhost`
**Solution**: Must have explicit code example with exact API

### Pitfall 3: Ignoring Metric Naming Convention
**Problem**: Assuming dots work (they break Grafana)
**Solution**: Verify underscores are used, test examples

### Pitfall 4: Shallow Research
**Problem**: "I think it works like this" instead of verified facts
**Solution**: Must have code examples from actual SDK documentation

### Pitfall 5: Skipping Comparison
**Problem**: Not identifying differences from TypeScript
**Solution**: Side-by-side comparison catches subtle issues

---

## Validation

**Before marking complete, verify**:

```bash
# File exists
ls [LANGUAGE]/llm-work/otel-sdk-comparison.md

# File has substance (>100 lines for thorough research)
wc -l [LANGUAGE]/llm-work/otel-sdk-comparison.md

# Contains key terms
grep -i "header" [LANGUAGE]/llm-work/otel-sdk-comparison.md
grep -i "underscore" [LANGUAGE]/llm-work/otel-sdk-comparison.md
grep -i "otlp" [LANGUAGE]/llm-work/otel-sdk-comparison.md
```

**All checks must pass before claiming completion.**

---

**Parent task**: Return to ROADMAP.md when complete
**Next task**: Task 4 - Complete SDK comparison doc with critical implementation details
