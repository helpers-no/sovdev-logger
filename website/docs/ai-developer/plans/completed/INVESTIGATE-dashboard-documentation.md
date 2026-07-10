# Investigate: How to document the new Grafana dashboard so a reader understands it end-to-end

Designs the documentation for `tools/dashboards/sovdev-logger-overview.json` — pairing each dashboard panel with the exact `sovdev_log*()` call that produces it, a screenshot of the real result, and enough explanation that a reader understands the whole story without needing to open a second file.

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Resolved — child plan shipped and confirmed

**Child plan**: [PLAN-dashboard-walkthrough-documentation.md](../completed/PLAN-dashboard-walkthrough-documentation.md) — the concrete steps (yours and mine) to ship the page.

**Goal**: Produce a page that walks through the company-lookup test program and the new dashboard together — code snippet, explanation, and a real screenshot for each panel — so a reader gets the full "this call produces this panel" understanding by reading it, not by cross-referencing multiple files.

**Last Updated**: 2026-07-10

**Outcome**: `website/docs/using/dashboard-walkthrough/index.md` shipped with all 4 screenshots and 9 panels documented. A maintainer-delegated review against the actual screenshots and source code (not just a read-through) found and fixed 5 real factual errors — see the child plan's "Post-completion fixes" section. Also fixed the root cause of one of them, a stale comment in `company-lookup.ts` itself.

---

## Current State (checked directly)

- **Zero images anywhere in the docs site.** `website/static/img/` has only `favicon.svg`; no `website/docs/**/*.md` file contains a markdown image (`![...]`). This would be the first doc with real screenshots — there's no established convention yet for where images live or how they're referenced.
- **`website/docs/using/observability-architecture.md` is stale relative to this session's work.** It documents a "three-dashboard architecture" (`test-dev-observability-infra-dashboard.json`, `test-dev-observability-structuredlog-dashboard.json`, `structuredlog-dashboard.json`) — all files in the external `dev-observability-stack` repo, none of them the dashboard built this session (`tools/dashboards/sovdev-logger-overview.json`, pushed as `sovdev-logger-full`). This new doc will either need to coexist alongside it or prompt an update to it — a decision for [Q6] below.
- **The test program's source is already unusually well-annotated for this purpose.** `typescript/test/e2e/company-lookup/company-lookup.ts` already has, for every `sovdev_log*()` call, a comment block naming exactly what it demonstrates and — in several places — an explicit `GRAFANA USE:` line (e.g. "Query by `log_type=\"job.status\"` to see all job lifecycles"). This isn't a coincidence to work around; it's most of the explanatory content already written, just not yet paired with a real screenshot.
- **`website/docs/using/index.md`'s existing pattern** (Azure integration, Configuration, Logging concepts, Log data structure, Observability architecture, Loggeloven) is short, focused pages, each linked from one index. A new page fits this pattern as a sibling, not a rewrite of the section.

### Concrete panel ↔ code mapping (verified against the actual file, not assumed)

| Dashboard panel | Produced by | Source location |
|---|---|---|
| Active Integrations, Total Operations, Error Rate, Avg Duration | Every `sovdev_log()` call (auto-generates `sovdev_operations_total`/`sovdev_errors_total`/`sovdev_operation_duration_milliseconds`) | Implicit — no explicit metrics code in the test program, this is the "one log call, automatic metrics" story |
| Peer Service Dependencies | `PEER_SERVICES.BRREG` passed to every `sovdev_log()` call in `lookupCompany()` | `company-lookup.ts:222-303` (start/success/error logs, all tagged `PEER_SERVICES.BRREG`) |
| Job Lifecycle | `sovdev_log_job_status()` (Started/Completed) + `sovdev_log_job_progress()` (one per company) | `company-lookup.ts:371-393` (Started), `:412-421` (progress, in the loop), `:481-487` (Completed) |
| Recent Traces (Tempo) | `sovdev_start_span()`/`sovdev_end_span()` wrapping `lookupCompany()` | `company-lookup.ts:202` (start), `:273` (end, success path), `:318` (end, error path) |
| Recent Errors | The intentional failure (org number `974652846`), logged via `sovdev_log(ERROR, ..., error)` | `company-lookup.ts:303-311` (inside `lookupCompany`'s catch), plus the batch-level echo at `:440-448` |
| Transaction Logs | Every `sovdev_log()` call with default `log_type="transaction"` | `company-lookup.ts:222`, `:258`, `:303`, `:440`, plus `main()`'s lifecycle logs |

---

## Questions to Answer

1. **[Q1]** Where does this doc live? `website/docs/using/` — it's about understanding what your own logging calls produce, the same audience as `logging-data.md`/`observability-architecture.md`, not a contributor/testing concern. — **Recommend: new page there**, e.g. `dashboard-walkthrough.md`.
2. **[Q2]** Screenshot workflow — I can't open a browser or take screenshots from this environment. The maintainer runs the test program, opens the dashboard, and captures screenshots; I write the explanatory prose around them. Where do the image files land? — **Decided: Docusaurus's co-located-assets pattern**, not `static/img/`. The page becomes a folder, `website/docs/using/dashboard-walkthrough/index.md`, with screenshots saved directly alongside it in the same folder and referenced by relative path (`![Peer Service Dependencies](./peer-service-dependencies.png)`) — Docusaurus's markdown loader processes local relative image paths in plain `.md` files, not just MDX. Keeps each doc page's images scoped to that page instead of accumulating in a shared, ever-growing `static/img/`.
3. **[Q3]** Narrative order — walk through in the order a reader would naturally scroll the dashboard (matches the panel order already built: metrics summary → dependencies → job lifecycle → traces → errors → transaction detail), not the order the code executes in (job start → per-company loop → job end). The two orders mostly agree already; where they don't (metrics panels have no single corresponding code block, they're the "automatic" side of the story), say so explicitly rather than force a code snippet that doesn't exist.
4. **[Q4]** Code snippet duplication — snippets get inlined (not just linked), since the whole point is "full understanding by reading the doc," not by opening a second tab. This means the snippets can drift from the real file over time. — **Accept the tradeoff**: `company-lookup.ts` is the fixed reference E2E scenario (see `08-testprogram-company-lookup.md`) and changes rarely; note in the new doc's own front matter that snippets are point-in-time copies, and — same as `check-doc-consistency.py`'s original motivation — this is a real doc-drift risk worth a periodic manual re-check, not a blocking concern now.
5. **[Q5]** TypeScript only, or Python too? The dashboard was built and verified against TypeScript's E2E output only this session. — **Recommend: TypeScript only for this pass**; Python's `company-lookup.py` produces identical log data (per `compare-with-master.sh`), so a future pass could reuse the same screenshots' *narrative* with Python snippets swapped in, but that's follow-on work, not this doc.
6. **[Q6]** What happens to `observability-architecture.md`? It's a separate, stale page about a different (external, UIS-provisioned) three-dashboard setup — not something this investigation's scope should silently rewrite. — **Recommend**: leave it alone for now, cross-link from the new page ("for the UIS-provisioned testing dashboards, see Observability architecture"), and flag its staleness as a separate, smaller follow-up rather than scope-creep this doc.

---

## Recommendation

New page `website/docs/using/dashboard-walkthrough/index.md` (folder, not a flat file — screenshots live alongside it in the same folder, Docusaurus's co-located-assets pattern), added to `using/index.md`'s page list. Structure, panel by panel in dashboard-scroll order:

1. **Setup** — one line: run `typescript/test/e2e/company-lookup/run-test.sh`, open the dashboard at the URL from `push-dashboard.ts`'s output.
2. **Per panel**: screenshot → the exact code snippet that produced it (with its existing `GRAFANA USE`/`DEMONSTRATES` comments kept, not stripped) → 2-4 sentences connecting the two explicitly ("the `peer_service: PEER_SERVICES.BRREG` argument here is what populates the `peer_service` label the dependency table groups by").
3. **Metrics panels** (Active Integrations/Total Operations/Error Rate/Avg Duration): explained together as "automatic" — one short section, no fake code snippet invented just to have one.
4. Cross-link to `observability-architecture.md` for the separate UIS-provisioned dashboards, and to `tools/dashboards/README.md` for how to push/maintain the dashboard itself.

---

## Next Steps

- [x] Maintainer confirmed the screenshot workflow: co-located folder (`dashboard-walkthrough/index.md` + images in the same folder), not `static/img/`
- [ ] Maintainer runs the company-lookup test program, takes one screenshot per panel, saves them into `website/docs/using/dashboard-walkthrough/` using the panel-derived filenames above
- [ ] I write `website/docs/using/dashboard-walkthrough/index.md` once screenshots exist, pulling the exact code snippets from the current `company-lookup.ts` and pairing each with its screenshot (relative-path references, e.g. `./peer-service-dependencies.png`)
- [ ] Add the new page to `website/docs/using/index.md`'s page list
- [ ] Docusaurus build check (first real images in the site — worth confirming they resolve correctly, not just that links don't 404)
