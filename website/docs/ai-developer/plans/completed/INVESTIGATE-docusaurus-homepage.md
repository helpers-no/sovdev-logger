---
mdx:
  format: md
---

# Investigate: Give the Docusaurus site a real homepage, modeled on `mimer`

sovdev-logger's docs site has never had a custom homepage — its root route just renders a plain "About" doc page. This investigates whether and how to build one, using the sibling `mimer` project's homepage (hero banner, narrative, feature-card grid) as the reference, without silently reversing the deliberate single-route simplification a prior plan already paid for.

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Completed — shipped via [`PLAN-docusaurus-homepage.md`](PLAN-docusaurus-homepage.md), Option C corrected mid-implementation (see below)

**Goal**: Decide whether sovdev-logger's docs site gets a real, purpose-built homepage — and if so, which of the real implementation shapes (ranging from "richer content on the existing page" to "mimer's full separate-route architecture") fits a much smaller, single-sidebar site without re-introducing a problem a prior plan already fixed once.

**Last Updated**: 2026-07-12 — shipped. See "Post-implementation correction" below: Option C as originally written didn't actually deliver a real homepage; the fix that shipped is cheaper than either C or D as originally scored.

---

## Current State (checked directly)

- **sovdev-logger has no custom homepage today.** `website/docs/index.md` (frontmatter `slug: /`) is a plain Markdown "About" page — a title, three short paragraphs, and a bullet list linking to `general/`, `using/`, `contributor/`. It renders through the standard docs theme, same as every other page — no hero, no visual identity, no call-to-action buttons, no feature grid.
- **This is a deliberate, already-paid-for simplification, not an oversight.** `docusaurus.config.ts` itself documents it inline (lines 50–53): *"This site is only documentation — `docs/index.md` (slug: `/`) is meant to be the actual homepage, not live under `/docs/` behind a separate generic landing page. Requires removing `src/pages/index.tsx` (Docusaurus won't allow two things claiming route `/`)."* `INVESTIGATE-documentation-strategy.md`'s PLAN-006 confirms what actually happened: the site originally had Docusaurus's stock template homepage (`src/pages/index.tsx`, the generic starter component every new Docusaurus project ships with) sitting uselessly alongside a docs plugin that lived under `/docs/` by default — nobody had customized it, it was pure boilerplate. PLAN-006 removed it and set `routeBasePath: '/'` so `docs/index.md` became the real front door instead of a placeholder. That plan also found and fixed a real, painful side effect of exactly this kind of route restructuring: *"every site link written in PLAN-005 and this plan was missing a `/docs/` path segment"* — a whole class of broken links caused purely by moving where docs live relative to the root.
- **`mimer` was already sovdev-logger's explicit structural model once** — `INVESTIGATE-documentation-strategy.md` Option C adapted mimer's `general/`/`system/`/`contributor/` split into sovdev-logger's own `general/`/`using/`/`contributor/`. So "look at mimer's homepage as a model" is a continuation of a pattern already deliberately borrowed once, not a new direction.
- **mimer's homepage is real, custom-built, and reasonably involved** (`mimer/website/src/pages/index.tsx`, checked directly): a hero banner (logo image, title, tagline, three CTA buttons), a narrative paragraph explaining the Mímir-myth name, a callout card ("The Mimer oath," an MDX partial imported into the page), an info-alert pointing at an origin-story blog post, and a `HomepageFeatures` grid — one card per site section, each with an emoji, a "Today"/"Tomorrow" badge, and a description — generated from a single shared `SECTIONS` list (`src/sections.ts`) that **also drives mimer's navbar**, so the homepage cards and the top menu can never drift out of sync.
- **mimer's homepage architecture is only possible because mimer's docs aren't at the root.** mimer runs **nine separate docs-plugin instances** (`systems`, `current-apis`, `current-repos`, `data`, `design`, `landscape`, `background`, `timeline`, `about`) each at its own `routeBasePath`, plus a blog — `src/pages/index.tsx` is free to claim route `/` because nothing else wants it. mimer's homepage is a genuine front-door/router across many distinct, independently-plugin'd sections. sovdev-logger has **exactly one** docs-plugin instance, at `routeBasePath: '/'`, with one sidebar covering three sections (`general/using/contributor`) — a materially smaller information architecture that doesn't have the same "which of nine sections do I want" navigation problem mimer's homepage solves.
- **No new dependencies would be needed for any approach.** sovdev-logger's `website/package.json` already has the identical `react`, `react-dom`, and `clsx` versions mimer's homepage code uses (both required by Docusaurus's classic preset regardless) — this is purely an implementation-effort and information-architecture question, not a tooling gap.
- **No dedicated logo/illustration exists today** — `static/img/` has only `favicon.svg`. A mimer-style hero with a logo mark would need a new visual asset; a text-only hero would not.

---

## Options

### Option A: Do nothing — keep `docs/index.md` exactly as it is

**Pros**: zero cost, zero risk, matches the deliberate PLAN-006 decision exactly, arguably already right-sized for a one-sidebar, three-section site.
**Cons**: no visual identity, no at-a-glance overview, doesn't reflect any of what makes mimer's homepage effective (clear entry points, a name/identity, a sense of "this is a real, cared-for project" on first look).

### Option B: Enhance `docs/index.md` in place — plain Markdown/Infima only, no new components

Keep the file as `.md` (not `.mdx`), no custom React. Use Docusaurus's built-in classic-theme CSS classes (`hero`, `button`, `button--primary`, `card`, `alert`, `badge` — the same Infima classes mimer's own components ultimately render, just written directly in Markdown/HTML instead of through a component) to give the existing content more visual structure: bigger title treatment, a row of button-styled links to `general/`/`using/`/`contributor` instead of a plain bullet list, maybe an `:::info` admonition instead of the info-alert `<div>` mimer hand-rolls.

**Pros**: cheapest real improvement; no MDX conversion, no new files, no build-config changes; still exactly one route, no risk of reopening the `/docs/`-path-segment class of bug PLAN-006 already paid to fix.
**Cons**: doesn't reach mimer's actual polish (no feature-grid cards with hover states, no shared-config-driven consistency between homepage and navbar) — Infima's raw classes look plainer than mimer's purpose-styled components.

### Option C: Enhance `docs/index.md` in place — convert to `.mdx`, embed real components

Rename `docs/index.md` → `docs/index.mdx` (the site's `markdown.format: 'detect'` setting already means `.mdx` files get full JSX support — no config change needed). This unlocks importing and rendering actual React components *inside the docs plugin's existing page*, at the existing route, with zero route restructuring: a small `HomepageHero` component (title, tagline, three CTA buttons to `general/`, `using/`, `contributor/`), optionally a feature-card grid modeled on mimer's `HomepageFeatures` (three cards instead of mimer's nine, one per section) — reusing mimer's actual visual patterns and component shapes, without the multi-plugin architecture that makes them necessary at mimer's scale.

**Pros**: gets meaningfully closer to mimer's actual look and feel (real cards, real hero styling, a component that's easy to keep in sync with the sidebar) while staying inside the exact single-route architecture PLAN-006 deliberately built — no risk of resurrecting the `/docs/`-path-segment bug class, no `src/pages/` route-collision question to resolve.
**Cons**: real, if small, component-authoring work; needs a decision on the hero's visual identity (logo mark vs. text-only, given no logo asset exists today — see [Q2]).

### Option D: Full mimer architecture — separate `src/pages/index.tsx`, docs move off `routeBasePath: '/'`

Actually replicate mimer's structure: docs move to e.g. `routeBasePath: '/docs'` (or split into multiple plugin instances mirroring `general`/`using`/`contributor`, mimer-style), freeing up `/` for a real `src/pages/index.tsx` hero + `HomepageFeatures` component, identical in shape to mimer's own.

**Pros**: the most literal match to "make it like mimer"; scales cleanly if this site ever grows enough independent sections to need mimer's nine-plugin front-door pattern.
**Cons**: **directly reopens the exact problem PLAN-006 already found and fixed once** — moving docs off root re-introduces the "every internal link is missing a path segment" bug class, this time in reverse (every existing site link assuming `routeBasePath: '/'` would need a `/docs/`-equivalent prefix added). Solves a navigation problem (many sections, which one do I want?) sovdev-logger doesn't actually have today — one sidebar, three sections, already navigable from the current landing page's bullet list. This is the option most likely to be solving a problem this site doesn't have yet, borrowed from a much bigger, differently-shaped site.

---

## Recommendation

**Option C** is the best fit: it gets real, mimer-inspired visual polish (a proper hero, real feature cards) without touching the routing architecture PLAN-006 deliberately built and already paid a real cost to get right. **Option D should be rejected unless/until sovdev-logger's docs actually grow into multiple independent, differently-audienced sections the way mimer's nine plugin instances did** — right now, that's not the shape of this site, and adopting mimer's route architecture would be borrowing a solution to a navigation problem (which of many sections do I want?) this site doesn't have. **Option B** is a reasonable cheaper fallback if even a small component is more than wanted right now — it's a strict subset of what Option C does, so choosing B doesn't foreclose upgrading to C later.

---

## Open Questions

1. **[Q1]** — **Decided.** Option C — convert `docs/index.md` to `.mdx`, embed real components (hero, feature cards), no route change.
2. **[Q2]** — **Decided.** Needs a logo/illustration mark. Since generating new artwork here would be AI-generated visual content published externally (flagged per this org's AI-reglement, point 8 — "KI-genererte bilder/videoer skal ikke brukes eksternt"), resolved instead by **reusing mimer's own placeholder mark** (`mimer-logo.svg`'s ripple/well motif, itself explicitly labeled "PLACEHOLDER... replace with the designed logo" in mimer's own repo) — recolored to this project's existing favicon green (`#2e8555`) and saved as `website/static/img/sovdev-logo.svg`, clearly commented as a reused placeholder to swap for a real design later. Not new AI-generated art, and not permanent.
3. **[Q3]** — **Decided.** Yes, build the three-card feature grid, mimer-`HomepageFeatures`-style.
4. **[Q4]** — **Decided.** Yes — the "Who Do You Write Logs For?" text gets a callout card on the new homepage, mimer-oath-card-style, linking out to the full text in `typescript/README.md` (canonical location, not duplicated — per `INVESTIGATE-readme-vs-docusaurus-policy.md`). This supersedes the smaller, separately-proposed `general/index.md` paragraph from earlier in this session — one placement, not two.

## Post-implementation correction: Option C didn't deliver what it promised, and Option D's cost was overstated

Found while implementing Phase 1 of the child plan — worth recording since it changes how to read the Options section above for future reference:

- **Option C, as written, still looked like a docs page, not a homepage.** Embedding the hero inside `docs/index.mdx` renders through Docusaurus's standard doc-page theme regardless — sidebar, breadcrumbs, TOC rail, pagination footer all still there. The maintainer caught this immediately on first look ("this is not the same design as mimer. mimer has a real homepage"). A hero banner sitting inside that chrome was never going to look like mimer's bare, full-width `<Layout>` page — that's a structural fact about the docs plugin, not a styling gap CSS can fix.
- **Option D's cost was overstated.** It was scoped as "docs move to `routeBasePath: '/docs'` (or split into multiple plugin instances)" — implying every page's URL changes, reopening PLAN-006's "every link missing a path segment" problem. **That's not actually necessary.** Docusaurus only forbids two things claiming the exact same route; it doesn't forbid a docs plugin at `routeBasePath: '/'` coexisting with a `src/pages/index.tsx`, as long as no individual *document* has `slug: /`. The fix that shipped: move only the one "About" document's slug (`/` → `/about`), add a real `src/pages/index.tsx`. `general/`, `using/`, `contributor/` never moved — confirmed via a real build with `onBrokenLinks: 'throw'`, zero breakage.
- **Net result**: neither C nor D exactly as scored. The shipped answer gets Option D's actual visual outcome (a true bare-layout homepage) at a fraction of Option D's assumed cost (one document's slug, not the whole plugin's `routeBasePath`) — because the real constraint was "no doc can claim `/`," not "the whole docs plugin must move."
- **Content also changed materially from what this investigation scoped**: the three-card grid became four cards about project values (Sovereign/Open/OpenTelemetry-native/Consistent), not `general`/`using`/`contributor` navigation (dropped — the hero's own buttons and the sidebar already cover that). Two new sections not in this investigation at all: Languages and Backends rows with real logos (TypeScript/Python/UIS/Grafana — sourced from Simple Icons CC0 and UIS's own real site, not generated, consistent with [Q2]'s AI-imagery finding), distinguishing what's actually shipped/verified from what's merely planned/theoretical.

## Next Steps

- [x] Maintainer decided [Q1]–[Q4]
- [x] Created and shipped [`PLAN-docusaurus-homepage.md`](PLAN-docusaurus-homepage.md)

## See also

- [`INVESTIGATE-documentation-strategy.md`](INVESTIGATE-documentation-strategy.md) — where `mimer` first became sovdev-logger's structural model, and where the current single-route homepage decision was made (via its child `PLAN-006-documentation-content-migration.md`)
- `/Users/tec/learn/helpers/mimer/website/src/pages/index.tsx` and `src/components/HomepageFeatures/` — the actual reference implementation this investigation compares against
