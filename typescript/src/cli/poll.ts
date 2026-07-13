// Poll-with-backoff for the read side, per [Q4]: query on an interval until
// found or a timeout, distinguishing a timeout ("may still arrive") from a
// hard failure (a query that throws -- wrong credential, wrong endpoint) --
// conflating the two reproduces the false "it's broken" signal this whole
// line of investigation exists to eliminate. A hard failure is reported
// immediately, without waiting out the rest of the timeout.

export interface SignalResult {
  name: string;
  pass: boolean;
  detail: string;
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

/**
 * extractDetail returns null if the signal isn't found in this response yet
 * (keep polling), or a human-readable description of what was actually
 * found if it is -- so the report shows real content (the log message, the
 * metric value), not just the word "found".
 */
export async function pollForSignal(
  name: string,
  queryFn: () => Promise<unknown>,
  extractDetail: (response: unknown) => string | null,
  timeoutMs: number,
  intervalMs = 2000
): Promise<SignalResult> {
  const deadline = Date.now() + timeoutMs;

  while (Date.now() < deadline) {
    let response: unknown;
    try {
      response = await queryFn();
    } catch (err) {
      return {
        name,
        pass: false,
        detail: `query failed: ${(err as Error).message.split('\n')[0]}`,
      };
    }

    const detail = extractDetail(response);
    if (detail !== null) {
      return { name, pass: true, detail };
    }

    await sleep(intervalMs);
  }

  return { name, pass: false, detail: 'timed out -- may still arrive, try again shortly' };
}
