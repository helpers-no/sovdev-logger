#!/usr/bin/env npx tsx
// query-prometheus.ts - Query Grafana Cloud's hosted Mimir (Prometheus-compatible) for metrics
//
// The Grafana Cloud counterpart to specification/tools/query-prometheus.sh.
// Confirmed empirically (see tools/validation/grafana/probe-tempo-prometheus.ts,
// now answered): the real query path needs Grafana Cloud's Cortex-style
// "/api/prom" prefix in front of the standard Prometheus API —
// GRAFANA_CLOUD_PROMETHEUS_URL + "/api/prom/api/v1/query" returned 200,
// plain "/api/v1/query" returned 404.
//
// Same staleness gotcha as the bash version: metrics from a one-shot test
// process are pushed once at flush time and only exposed by the OTel
// Collector for a short window afterward — query promptly after the run,
// don't rely on --time-range to look back at an old run.
//
// Usage:
//   npx tsx query-prometheus.ts <service-name> [options]
//
// Options:
//   --json               Output raw JSON data
//   --compare-with FILE  Compare with a log file for consistency (pipes to
//                        specification/tests/validate-prometheus-consistency.py)
//   --metric NAME        Metric name to query (default: sovdev_operations_total)
//   --time-range R       Snapshot time R ago (e.g. 5m) instead of now — omit
//                        for an instant "now" query (recommended, see above)
//   --help               Show this help message

import { grafanaCloudQuery, credentialsFromEnv } from './lib/grafana-cloud-client.js';
import { runConsistencyCheck } from './lib/consistency-check.js';

interface Options {
  serviceName: string;
  json: boolean;
  compareWith: string | null;
  metricName: string;
  timeRange: string | null;
}

function parseArgs(argv: string[]): Options {
  let serviceName = '';
  let json = false;
  let compareWith: string | null = null;
  let metricName = 'sovdev_operations_total';
  let timeRange: string | null = null;

  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    switch (arg) {
      case '--json':
        json = true;
        break;
      case '--compare-with':
        compareWith = argv[++i];
        json = true;
        break;
      case '--metric':
        metricName = argv[++i];
        break;
      case '--time-range':
        timeRange = argv[++i];
        break;
      case '--help':
        printHelp();
        process.exit(0);
        break;
      default:
        if (!serviceName) {
          serviceName = arg;
        } else {
          console.error(`Unknown argument: ${arg}`);
          process.exit(1);
        }
    }
  }

  if (!serviceName) {
    console.error('Error: service name is required');
    printHelp();
    process.exit(1);
  }

  return { serviceName, json, compareWith, metricName, timeRange };
}

function printHelp(): void {
  console.log(`Usage: npx tsx query-prometheus.ts <service-name> [options]

Options:
  --json               Output raw JSON data
  --compare-with FILE  Compare with a log file for consistency
  --metric NAME        Metric name to query (default: sovdev_operations_total)
  --time-range R       Snapshot time R ago instead of now (e.g. 5m) — omit for "now"
  --help               Show this help message`);
}

function parseTimeRangeToUnixSeconds(range: string): number {
  const match = range.match(/^(\d+)([hms])$/);
  if (!match) {
    throw new Error(`Invalid time range format: ${range}. Use format like: 1h, 30m, 5m`);
  }
  const [, amountStr, unit] = match;
  const amount = Number(amountStr);
  const multiplier = { h: 3600, m: 60, s: 1 }[unit as 'h' | 'm' | 's'];
  return Math.floor(Date.now() / 1000) - amount * multiplier;
}

async function main(): Promise<void> {
  const opts = parseArgs(process.argv.slice(2));
  const baseUrl = process.env.GRAFANA_CLOUD_PROMETHEUS_URL;
  if (!baseUrl) {
    console.error('Error: GRAFANA_CLOUD_PROMETHEUS_URL is not set (see .env.example)');
    process.exit(1);
  }
  const creds = credentialsFromEnv('GRAFANA_CLOUD_PROMETHEUS_INSTANCE_ID', 'GRAFANA_CLOUD_VERIFY_TOKEN');

  const promqlQuery = `${opts.metricName}{service_name="${opts.serviceName}"}`;
  const params: Record<string, string> = { query: promqlQuery };
  if (opts.timeRange) {
    params.time = String(parseTimeRangeToUnixSeconds(opts.timeRange));
  }

  let result: unknown;
  try {
    result = await grafanaCloudQuery(baseUrl, '/api/prom/api/v1/query', params, creds);
  } catch (err) {
    console.error(`❌ Failed to query Prometheus: ${(err as Error).message}`);
    process.exit(1);
  }

  if (opts.compareWith) {
    const { exitCode, stdout, stderr } = runConsistencyCheck(
      'validate-prometheus-consistency.py',
      opts.compareWith,
      JSON.stringify(result),
    );
    process.stdout.write(stdout);
    process.stderr.write(stderr);
    process.exit(exitCode);
  }

  if (opts.json) {
    console.log(JSON.stringify(result));
    return;
  }

  const data = result as { data?: { result?: unknown[] } };
  const series = data.data?.result ?? [];
  if (series.length === 0) {
    console.log(`⚠️  No metrics found for service: ${opts.serviceName}`);
    process.exit(1);
  }
  console.log(`✅ Service '${opts.serviceName}' found in Grafana Cloud Prometheus`);
  console.log(`✅ Found ${series.length} metric series`);
}

main();
