---
title: "UIS (local)"
sidebar_label: "UIS (local)"
sidebar_position: 1
description: "Set up Urbalurba Infrastructure Stack locally via Rancher Desktop, and point a language's E2E test at it."
---

# Testing against UIS

[UIS (Urbalurba Infrastructure Stack)](https://uis.sovereignsky.no/) is "a complete datacenter on your laptop" — a Kubernetes-based local infrastructure platform, installed via a small CLI that provisions services (including a full observability stack) onto a local cluster. This page documents standing it up and pointing a language's E2E test at it — the process is the same shape for any future backend documented under [Testing backends](index.md). Steps 1–3 are shared; step 4 covers TypeScript and step 6 covers Python — both have been verified end-to-end against a live UIS stack.

## 1. Prerequisite: Kubernetes enabled in Rancher Desktop, with enough memory

UIS needs a local Kubernetes cluster. In Rancher Desktop's settings, enable Kubernetes (off by default). Confirm it's up:

```bash
kubectl config current-context   # should print: rancher-desktop
kubectl get nodes                # should show one Ready control-plane node
```

**Give the VM enough memory.** Rancher Desktop's default (4GB RAM / 2 CPU) is not enough to run the full observability stack (Prometheus, Tempo, Loki, an OTel Collector, and Grafana, on top of core k3s components) — it manifests as pods crash-looping every few seconds and queries silently returning nothing. Increase it in Rancher Desktop → Preferences → Virtual Machine (7GB / 4 CPU worked reliably on a 16GB/8-core host) and restart Rancher Desktop. After restarting, `uis-provision-host` (the container UIS's CLI uses to reach the cluster) does not come back on its own — start it manually:

```bash
docker start uis-provision-host
```

Before trusting any query result, confirm the stack is actually stable, not just up:

```bash
docker exec uis-provision-host kubectl get pods -n monitoring
```

All pods should show `Running` with their full ready count (e.g. `2/2`, not `1/2`), and restart counts should stay constant if you check again a couple of minutes later. A pod that's `Running` but not fully ready, or whose restart count is still climbing, means the stack hasn't settled — don't test against it yet, the results won't be trustworthy (see [Troubleshooting](#troubleshooting) below).

## 2. Install the UIS CLI and start it

From any directory outside this repo (UIS is a general-purpose local infrastructure tool, not part of sovdev-logger itself):

```bash
curl -fsSL https://raw.githubusercontent.com/helpers-no/urbalurba-infrastructure/main/uis -o uis
chmod +x uis
./uis start
```

`./uis start` pulls a provisioning container (`ghcr.io/helpers-no/uis-provision-host`), initializes `.uis.extend/` (config, safe to commit) and `.uis.secrets/` (gitignored), and applies a base set of Kubernetes secrets and namespaces — including `monitoring`, which is what the rest of this page uses.

## 3. Install the observability stack

```bash
./uis stack install observability
```

This deploys **Prometheus, Tempo, Loki, an OpenTelemetry Collector, and Grafana** into the `monitoring` namespace via Ansible + Helm, and — notably — the installer itself runs a full end-to-end validation before declaring success: it sends real test logs/traces/metrics through the OTel Collector and queries each backend to confirm they arrived. Confirmed on a real run: all three pipelines (logs→Loki, traces→Tempo, metrics→Prometheus) reported `PASS`, and Grafana's datasource connectivity to all three was verified the same way.

**Endpoints this leaves you with** (from the installer's own output, all routed through Traefik on `localhost`, no port needed):

| What | URL | Notes |
|---|---|---|
| OTLP HTTP (logs/traces/metrics) | `http://otel.localhost/v1/logs`, `/v1/traces`, `/v1/metrics` | IngressRoute matches `HostRegexp: otel\..+` — the `Host` header is what routes the request, not the domain name resolving to a specific IP |
| Grafana UI | `http://grafana.localhost` | `admin` / `SecretPassword1` |

UIS also deploys a **"Sovdev Logger - Overview"** Grafana dashboard by default as part of this stack — it's built with this project specifically in mind.

## 4. Point the TypeScript E2E test at it

The sovdev-logger devcontainer can't resolve `otel.localhost` directly (it's a hostname Traefik matches on the host's network, not a name any DNS resolves) — from inside the devcontainer, reach it via `host.docker.internal` with an explicit `Host` header instead. Copy `typescript/test/e2e/company-lookup/.env.example` to `.env` in the same directory — it already has the right values:

```bash
OTEL_EXPORTER_OTLP_LOGS_ENDPOINT=http://host.docker.internal/v1/logs
OTEL_EXPORTER_OTLP_METRICS_ENDPOINT=http://host.docker.internal/v1/metrics
OTEL_EXPORTER_OTLP_TRACES_ENDPOINT=http://host.docker.internal/v1/traces
OTEL_EXPORTER_OTLP_HEADERS=Host=otel.localhost
OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf
```

`OTEL_EXPORTER_OTLP_HEADERS` is the standard OpenTelemetry format — comma-separated `key=value` pairs, no quoting needed. (This used to be documented as a JSON value requiring load-bearing single quotes to survive bash's `source` — that was working around a real bug in sovdev-logger itself, not a genuine OTel requirement; see [`INVESTIGATE-otlp-headers-standard-compliance.md`](../../ai-developer/plans/backlog/INVESTIGATE-otlp-headers-standard-compliance.md) for the full story and [Troubleshooting](#troubleshooting) below.)

## 5. Run the TypeScript test and verify data actually arrived

```bash
dct-exec bash -c "cd /workspace/typescript/test/e2e/company-lookup && bash run-test.sh"
```

(`dct-exec` is this repo's devcontainer-toolbox host helper — it finds the running devcontainer via a Docker label instead of a fixed name. Install it via `curl -fsSL https://raw.githubusercontent.com/helpers-no/devcontainer-toolbox/main/install.sh | bash` if it's not already on your `PATH`. The older `specification/tools/in-devcontainer.sh` wrapper hardcoded a container name that no longer matches how the devcontainer actually runs — it's been deleted in favor of `dct-exec`.)

Expected result: **17 log entries** (matching `08-testprogram-company-lookup.md`'s documented scenario — 3 successful lookups, 1 intentional failure), schema validation passing with real trace/span IDs found, and a clean OTLP flush/shutdown.

Passing schema validation only proves the file log is well-formed — it doesn't prove the data reached the backend, and it doesn't prove the backend has *this run's* data rather than some earlier run's. A query that merely checks "is this service name present" can be a false positive: it doesn't distinguish this run from a stale one, and (as found the hard way — see [Troubleshooting](#troubleshooting)) it can also report success on a genuinely empty or failed query if the tool doesn't check carefully. Use `--compare-with` instead, which cross-checks the backend's data against the actual log file by `trace_id`/`event_id`, so a mismatch or missing entry is a hard failure, not a maybe:

```bash
dct-exec bash -c "cd /workspace/specification/tools && ./query-loki.sh sovdev-test-company-lookup-typescript --compare-with /workspace/typescript/test/e2e/company-lookup/logs/dev.log"
dct-exec bash -c "cd /workspace/specification/tools && ./query-tempo.sh sovdev-test-company-lookup-typescript --compare-with /workspace/typescript/test/e2e/company-lookup/logs/dev.log"
dct-exec bash -c "cd /workspace/specification/tools && ./query-prometheus.sh sovdev-test-company-lookup-typescript --compare-with /workspace/typescript/test/e2e/company-lookup/logs/dev.log"
```

Expect: Loki reports all 17 entries matching by trace_id/event_id; Tempo reports the 4 spanned entries matching (traces can take a few seconds to become searchable after ingestion — retry once if it comes back empty); Prometheus reports all 5 metric groups matching **only if queried within a few minutes of the run** — the OTel Collector only exposes a one-shot process's pushed metrics for a short window after it exits, so check promptly.

## 6. Point the Python E2E test at it — and the quoting difference

Python's E2E test (`python/test/e2e/company-lookup/`) uses the exact same UIS endpoints and headers, and works the same way: copy `.env.example` to `.env` in that directory, then run it via `dct-exec`:

```bash
dct-exec bash -c "cd /workspace/python/test/e2e/company-lookup && bash run-test.sh"
```

`OTEL_EXPORTER_OTLP_HEADERS` uses the same real OTel spec format as TypeScript (comma-separated `key=value`, no quoting needed here regardless):

```bash
OTEL_EXPORTER_OTLP_HEADERS=Host=otel.localhost
```

**Quoting is never load-bearing for Python either way** — TypeScript's `run-test.sh` loads `.env` with bash's `source`, which word-splits unquoted values containing a space or embedded quote character. Python's test loads `.env` with `python-dotenv`'s `load_dotenv()` (in `company-lookup.py`), which doesn't do shell-style parsing — so even a value containing a space (e.g. a Basic Auth token) works unquoted here.

Confirmed empirically, not assumed: re-ran the test after porting Python's header handling to stop `json.loads`-parsing this env var itself (letting the OTel SDK's own `parse_env_headers()` read it natively, matching the real spec) — clean run, 17 log entries, correct 3-success/1-failure pattern, `TracerProvider` initialized correctly. Verified the data landed the same way as TypeScript, using `--compare-with` for the same exact trace_id/event_id cross-check (not just "service found"):

```bash
dct-exec bash -c "cd /workspace/specification/tools && ./query-loki.sh sovdev-test-company-lookup-python --compare-with /workspace/python/test/e2e/company-lookup/logs/dev.log"
dct-exec bash -c "cd /workspace/specification/tools && ./query-tempo.sh sovdev-test-company-lookup-python --compare-with /workspace/python/test/e2e/company-lookup/logs/dev.log"
dct-exec bash -c "cd /workspace/specification/tools && ./query-prometheus.sh sovdev-test-company-lookup-python --compare-with /workspace/python/test/e2e/company-lookup/logs/dev.log"
```

All three matched exactly (17/17 log entries, 4/4 spans, 5/5 metric groups), and a subsequent `compare-with-master.sh python` run still reported a clean match against TypeScript's output — testing against a live backend didn't change Python's behavior relative to the reference implementation.

## Troubleshooting

**A query reports the service "found" but you're not sure it's *this* run's data, or `query-loki.sh` returns nothing.** Two real bugs existed here and are now fixed, but are worth knowing about since they explain why a naive verification can lie to you:

- `query-loki.sh` used to `kubectl exec` into the `loki-0` pod and run `wget` inside it. The `grafana/loki` image has no shell or `wget` — just the `loki` binary — so that could never work; it's now a disposable `kubectl run --image=curlimages/curl` pod instead, the same approach `query-tempo.sh`/`query-prometheus.sh` already used.
- All three `query-*.sh` scripts strip known kubectl noise (audit banners, "pod deleted" messages) from the raw output before parsing it as JSON — because `kubectl run -i` doesn't emit that noise consistently, a leftover blacklist-style filter can still let stray text through and break JSON parsing, or (in Loki's case) an empty/broken response used to be silently reported as "found" because the failure check compared against the literal string `"0"`, which an empty response doesn't satisfy. Prefer `--compare-with` over the presence-only check for exactly this reason — a real trace_id/event_id mismatch fails loudly, "found: yes" does not.

**Prometheus `--compare-with` reports 0 matches even though the run clearly succeeded.** Check how much time has passed since the run. Metrics from a one-shot process are pushed once at flush time; the OTel Collector only exposes them for a short window afterward. Re-run the test and check Prometheus within a couple of minutes.

**Historical: `OTEL_EXPORTER_OTLP_HEADERS` used to require single-quoting, and flush would silently drop telemetry with any Basic-Auth-style header.** sovdev-logger used to document (and require) this env var as JSON — its own contract was wrong. The underlying OTel SDK reads this same, reserved env var name natively, expecting the real spec format (comma-separated `key=value`), independently of whatever the app explicitly passed to its exporters. For UIS's `Host` header this only caused a silent config-validation no-op; for any header value containing `=` (e.g. Basic Auth tokens, since base64 padding uses `=`) it crashed flush with `ERR_INVALID_HTTP_TOKEN`, silently dropping that flush's telemetry. Fixed — see [`INVESTIGATE-otlp-headers-standard-compliance.md`](../../ai-developer/plans/backlog/INVESTIGATE-otlp-headers-standard-compliance.md) for the full root-cause trace through the actual OTel SDK source.
