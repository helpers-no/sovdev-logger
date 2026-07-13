// Per-signal query functions built on queryWithBasicAuth(), one for each
// backend shape. Grafana Cloud hits its own hosted Loki/Prometheus URLs
// directly (instanceId:token as Basic Auth); UIS hits the same native paths
// through Grafana's datasource-proxy API (username:password as Basic Auth) --
// see INVESTIGATE-selftest-cli.md's "UIS is reachable over plain HTTP".

import { queryWithBasicAuth } from './query-client.js';
import type { SelftestConfig } from './backend-config.js';

function uisProxyUrl(grafanaUrl: string, datasourceUid: 'loki' | 'prometheus'): string {
  return `${grafanaUrl}/api/datasources/proxy/uid/${datasourceUid}`;
}

export async function queryLoki(
  config: SelftestConfig,
  params: Record<string, string>
): Promise<unknown> {
  if (config.backend === 'grafana-cloud') {
    return queryWithBasicAuth(config.lokiUrl, '/loki/api/v1/query_range', params, {
      user: config.lokiInstanceId,
      pass: config.verifyToken,
    });
  }
  return queryWithBasicAuth(
    uisProxyUrl(config.grafanaUrl, 'loki'),
    '/loki/api/v1/query_range',
    params,
    {
      user: config.username,
      pass: config.password,
    },
    config.hostHeader
  );
}

export async function queryPrometheus(
  config: SelftestConfig,
  params: Record<string, string>
): Promise<unknown> {
  if (config.backend === 'grafana-cloud') {
    return queryWithBasicAuth(config.prometheusUrl, '/api/prom/api/v1/query', params, {
      user: config.prometheusInstanceId,
      pass: config.verifyToken,
    });
  }
  return queryWithBasicAuth(
    uisProxyUrl(config.grafanaUrl, 'prometheus'),
    '/api/v1/query',
    params,
    {
      user: config.username,
      pass: config.password,
    },
    config.hostHeader
  );
}
