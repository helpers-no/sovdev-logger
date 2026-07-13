// The write half of the self-test: the exact same public API any real
// application uses (sovdev_initialize / sovdev_log / sovdev_shutdown) --
// not a special-cased write path. See INVESTIGATE-selftest-cli.md's Current
// State: "The write side isn't a new mechanism."

import { sovdev_initialize, sovdev_log, sovdev_shutdown } from '../index.js';
import { SOVDEV_LOGLEVELS } from '../logLevels.js';
import { create_peer_services } from '../peerServices.js';
import { logProgress } from './progress.js';
import { SELFTEST_MARKER_MESSAGE } from './marker.js';

/**
 * Resolves the disposable self-test service name: `<real-service-name>-selftest`.
 * Per [Q3], this keeps self-test writes isolated from the real dashboard's data.
 */
export function selftestServiceName(realServiceName: string): string {
  return `${realServiceName}-selftest`;
}

/**
 * Writes one marker log + one metric (sovdev_log's own operation-count
 * metric, emitted automatically per call) under the disposable service
 * name, then shuts down. Per [Q8], the disposable service name itself is
 * the marker -- no separate unique-value scheme needed for the metric.
 *
 * Progress is announced *between* each real call, in the actual order
 * things happen -- not one "sending" announcement made before any of this
 * starts. sovdev_initialize() configures the OTLP exporters (this is where
 * its own "OTLP Metrics configured for..." lines come from); sovdev_log()
 * only queues the marker in memory; sovdev_shutdown() is what actually
 * flushes the queue over the network. Reporting "sending" before
 * initialize() had even run was exactly the confusing, out-of-order
 * impression the maintainer flagged.
 */
export async function writeSelftestMarker(realServiceName: string): Promise<void> {
  const serviceName = selftestServiceName(realServiceName);
  const peerService = create_peer_services({}).INTERNAL;

  logProgress(
    `Initializing sovdev-logger for service_name=${serviceName} (configures the OTLP exporters) ...`
  );
  sovdev_initialize(serviceName);
  logProgress('Initialization complete.');

  // Spelled out as the literal argument list sovdev_log() is about to be
  // called with, in order, including the three optional args left null --
  // "queuing a marker" on its own doesn't say what's being sent, and
  // silently omitting the null args would hide part of the real call just
  // as much as omitting the non-null ones would. service_name isn't one of
  // sovdev_log()'s own arguments (it was set once, above, by
  // sovdev_initialize()), so it's not repeated here -- restating it inside
  // this line as well as inside a parenthetical about the metric was the
  // "blabla" the maintainer flagged: two mentions of the same fact, one of
  // them wrapped in an explanation nobody asked for mid-sentence.
  logProgress(
    `Queuing log entry -- sovdev_log(level=INFO, function_name=sovdev-selftest, message="${SELFTEST_MARKER_MESSAGE}", peer_service=${peerService}, input_json=null, response_json=null, exception_object=null) ...`
  );
  sovdev_log(
    SOVDEV_LOGLEVELS.INFO,
    'sovdev-selftest',
    SELFTEST_MARKER_MESSAGE,
    peerService,
    null,
    null,
    null
  );
  // A separate, plain statement of fact -- not folded into the line above --
  // since it's a distinct thing that just happened (a second signal emitted
  // from the one call above), not a justification for it.
  logProgress('Queued. This same call also auto-emitted the sovdev_operations_total metric.');

  logProgress(
    'Flushing and shutting down -- this is when the queued log + metric actually get sent over the network ...'
  );
  await sovdev_shutdown();
  logProgress('Shutdown complete.');
}
