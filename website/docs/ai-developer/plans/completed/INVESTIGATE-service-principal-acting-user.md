# Investigate: `service_principal` and `acting_user` request-scoped context fields

Extends `sovdev_set_context()` (shipped in `PLAN-context-propagation.md`) with two more fields — which database credential an API used to query (`service_principal`) and which human the query was scoped/impersonated to, when applicable (`acting_user`) — reviving the "acting-user id" half of the original GitHub issue #23 ask that was deliberately deferred to just `client_name` the first time.

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Completed

**Goal**: Decide field names, semantics (when each is present/absent), the merge-vs-replace question `sovdev_set_context()` now needs revisiting for, and the Grafana Cloud privacy warning mechanism for `acting_user`.

**Last Updated**: 2026-07-13

**Builds on**: [`INVESTIGATE-context-propagation.md`](../completed/INVESTIGATE-context-propagation.md) / [`PLAN-context-propagation.md`](../completed/PLAN-context-propagation.md) — the mechanism (`sovdev_set_context()`, backed by `AsyncLocalStorage`, one value per request) is already built and shipped. This investigation is additive to that design, not a re-litigation of it — except where noted (see **[Q4]**, a real correctness question the original single-field design didn't need to answer).

---

## Source

Raised in conversation, immediately after `PLAN-context-propagation.md` shipped, while discussing the still-open "operator dashboard" idea. The maintainer, thinking through what an operator would want to know, identified a need distinct from `client_name`: not "which frontend called," but "under what identity did the API query the database." Two concrete scenarios surfaced through discussion:

- **Customer-facing APIs**: the frontend sends a JWT identifying a human user. The API can't literally authenticate to the database *as* that human (no database has one login per external end-user) — instead it connects using a shared, privileged credential capable of impersonation (SQL Server `EXECUTE AS USER`, Postgres `SET ROLE`, or an app-level row-level-security context variable), and separately records which human the query was scoped to for that one call.
- **Service-to-service / batch jobs**: the API queries as a fixed account with no human involved at all.

This is genuinely two distinct identities, not one field with two possible kinds of value:

- **`service_principal`** — the actual database credential/account the API used to connect. Always present whenever the API talks to the database at all. "Service principal" is the maintainer-confirmed correct term (and is literally Azure/Entra ID's own name for non-human identities — a good sign given Azure Monitor integration is already on the `INVESTIGATE-external-backend-verification.md` roadmap).
- **`acting_user`** — the specific human the query was scoped/impersonated to, from the JWT. Present only when a real end-user is behind the call; absent for pure service-to-service calls.

```typescript
// Customer-facing call: both present
sovdev_set_context({
  client_name: 'web-app',
  service_principal: 'api-db-svc',
  acting_user: '<id-from-jwt>',
});

// Service-to-service / batch job: no human involved
sovdev_set_context({
  client_name: 'batch-runner',
  service_principal: 'batch-db-svc',
  // acting_user intentionally absent
});
```

---

## Questions to Answer

1. **[Q1]** Field names — `service_principal` and `acting_user` were the working names throughout this discussion. Any reason to reconsider either before they're locked into the shared schema (same "cheap to rename now, expensive once a second consumer exists" reasoning `PLAN-context-propagation.md`'s Q4/Q6 already established)? `acting_user_id` was considered as a more explicit alternative to `acting_user` (making clear it's an identifier, not a display name) — worth deciding alongside.

2. **[Q2]** Confirmed in discussion, not yet formally decided: `sovdev-logger` has **zero** opinion on either field's *value* — same scope boundary as `client_name` (the original investigation's Q10). The calling application decides whether `acting_user` holds a raw JWT claim, a hash, a truncated value, or an internal pseudonymous ID; the library only ever propagates whatever string it's given. Confirm this explicitly as the boundary, so a future contributor doesn't try to add validation/hashing logic to the library itself.

3. **[Q3]** The Grafana Cloud privacy warning — agreed in discussion: **warn, don't block or silently strip**. When `acting_user` is set (this field specifically, not `service_principal` — a service account name isn't personal data the same way a real end-user identity can be) and the configured OTLP endpoint looks like Grafana Cloud (hostname check, e.g. contains `grafana.net`), print a one-time warning that this value is headed to a third-party service and may contain personal data. Checked directly: **no existing precedent for this kind of hostname-based backend detection exists anywhere in the codebase today** (`grep`'d for it, found nothing) — this would be new detection logic, not a reuse of something already there. Needs: (a) designing that detection logic from scratch (endpoint hostname substring match is the obvious approach, but worth confirming it's robust — e.g. does it need to handle a custom/self-hosted Grafana Cloud-compatible endpoint that doesn't contain `grafana.net`?), (b) confirming this fires once per process (not once per log call — that would be console-spam, inconsistent with how every other diagnostic warning in this library behaves).

4. **[Q4] — a real correctness question the single-field design didn't have to answer.** `PLAN-context-propagation.md`'s Q3 decided `sovdev_set_context()` **replaces** the entire stored context on every call (matching `spanStorage.enterWith()`'s behavior) — fine when there was only one field (`client_name`), typically set once, early, in auth middleware. With three fields that may naturally get set at *different points* in the call stack — `client_name` early in middleware, `service_principal`/`acting_user` later, once code actually reaches the database-access layer — **replace semantics would silently wipe out `client_name` (or any earlier field) the moment a later call sets the other two.** This is a real bug waiting to happen, not a style preference. Recommend revisiting: `sovdev_set_context()` should **shallow-merge** into the existing context (new keys overwrite same-named keys; keys not mentioned in this call are preserved), not replace it wholesale. This changes behavior for the *existing*, already-shipped `client_name` mechanism too — needs to be treated as a real (small) follow-up fix to already-shipped code, not just new-feature design.

5. **[Q5]** Does `service_principal`/`acting_user` need its own dashboard treatment (a column on the "Recent Errors" table, following the `client_name`/`peer_service` precedent), or is that a natural follow-on once this ships, not part of deciding the fields themselves? Leaning toward: decide the fields and mechanism here, treat any dashboard work as its own small follow-up once there's real data to look at (same sequencing `PLAN-context-propagation.md` itself used — dashboard was Phase 4, after the mechanism shipped in Phase 1).

---

## Recommendation

**[Q1]/[Q2]** look settled from the discussion already — `service_principal` and `acting_user` (or `acting_user_id`, a small naming detail), pure pass-through, no library-side validation. **[Q3]** (the warning) is agreed in shape (warn, not block) but needs its exact detection/frequency mechanics nailed down before implementation. **[Q4]** is the one genuinely important finding here: it's not really about the new fields at all — it's a latent correctness gap in the *already-shipped* `sovdev_set_context()` that this investigation's three-field scenario is what exposed. Recommend fixing the merge-vs-replace behavior as part of whatever plan implements `service_principal`/`acting_user`, not deferring it, since the bug gets worse (silently dropping more state) the more fields exist.

---

## Next Steps

- [x] Maintainer confirms field names (**[Q1]**) — `acting_user`, not `acting_user_id`
- [x] Confirm the Grafana Cloud detection mechanism and warning frequency (**[Q3]**) — once at `sovdev_initialize()` time, cached
- [x] Decide merge-vs-replace fix scope (**[Q4]**) — shipped separately, ahead of this investigation's own plan, as [`PLAN-context-merge-semantics.md`](PLAN-context-merge-semantics.md)
- [x] Create `PLAN-service-principal-acting-user.md` with the chosen approach — shipped as [`PLAN-service-principal-acting-user.md`](PLAN-service-principal-acting-user.md)

**All resolved and shipped.** Moved to `completed/` — its only child plan has shipped, per [PLANS.md](../../PLANS.md)'s INVESTIGATE lifecycle rule. Dashboard treatment (**[Q5]**) and Python parity remain explicitly deferred, tracked as separate future work in `1PRIORITY.md`, not as open items on this investigation.
