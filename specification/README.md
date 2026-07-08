# Sovdev Logger Specification

The specification's prose (design principles, API contract, field definitions, anti-patterns, the implementation process) has moved to the Docusaurus site: **[Contributor documentation](https://sovdev-logger.sovereignsky.no/contributor)**, migrated in [PLAN-006](../website/docs/ai-developer/plans/completed/PLAN-006-documentation-content-migration.md). Start there — [`Implementation guide`](https://sovdev-logger.sovereignsky.no/contributor/implementation-guide) is the short version of the whole process.

## What's still here

This directory keeps the **functional code**, which was never documentation and was never migrated:

- **[`schemas/`](schemas/)** — JSON Schema definitions for the exact log format (`log-entry-schema.json`, Loki/Prometheus/Tempo response schemas)
- **[`tests/`](tests/)** — the validators and comparators, including `compare-log-files.py`
- **[`tools/`](tools/)** — the validation and query scripts, including `compare-with-master.sh` (the actual completion gate — see [`tools/README.md`](tools/README.md)) and `generate-field-constants.py`
- **[`llm-work-templates-archive/`](llm-work-templates-archive/)** — superseded process scaffolding, kept for reference, not maintained (see [PLAN-003](../website/docs/ai-developer/plans/completed/PLAN-003-spec-scaffolding-cleanup.md))

**Specification Status:** ✅ v2.1.0 COMPLETE
**Reference Implementation:** TypeScript (`typescript/`)
