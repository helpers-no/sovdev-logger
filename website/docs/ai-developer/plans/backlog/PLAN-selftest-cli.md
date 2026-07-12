---
mdx:
  format: md
---

# Plan: Build the self-test CLI (write, read back, report)

Ships `sovdev-selftest` as a bundled `bin` entry inside `@terchris/sovdev-logger` — writes a uniquely-marked log and metric, reads both back over plain HTTP against either Grafana Cloud or local UIS, and reports a clear four-signal PASS/FAIL.

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Backlog

**Investigation**: [INVESTIGATE-selftest-cli.md](INVESTIGATE-selftest-cli.md) — Option A, all design questions ([Q1]-[Q8]) decided

**Goal**: `npx sovdev-selftest --backend grafana-cloud|uis` initializes sovdev-logger, emits one uniquely-marked log + metric under a disposable `<service_name>-selftest` name, polls Loki and Prometheus (via each backend's own plain-HTTP query API) until both show up or a timeout is reached, and prints a four-line PASS/FAIL report (plain text by default, `--json` for CI) with a real exit code.

**Last Updated**: 2026-07-13 (Phase 1's Grafana Cloud config revised: a separate, dedicated read-only token, not the write token reused, after a live portal check found Grafana Cloud's own UI warns against combining read+write scopes on one Access Policy)

---

## Problem Summary

See `INVESTIGATE-selftest-cli.md` for the full research. In short: no existing tool does the full write→read-back cycle in one invocation against either backend, and — checked directly against vendor tooling — no observability vendor bundles this either (Sentry's live-polling page depends on true multi-tenancy sovdev-logger doesn't have; everyone else ships separate, separately-installed query CLIs). This plan builds it as a native TypeScript layer: one shared HTTP query client (generalized from `tools/validation/grafana-cloud/lib/grafana-cloud-client.ts`), reaching Grafana Cloud directly and UIS through Grafana's own datasource-proxy API (`grafana.localhost/api/datasources/proxy/uid/<uid>/...` — confirmed live this session, no `kubectl` required for either backend).

---

## Phase 1: Generalize the shared query client into the published package

The existing `grafanaCloudQuery()` in `tools/validation/grafana-cloud/lib/grafana-cloud-client.ts` lives in a tooling-only workspace, never published to npm. The self-test CLI ships inside `@terchris/sovdev-logger` itself, so its query logic needs to live in `typescript/src/`, not `tools/`.

### Tasks

- [ ] 1.1 Create `typescript/src/cli/query-client.ts` — a generalized version of `grafanaCloudQuery()`: same GET-with-Basic-Auth-and-throw-on-non-2xx shape, but the credential parameter is a generic `{user: string; pass: string}` pair (Grafana Cloud passes `instanceId`/`token` into it; UIS passes `username`/`password`) — the two are structurally identical (both are HTTP Basic Auth), only the field names differ per backend, matching [Q2]'s decided backend-specific config types.
- [ ] 1.2 Define the two backend config types per [Q2]:
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
- [ ] 1.3 Define the concrete env vars each config type resolves from:
  - Grafana Cloud: reuse the **existing, already-provisioned** vars from `tools/validation/grafana-cloud/.env.example` exactly as named — `GRAFANA_CLOUD_INGEST_TOKEN`, `GRAFANA_CLOUD_VERIFY_TOKEN`, `GRAFANA_CLOUD_OTLP_ENDPOINT`, `GRAFANA_CLOUD_OTLP_INSTANCE_ID`, `GRAFANA_CLOUD_LOKI_URL`, `GRAFANA_CLOUD_LOKI_INSTANCE_ID`, `GRAFANA_CLOUD_PROMETHEUS_URL`, `GRAFANA_CLOUD_PROMETHEUS_INSTANCE_ID`. No new Access Policy needed for this first version — `GRAFANA_CLOUD_VERIFY_TOKEN` is the same unscoped, stack-wide read credential the existing query tooling already uses. **Not suitable to hand to an external consumer like ollacrm as-is** (unscoped read sees every onboarded system's data) — minting ollacrm their own LBAC-scoped, per-system read policy is explicitly deferred, tracked as a follow-up, not a blocker for this plan.
  - UIS: `GRAFANA_URL`, `GRAFANA_USER`, `GRAFANA_PASSWORD` (matching `tools/dashboards/push-dashboard.ts`'s existing convention exactly).
- [ ] 1.4 Build the UIS query path as a thin wrapper: `${grafanaUrl}/api/datasources/proxy/uid/<loki|prometheus>/<native-path>`, reusing the same `query-client.ts` function with the datasource-proxy prefix baked into the base URL.

### Validation

Unit test (or a quick manual script) hitting both a live Grafana Cloud instance and local UIS with the generalized client, confirming both return real data — same shape of check already done manually in the investigation.

---

## Phase 2: Backend selection and config resolution

### Tasks

- [ ] 2.1 Implement `--backend grafana-cloud|uis` flag parsing using Node's built-in `util.parseArgs` (no new dependency — the package has none for CLI parsing today, and this is a two-flag surface: `--backend` and `--json`).
- [ ] 2.2 Auto-detect fallback per [Q1]: if `--backend` isn't given, check which config's env vars are present; if both are present, fail fast with a message asking for an explicit `--backend` (the maintainer's own dual-backend devcontainer case); if neither is present, fail fast listing which vars are missing for each backend.
- [ ] 2.3 Resolve the chosen backend's config (Phase 1's types), erroring immediately with a specific missing-var message if the explicitly-requested backend's own vars aren't fully present.

### Validation

Manual run with: only Grafana Cloud vars set (should auto-select); only UIS vars set (should auto-select); both set with no flag (should error asking for `--backend`); both set with `--backend uis` (should select UIS); neither set (should list missing vars for both).

---

## Phase 3: Write step

### Tasks

- [ ] 3.1 Call `sovdev_initialize()` with a disposable service name: `${OTEL_SERVICE_NAME}-selftest` (or a `--service-name` override flag if `OTEL_SERVICE_NAME` isn't set) — per [Q3]'s decided disposable-name convention.
- [ ] 3.2 Call `sovdev_log()` once with a marker message (any fixed, greppable string is enough — per [Q8], the disposable service_name is what actually identifies this run, not the message content).
- [ ] 3.3 Call `sovdev_shutdown()` to force-flush and tear down, per this project's own established flush/shutdown split.

### Validation

Confirm via existing query tooling (`tools/validation/grafana-cloud/query-loki.ts` or local UIS query) that the write actually lands, before building the read side on top of it.

---

## Phase 4: Read step — poll with backoff, four-signal report

### Tasks

- [ ] 4.1 Implement poll-with-backoff per [Q4]: query every 2s, timeout at 30s for the log, 60s for the metric — two independent timeout clocks, not one shared one (metrics lag further behind than logs).
- [ ] 4.2 Distinguish a timeout ("may still arrive — try again shortly") from a hard failure (non-2xx response, e.g. wrong credential or endpoint) in the message — per [Q4], conflating the two was explicitly identified as the exact false-"broken"-signal problem this tool exists to eliminate.
- [ ] 4.3 Report four independent lines per [Q6]: write-log, write-metric, read-log, read-metric — each with its own pass/fail and a specific diagnostic on failure (which credential, which endpoint, which timeout).
- [ ] 4.4 Plain text output by default; `--json` flag emits the same four signals as a structured object instead.
- [ ] 4.5 Exit code 0 only if all four signals pass, 1 otherwise.

### Validation

Full end-to-end run against both real backends (Grafana Cloud and local UIS), confirming both the human-readable and `--json` output modes, and confirming a deliberately-broken credential produces the specific diagnostic, not a stack trace.

---

## Phase 5: Packaging and final verification

### Tasks

- [ ] 5.1 Add `"bin": {"sovdev-selftest": "dist/cli/selftest.js"}` to `typescript/package.json` (confirmed `tsconfig.json`'s `include: ["src/**/*"]` already compiles anything under `src/cli/` into `dist/cli/` with no config changes needed) — with a `#!/usr/bin/env node` shebang at the top of `src/cli/selftest.ts`.
- [ ] 5.2 Full build (`npm run build` in `typescript/`), confirm `dist/cli/selftest.js` is executable and `npx sovdev-selftest --help` works from a fresh install.
- [ ] 5.3 Mark `INVESTIGATE-selftest-cli.md` shipped; re-rank in `1PRIORITY.md`.
- [ ] 5.4 **Deferred, tracked as follow-up, not part of this plan's completion**: mint ollacrm (and any future external consumer) their own LBAC-scoped, read-only Access Policy before handing them the CLI — `GRAFANA_CLOUD_VERIFY_TOKEN` is fine for the maintainer's own use in this plan, but unscoped and unsafe to distribute externally as-is. Includes confirming whether Grafana Cloud LBAC (the "Add label selector" control) is actually available on the `urbalurba` stack's plan tier — still unconfirmed as of this plan.

### Validation

```bash
cd typescript && npm run build && npx sovdev-selftest --backend grafana-cloud
cd typescript && npx sovdev-selftest --backend uis
```

Both real end-to-end runs pass, both against live backends, not mocked.

---

## Acceptance Criteria

- [ ] `npx sovdev-selftest --backend grafana-cloud` and `--backend uis` both work end-to-end against real, live backends
- [ ] Auto-detect works when only one backend is configured; explicit `--backend` is required (with a clear error) when both are configured or neither is
- [ ] Four independent signals reported (write-log, write-metric, read-log, read-metric), each with a specific diagnostic on failure
- [ ] `--json` mode and a correct exit code (0 only on full pass) both work
- [ ] No new runtime dependencies added (query client and arg parsing both built on what the package already has, or Node's built-ins)
- [ ] `INVESTIGATE-selftest-cli.md` and `1PRIORITY.md` updated to reflect this shipped

## Files to Modify

- `typescript/src/cli/query-client.ts` (new)
- `typescript/src/cli/selftest.ts` (new — the actual CLI entry point)
- `typescript/package.json` (`bin` entry added)
- `website/docs/ai-developer/plans/backlog/INVESTIGATE-selftest-cli.md`
- `website/docs/ai-developer/plans/backlog/1PRIORITY.md`
