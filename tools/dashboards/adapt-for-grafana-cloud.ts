#!/usr/bin/env npx tsx
// adapt-for-grafana-cloud.ts - Rewrite a dashboard JSON's datasource UIDs from
// local UIS's names ("prometheus"/"loki"/"tempo") to Grafana Cloud's real,
// auto-provisioned datasource UIDs, for manual import via Grafana Cloud's own
// UI (Dashboards -> New -> Import -> Upload dashboard JSON file).
//
// WHY THIS EXISTS: Grafana's Import UI only shows an interactive "map each
// datasource" step when the JSON has an __inputs/__requires structure, which
// only gets added when a dashboard is *exported* from Grafana itself via
// "Export for sharing externally". A hand-authored JSON (like this one, built
// by a script rather than exported from a UI) doesn't have that structure --
// confirmed empirically: importing it as-is silently keeps the hardcoded
// local-UIS UIDs, and every panel then fails with "Datasource X was not
// found" (visible only by hovering the small warning triangle Grafana puts
// on each panel -- it's a real query error, not just an empty result).
//
// The real Grafana Cloud UIDs are NOT the same as the datasource display
// names shown in Connections -> Data sources (e.g. display name
// "grafanacloud-urbalurba-prom" vs actual UID "grafanacloud-prom" -- found by
// opening each datasource's settings page and reading its URL,
// .../datasources/edit/<uid>). Confirmed on one real Grafana Cloud stack:
//
//   prometheus -> grafanacloud-prom
//   loki       -> grafanacloud-logs
//   tempo      -> grafanacloud-traces
//
// These look like Grafana Cloud's fixed, standard UIDs for every stack's
// auto-provisioned default datasources (not derived from the org/stack name)
// -- plausible given the pattern, but only confirmed against one stack so
// far. If a different stack's UIDs turn out to differ, update the map below
// and re-run.
//
// Usage:
//   npx tsx adapt-for-grafana-cloud.ts [input.json] [output.json]
//
// Defaults: ./sovdev-logger-overview.json -> ./sovdev-logger-overview-grafana-cloud.json

import { readFileSync, writeFileSync } from 'node:fs';
import path from 'node:path';

const GRAFANA_CLOUD_DATASOURCE_UIDS: Record<string, string> = {
  prometheus: 'grafanacloud-prom',
  loki: 'grafanacloud-logs',
  tempo: 'grafanacloud-traces',
};

function fixDatasourceUids(node: unknown): number {
  let count = 0;
  if (Array.isArray(node)) {
    for (const item of node) count += fixDatasourceUids(item);
  } else if (node && typeof node === 'object') {
    const obj = node as Record<string, unknown>;
    const type = obj.type;
    if (typeof type === 'string' && typeof obj.uid === 'string' && type in GRAFANA_CLOUD_DATASOURCE_UIDS) {
      const newUid = GRAFANA_CLOUD_DATASOURCE_UIDS[type];
      if (obj.uid !== newUid) {
        obj.uid = newUid;
        count += 1;
      }
    }
    for (const value of Object.values(obj)) count += fixDatasourceUids(value);
  }
  return count;
}

function main(): void {
  const inputPath = process.argv[2] ?? path.join(import.meta.dirname, 'sovdev-logger-overview.json');
  const outputPath = process.argv[3] ?? path.join(import.meta.dirname, 'sovdev-logger-overview-grafana-cloud.json');

  const dashboard = JSON.parse(readFileSync(inputPath, 'utf-8'));

  const count = fixDatasourceUids(dashboard);

  // Distinguish it from the local-UIS dashboard in the Grafana Cloud UI, and
  // give it its own UID so importing never collides with (or overwrites) the
  // local-UIS one if the same JSON is ever pushed to both.
  if (!dashboard.title.endsWith(' (Grafana Cloud)')) {
    dashboard.title += ' (Grafana Cloud)';
  }
  dashboard.uid = `${dashboard.uid}-cloud`;
  // Reset identity fields so this imports as a fresh dashboard rather than
  // trying to update local UIS's internal numeric id/version.
  dashboard.id = null;
  delete dashboard.version;

  writeFileSync(outputPath, JSON.stringify(dashboard, null, 2) + '\n');
  console.log(`✅ Replaced ${count} datasource UID reference(s)`);
  console.log(`   Wrote ${outputPath}`);
  console.log(`   Title: ${dashboard.title}, UID: ${dashboard.uid}`);
}

main();
