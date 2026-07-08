# Investigate: Documenting sovdev-logger for two human audiences, the product's own reasoning, and the AI agent that will maintain it

How to restructure sovdev-logger's documentation so library *users* and library *implementers* each get what they need without wading through the other's content, the case for OpenTelemetry/OTLP is actually made somewhere instead of assumed or buried, and the docs a future AI coding agent reads are calibrated to a capable model — not re-built as the same kind of compensating scaffolding this project just spent four plans removing.

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Completed — both child plans shipped

**Goal**: Decide a documentation structure that cleanly separates "how do I use this library" from "how do I implement/maintain this library," makes the case for the product's own existence and its choice of OTLP explicit and general (not just Azure-framed), and is sized and shaped for an AI agent to read and keep current — without recreating the ROADMAP/`.claude/skills`-style scaffolding [PLAN-003](PLAN-003-spec-scaffolding-cleanup.md) just deleted. **Revised after the initial recommendation**: the actual destination for this content is `website/docs/` (the Docusaurus site), not the repo-root `docs/` folder — the site's own homepage already promises this migration and never delivered it. Structure modeled on the sibling `mimer` project's `general/`/`system/`/`contributor/` split.

**Last Updated**: 2026-07-08 (maintainer answered all questions below, accepted the Option C recommendation, then redirected the destination to the Docusaurus site with `mimer` as the structural model)

---

## Questions to Answer

1. **[Q1]** Should the "why sovdev-logger / why OTLP" explanation live in one doc read by both audiences (linked from different entry points), or does it need two versions — a short pitch for users and a deeper rationale for implementers? — **Decided: one doc, two entry points.** Linked from both the root README and `specification/00-design-principles.md`, per Diátaxis's own guidance that explanation content doesn't need to fork by audience the way reference material does.
2. **[Q2]** Should TypeScript's README stay the "canonical" quickstart that other language READMEs diff against (Python's README already does this informally — see Current State), given it's also the master implementation for behavior? Or is coupling the doc pattern to whichever language happened to be first a bad idea long-term, and a language-neutral quickstart template should exist instead? — **Decided: yes, TypeScript's README stays canonical.** It's already the master implementation for behavior; Python's README already diffs against it successfully; no new template artifact to create or keep in sync.
3. **[Q3]** The three top-level READMEs currently point at three different GitHub remotes (`norwegianredcross`, `terchris`, `helpers-no` — confirmed by direct grep, not assumed; see Current State). Fix this now as an obviously-correct, decision-free bug, or fold it into whichever docs plan comes out of this investigation? — **Decided: fix it now, separately.** `helpers-no/sovdev-logger` is the actual current remote; no reason to block an obviously-correct fix on the broader docs plan.
4. **[Q4]** How defensive should new documentation be against a *future* model being less reliable than assumed here? This project already over-built once for a weaker model and had to strip it back ([PLAN-003](PLAN-003-spec-scaffolding-cleanup.md)). — **Decided: write for a capable model, no hedging.** Short, correct, pointer-heavy docs; no preemptive scaffolding against a hypothetical future regression. If a real, evidenced problem with a future weaker model shows up, add scaffolding then, backed by evidence.
5. **[Q5]** Should the "why OTLP" explanation be purely persuasive (as `docs/README-microsoft-opentelemetry.md` currently is — all upside, no tradeoffs), or should it honestly name what OTLP costs? — **Decided: honest, including tradeoffs.** Name the real costs (more moving parts than a flat JSON logger, a learning curve, dependency on collector infrastructure) alongside the benefits, per Diátaxis's own permission for explanation content to discuss rejected alternatives.

---

## Decisions

All open questions above are now resolved by the maintainer, all in the direction this investigation recommended. In summary:

- **One "why OTLP" doc, not two** — linked from both the root README and `specification/00-design-principles.md`, honest about tradeoffs, not purely persuasive.
- **TypeScript's README stays canonical** — Python's README (and any future language's) diffs against it rather than duplicating it.
- **The three-remotes bug gets fixed immediately**, independent of the docs plan's timeline.
- **No preemptive defensiveness against a future weaker model** — write short, correct, pointer-heavy docs for a capable model; add scaffolding later only if a real problem actually appears.

This confirms Option C as accepted. Proceeding to draft the child PLAN.

---

## Current State

Confirmed by reading every doc surface directly (file-by-file, not sampled), not assumed from file names.

### The root `README.md` declares an audience split it doesn't actually follow

`README.md` has an explicit `## 👥 Choose Your Path` section splitting "For Library Users" from "For Language Implementers" — but everything before and after that section mixes both freely: user-facing quickstart content sits next to implementer-facing "Repository Status" and spec-version tracking, in the same file, in no particular order relative to the declared split. The audience router exists; the content around it doesn't respect it.

### Per-language READMEs: one disciplined pattern already exists by accident, one doesn't

`typescript/README.md` (~1,400 lines) is fully self-contained — it re-includes the root README's "Who Do You Write Logs For?" essay, the Problem/Solution code snippet, the "What You Get Automatically" diagram, and the Azure/vendor-lock-in bullets, verbatim. `python/README.md`, by contrast, is written as an explicit *diff* against TypeScript's — "see the TypeScript README's X section" for shared content, with its own content limited to what's actually different (three functions TypeScript has that Python doesn't, `sovdev_flush()` being sync instead of async). This is the better pattern, and it happened because whoever wrote PLAN-002's promotion step chose it, not because it's written down as a rule anywhere. Nothing stops the next language (Go, C#, Rust, PHP) from copying TypeScript's self-contained approach instead, and every one of the copy-pasted blocks becomes one more place the same fact can silently go stale — which leads directly to the next finding.

### A concrete, live consequence of that duplication risk: three different GitHub remotes

Confirmed by direct grep, not assumed:
```
README.md:366              https://github.com/norwegianredcross/sovdev-logger/issues
typescript/README.md:1337  git clone https://github.com/terchris/sovdev-logger.git
typescript/README.md:1395  https://github.com/terchris/sovdev-logger
python/README.md:406       git clone https://github.com/helpers-no/sovdev-logger.git
python/README.md:445       https://github.com/helpers-no/sovdev-logger
```
Three files, three different remotes, none of them wrong exactly (the repo has moved/forked over its life — `helpers-no/sovdev-logger` is the current one, per this session's own established context), but nothing caught the other two going stale. This is the exact class of drift the "one canonical doc, everything else diffs against it" pattern is supposed to prevent, and it's already happened.

### `docs/` (7 files): mostly mechanics, one real "why" doc — narrowly scoped

`docs/README-microsoft-opentelemetry.md` is the only doc with substantive "why OpenTelemetry" content: a `## Why We Use Standard OTEL vs Microsoft's Distro` section arguing vendor neutrality, portability, and no lock-in. But it's framed entirely for an Azure/Microsoft-shop reader (opens with a Microsoft quote, structured as "why not the Azure Distro"), which makes it a good doc for a sub-decision, not the top-level case for OTLP itself (why OTLP over a vendor SDK, over a bespoke JSON format, over any other neutral standard). The other 6 files (`README-configuration.md`, `README-loggeloven.md`, `README-logging-concepts.md`, `README-observability-architecture.md`, `logging-data.md`, plus `images/`) are all mechanics — how to configure, how spans work, how to read the Grafana dashboards — genuinely useful, but none of them explain why the library is built this way. `README-observability-architecture.md` is worth noting separately: it's the only doc in the whole repo with explicit `### For Library Developers` / `### For Infrastructure Maintainers` / `### For Application Developers` subheadings — proof the multi-audience pattern already works when someone bothers to write it that way.

### `specification/00-design-principles.md` has real "why" content — but only for implementation-level decisions

This document has genuine Context/Decision/Rationale/Alternatives-Considered writeups (why exception types always normalize to `"Error"`, why `response_json` is always present even as `null`) — it's a working example of the "explanation" category done well. But its scope stops at implementation decisions within an assumed OTLP architecture; it never argues for OTLP itself. `specification/README.md` and `specification/implementation-guide.md` are pure mechanics (doc index, validation commands, the 8-step implementation process) — appropriately so, they're reference material, not explanation.

### Grepping the whole repo for "why OTLP" content confirms the gap is real, not just hard to find

Outside `docs/README-microsoft-opentelemetry.md`, the only other hits are two duplicated marketing bullets ("✅ No vendor lock-in: Write once, deploy anywhere") in `README.md` and `typescript/README.md`. There is no doc anywhere that makes the general case — ecosystem size, multi-backend support beyond Azure specifically, why OTLP rather than statsd/a vendor SDK/a homegrown format. This is an absence, not a discoverability problem.

### `website/docs/ai-developer/` vs. `specification/`: already a clean boundary — don't disturb it

Worth stating explicitly so this investigation doesn't accidentally blur it: `website/docs/ai-developer/` is a generic, portable AI-agent process framework (`WORKFLOW.md`, `PLANS.md`, `GIT.md`, etc. — the same files this investigation and its resulting plans follow), shared conceptually with sibling repos. `specification/` is entirely product-specific — the logger's own contract and design rationale. There's no overlap today and no reason to introduce one.

### Revision: the Docusaurus site already declares product-doc migration as its own unfulfilled intent

Caught after the original survey above, and material enough to change the recommendation below — not a minor addendum. `website/docs/index.md`, the site's actual homepage, currently reads:

> "This docs site is newly set up — content is being migrated in from the repo's `specification/` and `docs/` folders. In the meantime, see the project README for the full picture."

The site was scaffolded with exactly this migration as its stated purpose, and it was never done — `website/docs/` today contains only that placeholder and the `ai-developer/` framework. This changes the earlier framing: the question isn't just "where should a new 'why OTLP' doc live," it's "the actual intended home for all of this project's product documentation is the Docusaurus site, and none of it has moved there yet." Everything in `specification/`, `docs/`, and the READMEs surveyed above is, by the site's own admission, provisional content sitting outside its intended final home.

---

## This Repo's Own History With Documentation

Directly relevant precedent, not a hypothetical concern — this project has already lived through every failure mode this investigation is trying to avoid repeating:

- **Staleness, discovered incidentally, repeatedly.** PLAN-002 found a README pointing at a script that never existed. PLAN-003 found a stale "Python README (coming soon)" reference and multiple dead cross-links. PLAN-004 found a stale file path and a wrong field count in an earlier draft of its own plan. None of these were found by anyone looking for them — they surfaced as side effects of unrelated work.
- **Overclaiming, self-corrected in place.** `INVESTIGATE-multi-language-conformance.md` originally claimed its proposed comparison tool "would catch all three known Python bugs." Once built and tested, only one of three actually was — the doc was corrected in place rather than left standing.
- **Scaffolding built for a weaker model, then stripped back once it wasn't needed.** The clearest case: `specification/llm-work-templates/`'s 13-task ROADMAP/CLAUDE.md/enforcement-script system and `.claude/skills/`'s automatically-invoked routers were both explicitly diagnosed (in PLAN-003) as "hand-holding... built for an earlier, weaker model" and deleted once a capable model no longer needed the hand-holding. The fix that actually solved the underlying problem — `compare-with-master.sh`, an automated check — made the prose scaffolding redundant; the prose scaffolding itself never would have caught what the automated check caught.

The pattern across all three: docs and process built as manual/prose compensating controls tend to (a) drift silently from the code they describe, (b) overclaim confidently until someone actually tests the claim, and (c) outlive the specific weakness they were built to compensate for. Any new documentation structure this investigation proposes should be judged against whether it's likely to repeat this pattern, not just whether it looks well-organized on day one.

---

## External Research: How Others Have Solved This

### Diátaxis maps cleanly onto the "why" vs. "how" split this project needs

The [Diátaxis framework](https://diataxis.fr/) (used by Django, Ansible, Cloudflare, Gatsby) splits documentation into four kinds by the reader's need: tutorials and how-to guides (practical), reference and explanation (theoretical). Reference is meant to be "austere" and mirror the structure of the thing it describes — exactly what `specification/01-api-contract.md`/`02-field-definitions.md` already are. Explanation is allowed to be discursive and argue tradeoffs — exactly what's missing for "why OTLP." Diátaxis's own guidance is explicit that reference material shouldn't try to also justify itself inline — which is a real critique of the old `CLAUDE.md`/ROADMAP blob (contract, rationale, and process all mixed into one artifact) and an argument for keeping any new "why" content in its own doc rather than folded into `specification/01-api-contract.md` or `implementation-guide.md`.

### OpenTelemetry's own semantic-conventions repo is the closest real analog to this project's shape

sovdev-logger's shape — one specification, N per-language implementations — is unusual for a small project but is exactly how [OpenTelemetry's semantic-conventions repo](https://github.com/open-telemetry/semantic-conventions) is organized: a machine-readable model as the single source of truth, generated reference docs, and separate per-language SDK repos that each carry their own contributor docs. Design rationale sits in a third location again — gRPC's analogous ecosystem keeps "why we decided X" in a dedicated `grpc/proposal` repo of design-decision records, deliberately kept out of both user docs and implementer reference. The consistent pattern across both: **three locations, never merged** — contract, rationale, and per-implementation notes — and cross-consistency is enforced by tooling (Weaver, compliance suites), not by a human re-reading prose. This directly validates the shape `compare-with-master.sh` (PLAN-001) already gave this project for the *contract* side; what's missing is the equivalent discipline for the *rationale* side, which currently has no dedicated location at all.

### A second, closer-to-home precedent: the `mimer` project's own Docusaurus information architecture

`/Users/tec/learn/helpers/mimer/website/docs/` is a sibling Red Cross Norway project on the exact same stack (Docusaurus, the same `ai-developer/` framework, the same `_category_.json`/autogenerated-sidebar conventions this repo already uses for `website/docs/ai-developer/plans/`). It solves precisely this investigation's problem — multiple audiences, a system whose reasoning needs explaining, contributor-facing build/maintenance detail — with a site structure of four top-level sections, each with an `index.md` hub page and a `_category_.json`:

- **`general/`** — "what this project is, in plain terms — for stakeholders and newcomers, before the implementation detail." The broadest audience.
- **`system/`** — "how the system works, so a reader can trust it and a contributor can develop and maintain it." Architecture-level explanation that bridges both audiences — this is where mimer put its "why" content (`how-it-all-works.mdx`) and its trust contract (`oath.md`, referenced from the homepage: "that split is a promise kept mechanically").
- **`contributor/`** — "For people working on the repo itself" — pure build-pipeline/implementation reference (scripts, data models, standards), explicitly distinguished from `system/`'s higher-level explanation.
- **`ai-developer/`** — the same portable process framework this repo already has, untouched.

The site's own root `index.md` explains the split in one paragraph and links to all three, then notes "Engine internals... are documented for maintainers in the Contributor section" — i.e., the three-way split isn't abstract taxonomy, it's one short paragraph plus three folders. This is a proven, working instance of the OpenTelemetry-style three-location pattern above, already running in Docusaurus, already familiar to whoever set up this exact site. Directly relevant given the finding above: **sovdev-logger's own `website/docs/index.md` already promises this kind of migration and never delivered it.**

### Conventions for documentation an AI agent reads and re-reads every session

`AGENTS.md` (vendor-neutral, Linux Foundation-stewarded, the file Claude Code falls back to when no `CLAUDE.md` exists) and `llms.txt` (a curated link index for LLM context, not a full dump) both converge on the same advice: keep it short, include only facts the model can't infer from the code or a linter, and prefer pointer structures ("see X for Y") over narrative — because an agent re-parses this content every session, and narrative spends context budget without a reliability payoff a linter or test wouldn't already provide. `specification/implementation-guide.md` (28 lines, all pointers) is already a good example of this; a new "why OTLP" doc should be judged by the same bar, not allowed to grow into another 800-line prose file.

### There's a name for the specific mistake this project already made and undid

Manufacturing has a clean distinction between **poka-yoke** (mistake-proofing built into the process itself) and manual inspection checklists — Deming's own framing: quality comes from improving the process, not from inspecting its output after the fact. The adjacent term from security/audit practice is a **"compensating control"**: a manual control stood up to cover a gap until a real automated one exists, meant to be time-boxed and retired but which tends to calcify instead. Google's SRE book calls the general version **"toil"** — manual work that should be automated away, not documented and repeated. `llm-work-templates`/`.claude/skills` were compensating controls (poka-yoke never having been built); `compare-with-master.sh` is the poka-yoke. The same question applies to documentation itself now: is a given doc recording a fact a test could check instead, or is it the kind of judgment/rationale content nothing but prose can carry?

---

## Options

### Option A: Minimal targeted fixes only

Fix what's concretely broken and nothing else: add one general "why OTLP" doc, fix the root README so its declared audience split is actually respected by the content around it, fix the three-different-remotes bug.

**Pros:**
- Cheapest, lowest-risk, directly closes the one confirmed content gap (general OTLP rationale) and one confirmed bug (remotes)
- No new structure to maintain or get wrong

**Cons:**
- Does nothing about the duplication-vs-diff inconsistency between `typescript/README.md` and `python/README.md` — the exact mechanism that produced the remotes bug in the first place will produce the next one, in whichever of Go/C#/Rust/PHP gets written next, unless the pattern is written down somewhere a future implementer (human or LLM) actually reads
- Treats each finding as isolated rather than recognizing the repo's own repeated pattern (staleness → found incidentally → patched) documented above

### Option B: Full Diátaxis four-category restructure across every doc

Formally reorganize all documentation — user and implementer — into tutorials/how-to/reference/explanation, mirroring how a large multi-team OSS project like Django or Ansible would structure a docs site.

**Pros:**
- Most rigorous, most future-proof if the project grows substantially
- Removes any ambiguity about where a new doc belongs

**Cons:**
- Heavy for a project with 7 `docs/` files, 2 language implementations, and effectively one active maintainer plus AI agents — exactly the kind of over-engineering-for-scale this project has already built and stripped back once (the ROADMAP system was also "rigorous and future-proof" on paper)
- A four-category taxonomy is itself a form of process scaffolding; it needs to be learned, applied consistently, and re-taught to every future contributor (including every future LLM session) — more upfront cost than the current problems justify
- Risks becoming exactly the kind of thing [Q4] warns about: built for a hypothetical future need rather than the demonstrated actual one

### Option C: Three-section Docusaurus site, adapted from OpenTelemetry's and `mimer`'s precedent

Not a new taxonomy — `mimer`'s already-working `general/` + `system/` + `contributor/` model, adapted to sovdev-logger's two audiences, built where the site's own homepage already says this content should live:

1. **`website/docs/general/`** — what sovdev-logger is and the general, honest "why OTLP" case (vendor neutrality, ecosystem, and real tradeoffs per [Q5]) — the broadest audience, read before anyone decides whether to adopt the library. `docs/README-microsoft-opentelemetry.md`'s Azure-specific content moves here too, as a linked-but-separate deeper page, not merged into the general one.
2. **`website/docs/using/`** — for library *users*: per-language quickstarts (migrated from `typescript/README.md`/`python/README.md`), configuration, log structure reference, and the existing `docs/*.md` mechanics content (observability architecture, logging concepts, Loggeloven compliance).
3. **`website/docs/contributor/`** — for library *implementers* (human or LLM): the specification's prose (`00-design-principles.md` through `10-code-quality.md`, `implementation-guide.md`) migrated in, alongside the API contract, field definitions, and anti-patterns table. `specification/schemas/`, `specification/tests/`, `specification/tools/` stay exactly where they are — they're functional code the implementation reads and runs, not documentation to migrate.
4. **`website/docs/ai-developer/`** stays untouched — it's already the right shape and already following this pattern.
5. The root `README.md` shrinks to a `mimer`-style pitch (what/why in a few paragraphs, install-and-link-out) rather than the ~400-line mixed reference it is today — matching how `mimer`'s own root README stays under 50 lines and defers depth to its site. Per [Q2], `typescript/README.md` stays the canonical *source* for the migrated user quickstart content (other languages diff against it) even after migration.
6. The three-remotes bug — already fixed, per [Q3], ahead of this plan.
7. A cheap, automated doc-consistency check (GitHub-remote consistency, Supported Languages table vs. actual per-language content) — same as before, just checking the new structure instead of the old one.

**Pros:**
- Modeled on two independent real precedents, not an invented structure: OpenTelemetry's spec/rationale/implementation split validates *what* to separate; `mimer`'s own already-running Docusaurus site (same stack, same `_category_.json` conventions, same org) validates exactly *how* to lay it out
- Finally does what `website/docs/index.md` already promised instead of leaving that promise unfulfilled
- Closes the general-OTLP-rationale gap and the duplication-risk pattern in one coherent move, not two separate patches
- The site becomes the single source of truth for product docs; `specification/`'s prose content moves into it while `specification/`'s functional code (schemas, tests, tools) stays exactly where it is

**Cons:**
- Substantially bigger than "add one doc" — migrating `specification/`'s prose and the `docs/` folder into Docusaurus sections is real content work, not a quick patch; likely needs its own PLAN scoped just to the information architecture (folders, index hubs, `_category_.json`) with content migration following incrementally, the same way `mimer`'s own `general/` section is still marked "Stub" months into that project
- Two places could theoretically drift (the Docusaurus source under `website/docs/` vs. GitHub's own rendering of the root README) unless the README is kept deliberately minimal, per point 5 above

### Option D: Status quo — fix things ad hoc as they're found

Keep doing what's already happening: let stale docs and gaps surface as side effects of unrelated plans, patch them individually.

**Pros:**
- Zero effort now

**Cons:**
- This is what already produced the three-remotes bug and the four incidental staleness findings across PLAN-002/003/004 — it's not a neutral baseline, it's the status quo that generated the evidence this investigation is built on
- Explicitly rejected by the instruction that prompted this investigation: the request was to actually decide a documentation strategy, not to keep finding problems one plan at a time

---

## Recommendation

**Option C**, now scoped explicitly to `website/docs/` rather than the repo-root `docs/` folder — per direct maintainer instruction: "the docs must go into the docusaurus website as that is the documentation," with `mimer`'s `general/`/`system/`/`contributor/` split named as the model to draw from. This is evidence-backed twice over (OpenTelemetry's spec/rationale/implementation shape, `mimer`'s already-running Docusaurus instance of that shape) and finally does what `website/docs/index.md` already told every visitor was coming. Given the "Cons" above, this should ship as more than one PLAN: an initial plan for the information architecture (the `general/`/`using/`/`contributor/` folders, index hubs, `_category_.json`, the new OTLP-rationale doc, the root-README shrink) and the diff-against-canonical rule, with full migration of `specification/`'s and `docs/`'s remaining prose following incrementally — the same way `mimer`'s own `general/` section shipped as a labeled "Stub" rather than waiting for full content before going live.

---

## Next Steps

- [x] Get sign-off on the recommendation and answers to [Q1]-[Q5] above — **accepted by maintainer 2026-07-08**, see "Decisions"
- [x] Fixed the three-different-GitHub-remotes bug ([Q3]) — done immediately and separately, ahead of the child plan, per the decision: `README.md`, `typescript/README.md`, and `docs/README-configuration.md`'s two Go-example import paths all now point at `helpers-no/sovdev-logger`.
- [x] Create [`PLAN-005-documentation-restructure.md`](PLAN-005-documentation-restructure.md) scoped to Option C's information-architecture phase — **completed 2026-07-08.** Drafted (v1) for the repo-root `docs/` destination, then **revised same-day** after the maintainer redirected the destination to `website/docs/` with `mimer`'s `general/`/`system/`/`contributor/` split as the model. `website/docs/general/`, `using/`, `contributor/` now exist with index hubs and `_category_.json`, replacing the homepage's unfulfilled migration placeholder; `general/why-otlp.md` makes the general, honest OTLP case; the Azure-specific content moved to `using/azure-integration.md`; the root README shrank 387 → 95 lines (every cut section verified present in `typescript/README.md`, nothing lost); `implementation-guide.md` has the diff-against-canonical rule; `specification/tools/check-doc-consistency.py` catches the remotes/table-drift class of bug going forward, verified against two independently-introduced mismatches.
- [x] Create [`PLAN-006-documentation-content-migration.md`](PLAN-006-documentation-content-migration.md) — **completed 2026-07-08.** `specification/`'s prose moved (not duplicated) into `contributor/`; the remaining `docs/*.md` moved into `using/`; `typescript/README.md`/`python/README.md` untouched, linked not duplicated, per [Q2]. `specification/README.md` and the moved `docs/*.md` paths are now short pointers, matching the pattern already established for `docs/README-microsoft-opentelemetry.md`. **Found and fixed two things this investigation didn't anticipate**: every site link written in PLAN-005 and this plan was missing a `/docs/` path segment (the docs plugin's route base path didn't match `docs/index.md`'s own `slug: /` intent) — fixed by setting `routeBasePath: '/'`, which also required removing the unused generic Docusaurus template homepage. And GitHub Pages itself had never actually been enabled on the repo — every prior "Deploy Documentation" run (5 of them, back to PLAN-001) had been silently failing. Both fixed and verified against the real, live site at `https://sovdev-logger.sovereignsky.no`.

This closes the investigation — all five decided questions are implemented, both child plans shipped, and the Docusaurus site is now the real, live, working home for sovdev-logger's documentation, not an unfulfilled placeholder.
