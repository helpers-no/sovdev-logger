#!/usr/bin/env npx tsx
// probe-otlp-ingest.ts - one-off diagnostic to test all three OTLP ingestion
// paths directly with the ingest token, bypassing curl (which had an
// unexplained "command not found" in one debugging session) and bypassing
// the sovdev-logger library entirely, to isolate whether a 401 is a
// credential/account problem or something specific to the library's export
// path.
//
// Usage:
//   set -a && source .env && set +a && npx tsx probe-otlp-ingest.ts
//
// Never prints the token — only HTTP status codes.

const endpoint = process.env.GRAFANA_CLOUD_OTLP_ENDPOINT;
const instanceId = process.env.GRAFANA_CLOUD_OTLP_INSTANCE_ID;
const token = process.env.GRAFANA_CLOUD_INGEST_TOKEN;

if (!endpoint || !instanceId || !token) {
  console.error('Missing GRAFANA_CLOUD_OTLP_ENDPOINT / GRAFANA_CLOUD_OTLP_INSTANCE_ID / GRAFANA_CLOUD_INGEST_TOKEN — source .env first');
  process.exit(1);
}

const auth = Buffer.from(`${instanceId}:${token}`).toString('base64');

async function probe(path: string): Promise<void> {
  const response = await fetch(`${endpoint}/${path}`, {
    method: 'POST',
    headers: {
      Authorization: `Basic ${auth}`,
      'Content-Type': 'application/json',
    },
    body: '{}',
  });
  const text = await response.text();
  console.log(`${response.ok ? '✅' : '❌'} ${path}: HTTP ${response.status} ${text.slice(0, 200)}`);
}

async function main(): Promise<void> {
  for (const path of ['v1/logs', 'v1/traces', 'v1/metrics']) {
    await probe(path);
  }
}

main();
