# Investigate: Make `using/onboarding/ollacrm/index.md` a real, self-serve checklist

Whether ollacrm can actually follow `using/onboarding/ollacrm/index.md` end-to-end on her own — surfaced by a real broken command in the page's own step 3, and by how much of the page's newest section only exists because of a live conversation with the maintainer, not because the doc was self-sufficient.

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Backlog

**Goal**: A version of the ollacrm onboarding page that a developer can follow start-to-finish without needing a live conversation to fill gaps — proven by an actual cold-start attempt, not just a read-through.

**Last Updated**: 2026-07-14

---

## Background — two concrete gaps found the same day the page shipped

`using/onboarding/ollacrm/index.md` was rewritten this session into a clean 4-step checklist plus a "Using sovdev-logger itself" section, committed and pushed. The same day, walking through the real procedure surfaced two separate, concrete problems — not a vague "docs could be better" feeling.

### 1. Confirmed real bug: step 3's command fails exactly as documented

Step 3 reads:

```bash
NODE_OPTIONS="--env-file=/path/to/the-file.env" npx sovdev-selftest --backend grafana-cloud
```

Ollacrm's real terminal, running this literally:

```
node: --env-file= is not allowed in NODE_OPTIONS
```

This is a hard Node.js restriction, not a version quirk — Node explicitly blocklists a handful of flags (including `--env-file`) from being set via `NODE_OPTIONS`, almost certainly because `NODE_OPTIONS` is itself an environment variable, and allowing it to force-read an arbitrary file would be a security footgun. Confirmed locally: `NODE_OPTIONS="--env-file=/dev/null" node -e "..."` fails identically on this machine (Node 20.11.0), and this is documented Node behavior, not something that improves at a later Node version.

**Root cause of how this shipped broken**: earlier this session, `dotenv-cli` was replaced with `NODE_OPTIONS="--env-file="` specifically to avoid requiring non-Node developers to install an extra Node-specific tool just to set env vars — a deliberate call favoring language-agnostic tooling for cross-language concerns. That substitution was never actually run end-to-end before being published — the first real test was ollacrm's own terminal, today.

### 2. The "Using sovdev-logger itself" section only exists because of a live Q&A cycle

Before this session, the page had **zero** mention of `sovdev_set_context()`, `client_name`, `service_principal`, or `acting_user` — despite all three already existing in the library and directly driving one of her own dashboard panels ("Active Clients" shows `0` without them). Arriving at the content now on the page required, in order:

- Being told directly which dashboard panel depends on which field — not written down anywhere beforehand.
- Reading `INVESTIGATE-context-propagation.md` to recover the concrete value `client_name` should hold for her specifically (her registered frontend names, e.g. `olla.helsestell.no`) — not on the onboarding page itself.
- A live back-and-forth to establish that `acting_user` is effectively mandatory for her API specifically (every call is user-scoped), contradicting the general library docs' "only when applicable" framing.
- Reviewing her actual `requireUser` middleware table to confirm `client_name`/`service_principal` were wired correctly, and catch that `acting_user` was a raw email rather than a pseudonymous ID.

None of this reflects badly on the page's *current* content — it's now accurate and complete. The concern is structural: **the page's completeness depended entirely on a maintainer already holding all this context, asking the right questions in real time.** The next customer after ollacrm won't have that conversation available.

---

## Options

### Option A: Fix the immediate command bug directly, as its own small fix

Give `sovdev-selftest` (and any future sovdev-logger CLI) its own `--env-file <path>` argument, loaded internally via Node's `process.loadEnvFile()` API — never touching `NODE_OPTIONS` at all. Since `sovdev-selftest` is already a Node program, this doesn't reintroduce the "don't force non-Node developers to install Node" problem the `NODE_OPTIONS` switch was originally solving — that concern is about a *consumer's own app*, not about running this CLI, which already requires Node.

**Not yet verified**: `process.loadEnvFile()`'s availability at the package's stated `engines.node: >=22.0.0` floor. Confirmed `undefined` on the highest version installed locally via `nvm` (21.6.1) — needs a real Node 22 install to confirm it's actually present and stable there, not just check documentation.

**Alternative within this option**: invoke `node` directly with its own `--env-file` flag (valid as a direct CLI arg — only disallowed inside `NODE_OPTIONS`), pointed at the CLI's resolved entry file instead of going through `npx`. Rejected as the primary fix: fragile (differs by install method — local vs global vs monorepo), and reintroduces exactly the kind of "one more thing to get right" step 3 was trying to avoid.

**Pros**: small, targeted, fixes the actively-broken command today.
**Cons**: doesn't address the second, structural gap (section 2 above) at all.

### Option B: A "cold start" dry-run process for onboarding docs generally

Before considering any onboarding page (ollacrm's, or a future generic template) done, have a fresh reviewer — an agent with no prior context on this project, or a real person unfamiliar with the internals — attempt to follow it literally, step by step, in an isolated environment, and report every point they got stuck, had to guess, or hit a command that failed. This is a **dry-run** review, structurally different from a read-through review: a read-through catches unclear prose, a dry-run catches exactly the class of bug found here (a command that reads fine but has never actually been executed).

**Pros**: would have caught the `NODE_OPTIONS` bug before ollacrm did; directly targets the structural problem (docs whose completeness depends on the author's live availability), not just today's symptom.
**Cons**: process work, not a one-time fix — needs deciding when this dry-run happens (before every onboarding-doc edit? only before major rewrites?) and who/what performs it cheaply enough to actually happen.

### Option C: Do nothing beyond the command fix, treat future gaps as they surface

**Pros**: zero process overhead.
**Cons**: this is the second time in one session a real gap in this exact page was found only because a real user hit it live — no reason to expect this was the last one, and the next customer after ollacrm won't have a maintainer on a live call to unblock them.

---

## Recommendation

**Option A now** (fix the actively-broken command — ollacrm is blocked on this today), **Option B as the actual answer to "how do we know it's self-serve"** — worth scoping as its own follow-up once Option A ships, rather than bundling a process change with today's urgent fix.

---

## Open Questions

1. **[Q1]** Does `process.loadEnvFile()` actually work as expected on Node `>=22.0.0` (this package's stated floor)? Not verifiable on this machine today (`nvm`'s highest installed version is 21.6.1, where the API is `undefined`) — needs a real Node 22 install to confirm before committing to Option A.
2. **[Q2]** Should the fixed command still be demonstrated as working *before* being handed to the next real customer, given the `NODE_OPTIONS` command was published without that check? What's the minimum verification that would have caught this (a CI step, a local smoke test, a dry run per Option B) without over-engineering a one-line doc fix?
3. **[Q3]** Does Option B belong on every onboarding-doc change, or only substantial rewrites (like the one that shipped this session)? A cost/frequency question, not yet answered.
4. **[Q4]** Should the concrete field-value guidance recovered this session (which env var maps to which dashboard panel, what `client_name`/`service_principal`/`acting_user` should actually contain for a JWT-driven, DB-impersonating API like ollacrm's) be generalized into reusable guidance for the *next* customer, or is it inherently ollacrm-specific? Relates to [Q2] in `INVESTIGATE-docs-site-structure.md` (whether a generic developer-quickstart template is worth building yet).

## Next Steps

- [ ] **[Q1]** Install a real Node `>=22.0.0`, confirm `process.loadEnvFile()` behavior directly
- [ ] Draft a `PLAN-*.md` for Option A once [Q1] is confirmed
- [ ] Decide scope/cadence for Option B ([Q3]) — separate from the urgent fix
- [ ] Re-verify step 3's fixed command with ollacrm herself once shipped

## Files to Modify (Option A)

- `typescript/src/cli/selftest.ts` (or wherever the CLI entrypoint lives) — accept `--env-file <path>`, load via `process.loadEnvFile()`
- `website/docs/using/onboarding/ollacrm/index.md` — update step 3's command
- `website/docs/using/onboarding/index.md` — check for the same `NODE_OPTIONS` pattern elsewhere, if present
- `typescript/README.md` — same, if the broken pattern is documented there too
