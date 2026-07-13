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

**Last triaged:** 2026-07-13 — `INVESTIGATE-context-propagation.md` and its child [`PLAN-context-propagation.md`](../completed/PLAN-context-propagation.md) both shipped and moved to `completed/`: `sovdev_set_context({client_name})` in the TypeScript package, README updates, a "Client" column on the Grafana dashboard, and end-to-end validation against real Grafana Cloud and UIS. Two real bugs found and fixed along the way (the OTLP export path silently dropping `client_name`; a stale cross-reference link), plus an unscoped cleanup (removed 4 redundant, fragile dashboard panels found during the maintainer's own live review). Checking the operator-dashboard idea (Tier 5) then surfaced a real naming problem — "Active Integrations" actually counts distinct `service_name` values, not integrations — which the maintainer asked to generalize into a full terminology review: new [`INVESTIGATE-terminology-review.md`](INVESTIGATE-terminology-review.md) covers every schema field and every dashboard panel title, with real findings beyond the trigger (`session_id` reinvents OTel's own `service.instance.id`; `trace_id` silently means two different things depending on whether a span was active; a couple of smaller naming inconsistencies). Python implementation, Azure/GCP query verification, and the operator dashboard panel are explicitly deferred, tracked below. `INVESTIGATE-otel-dependency-upgrade.md` (from the same [GitHub issue #23](https://github.com/helpers-no/sovdev-logger/issues/23)) still needs a bump-strategy decision. The issue's remaining two items — a `sovdev_test_otlp_connection()` bug (204 misread as failure), and four documentation gaps — have a clear solution already and don't need investigation; ready to go straight to a `PLAN-*.md` whenever picked up. `INVESTIGATE-developer-first-onboarding.md` still Tier 1: the current onboarding recipe was written for a maintainer setting up shared infrastructure, not for a customer developer who knows nothing about OTLP/Grafana — a real risk of "this library is bad, I'll just use console.log" if the first-contact experience stays this heavy.

---

## Tier 1 — next up

- [`INVESTIGATE-developer-first-onboarding.md`](INVESTIGATE-developer-first-onboarding.md) — the app-facing code is already simple (3 function calls); the entire burden is in hand-producing 6 OTLP env vars, and verification is a console message the developer can't fully trust. Checked how Sentry/Datadog/Grafana Labs solve this: Sentry's DSN validates the "bundled connection string" idea; Grafana Cloud's own "Share externally" public-dashboard feature gives a near-zero-cost way to copy Sentry's "watch it appear live" UX with no credential changing hands at all — the recommended near-term action. Also found Grafana Cloud's Label-Based Access Control (LBAC): one Access Policy per system can combine Write with a label-selector-scoped Read (same `service_name`) — one token, not two, that both writes and reads back only its own data. This resolves the credential-sharing risk that previously made the bespoke self-test CLI (Option E3) feel riskier than the dashboard-link option — now just a build-effort question, evidence-gated rather than risk-gated. Also has forward-looking Azure/GCP research (connection-string shapes, official read-back CLIs) for when those backends are added — see [`INVESTIGATE-external-backend-verification.md`](INVESTIGATE-external-backend-verification.md). 9 open questions need maintainer answers — see the doc.
- [`INVESTIGATE-otel-dependency-upgrade.md`](INVESTIGATE-otel-dependency-upgrade.md) — 4 Dependabot alerts (2 high, 2 moderate) against `@opentelemetry/sdk-node` (`^0.55.0`, ~165 minor versions behind), `@opentelemetry/auto-instrumentations-node` (`^0.51.0`, ~27 behind), and `@opentelemetry/core` (a full major version behind, `1.x` → `2.x`); `uuid` is also imported directly in source but was never declared as a direct dependency. None currently exploitable in the one production deployment we've heard from, but that's deployment-specific luck, not a guarantee for other integrators. Real risk: OTel's `0.x` packages can break on a minor bump per semver convention, so this isn't a routine Dependabot auto-merge — needs a deliberate bump strategy, see the doc's 3 options.

## Tier 2 — real, not urgent

_(none yet)_

## Tier 3 — blocked

_(none yet)_

## Tier 4 — investigated, undecided

- [`INVESTIGATE-external-backend-verification.md`](INVESTIGATE-external-backend-verification.md) — whether to verify sovdev-logger against Grafana Cloud, Azure Monitor, and/or Google Cloud beyond local UIS, and in what order. Research complete (query APIs, auth models, cost/retention per backend, and TypeScript-vs-bash tooling choice); sequencing is a maintainer values call (cheapest-first vs. production-target-first), not a technical one — see [Q2] in the doc.

## Tier 5 — raw ideas

- Decide whether Go/C#/Rust/PHP restart from scratch or from their archived `terchris/implementation-tests/` state — the one remaining open item from [`INVESTIGATE-multi-language-conformance.md`](../completed/INVESTIGATE-multi-language-conformance.md) (resolved and moved to `completed/`, all four child plans merged); no INVESTIGATE written for this yet, no urgency signal from the maintainer.
- **New dashboard panel(s) for an "operator" persona** — someone managing the whole fleet (all APIs, all registered frontends/clients), distinct from a single API's own maintainer. Concrete ask: show how many distinct frontends/clients are actively logging. Directly enabled by `client_name` ([`PLAN-context-propagation.md`](../completed/PLAN-context-propagation.md), shipped and merged) — before that field existed there was no data to build this from at all.

  **Core technical risk checked directly against real UIS data, not assumed — it's feasible.** `client_name` is only ever a Loki structured-metadata field, never a Prometheus metric label, so it can't reuse "Active Integrations"' exact PromQL (`count by (service_name)` over `sovdev_operations_total`). But Loki's own metric-query LogQL supports grouping by structured-metadata fields the same way PromQL groups by labels — confirmed empirically: `sum by (client_name) (count_over_time({service_name=~".+"}[10m]))` correctly returned one series per distinct `client_name`, and `count(count by (client_name) (count_over_time({service_name=~".+"}[10m])))` returned `1` (correct — one distinct client in the test data). Same shape as "Active Integrations"' `count(count by (service_name) (...))`, just a Loki datasource + LogQL instead of Prometheus + PromQL.

  **One real, worth-noting difference, also found empirically, not assumed**: "Active Integrations" (Prometheus) currently returns **empty** for the same short-lived test data — its counter has aged out of Prometheus's retention window. A Loki-based `client_name` panel wouldn't have that problem the same way, since it counts actual log lines within an explicit time range rather than relying on a persistent counter — but that cuts both ways: it needs an explicit lookback window (e.g. `$__range`, "clients seen in the last N hours"), not a "have they ever appeared, ever" persistent view, and inherits the same fleet-wide wildcard-selector cost caveat already documented in `INVESTIGATE-context-propagation.md`'s Q8 (a `service_name=~".+"` selector scans every stream in the window, not just matching ones).

  No formal INVESTIGATE written yet — this note is the "checked, feasible, here's the shape" starting point; raised by the maintainer right after validating the `client_name` dashboard column, deliberately deferred until `PLAN-context-propagation.md` was fully closed out, now spot-checked.

## Notes (not triage, just don't want to lose it)

- **Slogan idea, in progress**: something along the lines of *logging for hundreds of frontends and thousands of APIs* — echoes the actual driving use case behind `INVESTIGATE-context-propagation.md` (ollacrm: "gather logs from hundreds of APIs and many clients... filter out one client... across many APIs"). Not decided/finalized, just parking it here.

- **Two-customer framing, in progress**: sovdev-logger has two distinct customers, and both must be happy at once, not traded off against each other.
  - **The developer** — just wants to log from her application. Wants this simple: one `sovdev_log()` call, zero-effort metrics/traces, nothing extra to think about unless she needs it.
  - **The operator** — manages *all* the logs, across *all* the applications, and by extension needs visibility into all the developers/teams producing them. Wants the fleet-wide view: which API, which client, how many are actually logging, where the errors are.
  - This isn't just a slogan angle — it's already a real design principle behind decisions made in `PLAN-context-propagation.md`: `client_name` is entirely optional/additive (Q9) *specifically* so the developer who doesn't care about fleet management never has to touch it, while the operator gets fleet-wide filtering once a service opts in. The still-open "operator dashboard panel" idea (Tier 5 above) is the operator-side half of this same framing — a developer-facing feature (`client_name`) that only pays off once there's an operator-facing view built on top of it.

## Retire candidates

_(none yet)_
