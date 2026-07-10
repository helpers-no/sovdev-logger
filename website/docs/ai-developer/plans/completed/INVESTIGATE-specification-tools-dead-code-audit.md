# Investigate: How much of `specification/tools|tests|schemas` is actually dead code, and where should the live parts go?

Audits every script in `specification/tools/`, `specification/tests/`, and `specification/schemas/` against real usage across the repo (not assumption), to separate what's still load-bearing from what's been superseded and never cleaned up — and designs a `tools/` structure that scales to more languages and more OTLP backends.

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Resolved — audit complete, reorg shipped

**Child plan**: [PLAN-consolidate-validation-tools.md](PLAN-consolidate-validation-tools.md) — executes the move and removal below.

**Goal**: Determine which scripts in `specification/tools/`, `specification/tests/`, `specification/schemas/` are still used, which are dead, and design a `tools/` layout that scales to more languages and more OTLP backends without special-casing each one.

**Last Updated**: 2026-07-11

---

## Method

Grepped every `.md`/`.sh`/`.ts`/`.py`/`.json`/CI-workflow file in the repo for each script's filename, then classified by what actually referenced it:

- **Live**: referenced by current (non-archived, non-completed) docs, or directly exercised as part of this session's own verification work
- **Dead**: zero references anywhere, or referenced only by other dead scripts / the intentionally-archived `llm-work-templates-archive/`
- **Ambiguous**: referenced only by a stale doc describing a superseded workflow — resolved by checking whether the *referencing doc* itself was current or already superseded

## Findings

### Confirmed dead — zero live references, testing an already-abandoned approach

- **`verify-kubectl-setup.sh`** — nothing else in the repo referenced it. It checks `kubectl exec -n monitoring loki-0`, but `query-loki.sh`'s own documented history (`testing/uis.md`'s Troubleshooting section) already proved that pattern can never work — the `grafana/loki` image has no shell/`wget` to exec into. It was checking for a capability nothing has needed since that fix landed. Oldest-touched file in the tree (2025-10-30).

### Confirmed dead — a whole superseded validation layer

- **`query-grafana-loki.sh` / `query-grafana-prometheus.sh` / `query-grafana-tempo.sh`** — queried Loki/Prometheus/Tempo *through Grafana's datasource proxy* using a **hardcoded datasource ID** (`proxy/2/loki/...`). Only referenced by the old "8-step validation sequence" in `09-development-loop.md`, `run-full-validation.sh`, `run-grafana-validation.sh`, and the archived templates.
- **`run-grafana-validation.sh`**, **`validate-grafana-datasources.sh`** — orchestration/checks for the same dead layer, no independent usage.
- **`run-full-validation.sh`** — orchestrated the entire 8-step sequence (direct backend queries **and** the dead Grafana-proxy queries in one script). Still linked from the *current* `09-development-loop.md`, so not orphaned exactly, but documenting a workflow nobody actually used this session — every real verification (this session, and the already-shipped `testing/uis.md`/`testing/grafana-cloud.md` docs) used the individual `query-*.sh --compare-with` calls plus `compare-with-master.sh` instead. Trimming it to just the live steps was considered and rejected: the simpler, already-proven pattern (call each query script directly) needed no new orchestration script to document it.

### Probably a one-off, not ongoing (kept, not removed)

- **`check-doc-consistency.py`** — its own docstring says "a five-minute script, not a subsystem," written for one specific docs migration (PLAN-005/006). Only referenced by now-completed plans. Kept under `tools/repo-maintenance/` since it's still runnable and harmless, not because it's in active use.

### Confirmed live — moved, not removed

`query-loki.sh`, `query-tempo.sh`, `query-prometheus.sh`, `compare-with-master.sh`, `validate-log-format.sh`, `run-company-lookup.sh` (all `specification/tools/`), the 8 Python validators + `compare-log-files.py` (`specification/tests/`), the 4 JSON schemas (`specification/schemas/`), and `generate-field-constants.py` — all directly exercised and re-verified working after the move (see child plan). `generate-field-constants.py` actively generates `python/src/field_names.py`, confirmed via its own "GENERATED FILE" header.

---

## New Structure

```
tools/
├── validation/
│   ├── schemas/        # JSON Schema — single source of truth for log/response shape
│   ├── validators/      # Python: schema + cross-validation, backend-agnostic
│   ├── uis/             # Bash + kubectl: local UIS backend
│   └── grafana-cloud/    # TypeScript: Grafana Cloud backend (renamed from grafana/ for symmetry)
├── codegen/             # generate-field-constants.py (schema-driven code generation)
└── repo-maintenance/    # check-doc-consistency.py
```

**[Q1]** Why split `validation/` by backend rather than by language? Every query/comparison tool here takes a service name or log file as a parameter and works identically regardless of which language produced the E2E output — language is a runtime argument, not a directory. What actually differs per backend is the query API and auth model (local `kubectl` access vs. Grafana Cloud's HTTP Basic Auth), so that's the axis that gets its own subdirectory. All backends pipe into the same `validators/` — the comparison logic (does this data match the source log file, field by field) is written once.

**[Q2]** Why not leave things where they were? `specification/` no longer contains any prose (that migrated to the Docusaurus site in PLAN-006) — keeping functional tooling nested under a folder named after documentation that itself moved elsewhere was exactly the kind of naming drift the maintainer had already flagged (`1PRIORITY.md` Tier 5, and `INVESTIGATE-grafana-cloud-validator.md`'s Q1, which explicitly avoided adding new tooling under `specification/` for this same reason). Consolidating under top-level `tools/` — where the Grafana Cloud tooling already lived — fixes that for the old tooling too, in the same move.

---

## Next Steps

- [x] Audit complete, findings documented above
- [x] Child plan created and executed — see [PLAN-consolidate-validation-tools.md](PLAN-consolidate-validation-tools.md)
