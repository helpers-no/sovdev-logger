// Backend config resolution for the self-test CLI. Two backend-specific
// shapes, not one generic one -- see INVESTIGATE-selftest-cli.md [Q2].
// Grafana Cloud reuses the same env vars tools/validation/grafana-cloud/
// already documents (.env.example) -- no new Access Policy needed for a
// first working version. UIS reuses tools/dashboards/push-dashboard.ts's
// existing GRAFANA_URL/GRAFANA_USER/GRAFANA_PASSWORD convention.

export interface GrafanaCloudSelftestConfig {
  backend: 'grafana-cloud';
  lokiUrl: string;
  lokiInstanceId: string;
  prometheusUrl: string;
  prometheusInstanceId: string;
  ingestToken: string;
  verifyToken: string;
  otlpEndpoint: string;
  otlpInstanceId: string;
}

export interface UisSelftestConfig {
  backend: 'uis';
  grafanaUrl: string;
  username: string;
  password: string;
  // Optional HTTP Host header override for the read side -- needed only
  // from inside the devcontainer, where grafana.localhost resolves to the
  // container's own loopback rather than the host machine. Set GRAFANA_URL
  // to http://host.docker.internal and this to grafana.localhost so
  // Traefik still routes by hostname (see uis.md's existing
  // OTEL_EXPORTER_OTLP_HEADERS=Host=otel.localhost pattern for the write
  // side's equivalent).
  hostHeader?: string;
}

export type SelftestConfig = GrafanaCloudSelftestConfig | UisSelftestConfig;

const GRAFANA_CLOUD_VARS = [
  'GRAFANA_CLOUD_INGEST_TOKEN',
  'GRAFANA_CLOUD_VERIFY_TOKEN',
  'GRAFANA_CLOUD_OTLP_ENDPOINT',
  'GRAFANA_CLOUD_OTLP_INSTANCE_ID',
  'GRAFANA_CLOUD_LOKI_URL',
  'GRAFANA_CLOUD_LOKI_INSTANCE_ID',
  'GRAFANA_CLOUD_PROMETHEUS_URL',
  'GRAFANA_CLOUD_PROMETHEUS_INSTANCE_ID',
] as const;

const UIS_VARS = ['GRAFANA_URL', 'GRAFANA_USER', 'GRAFANA_PASSWORD'] as const;

function presentVars(names: readonly string[]): string[] {
  return names.filter((name) => !!process.env[name]);
}

function missingVars(names: readonly string[]): string[] {
  return names.filter((name) => !process.env[name]);
}

function readGrafanaCloudConfig(): GrafanaCloudSelftestConfig {
  const missing = missingVars(GRAFANA_CLOUD_VARS);
  if (missing.length > 0) {
    throw new Error(`Missing Grafana Cloud env vars: ${missing.join(', ')}`);
  }
  return {
    backend: 'grafana-cloud',
    lokiUrl: process.env.GRAFANA_CLOUD_LOKI_URL!,
    lokiInstanceId: process.env.GRAFANA_CLOUD_LOKI_INSTANCE_ID!,
    prometheusUrl: process.env.GRAFANA_CLOUD_PROMETHEUS_URL!,
    prometheusInstanceId: process.env.GRAFANA_CLOUD_PROMETHEUS_INSTANCE_ID!,
    ingestToken: process.env.GRAFANA_CLOUD_INGEST_TOKEN!,
    verifyToken: process.env.GRAFANA_CLOUD_VERIFY_TOKEN!,
    otlpEndpoint: process.env.GRAFANA_CLOUD_OTLP_ENDPOINT!,
    otlpInstanceId: process.env.GRAFANA_CLOUD_OTLP_INSTANCE_ID!,
  };
}

function readUisConfig(): UisSelftestConfig {
  const missing = missingVars(UIS_VARS);
  if (missing.length > 0) {
    throw new Error(`Missing UIS env vars: ${missing.join(', ')}`);
  }
  return {
    backend: 'uis',
    grafanaUrl: process.env.GRAFANA_URL!,
    username: process.env.GRAFANA_USER!,
    password: process.env.GRAFANA_PASSWORD!,
    hostHeader: process.env.GRAFANA_HOST_HEADER || undefined,
  };
}

/**
 * Resolves which backend to use and its config. Explicit `requested` backend
 * always wins (and fails fast with a specific missing-var list if that
 * backend's own vars aren't fully present). With no explicit backend,
 * auto-detects only when exactly one backend's vars are present -- if both
 * or neither are, this throws rather than guessing (see [Q1]).
 */
export function resolveSelftestConfig(requested?: 'grafana-cloud' | 'uis'): SelftestConfig {
  if (requested === 'grafana-cloud') return readGrafanaCloudConfig();
  if (requested === 'uis') return readUisConfig();

  const grafanaCloudPresent = presentVars(GRAFANA_CLOUD_VARS).length > 0;
  const uisPresent = presentVars(UIS_VARS).length > 0;

  if (grafanaCloudPresent && uisPresent) {
    throw new Error(
      'Both Grafana Cloud and UIS env vars are present -- pass --backend grafana-cloud or --backend uis explicitly.'
    );
  }
  if (grafanaCloudPresent) return readGrafanaCloudConfig();
  if (uisPresent) return readUisConfig();

  throw new Error(
    `No backend configured. Set either:\n` +
      `  Grafana Cloud: ${GRAFANA_CLOUD_VARS.join(', ')}\n` +
      `  UIS: ${UIS_VARS.join(', ')}`
  );
}
