# 1PRIORITY — the backlog triage

The priority view across all open INVESTIGATE files: what to investigate
next, what can wait, and what's been overtaken by shipped work. A triage
tool, not a roadmap.

## How to use this doc

- **Tier 1** is the queue: the top row is what gets picked up next when the
  maintainer says go. Everything below waits.
- **Tier 2** is real but not urgent — promote when Tier 1 drains.
- **Tier 3** is blocked on a prerequisite — promote when the prereq lands.
- **Tier 4** is investigated future ideas: the INVESTIGATE is written
  (options, Q-IDs, recommendation), but **whether/when to implement is not
  decided**. These wait for the maintainer's decision, not for capacity —
  promote to Tier 1/2 when they say go; they can also stay here
  indefinitely or be rejected (note the rejection, keep the file).
- **Tier 5** is raw ideas: no INVESTIGATE yet.
- **Retire candidates** are investigations likely superseded by shipped
  code: verify the remainder, harvest anything still open into a new
  investigation or Tier 5 idea, then move the file to `completed/` with a
  historical banner.
- Update triggers ([PLANS.md](../../PLANS.md)): new INVESTIGATE lands → tier
  it; one completes → strike it and promote dependents; a child PLAN ships
  → re-rank the parent. Full re-rank quarterly or after every 3 ships.

**Last triaged:** 2026-07-12 — `INVESTIGATE-docusaurus-homepage.md` shipped and moved to `completed/` (real homepage at `/`, four value cards, Languages/Backends logo rows; found mid-implementation that Option D's cost had been overstated — see the investigation's "Post-implementation correction"). `INVESTIGATE-developer-first-onboarding.md` still Tier 1: the current onboarding recipe was written for a maintainer setting up shared infrastructure, not for a customer developer who knows nothing about OTLP/Grafana — a real risk of "this library is bad, I'll just use console.log" if the first-contact experience stays this heavy. `INVESTIGATE-selftest-cli.md` remains Tier 4: works out how to build Option E3's self-test CLI (Grafana Cloud + local UIS), deliberately deferred — doesn't block onboarding ollacrm with what already exists.

---

## Tier 1 — next up

- [`INVESTIGATE-developer-first-onboarding.md`](INVESTIGATE-developer-first-onboarding.md) — the app-facing code is already simple (3 function calls); the entire burden is in hand-producing 6 OTLP env vars, and verification is a console message the developer can't fully trust. Checked how Sentry/Datadog/Grafana Labs solve this: Sentry's DSN validates the "bundled connection string" idea; Grafana Cloud's own "Share externally" public-dashboard feature gives a near-zero-cost way to copy Sentry's "watch it appear live" UX with no credential changing hands at all — the recommended near-term action. Also found Grafana Cloud's Label-Based Access Control (LBAC): one Access Policy per system can combine Write with a label-selector-scoped Read (same `service_name`) — one token, not two, that both writes and reads back only its own data. This resolves the credential-sharing risk that previously made the bespoke self-test CLI (Option E3) feel riskier than the dashboard-link option — now just a build-effort question, evidence-gated rather than risk-gated. Also has forward-looking Azure/GCP research (connection-string shapes, official read-back CLIs) for when those backends are added — see [`INVESTIGATE-external-backend-verification.md`](INVESTIGATE-external-backend-verification.md). 9 open questions need maintainer answers — see the doc.

## Tier 2 — real, not urgent

_(none yet)_

## Tier 3 — blocked

_(none yet)_

## Tier 4 — investigated, undecided

- [`INVESTIGATE-external-backend-verification.md`](INVESTIGATE-external-backend-verification.md) — whether to verify sovdev-logger against Grafana Cloud, Azure Monitor, and/or Google Cloud beyond local UIS, and in what order. Research complete (query APIs, auth models, cost/retention per backend, and TypeScript-vs-bash tooling choice); sequencing is a maintainer values call (cheapest-first vs. production-target-first), not a technical one — see [Q2] in the doc.
- [`INVESTIGATE-selftest-cli.md`](INVESTIGATE-selftest-cli.md) — design for a TypeScript CLI that writes a marker log+metric and reads it back, confirming a sovdev-logger setup actually works, usable by both the maintainer (against local UIS) and an external consumer like ollacrm (against Grafana Cloud). Real complication found: local UIS is only reachable via `kubectl`, not plain HTTP, so this is a genuine two-backend architecture, not a single tool with one config. 6 open design questions, no PLAN yet — explicitly deferred, doesn't block ollacrm's onboarding with today's manual recipe.

## Tier 5 — raw ideas

- Decide whether Go/C#/Rust/PHP restart from scratch or from their archived `terchris/implementation-tests/` state — the one remaining open item from [`INVESTIGATE-multi-language-conformance.md`](../completed/INVESTIGATE-multi-language-conformance.md) (resolved and moved to `completed/`, all four child plans merged); no INVESTIGATE written for this yet, no urgency signal from the maintainer.

## Retire candidates

_(none yet)_
