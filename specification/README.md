# Sovdev Logger Specification

The specification's prose (design principles, API contract, field definitions, anti-patterns, the implementation process) has moved to the Docusaurus site: **[Contributor documentation](https://sovdev-logger.sovereignsky.no/contributor)**, migrated in [PLAN-006](../website/docs/ai-developer/plans/completed/PLAN-006-documentation-content-migration.md). Start there — [`Implementation guide`](https://sovdev-logger.sovereignsky.no/contributor/implementation-guide) is the short version of the whole process.

## What's still here

The **functional code** that used to live here (`schemas/`, `tests/`, `tools/`) moved to top-level [`tools/`](../tools/) — see [`tools/README.md`](../tools/README.md) for the new structure (organized by OTLP backend: local UIS, Grafana Cloud, and future backends). This keeps validation tooling in one place regardless of which language or backend it targets, rather than nested under a folder named after documentation that itself moved elsewhere.

- **[`llm-work-templates-archive/`](llm-work-templates-archive/)** — superseded process scaffolding, kept for reference, not maintained (see [PLAN-003](../website/docs/ai-developer/plans/completed/PLAN-003-spec-scaffolding-cleanup.md))

**Specification Status:** ✅ v2.1.0 COMPLETE
**Reference Implementation:** TypeScript (`typescript/`)
