# Investigate: Onboard ollacrm as sovdev-logger's first real external consumer

`ollacrm` (`terchris/ollacrm`, a private family care-coordination app, TypeScript/Hono on Cloud Run) is about to become the first system outside this repo to actually use sovdev-logger. This investigation covers the two things that need to be true before that can happen cleanly: a precise integration guide (a Docusaurus page, not a GitHub issue — see [Q4]) and Grafana Cloud actually ready to receive and display ollacrm's telemetry.

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Resolved on sovdev-logger's side — remaining work is in `terchris/ollacrm`'s own repo

**Goal**: A precise integration guide for `ollacrm`, plus Grafana Cloud actually ready to show its data once it starts arriving.

**Last Updated**: 2026-07-10

**Outcome**: All of [Q1]–[Q6] resolved. The `ollacrm-ingest` token is created and empirically validated (real Loki/Prometheus readback). The dashboard is live on Grafana Cloud with real data confirmed — turned out to need one genuine fix beyond a plain UI Import (see the "Grafana Cloud" section and `tools/dashboards/README.md`'s "Deploying to Grafana Cloud" section for the full story: Grafana's Import wizard doesn't auto-map datasources for a hand-authored JSON, and the real datasource UIDs aren't the same as their display names). No Service Account token was ever needed, confirming the corrected understanding below. What's left is `ollacrm`'s own repo's work (installing the package, wiring the code) — see the last Next Steps item.

**Why this was parked, for the record**: writing the flush guidance for ollacrm surfaced a real, confirmed divergence — TypeScript's `sovdev_flush()` shut down the SDK permanently on first call, Python's didn't — bigger than one onboarding, worth resolving at the library level first. Spun out to [`INVESTIGATE-long-running-server-flush.md`](INVESTIGATE-long-running-server-flush.md), now shipped. This never actually blocked ollacrm's onboarding: the documented initialize-once/shutdown-on-`SIGTERM` pattern never called `sovdev_flush()` more than once per process.

---

## Why this needs an investigation, not just a quick issue draft

This is the first time sovdev-logger's published TypeScript package gets used by anyone other than its own E2E test — and the E2E test is a short script, while ollacrm is a persistent Cloud Run server. Every existing usage example in the README is script-shaped (`sovdev_flush()` once at the end, then exit); nothing documents the initialize-once / flush-on-shutdown pattern a long-running server actually needs. Getting this wrong either drops telemetry silently (never flushing) or adds needless latency to every request (flushing per-request). Separately, getting the dashboard onto Grafana Cloud was initially assumed to need new tooling (a Service Account token, a script to substitute datasource UIDs) — it doesn't; Grafana Cloud's own Import UI handles the datasource mapping interactively, a manual one-time task rather than something to build. Worth resolving both with evidence before writing anything.

---

## Current State (checked directly)

### ollacrm's stack

Checked directly in `/Users/tec/learn/helpers/ollacrm` (real code, not assumed):

- TypeScript, Node ≥22, ESM, [Hono](https://hono.dev/) web framework, bundled with esbuild to `dist/server.mjs`, deployed as a Cloud Run container (`services/api/`).
- Entry point `services/api/src/server.ts`; config pattern in `services/api/src/config.ts` (plain identifiers as exported constants; real secrets read from `process.env.X`, mounted from Secret Manager — the file's own header promises "NEVER secrets").
- No logging library today — 18 raw `console.log`/`console.error`/`console.warn` calls across `services/api/src`.
- Deploy pipeline (`.github/workflows/deploy.yml`) uses `gcloud run deploy` with two distinct flags: `--update-env-vars` (merges, for plain identifiers — currently `APP_VERSION`, `BUILT_AT`, `VAPID_PUBLIC_KEY`, `VAPID_SUBJECT`) and `--set-secrets` (mounts from Secret Manager — currently just `VAPID_PRIVATE_KEY=vapid-private:latest`). This distinction matters directly for how OTLP config gets wired in — see Recommendation.
- This is a genuinely long-running server (Cloud Run keeps instances warm under load), not a one-shot script — there is no natural "end of script, flush now" moment the way the E2E test has one.

### sovdev-logger's TypeScript package

- Published to npm as `@terchris/sovdev-logger@1.0.1` at the time this was written (confirmed via `npm view`, published 2026-07-10). Unpacked the actual tarball and confirmed `dist/logger.js` already contains the OTLP header spec-compliance fix (`fix: OTEL_EXPORTER_OTLP_HEADERS follows the real OpenTelemetry spec`, merged in `dd5360f`) — ollacrm can `npm install` the real published package directly, no git-dependency workaround needed. **Superseded**: `1.0.2` has since shipped (see [Q5]) and is required — it adds `sovdev_shutdown()`, which the worked example (`using/onboarding/ollacrm/index.md`) uses throughout.
- **Found, not blocking**: `typescript/package.json`'s `repository` field still points at `norwegianredcross/sovdev-logger` (the old upstream), not `helpers-no/sovdev-logger` (this fork, where all current work actually lives). Stale metadata, worth a one-line fix — see [Q5].
- Full public API confirmed directly from `typescript/src/index.ts` + `logger.ts`: `sovdev_initialize`, `sovdev_flush`, `sovdev_log`, `sovdev_log_job_status`, `sovdev_log_job_progress`, `sovdev_start_span`, `sovdev_end_span`, `sovdev_validate_config`, `sovdev_test_otlp_connection`, plus `SOVDEV_LOGLEVELS` and `create_peer_services`.
- Required env vars, confirmed from `sovdev_validate_config()` (`logger.ts:949`): `OTEL_SERVICE_NAME`, `OTEL_EXPORTER_OTLP_LOGS_ENDPOINT`, `OTEL_EXPORTER_OTLP_METRICS_ENDPOINT`, `OTEL_EXPORTER_OTLP_TRACES_ENDPOINT`, `OTEL_EXPORTER_OTLP_HEADERS` (all required); `OTEL_EXPORTER_OTLP_PROTOCOL` is optional but recommended (`http/protobuf`).
- Batching is automatic and fast, confirmed from `logger.ts`: logs export every 1s (`BatchLogRecordProcessor`, `scheduledDelayMillis: 1000`), metrics every 10s (`exportIntervalMillis: 10000`). `sovdev_flush()` exists only to force the *final* in-flight batch out before a process actually exits — it is not needed after every log call.

### The flush gap — every existing example is script-shaped, ollacrm is a server

- `typescript/README.md`'s every usage example calls `await sovdev_flush()` once, at the very end of a short script, mirroring the E2E test's own shape. There is no documented pattern for a process that never "ends."
- The correct pattern for ollacrm: call `sovdev_initialize()` once at module load (alongside the rest of `server.ts`'s top-level setup), call `sovdev_log()` freely per-request with no flush, and flush exactly once — on graceful shutdown.
- Cloud Run sends `SIGTERM` with a grace period before `SIGKILL` on scale-down or redeploy (long enough to cover the 1–10s batch windows above), so `process.on('SIGTERM', async () => { await sovdev_flush(); process.exit(0); })` is the right, idiomatic hook — standard Node/Cloud Run shutdown handling, nothing sovdev-logger-specific about the mechanism itself.
- This pattern isn't written down anywhere today. Worth spelling out precisely in the issue — and, per [Q6] below, arguably worth adding to the README afterward as sovdev-logger's first real server-shaped example, since ollacrm won't be the last.

### Grafana Cloud — a verified ingest/query pipeline; the dashboard itself is a manual, few-minutes step, not a credential problem

- `tools/validation/grafana-cloud/` already has a fully working, previously-verified OTLP ingest + Loki/Tempo/Prometheus query pipeline (see `INVESTIGATE-grafana-cloud-validator.md`) — built and verified as sovdev-logger's own testing/verification stack, not (yet) a customer-facing one.
- The data layer needs nothing further: the moment any new system pushes via its own ingest token (like `ollacrm-ingest`), its telemetry lands in the exact same Loki/Prometheus/Tempo the dashboard already queries — that's the whole "one place, many systems" architecture, and it doesn't depend on the dashboard existing on Grafana Cloud at all.
- **Corrected assumption, caught by the maintainer**: originally assumed getting the *dashboard definition itself* onto Grafana Cloud needed a new Grafana Service Account token, to script the push via `/api/dashboards/db` the way `push-dashboard.ts` does for local UIS. It doesn't — Grafana Cloud's own UI has a built-in **Import dashboard** flow (Dashboards → New → Import → paste/upload JSON). Grafana itself prompts you, interactively, to map each datasource reference in the JSON to a real datasource in your instance — exactly the substitution problem below, solved by the UI, not a script.
- `tools/dashboards/sovdev-logger-overview.json` hardcodes datasource identifiers as the literal strings `"prometheus"`, `"loki"`, `"tempo"` (confirmed by reading the JSON directly) — that's what local UIS's Traefik-provisioned Grafana happens to call its own datasources. Grafana Cloud's own Grafana instance manages its Loki/Tempo/Mimir datasources under its own UIDs, but the Import flow's mapping prompt handles this directly — no need to query `/api/datasources` or hand-edit a Grafana-Cloud-specific copy of the JSON first.
- The dashboard is otherwise portable as-is: every panel query (PromQL/LogQL/TraceQL) and the `$service_name` template variable (`multi: true`, `includeAll: true`, `allValue: ".+"`) already assume more than one service will show up in the same dashboard. This is exactly the "one schema, one dashboard, many systems" scenario [`why-consistent-logging.md`](../../../general/why-consistent-logging.md) argues for — ollacrm would be the second service filling it in, not a special case.

---

## Options

### Option A: Reuse the exact same Grafana Cloud stack and ingest token sovdev-logger already validates against

ollacrm pushes telemetry to the same OTLP endpoint and stack, distinguished only by its own `service_name` (e.g. `ollacrm-api`). The dashboard's `$service_name` variable already handles multiple services with no changes needed once it's pushed.

**Pros**: zero new Grafana Cloud account setup; reuses the already-verified ingest pipeline; ollacrm can start logging as soon as env vars are configured.
**Cons**: mixes a real, personal-use application's telemetry with sovdev-logger's own test/validation traffic in the same stack and the same free-tier quota; a token rotation done for sovdev-logger's own testing reasons would break ollacrm's logging too, with no isolation between the two.

### Option B: Mint a dedicated ingest token (same stack, same dashboard) scoped for ollacrm specifically

Same Grafana Cloud stack and dashboard as Option A, but a second Access Policy/token (e.g. `ollacrm-ingest`, scoped `logs:write`+`metrics:write`+`traces:write`) independent from sovdev-logger's own `sovdev-logger-ingest` token.

**Pros**: all of Option A's benefits, plus independent revocation/rotation — a leak or rotation of one credential doesn't affect the other; matches the least-privilege pattern this project already established (`sovdev-logger-ingest` vs `sovdev-logger-verify`, two separate policies rather than one broad one).
**Cons**: one more manual step in the Grafana Cloud portal — but that step (creating an access policy + minting a token) is already established as something only the maintainer does by hand; `contributor/testing/grafana-cloud.md` notes two separate Claude Code sessions have each independently declined to click "Create" on access controls even with explicit authorization.

### Option C: Set up an entirely separate Grafana Cloud stack for ollacrm

A new, independent Grafana Cloud account/stack, its own free-tier quota, its own copy of the dashboard.

**Pros**: full isolation from sovdev-logger's own testing infrastructure.
**Cons**: gives up the exact benefit [`why-consistent-logging.md`](../../../general/why-consistent-logging.md) argues for — one schema, one dashboard, org-wide monitoring — at the very first real opportunity to demonstrate it; doubles setup and ongoing maintenance for no clear benefit, since both projects share the same maintainer.

---

## Recommendation

**Option B.** Same Grafana Cloud stack and the same dashboard (so "one schema, many systems, one dashboard" is real and demonstrated, not just written down), with a dedicated `ollacrm-ingest` token so the two systems' credentials stay independently revocable — one manual portal step, matching the existing precedent for how these tokens get created.

**For getting the dashboard onto Grafana Cloud**: no new credential needed. Open the Grafana Cloud instance, **Dashboards → New → Import**, paste or upload `tools/dashboards/sovdev-logger-overview.json`, and use Grafana's own datasource-mapping prompt to point the JSON's `"prometheus"`/`"loki"`/`"tempo"` references at the real datasources already provisioned in that instance. A manual, few-minutes, one-time task — not a scripting problem, and not blocked on minting anything.

**For the GitHub issue**: one precise document covering —
1. **Install**: `npm install @terchris/sovdev-logger` (real published package, header fix included).
2. **Config wiring matched to ollacrm's actual deploy pattern**: `OTEL_EXPORTER_OTLP_HEADERS` (contains the Grafana Cloud Basic Auth token) is a real secret → `--set-secrets`, mounted from Secret Manager, exactly like `VAPID_PRIVATE_KEY` already is. `OTEL_SERVICE_NAME` and the three endpoint URLs are plain identifiers → `--update-env-vars`, exactly like `APP_VERSION`/`VAPID_PUBLIC_KEY` already are.
3. **The initialize-once / flush-on-`SIGTERM` server pattern** — not documented anywhere today, spelled out precisely for `server.ts`'s actual shape.
4. **A worked example**: replace 2–3 of the 18 existing `console.log` calls with real `sovdev_log()` calls in an actual ollacrm handler, not an invented snippet.
5. **`peer_service` identifiers**: ollacrm's own decision for what to call Google Drive/Calendar/Vertex AI/Sheets as peer services, but shown concretely via `create_peer_services({...})`, matching this repo's own `company-lookup.ts` pattern.

---

## Open Questions

1. **[Q1]** — **Decided by maintainer.** Option B: same Grafana Cloud stack and dashboard (rejecting Option C — the whole point is one dashboard across many systems), with a dedicated `ollacrm-ingest` access policy/token rather than reusing `sovdev-logger-ingest` (rejecting Option A) — independent revocation for the two systems.
2. **[Q2]** Is the Grafana Cloud free tier's 14-day retention acceptable once ollacrm is actually logging real family-care activity, or does this need a paid tier (or a different backend entirely) before it's more than a test?
3. **[Q3]** — **Moot.** Was framed as "script the datasource-UID substitution, or hand-edit a Grafana-Cloud copy of the JSON" — neither is needed. Grafana Cloud's own dashboard Import UI prompts for the datasource mapping interactively; there's no copy of the JSON to maintain and no substitution to script.
4. **[Q4]** — **Superseded.** Originally "file the GitHub issue now or hold it until the dashboard is live" — moot, since the decision (see Next Steps) was to not file a GitHub issue on `terchris/ollacrm` at all. The integration guide is a public Docusaurus page (`using/onboarding/ollacrm/index.md`) instead, which doesn't have the same "dead link until the dashboard exists" problem — it's useful reference material on its own regardless of the dashboard's state.
5. **[Q5]** — **Fully resolved.** `typescript/package.json`'s `repository`/`bugs`/`homepage` corrected to `helpers-no/sovdev-logger`; `1.0.2` published to npm (confirmed live via `npm view @terchris/sovdev-logger version`) — carries this metadata fix and the `sovdev_flush()`/`sovdev_shutdown()` split. Along the way, documented the publish process for the first time ever (see [`contributor/publishing/typescript.md`](../../../contributor/publishing/typescript.md)) — it had only ever existed as one buried line in a completed plan's checklist.
6. **[Q6]** — **Resolved, no action needed.** `typescript/README.md` links out to `using/onboarding/` for the full server pattern rather than duplicating it inline — this already matches the project's own README-vs-Docusaurus policy (small essentials inline, full reference linked out), settled in `INVESTIGATE-readme-vs-docusaurus-policy.md`.

## Next Steps

Only one Grafana Cloud credential is actually needed here — the ingest access policy. The dashboard side turned out not to need a second credential at all (see the corrected "Grafana Cloud" section above): getting the dashboard definition onto Grafana Cloud is a manual, one-time Import through the UI, not something to mint a Service Account token to script.

The ingest access policy + standard OTLP env vars is written up as a reusable, generic recipe — [`using/onboarding/index.md`](../../../using/onboarding/index.md) — since ollacrm won't be the last system to onboard.

- [x] **(Maintainer)** Create the `ollacrm-ingest` access policy + token (Cloud Portal, `logs:write`+`metrics:write`+`traces:write`, scoped to the one stack) — done, and validated: pushed a disposable `ollacrm-ingest-validation` log + metric through it, confirmed both landed via `query-loki.ts`/`query-prometheus.ts` against the real backend, not just "token created" in the portal
- [x] **(Maintainer)** Import the dashboard into the Grafana Cloud instance — done, confirmed live with real data. Turned out to need one more real fix than expected: Grafana's Import wizard doesn't auto-map datasources for a hand-authored JSON (no `__inputs` structure), so the first import silently kept the local-UIS datasource identifiers and every panel failed with "Datasource X was not found." Fixed by writing [`tools/dashboards/adapt-for-grafana-cloud.ts`](https://github.com/helpers-no/sovdev-logger/blob/main/tools/dashboards/adapt-for-grafana-cloud.ts), which rewrites the UIDs to Grafana Cloud's real ones (found by opening each datasource's settings page, not from the Data Sources list's display names, which differ from the actual UID) — re-imported the generated file, verified with fresh telemetry pushed through `ollacrm-ingest`, confirmed showing up live. Full writeup in [`tools/dashboards/README.md`](https://github.com/helpers-no/sovdev-logger/blob/main/tools/dashboards/README.md)'s "Deploying to Grafana Cloud" section.
- [x] Maintainer answers [Q2]–[Q6] — all resolved, see above
- [x] **Revised**: rather than filing this as a GitHub issue on `terchris/ollacrm`, the integration guide is now [`using/onboarding/ollacrm/index.md`](../../../using/onboarding/ollacrm/index.md) — a Docusaurus page (in a folder, so future screenshots/notes from the actual integration have somewhere to live) — so it serves as both the howto for ollacrm's actual integration and permanent, public documentation of a real worked example (not a private issue nobody else can reference). Nothing has been filed on `terchris/ollacrm` itself.
- [ ] The actual ollacrm code changes (install `@terchris/sovdev-logger@1.0.2`+, wire `sovdev_initialize()`/`sovdev_shutdown()` into `server.ts`, convert the `sheets.ts` example) — this is `terchris/ollacrm`'s own repo, out of this session's scope; `using/onboarding/ollacrm/index.md` is ready as the guide whenever that work happens, here or in an ollacrm-scoped session
