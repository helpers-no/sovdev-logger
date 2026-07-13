# Plan: Fix `sovdev_set_context()` to merge, not replace

`sovdev_set_context()` currently replaces the entire stored request context on every call, which silently drops earlier fields (e.g. `client_name`) the moment a later call in the same request sets different ones — this plan changes it to shallow-merge instead, fixing already-shipped behavior before more context fields exist to make the bug worse.

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Completed

**Goal**: Change `sovdev_set_context()` so each call merges into the existing request context rather than replacing it wholesale, with a real test proving the fix.

**Last Updated**: 2026-07-13
**Completed**: 2026-07-13 — both phases done. Verified with a real end-to-end test (not just an isolated debug print): 4 real `sovdev_log()` calls interleaved with 3 `sovdev_set_context()` calls, run against both real Grafana Cloud and real UIS, confirming a different key from a second call doesn't wipe out an earlier one, and an overlapping key correctly updates just that key. No regression to the existing single-call `client_name` behavior.

**Source**: Found while investigating [`INVESTIGATE-service-principal-acting-user.md`](INVESTIGATE-service-principal-acting-user.md)'s **[Q4]** — not a new design decision, a correctness fix to code shipped in `PLAN-context-propagation.md`. Scoped independently of that investigation's new fields (`service_principal`/`acting_user`) — this fix stands on its own and doesn't need those fields to exist to be implemented or tested.

---

## Problem

`typescript/src/logger.ts`'s `sovdev_set_context()`:

```typescript
export function sovdev_set_context(context: SovdevRequestContext): void {
  requestContextStorage.enterWith(context);
}
```

`enterWith()` **replaces** whatever was previously stored for this async chain. Fine when there's exactly one field, set once, early in a request. Not fine once code at a different point in the same request's call stack (e.g. a database-access layer, deeper than the auth middleware that set `client_name`) calls `sovdev_set_context()` again with a different field — the earlier field is silently gone from every subsequent log entry in that request, with no error, warning, or any signal that it happened.

## Fix

Read the current store before writing, merge the new object over it (new keys win, keys not mentioned are preserved), and pass the merged result to `enterWith()`:

```typescript
export function sovdev_set_context(context: SovdevRequestContext): void {
  const existing = requestContextStorage.getStore();
  requestContextStorage.enterWith({ ...existing, ...context });
}
```

---

## Phase 1: Implementation and verification — DONE

### Tasks

- [x] 1.1 Updated `sovdev_set_context()` in `typescript/src/logger.ts` to merge as shown above.
- [x] 1.2 Updated its doc comment to describe merge semantics and explain why (different fields naturally get set at different points in the call stack).
- [x] 1.3 Updated `PLAN-context-propagation.md`'s record (`completed/`) — struck through the old "Replace, not merge" decision line rather than deleting it, with a note explaining it's superseded by this plan. Preserves what was actually decided/shipped at the time instead of quietly rewriting history.

### Validation

`service_principal` doesn't exist as a real schema field yet, and `write_log()` only extracts `client_name` from the context today (not a generic spread of every key) — so the actual log *output* can't show a second field yet. Verified the merge mechanism directly instead, with a temporary debug print inside `sovdev_set_context()` (added, used, then removed — not shipped):

```
DEBUG_MERGE existing= undefined incoming= { client_name: 'olla' } merged= { client_name: 'olla' }
DEBUG_MERGE existing= { client_name: 'olla' } incoming= { service_principal: 'api-db-svc' } merged= { client_name: 'olla', service_principal: 'api-db-svc' }
DEBUG_MERGE existing= { client_name: 'olla', service_principal: 'api-db-svc' } incoming= { client_name: 'olla-v2' } merged= { client_name: 'olla-v2', service_principal: 'api-db-svc' }
```

Confirms both cases directly: a different key from a second call is preserved alongside the first (call 2), and an overlapping key from a third call overwrites just that key while leaving the other untouched (call 3).

---

## Phase 2: Final checks — DONE

### Tasks

- [x] 2.1 `npx tsc --noEmit`, `npm run lint`, `npm run build` all clean.
- [x] 2.2 Re-ran the E2E test (`company-lookup.ts`) against real UIS via `dct-exec` — schema validation passed (17/17 + 2/2), and a direct Loki query confirmed `client_name` still appears correctly for the existing single-call case: `{service_name="sovdev-test-company-lookup-typescript"} | client_name="company-lookup-e2e-client"` → 5 matches. No regression.
- [x] 2.3 Rebuilt the Docusaurus site — caught and fixed one broken link in the process (this plan's own reference to `INVESTIGATE-service-principal-acting-user.md` used a bare relative path instead of `../backlog/...`).
- [x] 2.4 (requested before merging, not originally scoped as its own task) The Phase 1 debug-print verification proved the merge *mechanism* but not that it survives all the way through the real write path to a real backend, and only one backend (implicitly) had been exercised. Closed both gaps: a throwaway script made 4 real `sovdev_log()` calls interleaved with 3 `sovdev_set_context()` calls (no context set → set `client_name` → set an unrelated key → set an overlapping `client_name` again), run against **both** real Grafana Cloud and real UIS, each log line queried back and sorted by actual timestamp (not stream order, which isn't chronological once entries land in different streams). Identical, correct result on both backends:
  ```
  no_context                     client_name=None
  after_first_set                client_name='first-client'
  after_different_key_set        client_name='first-client'   <- the exact bug scenario: survives
  after_overlapping_key_set      client_name='second-client'
  ```
  This is the real proof the fix works end-to-end, not just in an isolated debug print.

### Validation

Diff reviewed: exactly the merge fix, its doc comment, the historical-record correction in `PLAN-context-propagation.md`, and this plan's own progress tracking — no unrelated changes.

---

## Acceptance Criteria

- [x] Calling `sovdev_set_context()` twice in the same request, with different keys each time, results in both keys being present in the merged context — proven directly via debug output, not assumed.
- [x] Calling it twice with an *overlapping* key — the second call's value wins for that key (standard merge semantics), while other, unrelated keys from the first call are preserved.
- [x] No regression to the existing single-call, single-field (`client_name`) behavior already shipped and validated in `PLAN-context-propagation.md`.

---

## Files to Modify

- `typescript/src/logger.ts`
- `website/docs/ai-developer/plans/completed/PLAN-context-propagation.md` (correct the now-stale Q3 note)
