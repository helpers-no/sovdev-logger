# Investigate: Can one system's ingest key be stopped from writing data under another system's name?

Whether a system's leaked or misused ingest token can be prevented from writing fabricated data claiming to be a different system, within the one shared Grafana Cloud stack every onboarded system (ollacrm, CI, every future customer) writes into today.

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Completed 2026-07-14 — confirmed real, structural limitation; decided not to fix, accepted as a known risk

**Goal**: Determine whether write-side tenant isolation between systems is achievable within this project's current architecture, and at what cost — not just confirm the gap exists.

**Last Updated**: 2026-07-14

---

## Background — the trigger finding

While documenting the CI-specific credentials (`sovdev-ci-ingest`/`sovdev-ci-verify`) built for the new CI consistency-check gate (see `full-consistency-check.sh`), the maintainer asked directly: is there really nothing stopping one key from writing logs as another system? Initial answer was "no portal-level fix exists" — the maintainer correctly pushed back that this seemed implausible for a production system, which prompted digging into the actual root cause rather than accepting the first answer.

**Confirmed empirically, not assumed**: using `sovdev-ci-ingest`'s real token, a log entry was written claiming `service_name="totally-different-spoofed-service"` — a name with no relationship to that token's intended use. Confirmed landing in Grafana Cloud by querying it back with the maintainer's own separate, broader read token.

## Current State — root cause, confirmed via two independent first-party sources

**It's not a missing checkbox — it's how Loki/Mimir/Tempo's multi-tenancy actually works.** Their real isolation boundary is the `X-Scope-OrgID` tenant header, not labels. Within one tenant, a label like `service_name` is just data attached to a stream — never an access-control boundary. Every Access Policy in this project (`ollacrm-ingest`, `sovdev-ci-ingest`, `sovdev-logger-ingest`, every future customer's own ingest key) operates inside the exact same single tenant — this project's one "urbalurba" Grafana Cloud stack.

Confirmed by:
- The portal's own UI text, seen while configuring `ollacrm-verify`'s label selector: *"Available only with read permissions for metrics and logs."*
- [Grafana's LBAC docs](https://grafana.com/docs/grafana-cloud/security-and-account-management/authentication-and-permissions/access-policies/label-access-policies/): *"Label selectors for access policies can only be used with read permission for metrics and logs."*
- [Grafana Enterprise Metrics/Logs docs](https://grafana.com/docs/enterprise-metrics/latest/manage/tenant-management/lbac/): *"GEM does not enforce label-based access control on the write requests... a `metrics:write` scope... allows clients to push any metrics without restrictions regarding the labels."* (GEL states the identical thing for `logs:write`.)

**Consequence**: any ingest token in this project, if leaked or misused, can write fabricated data claiming to be *any* system in the shared stack — not just its own. **Read-side isolation is unaffected** — every `*-verify` token stays correctly LBAC-scoped to just its own data (confirmed this session for both `ollacrm-verify` and `sovdev-ci-verify`, including the regex-vs-exact-match fix). The "one token per system, contained blast radius" story this project has told itself (`using/onboarding/index.md`'s original "every system's blast radius stays contained to its own token") only ever held for reads — corrected in that doc as part of this investigation.

## Options

### Option A: Separate Grafana Cloud stack per system — genuine tenant isolation

Grafana's own architecture guidance describes exactly this project's situation:

> *"Multiple production stacks are recommended when the goal is complete isolation among departments or teams... typically used by resellers and managed service providers that have customers who shouldn't have access to one another's data."* — [Stack architecture recommendations](https://grafana.com/docs/grafana-cloud/security-and-account-management/cloud-stacks/stack-architecture-guidance/)

**Pros**: real, structural isolation — a system's ingest key literally cannot write into a different tenant at all, not just discouraged from it by convention.
**Cons**: contradicts this project's own foundational design decision, already built and in production use — "one stack, one dashboard... differentiated only by `service_name`" (`using/onboarding/index.md`'s stated principle since the very first system onboarded). Grafana's own docs warn the other direction too: *"cross-stack correlation won't function properly"* across stacks — the single unified dashboard this whole onboarding recipe is built around would stop working as designed. Onboarding a new system would also require provisioning an entire new Grafana Cloud stack, not just two Access Policies — a meaningfully heavier operation.

### Option B: Accept as a known, documented limitation (chosen)

**Pros**: no architecture change — keeps the single-dashboard design already built, documented, and proven in production (ollacrm onboarded, the new CI consistency-check gate built directly on top of it). The actual risk is bounded: a leaked ingest token can inject fabricated/junk data under another system's name — a data-integrity/noise problem, and one that's discoverable (an anomalous, unexplained `service_name` appearing in the shared dashboard is a visible signal, not a silent one) — but it cannot read any other system's real data.
**Cons**: requires being honest that the isolation story only covers reads, not writes — silently letting the original "blast radius stays contained" claim stand uncorrected would have been actively misleading to future onboarded systems.

### Option C: Client-side mitigation (rejected as ineffective)

E.g. `sovdev-logger` itself refusing to log under an unexpected `service_name`. Doesn't protect against a malicious token-holder, who controls the client entirely and can trivially bypass any check baked into the library — only guards against accidental misconfiguration, a different and lesser concern than a leaked/malicious credential.

---

## Recommendation

**Option B.** The cost of Option A — losing the single shared dashboard this project's entire onboarding design is built around, plus a meaningfully heavier per-system onboarding operation — is disproportionate to the actual risk at this project's current scale (a handful of systems, a maintainer able to notice an anomalous `service_name` appearing in the shared dashboard). The sensitive direction — read confidentiality — is already properly protected via LBAC on every `*-verify` token.

## Decision

**Confirmed by the maintainer, 2026-07-14: do not pursue Option A.** Accepted as a known, documented limitation. Revisit only if the number of independent, mutually-untrusted systems grows large enough to change this cost/benefit balance, or if a real incident (an ingest token actually used to inject fabricated data maliciously) occurs.

## What was done

- [x] Root cause confirmed empirically (spoofed write test) and via two independent first-party Grafana sources — not left as a guess
- [x] `contributor/testing/grafana-cloud.md` — added "Known limitation: write tokens aren't service_name-restricted" section with full sourcing
- [x] `using/onboarding/index.md` — corrected the "blast radius stays contained" claim to be explicit about read-only isolation
- [x] Decision recorded here — no child `PLAN-*.md` needed, nothing further to build

## Files Modified

- `website/docs/contributor/testing/grafana-cloud.md`
- `website/docs/using/onboarding/index.md`
