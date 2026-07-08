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

**Last triaged:** 2026-07-08 — first investigation's four child plans shipped and merged; second investigation (documentation strategy) accepted, queued for PLAN drafting.

---

## Tier 1 — next up

- [INVESTIGATE-documentation-strategy.md](INVESTIGATE-documentation-strategy.md) — **accepted 2026-07-08.** [`PLAN-005-documentation-restructure.md`](../completed/PLAN-005-documentation-restructure.md) **completed**: `website/docs/general/`, `using/`, `contributor/` now exist (replacing the homepage's long-unfulfilled migration placeholder, structured on the sibling `mimer` project's model), `general/why-otlp.md` makes the general/honest OTLP case, Azure-specific content lives in `using/azure-integration.md`, the root README shrank 387 → 95 lines, `implementation-guide.md` has the diff-against-canonical rule, and `specification/tools/check-doc-consistency.py` catches remote/table drift mechanically going forward. Next: a follow-up plan (not yet created) to migrate `specification/`'s and `docs/`'s remaining prose into `using/`/`contributor/`.

## Tier 2 — real, not urgent

_(none yet)_

## Tier 3 — blocked

_(none yet)_

## Tier 4 — investigated, undecided

_(none yet)_

## Tier 5 — raw ideas

- Decide whether Go/C#/Rust/PHP restart from scratch or from their archived `terchris/implementation-tests/` state — the one remaining open item from `INVESTIGATE-multi-language-conformance.md` (now otherwise fully shipped, all four child plans merged); no INVESTIGATE written for this yet, no urgency signal from the maintainer.

## Retire candidates

_(none yet)_
