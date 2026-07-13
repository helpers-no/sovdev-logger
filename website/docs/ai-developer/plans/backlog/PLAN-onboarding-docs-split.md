---
mdx:
  format: md
---

# Plan: Split the onboarding recipe into operator and developer docs

Splits `using/onboarding/index.md` into a short landing page plus two audience-specific docs — an operator setup guide and a developer quickstart — so a customer developer never has to read past infrastructure steps that aren't theirs to do.

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Backlog

**Investigation**: [INVESTIGATE-developer-first-onboarding.md](INVESTIGATE-developer-first-onboarding.md) — Option A, accepted

**Goal**: `using/onboarding/` reads as three clearly separated audiences — developer, operator, and (already existing elsewhere) contributor — with no doc asking a customer developer to read infrastructure steps that were never theirs to do.

**Last Updated**: 2026-07-11

---

## Problem Summary

`using/onboarding/index.md` currently interleaves two jobs in one linear 7-step recipe: steps 1–5 are infrastructure work (pick a service name, create a Grafana Cloud Access Policy + token, find the OTLP endpoint, compute env vars, validate the token) that only someone with Grafana Cloud portal access can do; steps 6–7 are what an application developer actually needs (treat the header as a secret, confirm it shows up). A customer developer like ollacrm's engineers reads the whole thing even though 5 of 7 steps aren't theirs to act on — this is exactly the "two hats in one doc" problem the parent investigation identified. `using/onboarding/ollacrm/index.md` (the worked example) already reads almost entirely as developer-facing content, which confirms the split is real and not just theoretical — that page barely touches the operator's steps, just a one-line pointer to "follow the recipe first."

The third audience — **contributor** (someone working on sovdev-logger's own codebase) — already has its own home in `website/docs/contributor/*` and needs no new doc; this plan only touches `using/onboarding/`.

---

## Phase 1: Write the Operator doc

### Tasks

- [ ] 1.1 Create `website/docs/using/onboarding/operator-setup.md` — move (not duplicate) steps 1–5 of the current `index.md` verbatim: pick a `service_name`, create the Access Policy + token, find the OTLP endpoint/Instance ID, configure the 6 env vars, validate the token via the disposable-service-name push+read-back test. Keep the existing screenshot (`grafana-cloud-access-policy-form.png`) and its caption.
- [ ] 1.2 End the doc with an explicit handoff: "give the developer this `.env` snippet (6 lines) and tell them the `OTEL_EXPORTER_OTLP_HEADERS` line is a secret" — mirroring what step 6 of the current doc already says, but framed as the operator's deliverable rather than a shared step.
- [ ] 1.3 Frame the doc for the *role*, not "the sovdev-logger maintainer" specifically — note explicitly that today this is always the maintainer (sole admin of the one shared stack), but the doc describes what an operator does, since a future consumer project's own admin could plausibly fill this role instead.
- [ ] 1.4 Keep the existing "This step doesn't get delegated to an AI agent" callout (Access Policy creation) — unchanged, still a hard rule.

### Validation

User confirms the operator doc reads correctly as a standalone infra runbook, with no application-code content in it.

---

## Phase 2: Write the Developer quickstart doc

### Tasks

- [ ] 2.1 Create `website/docs/using/onboarding/developer-quickstart.md` — starts from "you were handed a 6-line `.env` snippet by whoever operates your project's Grafana Cloud connection" (no mention of Access Policies, OTLP Instance IDs, or the portal at all).
- [ ] 2.2 Cover: `npm install sovdev-logger`, where the secret goes (deploy pipeline's secret manager vs. plain env vars — reuse the distinction already spelled out in `ollacrm/index.md` section 2), the three function calls (`sovdev_initialize` / `sovdev_log` / `sovdev_shutdown`), and confirming it works (today: open the shared dashboard and find your `service_name` — step 7 of the current doc, moved here unchanged).
- [ ] 2.3 Cross-reference `ollacrm/index.md` as "a full worked example of this quickstart" rather than duplicating its content.

### Validation

User confirms the developer doc is readable start-to-finish with zero portal/Access-Policy knowledge required.

---

## Phase 3: Rewrite the landing page

### Tasks

- [ ] 3.1 Rewrite `website/docs/using/onboarding/index.md` as a short landing page: keep "The principle" section (one stack, one dashboard, per-system tokens — applies to both roles), then a brief "which doc do I need?" pointer — **Operator** → `operator-setup.md`, **Developer** → `developer-quickstart.md` — and a one-line note that contributing to sovdev-logger's own codebase is a different, third role covered under `contributor/*`.
- [ ] 3.2 Keep "What you're *not* doing" and "Experience reports" / "See also" sections, updated to point at the new file structure where relevant.

### Validation

User confirms the landing page is short (a picker, not a recipe) and correctly routes to both new docs.

---

## Phase 4: Fix cross-references

### Tasks

- [ ] 4.1 Update `website/docs/using/onboarding/ollacrm/index.md` — its pointer to "follow [Onboarding a new system]'s recipe first" (section 2) should point at `operator-setup.md` specifically (that's whose job the Access Policy/token actually is); its "Open the shared dashboard" step (section 6) can keep pointing at the landing page or `developer-quickstart.md`, whichever reads better once both docs exist.
- [ ] 4.2 Check and update, if needed, every other file confirmed to reference `using/onboarding` — `tools/dashboards/README.md`, `typescript/README.md`, `website/docs/ai-developer/plans/completed/INVESTIGATE-ollacrm-onboarding.md`, `website/docs/ai-developer/plans/completed/PLAN-long-running-server-flush.md`, `website/docs/ai-developer/plans/completed/INVESTIGATE-selftest-cli.md`, `website/docs/ai-developer/plans/backlog/INVESTIGATE-developer-first-onboarding.md` — most likely just need their step-number references (e.g. "step 5" for the validation step) re-pointed to `operator-setup.md`.
- [ ] 4.3 Mark `INVESTIGATE-developer-first-onboarding.md`'s Option A as shipped once this plan completes; re-rank it in `1PRIORITY.md`.

### Validation

```bash
cd website && npm run build
```

Clean build, no broken-link errors. User does a final read-through of all three onboarding docs together.

---

## Acceptance Criteria

- [ ] `using/onboarding/index.md` is a short landing page, not a recipe
- [ ] `using/onboarding/operator-setup.md` contains everything an operator needs, nothing an application developer needs
- [ ] `using/onboarding/developer-quickstart.md` contains everything a developer needs, with zero portal/Access-Policy knowledge assumed
- [ ] `ollacrm/index.md` and every other cross-referencing file point at the correct new doc
- [ ] `npm run build` passes clean (no broken links)
- [ ] `INVESTIGATE-developer-first-onboarding.md` and `1PRIORITY.md` updated to reflect Option A shipped

## Files to Modify

- `website/docs/using/onboarding/index.md`
- `website/docs/using/onboarding/operator-setup.md` (new)
- `website/docs/using/onboarding/developer-quickstart.md` (new)
- `website/docs/using/onboarding/ollacrm/index.md`
- `tools/dashboards/README.md`
- `typescript/README.md`
- `website/docs/ai-developer/plans/completed/INVESTIGATE-ollacrm-onboarding.md`
- `website/docs/ai-developer/plans/completed/PLAN-long-running-server-flush.md`
- `website/docs/ai-developer/plans/completed/INVESTIGATE-selftest-cli.md`
- `website/docs/ai-developer/plans/backlog/INVESTIGATE-developer-first-onboarding.md`
- `website/docs/ai-developer/plans/backlog/1PRIORITY.md`
