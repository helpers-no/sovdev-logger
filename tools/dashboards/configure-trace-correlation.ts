#!/usr/bin/env npx tsx
// configure-trace-correlation.ts - Wire up bidirectional log<->trace
// correlation on a Grafana instance's Loki and Tempo datasources.
//
// sovdev-logger's trace_id is a Loki *label*, not text embedded in the log
// line -- so the older per-datasource `derivedFields` (line-text regex only)
// can't reach it. This uses Grafana's Correlations API instead, which links
// a named field (trace_id) directly to a Tempo TraceQL query, regardless of
// whether that field came from the log line or a label.
//
// The reverse direction (viewing a trace, jumping to its correlated logs)
// uses Tempo's own native `tracesToLogsV2` datasource setting instead --
// that's a different, purpose-built mechanism, not the Correlations API.
//
// Usage:
//   GRAFANA_URL=http://grafana.localhost GRAFANA_USER=admin GRAFANA_PASSWORD=SecretPassword1 \
//     npx tsx configure-trace-correlation.ts
//
// Requires datasource UIDs "loki" and "tempo" (this repo's local UIS default
// naming) -- pass LOKI_UID/TEMPO_UID env vars to override for a different
// Grafana instance.

function buildAuthHeader(): string {
  const token = process.env.GRAFANA_TOKEN;
  if (token) {
    return `Bearer ${token}`;
  }

  const user = process.env.GRAFANA_USER;
  const password = process.env.GRAFANA_PASSWORD;
  if (user && password) {
    return `Basic ${Buffer.from(`${user}:${password}`).toString('base64')}`;
  }

  console.error(
    'Missing credentials: set GRAFANA_TOKEN (bearer) or GRAFANA_USER + GRAFANA_PASSWORD (basic auth)',
  );
  process.exit(1);
}

async function request(grafanaUrl: string, authHeader: string, method: string, apiPath: string, body: unknown) {
  const url = new URL(apiPath, grafanaUrl);
  const response = await fetch(url, {
    method,
    headers: { Authorization: authHeader, 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  const text = await response.text();
  if (!response.ok) {
    throw new Error(`${method} ${apiPath} failed: ${response.status} ${response.statusText}\n${text}`);
  }
  return JSON.parse(text);
}

async function main(): Promise<void> {
  const grafanaUrl = process.env.GRAFANA_URL;
  if (!grafanaUrl) {
    console.error('Missing GRAFANA_URL, e.g. http://grafana.localhost');
    process.exit(1);
  }
  const authHeader = buildAuthHeader();
  const lokiUid = process.env.LOKI_UID ?? 'loki';
  const tempoUid = process.env.TEMPO_UID ?? 'tempo';

  // Loki -> Tempo: a Correlation on the trace_id label, since it's a label
  // (not line text) and derivedFields can't reach it.
  //
  // The Correlations API has no upsert -- POSTing twice creates two
  // correlations, not an update. Delete any correlation this script already
  // created (same source/target/field) before creating a fresh one, so
  // re-running is safe.
  const existing = await request(grafanaUrl, authHeader, 'GET', '/api/datasources/correlations', undefined);
  for (const correlation of existing.correlations ?? []) {
    if (
      correlation.sourceUID === lokiUid &&
      correlation.targetUID === tempoUid &&
      correlation.config?.field === 'trace_id'
    ) {
      await request(
        grafanaUrl,
        authHeader,
        'DELETE',
        `/api/datasources/uid/${lokiUid}/correlations/${correlation.uid}`,
        undefined,
      );
    }
  }

  await request(grafanaUrl, authHeader, 'POST', `/api/datasources/uid/${lokiUid}/correlations`, {
    targetUID: tempoUid,
    label: 'View trace',
    description: 'Jump from a log line to its full trace',
    type: 'query',
    config: {
      field: 'trace_id',
      target: {
        datasource: { type: 'tempo', uid: tempoUid },
        queryType: 'traceql',
        query: '${__value.raw}',
        refId: 'A',
      },
    },
  });
  console.log('✅ Loki -> Tempo correlation configured (field: trace_id)');

  // Tempo -> Loki: native tracesToLogsV2 setting, merged into the existing
  // datasource config so nothing else on it gets clobbered.
  const tempoDatasource = await request(grafanaUrl, authHeader, 'GET', `/api/datasources/uid/${tempoUid}`, undefined);
  await request(grafanaUrl, authHeader, 'PUT', `/api/datasources/uid/${tempoUid}`, {
    ...tempoDatasource,
    jsonData: {
      ...tempoDatasource.jsonData,
      tracesToLogsV2: {
        datasourceUid: lokiUid,
        spanStartTimeShift: '-1h',
        spanEndTimeShift: '1h',
        tags: [{ key: 'service.name', value: 'service_name' }],
        filterByTraceID: false,
        filterBySpanID: false,
      },
    },
  });
  console.log('✅ Tempo -> Loki correlation configured (tracesToLogsV2, tag service.name -> service_name)');
}

main().catch((error) => {
  console.error('❌', error instanceof Error ? error.message : error);
  process.exit(1);
});
