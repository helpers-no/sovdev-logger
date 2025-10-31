# Task 6: Implement OTLP Exporters

**Parent task**: ROADMAP.md - Phase 1, Task 6
**Estimated time**: 2-3 hours
**Prerequisites**: Phase 0 complete (especially Task 3 - Research OTEL SDK)

---

## Purpose

Implement OTLP (OpenTelemetry Protocol) exporters for logs, metrics, and traces.

**Critical requirement**: ALL exporters MUST include `Host: otel.localhost` HTTP header.

**Why critical**: Traefik routing depends on this header to route to correct backend (see `specification/05-environment-configuration.md` for architecture).

---

## Prerequisites Check

Before starting, verify:
- [ ] Phase 0 is 100% complete (4/4 tasks)
- [ ] otel-sdk-comparison.md exists and contains HTTP header method
- [ ] You know the exact [LANGUAGE] API for adding HTTP headers
- [ ] Project structure is set up (Task 5 complete)

**If ANY prerequisite missing → Go back and complete it first**

---

## Subtasks

### 6.1 Install OTLP Exporter Packages

- [ ] Identify required packages from otel-sdk-comparison.md
- [ ] Add packages to dependency file (package.json, requirements.txt, go.mod, *.csproj, etc.)
- [ ] Install dependencies
- [ ] Verify installation successful

**Example (C#)**:
```xml
<PackageReference Include="OpenTelemetry.Exporter.OpenTelemetryProtocol" Version="1.x.x" />
<PackageReference Include="OpenTelemetry.Extensions.Hosting" Version="1.x.x" />
```

**Validation**:
```bash
# Build should succeed
cd [LANGUAGE]
[build-command]  # e.g., dotnet build, npm install, go build
```

---

### 6.2 Create OTLP Logs Exporter

Implement OTLP logs exporter with `Host: otel.localhost` header.

**Configuration requirements**:
- Endpoint: `http://otel-collector:4318/v1/logs`
- Protocol: `http/protobuf`
- Custom header: `Host: otel.localhost`

**Implementation checklist**:
- [ ] Import OTLP logs exporter package
- [ ] Configure endpoint URL
- [ ] Add `Host: otel.localhost` header
- [ ] Set protocol to http/protobuf
- [ ] Register exporter with logging provider

**Example structure (pseudocode)**:
```
import OTLPLogExporter

logExporter = new OTLPLogExporter({
  endpoint: "http://otel-collector:4318/v1/logs",
  headers: {
    "Host": "otel.localhost"
  },
  protocol: "http/protobuf"
})

registerLogExporter(logExporter)
```

**Validation**:
- [ ] Code compiles without errors
- [ ] No missing imports
- [ ] Header configuration uses syntax from otel-sdk-comparison.md

---

### 6.3 Create OTLP Metrics Exporter

Implement OTLP metrics exporter with `Host: otel.localhost` header.

**Configuration requirements**:
- Endpoint: `http://otel-collector:4318/v1/metrics`
- Protocol: `http/protobuf`
- Custom header: `Host: otel.localhost`
- Export interval: 1000ms (or SDK default)

**Implementation checklist**:
- [ ] Import OTLP metrics exporter package
- [ ] Configure endpoint URL
- [ ] Add `Host: otel.localhost` header
- [ ] Set protocol to http/protobuf
- [ ] Set export interval (if configurable)
- [ ] Register exporter with metrics provider

**Example structure (pseudocode)**:
```
import OTLPMetricExporter

metricExporter = new OTLPMetricExporter({
  endpoint: "http://otel-collector:4318/v1/metrics",
  headers: {
    "Host": "otel.localhost"
  },
  protocol: "http/protobuf",
  exportIntervalMillis: 1000
})

registerMetricExporter(metricExporter)
```

**Validation**:
- [ ] Code compiles without errors
- [ ] No missing imports
- [ ] Header configuration matches logs exporter pattern

---

### 6.4 Create OTLP Traces Exporter

Implement OTLP traces exporter with `Host: otel.localhost` header.

**Configuration requirements**:
- Endpoint: `http://otel-collector:4318/v1/traces`
- Protocol: `http/protobuf`
- Custom header: `Host: otel.localhost`

**Implementation checklist**:
- [ ] Import OTLP traces exporter package
- [ ] Configure endpoint URL
- [ ] Add `Host: otel.localhost` header
- [ ] Set protocol to http/protobuf
- [ ] Register exporter with tracing provider

**Example structure (pseudocode)**:
```
import OTLPTraceExporter

traceExporter = new OTLPTraceExporter({
  endpoint: "http://otel-collector:4318/v1/traces",
  headers: {
    "Host": "otel.localhost"
  },
  protocol: "http/protobuf"
})

registerTraceExporter(traceExporter)
```

**Validation**:
- [ ] Code compiles without errors
- [ ] No missing imports
- [ ] Header configuration matches pattern from other exporters

---

### 6.5 Configure Resource Attributes

Add common resource attributes to identify this service.

**Required attributes**:
- `service.name`: "[language]-logger" (e.g., "csharp-logger")
- `service.version`: "1.0.0" (or your version)
- `deployment.environment`: "development"

**Implementation checklist**:
- [ ] Create Resource object with attributes
- [ ] Attach resource to logs provider
- [ ] Attach resource to metrics provider
- [ ] Attach resource to traces provider

**Example structure (pseudocode)**:
```
resource = new Resource({
  "service.name": "[language]-logger",
  "service.version": "1.0.0",
  "deployment.environment": "development"
})

logProvider.setResource(resource)
metricProvider.setResource(resource)
traceProvider.setResource(resource)
```

**Validation**:
- [ ] All three providers have resource attributes
- [ ] service.name uses [language]-logger format

---

### 6.6 Initialize OpenTelemetry SDK

Set up SDK initialization that configures all providers.

**Requirements**:
- Initialize SDK early (before any logging/metrics/tracing)
- Register all three exporters
- Configure resource attributes
- Handle initialization errors gracefully

**Implementation checklist**:
- [ ] Create initialization function (e.g., `initOpenTelemetry()`)
- [ ] Initialize logging provider with OTLP exporter
- [ ] Initialize metrics provider with OTLP exporter
- [ ] Initialize tracing provider with OTLP exporter
- [ ] Add error handling
- [ ] Export/expose initialization function

**Example structure (pseudocode)**:
```
function initOpenTelemetry() {
  try {
    // Create resource
    resource = createResource()

    // Initialize logs
    logProvider = createLogProvider(resource, logExporter)

    // Initialize metrics
    metricProvider = createMetricProvider(resource, metricExporter)

    // Initialize traces
    traceProvider = createTraceProvider(resource, traceExporter)

    // Register global providers
    registerGlobalLogProvider(logProvider)
    registerGlobalMetricProvider(metricProvider)
    registerGlobalTraceProvider(traceProvider)

  } catch (error) {
    console.error("Failed to initialize OpenTelemetry:", error)
    throw error
  }
}
```

**Validation**:
- [ ] Function compiles without errors
- [ ] Error handling present
- [ ] All three providers initialized

---

### 6.7 **MANDATORY VALIDATION**: Test Logs Exporter Connectivity

**⛔ BLOCKING STEP**: You MUST verify logs reach Loki before proceeding.

**Complete validation documentation**: See `specification/tools/README.md` for:
- Two-level validation strategy (TypeScript baseline + language-specific)
- Complete 8-step validation sequence
- Tool usage examples and troubleshooting

Create minimal test to verify logs exporter works. This uses OTEL SDK functions to test connectivity.

**Test approach**:
- [ ] Call initOpenTelemetry()
- [ ] Emit a test log entry
- [ ] **MANDATORY**: Verify log appears in Loki backend

**Test code example**:
```
initOpenTelemetry()

logger.info("Test log entry", {
  test_attribute: "test_value"
})

// Give exporter time to send (OTLP batching)
sleep(2000)
```

**Validation (MANDATORY)**:
- [ ] No errors during initialization
- [ ] No errors when emitting log
- [ ] No exceptions thrown
- [ ] **REQUIRED**: Verify in Loki using query tool

**Backend verification (MANDATORY)**:
```bash
# Wait for OTLP export
sleep 10

# Check if logs reach Loki (MUST pass before continuing)
./specification/tools/in-devcontainer.sh -e "cd /workspace/specification/tools && ./query-loki.sh sovdev-test-company-lookup-[LANGUAGE]"
```

**⛔ Cannot proceed to 6.8 until**:
- Logs exporter sends data successfully
- Query tool shows log entries in Loki
- No errors in exporter or backend

**If validation fails**:
- Check Host header is exactly "Host: otel.localhost"
- Check endpoint is "http://otel-collector:4318/v1/logs"
- Check protocol is http/protobuf
- Run TypeScript validation to verify infrastructure works (see specification/09-development-loop.md)

---

### 6.8 **MANDATORY VALIDATION**: Test Metrics Exporter Connectivity

**⛔ BLOCKING STEP**: You MUST verify metrics reach Prometheus before proceeding.

Create minimal test to verify metrics exporter works. This uses OTEL SDK functions to test connectivity.

**Test approach**:
- [ ] Call initOpenTelemetry()
- [ ] Create a counter metric
- [ ] Increment counter with attributes
- [ ] **MANDATORY**: Verify metric appears in Prometheus backend

**Test code example**:
```
initOpenTelemetry()

meter = getMeter("[language]-logger")
counter = meter.createCounter("test_counter", "count", "Test counter")

counter.add(1, {
  peer_service: "test",    // ← Note: underscores!
  operation_name: "test"   // ← Note: underscores!
})

// Give exporter time to send (OTLP batching)
sleep(2000)
```

**Validation (MANDATORY)**:
- [ ] No errors during metric creation
- [ ] No errors when incrementing counter
- [ ] Attributes use underscores (NOT dots)
- [ ] **REQUIRED**: Verify in Prometheus using query tool

**Backend verification (MANDATORY)**:
```bash
# Wait for OTLP export
sleep 10

# Check if metrics reach Prometheus (MUST pass before continuing)
./specification/tools/in-devcontainer.sh -e "cd /workspace/specification/tools && ./query-prometheus.sh sovdev-test-company-lookup-[LANGUAGE]"
```

**⛔ Cannot proceed to 6.9 until**:
- Metrics exporter sends data successfully
- Query tool shows metrics in Prometheus
- Attributes use underscores (peer_service, NOT peer.service)
- No errors in exporter or backend

**If validation fails**:
- Check Host header is exactly "Host: otel.localhost"
- Check endpoint is "http://otel-collector:4318/v1/metrics"
- Check attributes use underscores, not dots
- Run TypeScript validation to verify infrastructure works (see specification/09-development-loop.md)

---

### 6.9 **MANDATORY VALIDATION**: Test Traces Exporter Connectivity

**⛔ BLOCKING STEP**: You MUST verify traces reach Tempo before proceeding.

Create minimal test to verify traces exporter works. This uses OTEL SDK functions to test connectivity.

**Test approach**:
- [ ] Call initOpenTelemetry()
- [ ] Create a test span
- [ ] Add attributes to span
- [ ] End span
- [ ] **MANDATORY**: Verify trace appears in Tempo backend

**Test code example**:
```
initOpenTelemetry()

tracer = getTracer("[language]-logger")
span = tracer.startSpan("test_operation")

span.setAttribute("peer_service", "test")    // ← Note: underscores!
span.setAttribute("operation_name", "test")  // ← Note: underscores!

span.end()

// Give exporter time to send (OTLP batching)
sleep(2000)
```

**Validation (MANDATORY)**:
- [ ] No errors during span creation
- [ ] No errors when adding attributes
- [ ] No errors when ending span
- [ ] Attributes use underscores (NOT dots)
- [ ] **REQUIRED**: Verify in Tempo using query tool

**Backend verification (MANDATORY)**:
```bash
# Wait for OTLP export
sleep 10

# Check if traces reach Tempo (MUST pass before continuing)
./specification/tools/in-devcontainer.sh -e "cd /workspace/specification/tools && ./query-tempo.sh sovdev-test-company-lookup-[LANGUAGE]"
```

**⛔ Cannot mark Task 6 complete until**:
- Traces exporter sends data successfully
- Query tool shows traces in Tempo
- Attributes use underscores (peer_service, NOT peer.service)
- No errors in exporter or backend

**If validation fails**:
- Check Host header is exactly "Host: otel.localhost"
- Check endpoint is "http://otel-collector:4318/v1/traces"
- Check attributes use underscores, not dots
- Run TypeScript validation to verify infrastructure works (see specification/09-development-loop.md)

---

### 6.10 Verify HTTP Header Configuration

**Critical validation**: Confirm `Host: otel.localhost` header is being sent.

**Why critical**: Without this header, requests fail at Traefik (routing fails).

**Verification approaches**:

**Approach 1: Code review**
- [ ] Review each exporter configuration
- [ ] Verify header is set in logs exporter
- [ ] Verify header is set in metrics exporter
- [ ] Verify header is set in traces exporter
- [ ] Confirm syntax matches otel-sdk-comparison.md

**Approach 2: Debug logging** (if SDK supports it)
- [ ] Enable SDK debug logging
- [ ] Run test code
- [ ] Check logs for HTTP requests
- [ ] Confirm "Host: otel.localhost" appears

**Approach 3: Network capture** (if needed)
- [ ] Use tcpdump or wireshark
- [ ] Capture traffic to otel-collector:4318
- [ ] Verify HTTP headers include Host: otel.localhost

**Validation checklist**:
- [ ] All three exporters have header configured
- [ ] Header key is exactly "Host" (case matters in some languages)
- [ ] Header value is exactly "otel.localhost"
- [ ] No typos (otel.localhost, not otel-localhost or otel_localhost)

**If header is missing → Exporters will fail → Must fix before proceeding**

---

## Success Criteria

**This task is complete when**:

- [ ] All 10 subtasks checked off
- [ ] OTLP packages installed successfully
- [ ] All three exporters implemented (logs, metrics, traces)
- [ ] ALL exporters include `Host: otel.localhost` header
- [ ] Resource attributes configured correctly
- [ ] initOpenTelemetry() function exists and works
- [ ] Test code runs without errors for all three signal types
- [ ] Code compiles/builds successfully

**Do NOT mark complete if**:
- ❌ Any exporter missing `Host: otel.localhost` header
- ❌ Metric attributes use dots instead of underscores
- ❌ Code doesn't compile
- ❌ Test code throws exceptions
- ❌ initOpenTelemetry() function missing

---

## Common Pitfalls

### Pitfall 1: Missing HTTP Header
**Problem**: Forgetting `Host: otel.localhost` in one or more exporters
**Impact**: Traefik routing fails, data doesn't reach backend
**Solution**: Check ALL three exporters, verify header present

### Pitfall 2: Wrong Header Syntax
**Problem**: Using wrong API for headers (from wrong SDK version or language)
**Impact**: Header not sent, routing fails
**Solution**: Copy exact syntax from otel-sdk-comparison.md

### Pitfall 3: Dots in Attributes
**Problem**: Using `peer.service` instead of `peer_service`
**Impact**: Grafana filtering breaks
**Solution**: Use underscores in ALL metric/span attributes

### Pitfall 4: Wrong Endpoints
**Problem**: Using localhost:4318 instead of otel-collector:4318
**Impact**: Works on host, fails in DevContainer
**Solution**: Use `otel-collector:4318` (container hostname)

### Pitfall 5: No Error Handling
**Problem**: Initialization crashes silently
**Impact**: Application fails mysteriously
**Solution**: Add try/catch, log errors clearly

### Pitfall 6: Skipping Tests
**Problem**: "I'll test it later with E2E test"
**Impact**: Discover exporter issues late, harder to debug
**Solution**: Test each exporter as you build it (6.7, 6.8, 6.9)

---

## Validation

**Before marking complete, run**:

```bash
# Code builds successfully
cd [LANGUAGE]
[build-command]

# Run minimal test (if you created one)
[run-test-command]

# Check for Host header in code
grep -r "Host.*otel.localhost" [LANGUAGE]/
# Should find at least 3 occurrences (logs, metrics, traces)

# Check for dots in test attributes (should find NONE)
grep -r "peer\.service" [LANGUAGE]/
grep -r "operation\.name" [LANGUAGE]/
# Both should return empty (use underscores instead)
```

**All checks must pass before claiming completion.**

---

## Reference Documents

- **specification/tools/README.md**: Complete validation tool documentation (CRITICAL)
  - Two-level validation strategy
  - Complete 8-step validation sequence
  - Tool usage examples and troubleshooting
- **specification/06-otel-backend-config.md**: Endpoint URLs and configuration
- **specification/09-development-loop.md**: Development workflow and validation-first principle
- **[LANGUAGE]/llm-work/otel-sdk-comparison.md**: SDK-specific syntax (YOUR research)
- **typescript/src/index.ts**: TypeScript reference implementation

---

## Time Estimate

- Subtask 6.1: 15 minutes (install packages)
- Subtask 6.2: 30 minutes (logs exporter)
- Subtask 6.3: 30 minutes (metrics exporter)
- Subtask 6.4: 30 minutes (traces exporter)
- Subtask 6.5: 15 minutes (resource attributes)
- Subtask 6.6: 30 minutes (initialization function)
- Subtask 6.7: 10 minutes (test logs)
- Subtask 6.8: 10 minutes (test metrics)
- Subtask 6.9: 10 minutes (test traces)
- Subtask 6.10: 20 minutes (verify headers)

**Total**: ~3 hours

---

## Next Steps

After completing this task:
- Task 7: Implement file logging (separate from OTLP)
- Task 8: Implement the 8 API functions (uses these exporters)

**Parent task**: Return to ROADMAP.md when complete
