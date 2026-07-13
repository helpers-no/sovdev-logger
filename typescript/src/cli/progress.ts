// Timestamped progress logging to stderr -- shared by selftest.ts and
// write-step.ts so every line (both the CLI's own announcements and the
// ones interleaved with the actual library calls) carries a timestamp and
// stays out of stdout, which --json mode's CI consumers parse as JSON.
export function logProgress(message: string): void {
  console.error(`[${new Date().toISOString()}] ${message}`);
}
