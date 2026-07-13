---
mdx:
  format: md
---

# Plan: Build the self-test CLI (write, read back, report)

Ships `sovdev-selftest` as a bundled `bin` entry inside `@terchris/sovdev-logger` — writes a uniquely-marked log and metric, reads both back over plain HTTP against either Grafana Cloud or local UIS, and reports a clear four-signal PASS/FAIL.

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Completed

**Investigation**: [INVESTIGATE-selftest-cli.md](INVESTIGATE-selftest-cli.md) — Option A, all design questions ([Q1]-[Q8]) decided

**Goal**: `npx sovdev-selftest --backend grafana-cloud|uis` initializes sovdev-logger, emits one uniquely-marked log + metric under a disposable `<service_name>-selftest` name, polls Loki and Prometheus (via each backend's own plain-HTTP query API) until both show up or a timeout is reached, and prints a four-line PASS/FAIL report (plain text by default, `--json` for CI) with a real exit code.

**Completed**: 2026-07-13 — all 5 phases done, validated end-to-end against real Grafana Cloud and UIS backends, and against a real `npm pack` → fresh install → `npx` round-trip. Two real bugs found and fixed during implementation (a URL-joining bug that would have silently broken every UIS query, and a `--json`-mode console-noise bug that would have broken CI's `JSON.parse(stdout)`). One item explicitly deferred as a tracked follow-up, not blocking this completion — see Phase 5.4.

---

## Problem Summary

See `INVESTIGATE-selftest-cli.md` for the full research. In short: no existing tool does the full write→read-back cycle in one invocation against either backend, and — checked directly against vendor tooling — no observability vendor bundles this either (Sentry's live-polling page depends on true multi-tenancy sovdev-logger doesn't have; everyone else ships separate, separately-installed query CLIs). This plan builds it as a native TypeScript layer: one shared HTTP query client (generalized from `tools/validation/grafana-cloud/lib/grafana-cloud-client.ts`), reaching Grafana Cloud directly and UIS through Grafana's own datasource-proxy API (`grafana.localhost/api/datasources/proxy/uid/<uid>/...` — confirmed live this session, no `kubectl` required for either backend).

---

## Phase 1: Generalize the shared query client into the published package — DONE

The existing `grafanaCloudQuery()` in `tools/validation/grafana-cloud/lib/grafana-cloud-client.ts` lives in a tooling-only workspace, never published to npm. The self-test CLI ships inside `@terchris/sovdev-logger` itself, so its query logic needs to live in `typescript/src/`, not `tools/`.

### Tasks

- [x] 1.1 Create `typescript/src/cli/query-client.ts` — a generalized version of `grafanaCloudQuery()`: same GET-with-Basic-Auth-and-throw-on-non-2xx shape, but the credential parameter is a generic `{user: string; pass: string}` pair (Grafana Cloud passes `instanceId`/`token` into it; UIS passes `username`/`password`) — the two are structurally identical (both are HTTP Basic Auth), only the field names differ per backend, matching [Q2]'s decided backend-specific config types.
- [x] 1.2 Define the two backend config types per [Q2]:
  ```typescript
  interface GrafanaCloudSelftestConfig {
    lokiUrl: string; lokiInstanceId: string;
    prometheusUrl: string; prometheusInstanceId: string;
    ingestToken: string;  // write
    verifyToken: string;  // read — separate credential, not the write token
    otlpEndpoint: string; otlpInstanceId: string;
  }
  interface UisSelftestConfig {
    grafanaUrl: string; username: string; password: string;
  }
  ```
- [x] 1.3 Define the concrete env vars each config type resolves from:
  - Grafana Cloud: reuse the **existing, already-provisioned** vars from `tools/validation/grafana-cloud/.env.example` exactly as named — `GRAFANA_CLOUD_INGEST_TOKEN`, `GRAFANA_CLOUD_VERIFY_TOKEN`, `GRAFANA_CLOUD_OTLP_ENDPOINT`, `GRAFANA_CLOUD_OTLP_INSTANCE_ID`, `GRAFANA_CLOUD_LOKI_URL`, `GRAFANA_CLOUD_LOKI_INSTANCE_ID`, `GRAFANA_CLOUD_PROMETHEUS_URL`, `GRAFANA_CLOUD_PROMETHEUS_INSTANCE_ID`. No new Access Policy needed for this first version — `GRAFANA_CLOUD_VERIFY_TOKEN` is the same unscoped, stack-wide read credential the existing query tooling already uses. **Not suitable to hand to an external consumer like ollacrm as-is** (unscoped read sees every onboarded system's data) — minting ollacrm their own LBAC-scoped, per-system read policy is explicitly deferred, tracked as a follow-up, not a blocker for this plan.
  - UIS: `GRAFANA_URL`, `GRAFANA_USER`, `GRAFANA_PASSWORD` (matching `tools/dashboards/push-dashboard.ts`'s existing convention exactly).
- [x] 1.4 Build the UIS query path as a thin wrapper: `${grafanaUrl}/api/datasources/proxy/uid/<loki|prometheus>/<native-path>`, reusing the same `query-client.ts` function with the datasource-proxy prefix baked into the base URL. **Found and fixed a real bug during validation**: `new URL(path, baseUrl)` treats a leading-slash path as absolute, silently discarding `baseUrl`'s own path segment — fatal for UIS's proxy URLs, which have a real path prefix (`/api/datasources/proxy/uid/<uid>`). Fixed in `query-client.ts` by appending to the existing pathname instead of replacing it.

### Validation

Unit test (or a quick manual script) hitting both a live Grafana Cloud instance and local UIS with the generalized client, confirming both return real data — same shape of check already done manually in the investigation.

**Done.** A temporary validation script (not committed) confirmed real Loki and Prometheus data back from both Grafana Cloud and local UIS through the shared `queryWithBasicAuth()` client — including catching and fixing the URL-joining bug above before it could hide inside the actual CLI.

---

## Phase 2: Backend selection and config resolution

### Tasks

- [ ] 2.1 Implement `--backend grafana-cloud|uis` flag parsing using Node's built-in `util.parseArgs` (no new dependency — the package has none for CLI parsing today, and this is a two-flag surface: `--backend` and `--json`).
- [x] 2.2 Auto-detect fallback per [Q1]: if `--backend` isn't given, check which config's env vars are present; if both are present, fail fast with a message asking for an explicit `--backend` (the maintainer's own dual-backend devcontainer case); if neither is present, fail fast listing which vars are missing for each backend. Built as `resolveSelftestConfig()` in `backend-config.ts` (landed alongside Phase 1's config types, since the two were naturally the same unit of work).
- [x] 2.3 Resolve the chosen backend's config (Phase 1's types), erroring immediately with a specific missing-var message if the explicitly-requested backend's own vars aren't fully present.
- [ ] 2.1 Implement `--backend grafana-cloud|uis` / `--json` argv parsing using Node's built-in `util.parseArgs` (no new dependency) — the actual CLI entry point calling `resolveSelftestConfig()`, not yet written. Remaining task for this phase.

### Validation

Manual run with: only Grafana Cloud vars set (should auto-select); only UIS vars set (should auto-select); both set with no flag (should error asking for `--backend`); both set with `--backend uis` (should select UIS); neither set (should list missing vars for both).

**2.2/2.3 done** — confirmed via the same temporary validation script: explicit `'grafana-cloud'`/`'uis'` resolve correctly, and calling `resolveSelftestConfig()` with both backends' env vars present correctly throws asking for an explicit `--backend`. 2.1 (real argv parsing) remains — needs the actual `selftest.ts` entry point, not just the resolver function.

---

## Phase 3: Write step — DONE

### Tasks

- [x] 3.1 Call `sovdev_initialize()` with a disposable service name: `${OTEL_SERVICE_NAME}-selftest` — per [Q3]'s decided disposable-name convention. Built as `selftestServiceName()` in `typescript/src/cli/write-step.ts`.
- [x] 3.2 Call `sovdev_log()` once with a marker message (any fixed, greppable string is enough — per [Q8], the disposable service_name is what actually identifies this run, not the message content). Built as `writeSelftestMarker()`.
- [x] 3.3 Call `sovdev_shutdown()` to force-flush and tear down, per this project's own established flush/shutdown split.

### Validation

Confirm via existing query tooling (`tools/validation/grafana-cloud/query-loki.ts` or local UIS query) that the write actually lands, before building the read side on top of it.

**Done.** Wrote a real marker via `writeSelftestMarker()` against local UIS, then read it back with Phase 1/2's `queryLoki()` — confirmed the full log entry landed with the correct schema (`log_type: "transaction"`, `function_name: "sovdev-selftest"`, correct disposable `service_name`). Along the way, confirmed `peer_service: 'INTERNAL'` correctly resolves to the service's own name in the stored log (existing, documented library behavior at `logger.ts:376-377`, not something this plan needed to handle). One thing worth remembering for Phase 4: Loki's `query_range` needs an explicit `start`/`end` — omitting it (as a first pass at this validation did) silently returns zero results, not an error.

---

## Phase 4: Read step — poll with backoff, four-signal report — DONE

### Tasks

- [x] 4.1 Implement poll-with-backoff per [Q4]: query every 2s, timeout at 30s for the log, 60s for the metric — two independent timeout clocks, not one shared one (metrics lag further behind than logs). Built as `pollForSignal()` in `typescript/src/cli/poll.ts`.
- [x] 4.2 Distinguish a timeout ("may still arrive — try again shortly") from a hard failure (non-2xx response, e.g. wrong credential or endpoint) in the message — a query that *throws* is reported immediately, without waiting out the rest of the timeout; only an empty-but-successful query keeps polling until the deadline.
- [x] 4.3 Report four independent lines per [Q6]: write-log, write-metric, read-log, read-metric — each with its own pass/fail and a specific diagnostic on failure. Built as `report()`/`reportPlainText()`/`reportJson()` in `typescript/src/cli/report.ts`, tied together in `typescript/src/cli/selftest.ts` (also completes Phase 2's remaining task 2.1 — `util.parseArgs` for `--backend`/`--json`/`--service-name`/`--help`).
- [x] 4.4 Plain text output by default; `--json` flag emits the same four signals as a structured object instead.
- [x] 4.5 Exit code 0 only if all four signals pass, 1 otherwise.

### Validation

Full end-to-end run against both real backends (Grafana Cloud and local UIS), confirming both the human-readable and `--json` output modes, and confirming a deliberately-broken credential produces the specific diagnostic, not a stack trace.

**Done, against real UIS** (Grafana Cloud already proven in Phases 1–3; the read/poll logic is backend-agnostic by construction). All four signals pass on a clean run; a deliberately wrong `GRAFANA_PASSWORD` immediately produces `401 Unauthorized` on both read signals (not a 30s/60s wait), exit code 1 confirmed directly (not through a pipe, which reports its own exit code).

**Found and fixed a real gap in [Q6]'s "CI parsing" requirement**: `sovdev_initialize()`/`sovdev_shutdown()` print their own diagnostic `console.log`/`console.warn` lines (session ID, OTLP setup/teardown) — these polluted `--json` mode's stdout with non-JSON lines, which would break a CI script's `JSON.parse(stdout)`. Fixed by suppressing `console.log`/`console.warn` around the write step specifically when `--json` is passed (`withSuppressedConsole()` in `selftest.ts`) — confirmed stdout is now a single, valid, parseable JSON line with nothing else in it.

**Two more real findings from actual usage, after this plan was first marked done** (real dogfooding in the devcontainer against Grafana Cloud, not something either of the two rounds of local validation above had caught):

- **`detail: 'found'`/`'sent'` wasn't actually useful** — the maintainer pointed out the report didn't show *what* was written or read back, only that something was. Fixed: `pollForSignal()`'s callback changed from a boolean `foundCheck` to a `string | null` `extractDetail`, so a passing `read-log`/`read-metric` now shows the actual marker message + timestamp, or the actual metric value + timestamp (checked directly against real Loki/Prometheus response shapes first — the message lives in Loki's `values[0][1]`, not the stream labels; the metric value is in Prometheus's `value[1]`, with a Unix-seconds timestamp in `value[0]`, not nanoseconds like Loki's). `write-log`/`write-metric` similarly now show the marker message and disposable `service_name` used, not just "sent".
- **A second `--json`-mode stdout-noise source**, found only by running against an environment with `LOG_TO_CONSOLE=true` set (inherited from sourcing `test/e2e/company-lookup/.env.grafana-cloud`, a real combination neither round of local validation had tried) — sovdev-logger's own Winston console transport prints the marker log line itself, a real application log line, not an SDK diagnostic, so the existing `console.log`/`console.warn` override didn't catch it (Winston's transport doesn't go through the global `console.log` this override replaces). Fixed by also forcing `process.env.LOG_TO_CONSOLE = 'false'` for the duration of the write step in `--json` mode, restored afterward. Confirmed clean, valid JSON with this env var set, not just without it.

**Two more rounds of real feedback, same dogfooding session**:

- **No version identification** — nothing printed which tool/version was even running before `sovdev_initialize()`'s own "🔑 Session ID" line took over the screen. Fixed: a version banner (`sovdev-selftest v1.0.2 (@terchris/sovdev-logger)`), read from this package's own `package.json` (resolved via `__dirname`, not `process.cwd()` — a different question than `logger.ts`'s existing `getServiceVersion()`, which intentionally reads the *consuming app's* version, not the library's own), printed as the literal first line of `main()`.
- **Reporting "sent"/"found" only in the final summary read as retrospective, not trustworthy** — the maintainer's own words: "just saying at the end that you did it is not trustworthy." Fixed: real-time progress lines announced before and after each step (`Sending log "..." ...` → `Sent.` → `Reading back the log (polling up to 30s) ...` → `Found: ...`), not just a summary after everything (including up to ~90s of polling) has already finished.
- Both the version banner and the progress lines print to **stderr** via `console.error`, not `console.log` — deliberately, so they're always visible on screen but never part of the stdout stream `--json` mode's CI consumers parse as JSON. Confirmed stdout stays pure, valid JSON with both features active.

**A third round, catching a real perf bug the maintainer noticed just from watching the output**: the version banner wasn't actually the first thing that happened — the maintainer noticed "some ms" passed before it printed and asked whether it really was first. Measured directly, not dismissed: `require('./dist/index.js')` (the full `@opentelemetry/*` SDK chain) takes **~434ms** to load. `write-step.ts` (which needs that whole chain) was a top-level `import` in `selftest.ts`, so Node resolved and ran all 434ms of it before `main()` — and the banner — ever executed, even for `--help`, which never uses any of it. Fixed by moving `write-step.ts`'s import to a dynamic `await import('./write-step.js')`, placed after arg parsing and config validation succeed (so invalid input still exits fast) but before the write step actually needs it. Confirmed: `--help` dropped from paying the full ~434ms tax to **40ms total** (measured with `time -p`), and the banner now genuinely prints before any heavy work starts, confirmed by output ordering (banner → "Sending log..." → *then* `sovdev_initialize()`'s own "🔑 Session ID" line).

**A fourth round, on output structure rather than timing or content**: even with the ordering fixed, the maintainer found the output genuinely hard to read — `sovdev_initialize()`/`sovdev_log()`/`sovdev_shutdown()`'s own verbose diagnostic lines (session ID, OTLP setup, flush/shutdown progress, ~20 lines) are interleaved with the CLI's own progress lines with no visual boundary marking where one ends and the other begins. Fixed with explicit `=== Test starting ===` / `=== Test finished ===` markers bracketing the entire write+read sequence (both the CLI's own lines and the library's own verbose output land inside this one clearly-delimited block) — not an attempt to separate "library init" from "the test" as two different phases (they're not separable; `sovdev_initialize()`'s setup and `sovdev_log()`'s actual write happen inside one sequential library call), but a single, honest boundary around "everything that happens during the actual test," distinct from the version banner before it and the final summary report after it.

**A fifth round, catching a genuine ordering bug the markers alone hadn't fixed**: the maintainer asked for timestamps on every CLI-owned line (so real ordering is verifiable, not just asserted) and pointed out that `📊 OTLP Metrics configured for...` still appeared to come *after* `Sending log "..."` — backwards, since configuring the exporters should logically happen before anything sends. Checked directly, this was real: the CLI printed one "Sending log..." announcement in `selftest.ts` *before* calling `writeSelftestMarker()`, but `sovdev_initialize()` (which is what actually prints the OTLP-configured lines) only runs *inside* that function, several lines of setup before any log is queued. Fixed properly, not just reworded: moved progress announcements *into* `write-step.ts` itself, interleaved between the three real library calls in their actual order — `logProgress('Initializing sovdev-logger (configures the OTLP exporters) ...')` before `sovdev_initialize()`, `logProgress('Queuing marker log ...')` before `sovdev_log()`, `logProgress('Flushing and shutting down -- this is when the queued data actually gets sent ...')` before `sovdev_shutdown()`. Added a small shared `progress.ts` module (`logProgress()`, ISO-timestamp-prefixed, to stderr) used by both `selftest.ts` and `write-step.ts` so every CLI-owned line — banner, markers, and now these three — carries a timestamp. Confirmed via a real run: `Initializing sovdev-logger ...` now genuinely prints before `📊 OTLP Metrics configured for...`, not after.

**A sixth round, prompted by a standing principle rather than one specific complaint**: even after the fifth round's fix, the maintainer pointed out two remaining gaps — no explicit line marking init as finished before queuing starts, and "this still gives me absolutely NO idea what you are sending" — then stated the underlying design principle directly: *"if you are going to make a program that validates something, then you must be trustworthy. and to be trustworthy you must say exactly what you are doing so that i can verify what you claim yourself."* Two changes, both aimed at literal verifiability rather than better wording:
1. `write-step.ts` now logs `logProgress('Initialization complete.')` right after `sovdev_initialize()` returns, and spells out the *literal* `sovdev_log()` argument list about to be used — `sovdev_log(level=INFO, function_name=sovdev-selftest, message="...", peer_service=..., input_json=null, response_json=null, exception_object=null)` — including the three `null` arguments, since hiding those by omission would be its own small dishonesty.
2. `query-client.ts`'s `queryWithBasicAuth()` now logs `Querying: GET <url>` immediately before firing each request, using the *same* `url` variable the real `fetch()` call uses — not a string reconstructed separately for display, which could silently drift from the real request if this function changes later. The URL carries no credential (Basic Auth is a header, not a query param), so it's safe to print in full, and it's exactly what the maintainer could paste into a browser or `curl -u user:pass` to check the read independently rather than trust the tool's own "Found"/"Not found" claim. Every poll retry logs its own request (a real, distinct HTTP call each time), not just the first attempt.

Verified end-to-end against real Grafana Cloud in both plain-text and `--json` mode after this round (the `--json` run additionally with `LOG_TO_CONSOLE=true` forced on, confirming stdout is still pure, valid JSON).

**A seventh round, catching redundancy the sixth round's fix had introduced**: the maintainer flagged the queuing line's tail as "blabla" — `under service_name=X (this same call also auto-emits the sovdev_operations_total metric for service_name=X)` restated `service_name` twice (once bare, once inside a parenthetical justifying the metric) and buried a plain fact inside an explanatory aside. Fixed by stating `service_name` exactly once, where it's actually set (`Initializing sovdev-logger for service_name=X ...`, not repeated at the queuing line), and giving the metric side-effect its own short sentence after `sovdev_log()` returns (`Queued. This same call also auto-emitted the sovdev_operations_total metric.`) instead of folding it into the call description. Separately, the maintainer also correctly suspected that the `🔄 Flushing OpenTelemetry traces...`-style lines aren't this tool's own code — confirmed true (they're `sovdev_initialize()`/`sovdev_shutdown()`'s own internal diagnostics, passed through as-is) — but that distinction had only ever been written down in this doc, never stated in the tool's own output. Fixed by stating the rule once, in the `=== Test starting ===` line itself: `(timestamped lines below are this tool's own reporting; un-timestamped lines are sovdev-logger's own internal diagnostic output, printed as-is, not a claim made by this tool)`.

**An eighth round, a real bug found by the maintainer actually asking "does this work on UIS too?" and running it inside the devcontainer**: `write-log`/`write-metric` reported pass, but `read-log`/`read-metric` failed with `fetch failed`. Investigated directly rather than assumed: `getent hosts` inside the devcontainer confirmed `otel.localhost`/`grafana.localhost` both resolve to `127.0.0.1` — the *container's own* loopback, not the host machine — so nothing answers there; a direct `curl` to both confirmed connection failure. This also exposed a second, quieter fact worth naming: `write-log`/`write-metric` reporting "pass" here means only that `sovdev_log()`/`sovdev_shutdown()` didn't throw, not that the data was confirmed delivered (the OTel SDK doesn't surface export failures as thrown errors) — confirming delivery is exactly what `read-log`/`read-metric` exist for, and they correctly caught what the write side couldn't. Fixed the read side to support the same `host.docker.internal` + explicit `Host` header pattern the write side's OTLP env vars already use (`OTEL_EXPORTER_OTLP_HEADERS=Host=otel.localhost`): added an optional `GRAFANA_HOST_HEADER` env var, threaded through `backend-config.ts` → `signal-clients.ts` → `query-client.ts`. Building this exposed a second, independent bug caught by testing rather than assuming: an initial version built on the global `fetch()` looked correct (no type error, no exception) but silently failed, because `fetch()`/undici drops a manually-set `Host` header (it's a WHATWG-forbidden header name) — confirmed directly with a live request (`curl -H "Host: grafana.localhost" http://host.docker.internal/...` → 200; the equivalent `fetch()` call → 404). Rewrote `query-client.ts` on `node:http`/`node:https` instead, which do send whatever `Host` they're given — confirmed with the same live request (200). Verified end-to-end, for real, inside the devcontainer via `dct-exec`: all four signals pass against UIS with `GRAFANA_URL=http://host.docker.internal` + `GRAFANA_HOST_HEADER=grafana.localhost`, and a repeat run on the host Mac (no `hostHeader` set) confirmed no regression there.

**A ninth round, on `--help` itself**: the maintainer ran `--help` and found it genuinely thin — no stated purpose, no explanation of *why* `--backend` exists, and two real flags (`--service-name`, `--help` itself) never mentioned at all, only inferable from the one-line usage synopsis. Rewrote it to state the tool's actual purpose up front (why read-back matters, not just what it writes), document all four flags with real explanations including why `--backend` is sometimes required, and list the required env vars per backend (including the new `GRAFANA_HOST_HEADER` from the previous round) so someone can go from `--help` straight to a working command without needing this doc open. The option list's column alignment is computed from the actual flag strings (`Math.max(...HELP_OPTIONS.map(o => o.flag.length))`) rather than hand-counted spaces — a hardcoded column would have silently drifted the next time a flag or description changed, the same class of "looks right but isn't" gap this tool exists to avoid making about *other* systems.

---

## Phase 5: Packaging and final verification

### Tasks

- [x] 5.1 Add `"bin": {"sovdev-selftest": "dist/cli/selftest.js"}` to `typescript/package.json` (confirmed `tsconfig.json`'s `include: ["src/**/*"]` already compiles anything under `src/cli/` into `dist/cli/` with no config changes needed) — with a `#!/usr/bin/env node` shebang at the top of `src/cli/selftest.ts`.
- [x] 5.2 Full build (`npm run build` in `typescript/`), confirm `dist/cli/selftest.js` is executable and `npx sovdev-selftest --help` works from a fresh install. **Validated properly, not assumed**: `npm pack` → installed the real tarball into a fresh scratch project → `npx sovdev-selftest --help` and a full `--backend uis --json` run both worked correctly (npm creates the executable symlink from the `bin` entry automatically, confirmed via `ls -la node_modules/.bin/sovdev-selftest`).
- [ ] 5.3 Mark `INVESTIGATE-selftest-cli.md` shipped; re-rank in `1PRIORITY.md`.
- [ ] 5.4 **Deferred, tracked as follow-up, not part of this plan's completion**: mint ollacrm (and any future external consumer) their own LBAC-scoped, read-only Access Policy before handing them the CLI — `GRAFANA_CLOUD_VERIFY_TOKEN` is fine for the maintainer's own use in this plan, but unscoped and unsafe to distribute externally as-is. Includes confirming whether Grafana Cloud LBAC (the "Add label selector" control) is actually available on the `urbalurba` stack's plan tier — still unconfirmed as of this plan.

### Validation

```bash
cd typescript && npm run build && npx sovdev-selftest --backend grafana-cloud
cd typescript && npx sovdev-selftest --backend uis
```

Both real end-to-end runs pass, both against live backends, not mocked.

**Done.** Both backends validated end-to-end across Phases 1–4 (Grafana Cloud and UIS), and the packaged, installed CLI additionally validated via a real `npm pack` → fresh install → `npx` round-trip in Phase 5 above — not just running `node dist/cli/selftest.js` directly inside the source workspace.

---

## Acceptance Criteria

- [x] `npx sovdev-selftest --backend grafana-cloud` and `--backend uis` both work end-to-end against real, live backends
- [x] Auto-detect works when only one backend is configured; explicit `--backend` is required (with a clear error) when both are configured or neither is
- [x] Four independent signals reported (write-log, write-metric, read-log, read-metric), each with a specific diagnostic on failure
- [x] `--json` mode and a correct exit code (0 only on full pass) both work
- [x] No new runtime dependencies added (query client and arg parsing both built on what the package already has, or Node's built-ins)
- [x] `INVESTIGATE-selftest-cli.md` and `1PRIORITY.md` updated to reflect this shipped

## Files Modified

- `typescript/src/cli/query-client.ts` (new)
- `typescript/src/cli/backend-config.ts` (new)
- `typescript/src/cli/signal-clients.ts` (new)
- `typescript/src/cli/write-step.ts` (new)
- `typescript/src/cli/poll.ts` (new)
- `typescript/src/cli/report.ts` (new)
- `typescript/src/cli/progress.ts` (new — shared timestamped stderr logging)
- `typescript/src/cli/selftest.ts` (new — the actual CLI entry point)
- `typescript/package.json` (`bin` entry added)
- `website/docs/ai-developer/plans/completed/INVESTIGATE-selftest-cli.md` (moved from `backlog/`)
- `website/docs/ai-developer/plans/backlog/1PRIORITY.md`
