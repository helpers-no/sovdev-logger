// Output formatting per [Q6]: plain text by default (matching query-loki.ts's
// existing ✅/❌ convention), --json for CI. Four independent signals, not
// one aggregate pass/fail.

import type { SignalResult } from './poll.js';

export function reportPlainText(results: SignalResult[]): void {
  for (const r of results) {
    const icon = r.pass ? '✅' : '❌';
    console.log(`${icon} ${r.name}: ${r.detail}`);
  }
  console.log();
  console.log(
    results.every((r) => r.pass)
      ? '✅ All checks passed.'
      : '❌ One or more checks failed — see above.'
  );
}

export function reportJson(results: SignalResult[]): void {
  const obj: Record<string, { pass: boolean; detail: string }> = {};
  for (const r of results) {
    obj[r.name] = { pass: r.pass, detail: r.detail };
  }
  console.log(JSON.stringify(obj));
}

export function report(results: SignalResult[], json: boolean): void {
  if (json) {
    reportJson(results);
  } else {
    reportPlainText(results);
  }
}
