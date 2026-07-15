---
title: "Onboarding ollacrm"
sidebar_label: "Onboarding ollacrm"
sidebar_position: 1
description: "Steps for ollacrm-api to get onto sovdev-logger 1.0.2 and set up self-verification."
---

# Onboarding ollacrm

Steps for `ollacrm-api` to get fully onboarded and up to date. This is a living checklist — it reflects the current state, not a record of what happened before.

## 1. Install the latest version

```bash
npm install sovdev-logger@latest
```

## 2. Save the config file out of git

This file contains all the config needed for logging — keep it safe.

## 3. Verify it locally — same command on Mac, Linux, or Windows

```bash
NODE_OPTIONS="--env-file=/path/to/the-file.env" npx sovdev-selftest --backend grafana-cloud
```

Real output from a passing run:

```
✅ write-log: sent message="sovdev-selftest marker" under service_name=ollacrm-api-selftest
✅ write-metric: sent sovdev_operations_total{service_name="ollacrm-api-selftest"} 1
✅ read-log: "sovdev-selftest marker" at 2026-07-14T09:44:03.651Z
✅ read-metric: value=1 at 2026-07-14T09:44:06.224Z

✅ All checks passed.
```

## 4. Make the variables available to your deployed service

However you already do that.

## Using sovdev-logger itself

This page is only about credentials and connectivity. `sovdev_initialize()` itself hasn't changed — your existing call still works as-is.

What's new since your original integration is `sovdev_set_context()` (`client_name`, `service_principal`, `acting_user`) — call it once per request/operation, alongside your existing `sovdev_log()` calls. It's not just a nice-to-have: the dashboard's **"Active Clients"** panel is driven directly by `client_name` — it only counts requests where `client_name` was actually set, so without calling `sovdev_set_context()` that panel will show 0 for `ollacrm-api` no matter how much traffic it has. **"Active Integrations"** doesn't need this — it just counts `service_name`, which you already report today.

Call it once, in your auth middleware, right after resolving the caller's identity — every `sovdev_log()` call made afterward in the same request automatically inherits all three fields, with no argument threading needed:

```typescript
function authMiddleware(req, res, next) {
  sovdev_set_context({
    client_name: resolveClientFromApiKey(req.headers['x-api-key']), // your own logic — e.g. 'olla.helsestell.no'
    service_principal: 'ollacrm-db-svc',                            // the DB credential/account this API queries with
    acting_user: req.jwt.sub,                                       // the human end-user the request is scoped to
  });
  next();
}
```

Since every call your API handles is scoped to a real end-user, `acting_user` isn't conditional for you the way the general docs describe it — set it on every request alongside the other two fields. Two things worth knowing: this is request-scoped (safe under concurrent requests — one request's values never leak into another's), and since your backend is Grafana Cloud (third-party), the library prints a one-time console warning the first time `acting_user` is set, reminding you to use a pseudonymous/internal ID rather than a raw claim if it could carry personal data — it never blocks or strips the value.

For the exact API — `sovdev_log`, `sovdev_set_context`, spans, job-status logging — see the [TypeScript README](https://github.com/helpers-no/sovdev-logger/blob/main/typescript/README.md), the canonical, always-current reference.

## See also

- [Logging conventions](conventions.md) — how ollacrm actually uses the library in production: field mapping, log-level semantics, and per-layer patterns across ~90 call sites
- [Onboarding a new system](../index.md) — the generic recipe, for standing up a system's Grafana Cloud credentials from scratch
- [Quick check: sovdev-selftest](../../../contributor/testing/selftest-cli.md) — the full design behind the self-test command above
- [Dashboard walkthrough](../../dashboard-walkthrough/index.md) — what each panel means once data arrives

---

**Note**: if you still have the old scoped package installed (`@terchris/sovdev-logger`), it can safely be removed — `npm uninstall @terchris/sovdev-logger`. This only applies to ollacrm; no one else onboarding onto sovdev-logger will have it.
