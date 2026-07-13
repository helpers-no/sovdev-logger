// The self-test marker message text, split into its own module so both
// selftest.ts and write-step.ts can import it without selftest.ts having to
// statically import write-step.ts itself -- write-step.ts pulls in the full
// @opentelemetry/* SDK chain (../index.js), which is deliberately deferred to
// a dynamic import in selftest.ts (~434ms to load; see the comment there).
export const SELFTEST_MARKER_MESSAGE = 'sovdev-selftest marker';
