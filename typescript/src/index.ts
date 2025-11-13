/**
 * Sovdev Logger - Main Export File
 *
 * Structured logging library for OpenTelemetry with "Loggeloven av 2025" compliance
 *
 * @packageDocumentation
 */

// Export main logging functions (with sovdev_ prefix for consistency with Python implementation)
export {
  sovdev_validate_config,        // NEW: Validate OTLP configuration
  sovdev_test_otlp_connection,   // NEW: Test OTLP connectivity
  sovdev_initialize,
  sovdev_flush,
  sovdev_log,
  sovdev_log_job_status,
  sovdev_log_job_progress,
  sovdev_start_span,
  sovdev_end_span,
} from './logger';

// Export log levels
export { SOVDEV_LOGLEVELS } from './logLevels';

// Export peer service helper
export { create_peer_services } from './peerServices';

// Export TypeScript types
export type { sovdev_log_level } from './logLevels';
export type { structured_log_entry } from './logger';
