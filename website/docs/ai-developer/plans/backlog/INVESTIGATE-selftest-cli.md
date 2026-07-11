---
mdx:
  format: md
---

# Investigate: A self-test CLI that writes then reads back logs/metrics, usable by both the sovdev-logger maintainer and an external developer

Spun off from `INVESTIGATE-developer-first-onboarding.md`'s Option E3, this works out the actual design of a TypeScript self-test CLI — one tool, pluggable across Grafana Cloud and local UIS backends, runnable by both the sovdev-logger maintainer and an external consumer like ollacrm.

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Backlog — design not yet decided; deliberately deferred, not blocking ollacrm

**Goal**: A single TypeScript command that initializes sovdev-logger, emits one uniquely-marked log + metric, reads both back, and reports a clear PASS/FAIL with a specific diagnostic — runnable by the maintainer against local UIS and by an external consumer against Grafana Cloud, same tool either way.

**Last Updated**: 2026-07-11

---

## Why this is its own investigation, not folded into the parent

`INVESTIGATE-developer-first-onboarding.md`'s Option E3 already proposed this CLI and reasoned about *whether* to build it (verdict there: yes, worth building — Grafana Cloud's Label-Based Access Control (LBAC) resolved the credential-sharing risk that was the main objection, see that doc's [Q6]). This document is scoped narrower and more concrete: *how* to build it — and a first design pass surfaced a real complication the parent investigation hadn't caught. Local UIS's Loki/Prometheus/Tempo aren't reachable over plain HTTP at all: every existing query script (`tools/validation/uis/query-loki.sh` and its siblings) shells out via `kubectl run` against in-cluster services, something only this project's own devcontainer has access to. "One CLI, two backends" is a real architectural fork, not just a different URL — worth its own investigation rather than a sub-section.

**Explicitly deferred**: this is written now so the design thinking isn't lost, but nothing here blocks onboarding ollacrm today — they proceed with the existing manual write+read-back validation recipe (`using/onboarding/index.md` step 5) in the meantime. We can help the ollacrm developer get their code working with what already exists; this CLI is a later improvement, not a prerequisite.

---

## Current State (checked directly)

- **Grafana Cloud side** already has most of the read-back logic, just not wired to a write step or packaged for external use: `tools/validation/grafana-cloud/query-loki.ts` / `query-prometheus.ts` (LogQL/PromQL over HTTP Basic Auth, via `lib/grafana-cloud-client.ts`), `check-connection.ts` (preflight — validates env vars and that connections work, but doesn't push+verify a specific marker), `probe-otlp-ingest.ts` (a raw HTTP probe with an empty body, not a real sovdev-logger write).
- **UIS side's** equivalents (`tools/validation/uis/query-loki.sh`, `query-prometheus.sh`, `query-tempo.sh`) are bash scripts that shell out to `kubectl run --image=curlimages/curl ... -n monitoring` — Loki/Prometheus/Tempo's own pod images are distroless (no shell, no curl) and aren't exposed outside the cluster. **This only works from a machine with `kubectl` configured against this project's own Kubernetes cluster** (the devcontainer auto-configures `KUBECONFIG` from `/workspace/.devcontainer.secrets/.kube/config`). An external consumer's laptop or CI runner has neither the cluster access nor the config.
- No existing tool does the full write→read-back cycle in one invocation against either backend. No packaging (`bin` entry, standalone script) exists for shipping any of this outside the sovdev-logger repo.
- Confirmed in this conversation: both backends are real targets — UIS for the maintainer's own local development/dogfooding, Grafana Cloud for external consumers like ollacrm — and both should be real, switchable modes of the same tool from day one, not a Grafana-Cloud-only v1 with UIS deferred.

---

## Design questions

1. **[Q1]** How does the tool know which backend to target? Two real shapes:
   - Explicit flag (`sovdev-selftest --backend grafana-cloud|uis`) — unambiguous, one more thing the developer has to know and get right.
   - Auto-detect from environment (Grafana Cloud read-credential env vars present → Grafana Cloud; `kubectl` on `PATH` + a reachable `KUBECONFIG` → UIS) — removes a decision for an external consumer (they'll only ever have the Grafana Cloud vars set, so it "just works"), but needs an explicit tie-breaker for the maintainer's own devcontainer, where both could technically be reachable at once.
2. **[Q2]** The read credential shape differs completely per backend — does the tool's internal interface abstract that, or does each backend just get its own separate config block? Grafana Cloud's read side is an HTTP Basic Auth token (ideally LBAC-scoped to one `service_name`, per the parent investigation's [Q6]). UIS's read side is `kubectl` + the devcontainer's own kubeconfig — not a portable secret at all, and not something an external consumer could ever hold. These are two different trust models, not two flavors of one credential; the interface needs to accommodate that rather than pretend they're unified.
3. **[Q3]** Disposable service_name vs. the real one, and how that interacts with an LBAC-scoped read token. Following `using/onboarding/index.md` step 5's existing convention, self-test writes should use a disposable, suffixed name (e.g. `<service_name>-selftest`) so repeated runs don't pollute the real dashboard. But if the maintainer mints a read-only Access Policy scoped to the exact label `{service_name="ollacrm-api"}`, a `-selftest`-suffixed write falls outside that selector and the read-back half fails — not because anything is broken, but because the scoping doesn't cover it. Two ways to reconcile: (a) mint the LBAC selector as a regex (`{service_name=~"^ollacrm-api.*"}`, confirmed Grafana Cloud's LBAC supports regex operators) covering both names, or (b) write the self-test under the exact real service_name and accept a small amount of marker-log noise in the real dashboard. Leaning toward (a), not decided.
4. **[Q4]** Ingestion isn't instant — how long does the tool wait, and how does it distinguish a timeout from a real failure? Grafana Cloud logs can appear near-immediately but Prometheus/Mimir metrics lag behind scrape/flush intervals; local UIS's latency for this specific purpose hasn't been measured. Needs a poll-with-backoff loop (not one immediate query) and a message that clearly separates "timed out, may still arrive — try again shortly" from a hard failure (wrong credential, wrong endpoint) — conflating the two reproduces exactly the false "it's broken" signal this whole line of investigation exists to eliminate.
5. **[Q5]** Distribution — ship inside `@terchris/sovdev-logger` itself as a `bin` entry, or as a separate package? Carried over from [Q7] in the parent investigation. Bundling means `npm install @terchris/sovdev-logger` (which ollacrm already runs) gets them the CLI for free — zero new install step. The alternative (a separate `@terchris/sovdev-logger-cli` package, or "clone this repo") adds friction for exactly the audience — "a developer who should know nothing beforehand" — this whole line of investigation exists to serve. Open sub-question: is it acceptable for a `kubectl`-shelling UIS code path to ship inside a package meant for production consumers, or should that path be excluded from the published npm bundle (UIS support only ever matters for the maintainer, who has the full repo anyway)?
6. **[Q6]** What does PASS/FAIL output actually look like? Four independent signals to report (write-log, write-metric, read-log, read-metric), not one aggregate pass/fail — a failure in just the read half (e.g. a misconfigured LBAC selector) looks completely different from a failure in the write half (e.g. a wrong ingest token), and the diagnostic should point at the specific likely cause. Also: plain text good enough, or a `--json` mode for CI parsing, matching `query-loki.ts`'s existing `--json` convention?

---

## Options for the overall shape

### Option A: One command, backend auto-detected, shared core with two internal read-adapters

The direction confirmed in this conversation — one tool for both audiences, both backends. Internally: a shared "write a marker, then poll a pluggable read-adapter, then report" core, with a `GrafanaCloudReadAdapter` (HTTP) and a `UisReadAdapter` (`kubectl run`) implementing the same interface. [Q1]-[Q6] above are this option's real design questions.

**Pros**: matches what was actually asked for; one thing to maintain and document; the maintainer dogfoods the exact same "write, poll, report" code path (via the UIS adapter) that ships to consumers (via the Grafana Cloud adapter), so bugs in the shared logic get caught locally before they'd ever reach ollacrm.
**Cons**: real design surface — two credential models, an auto-detection tie-breaker, and a packaging question about whether `kubectl`-shelling code belongs in a published npm package at all. Not a small tool.

### Option B: Two separate, unrelated scripts

Keep `tools/validation/uis/*` exactly as-is (maintainer-only, stays in this repo, used by hand) and build a *new*, separate, minimal write+read-back tool that only targets Grafana Cloud, shipped in the npm package.

**Pros**: much smaller design surface — no backend abstraction, no auto-detection question, no credential-model unification to work out; ships faster.
**Cons**: doesn't match the direction confirmed this conversation (one tool, both backends); the new Grafana-Cloud-only tool and the existing UIS scripts drift independently over time instead of sharing one "write, poll, report" implementation.

Option A is the intended direction given the maintainer's explicit call this session ("build a real `--backend uis` mode too"); Option B is recorded here as the fallback if [Q1]-[Q6] turn out to cost more than expected once actually scoped into a PLAN.

---

## Recommendation

Not resolved yet — that's the point of deferring this. When this investigation is picked back up: work through [Q1]-[Q6] to a concrete decision each, then write a PLAN (likely a single `PLAN-selftest-cli.md`, per [PLANS.md](../../PLANS.md)'s guidance — the pieces here are tightly coupled, not independently shippable, so this doesn't need splitting into ordered sub-plans).

## Next Steps

- [ ] Not blocking: ollacrm proceeds with the existing manual write+read-back validation recipe (`using/onboarding/index.md` step 5) until this ships
- [ ] Resolve [Q1]-[Q6] when there's bandwidth to actually design this
- [ ] Confirm whether Grafana Cloud LBAC is actually available on the `urbalurba` stack's plan tier (carried over from the parent investigation's [Q6] — docs didn't confirm plan-tier availability)
- [ ] Create `PLAN-selftest-cli.md` once the design questions above are resolved

## See also

- [`INVESTIGATE-developer-first-onboarding.md`](INVESTIGATE-developer-first-onboarding.md) — the parent investigation; Option E3 is what this document works out in detail
- `tools/validation/grafana-cloud/` — existing Grafana Cloud query/probe tooling this CLI's Grafana Cloud adapter would build on
- `tools/validation/uis/` — existing UIS query tooling (kubectl-based) this CLI's UIS adapter would build on
