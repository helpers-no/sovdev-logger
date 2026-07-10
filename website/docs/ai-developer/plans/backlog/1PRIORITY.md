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

**Last triaged:** 2026-07-09 — wiring up Grafana Cloud ingestion surfaced a real bug in sovdev-logger itself (`OTEL_EXPORTER_OTLP_HEADERS` deviates from the OTel spec, collides with the SDK's native parsing, silently drops telemetry for any Basic-Auth-style header). New `INVESTIGATE-otlp-headers-standard-compliance.md` added to Tier 1 — it now blocks `INVESTIGATE-grafana-cloud-validator.md`, which drops to Tier 3.

---

## Tier 1 — next up

- `PLAN-fix-otlp-headers-spec-compliance.md` (separate branch, `fix/otlp-headers-spec-compliance`) — fix a real bug: sovdev-logger's own contract mandated a JSON format for `OTEL_EXPORTER_OTLP_HEADERS` that deviated from the actual OpenTelemetry spec and collided with the OTel SDK's native env-var parsing. **Phase 1 (TypeScript) done and verified live against Grafana Cloud** — Phase 2 (Python port) and Phase 3 (version bump/republish) remain. No longer blocks `INVESTIGATE-grafana-cloud-validator.md`, which is now fully complete.

## Tier 2 — real, not urgent

_(none yet)_

## Tier 3 — blocked

- [`INVESTIGATE-grafana-cloud-validator.md`](INVESTIGATE-grafana-cloud-validator.md) — building the TypeScript verification program for Grafana Cloud. All three query/auth scripts (`query-loki.ts`/`query-tempo.ts`/`query-prometheus.ts`) implemented and confirmed working live via `check-connection.ts` (13/13 checks pass). Blocked on `INVESTIGATE-otlp-headers-standard-compliance.md` landing — ingestion crashes on flush until that bug is fixed.

## Tier 4 — investigated, undecided

- [`INVESTIGATE-external-backend-verification.md`](INVESTIGATE-external-backend-verification.md) — whether to verify sovdev-logger against Grafana Cloud, Azure Monitor, and/or Google Cloud beyond local UIS, and in what order. Research complete (query APIs, auth models, cost/retention per backend, and TypeScript-vs-bash tooling choice); sequencing is a maintainer values call (cheapest-first vs. production-target-first), not a technical one — see [Q2] in the doc.

## Tier 5 — raw ideas

- Decide whether Go/C#/Rust/PHP restart from scratch or from their archived `terchris/implementation-tests/` state — the one remaining open item from `INVESTIGATE-multi-language-conformance.md` (now otherwise fully shipped, all four child plans merged); no INVESTIGATE written for this yet, no urgency signal from the maintainer.

## Retire candidates

_(none yet)_
