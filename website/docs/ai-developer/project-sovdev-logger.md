# Project: sovdev-logger

`sovdev-logger` is a **specification-first, multi-language structured logging library**. One log call gives structured logs, metrics, and distributed traces — correlated automatically — against any OpenTelemetry-compatible backend (Azure Monitor, Grafana Cloud, Datadog, New Relic, Honeycomb, or self-hosted).

The specification is the source of truth: every language implementation must produce **identical output** for the same log call. TypeScript is the reference implementation; Python is conformant (verified via `compare-with-master.sh`); Go, C#, Rust, and PHP are planned.

For the user-facing description and quickstart, read the repo-root [`README.md`](https://github.com/helpers-no/sovdev-logger/blob/main/README.md) first.

---

## What this repo contains

```text
sovdev-logger/
├── README.md                   — product overview (read this first)
├── LICENSE
│
├── specification/               — functional code only; prose moved to the docs site's Contributor section (PLAN-006)
│   ├── README.md                — pointer to the Contributor docs + what's still here
│   ├── schemas/                 — output schemas implementations must match
│   ├── tests/                   — cross-language test scenarios
│   ├── tools/                   — validation / query tooling, incl. compare-with-master.sh
│   └── llm-work-templates-archive/  — superseded ROADMAP/checklist scaffolding, kept for reference (see PLAN-003)
│
├── typescript/                  — reference implementation
│   ├── src/                     — logger.ts, logLevels.ts, peerServices.ts, index.ts
│   └── test/
│
├── python/                      — conformant implementation (verified against TypeScript)
│   ├── src/
│   └── test/
│
├── docs/                        — logging concepts, observability architecture, Microsoft OTel notes
│
├── website/                     — this Docusaurus site (docs.sovdev-logger.sovereignsky.no)
│
├── .devcontainer/                — DevContainer Toolbox (DCT), image-based model
├── .devcontainer.extend/         — project-specific devcontainer setup (enabled tools/services)
│
└── website/docs/ai-developer/    — this folder
    ├── README.md, WORKFLOW.md, PLANS.md, GIT.md,
    ├── TALK.md, WORKTREE.md, DEVCONTAINER.md
    ├── project-sovdev-logger.md  — this file
    └── plans/                     — INVESTIGATE-*.md + PLAN-*.md
        ├── backlog/                — 1PRIORITY.md lives here (triage view)
        ├── active/
        ├── completed/
        └── talk/                   — AI-to-AI testing sessions (TALK.md protocol)
```

---

## How it's used

This is a **library**, not a CLI tool — there's no `sovdev-logger` command. A developer (human or LLM) implementing sovdev-logger in a new language works from the specification directly, not from an automatically-invoked workflow:

1. Read the [Implementation guide](https://sovdev-logger.sovereignsky.no/contributor/implementation-guide) — contract → TypeScript → anti-patterns table → implement
2. Run `specification/tools/compare-with-master.sh {language}` until it passes — this is the completion gate, not a self-reported checklist

There used to be a `.claude/skills/` directory with hand-holding routers (mandatory checkpoints, per-language ROADMAP generation) built for an earlier, weaker model. It was deleted 2026-07-08 — see [PLAN-003](plans/completed/PLAN-003-spec-scaffolding-cleanup.md) — once `compare-with-master.sh` made the checklist-enforcement approach redundant.

Read the [Contributor documentation](https://sovdev-logger.sovereignsky.no/contributor) before starting any implementation work — migrated from `specification/` in [PLAN-006](plans/completed/PLAN-006-documentation-content-migration.md).

---

## Devcontainer

**Uses a devcontainer** — see [`DEVCONTAINER.md`](DEVCONTAINER.md), it applies in full. `.devcontainer/devcontainer.json` is the thin, managed config pointing at `ghcr.io/helpers-no/devcontainer-toolbox`; project-specific setup (which tools/services auto-install) lives in `.devcontainer.extend/`, not in `.devcontainer/` itself.

---

## Working on the docs site

The site under `website/` is a Docusaurus app:

```bash
cd website
npm install      # first time only
npm start        # http://localhost:3000 with hot reload
npm run build    # production build (catches broken links; onBrokenLinks: 'throw')
```

Requires **Node 20+**. Mermaid and local search are enabled; a dev-mode warning from the search plugin (`⚠ Local search will not work in dev mode`) is normal — the index is built at `npm run build` time.

Unlike noclickops's docs site, there is no content-generator script here — docs pages are written directly under `website/docs/`, not generated from `bin/*.sh` metadata.

---

## Platform: GitHub

This repo is on **GitHub** (`https://github.com/helpers-no/sovdev-logger`, forked from `norwegianredcross/sovdev-logger`), not Azure DevOps — use the **GitHub Operations (`gh`) section of [`GIT.md`](GIT.md)** for PR mechanics here. There is no `AZURE-DEVOPS.md` in this folder (dropped, since this repo never touches Azure DevOps); if a future repo in this org needs it, pull it back in from `noclickops`'s copy.

---

## Key rules and contracts

### The specification is the contract — not any one implementation

No language implementation may drift from `specification/`. If an implementation needs to do something the spec doesn't cover, the spec gets updated first (or the gap gets flagged), not worked around silently in one language's code. This is what "identical output across all implementations" depends on.

### Always work on a branch — never commit directly to `main`

Required flow: **branch → commit → push → PR → merge**. This repo lives on GitHub; PR mechanics are `gh pr create` / `gh pr merge` (see [`GIT.md`](GIT.md)).

### Two related-but-separate repos in this org

`helpers-no/sovdev-logger` (this repo) is unrelated in *purpose* to `helpers-no/devcontainer-toolbox`, `helpers-no/noclickops`, and `ollacrm`, but shares the same devcontainer and AI-developer-workflow conventions with them. The `website/docs/ai-developer/` framework docs in this folder were originally copied from `noclickops`, then refreshed from `ollacrm`'s more mature version (one-line-abstract convention for plan/investigation/talk headers, cluster naming for grouped investigations, `plans/talk/` for in-repo AI-to-AI testing sessions, `plans/backlog/1PRIORITY.md` for triage) — meant to stay portable across all of them.

---

## Always-loaded rules

Check the repo root for a `CLAUDE.md` — if present, it's what Claude Code auto-loads at session start and it takes precedence over anything in this file if the two ever disagree.
