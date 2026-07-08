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

**Last triaged:** 2026-07-08 — maintainer accepted the recommendation on the first investigation; queued for PLAN drafting.

---

## Tier 1 — next up

- [INVESTIGATE-multi-language-conformance.md](INVESTIGATE-multi-language-conformance.md) — **accepted 2026-07-08.** [`PLAN-001-master-comparison-mode.md`](../completed/PLAN-001-master-comparison-mode.md) **completed** (branch `feature/master-comparison-mode`, committed but not yet merged): `compare-with-master.sh`/`compare-log-files.py` built and verified against the real devcontainer; Loki severity-schema gap closed. Found two real bugs in the current Python implementation (`response_json` dropped, `exception_message` whitespace) for the next plan to fix. Next: `PLAN-002-python-conformance.md` (fix those, re-run until clean, execute the promotion step to flip `README.md`). `PLAN-003` (cut `llm-work-templates/` scaffolding) and `PLAN-004` (schema-driven field-name generation) follow. Python must pass before any other language is attempted.

## Tier 2 — real, not urgent

_(none yet)_

## Tier 3 — blocked

_(none yet)_

## Tier 4 — investigated, undecided

_(none yet)_

## Tier 5 — raw ideas

_(none yet)_

## Retire candidates

_(none yet)_
