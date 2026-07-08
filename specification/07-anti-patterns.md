# Anti-Patterns

## Purpose

This document lists common mistakes discovered during sovdev-logger development. Following these patterns ensures consistent behavior across all language implementations. Compressed into a table per [PLAN-003](../../website/docs/ai-developer/plans/backlog/PLAN-003-spec-scaffolding-cleanup.md) — the pattern content itself is unchanged, only the format is (previously: ~50 lines of prose/code-example per row, now: one row per pattern). The original bad/correct code examples and full "why this matters" prose are in this file's git history (pre-2026-07-08 commits) if a specific one is ever needed.

"Current status" below reflects the state of `python/src/logger.py` and `typescript/src/logger.ts` as of 2026-07-08, re-verified against the code while writing this table — not carried forward from when each pattern was first documented.

---

## Code Anti-Patterns

| # | Don't | Do Instead | Current Status |
|---|---|---|---|
| 1 | Use the internal module name (`__name__`, `module.exports` path) for `scope_name` | Use the service name passed to `sovdev_initialize()` | Fixed in both — Python: `logging.getLogger(service_name)`; TypeScript: `logs.getLogger(options.serviceName, ...)` |
| 2 | Use the language's native exception type name (`ValueError`, `HTTPError`, ...) for `exception_type` | Always emit `"Error"`, regardless of the actual exception class — keeps cross-language Grafana alerts language-independent | Python: correct, hardcoded `"Error"` (`logger.py:409`). **TypeScript is not fully correct**: `exception_type: clean_exception.constructor?.name \|\| clean_exception.name \|\| 'Error'` (`logger.ts:481`) only resolves to `"Error"` for a plain `Error` instance — a custom subclass (`class HTTPError extends Error`) would leak its class name. Not fixed here (doc-only plan); flagged for a future fix. |
| 3 | Nest objects in log entries (`log_entry.exception = {...}`) | Flatten everything to root-level, prefixed field names (`exception_type`, `http_status_code`, ...) — OTLP/Loki/Prometheus require flat structure | Fixed in both — confirmed by `compare-with-master.sh` matching field-for-field |
| 4 | Include unredacted credentials in stack traces, or truncate *before* redacting (redaction can't remove what's already cut off) | Redact first (`Authorization`, `Bearer`, API keys, passwords, JWTs, session IDs, cookies), truncate to 350 chars second | **Python is more thorough than TypeScript.** Python: full regex-based redaction of all 7 categories above (`logger.py:301-334`), then truncates. TypeScript: only strips `config.auth`/`config.headers.Authorization` from axios-shaped error objects (`logger.ts:460-467`) — no generic regex redaction of the stack trace text itself. Not fixed here; flagged for a future fix since TypeScript is the reference implementation. |
| 5 | Generate a new `traceId` for each log call within one logical transaction | Generate once per transaction (typically via `sovdev_start_span()`), reuse for every related log | By design in both — trace ID comes from the active span, not a per-call generator |
| 6 | Exit without calling `sovdev_flush()` | Always flush before exit, including on error paths and signal handlers (SIGINT/SIGTERM) — OTel batches logs, the final batch is only sent on flush | Usage pattern, not a library guarantee — confirmed followed by both E2E test scripts (`company-lookup.ts`/`.py` call `sovdev_flush()` at the end of `main()`) |
| 7 | Generate a new `sessionId` per function call | Generate once in `sovdev_initialize()`, reuse for the entire process lifetime | Fixed in both — `logger.py:814`, `logger.ts:1315`, both generate once at initialize |
| 8 | Define `input`/`response` objects inline at each `sovdev_log()` call site | Define once as a variable, reuse across the request/response/error logs for that operation | Usage pattern — confirmed followed in both E2E test scripts |
| 9 | Hardcode the function name as a string literal at every log call | Define a `FUNCTIONNAME` constant once per function | Usage pattern — confirmed followed in both E2E test scripts |
| 10 | Skip file rotation configuration (unbounded log growth) | Configure rotation: main log 50MB × 5 files (~250MB), error log 10MB × 3 files (~30MB) | Fixed identically in both — `logger.py:245-262`, `logger.ts:291-310` |
| 11 | Implement custom file writing/rotation from scratch | Use an established logging library (handles locking, buffering, atomicity) | Fixed in both — Python: stdlib `logging` + `RotatingFileHandler`; TypeScript: Winston |

**Required libraries by language** (item 11, for languages not yet implemented):

| Language | Library |
|---|---|
| Go | `zap` or `logrus` + `lumberjack` |
| Java | `SLF4J` + `Logback` or `Log4j2` |
| C# | `Serilog` or `NLog` |
| PHP | `Monolog` |
| Rust | `tracing` or `log` + `env_logger` |

## Implementation Process Pitfalls

Discovered during the original Python implementation attempt; kept as a table since they're process lessons, not code rules to check off.

| # | Don't | Do Instead | Current Status |
|---|---|---|---|
| 12 | Assume metric names need dots (`sovdev.operations.total`) sanitized to underscores manually | — | **This pitfall no longer holds as documented.** TypeScript emits OTel-conventional dot-separated names at the SDK level (`sovdev.operations.total`, `logger.ts:752-767`); Python hardcodes underscores directly (`sovdev_operations_total`, `logger.py:86-104`). Both currently resolve to underscore names in Prometheus — confirmed by `specification/tools/query-prometheus.sh`'s own default metric name being the underscore form — because the OTel Collector's Prometheus exporter sanitizes dots automatically. The original 30-minute debugging incident this documents likely predates that sanitizing step being in place, or came from a different export path. Neither implementation currently fails because of this. |
| 13 | Convert an enum to string with `str()`/`.toString()` (returns the enum *name*, e.g. `"SOVDEV_LOGLEVELS.ERROR"`, not its *value*) | Use `.value` (Python) / the string literal directly (TypeScript) | Fixed — Python uses `level.value` throughout (`logger.py:909` and others); this was the one historically-documented bug PLAN-001's file-log comparison could actually catch, and it's confirmed still fixed |
| 14 | Omit `severity_text`/`severity_number` needed by Grafana's error panel | Ensure the OTel log record carries both | Handled differently in both, neither is missing it: TypeScript sets `severityNumber`/`severityText` explicitly via a manual level map (`logger.ts:159-165, 219-220`); Python has no equivalent code at all because it relies on the OTel SDK's own `LoggingHandler` bridge, which derives severity from the stdlib logging level automatically — that's the idiomatic way to do it for that SDK, not a gap. |
| 15 | Spend time debugging `kubectl` connectivity when validating | Use the `query-grafana-*.sh` scripts (Grafana API, always available) instead of `query-*.sh` (direct kubectl, optional) | Process guidance, not a code pattern — no current-status check applies |

---

**Document Status:** ✅ v2.0.0 — compressed into tables 2026-07-08, technical content unchanged, verified against current code
**Part of:** sovdev-logger specification
