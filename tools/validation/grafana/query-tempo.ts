#!/usr/bin/env npx tsx
// query-tempo.ts - Query Grafana Cloud's hosted Tempo for traces
//
// The Grafana Cloud counterpart to specification/tools/query-tempo.sh.
// Confirmed empirically (see tools/validation/grafana/probe-tempo-prometheus.ts,
// now answered): the real query path needs a "/tempo" prefix in front of the
// Tempo API — GRAFANA_CLOUD_TEMPO_URL + "/tempo/api/search" returned 200,
// plain "/api/search" returned 404. This is the opposite of what self-hosted
// Tempo needs, and opposite of what was initially guessed — don't assume it
// generalizes to future backends.
//
// Usage:
//   npx tsx query-tempo.ts <service-name> [options]
//
// Options:
//   --json               Output raw JSON data
//   --compare-with FILE  Compare with a log file for consistency (pipes to
//                        specification/tests/validate-tempo-consistency.py)
//   --limit N            Limit results to N traces (default: 10)
//   --time-range R       Time range: 1h, 30m, 5m, etc. (default: 1h)
//   --help               Show this help message

import { grafanaCloudQuery, credentialsFromEnv } from './lib/grafana-cloud-client.js';
import { runConsistencyCheck } from './lib/consistency-check.js';

interface Options {
  serviceName: string;
  json: boolean;
  compareWith: string | null;
  limit: number;
  timeRange: string;
}

interface TempoSearchResponse {
  traces?: Array<{ traceID: string; [key: string]: unknown }>;
  metrics?: unknown;
}

interface TempoSpan {
  spanId: string;
  traceId: string;
  name: string;
  startTimeUnixNano: string;
  endTimeUnixNano: string;
  attributes?: unknown;
  status?: { code?: string };
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
        json = true;
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
  console.log(`Usage: npx tsx query-tempo.ts <service-name> [options]

Options:
  --json               Output raw JSON data
  --compare-with FILE  Compare with a log file for consistency
  --limit N            Limit results to N traces (default: 10)
  --time-range R       Time range: 1h, 30m, 5m, etc. (default: 1h)
  --help               Show this help message`);
}

function parseTimeRangeToSeconds(range: string): { startSec: number; endSec: number } {
  const match = range.match(/^(\d+)([hms])$/);
  if (!match) {
    throw new Error(`Invalid time range format: ${range}. Use format like: 1h, 30m, 5m`);
  }
  const [, amountStr, unit] = match;
  const amount = Number(amountStr);
  const multiplier = { h: 3600, m: 60, s: 1 }[unit as 'h' | 'm' | 's'];
  const durationSeconds = amount * multiplier;
  const nowSec = Math.floor(Date.now() / 1000);
  return { startSec: nowSec - durationSeconds, endSec: nowSec };
}

function base64ToHex(base64: string): string {
  return Buffer.from(base64, 'base64').toString('hex');
}

/** Transform a raw Tempo /tempo/api/traces/{id} response into the
 * spanSets[].spans[] shape validate-tempo-consistency.py expects, with
 * base64 span/trace IDs converted to hex (matching how log files record them). */
function transformTraceDetail(traceDetail: unknown, originalTrace: Record<string, unknown>): Record<string, unknown> {
  const detail = traceDetail as { batches?: Array<{ scopeSpans?: Array<{ spans?: TempoSpan[] }> }> };
  if (!detail.batches) {
    return originalTrace;
  }

  const spans = detail.batches.flatMap((batch) =>
    (batch.scopeSpans ?? []).flatMap((scopeSpan) =>
      (scopeSpan.spans ?? []).map((span) => ({
        spanID: base64ToHex(span.spanId),
        traceID: base64ToHex(span.traceId),
        operationName: span.name,
        startTimeUnixNano: span.startTimeUnixNano,
        durationNanos: String(BigInt(span.endTimeUnixNano) - BigInt(span.startTimeUnixNano)),
        attributes: span.attributes,
        status: span.status?.code === 'STATUS_CODE_ERROR' ? { code: 2 } : { code: 0 },
      })),
    ),
  );

  return { ...originalTrace, spanSets: [{ spans }] };
}

async function main(): Promise<void> {
  const opts = parseArgs(process.argv.slice(2));
  const baseUrl = process.env.GRAFANA_CLOUD_TEMPO_URL;
  if (!baseUrl) {
    console.error('Error: GRAFANA_CLOUD_TEMPO_URL is not set (see .env.example)');
    process.exit(1);
  }
  const creds = credentialsFromEnv('GRAFANA_CLOUD_TEMPO_INSTANCE_ID', 'GRAFANA_CLOUD_VERIFY_TOKEN');

  const { startSec, endSec } = parseTimeRangeToSeconds(opts.timeRange);

  let searchResult: TempoSearchResponse;
  try {
    searchResult = (await grafanaCloudQuery(
      baseUrl,
      '/tempo/api/search',
      {
        tags: `service.name=${opts.serviceName}`,
        limit: String(opts.limit),
        start: String(startSec),
        end: String(endSec),
      },
      creds,
    )) as TempoSearchResponse;
  } catch (err) {
    console.error(`❌ Failed to query Tempo: ${(err as Error).message}`);
    process.exit(1);
  }

  const traces = searchResult.traces ?? [];

  // Fetch full span detail per trace when we need exact-match data
  // (--compare-with) or raw --json output. Search alone only returns
  // trace-level metadata, not spans.
  const detailedTraces: Record<string, unknown>[] = [];
  for (const trace of traces) {
    try {
      const detail = await grafanaCloudQuery(baseUrl, `/tempo/api/traces/${trace.traceID}`, {}, creds);
      detailedTraces.push(transformTraceDetail(detail, trace));
    } catch {
      detailedTraces.push(trace);
    }
  }

  const result = { traces: detailedTraces, metrics: searchResult.metrics ?? {} };

  if (opts.compareWith) {
    const { exitCode, stdout, stderr } = runConsistencyCheck(
      'validate-tempo-consistency.py',
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

  if (traces.length === 0) {
    console.log(`⚠️  No traces found for service: ${opts.serviceName} (time range: ${opts.timeRange})`);
    process.exit(1);
  }
  console.log(`✅ Service '${opts.serviceName}' found in Grafana Cloud Tempo`);
  console.log(`✅ Found ${traces.length} traces`);
}

main();
