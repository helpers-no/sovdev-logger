---
mdx:
  format: md
---

# Investigate: A self-test CLI that writes then reads back logs/metrics, usable by both the sovdev-logger maintainer and an external developer

Spun off from `INVESTIGATE-developer-first-onboarding.md`'s Option E3, this works out the actual design of a TypeScript self-test CLI — one tool, pluggable across Grafana Cloud and local UIS backends, runnable by both the sovdev-logger maintainer and an external consumer like ollacrm.

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Completed — shipped via [`PLAN-selftest-cli.md`](PLAN-selftest-cli.md), `sovdev-selftest` bin entry in `@terchris/sovdev-logger`

**Goal**: A single TypeScript command that initializes sovdev-logger, emits one uniquely-marked log + metric, reads both back, and reports a clear PASS/FAIL with a specific diagnostic — runnable by the maintainer against local UIS and by an external consumer against Grafana Cloud, same tool either way.

**Last Updated**: 2026-07-13 — shipped. All design questions ([Q1]-[Q8]) resolved and implemented; see [`PLAN-selftest-cli.md`](PLAN-selftest-cli.md) for the full build-and-verify record, including a real URL-joining bug and a `--json`-mode console-noise bug found and fixed during implementation.

---

## Why this is its own investigation, not folded into the parent

`INVESTIGATE-developer-first-onboarding.md`'s Option E3 already proposed this CLI and reasoned about *whether* to build it (verdict there: yes, worth building — Grafana Cloud's Label-Based Access Control (LBAC) resolved the credential-sharing risk that was the main objection, see that doc's [Q6]). This document is scoped narrower and more concrete: *how* to build it. An initial design pass thought it had found a real complication — local UIS's Loki/Prometheus/Tempo looked unreachable except via `kubectl run` (every existing query script, `tools/validation/uis/query-loki.sh` and its siblings, works this way). **That complication turned out not to be real** — see "UIS is reachable over plain HTTP" below, verified live against the actual running cluster. What's left is a smaller, genuinely simpler design than first thought, still worth its own document rather than a sub-section of the parent.

**Explicitly deferred**: this is written now so the design thinking isn't lost, but nothing here blocks onboarding ollacrm today — they proceed with the existing manual write+read-back validation recipe (`using/onboarding/index.md` step 5) in the meantime. We can help the ollacrm developer get their code working with what already exists; this CLI is a later improvement, not a prerequisite.

---

## Is "write, then read back, in one bundled tool" already solved elsewhere?

Worth checking directly before building this — reinventing a solved problem would be wasted effort. Checked, and the honest answer is **no vendor bundles exactly this**, though some come close in different ways:

- **Even OpenTelemetry itself splits this into two unbundled halves.** The official OTel Collector project ships `telemetrygen` — a CLI that generates synthetic logs/traces/metrics and sends real OTLP traffic, exactly like a real application would. ([telemetrygen for pipeline validation](https://oneuptime.com/blog/post/2026-02-06-telemetrygen-test-traces-pipeline-validation/view)) It's **write-only** — it never queries a backend to confirm the data arrived and became queryable. Verification is left entirely to whatever backend you're using. The standard itself doesn't bundle write+verify, and neither does anything built directly on it.
- **Sentry**: a live-polling dashboard page ("waiting for events..."). Not a CLI or SDK feature — a vendor-hosted UI, and it only works because Sentry is true multi-tenant SaaS: an API key *is* your own project with automatic dashboard access. Already established elsewhere in this investigation's parent doc that this doesn't transplant to sovdev-logger's shared-stack model.
- **Datadog**: `datadog-agent status` (a separate daemon install) reports the *Agent's* local connectivity, not whether your specific application's data arrived and is queryable on the backend.
- **Azure**: Live Metrics (portal, needs login) + `az monitor app-insights query` (a separate CLI install) — two disconnected query tools, not a bundled write-then-verify cycle.
- **GCP**: Logs Explorer (portal, needs login) + `gcloud logging read` (a separate CLI install) — same shape as Azure.
- **Grafana Labs**: `logcli`/`promtool`/`tempo-cli` (separate CLI installs) — also just query tools; this is exactly what "Considered and rejected" above already ruled out wrapping.

**Conclusion**: what's being designed here is genuinely closer to Sentry's approach than anyone else's — a single, zero-install, write-then-verify experience — adapted to a real architectural difference Sentry doesn't have (multiple backends behind one shared, non-multi-tenant stack, so no vendor-hosted live-polling page to lean on). Bundling the verification logic directly into the client library, rather than depending on a portal login or a separately-installed CLI, is the part that's actually new here — every other option surveyed requires one or the other. This strengthens rather than undermines the case for building it.

---

## Current State (checked directly)

- **Grafana Cloud side** already has most of the read-back logic, just not wired to a write step or packaged for external use: `tools/validation/grafana-cloud/query-loki.ts` / `query-prometheus.ts` (LogQL/PromQL over HTTP Basic Auth, via `lib/grafana-cloud-client.ts`), `check-connection.ts` (preflight — validates env vars and that connections work, but doesn't push+verify a specific marker), `probe-otlp-ingest.ts` (a raw HTTP probe with an empty body, not a real sovdev-logger write).
- **UIS side's** existing scripts (`tools/validation/uis/query-loki.sh`, `query-prometheus.sh`, `query-tempo.sh`) shell out to `kubectl run --image=curlimages/curl ... -n monitoring` — Loki/Prometheus/Tempo's own pod images are distroless (no shell, no curl) and their ClusterIP services aren't exposed outside the cluster directly. **A real, simpler alternative was found and verified live this session — see "UIS is reachable over plain HTTP" below.** `kubectl` is not actually required at all.
- No existing tool does the full write→read-back cycle in one invocation against either backend. No packaging (`bin` entry, standalone script) exists for shipping any of this outside the sovdev-logger repo.
- Confirmed in this conversation: both backends are real targets — UIS for the maintainer's own local development/dogfooding, Grafana Cloud for external consumers like ollacrm — and both should be real, switchable modes of the same tool from day one, not a Grafana-Cloud-only v1 with UIS deferred.
- **The write side isn't a new mechanism** — it's `sovdev_initialize()` / `sovdev_log()` / `sovdev_shutdown()` from the same `@terchris/sovdev-logger` package the tool ships inside, using whatever `OTEL_EXPORTER_OTLP_*` env vars are already configured (Grafana Cloud or the local dev otel-collector for UIS). The self-test CLI doesn't reimplement writing — it's a consumer of the library's own existing public API, exactly like any real application would be.

---

## Considered and rejected: wrapping each backend's official vendor CLI

Grafana Labs ships official CLIs (`logcli`, `promtool`, `tempo-cli`) that work against any Loki/Prometheus/Tempo-compatible endpoint — meaning the same three tools could in principle read back both UIS and Grafana Cloud, differing only in connection setup (a `kubectl port-forward` for UIS vs. a hosted URL + token for Grafana Cloud). Azure and GCP have equivalent official CLIs (`az monitor app-insights query`, `gcloud logging read`). A CLI that shelled out to whichever of these applied was considered — and **rejected**, since it reintroduces exactly the burden this whole line of investigation exists to remove: the developer would need `logcli`/`promtool`/`tempo-cli` (or `az`/`gcloud`) actually installed just to run a project-specific health check, on top of everything else.

**[Q7]** — **Decided.** The read side is a thin, native, dependency-free layer instead: each backend's own official **SDK or REST API**, called directly from TypeScript, bundled as an ordinary npm dependency — no external binary, no separate install step. Confirmed this works uniformly across every backend under discussion:
- **Grafana Cloud**: already exactly this shape — `lib/grafana-cloud-client.ts`'s direct HTTP calls to Loki/Prometheus's own APIs.
- **Azure**: `@azure/monitor-query-logs` (current package; predecessor `@azure/monitor-query` is deprecated) runs KQL directly against Log Analytics/Application Insights over REST, authenticated via `@azure/identity`'s `DefaultAzureCredential` — no `az` CLI involved. ([npm: @azure/monitor-query-logs](https://www.npmjs.com/package/@azure/monitor-query-logs))
- **GCP**: `@google-cloud/logging` reads log entries directly via Cloud Logging's REST API, authenticated with a service account JSON key (or ADC) — no `gcloud` CLI involved. `@google-cloud/monitoring` is the metrics equivalent, same pattern. ([npm: @google-cloud/logging](https://www.npmjs.com/package/@google-cloud/logging))

One thing this does *not* unify: **auth shape**, which is a real, per-backend difference, not a detail to abstract away — Grafana Cloud's is a single Basic Auth token; Azure needs an Entra ID service principal (client ID + secret + tenant ID) via `DefaultAzureCredential`; GCP needs a service account JSON key file. The read-*code* is one consistent interface (`readLogs(serviceName, timeRange) → LogEntry[]`); the credential each backend's adapter expects can't be, and shouldn't pretend to be.

### UIS is reachable over plain HTTP — no `kubectl` needed at all

**Verified live against the actual running cluster this session, not assumed.** `kubectl get ingress -A` returns nothing because Rancher Desktop's Traefik uses its own `IngressRoute` CRD (`traefik.io/v1alpha1`), not the standard `networking.k8s.io/v1 Ingress` — checking the wrong resource kind was the earlier mistake. Only **Grafana** has an `IngressRoute` (`HostRegexp` matching `grafana.*`, resolving via `*.localhost` auto-DNS to `127.0.0.1` — this is UIS's own documented, deliberate pattern, confirmed against `urbalurba-infrastructure`'s `contributors/rules/ingress-traefik.md`: only Grafana gets a hostname, everything else is reached through it or via pod-exec). Loki/Prometheus/Tempo have no `IngressRoute` of their own — **but Grafana itself exposes a datasource-proxy API** (`/api/datasources/proxy/uid/<uid>/<native-api-path>`) that forwards to whatever datasource it's configured with, using Grafana's own login, not a separate credential. Tested directly against the live local stack:

```bash
curl -u admin:SecretPassword1 "http://grafana.localhost/api/datasources/proxy/uid/loki/loki/api/v1/query_range" \
  --data-urlencode 'query={service_name=~".+"}' --data-urlencode 'limit=1' -G
# → 200, real Loki data back

curl -u admin:SecretPassword1 "http://grafana.localhost/api/datasources/proxy/uid/prometheus/api/v1/query" \
  --data-urlencode 'query=up' -G
# → 200, real Prometheus data back

curl -u admin:SecretPassword1 "http://grafana.localhost/api/datasources/proxy/uid/tempo/api/search" \
  --data-urlencode 'limit=1' -G
# → 200, valid Tempo response
```

All three signals, confirmed 200 OK with real data, using nothing but `grafana.localhost` + HTTP Basic Auth — the same admin credential this project's own `tools/dashboards/push-dashboard.ts` already uses. **No `kubectl`, no port-forward, no cluster access needed at all.**

Using full Grafana admin credentials here (rather than a scoped-down equivalent to Grafana Cloud's LBAC-restricted token) is intentional, not an oversight — UIS is maintainer-only ([Q5]: the `bin` entry ships to consumers, but `--backend uis` only ever runs against the maintainer's own local devcontainer, never distributed). There's no external party this credential could over-expose data to.

### One shared query client, not two adapters

UIS's Loki/Prometheus/Tempo *are* the same systems Grafana Cloud runs — self-hosted vs. hosted, but the exact same LogQL/PromQL/TraceQL-over-HTTP query API either way, and now confirmed *equally reachable over plain HTTP* for both. `lib/grafana-cloud-client.ts`'s existing HTTP client (or a small generalization of it) can be the **one** implementation both backends use. The only real difference is **base URL + auth shape**, not query logic, not reachability mechanism:
- **Grafana Cloud**: hits Loki/Prometheus/Tempo's own dedicated hosted URLs directly, with a Basic Auth token (Instance ID : ingest/read token).
- **UIS**: hits `http://grafana.localhost/api/datasources/proxy/uid/<loki|prometheus|tempo>/<native-path>`, with Basic Auth (Grafana admin username/password).

This turns Option A's "two internal read-adapters" into **one shared query client plus two different URL-and-credential configs** — both plain HTTP, both Basic Auth, no reachability plumbing (no port-forward to spawn/await, no `kubectl` dependency, no packaging question about whether cluster-access code belongs in a published npm package) on either side.

Azure and GCP adapters are **not being built now** — they stay forward-looking reference until `INVESTIGATE-external-backend-verification.md` decides sovdev-logger actually connects to those backends. This section exists so the research isn't re-done later, matching the parent investigation's own "Azure and GCP" reference section.

---

## Design questions

1. **[Q1]** — **Decided.** An explicit `--backend grafana-cloud|uis` selection must exist — auto-detect alone isn't enough, since the maintainer's own environment can have *both* Grafana Cloud and local UIS credentials configured at once (this is the normal case while developing sovdev-logger itself), and the tool needs to be told which one to actually use, not guess. Auto-detect can still apply when only one set of credentials is present (the common case for an external consumer like ollacrm, who will only ever have the Grafana Cloud vars) — but the explicit flag always wins when both are configured, and is required, not optional, for the maintainer's own dual-backend case.
2. **[Q2]** — **Decided, revised twice.** Backend-specific config types, not one generic shape — and, checked directly against the existing tooling (`tools/validation/grafana-cloud/.env.example`), the Grafana Cloud shape isn't a single flat object: Loki and Prometheus have **different** Instance IDs (`GRAFANA_CLOUD_LOKI_INSTANCE_ID` vs. `GRAFANA_CLOUD_PROMETHEUS_INSTANCE_ID`), so reading back a log *and* a metric needs two `{baseUrl, instanceId}` pairs. The actual shapes: `{lokiUrl, lokiInstanceId, prometheusUrl, prometheusInstanceId, readToken}` for Grafana Cloud vs. `{grafanaUrl, username, password}` for UIS. `readToken` is a separate, dedicated read-only token, not the write token reused — the parent investigation's [Q6] originally simplified to one combined read+write Access Policy, then reverted after Grafana Cloud's own portal UI warned against combining read+write scopes on one policy. **For the first working version, this reuses the existing `GRAFANA_CLOUD_VERIFY_TOKEN` / `GRAFANA_CLOUD_INGEST_TOKEN` (both already provisioned, unscoped, stack-wide — same ones `tools/validation/grafana-cloud/` already uses) rather than minting anything new.** That's fine for the maintainer's own dogfooding, but not something an external consumer like ollacrm should ever hold (unscoped read = can see every onboarded system's data) — giving ollacrm their own LBAC-scoped, per-system read policy is explicitly deferred to a later pass, not a blocker for getting the tool itself working first.
3. **[Q3]** — **Decided.** A regex LBAC selector, e.g. `{service_name=~"^ollacrm-api.*"}` (confirmed Grafana Cloud's LBAC supports regex operators), covering both the real `service_name` and its `-selftest` suffix under one selector set once when the maintainer creates the Access Policy — self-test writes stay isolated from the real dashboard's data.
4. **[Q4]** — **Decided.** Poll every 2s, timeout at 30s for logs, 60s for metrics (Prometheus/Mimir scrape/flush lag) — proposed defaults, accepted as a starting point to refine later from real usage rather than trying to get exact numbers right upfront. A distinct "timed out, may still arrive — try again shortly" message vs. a hard failure message (wrong credential, wrong endpoint) either way — conflating the two reproduces exactly the false "it's broken" signal this whole line of investigation exists to eliminate.
5. **[Q5]** — **Decided.** Bundled as a `bin` entry inside `@terchris/sovdev-logger` itself, not a separate package. `npm install @terchris/sovdev-logger` (which ollacrm already runs) gets them the CLI for free — zero new install step. (The earlier sub-question here — whether `kubectl`-shelling UIS code belongs in the published bundle — is moot: UIS's connection is plain HTTP too, see "UIS is reachable over plain HTTP" above, so there's no cluster-access code to exclude.)
6. **[Q6]** — **Decided.** Plain text by default, matching `query-loki.ts`'s existing convention; a `--json` mode for CI parsing. Four independent lines reported (write-log, write-metric, read-log, read-metric), not one aggregate pass/fail — a failure in just the read half (e.g. a misconfigured LBAC selector) looks completely different from a failure in the write half (e.g. a wrong ingest token), and the diagnostic points at the specific likely cause. Exit code 0 only if all four pass, 1 otherwise — required for the CI-friendly use case this whole line of investigation is built around. If neither backend's env vars are present, or the `--backend` given has none of its required vars set, the tool fails fast with a specific "which vars are missing" message, not a stack trace from whatever HTTP call happens to run first.
7. **[Q8]** — **Decided.** Metrics don't carry a free-text marker the way a log message does — sovdev-logger's metrics are labeled counters/gauges, not strings. Rather than inventing a way to embed a per-run unique value into a metric, the disposable `-selftest` service_name ([Q3]) *is* the marker: the self-test only checks that at least one datapoint exists with `service_name=<the disposable name>` inside the poll window. Nothing else legitimately writes under that exact disposable name, so existence alone is sufficient — no additional uniqueness scheme needed on top of what [Q3] already provides.

---

## Options for the overall shape

### Option A: One command, explicit `--backend` selection, one shared HTTP query client, two URL/auth configs

The direction confirmed in this conversation — one tool for both audiences, both backends, built as a native TypeScript layer rather than a wrapper around any vendor CLI (see [Q7]). Internally: a shared "write a marker, then poll, then report" core, and — since UIS's Loki/Prometheus/Tempo are reachable over plain HTTP too (via Grafana's datasource-proxy, see above) — **one shared HTTP query client** (built from `lib/grafana-cloud-client.ts`'s existing logic), not two separately-implemented adapters and no reachability plumbing on either side. What differs per backend is only the base URL(s) and how the Basic Auth header is built: Grafana Cloud uses its own hosted Loki/Prometheus URLs (each with its own Instance ID) + a shared Instance-ID:token pair reused from the write side; UIS uses `grafana.localhost`'s datasource-proxy path (one URL for all three signals) + a Grafana username:password pair. Backend selection is an explicit `--backend` flag, required whenever both are configured at once, with auto-detect as a convenience when only one is ([Q1]). [Q1]-[Q6], [Q8] above record this option's resolved design questions.

**Pros**: matches what was actually asked for; one query implementation to maintain and document, not two; both backends are plain HTTP + Basic Auth, so the maintainer dogfoods the exact same code path (against UIS) that ships to consumers (against Grafana Cloud) — bugs in the shared logic get caught locally before they'd ever reach ollacrm; genuinely small now — no `kubectl`, no port-forward, no cluster-access code to maintain or decide whether to publish.
**Cons**: still two different auth-header-construction paths to implement (per [Q2]'s decided shapes) — smaller than originally scoped, but not zero implementation surface.

### Option B: Two separate, unrelated scripts

Keep `tools/validation/uis/*` exactly as-is (maintainer-only, stays in this repo, used by hand) and build a *new*, separate, minimal write+read-back tool that only targets Grafana Cloud, shipped in the npm package.

**Pros**: much smaller design surface — no backend abstraction, no auto-detection question, no credential-model unification to work out; ships faster.
**Cons**: doesn't match the direction confirmed this conversation (one tool, both backends); the new Grafana-Cloud-only tool and the existing UIS scripts drift independently over time instead of sharing one "write, poll, report" implementation.

Option A is the intended direction given the maintainer's explicit call this session ("build a real `--backend uis` mode too"); Option B is recorded here as the fallback if [Q1]-[Q6]/[Q8] turn out to cost more than expected once actually scoped into a PLAN.

---

## Recommendation

**Resolved.** Option A, with every design question decided: one shared plain-HTTP query client (with Grafana Cloud's two-Instance-ID/one-token shape vs. UIS's one-URL shape, per [Q2]), backend-specific config types, explicit `--backend` selection required, a regex LBAC selector for the disposable self-test name, 30s/60s poll-with-backoff timeouts, the disposable service_name itself standing in as the metric marker ([Q8]), bundled as a `bin` entry in `@terchris/sovdev-logger`, plain-text output with a `--json` flag and a real exit code. Ready for a single `PLAN-selftest-cli.md` (per [PLANS.md](../../PLANS.md)'s guidance — the pieces here are tightly coupled, not independently shippable, so this doesn't need splitting into ordered sub-plans).

## Next Steps

- [x] Resolve [Q1]-[Q6], [Q8]
- [x] Create and ship [`PLAN-selftest-cli.md`](PLAN-selftest-cli.md)
- [ ] **Deferred, tracked as a real follow-up, not blocking this investigation's closure**: mint ollacrm (and any future external consumer) their own LBAC-scoped, read-only Access Policy before handing them the CLI — the shipped version uses the maintainer's own existing `GRAFANA_CLOUD_VERIFY_TOKEN`, which is unscoped and unsafe to distribute externally as-is. Includes confirming whether Grafana Cloud LBAC (the "Add label selector" control) is actually available on the `urbalurba` stack's plan tier — still unconfirmed.

## See also

- [`INVESTIGATE-developer-first-onboarding.md`](../backlog/INVESTIGATE-developer-first-onboarding.md) — the parent investigation; Option E3 is what this document works out in detail
- `tools/validation/grafana-cloud/lib/grafana-cloud-client.ts` — the existing HTTP query client this CLI's shared Loki/Prometheus/Tempo client would generalize from
- `tools/dashboards/push-dashboard.ts` — this project's own existing precedent for `GRAFANA_URL`/`GRAFANA_USER`/`GRAFANA_PASSWORD`-based Basic Auth against local UIS, the same credential shape the datasource-proxy approach reuses
- `tools/validation/uis/query-loki.sh` and siblings — the older `kubectl run` + disposable-curl-pod pattern this CLI's UIS connection replaces entirely (no `kubectl` at all — see "UIS is reachable over plain HTTP" above)
- `urbalurba-infrastructure`'s `website/docs/contributors/rules/ingress-traefik.md` — UIS's own documented Traefik `IngressRoute`/`*.localhost` pattern, confirming Grafana-only exposure is deliberate, not an oversight
