# OpenTelemetry SDK Implementation Guide

---

## Overview

**⚠️ CRITICAL:** OpenTelemetry SDKs differ significantly between languages. You **cannot** translate TypeScript code to another language. Each SDK has unique patterns, behaviors, and requirements.

**You must understand BOTH the reference SDK (TypeScript) AND the target language SDK before writing code.**

---

## The Core Problem

Each language's OTEL SDK has different:
- HTTP client behavior
- Metric attribute patterns
- Time/duration units
- Configuration patterns
- Header handling

**Example:** TypeScript Host headers work ✅ | Go overwrites Host header → 404 errors ❌

---

## Pre-Implementation Checklist

**Complete ALL before writing any code:**

### 1. Verify OTEL SDK
- [ ] Visit https://opentelemetry.io/docs/languages/
- [ ] Verify SDK status: Stable/Beta/Alpha
- [ ] Verify supports: Logs, Metrics, Traces

**Supported:** TypeScript ✅ Go ✅ Python ✅ Java ✅ .NET ✅ Rust ⚠️Beta PHP ⚠️Alpha

### 2. Study TypeScript (Reference)
- [ ] Read `typescript/src/logger.ts`
- [ ] Read https://opentelemetry.io/docs/languages/js/
- [ ] Understand: providers, exporters, metrics, duration, attributes

**Key TypeScript Patterns:**
```typescript
// Duration: milliseconds (Date.now())
const duration = Date.now() - startTime;

// Attributes: underscore notation
{ 'peer_service': value, 'log_type': value, 'log_level': value }

// Histogram: unit specification
meter.createHistogram('sovdev_operation_duration', { unit: 'ms' })
```

### 3. Study Target Language SDK
- [ ] Read Getting Started guide
- [ ] Read Logs/Metrics/Traces API docs
- [ ] Read OTLP HTTP Exporter docs

**Answer these questions:**

| Question | TypeScript Answer | Target Language Answer |
|----------|-------------------|------------------------|
| HTTP headers work? | Yes, via `headers` option | ? (test or read docs) |
| Attribute notation? | Underscores | ? (dots or underscores?) |
| Time unit? | Milliseconds (Date.now()) | ? (seconds? nanoseconds?) |
| Histogram unit? | `unit: 'ms'` option | ? (how to specify?) |
| Semantic conventions? | N/A (manual attributes) | ? (uses dots? can override?) |

### 4. Create SDK Comparison Document
- [ ] Create `<language>/llm-work/otel-sdk-comparison.md`
- [ ] Document all differences from TypeScript
- [ ] Document required workarounds
- [ ] Include code examples

**Note:** Use the `<language>/llm-work/` directory as your workspace for all SDK analysis, comparison documents, notes, and working files during implementation.

---

## SDK Comparison Template

**Location:** `<language>/llm-work/otel-sdk-comparison.md`

```markdown
# OTEL SDK Comparison: TypeScript vs <Language>

| Aspect | TypeScript | <Language> | Issue? | Solution |
|--------|-----------|------------|---------|----------|
| **HTTP Headers** | Via `headers` option, works | ? | ? | ? |
| **Attributes** | Underscores (peer_service) | ? | ? | ? |
| **Duration Unit** | Milliseconds (Date.now()) | ? | ? | ? |
| **Histogram Unit** | `unit: 'ms'` option | ? | ? | ? |
| **Semantic Conventions** | Manual attributes | ? | ? | ? |

## Known Issues
[Document each issue with symptom, cause, solution + code]
```

---

## Implementation & Validation

### Implementation Order
1. OTLP logs export → test in Loki
2. Metrics export → **verify labels match TypeScript** → test in Prometheus
3. Traces export → test in Tempo
4. All 8 API functions
5. Validate ALL (file logs, OTLP, Grafana)

### Validation (CRITICAL)

**DO NOT claim complete without ALL of these:

**1. File Logs**
```bash
validate-log-format.sh <language>/test/e2e/company-lookup/logs/dev.log
```

**2. OTLP Export**
```bash
run-full-validation.sh <language>
query-prometheus.sh 'sovdev_operations_total{service_name=~".*<language>.*"}'
```

**3. Grafana Dashboard (MOST CRITICAL)**
```bash
# Run both tests
run-full-validation.sh typescript
run-full-validation.sh <language>

# Open Grafana → http://grafana.localhost
# Verify ALL 3 panels show data for BOTH languages:
# 1. Total Operations (Last, Max)
# 2. Error Rate (Last, Max)
# 3. Average Operation Duration (all peer services)
```

**4. Compare Metric Labels**
```bash
# Compare TypeScript vs target language
query-prometheus.sh 'sovdev_operations_total{service_name=~".*typescript.*"}' > ts.txt
query-prometheus.sh 'sovdev_operations_total{service_name=~".*<language>.*"}' > lang.txt
diff ts.txt lang.txt

# Must show IDENTICAL labels:
# ✅ peer_service (underscore)
# ✅ log_type (underscore)
# ✅ log_level (underscore)
# ❌ NOT peer.service (dot) or function.name (wrong name)
```

---

## Common Pitfalls

| Pitfall | Wrong | Why it Fails | Correct |
|---------|-------|--------------|---------|
| **Syntax Translation** | Translate TS code to target language | SDK APIs differ | Study both SDKs, document differences, implement equivalents |
| **Semantic Conventions** | `semconv.PeerService` → "peer.service" | Prometheus needs underscores | Use explicit `attribute.String("peer_service", ...)` |
| **Duration Unit** | `time.Since().Seconds()` | Grafana expects milliseconds | Use `.Milliseconds()` to match TypeScript |
| **Histogram Unit** | Omit `unit` option | Grafana histogram queries need unit | Always include `unit: 'ms'` or `WithUnit("ms")` |
| **Early Complete** | File logs + Prometheus = done | Labels may be wrong | Validate Grafana dashboard ALL panels |

---

## Language-Specific Known Issues

**For environment architecture diagram** showing why `Host: otel.localhost` is required (Traefik routing), see `05-environment-configuration.md` → **Architecture Diagram** section.

### Go

| Issue | Symptom | Cause | Solution | Reference |
|-------|---------|-------|----------|-----------|
| HTTP Host header | 404 OTLP errors | `http.Client` overwrites Host from URL | Custom transport | `go/src/logger.go` + `05-environment-configuration.md` (Traefik routing) |
| Semantic conventions | No Grafana data | `semconv.PeerService` → "peer.service" (dot) | Explicit `attribute.String("peer_service", ...)` | `go/src/logger.go` |
| Duration unit | Zero/missing durations | `.Seconds()` returns seconds | Use `.Milliseconds()` | `go/src/logger.go` |

### Python, Java, Rust
[To be documented when implemented]

---

## For LLMs: Critical Rules

1. **Check language toolchain FIRST** - Install via `.devcontainer/additions/install-dev-<language>.sh` if needed
2. **Use `<language>/llm-work/` as your workspace** - Create SDK comparison, analysis notes, and working files in this directory
3. **Study BOTH SDKs BEFORE coding** - Read TypeScript + target language OTEL docs, create comparison document in `<language>/llm-work/`
4. **Compare behavior, not syntax** - Understand WHY TypeScript code exists, find equivalent pattern
5. **Document ALL differences** - Update SDK comparison as you discover issues
6. **NEVER claim complete without Grafana validation** - ALL 3 panels must show data

**📝 For universal implementation patterns** (batch processing, field naming, directory structure, etc.), see [`03-implementation-patterns.md`](./03-implementation-patterns.md)

---

## Success Criteria

- ✅ ALL file log validation passes
- ✅ ALL OTLP backends receive data
- ✅ ALL Grafana dashboard panels show data
- ✅ Metric labels match TypeScript exactly (peer_service, log_type, log_level with underscores)
- ✅ Duration values in milliseconds

**OpenTelemetry SDKs are NOT identical. Study both, document differences, implement workarounds, validate behavior.**

---

**Document Status:** ✅ v1.0.0 COMPLETE
**Last Updated:** 2025-10-27
**Part of:** sovdev-logger specification v1.1.0
**Based on:** Go implementation experience
