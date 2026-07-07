# Project: sovdev-logger

`sovdev-logger` is a **specification-first, multi-language structured logging library**. One log call gives structured logs, metrics, and distributed traces — correlated automatically — against any OpenTelemetry-compatible backend (Azure Monitor, Grafana Cloud, Datadog, New Relic, Honeycomb, or self-hosted).

The specification is the source of truth: every language implementation must produce **identical output** for the same log call. TypeScript is the reference implementation; Go, Python, C#, Rust, and PHP are planned or in progress.

For the user-facing description and quickstart, read the repo-root [`README.md`](https://github.com/helpers-no/sovdev-logger/blob/main/README.md) first.

---

## What this repo contains

```text
sovdev-logger/
├── README.md                   — product overview (read this first)
├── LICENSE
│
├── specification/               — language-agnostic spec; the source of truth
│   ├── 00-design-principles.md … 10-code-quality.md
│   ├── README.md                — how to use the spec (points at the Claude Code skills)
│   ├── schemas/                 — output schemas implementations must match
│   ├── tests/                   — cross-language test scenarios
│   ├── tools/                   — validation / query tooling (see validation-tools skill)
│   └── llm-work-templates/      — templates for tracking an in-progress implementation
│
├── typescript/                  — reference implementation
│   ├── src/                     — logger.ts, logLevels.ts, peerServices.ts, index.ts
│   └── test/
│
├── python/                      — implementation in progress
│   ├── src/
│   ├── test/
│   └── llm-work/                 — this implementation's working notes (SDK comparison, issues/fixes)
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
    ├── AZURE-DEVOPS.md, TALK.md, WORKTREE.md, DEVCONTAINER.md
    ├── project-sovdev-logger.md  — this file
    └── plans/                     — INVESTIGATE-*.md + PLAN-*.md
        ├── backlog/
        ├── active/
        └── completed/
```

---

## How it's used

This is a **library**, not a CLI tool — there's no `sovdev-logger` command. A developer (human or LLM) implementing sovdev-logger in a new language works from the specification, not from asking around:

```text
"implement sovdev-logger in {language}"   → invokes the implement-language skill
"validate the implementation"             → invokes the validate-implementation skill
```

See `.claude/skills/` in the repo root — these are **project-specific Claude Code skills** (distinct from the generic `website/docs/ai-developer/` framework docs in this folder):

| Skill | Purpose |
|---|---|
| `implement-language` | Systematic 4-phase implementation of sovdev-logger in a new language, with a ROADMAP.md task list and completion-criteria enforcement |
| `validate-implementation` | Runs the full validation suite: file logs → OTLP → Grafana → labels |
| `validation-tools` | Points at the right debugging/query tool for a given validation question |
| `development-loop` | The 6-step iterative development workflow for fast feedback during active development |

Read `specification/README.md` before starting any implementation work — it explains how the skills and the spec fit together.

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

This repo is on **GitHub** (`https://github.com/helpers-no/sovdev-logger`, forked from `norwegianredcross/sovdev-logger`), not Azure DevOps. Ignore the Azure DevOps half of [`AZURE-DEVOPS.md`](AZURE-DEVOPS.md); use the **GitHub Operations (`gh`) section of [`GIT.md`](GIT.md)** for PR mechanics here.

---

## Key rules and contracts

### The specification is the contract — not any one implementation

No language implementation may drift from `specification/`. If an implementation needs to do something the spec doesn't cover, the spec gets updated first (or the gap gets flagged), not worked around silently in one language's code. This is what "identical output across all implementations" depends on.

### Always work on a branch — never commit directly to `main`

Required flow: **branch → commit → push → PR → merge**. This repo lives on GitHub; PR mechanics are `gh pr create` / `gh pr merge` (see [`GIT.md`](GIT.md)).

### Two related-but-separate repos in this org

`helpers-no/sovdev-logger` (this repo) is unrelated in *purpose* to `helpers-no/devcontainer-toolbox` and `helpers-no/noclickops`, but shares the same devcontainer and AI-developer-workflow conventions with them — the `website/docs/ai-developer/` framework docs in this folder were copied from `noclickops` and are meant to stay portable across all three.

---

## Always-loaded rules

Check the repo root for a `CLAUDE.md` — if present, it's what Claude Code auto-loads at session start and it takes precedence over anything in this file if the two ever disagree.
