#!/usr/bin/env node
// sovdev-selftest -- writes a marker log + metric, reads both back, reports
// a four-signal PASS/FAIL. See INVESTIGATE-selftest-cli.md and
// PLAN-selftest-cli.md for the full design.

import { parseArgs } from 'node:util';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { resolveSelftestConfig } from './backend-config.js';
import { SELFTEST_MARKER_MESSAGE } from './marker.js';
import { queryLoki, queryPrometheus } from './signal-clients.js';
import { pollForSignal, type SignalResult } from './poll.js';
import { report } from './report.js';
import { logProgress } from './progress.js';
// NOT a top-level import, deliberately: write-step.ts imports the full
// sovdev-logger library (../index.js), which pulls in the entire
// @opentelemetry/* SDK chain -- measured at ~434ms to load. A static import
// here would pay that cost before main() (and the version banner) ever
// runs, even for --help. Loaded lazily instead, after the banner prints.

const LOG_TIMEOUT_MS = 30_000;
const METRIC_TIMEOUT_MS = 60_000;
const POLL_INTERVAL_MS = 2_000;

// This package's own version (dist/cli/selftest.js -> ../../package.json is
// typescript/package.json), not the consuming app's -- a different question
// than logger.ts's getServiceVersion(), which reads process.cwd()'s
// package.json (the app using the library, not the library itself).
function getOwnVersion(): string {
  try {
    const packageJson = JSON.parse(
      readFileSync(join(__dirname, '..', '..', 'package.json'), 'utf8')
    ) as {
      version?: string;
    };
    return packageJson.version ?? 'unknown';
  } catch {
    return 'unknown';
  }
}

// Loki: the message text is in each stream's `values[0][1]` (the log line
// itself) -- structured fields (function_name, log_type, etc.) live in the
// stream's own labels, not the line, per sovdev-logger's OTLP-to-Loki shape.
function extractLokiDetail(response: unknown): string | null {
  const data = response as { data?: { result?: Array<{ values: [string, string][] }> } };
  const streams = data.data?.result ?? [];
  if (streams.length === 0) return null;
  const [timestampNs, line] = streams[0].values[0];
  const timestamp = new Date(Number(BigInt(timestampNs) / 1_000_000n)).toISOString();
  return `"${line}" at ${timestamp}`;
}

// Prometheus: the value is in each result's `value[1]` (a string), `value[0]`
// is the Unix timestamp in seconds (not nanoseconds, unlike Loki).
function extractPrometheusDetail(response: unknown): string | null {
  const data = response as { data?: { result?: Array<{ value: [number, string] }> } };
  const series = data.data?.result ?? [];
  if (series.length === 0) return null;
  const [timestampSec, value] = series[0].value;
  const timestamp = new Date(timestampSec * 1000).toISOString();
  return `value=${value} at ${timestamp}`;
}

// Two independent sources of stdout noise in --json mode, both from the
// write step, neither of them ours to fix upstream:
// 1. sovdev_initialize()/sovdev_shutdown() print their own diagnostic
//    console.log/console.warn lines (session ID, OTLP setup, flush/shutdown
//    progress) -- caught by overriding console.log/console.warn directly.
// 2. If the ambient environment has LOG_TO_CONSOLE=true (e.g. inherited from
//    sourcing an E2E test's .env file, as real usage found), sovdev-logger's
//    own Winston console transport prints the marker log line itself --
//    that's a real application log line, not an SDK diagnostic, so
//    console.log/console.warn overrides alone don't catch it (Winston's
//    transport writes through its own configured stream). Forced off for
//    the duration of the write step in --json mode instead.
// Both are useful in plain-text mode (a human watching it run), so both are
// scoped to --json mode only. Note this does NOT touch console.error --
// logProgress()'s timestamped lines stay visible even in --json mode.
async function withSuppressedConsole<T>(suppress: boolean, fn: () => Promise<T>): Promise<T> {
  if (!suppress) return fn();
  const originalLog = console.log;
  const originalWarn = console.warn;
  const originalLogToConsole = process.env.LOG_TO_CONSOLE;
  console.log = (): void => {};
  console.warn = (): void => {};
  process.env.LOG_TO_CONSOLE = 'false';
  try {
    return await fn();
  } finally {
    console.log = originalLog;
    console.warn = originalWarn;
    if (originalLogToConsole === undefined) {
      delete process.env.LOG_TO_CONSOLE;
    } else {
      process.env.LOG_TO_CONSOLE = originalLogToConsole;
    }
  }
}

interface HelpOption {
  flag: string;
  description: string[];
}

const HELP_OPTIONS: HelpOption[] = [
  {
    flag: '--backend grafana-cloud|uis',
    description: [
      'Which backend to write to and read back from. Required when',
      "both backends' env vars are set at once (the normal case in",
      "this project's own devcontainer) -- auto-detected only when",
      'exactly one backend is configured.',
    ],
  },
  {
    flag: '--service-name NAME',
    description: [
      'Real service name to use (defaults to $OTEL_SERVICE_NAME).',
      'The actual write/read happens under "<name>-selftest".',
    ],
  },
  {
    flag: '--json',
    description: [
      'Machine-readable output for CI: the four signals as one JSON',
      'line on stdout, nothing else on stdout. Progress still prints',
      'to stderr.',
    ],
  },
  { flag: '--help', description: ['Show this help and exit.'] },
];

// Column width computed from the actual flag strings above, not a
// hand-counted number of spaces -- a hardcoded column would silently go out
// of alignment the next time a flag/description changes, which is the same
// kind of "looks right but isn't" gap this tool exists to avoid elsewhere.
function formatHelp(): string {
  const indentWidth = Math.max(...HELP_OPTIONS.map((o) => o.flag.length)) + 2 + 3;
  const indent = ' '.repeat(indentWidth);
  const optionLines = HELP_OPTIONS.flatMap(({ flag, description }) => {
    const [firstLine, ...restLines] = description;
    return [`  ${flag}`.padEnd(indentWidth) + firstLine, ...restLines.map((line) => indent + line)];
  });

  return [
    'sovdev-selftest -- confirms a logging/metrics backend connection actually works.',
    '',
    'Writes one marker log + one marker metric under a disposable',
    '<service-name>-selftest name (so it never touches your real dashboard data),',
    'then reads both back from the backend itself -- not just "the write call',
    "didn't throw\", which OTLP exporters don't guarantee reflects real delivery.",
    'Reports four independent signals: write-log, write-metric, read-log,',
    'read-metric. Exits 0 only if all four pass, 1 otherwise.',
    '',
    'Usage: sovdev-selftest [options]',
    '',
    'Options:',
    ...optionLines,
    '',
    'Required environment variables (see contributor/testing/selftest-cli.md for',
    'the full list and devcontainer-specific notes):',
    '  Grafana Cloud: GRAFANA_CLOUD_INGEST_TOKEN, GRAFANA_CLOUD_VERIFY_TOKEN,',
    '                 GRAFANA_CLOUD_OTLP_ENDPOINT, GRAFANA_CLOUD_OTLP_INSTANCE_ID,',
    '                 GRAFANA_CLOUD_LOKI_URL, GRAFANA_CLOUD_LOKI_INSTANCE_ID,',
    '                 GRAFANA_CLOUD_PROMETHEUS_URL, GRAFANA_CLOUD_PROMETHEUS_INSTANCE_ID',
    '  UIS:           GRAFANA_URL, GRAFANA_USER, GRAFANA_PASSWORD',
    '                 (+ GRAFANA_HOST_HEADER, optional, only needed from inside a',
    '                 devcontainer where GRAFANA_URL points at host.docker.internal)',
    '  Both backends also need the usual OTEL_EXPORTER_OTLP_*_ENDPOINT /',
    '  OTEL_SERVICE_NAME variables any sovdev-logger app needs to write logs at all.',
  ].join('\n');
}

async function main(): Promise<void> {
  // Printed to stderr, not stdout -- always visible on screen (including in
  // --json mode), but never part of the stdout stream a CI script parses as
  // JSON. First thing printed, before sovdev_initialize()'s own output.
  logProgress(`sovdev-selftest v${getOwnVersion()} (@terchris/sovdev-logger)`);

  const { values } = parseArgs({
    options: {
      backend: { type: 'string' },
      json: { type: 'boolean', default: false },
      'service-name': { type: 'string' },
      help: { type: 'boolean', default: false },
    },
  });

  if (values.help) {
    console.log(formatHelp());
    return;
  }

  const jsonMode = values.json === true;
  const backend = values.backend as 'grafana-cloud' | 'uis' | undefined;
  if (backend && backend !== 'grafana-cloud' && backend !== 'uis') {
    report(
      [
        {
          name: 'config',
          pass: false,
          detail: `--backend must be "grafana-cloud" or "uis", got "${backend}"`,
        },
      ],
      jsonMode
    );
    process.exit(1);
  }

  const realServiceName = values['service-name'] ?? process.env.OTEL_SERVICE_NAME;
  if (!realServiceName) {
    report(
      [
        {
          name: 'config',
          pass: false,
          detail: 'No service name -- set OTEL_SERVICE_NAME or pass --service-name',
        },
      ],
      jsonMode
    );
    process.exit(1);
  }

  let config: ReturnType<typeof resolveSelftestConfig>;
  try {
    config = resolveSelftestConfig(backend);
  } catch (err) {
    report([{ name: 'config', pass: false, detail: (err as Error).message }], jsonMode);
    process.exit(1);
  }

  // Deferred to here, not a top-level import -- see the comment by the
  // other imports. Args and config are already validated above, so this
  // ~434ms cost is only paid once we know the run will actually proceed.
  const { writeSelftestMarker, selftestServiceName } = await import('./write-step.js');

  const results: SignalResult[] = [];
  const disposableName = selftestServiceName(realServiceName);

  // Explicit start/end markers -- sovdev_initialize()/sovdev_log()/
  // sovdev_shutdown() print their own verbose diagnostic output (session ID,
  // OTLP setup, flush/shutdown progress) as part of the write step, not
  // hidden or reordered -- these markers bracket everything that happens
  // during the actual test as one clearly delimited unit. Every line here
  // (both the CLI's own and write-step.ts's own, interleaved with the
  // library's real init/queue/flush sequence) is timestamped via
  // logProgress(), so the real order is verifiable, not just asserted.
  //
  // The attribution rule below is stated once, here, rather than repeated
  // before every individual library call -- the maintainer's own read of
  // the output ("i have a feeling that the lines here does not come from
  // your code?") was correct, but had no way to confirm it from the output
  // itself; a timestamp-vs-no-timestamp rule only documented in a separate
  // markdown file isn't something someone running the tool can see.
  logProgress(
    "=== Test starting === (timestamped lines below are this tool's own reporting; " +
      "un-timestamped lines are sovdev-logger's own internal diagnostic output, printed as-is, not a claim made by this tool)"
  );

  try {
    await withSuppressedConsole(jsonMode, () => writeSelftestMarker(realServiceName));
    results.push({
      name: 'write-log',
      pass: true,
      detail: `sent message="${SELFTEST_MARKER_MESSAGE}" under service_name=${disposableName}`,
    });
    results.push({
      name: 'write-metric',
      pass: true,
      detail: `sent sovdev_operations_total{service_name="${disposableName}"} 1`,
    });
  } catch (err) {
    const detail = (err as Error).message;
    results.push({ name: 'write-log', pass: false, detail });
    results.push({ name: 'write-metric', pass: false, detail });
    logProgress('=== Test finished ===');
    report(results, jsonMode);
    process.exit(1);
  }

  logProgress(`Reading back the log (polling up to ${LOG_TIMEOUT_MS / 1000}s) ...`);
  const logResult = await pollForSignal(
    'read-log',
    () => {
      const nowNs = BigInt(Date.now()) * 1_000_000n;
      const startNs = nowNs - 300n * 1_000_000_000n; // 5 minute lookback buffer
      return queryLoki(config, {
        query: `{service_name="${disposableName}"}`,
        limit: '1',
        start: startNs.toString(),
        end: nowNs.toString(),
      });
    },
    extractLokiDetail,
    LOG_TIMEOUT_MS,
    POLL_INTERVAL_MS
  );
  logProgress(logResult.pass ? `Found: ${logResult.detail}` : `Not found: ${logResult.detail}`);
  results.push(logResult);

  logProgress(`Reading back the metric (polling up to ${METRIC_TIMEOUT_MS / 1000}s) ...`);
  const metricResult = await pollForSignal(
    'read-metric',
    () =>
      queryPrometheus(config, {
        query: `sovdev_operations_total{service_name="${disposableName}"}`,
      }),
    extractPrometheusDetail,
    METRIC_TIMEOUT_MS,
    POLL_INTERVAL_MS
  );
  logProgress(
    metricResult.pass ? `Found: ${metricResult.detail}` : `Not found: ${metricResult.detail}`
  );
  results.push(metricResult);

  logProgress('=== Test finished ===');

  report(results, jsonMode);
  process.exit(results.every((r) => r.pass) ? 0 : 1);
}

main();
