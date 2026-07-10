#!/usr/bin/env npx tsx
// push-dashboard.ts - Push a dashboard JSON file to a Grafana instance via its
// HTTP API (POST /api/dashboards/db). Works against any Grafana instance --
// local UIS (HTTP Basic Auth) today, Grafana Cloud (bearer Service Account
// token) later -- since the endpoint and payload shape are identical; only
// the auth header differs.
//
// Usage:
//   GRAFANA_URL=http://grafana.localhost GRAFANA_USER=admin GRAFANA_PASSWORD=SecretPassword1 \
//     npx tsx push-dashboard.ts [path-to-dashboard.json]
//
//   GRAFANA_URL=https://<stack>.grafana.net GRAFANA_TOKEN=glsa_xxx \
//     npx tsx push-dashboard.ts [path-to-dashboard.json]
//
// Defaults to ./sovdev-logger-overview.json if no path is given.
//
// This dashboard has its own UID (sovdev-logger-full) -- pushing it never
// touches or overwrites the UIS-provisioned "Sovdev Logger - Overview"
// (uid: sovdev-metrics), which ships from a separate infra repo and is
// intentionally left alone (see INVESTIGATE-grafana-dashboard-definitions.md).

import { readFileSync } from 'node:fs';
import path from 'node:path';

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
    'Missing credentials: set GRAFANA_TOKEN (bearer, e.g. Grafana Cloud) or GRAFANA_USER + GRAFANA_PASSWORD (basic auth, e.g. local UIS)',
  );
  process.exit(1);
}

async function main(): Promise<void> {
  const grafanaUrl = process.env.GRAFANA_URL;
  if (!grafanaUrl) {
    console.error('Missing GRAFANA_URL, e.g. http://grafana.localhost');
    process.exit(1);
  }

  const dashboardPath = process.argv[2] ?? path.join(import.meta.dirname, 'sovdev-logger-overview.json');
  const dashboard = JSON.parse(readFileSync(dashboardPath, 'utf-8'));

  const authHeader = buildAuthHeader();
  const url = new URL('/api/dashboards/db', grafanaUrl);

  const response = await fetch(url, {
    method: 'POST',
    headers: {
      Authorization: authHeader,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ dashboard, folderUid: '', overwrite: true }),
  });

  const text = await response.text();
  if (!response.ok) {
    console.error(`❌ Push failed: ${response.status} ${response.statusText}\n${text}`);
    process.exit(1);
  }

  const result = JSON.parse(text);
  console.log(`✅ Pushed "${dashboard.title}" (uid: ${dashboard.uid}) to ${grafanaUrl}`);
  console.log(`   ${new URL(result.url, grafanaUrl)}`);
}

main().catch((error) => {
  console.error('❌', error instanceof Error ? error.message : error);
  process.exit(1);
});
