// Shared HTTP Basic Auth query helper for the self-test CLI's read side.
// Generalized from tools/validation/grafana-cloud/lib/grafana-cloud-client.ts
// so both backends can use the exact same query logic: Grafana Cloud hits
// Loki/Prometheus's own hosted URLs directly; UIS hits the same paths
// through Grafana's datasource-proxy API (grafana.localhost/api/datasources/
// proxy/uid/<uid>/...). Neither backend has an SDK for this -- querying is
// plain HTTPS with a Basic Auth header either way (see
// INVESTIGATE-selftest-cli.md's "UIS is reachable over plain HTTP").

import * as http from 'node:http';
import * as https from 'node:https';
import { logProgress } from './progress.js';

export interface BasicAuthCredentials {
  user: string;
  pass: string;
}

/**
 * GET a Loki/Prometheus query API endpoint with HTTP Basic Auth.
 * Throws with the response body included on a non-2xx -- a self-test tool
 * that swallows the real error defeats its own purpose.
 *
 * Built on node:http/node:https rather than the global fetch(), specifically
 * because of `hostHeader` below -- verified directly (not assumed) that
 * fetch()/undici silently drops a manually-set `Host` header (it's a
 * WHATWG-forbidden header name), while node:http/https send whatever `Host`
 * you give them. A version of this using fetch() looked like it worked (no
 * error, no type mismatch) but actually sent the request with the wrong
 * Host, and Traefik 404'd it -- exactly the kind of silent, unverified claim
 * this tool exists to avoid making about *other* systems, so it can't make
 * that mistake about its own request either.
 *
 * `hostHeader`, when set, overrides the HTTP `Host` header sent with the
 * request without changing the URL/connection target -- needed from inside
 * the devcontainer, where `grafana.localhost` resolves to the container's
 * own loopback (nothing listens there), not the host machine. The working
 * path is `http://host.docker.internal` (Docker's built-in host alias) plus
 * `Host: grafana.localhost`, so Traefik still routes to Grafana by hostname
 * -- the exact same pattern the OTLP write side already uses via
 * `OTEL_EXPORTER_OTLP_HEADERS=Host=otel.localhost` (see uis.md).
 *
 * Logs the exact request URL (and the Host override, if any) immediately
 * before firing it -- the same `url`/`hostHeader` values used for the real
 * request, not a string reconstructed separately for display, so the log
 * line can't drift from what's actually sent. The Authorization header
 * itself (the credential) is never logged -- only the URL and Host
 * override, which carry no secret. The user can paste this exact URL (and
 * Host header, if shown) into curl with their own Basic Auth to verify the
 * read independently.
 */
export async function queryWithBasicAuth(
  baseUrl: string,
  path: string,
  params: Record<string, string>,
  creds: BasicAuthCredentials,
  hostHeader?: string
): Promise<unknown> {
  // `new URL(path, baseUrl)` would treat a leading-slash path as absolute,
  // silently discarding baseUrl's own path -- fatal for UIS's datasource-proxy
  // URLs, which have a real path prefix (/api/datasources/proxy/uid/<uid>).
  // Append to whatever path baseUrl already has instead of replacing it.
  const url = new URL(baseUrl);
  url.pathname = url.pathname.replace(/\/$/, '') + path;
  for (const [key, value] of Object.entries(params)) {
    url.searchParams.set(key, value);
  }

  logProgress(hostHeader ? `Querying: GET ${url} (Host: ${hostHeader})` : `Querying: GET ${url}`);

  const auth = Buffer.from(`${creds.user}:${creds.pass}`).toString('base64');
  const headers: Record<string, string> = { Authorization: `Basic ${auth}` };
  if (hostHeader) headers.Host = hostHeader;

  const client = url.protocol === 'https:' ? https : http;

  const { statusCode, statusMessage, body } = await new Promise<{
    statusCode: number;
    statusMessage: string;
    body: string;
  }>((resolve, reject) => {
    const req = client.request(
      {
        hostname: url.hostname,
        port: url.port || (url.protocol === 'https:' ? 443 : 80),
        path: `${url.pathname}${url.search}`,
        method: 'GET',
        headers,
      },
      (res) => {
        let data = '';
        res.setEncoding('utf8');
        res.on('data', (chunk: string) => (data += chunk));
        res.on('end', () =>
          resolve({
            statusCode: res.statusCode ?? 0,
            statusMessage: res.statusMessage ?? '',
            body: data,
          })
        );
      }
    );
    req.on('error', reject);
    req.end();
  });

  if (statusCode < 200 || statusCode >= 300) {
    throw new Error(`Query failed: ${statusCode} ${statusMessage}\nURL: ${url}\nBody: ${body}`);
  }

  return JSON.parse(body);
}
