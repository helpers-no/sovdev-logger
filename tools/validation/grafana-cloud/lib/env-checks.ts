// Pure validation functions for Grafana Cloud env vars — no I/O, no
// process.env access, so these are trivially unit-testable with fake values.
// check-connection.ts wires these to real env vars; env-checks.test.ts tests
// the logic itself with dummy data.

export interface CheckOutcome {
  ok: boolean;
  detail: string;
}

export function validateUrlEnv(value: string | undefined): CheckOutcome {
  if (!value) {
    return { ok: false, detail: 'not set' };
  }
  let url: URL;
  try {
    url = new URL(value);
  } catch {
    return { ok: false, detail: `set, but not a valid URL: "${value}"` };
  }
  if (url.protocol !== 'https:') {
    return { ok: false, detail: `set, but not https:// (${url.protocol})` };
  }
  return { ok: true, detail: 'set, valid https:// URL' };
}

export function validateInstanceIdEnv(value: string | undefined): CheckOutcome {
  if (!value) {
    return { ok: false, detail: 'not set' };
  }
  if (!/^\d+$/.test(value)) {
    return { ok: false, detail: `set, but not purely numeric: "${value}"` };
  }
  return { ok: true, detail: 'set, numeric' };
}

export function validateTokenEnv(value: string | undefined): CheckOutcome {
  if (!value) {
    return { ok: false, detail: 'not set' };
  }
  if (value.length < 20) {
    return { ok: false, detail: 'set, but suspiciously short for a real token' };
  }
  const looksLikeGrafanaToken = value.startsWith('glc_');
  return {
    ok: true,
    detail: looksLikeGrafanaToken
      ? 'set, length OK, has expected glc_ prefix'
      : 'set, length OK, but missing the usual glc_ prefix — double-check this is the right token',
  };
}
