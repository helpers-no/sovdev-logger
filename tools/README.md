# Tools

Repo-maintenance and cross-language verification tooling for sovdev-logger. Everything here is language-agnostic — it validates telemetry produced by any implementation's E2E test, not just one.

## Structure

```
tools/
├── validation/         # Does a language's OTLP output actually reach a real backend?
│   ├── schemas/        # JSON Schema definitions — the single source of truth for log/response shape
│   ├── validators/      # Python: schema validation + cross-validation against log files (backend-agnostic)
│   ├── uis/             # Bash + kubectl: local UIS (Urbalurba Infrastructure Stack) backend
│   └── grafana-cloud/   # TypeScript: Grafana Cloud backend (HTTP Basic Auth, no kubectl)
├── codegen/             # Schema-driven code generation (field-name constants per language)
├── dashboards/          # Grafana dashboard definitions owned by sovdev-logger, and the script that pushes them
└── repo-maintenance/    # Repo hygiene scripts (doc consistency checks, etc.)
```

**Why split `validation/` by backend?** Each OTLP backend (local UIS, Grafana Cloud, and whatever comes next — Azure Monitor, Google Cloud) has a different query API and auth model, so each gets its own subdirectory. All of them pipe their results through the *same* `validators/` — the comparison logic (does this data match the source log file, field by field) is written once and never duplicated per backend.

**Why split by backend, not by language?** These tools take a service name / log file as input and work identically regardless of which language produced the E2E test output — TypeScript, Python, or any future implementation. Language is a parameter, not a directory.

## Adding a new OTLP backend

1. New subdirectory under `validation/` (e.g. `validation/azure-monitor/`), named after the backend.
2. Implement query tools for that backend's API, in whatever language fits best (bash for `kubectl`-style access, TypeScript for HTTP APIs needing auth — see `grafana-cloud/` for that pattern).
3. Pipe results into the existing `validators/` scripts — don't reimplement comparison logic per backend.
4. Support `--compare-with FILE` at minimum — presence-only checks ("found: yes") can pass on stale or wrong data; exact-match comparison is the real bar.

## See also

- [Testing backends](https://sovdev-logger.sovereignsky.no/contributor/testing) — the verified, step-by-step workflow for each backend
