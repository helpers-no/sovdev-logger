# Investigate: Onboard ollacrm as sovdev-logger's first real external consumer

`ollacrm` (`terchris/ollacrm`, a private family care-coordination app, TypeScript/Hono on Cloud Run) is about to become the first system outside this repo to actually use sovdev-logger. This investigation covers the two things that need to be true before that can happen cleanly: a precise integration guide (filed as a GitHub issue on `terchris/ollacrm`) and a Grafana Cloud instance actually ready to receive and display ollacrm's telemetry.

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Parked — spun off a deeper library-level investigation

**Goal**: A GitHub issue for `terchris/ollacrm` precise enough that its Claude Code agent can wire up sovdev-logger correctly on the first attempt, plus a Grafana Cloud dashboard actually ready to show ollacrm's data once it starts arriving.

**Last Updated**: 2026-07-10

**Why parked**: writing the flush guidance for ollacrm surfaced a real, confirmed divergence — TypeScript's `sovdev_flush()` shuts down the SDK permanently on first call, Python's doesn't — that's bigger than one onboarding and worth resolving at the library level first. Spun out to [`INVESTIGATE-long-running-server-flush.md`](../completed/INVESTIGATE-long-running-server-flush.md) — **now shipped**: `sovdev_flush()`/`sovdev_shutdown()` split in both languages. This never blocked ollacrm's actual onboarding: the documented initialize-once/shutdown-on-`SIGTERM` pattern never called `sovdev_flush()` more than once per process. Its own worked example (`using/onboarding/ollacrm/index.md`) has already been updated to the new `sovdev_shutdown()` call. The Grafana Cloud credential steps ([Q1]–[Q6] below) remain independently actionable whenever the maintainer is ready.

---

## Why this needs an investigation, not just a quick issue draft

This is the first time sovdev-logger's published TypeScript package gets used by anyone other than its own E2E test — and the E2E test is a short script, while ollacrm is a persistent Cloud Run server. Every existing usage example in the README is script-shaped (`sovdev_flush()` once at the end, then exit); nothing documents the initialize-once / flush-on-shutdown pattern a long-running server actually needs. Getting this wrong either drops telemetry silently (never flushing) or adds needless latency to every request (flushing per-request). Separately, "push the dashboard we already built to Grafana Cloud" turns out not to be a trivial repeat of what was already done for local UIS — the dashboard hardcodes datasource identifiers that don't carry over, and there's no existing tooling for the Grafana Cloud dashboard API at all (only for OTLP ingest and read-back verification). Both are worth resolving with evidence before writing the issue or pushing anything.

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

- Published to npm as `@terchris/sovdev-logger@1.0.1` (confirmed via `npm view`, published 2026-07-10). Unpacked the actual tarball and confirmed `dist/logger.js` already contains the OTLP header spec-compliance fix (`fix: OTEL_EXPORTER_OTLP_HEADERS follows the real OpenTelemetry spec`, merged in `dd5360f`) — ollacrm can `npm install` the real published package directly, no git-dependency workaround needed.
- **Found, not blocking**: `typescript/package.json`'s `repository` field still points at `norwegianredcross/sovdev-logger` (the old upstream), not `helpers-no/sovdev-logger` (this fork, where all current work actually lives). Stale metadata, worth a one-line fix — see [Q5].
- Full public API confirmed directly from `typescript/src/index.ts` + `logger.ts`: `sovdev_initialize`, `sovdev_flush`, `sovdev_log`, `sovdev_log_job_status`, `sovdev_log_job_progress`, `sovdev_start_span`, `sovdev_end_span`, `sovdev_validate_config`, `sovdev_test_otlp_connection`, plus `SOVDEV_LOGLEVELS` and `create_peer_services`.
- Required env vars, confirmed from `sovdev_validate_config()` (`logger.ts:949`): `OTEL_SERVICE_NAME`, `OTEL_EXPORTER_OTLP_LOGS_ENDPOINT`, `OTEL_EXPORTER_OTLP_METRICS_ENDPOINT`, `OTEL_EXPORTER_OTLP_TRACES_ENDPOINT`, `OTEL_EXPORTER_OTLP_HEADERS` (all required); `OTEL_EXPORTER_OTLP_PROTOCOL` is optional but recommended (`http/protobuf`).
- Batching is automatic and fast, confirmed from `logger.ts`: logs export every 1s (`BatchLogRecordProcessor`, `scheduledDelayMillis: 1000`), metrics every 10s (`exportIntervalMillis: 10000`). `sovdev_flush()` exists only to force the *final* in-flight batch out before a process actually exits — it is not needed after every log call.

### The flush gap — every existing example is script-shaped, ollacrm is a server

- `typescript/README.md`'s every usage example calls `await sovdev_flush()` once, at the very end of a short script, mirroring the E2E test's own shape. There is no documented pattern for a process that never "ends."
- The correct pattern for ollacrm: call `sovdev_initialize()` once at module load (alongside the rest of `server.ts`'s top-level setup), call `sovdev_log()` freely per-request with no flush, and flush exactly once — on graceful shutdown.
- Cloud Run sends `SIGTERM` with a grace period before `SIGKILL` on scale-down or redeploy (long enough to cover the 1–10s batch windows above), so `process.on('SIGTERM', async () => { await sovdev_flush(); process.exit(0); })` is the right, idiomatic hook — standard Node/Cloud Run shutdown handling, nothing sovdev-logger-specific about the mechanism itself.
- This pattern isn't written down anywhere today. Worth spelling out precisely in the issue — and, per [Q6] below, arguably worth adding to the README afterward as sovdev-logger's first real server-shaped example, since ollacrm won't be the last.

### Grafana Cloud — a verified ingest/query pipeline, but no dashboard yet

- `tools/validation/grafana-cloud/` already has a fully working, previously-verified OTLP ingest + Loki/Tempo/Prometheus query pipeline (see `INVESTIGATE-grafana-cloud-validator.md`) — built and verified as sovdev-logger's own testing/verification stack, not (yet) a customer-facing one.
- **Gap found**: nothing in this repo touches the Grafana Cloud **Grafana UI's own dashboard API**. `.env.example` only defines ingest (`logs:write`/`metrics:write`/`traces:write`) and verify (`:read` equivalents) tokens — neither scope covers `/api/dashboards/db`, which needs a Grafana Cloud service-account token against the stack's own Grafana instance URL (e.g. `https://<stack>.grafana.net`), a credential this repo doesn't have yet.
- **Gap found**: `tools/dashboards/sovdev-logger-overview.json` hardcodes datasource identifiers as the literal strings `"prometheus"`, `"loki"`, `"tempo"` (confirmed by reading the JSON directly) — that's what local UIS's Traefik-provisioned Grafana happens to call its own datasources. Grafana Cloud's own Grafana instance manages its Loki/Tempo/Mimir datasources itself, under its own UIDs — not yet confirmed what those actually are, since nothing has queried `/api/datasources` against the Grafana Cloud Grafana instance yet.
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

**For the dashboard-push gap**: mint a Grafana Cloud service-account token scoped to the Grafana instance itself (distinct from the OTLP/Loki/Tempo/Prometheus tokens already in `.env`, none of which cover the dashboard API); query `/api/datasources` on that Grafana Cloud Grafana instance to get its real Loki/Tempo/Mimir UIDs; substitute them into a Grafana-Cloud-specific copy of `sovdev-logger-overview.json`; push it with the existing `push-dashboard.ts` pattern (it already supports bearer-token auth, which is what a Grafana Cloud service-account token needs), pointed at the Grafana Cloud Grafana URL instead of `http://grafana.localhost`.

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
3. **[Q3]** Should the dashboard-JSON generation be reworked to take datasource UIDs as parameters (one script, either backend), or is a one-off hand-edited Grafana-Cloud copy of the JSON good enough for now?
4. **[Q4]** File the GitHub issue now — so ollacrm's Claude Code agent can start the integration work in parallel with the Grafana Cloud prep, per your original message — or hold it until the dashboard is actually live, so anyone following the issue's link to "see it in Grafana" doesn't hit a stack with nothing configured yet?
5. **[Q5]** `typescript/package.json`'s `repository` field still points at `norwegianredcross/sovdev-logger`, not this fork. Worth a one-line fix (and a `1.0.2` republish) before or alongside this work, or defer to its own small ticket?
6. **[Q6]** Once ollacrm's integration is actually working, is the initialize-once/flush-on-`SIGTERM` server pattern worth folding back into `typescript/README.md` as a second real-world example (alongside the existing script-shaped one), since ollacrm won't be the last server-shaped consumer?

## Next Steps

Two genuinely different Grafana Cloud credential systems are involved here, confirmed by checking what's already in `tools/validation/grafana-cloud/.env.example` (only the first exists today):

1. **Cloud Portal Access Policies** (Security → Access Policies) — stack-level tokens scoped to `logs:write`/`metrics:write`/`traces:write` etc., used for OTLP ingest and raw signal queries. This is what `sovdev-logger-ingest`/`sovdev-logger-verify` already are, and what `ollacrm-ingest` (per [Q1]) needs to be.
2. **A Grafana Service Account** (inside the Grafana Cloud instance itself — Administration → Users and access → Service accounts) — an app-level token for the Grafana HTTP API (`/api/dashboards/db`, `/api/datasources`), the same kind of credential `push-dashboard.ts` already takes as `GRAFANA_TOKEN` for local UIS. Nothing in this repo has one of these for Grafana Cloud yet.

Per this project's own established precedent (`contributor/testing/grafana-cloud.md`: "Creating the access policies and generating tokens is something you have to do yourself"), both need to be created by the maintainer, not by an agent — minting credentials and touching access controls is a hard line this project has already drawn once.

The first of these two (the ingest access policy + standard OTLP env vars) is now written up as a reusable, generic recipe — [`using/onboarding/index.md`](../../../using/onboarding/index.md) — since ollacrm won't be the last system to onboard. This investigation's remaining next steps reference it rather than repeating it.

- [ ] **(Maintainer)** Create the `ollacrm-ingest` access policy + token (Cloud Portal, `logs:write`+`metrics:write`+`traces:write`, scoped to the one stack)
- [ ] **(Maintainer)** Create a Grafana Service Account + token inside the Grafana Cloud instance (Admin or Editor role) for dashboard push
- [ ] Once that token exists: query `/api/datasources` on the Grafana Cloud Grafana instance for its real Loki/Tempo/Mimir UIDs
- [ ] Push a Grafana-Cloud-adapted copy of `sovdev-logger-overview.json` using those UIDs
- [ ] Maintainer answers [Q2]–[Q6]
- [x] **Revised**: rather than filing this as a GitHub issue on `terchris/ollacrm`, the integration guide is now [`using/onboarding/ollacrm/index.md`](../../../using/onboarding/ollacrm/index.md) — a Docusaurus page (in a folder, so future screenshots/notes from the actual integration have somewhere to live) — so it serves as both the howto for ollacrm's actual integration and permanent, public documentation of a real worked example (not a private issue nobody else can reference). Nothing has been filed on `terchris/ollacrm` itself.
- [ ] (Optional, fast-follow per [Q6]) Add the initialize-once/flush-on-SIGTERM server pattern to `typescript/README.md`
