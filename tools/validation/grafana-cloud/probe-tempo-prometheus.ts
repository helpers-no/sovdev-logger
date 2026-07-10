#!/usr/bin/env npx tsx
// probe-tempo-prometheus.ts - one-off diagnostic to determine the real query
// paths for Grafana Cloud's Tempo and Prometheus APIs.
//
// The portal's own connection pages show paths (Tempo's "/tempo" suffix,
// Prometheus's "/api/prom" prefix) that might be Grafana-internal
// datasource-proxy routes rather than the public query API — this tries
// both candidate variants for each and reports which one actually returns
// a valid response. Never prints the credentials used to make the request.
//
// Usage:
//   set -a && source .env && set +a && npx tsx probe-tempo-prometheus.ts
//
// Once this confirms the real paths, delete this file and put the answer
// directly into query-tempo.ts/query-prometheus.ts — this script's only job
// is answering that one question.

import { probeGrafanaCloudPath, credentialsFromEnv, type GrafanaCloudCredentials } from './lib/grafana-cloud-client.js';

async function probe(
  name: string,
  baseUrl: string,
  path: string,
  params: Record<string, string>,
  creds: GrafanaCloudCredentials,
): Promise<void> {
  try {
    const result = await probeGrafanaCloudPath(baseUrl, path, params, creds);
    console.log(`${result.ok ? '✅' : '❌'} ${name}: HTTP ${result.status}`);
    console.log(`   ${result.bodySnippet.replace(/\n/g, ' ')}`);
  } catch (err) {
    console.log(`❌ ${name}: request failed — ${(err as Error).message}`);
  }
  console.log();
}

async function main(): Promise<void> {
  const tempoUrl = process.env.GRAFANA_CLOUD_TEMPO_URL;
  const promUrl = process.env.GRAFANA_CLOUD_PROMETHEUS_URL;
  if (!tempoUrl || !promUrl) {
    console.error('GRAFANA_CLOUD_TEMPO_URL and GRAFANA_CLOUD_PROMETHEUS_URL must be set (source .env first)');
    process.exit(1);
  }

  const tempoCreds = credentialsFromEnv('GRAFANA_CLOUD_TEMPO_INSTANCE_ID', 'GRAFANA_CLOUD_VERIFY_TOKEN');
  const promCreds = credentialsFromEnv('GRAFANA_CLOUD_PROMETHEUS_INSTANCE_ID', 'GRAFANA_CLOUD_VERIFY_TOKEN');

  console.log('=== Tempo ===\n');
  await probe('Variant A: /api/search', tempoUrl, '/api/search', { limit: '1' }, tempoCreds);
  await probe('Variant B: /tempo/api/search', tempoUrl, '/tempo/api/search', { limit: '1' }, tempoCreds);

  console.log('=== Prometheus ===\n');
  await probe('Variant A: /api/prom/api/v1/query', promUrl, '/api/prom/api/v1/query', { query: 'up' }, promCreds);
  await probe('Variant B: /api/v1/query', promUrl, '/api/v1/query', { query: 'up' }, promCreds);
}

main();
