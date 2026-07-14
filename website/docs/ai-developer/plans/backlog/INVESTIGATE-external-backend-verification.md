# Investigate: Verifying sovdev-logger against external OTLP backends (Grafana Cloud, Azure Monitor, Google Cloud)

Local UIS verification (Loki/Tempo/Prometheus via `kubectl run curlimages/curl` inside a local Kubernetes cluster) proves the TypeScript and Python implementations emit correct OTLP telemetry. It does not prove that telemetry survives contact with any real external backend — and each candidate backend turns out to need its own, genuinely separate verification tooling, not a shared abstraction.

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Backlog — 2 of 4 backends done, Azure/GCP sequencing still pending

**Real verification status, checked directly (2026-07-14)**: **UIS** (local) and **Grafana Cloud** both have real, working verification tooling today — `sovdev-selftest --backend uis`, `sovdev-selftest --backend grafana-cloud`, and the fuller `tools/validation/grafana-cloud/full-consistency-check.sh`. **Azure Monitor** and **Google Cloud** remain research-only — no OTLP export or verification tooling exists for either; `sovdev-selftest` has no `--backend azure`/`--backend gcp` option at all. The only real open question is Azure vs. GCP sequencing, not "verify 3 backends" as this doc's title implies.

**Goal**: Decide whether/when to build Azure Monitor and/or Google Cloud verification tooling and documentation, and in what order — driven by two distinct motivations that pull in different directions (see [Q2](#questions-to-answer)):
1. A **low-friction on-ramp** for people who don't want to run Kubernetes locally just to try the library (Grafana Cloud's free tier — already shipped, this motivation is satisfied).
2. **Proof against the real production target** — `website/docs/using/azure-integration.md` already documents Azure Monitor/Application Insights as sovdev-logger's actual intended production backend, not a hypothetical. This motivation is still unmet.

**Last Updated**: 2026-07-14

**Referenced by**: [`INVESTIGATE-context-propagation.md`](../completed/INVESTIGATE-context-propagation.md)'s **[Q12]** (shipped — see `PLAN-context-propagation.md`) — the `client_name` context field is emitted backend-agnostically, since Azure Monitor and Google Cloud (this doc's scope) are on the roadmap for the same fleet-wide filtering need, not just Grafana Cloud/UIS.

---

## Questions to Answer

1. **[Q1]** Can any verification tooling be shared across backends, the way `query-loki.sh`/`query-tempo.sh`/`query-prometheus.sh` share a common shape today? — **Answered by research: no.** Ingestion is converging on OTLP across all three (Grafana Cloud, Azure, Google Cloud increasingly accept OTLP directly), but the *query-back* side is fully divergent: three different query languages (LogQL/PromQL/Tempo-search vs. KQL/PromQL vs. Cloud Logging filter/PromQL/Cloud Trace API), three different auth models (Basic Auth vs. Entra ID OAuth2 vs. GCP IAM/ADC). Each backend earns its own script set and its own doc page, same shape as `uis.md` — see [Current State](#current-state).
2. **[Q2]** Grafana Cloud is technically the cheapest and closest to what we already know (same OSS query APIs, just hosted) — but Azure is the actual real-world production target per existing docs. Does "cheapest to build" or "most representative of production" drive the sequencing? — **Open.**
3. **[Q3]** Is Azure Monitor's native OTLP ingestion (currently **preview**, per research) stable enough to build verification tooling against now, or should this wait for GA to avoid churn as endpoint URLs/table schemas shift? — **Open.**
4. **[Q4]** Do all three backends get full treatment (dedicated query scripts + doc page, mirroring `uis.md`), or does Grafana Cloud get lighter treatment as "just an alternative endpoint for the same local-dev-style verification" while Azure/Google get heavier treatment as "this is what a real deployment must prove"? — **Open.**
5. **[Q5]** Should new verification tooling be written in TypeScript (using official SDKs where they exist) instead of bash+curl+jq, given every bug found in `query-loki.sh` this session traced back to bash's lack of real JSON handling? — **Answered by research: yes, TypeScript wins regardless of backend.** See [SDK/tooling research](#sdktooling-research-typescript-vs-bash) below. Whether to also retroactively rewrite the now-working `query-loki.sh`/`query-tempo.sh`/`query-prometheus.sh` in TypeScript is a separate, lower-priority question — they work today; this matters most for new tooling.

---

## Current State

Confirmed via three parallel research passes (one per backend), not assumed. Summary comparison:

| | **Grafana Cloud** | **Azure Monitor** | **Google Cloud** |
|---|---|---|---|
| **Ingestion** | One OTLP gateway URL, all 3 signals | OTLP ingestion is **preview**; separate endpoints per signal via an Application Insights resource | Unified Telemetry (OTLP) API at `telemetry.googleapis.com`, auto-appends per-signal paths |
| **Query: logs/traces** | Same LogQL (`/loki/api/v1/query_range`) and Tempo search/`/api/traces/{id}` APIs as self-hosted, just hosted at different hostnames | KQL against a Log Analytics workspace (`OTelLogs`/`OTelTraces` tables), via the Logs Query REST API or SDK | Cloud Logging filter language (`entries.list`); Cloud Trace API **v1** (read-only, separate from the write-only v2 API) |
| **Query: metrics** | Same PromQL API as self-hosted, hosted Mimir | **PromQL**, but against a separate Azure Monitor workspace — a different query surface from the KQL side, not unified | PromQL via Managed Service for Prometheus (`projects.location.prometheus.api.v1.query`); the older MQL is being phased out |
| **Auth** | HTTP Basic Auth — a numeric Instance ID per signal (Logs/Traces/Metrics, tracked separately) as username, a scoped Cloud Access Policy token as password | Microsoft Entra ID (Azure AD) OAuth2 client-credentials flow + IAM role assignments (`Monitoring Metrics Publisher`, `Log Analytics Reader`); no simple API-key path for real workspaces | GCP service account + IAM roles, Application Default Credentials — **one auth story** covering logs, traces, and metrics alike |
| **CLI option** | Plain `curl` with Basic Auth — closest to a drop-in replacement for our `kubectl run curlimages/curl` pattern | `az monitor log-analytics query` covers KQL (logs/traces); no CLI found for PromQL against an Azure Monitor workspace — needs raw REST + bearer token | `gcloud logging read` covers logs; traces/metrics need `curl` + `gcloud auth print-access-token` (no dedicated CLI subcommand for reads) |
| **Retention / cost (free tier)** | 14-day retention; 10K active series, 50GB logs/mo, 50GB traces/mo free — generous for repeated test runs, no credit card | Preview feature; cost is per-GB ingested into Log Analytics — repeated CI runs accumulate real cost, no documented free allowance found | Usage-based, cheap at test scale (Logging $0.50/GiB after 50GiB free; Trace $0.20/M spans after 2.5M free) — a disposable/sandbox GCP project is recommended for repeated CI runs |
| **Notable risk** | None significant found | **Preview status** — endpoint URL formats and table schemas may still change; Entra RBAC propagation can take minutes (transient 403s) | Cloud Trace v1 API read access is sometimes restricted by org policy; must build metrics tooling on PromQL, not MQL, since MQL is being deprecated |

Full per-backend detail (ingestion paths, exact endpoint shapes, sources) is in the research transcripts referenced by this investigation's originating conversation — not reproduced here to keep this doc pointer-sized; re-run the same research (Azure Monitor Query API + OTLP ingestion, Google Cloud Telemetry API + Logging/Trace/Monitoring query APIs, Grafana Cloud OTLP gateway + per-component query hosts) if this goes stale before a child plan is drafted.

**A secondary finding, not part of the technical comparison**: during both the Grafana Cloud and the Azure SDK research passes, a web fetch returned content mimicking a Røde Kors AI-policy compliance note, in Norwegian — not real vendor documentation, and consistent with a prompt-injection attempt appended to those fetches. Recognized and disregarded both times, not acted on. Noted here because it's now recurred twice across unrelated fetches; worth watching for if this research is re-run.

### SDK/tooling research: TypeScript vs. bash

A fourth research question, prompted by noticing that every bug found in `query-loki.sh` this session (the broken `kubectl exec`/wget approach, the false-success-on-empty-response bug, the fragile sed-based noise stripping that broke on a nondeterministic kubectl banner) traced back to the same root cause: **bash has no real JSON handling.** Since verifying a new backend means writing new validation code regardless, the question became whether an official TypeScript/Node SDK exists per backend that would sidestep this class of bug entirely, not just relocate it.

Confirmed via two further research passes (Azure, Google Cloud) — Grafana Cloud has no SDK story either way (querying is plain LogQL/PromQL/Tempo-search over HTTPS, same for OSS and Cloud):

| Backend | Logs | Traces | Metrics |
|---|---|---|---|
| **Azure** | ✅ `@azure/monitor-query-logs` (KQL, parsed objects). Note: `@azure/monitor-query` is **deprecated** — this is its Microsoft-maintained replacement. | ✅ Same client — traces are just another KQL table (`AppTraces`/`OTelTraces`), no separate mechanism needed | ⚠️ `@azure/monitor-query-metrics` exists but only for Azure-native metric format — **no SDK for PromQL**, raw REST + an `@azure/identity` token |
| **Google Cloud** | ✅ `@google-cloud/logging` (Advanced Query filter syntax, parsed `Entry` objects) | ❌ No official read-side SDK — `@google-cloud/trace-agent` is write-only/deprecated; needs the generic `googleapis` discovery client or raw REST for the v1 read API | ⚠️ `@google-cloud/monitoring` covers the older filter/MQL API — Google's own docs state **"the Prometheus HTTP endpoints aren't available in the Cloud Monitoring language-specific client libraries"** — raw HTTP + `google-auth-library` token |
| **Grafana Cloud** | ❌ No SDK for any signal — plain HTTPS + Basic Auth throughout | | |

**The finding that actually matters**: even in every "gap" cell above (PromQL on both clouds, GCP trace-reads, all of Grafana Cloud), the pattern is never back to bash-style fragility — it's always *official auth library obtains a token → one `fetch()` call → `JSON.parse()`*, which is unremarkable and robust in TypeScript regardless of whether a dedicated SDK wrapper exists. The real lesson isn't "use the SDK when available" — it's "write this in TypeScript, use the SDK where it exists and a plain authenticated `fetch` where it doesn't," since TypeScript's native JSON handling is what actually eliminates the bug class, not the presence of a vendor SDK specifically.

### Prior art already in this repo

- `website/docs/contributor/testing/uis.md` — the completed, working local-UIS verification page this investigation extends the pattern from (setup, `.env` config, `--compare-with` exact-data verification, troubleshooting).
- `website/docs/contributor/testing/index.md` — already lists Azure and Google Cloud as "Planned pages," confirming this was anticipated, just not scoped until now.
- `website/docs/using/azure-integration.md` — already documents Azure Monitor as a real deployment scenario (SDK config, endpoint, auth token), written from the *user* perspective (how to configure it) rather than the *contributor* perspective (how to verify it actually works) this investigation is about.
- `tools/validation/uis/query-loki.sh` / `query-tempo.sh` / `query-prometheus.sh` — the pattern each new backend's scripts would follow structurally (human-readable + `--json` + `--validate` + `--compare-with` modes), even though the query mechanics inside them would be entirely new per backend.

---

## Options

### Option A: Grafana Cloud → Google Cloud → Azure (cheapest/least-risky first)

Sequence by technical complexity and cost: Grafana Cloud first (reuses existing API knowledge, no IAM setup, generous free tier), then Google Cloud (simpler single-IAM auth story than Azure), Azure last (preview status, heaviest auth setup, real per-GB cost).

**Pros:**
- Lowest risk of wasted work — each step is strictly easier than the last, building confidence before the hardest backend
- Grafana Cloud alone satisfies the "no local UIS needed" on-ramp goal quickly

**Cons:**
- Deprioritizes Azure, which is the *actual* production target per `azure-integration.md` — the backend real deployments will use gets verified last, not first
- Azure's preview status is a reason to verify it *now* (catch breaking changes early) as much as a reason to wait

### Option B: Azure first (production-target-driven)

Verify against Azure Monitor first regardless of complexity, since it's the real destination for production sovdev-logger deployments, not a hypothetical or convenience option.

**Pros:**
- Directly answers the question that actually matters for this project: does sovdev-logger really work against the backend Røde Kors deployments will use?
- Surfaces preview-API instability now, while the verification tooling is new and expected to need iteration, rather than after it's calcified

**Cons:**
- Highest cost and setup burden first (Entra service principal, IAM role assignments, real per-GB billing) — more can go wrong before there's any working template to fall back on
- No existing local-analog experience to build from, unlike Grafana Cloud's near-identical query APIs

### Option C: Grafana Cloud only, defer Azure/Google indefinitely

Build the Grafana Cloud on-ramp (cheap, fast, serves real users who don't want local Kubernetes) and treat Azure/Google verification as future work with no committed timeline, revisited only when a concrete production deployment actually needs it proven.

**Pros:**
- Smallest total scope; delivers the friction-reducing on-ramp without committing to the more expensive cloud-verification work
- Avoids sinking effort into Azure's preview API before it's GA

**Cons:**
- Leaves the actual production-backend question ("does this really work against Azure?") unanswered indefinitely — the exact gap this investigation was meant to close per the original request ("we should also get the logging sent to azure and google")

### Option D: Do nothing further — local UIS is sufficient

Treat local UIS verification as the permanent bar; don't build cloud-specific verification at all.

**Pros:**
- Zero additional effort

**Cons:**
- Explicitly contradicts the maintainer's own framing of this thread ("the logger libs must be pushed to a registry... we should also get the logging sent to azure and google")
- Leaves real-backend correctness unverified — local Loki/Tempo/Prometheus behaving correctly doesn't guarantee Azure Monitor's KQL tables or Google's Cloud Logging filters see the same data the same way

---

## Recommendation

No recommendation is made here — **[Q2](#questions-to-answer) is a genuine values call for the maintainer**, not a technical one: whether to sequence by cost/risk (Option A) or by production relevance (Option B) depends on how urgent it is to prove Azure specifically works, versus how valuable the Grafana Cloud on-ramp is for other reasons (contributor experience, avoiding local Kubernetes for casual testing). Both are legitimate; this investigation's job is to make the tradeoff explicit, not resolve it.

If forced to name a lean: Option B's core argument — Azure is the real target, and preview instability is a reason to engage now rather than later — is the stronger technical argument. But Option A's practical benefit (cheap early win, reusable pattern-building before the harder backend) is real too, and Option C remains defensible if there's no near-term Azure production need driving urgency.

---

## Next Steps

- [ ] Maintainer decides sequencing ([Q2](#questions-to-answer)) and Azure preview-readiness tolerance ([Q3](#questions-to-answer))
- [ ] Draft a child PLAN per backend chosen, each scoped like `uis.md`: setup/account creation (external, maintainer does this — not automatable), `.env` config, new TypeScript verification tooling for that backend's actual query API (official SDK where one exists — `@azure/monitor-query-logs`, `@google-cloud/logging` — plain authenticated `fetch` where it doesn't), `--compare-with`-style exact-data verification, troubleshooting
- [x] Grafana Cloud's tooling design is already scoped in detail and now fully shipped: see [`INVESTIGATE-grafana-cloud-validator.md`](../completed/INVESTIGATE-grafana-cloud-validator.md)
- [ ] Update `website/docs/contributor/testing/index.md`'s "Planned pages" list as each backend actually ships
