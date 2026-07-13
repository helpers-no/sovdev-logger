# Plan: Fix `sovdev_set_context()` to merge, not replace

`sovdev_set_context()` currently replaces the entire stored request context on every call, which silently drops earlier fields (e.g. `client_name`) the moment a later call in the same request sets different ones — this plan changes it to shallow-merge instead, fixing already-shipped behavior before more context fields exist to make the bug worse.

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Backlog

**Goal**: Change `sovdev_set_context()` so each call merges into the existing request context rather than replacing it wholesale, with a real test proving the fix.

**Last Updated**: 2026-07-13

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

## Phase 1: Implementation and verification

### Tasks

- [ ] 1.1 Update `sovdev_set_context()` in `typescript/src/logger.ts` to merge as shown above.
- [ ] 1.2 Update its doc comment (currently says "Each call replaces the entire stored context, consistent with how `spanStorage.enterWith()` behaves" — that statement is being reversed, not just the code).
- [ ] 1.3 Update `PLAN-context-propagation.md`'s own record (`completed/`) to note this follow-up fix and correct its Q3 decision note, which currently documents the old (now-wrong) replace behavior as final — a completed plan shouldn't keep asserting something that's no longer true of the code.

### Validation

A throwaway script proves the actual bug and the actual fix, not just "the code compiles":

```typescript
sovdev_set_context({ client_name: 'olla' });
sovdev_set_context({ service_principal: 'api-db-svc' }); // different key, same request
sovdev_log(...); // must show BOTH client_name AND service_principal
```

Since `service_principal` doesn't exist as a real schema field yet, this test uses a second synthetic/arbitrary key (TypeScript's structural typing allows testing the merge mechanism itself without waiting on the schema decision) — the point is proving `client_name` survives a second call, not testing any specific future field.

---

## Phase 2: Final checks

### Tasks

- [ ] 2.1 `npx tsc --noEmit`, `npm run lint`, `npm run build` all clean.
- [ ] 2.2 Re-run the Phase 3 E2E test from `PLAN-context-propagation.md` (`company-lookup.ts` against real UIS) to confirm no regression — `client_name` still appears correctly when set once, same as before.
- [ ] 2.3 Rebuild the Docusaurus site.

### Validation

User confirms the diff is exactly this fix — no unrelated changes.

---

## Acceptance Criteria

- [ ] Calling `sovdev_set_context()` twice in the same request, with different keys each time, results in both keys being present on subsequent log entries — proven by a real test, not assumed.
- [ ] Calling it twice with an *overlapping* key — the second call's value wins for that key (standard merge semantics), while other, unrelated keys from the first call are preserved.
- [ ] No regression to the existing single-call, single-field (`client_name`) behavior already shipped and validated in `PLAN-context-propagation.md`.

---

## Files to Modify

- `typescript/src/logger.ts`
- `website/docs/ai-developer/plans/completed/PLAN-context-propagation.md` (correct the now-stale Q3 note)
