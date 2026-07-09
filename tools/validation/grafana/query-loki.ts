#!/usr/bin/env npx tsx
// query-loki.ts - Query Grafana Cloud's hosted Loki for logs from a specific service
//
// The Grafana Cloud counterpart to specification/tools/query-loki.sh (which
// queries a local UIS-hosted Loki instead). Same LogQL query, same
// --json/--validate/--compare-with/--time-range/--limit flags — only the
// transport differs (HTTP Basic Auth over the public internet instead of
// kubectl run against an in-cluster service).
//
// Usage:
//   npx tsx query-loki.ts <service-name> [options]
//
// Options:
//   --json               Output raw JSON data for parsing/verification
//   --compare-with FILE  Compare Grafana Cloud's response with a log file for
//                        consistency (pipes to specification/tests/validate-loki-consistency.py,
//                        unchanged — see lib/consistency-check.ts)
//   --limit N            Limit results to N entries (default: 10)
//   --time-range R       Time range: 1h, 30m, 24h, etc. (default: 1h)
//   --help               Show this help message
//
// Required environment variables (see .env.example):
//   GRAFANA_CLOUD_LOKI_URL          e.g. https://logs-prod-eu-west-0.grafana.net
//   GRAFANA_CLOUD_LOKI_INSTANCE_ID  numeric Instance ID for the Loki stack
//   GRAFANA_CLOUD_VERIFY_TOKEN      Cloud Access Policy token with logs:read scope
//
// Confirmed empirically: Grafana Cloud's Loki query API is identical to
// self-hosted Loki's (/loki/api/v1/query_range, same LogQL, same response
// shape) — no transformation needed before piping to the Python validator.

import { grafanaCloudQuery, credentialsFromEnv } from './lib/grafana-cloud-client.js';
import { runConsistencyCheck } from './lib/consistency-check.js';

interface Options {
  serviceName: string;
  json: boolean;
  compareWith: string | null;
  limit: number;
  timeRange: string;
}

function parseArgs(argv: string[]): Options {
  let serviceName = '';
  let json = false;
  let compareWith: string | null = null;
  let limit = 10;
  let timeRange = '1h';

  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    switch (arg) {
      case '--json':
        json = true;
        break;
      case '--compare-with':
        compareWith = argv[++i];
        json = true; // comparison requires JSON mode
        break;
      case '--limit':
        limit = Number(argv[++i]);
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

  return { serviceName, json, compareWith, limit, timeRange };
}

function printHelp(): void {
  console.log(`Usage: npx tsx query-loki.ts <service-name> [options]

Options:
  --json               Output raw JSON data
  --compare-with FILE  Compare with a log file for consistency
  --limit N            Limit results to N entries (default: 10)
  --time-range R       Time range: 1h, 30m, 24h, etc. (default: 1h)
  --help               Show this help message`);
}

function parseTimeRangeToNanos(range: string): { startNs: bigint; endNs: bigint } {
  const match = range.match(/^(\d+)([hms])$/);
  if (!match) {
    throw new Error(`Invalid time range format: ${range}. Use format like: 1h, 30m, 5m`);
  }
  const [, amountStr, unit] = match;
  const amount = BigInt(amountStr);
  const multiplier = { h: 3600n, m: 60n, s: 1n }[unit as 'h' | 'm' | 's'];
  const durationSeconds = amount * multiplier;
  const nowNs = BigInt(Date.now()) * 1_000_000n;
  const startNs = nowNs - durationSeconds * 1_000_000_000n;
  return { startNs, endNs: nowNs };
}

async function main(): Promise<void> {
  const opts = parseArgs(process.argv.slice(2));
  const baseUrl = process.env.GRAFANA_CLOUD_LOKI_URL;
  if (!baseUrl) {
    console.error('Error: GRAFANA_CLOUD_LOKI_URL is not set (see .env.example)');
    process.exit(1);
  }
  const creds = credentialsFromEnv('GRAFANA_CLOUD_LOKI_INSTANCE_ID', 'GRAFANA_CLOUD_VERIFY_TOKEN');

  // Auto-bump the limit for --compare-with, matching query-loki.sh's
  // behavior — otherwise the default limit (10) silently truncates results
  // below the file's actual entry count, reporting false "missing" entries.
  if (opts.compareWith) {
    const { readFileSync } = await import('node:fs');
    const fileEntryCount = readFileSync(opts.compareWith, 'utf-8').split('\n').filter(Boolean).length;
    const autoLimit = fileEntryCount + 10;
    if (autoLimit > opts.limit) {
      opts.limit = autoLimit;
    }
  }

  const { startNs, endNs } = parseTimeRangeToNanos(opts.timeRange);
  const logqlQuery = `{service_name="${opts.serviceName}"}`;

  let result: unknown;
  try {
    result = await grafanaCloudQuery(
      baseUrl,
      '/loki/api/v1/query_range',
      {
        query: logqlQuery,
        start: startNs.toString(),
        end: endNs.toString(),
        limit: String(opts.limit),
      },
      creds,
    );
  } catch (err) {
    console.error(`❌ Failed to query Loki: ${(err as Error).message}`);
    process.exit(1);
  }

  if (opts.compareWith) {
    const { exitCode, stdout, stderr } = runConsistencyCheck(
      'validate-loki-consistency.py',
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

  const data = result as { data?: { result?: Array<{ values: unknown[][] }> } };
  const streams = data.data?.result ?? [];
  if (streams.length === 0) {
    console.log(`⚠️  No logs found for service: ${opts.serviceName} (time range: ${opts.timeRange})`);
    process.exit(1);
  }
  const totalEntries = streams.reduce((sum, s) => sum + s.values.length, 0);
  console.log(`✅ Service '${opts.serviceName}' found in Grafana Cloud Loki`);
  console.log(`✅ Found ${totalEntries} log entries`);
}

main();
