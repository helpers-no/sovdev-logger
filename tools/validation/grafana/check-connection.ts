#!/usr/bin/env npx tsx
// check-connection.ts - Preflight check for Grafana Cloud verification tooling
//
// Validates that the required environment variables are set and look sane,
// then actually tests the connection to each backend (not just "is the
// variable non-empty" — a real query, since that's the only way to know
// auth + the query path actually work). Run this before trusting any other
// script in this directory.
//
// Usage:
//   set -a && source .env && set +a && npx tsx check-connection.ts
//
// Never prints token values — only pass/fail per check.

import { grafanaCloudQuery } from './lib/grafana-cloud-client.js';
import { validateUrlEnv, validateInstanceIdEnv, validateTokenEnv } from './lib/env-checks.js';

interface CheckResult {
  name: string;
  ok: boolean;
  detail: string;
}

const results: CheckResult[] = [];

function checkUrl(varName: string): string | null {
  const value = process.env[varName];
  const outcome = validateUrlEnv(value);
  results.push({ name: varName, ...outcome });
  return outcome.ok ? value! : null;
}

function checkInstanceId(varName: string): string | null {
  const value = process.env[varName];
  const outcome = validateInstanceIdEnv(value);
  results.push({ name: varName, ...outcome });
  return outcome.ok ? value! : null;
}

function checkToken(varName: string): string | null {
  const value = process.env[varName];
  const outcome = validateTokenEnv(value);
  results.push({ name: varName, ...outcome });
  return outcome.ok ? value! : null;
}

async function checkConnection(
  label: string,
  baseUrl: string | null,
  path: string,
  params: Record<string, string>,
  instanceId: string | null,
  token: string | null,
  evaluate: (result: unknown) => { ok: boolean; detail: string },
): Promise<void> {
  if (!baseUrl || !instanceId || !token) {
    results.push({ name: label, ok: false, detail: 'skipped — missing config above' });
    return;
  }
  try {
    const result = await grafanaCloudQuery(baseUrl, path, params, { instanceId, token });
    results.push({ name: label, ...evaluate(result) });
  } catch (err) {
    results.push({ name: label, ok: false, detail: (err as Error).message.slice(0, 300) });
  }
}

async function main(): Promise<void> {
  console.log('Checking environment variables...\n');

  const lokiUrl = checkUrl('GRAFANA_CLOUD_LOKI_URL');
  const lokiInstanceId = checkInstanceId('GRAFANA_CLOUD_LOKI_INSTANCE_ID');
  const verifyToken = checkToken('GRAFANA_CLOUD_VERIFY_TOKEN');

  const tempoUrl = checkUrl('GRAFANA_CLOUD_TEMPO_URL');
  const tempoInstanceId = checkInstanceId('GRAFANA_CLOUD_TEMPO_INSTANCE_ID');
  const promUrl = checkUrl('GRAFANA_CLOUD_PROMETHEUS_URL');
  const promInstanceId = checkInstanceId('GRAFANA_CLOUD_PROMETHEUS_INSTANCE_ID');
  checkUrl('GRAFANA_CLOUD_OTLP_ENDPOINT');
  checkInstanceId('GRAFANA_CLOUD_OTLP_INSTANCE_ID');
  checkToken('GRAFANA_CLOUD_INGEST_TOKEN');

  console.log('Testing live connections to all three signals...\n');
  await checkConnection(
    'Loki connection',
    lokiUrl,
    '/loki/api/v1/query_range',
    { query: '{service_name=~".+"}', limit: '1' },
    lokiInstanceId,
    verifyToken,
    (r) => {
      const data = r as { status?: string; data?: { result?: unknown[] } };
      const streamCount = data.data?.result?.length ?? 0;
      return data.status === 'success'
        ? { ok: true, detail: `status=success, ${streamCount} stream(s) matched` }
        : { ok: false, detail: `unexpected response shape: ${JSON.stringify(r).slice(0, 200)}` };
    },
  );
  await checkConnection(
    'Tempo connection',
    tempoUrl,
    '/tempo/api/search',
    { limit: '1' },
    tempoInstanceId,
    verifyToken,
    (r) => {
      const data = r as { traces?: unknown[] };
      return Array.isArray(data.traces)
        ? { ok: true, detail: `search succeeded, ${data.traces.length} trace(s) matched` }
        : { ok: false, detail: `unexpected response shape: ${JSON.stringify(r).slice(0, 200)}` };
    },
  );
  await checkConnection(
    'Prometheus connection',
    promUrl,
    '/api/prom/api/v1/query',
    { query: 'up' },
    promInstanceId,
    verifyToken,
    (r) => {
      const data = r as { status?: string; data?: { resultType?: string; result?: unknown[] } };
      const seriesCount = data.data?.result?.length ?? 0;
      return data.status === 'success'
        ? { ok: true, detail: `status=success, resultType=${data.data?.resultType}, ${seriesCount} series matched` }
        : { ok: false, detail: `unexpected response shape: ${JSON.stringify(r).slice(0, 200)}` };
    },
  );

  let allOk = true;
  results.forEach((r, i) => {
    const icon = r.ok ? '✅' : '❌';
    console.log(`[${i + 1}] ${icon} ${r.name}: ${r.detail}`);
    if (!r.ok) allOk = false;
  });

  console.log();
  if (allOk) {
    console.log('✅ All checks passed — connection to Grafana Cloud confirmed working.');
  } else {
    console.log('❌ One or more checks failed — see above. Fix these before trusting any query-*.ts output.');
  }
  process.exit(allOk ? 0 : 1);
}

main();
