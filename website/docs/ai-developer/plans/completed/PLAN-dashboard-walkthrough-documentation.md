# Write the dashboard walkthrough doc — screenshots (you) + code-paired narrative (me)

Splits the work needed to ship `website/docs/using/dashboard-walkthrough/index.md`: you generate fresh data and capture 9 screenshots, I pair each with its exact producing code and write the page.

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Completed

**Investigation**: [INVESTIGATE-dashboard-documentation.md](INVESTIGATE-dashboard-documentation.md) — panel↔code mapping, screenshot workflow, and page structure decisions.

**Goal**: Ship a walkthrough page pairing every dashboard panel with the exact `sovdev_log*()` call that produces it, a real screenshot, and explanatory prose — a reader gets the full story from this one page.

**Last Updated**: 2026-07-10

---

## Problem Summary

The dashboard exists (`sovdev-logger-full`, built in `PLAN-grafana-dashboard-definitions.md`) but nothing explains it to a reader yet. I can't open a browser or take screenshots from this environment, so this plan is inherently split: you produce the visual evidence, I produce the narrative that explains it. Doing this in one clean pass (fresh data → screenshots → doc) avoids screenshots that don't match what the paired code snippet describes.

---

## Phase 1: Generate fresh data and capture screenshots — YOUR STEPS

### Tasks

- [x] 1.1 Run the TypeScript E2E test to generate fresh, current data:
  ```
  dct-exec bash -c "cd /workspace/typescript/test/e2e/company-lookup && bash run-test.sh --skip-validation"
  ```
- [x] 1.2 Wait ~30-40 seconds (Tempo trace indexing lag — confirmed empirically during Phase 2 of the dashboard build; traces don't appear immediately)
- [x] 1.3 Open `http://grafana.localhost/d/sovdev-logger-full/sovdev-logger-full-overview` (`admin`/`SecretPassword1`)
- [x] 1.4 **Revised twice**: a single browser screenshot doesn't capture the full dashboard (only what's visible above the fold). Also, along the way, found and fixed two real bugs in the "by Peer Service" panels themselves (see `PLAN-grafana-dashboard-definitions.md`'s "Post-completion fix" sections — `instant: true` queries returned empty, then a duplicate-rows issue), which needed several rounds of fresh screenshots to confirm. Settled on 4 section-grouped screenshots (matching how they were naturally captured) rather than forcing exactly 2 composites:

  | Filename | Panels it covers |
  |---|---|
  | `dashboard-metrics.png` | Active Integrations, Total Operations, Error Rate, Average Operation Duration |
  | `dashboard-peer-service.png` | Operations/Errors/Error Rate/Avg Duration by Peer Service |
  | `dashboard-job-traces.png` | Job Lifecycle, Recent Traces |
  | `dashboard-errors-transactions.png` | Recent Errors, Transaction Logs |

  I copied the final files into place myself (`cp` from the maintainer's Desktop screenshots) once confirmed correct, rather than the maintainer moving them by hand.
- [x] 1.5 Confirmed all 4 files exist in `website/docs/using/dashboard-walkthrough/`

### Validation

- [x] I confirmed all 4 files exist at the expected path before starting Phase 2

---

## Phase 2: Write the walkthrough page — MY STEPS — DONE

### Tasks

- [x] 2.1 Re-read `company-lookup.ts` fresh — confirmed line numbers (202/222/258/273/303/318/371/412/440/481/614/666) against the current file, not assumed from the earlier investigation
- [x] 2.2 Wrote `website/docs/using/dashboard-walkthrough/index.md` — scenario intro, then one section per panel group in dashboard-scroll order, each with its screenshot and real code snippet (kept inline, not stripped of the file's own comments)
- [x] 2.3 Metrics panels got one shared "automatic" section, no invented snippet
- [x] 2.4 Cross-linked `tools/dashboards/README.md`, `observability-architecture.md`, and `logging-data.md`
- [x] 2.5 Added to `website/docs/using/index.md`'s page list

### Validation

- [x] `npm run build` — clean, and confirmed all 4 images actually made it into `build/assets/images/` with content hashes (not just that the build didn't error)
- [x] Page reviewed against the actual screenshots and source code (maintainer delegated this step rather than reviewing it themselves) — see "Post-completion fixes" below

---

## Post-completion fixes (found during the maintainer-delegated review)

Reviewing the rendered page meant actually looking at each screenshot pixel-by-pixel against its claimed content, and checking every factual claim against `typescript/src/logger.ts` and the dashboard JSON rather than trusting the prose written in Phase 2. Found and fixed five real inaccuracies:

1. **"60-line test program"** — the file is 718 lines. Removed the wrong number.
2. **`PEER_SERVICES.INTERNAL` claimed to equal `'internal'`** — false. `logger.ts:1318` shows `INTERNAL: service_name` — it resolves to the calling service's own name, confirmed visible in the Job Lifecycle screenshot's `peer_service=sovdev-test-company-lookup-typescript` on the "Job Completed" row. The wrong claim had been copied from a stale comment in `company-lookup.ts` itself (fixed separately, see below) without checking it against the real implementation.
3. **Recent Errors section was incomplete** — the screenshot shows two error rows (`batchLookup` and `lookupCompany`), but the doc only explained one. Added the missing `batchLookup` code snippet (the batch loop's own error log, which records which item number failed without stopping the batch) and explanation.
4. **"marked as an error span" claimed for the Recent Traces table** — unverifiable and likely wrong; that panel's config has no status/error column. Reworded to point to the trace waterfall view instead, where error-marking is a real, confirmed Grafana/Tempo behavior.
5. **`exception_type` claimed to always be `"Error"`** — false for TypeScript. `logger.ts:479` shows `constructor?.name || name || 'Error'` — `"Error"` is only the fallback, not a hardcoded value. (This matches a discrepancy already noted independently in `PLAN-003-spec-scaffolding-cleanup.md`.) Fixed to describe the actual fallback behavior.

Also fixed the root cause of finding #2: `typescript/test/e2e/company-lookup/company-lookup.ts:104`'s comment (`// INTERNAL is auto-generated with value 'internal'`) was itself wrong — corrected to `// INTERNAL is auto-generated, set to this service's own service_name`. Checked Python's equivalent test file and both READMEs for the same claim — none of them repeated it, so this was isolated to the one TypeScript comment.

`npm run build` re-confirmed clean after every fix.

---

## Acceptance Criteria

- [x] All 9 panels documented, each with its real screenshot (4 section-grouped images, each referenced once per panel section it covers) and the exact producing code
- [x] Reader can understand the whole dashboard from this one page, without needing to open `company-lookup.ts` separately
- [x] Docusaurus build clean, images render
- [x] Page linked from `using/index.md`

## Files to Modify

- `website/docs/using/dashboard-walkthrough/index.md` (new)
- `website/docs/using/dashboard-walkthrough/dashboard-metrics.png`, `dashboard-peer-service.png`, `dashboard-job-traces.png`, `dashboard-errors-transactions.png` (new — maintainer captured, I copied into place)
- `website/docs/using/index.md` (add page link)
