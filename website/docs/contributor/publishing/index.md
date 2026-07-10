---
title: Publishing per-language packages
sidebar_label: Publishing
sidebar_position: 0
description: "How to release each language's package to its registry — one language at a time, as each one gets there."
---

# Publishing per-language packages

Each language implementation publishes to its own registry (npm, PyPI, crates.io, NuGet, Packagist, ...), with its own login flow, its own gotchas, and its own maintainer-only release process. This section documents that, one language at a time, as each one actually reaches a published state — not written speculatively ahead of a real release.

## Pages

- **[TypeScript](typescript.md)** — `@terchris/sovdev-logger` on npm. The only language published so far.

## Not yet published

- **Python** — implemented and conformant (`compare-with-master.sh` passes), but not yet published to PyPI as a standalone package; install from this repo's `python/` directory for now (see [`python/README.md`](https://github.com/helpers-no/sovdev-logger/blob/main/python/README.md)).
- Go, C#, Rust, PHP — not yet implemented.

Add a page here the same day a language's package actually gets published for the first time — that's the point at which "how do I publish this" stops being a hypothetical and needs a real, verified answer, the same way [`typescript.md`](typescript.md) only exists because it's already happened.
