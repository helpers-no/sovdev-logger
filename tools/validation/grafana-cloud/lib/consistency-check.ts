// Pipes a query result to the existing Python consistency validators in
// tools/validation/validators/ — the exact-match comparison logic (trace_id/event_id
// against the source log file) is never reimplemented here. See
// INVESTIGATE-grafana-cloud-validator.md's "Option A" decision: only the
// fetch/auth layer is TypeScript; the proven, never-buggy comparison engines
// stay Python, unchanged, called the same way the bash scripts already call
// them.

import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const HERE = path.dirname(fileURLToPath(import.meta.url));

// tools/validation/validators/ relative to tools/validation/grafana-cloud/lib/
const VALIDATORS_DIR = path.resolve(HERE, '../../validators');

export interface ConsistencyCheckResult {
  exitCode: number;
  stdout: string;
  stderr: string;
}

export function runConsistencyCheck(
  validatorFilename: string,
  logFile: string,
  queryResultJson: string,
): ConsistencyCheckResult {
  const validatorScript = path.join(VALIDATORS_DIR, validatorFilename);
  const result = spawnSync('python3', [validatorScript, logFile, '-'], {
    input: queryResultJson,
    encoding: 'utf-8',
  });

  return {
    exitCode: result.status ?? 1,
    stdout: result.stdout ?? '',
    stderr: result.stderr ?? '',
  };
}
