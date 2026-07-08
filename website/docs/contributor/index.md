---
title: Contributor documentation
sidebar_label: Contributor
sidebar_position: 0
description: "The specification and implementation contract for people building or maintaining a sovdev-logger language port."
---

# Contributor documentation

For people (human or LLM) **implementing or maintaining** a sovdev-logger language port — the API contract, field definitions, and design rationale every implementation must follow. Not for people just using the library; see [Using sovdev-logger](../using/index.md) for that.

> **Stub.** The specification's prose (`specification/00-design-principles.md` through `10-code-quality.md`, `implementation-guide.md`) is still being migrated in — see [PLAN-005](../ai-developer/plans/completed/PLAN-005-documentation-restructure.md) for what's landed so far and the follow-up plan for the rest. In the meantime, [`specification/`](https://github.com/helpers-no/sovdev-logger/tree/main/specification) in the repo is the authoritative source — start with [`specification/implementation-guide.md`](https://github.com/helpers-no/sovdev-logger/blob/main/specification/implementation-guide.md).

## Planned pages

- Design principles and key design decisions
- The API contract (function signatures every language implements)
- Field definitions (every log field, its type, and when it's present)
- Anti-patterns (the mistakes every prior implementation attempt has actually made)
- The implementation process (read the contract, study TypeScript, run `compare-with-master.sh` until it passes)
