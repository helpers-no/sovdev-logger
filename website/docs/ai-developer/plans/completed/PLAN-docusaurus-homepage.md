---
mdx:
  format: md
---

# Plan: Build the docs site's real homepage

Gives the docs site a true, bare-layout homepage at `/` — hero, values, languages, backends — moving the existing "About" doc to `/about` rather than embedding the hero inside the docs theme's chrome, which is what Option C as originally scoped turned out to still look like.

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Completed

**Investigation**: [INVESTIGATE-docusaurus-homepage.md](INVESTIGATE-docusaurus-homepage.md) — Option C as originally scoped, revised mid-implementation (see Phase 1)

**Goal**: `/` is a true, bare `src/pages/index.tsx` homepage (hero, narrative, "Who Do You Write Logs For?" callout card, four value cards, Languages and Backends badge rows with real logos) — no docs sidebar/breadcrumb chrome around it. The former "About" doc content moved to `/about`; `general/`, `using/`, `contributor/` are completely unaffected.

**Last Updated**: 2026-07-12

---

## Problem Summary

`docs/index.md` was a plain Markdown "About" page with no visual identity — see `INVESTIGATE-docusaurus-homepage.md` for the full comparison against mimer's homepage. Also see Phase 1 below for a real correction found during implementation: embedding a hero inside the docs plugin's own index page (Option C as originally written) still renders through the standard doc-page theme — sidebar, breadcrumbs, TOC rail, pagination footer — so it never actually looked like a real homepage. The fix that shipped keeps all the upside of Option C (no `routeBasePath` change, `general/`/`using/`/`contributor/` untouched) while getting a truly bare page: only the single "About" document's `slug` moved, from `/` to `/about`, freeing `/` for a real `src/pages/index.tsx`.

---

## Phase 1: Build the hero, discover and fix the docs-chrome problem — DONE

### Tasks

- [x] 1.1 Renamed `website/docs/index.md` → `website/docs/index.mdx`, built `HomepageHero` (`website/src/components/HomepageHero/`), embedded it at the top of the doc page — this is what Option C originally specified.
- [x] 1.2 **Found the doc-chrome problem**: after building, the hero rendered inside the standard docs theme (sidebar, breadcrumbs, TOC, pagination) — visibly not "a real homepage" like mimer's, which uses a bare `@theme/Layout` with no docs plugin wrapping it at all.
- [x] 1.3 **Verified a fix with a test build before committing to it**: changed the About doc's frontmatter `slug: /` → `slug: /about` and added a genuine `website/src/pages/index.tsx` (bare `Layout`, no sidebar). Confirmed via a real build that `/`, `/about`, and `/general/` all resolve correctly with zero broken links — `routeBasePath: '/'` stays exactly as-is for every other page; only the one About document's URL moved.
- [x] 1.4 Renamed the About doc `website/docs/index.mdx` → `website/docs/about.md` (plain Markdown again — it no longer needs JSX now that the hero moved to the real homepage), removed the `HomepageHero` import from it.

### Validation

`npm run build` clean, confirmed via grep against the built HTML that the hero's actual content (not just a successful build) rendered on `/`.

---

## Phase 2: Values grid (revised scope) — DONE

Originally scoped as a three-card `general`/`using`/`contributor` navigation grid. **Revised**: the maintainer decided doc navigation didn't need its own homepage section (the hero's buttons + the sidebar already cover it) — instead, `HomepageValues` (renamed from the originally-planned `HomepageFeatures`) is four cards about *why* the project is built the way it is:

### Tasks

- [x] 2.1 Built `website/src/components/HomepageValues/` — four cards: 🔓 **Sovereign**, 🌐 **Open**, 🔭 **OpenTelemetry-native**, 🧩 **Consistent** (the fourth added after the maintainer asked for a card about structured logging making fleet-wide monitoring possible, grounded in `general/why-consistent-logging.md`'s existing argument).
- [x] 2.2 Rendered `HomepageValues` on the new `src/pages/index.tsx`.

### Validation

`npm run build` clean; confirmed via grep that all four cards' text rendered.

---

## Phase 3: "Who Do You Write Logs For?" callout card — DONE

### Tasks

- [x] 3.1 Added a card section to `src/pages/index.tsx` (mimer-oath-card-style: `card__header` + `card__body`), linking out to the full text's canonical location in `typescript/README.md` on GitHub — not duplicated on the docs site, per `INVESTIGATE-readme-vs-docusaurus-policy.md`'s "canonical, not duplicated" rule.
- [x] 3.2 This supersedes the smaller, separately-proposed `general/index.md` paragraph raised earlier in the session — one placement, on the real homepage, not two.

### Validation

`npm run build` clean; confirmed the card's text and GitHub link render.

---

## Phase 4 (added): Languages and Backends badge rows with real logos — DONE

Not in the original plan — added after the maintainer asked for logos representing what's actually shipped vs. planned/theoretical.

### Tasks

- [x] 4.1 Built a shared `website/src/components/HomepageBadgeRow/` component: items with a `logo` render as a large icon-chip (same `2.5rem` scale as `HomepageValues`' emoji, at the maintainer's explicit request — matched, not guessed); items without one render as a plain text badge.
- [x] 4.2 Sourced real logo assets, not generated art (per this org's AI-reglement flag on AI-generated external imagery, raised earlier this session): TypeScript, Python, and Grafana from Simple Icons (CC0-licensed, official brand marks, recolored with each project's real brand color); UIS's actual logo fetched from its own real public site (`uis.sovereignsky.no/img/logo.svg`).
- [x] 4.3 **Languages row**: TypeScript and Python get logos + a "success" tone (the two real, shipped implementations); Go/C#/Rust/PHP stay plain text ("planned").
- [x] 4.4 **Backends row**: UIS and Grafana Cloud get logos + a "success" tone and a "verified" label (the only two backends actually validated end-to-end today, confirmed against `INVESTIGATE-external-backend-verification.md`); Azure Monitor/Datadog/New Relic/Honeycomb/self-hosted stay plain text (OTLP-compatible in principle, not yet verified) — this corrected an accuracy gap the first draft of this row had (it listed all backends as equally supported).

### Validation

`npm run build` clean; confirmed all four logo files render in the built HTML at the correct size.

---

## Acceptance Criteria

- [x] `/` is a true bare-layout homepage (hero, narrative, callout card, 4 value cards, Languages/Backends rows) — no docs sidebar/chrome
- [x] `/about` carries the former "About" doc content; `general/`, `using/`, `contributor/` are unaffected — confirmed via build, no `routeBasePath` change anywhere
- [x] `npm run build` passes clean at every step
- [x] Maintainer visually confirmed the page locally via `npm run serve` across multiple rounds of feedback
- [x] Logos are real, sourced assets (Simple Icons CC0 + UIS's own site) — not AI-generated art
- [ ] `INVESTIGATE-docusaurus-homepage.md` and `1PRIORITY.md` updated to reflect this shipped, and the Option-D cost re-assessed (next step, immediately following this plan's completion)

## Files Modified

- `website/docs/index.md` → `website/docs/about.md` (moved, `slug: /about`)
- `website/src/pages/index.tsx` (new — the real homepage)
- `website/src/components/HomepageHero/` (new)
- `website/src/components/HomepageValues/` (new, renamed from the originally-planned `HomepageFeatures`)
- `website/src/components/HomepageBadgeRow/` (new, not in the original plan)
- `website/static/img/sovdev-logo.svg`, `typescript.svg`, `python.svg`, `grafana.svg`, `uis-logo.svg` (new)
- `website/docs/ai-developer/plans/completed/INVESTIGATE-docusaurus-homepage.md` (moved from `backlog/`)
- `website/docs/ai-developer/plans/backlog/1PRIORITY.md`
