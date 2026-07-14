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

## See also

- [Onboarding a new system](../index.md) — the generic recipe, for standing up a system's Grafana Cloud credentials from scratch
- [Quick check: sovdev-selftest](../../../contributor/testing/selftest-cli.md) — the full design behind the self-test command above
- [Dashboard walkthrough](../../dashboard-walkthrough/index.md) — what each panel means once data arrives

---

**Note**: if you still have the old scoped package installed (`@terchris/sovdev-logger`), it can safely be removed — `npm uninstall @terchris/sovdev-logger`. This only applies to ollacrm; no one else onboarding onto sovdev-logger will have it.
