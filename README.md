# sovdev-logger

**Multi-language structured logging with zero-effort observability**

One log call. Complete observability. Currently available for TypeScript and Python, with Go, C#, Rust, PHP, and more planned.

---

## What is sovdev-logger?

One log call gives you structured logs, metrics, and distributed traces — correlated automatically — instead of hand-wiring a logger, a metrics client, and a tracer separately for every operation. It works with any OpenTelemetry-compatible backend: Azure Monitor, Grafana Cloud, Datadog, New Relic, Honeycomb, or self-hosted Loki/Prometheus/Tempo.

You write code for yourself, but you write **logs** for the on-call engineer debugging a production incident who doesn't know your codebase. sovdev-logger makes the useful version (structured, correlated, with real context) the default, not extra effort.

See **[Why OTLP](https://sovdev-logger.sovereignsky.no/general/why-otlp)** for why it's built this way — including the real tradeoffs, not just the benefits — and the [docs site](https://sovdev-logger.sovereignsky.no) for the full picture: usage guides, configuration, and the specification every language implementation follows.

---

## Supported Languages

| Language | Status | Documentation |
|----------|--------|---------------|
| **TypeScript** | ✅ Available | [typescript/README.md](typescript/README.md) |
| **Python** | ✅ Available | [python/README.md](python/README.md) |
| **Go** | 📅 Planned | - |
| **C#** | 📅 Planned | - |
| **Rust** | 📅 Planned | - |
| **PHP** | 📅 Planned | - |

---

## Quick Start

**Using the library in your application:**

```bash
npm install sovdev-logger           # TypeScript — see typescript/README.md
pip install -r requirements.txt      # Python, from the python/ directory — see python/README.md
```

Full API reference, examples, and configuration live in each language's own README, and on the [docs site](https://sovdev-logger.sovereignsky.no/using) (in progress — the READMEs are authoritative until that migration completes).

**Implementing sovdev-logger in a new language:**

1. Read [Implementation guide](https://sovdev-logger.sovereignsky.no/contributor/implementation-guide) — the end-to-end process: contract → TypeScript → anti-patterns → implement → `compare-with-master.sh`
2. Study [`typescript/src/logger.ts`](typescript/src/logger.ts) — the master implementation
3. Run `tools/validation/uis/compare-with-master.sh {language}` until it passes — the actual completion gate, not a checklist

See the [contributor docs](https://sovdev-logger.sovereignsky.no/contributor) for the full specification.

---

## Documentation

- **Docs site**: [sovdev-logger.sovereignsky.no](https://sovdev-logger.sovereignsky.no) — why OTLP, usage guides, the specification
- **TypeScript**: [typescript/README.md](typescript/README.md) — complete API reference, examples, patterns (canonical — other languages diff against this)
- **Python**: [python/README.md](python/README.md) — complete API reference, notes differences from TypeScript
- **Configuration**: [Configuration](https://sovdev-logger.sovereignsky.no/using/configuration) — environment variables, OTLP setup, file logging
- **Log data structure**: [Log data structure](https://sovdev-logger.sovereignsky.no/using/logging-data) — field reference, logging patterns, correlation strategies
- **Observability architecture**: [Observability architecture](https://sovdev-logger.sovereignsky.no/using/observability-architecture) — dashboard setup, verification
- **Loggeloven compliance**: [Loggeloven compliance](https://sovdev-logger.sovereignsky.no/using/loggeloven) — Norwegian Red Cross logging requirements

---

## License

MIT License - Copyright (c) 2025 Norwegian Red Cross

See [LICENSE](LICENSE) for details.

---

## Support

- **GitHub Issues**: [https://github.com/helpers-no/sovdev-logger/issues](https://github.com/helpers-no/sovdev-logger/issues)
- **Documentation**: See language-specific README files in each directory

---

## Repository Status

This repository implements a multi-language logging library with identical output across all languages.

**Development Status:**

- ✅ **Specification v2.1.0** - Complete implementation guide
- ✅ **TypeScript** - Complete, master implementation (snake_case API)
- ✅ **Python** - Conformant, verified field-for-field against TypeScript via `tools/validation/uis/compare-with-master.sh`
- 📅 **Go, C#, Rust, PHP** - Planned

**All implementations follow:**
- Identical API (8 functions)
- Identical output format (JSON with snake_case fields)
- Identical validation requirements
- Source of truth: [Contributor documentation](https://sovdev-logger.sovereignsky.no/contributor)
