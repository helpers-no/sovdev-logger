---
title: Publishing the TypeScript package
sidebar_label: Publishing
sidebar_position: 1
description: "How to release a new version of sovdev-logger to npm."
---

# Publishing the TypeScript package

`sovdev-logger` (unscoped on npm; renamed from `@terchris/sovdev-logger` in 2026-07) is a real, published npm package — this is the maintainer-only release process, distinct from the (unpublished) Python package. This has only been done a handful of times; write down what actually happened, not a guessed process.

## Before you publish

1. **Decide the version bump** (semver): patch for a bug fix with no public API surface change, minor for a new function/parameter added without breaking anything, major for a breaking change to an existing function's signature or behavior. Bump `typescript/package.json`'s `"version"` field.
2. **Rebuild and sanity-check the tarball** before publishing anything:
   ```bash
   cd typescript
   npm run build
   npm pack --dry-run
   ```
   Confirm the version number and file list look right (should be `dist/`, `README.md`, `LICENSE` per the `"files"` field in `package.json` — nothing else).
3. **Run the conformance check** if the change touches `src/logger.ts` at all — `compare-with-master.sh typescript` (see [Testing backends](../testing/index.md)) — before publishing a behavioral change.

## Publish

`npm publish`/`npm login` both need a real interactive terminal (for OTP/browser-based login) — run these yourself in a real shell, not via a one-shot non-interactive command. **Corrected 2026-07-13**: this doc previously claimed the host Mac has no `npm` and required running via `dct-exec bash` inside the DevContainer — that's stale; `npm login`/`npm publish` both ran directly from the host terminal without issue.

```bash
cd typescript
npm login
```

`npm login` prints a browser-login URL and waits for you to complete it. **If the automatic browser-open fails** (headless container, no `xdg-open` target) — this is expected, not a real error. The CLI still printed the URL and is still waiting; open it yourself and it'll pick up as soon as you complete the login.

```bash
npm publish --access public
```

`--access public` is a no-op now that the package is unscoped (`sovdev-logger`, not `@terchris/sovdev-logger`) — unscoped packages on the public registry are always public, there's no private option to default away from. Harmless to keep in the command; kept here for the day this package (or a future one) is scoped again.

**Two things that look like errors but aren't:**
- `npm warn publish "repository.url" was normalized to "git+https://github.com/.../sovdev-logger.git"` — npm's own normalization of the `repository.url` field (adding `git+` and `.git`), not a problem with what's in `package.json`.
- A **second** interactive auth prompt appears during the publish step itself, separate from the `npm login` you already did:
  ```
  Authenticate your account at:
  https://www.npmjs.com/auth/cli/<uuid>
  Press ENTER to open in the browser...
  ```
  **Pressing ENTER only opens the browser tab — it does not complete the auth by itself.** Open that URL, and on the page it loads, enter the 6-digit code from your authenticator app (Google Authenticator or equivalent) *before* npm's CLI will proceed. The terminal sits waiting until that page confirms the code; only then does the publish actually go through.

**This step cannot be run non-interactively.** Confirmed directly: running `npm publish` via a scripted, non-interactive shell (no real TTY attached — e.g. a one-shot command with no terminal to respond to the prompt) gets all the way through building and packing the tarball, then fails at the very last step with `npm error EOTP — This operation requires a one-time password from your authenticator`. There's no way around this short of `--otp=<code>`, which still requires a human reading a live code off their authenticator app in the moment — there's no way to script or delegate this step.

## After publishing

- Confirm it landed: `npm view sovdev-logger version` should show the new version.
- If the change is behaviorally significant (not just docs/metadata), consider whether it's worth a note somewhere visible — this repo doesn't have a `CHANGELOG.md` yet; the commit history and the relevant `completed/PLAN-*.md` are the record for now.

## See also

- [API contract](../01-api-contract.md) — what counts as a breaking vs. non-breaking change to the public API
- [Development loop](../09-development-loop.md) — the edit/lint/build/validate cycle before you get to this point
