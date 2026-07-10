# Investigate: How sovdev-logger provides continuous telemetry export in a long-running server

`INVESTIGATE-ollacrm-onboarding.md`'s "flush gap" turned out to be deeper than a documentation gap. TypeScript's `sovdev_flush()` is a one-time, shutdown-coupled operation that silently diverges from Python's own `sovdev_flush()` — and Cloud Run's default CPU throttling between requests makes that divergence matter in practice, not just in theory. This investigation is scoped narrowly to that: what should "flush" mean in a process that never ends, and how does sovdev-logger get there without breaking the script-shaped callers that already exist.

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Resolved — shipped

**Child plan**: [PLAN-long-running-server-flush.md](PLAN-long-running-server-flush.md) — DONE, all 4 phases complete.

**Goal**: A safe way for a long-running server to protect recent telemetry against an ungraceful crash, without risking silently disabling all future logging in that process — and without breaking any existing script-shaped caller.

**Non-negotiable constraint (maintainer):** sovdev-logger's steady-state design — `sovdev_log()` queues instantly, a background timer does the actual network export — already satisfies "streams data, doesn't slow down the code." Nothing in this fix should introduce a blocking flush into any request/error path. The fix is about what happens in the rare case flush gets called more than once (shutdown, restart, defensive re-flush), not about changing the hot path.

**Last Updated**: 2026-07-10

**Outcome**: Split `sovdev_flush()` (now force-flush-only, safe to call any number of times, in both TypeScript and Python — matching Python's original behavior) from a new `sovdev_shutdown()` (force-flush then terminate, call exactly once, added to both languages). Empirically re-verified the fix: a 3-cycle log/flush/log/flush/log/flush/shutdown test against local UIS now shows all 3 log markers **and** all 3 metric increments reaching the backend (previously stuck at 1 metric after 2 log calls). Both languages' E2E tests pass `compare-with-master.sh` clean, and both exit naturally (no hang) via the new `sovdev_shutdown()` call. Updated both READMEs, both onboarding docs, and — found necessary mid-implementation, not originally scoped — the full `contributor/*.md` API contract and spec docs, since those are what a future Go/C#/Rust/PHP port would read and could otherwise copy the old, buggy contract from.

---

## The core finding: TypeScript's `sovdev_flush()` is not what Python's `sovdev_flush()` is

Checked both implementations directly, not assumed:

**TypeScript** (`typescript/src/logger.ts:1712-1751`, `flush_sovdev_logs`):
```typescript
await globalTracerProvider.forceFlush();
await globalMeterProvider.forceFlush();
await globalLoggerProvider.forceFlush();
await otelSDK.shutdown();
await globalTracerProvider.shutdown();
await globalMeterProvider.shutdown();
```
Force-flushes, then **shuts down the SDK and every provider**. None of the shut-down globals (`otelSDK`, `globalTracerProvider`, `globalMeterProvider`, `globalLoggerProvider`) get reset to `null`/`undefined` afterward. `initialize_sovdev_logger`'s `if (!otelSDK)` guard means a subsequent `sovdev_initialize()` call is a silent no-op against the already-shut-down SDK. The public docstring says exactly what this is for: "before app exit."

**Python** (`python/src/logger.py:1058-1084`, `sovdev_flush`):
```python
global_tracer_provider.force_flush()
global_meter_provider.force_flush()
global_logger_provider.force_flush()
for handler in otel_logging_handlers:
    handler.flush()
```
Force-flushes only. **No shutdown call anywhere in the function.** Its own docstring: "Safe to call from signal handlers and atexit hooks" — a repeatable, mid-process-safe operation by design.

This is a genuine cross-language behavioral divergence of exactly the class this project has fixed before (dots-vs-underscores metric names, `str(enum)` vs `.value`, a missing field) — except this time it's a whole function's safety contract that differs, not a field value.

### Empirically verified — and the real result is more precise (and more dangerous) than expected

**[Q1] answered.** Built a small standalone script (`sovdev_initialize` → log "MARKER-BEFORE-FIRST-FLUSH" → `sovdev_flush()` → log "MARKER-AFTER-FIRST-FLUSH" → `sovdev_flush()` again) and ran it against local UIS, then queried Loki and Prometheus directly for the actual result — not inferred from console output, which claimed success at every step regardless.

- **Logs: both messages arrived.** `query-loki.sh` found 2 entries, both markers present, confirmed via raw JSON (`MARKER-BEFORE-FIRST-FLUSH` and `MARKER-AFTER-FIRST-FLUSH` both present with distinct timestamps 96ms apart). The second `sovdev_log()` call, made after the first `sovdev_flush()`'s `.shutdown()`, did not throw and its data did reach the backend.
- **Metrics: only the first increment survived.** `query-prometheus.sh --json` on `sovdev_operations_total` for this test service returns `"value": [..., "1"]` — a raw count of **1**, despite two `sovdev_log()` calls that should each increment the counter once. The second increment was silently lost: no error, no warning, nothing in the console output (which reported "OpenTelemetry metrics flushed successfully" on *both* flush calls).

**This is a more dangerous finding than the original hypothesis of "everything breaks after the first flush."** A total, obvious failure (calling `sovdev_log()` a second time throws, or every subsequent log visibly vanishes) would be caught immediately by whoever hit it. What was actually found is a **silent, signal-specific partial failure**: logs keep flowing, giving every appearance that logging still works fine after a flush — while metrics quietly stop being recorded, with no indication anything is wrong. A server that (against current guidance) called `sovdev_flush()` more than once would see its error logs continue to show up in Loki — building false confidence — while its error-rate metrics and any dashboard alerting built on them silently went stale.

This was tested as one short, immediate double-flush cycle in a single process with no real load — not across a longer time gap, concurrent requests, or repeated flush cycles. The result should be read as "confirmed present in the simplest case," not "fully characterized in every case."

## Why this matters now, not hypothetically

- `ollacrm` (Cloud Run, a persistent Hono server) is the first real, long-running consumer sovdev-logger has ever had outside its own short-lived E2E test.
- Cloud Run's **default** CPU allocation (request-based billing — confirmed via `ollacrm`'s actual deploy command, no `--no-cpu-throttling` flag present) throttles background timers between requests. OTel's batch processors use exactly this kind of timer (`setInterval`) for their periodic export — confirmed via Google's own documentation and community reports (see `INVESTIGATE-ollacrm-onboarding.md`'s research for full sourcing).
- Consequence: the one situation where you'd most want to *guarantee* telemetry reaches the backend — right after logging an `ERROR`, in case the process crashes next — has no safe mechanism today. Calling `sovdev_flush()` there wouldn't lose the log itself (confirmed: logs kept working after a prior flush), but it would silently stop that error from ever incrementing `sovdev_errors_total` again — the exact metric an alert or dashboard would be watching. The failure mode isn't "logging breaks," it's "your error-rate graph quietly goes flat while the actual errors keep showing up in the logs panel right next to it."
- Any future language port that copies TypeScript's shutdown-coupled implementation (rather than Python's) inherits the same trap. Nothing currently documents that these two `sovdev_flush()`s behave differently, so there's no reason a new port would know to prefer Python's shape over TypeScript's.

## A real constraint on the fix: TypeScript's own E2E test relies on the shutdown side effect

Checked `typescript/test/e2e/company-lookup/company-lookup.ts` directly. Its `main()` function's success path has **no explicit `process.exit()`** — it just returns after `await sovdev_flush()`, relying on Node exiting naturally once no handles/timers remain active. That only works *because* `sovdev_flush()`'s `.shutdown()` calls clear the batch processors' internal timers. The failure path (`main().catch(...)`) does call `process.exit(1)` explicitly — likely added defensively, possibly for exactly this reason on a path that hits `catch`.

This means simply removing `.shutdown()` from TypeScript's `flush_sovdev_logs()` would make the *existing, currently-passing* E2E test's success path **hang forever** — a real regression, not a hypothetical one. Any fix has to account for this, either by requiring an explicit `process.exit()` after flush everywhere (a breaking change to the implicit script contract) or by not touching the existing function at all.

---

## Options

### Option A: Make TypeScript's `sovdev_flush()` match Python's (force-flush only, no shutdown)

Remove the `.shutdown()` calls from `flush_sovdev_logs()`, keeping only the `.forceFlush()` calls already there.

**Pros**: direct conformance fix — brings TypeScript in line with Python's actual, already-shipped behavior; makes `sovdev_flush()` genuinely safe to call repeatedly, unlocking a real "flush after logging an ERROR" pattern for servers; closes the confirmed silent-metrics-loss risk rather than just documenting it (logs already survive a repeat flush today, but metrics don't — see the empirical finding above).
**Cons**: **confirmed regression risk**, not just a theoretical one — the existing E2E test's success path hangs forever without `.shutdown()`'s timer cleanup, per the finding above. Fixing this requires either adding an explicit `process.exit()` to every existing script-shaped caller (a breaking change to an implicit contract nothing currently documents) or accepting that short scripts now need one more line than before.

### Option B: Add a new, additive function — leave `sovdev_flush()` exactly as it is

Keep `sovdev_flush()`'s current shutdown-coupled behavior untouched (matches its docstring, doesn't disturb the E2E test or any other existing script-shaped caller). Add a second function — e.g. `sovdev_force_export()` — that only force-flushes, mirroring what Python's `sovdev_flush()` already does, safe to call repeatedly.

**Pros**: zero regression risk to any existing caller; purely additive, no version-compatibility concern; gives servers exactly the safe, repeatable primitive they need without touching the script-shaped contract at all.
**Cons**: TypeScript now has two flush-shaped functions with different names and different safety contracts unless Python also gets the new function added to match — more API surface to keep in sync across every future language port; slightly muddies the "one function to call" simplicity the API has today; still leaves TypeScript's `sovdev_flush()` and Python's `sovdev_flush()` genuinely different, just under a name that (per the finding above) already means two different things across languages today — this option doesn't resolve that divergence, it works around it.

### Option C: Documentation-only — no library change

Leave `sovdev_flush()` exactly as-is in both languages (i.e., accept that they already differ). Document the TypeScript behavior precisely (call once, at true process end, never in a live request path) and rely on infrastructure-level mitigation (Cloud Run's always-on CPU) for servers that want tighter guarantees.

**Pros**: zero library code risk.
**Cons**: leaves a confirmed, real cross-language divergence unresolved (verified empirically, not hypothetical) — TypeScript servers that ever call `sovdev_flush()` more than once silently lose every metric increment after the first call, with no error and no warning, while their logs keep working normally right next to the now-wrong numbers; the exact kind of silent-until-it-bites-someone inconsistency this project has treated as a real bug every other time it's been found.

### Option D: Split into two functions — `sovdev_flush()` (repeatable) + `sovdev_shutdown()` (terminal) — **decided**

Neither A nor B alone was right. A's regression (E2E test hangs) is real, and B leaves the actual cross-language divergence in place under a workaround. The better shape: make `sovdev_flush()` force-flush-only in TypeScript (fixing the divergence at the root — it now means the same thing Python's already does), and add a **new** `sovdev_shutdown()` in both languages for the one thing that actually needs a terminal call: the E2E test (and any future script) calls `sovdev_shutdown()` once, at the very end, instead of relying on `sovdev_flush()`'s side effect.

**Pros**: fixes the cross-language divergence directly (not a workaround); `sovdev_flush()` becomes genuinely safe to call any number of times, in both languages, meaning the same thing in both; the E2E test's timer-cleanup need is preserved, just under an explicit, correctly-named call instead of a side effect of a differently-named function; every future language port gets one clear contract — "flush freely, shut down once" — instead of having to reverse-engineer which existing language's shape to copy.
**Cons**: touches a public function's documented behavior in TypeScript (see [Q5] on versioning) and adds one new exported function per language; every script-shaped caller (the E2E tests, any documentation examples) needs updating to call the new function at the true end instead of `sovdev_flush()`.

---

## Recommendation

**Option D**, per maintainer decision — given a hard requirement that the steady-state logging path never gets slower (see the Goal section's constraint): this doesn't touch the hot path at all. `sovdev_log()` keeps queuing instantly, background timers keep doing the real export, exactly as today. This is entirely about what happens in the rare case flush gets called more than once — closing the confirmed silent-metrics-loss bug without ever tempting anyone into a per-request or per-error flush (which would be the actual latency risk, regardless of which option shipped here).

---

## Open Questions — all decided

1. **[Q1]** — **Answered.** Logs survive a repeat `sovdev_flush()` call; metrics silently don't (confirmed via real Loki/Prometheus queries against local UIS, see above). Not a total-failure divergence — a silent, metrics-specific one.
2. **[Q2]** — **Decided: Option D**, the flush/shutdown split — see above, not A or B as originally framed.
3. **[Q3]** — **Decided.** Python gets a new, mirrored `sovdev_shutdown()` too, for API symmetry — even though Python's existing `sovdev_flush()` already behaves safely without it (no shutdown call to begin with), so this is about a consistent contract across languages, not fixing a bug in Python.
4. **[Q4]** — **Decided: doesn't block.** `ollacrm` ships with the documented initialize-once/flush-on-`SIGTERM` pattern now; once Option D lands, the only change at its `SIGTERM` handler is swapping `sovdev_flush()` for `sovdev_shutdown()` — a one-line doc update, not a re-architecture.
5. **[Q5]** — **Decided: yes, a changelog note.** Adding `sovdev_shutdown()` is additive; changing what `sovdev_flush()` does in TypeScript is a real behavioral change to existing public API and deserves an explicit note, even this early in the package's life.

## Next Steps

- [x] Verify [Q1] empirically — done, see the finding above
- [x] Maintainer decides [Q2]–[Q5] — done, see above
- [x] Implement per [`PLAN-long-running-server-flush.md`](PLAN-long-running-server-flush.md) — done, all 4 phases
- [ ] Resume [`INVESTIGATE-ollacrm-onboarding.md`](../backlog/INVESTIGATE-ollacrm-onboarding.md) — its own worked example already uses the new `sovdev_shutdown()`; still Parked pending the maintainer's Grafana Cloud credential steps, unrelated to this fix
