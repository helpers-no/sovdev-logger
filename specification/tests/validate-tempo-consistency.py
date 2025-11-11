#!/usr/bin/env python3
"""
Sovdev Logger - Enhanced Trace Consistency Validator

Cross-validates that traces in Tempo match log entries field-by-field.
Ensures distributed tracing is working correctly and trace content is accurate.

Usage:
    # Compare file logs with Tempo response (human-readable output)
    ./query-tempo.sh sovdev-test-app --json > /tmp/tempo.json
    python3 validate-trace-consistency.py ./logs/dev.log /tmp/tempo.json

    # JSON output for automation
    python3 validate-trace-consistency.py ./logs/dev.log /tmp/tempo.json --json

    # Pipe Tempo response directly
    python3 validate-trace-consistency.py ./logs/dev.log <(./query-tempo.sh sovdev-test-app --json)

Exit Codes:
    0 - All trace_ids match (consistency verified)
    1 - Mismatches found (trace_ids don't match between file and Tempo)
    2 - Usage error (missing files, invalid JSON, etc.)

Output:
    - Matches: trace_ids that exist in both file and Tempo
    - Missing in Tempo: trace_ids in file but not found in Tempo (ERROR)
    - Older traces in Tempo: trace_ids in Tempo from previous test runs (expected)

Comparison Strategy:
    - Extracts unique trace_id values from log file
    - Extracts traceID values from Tempo response
    - Verifies all file trace_ids exist in Tempo
    - Note: Tempo stores trace_ids in 32-char hex format (without dashes)
    - File logs use UUID format with dashes (8-4-4-4-12)
    - Validator normalizes both formats for comparison

Integration:
    Can be integrated into run-company-lookup-validate.sh:
    ```bash
    if python3 validate-trace-consistency.py logs/dev.log <(query-tempo.sh app --json); then
        print_success "Trace consistency validated"
    else
        print_error "File trace_ids don't match Tempo traces"
    fi
    ```

Dependencies:
    - Python 3.7+
    - No external libraries required (uses stdlib only)

Troubleshooting:
    - "No matching traces": Check trace_id format (file: UUID with dashes, Tempo: 32-char hex)
    - "Missing in Tempo": Verify OTLP trace export is configured correctly
    - "Older traces in Tempo": This is normal - traces from previous test runs remain in Tempo

Related:
    - validate-log-format.sh: Validates file logs against schema
    - validate-tempo-response.py: Validates Tempo API response structure
    - query-tempo.sh: Queries Tempo for traces
"""

import argparse
import json
import sys
from pathlib import Path
from typing import Dict, List, Set, Any, Tuple
from datetime import datetime

# ANSI color codes
class Colors:
    RED = '\033[0;31m'
    GREEN = '\033[0;32m'
    YELLOW = '\033[1;33m'
    BLUE = '\033[0;34m'
    NC = '\033[0m'


class TraceConsistencyValidator:
    """Cross-validates file trace_ids against Tempo backend traces"""

    def __init__(self, json_mode: bool = False):
        """
        Initialize validator

        Args:
            json_mode: If True, output JSON instead of human-readable text
        """
        self.json_mode = json_mode
        self.matches = []
        self.mismatches = []
        self.missing_in_tempo = []
        self.extra_in_tempo = []
        self.errors = []
        self.warnings = []

    def print_success(self, msg: str):
        if not self.json_mode:
            print(f"{Colors.GREEN}✅ {msg}{Colors.NC}")

    def print_error(self, msg: str):
        self.errors.append(msg)
        if not self.json_mode:
            print(f"{Colors.RED}❌ {msg}{Colors.NC}", file=sys.stderr)

    def print_warning(self, msg: str):
        self.warnings.append(msg)
        if not self.json_mode:
            print(f"{Colors.YELLOW}⚠️  {msg}{Colors.NC}", file=sys.stderr)

    def print_info(self, msg: str):
        if not self.json_mode:
            print(f"{Colors.BLUE}ℹ️  {msg}{Colors.NC}")

    def normalize_trace_id(self, trace_id: str) -> str:
        """
        Normalize trace_id to 32-char hex format (no dashes, zero-padded)

        File logs: 8-4-4-4-12 format with dashes (UUID)
        Tempo: 16-32 char hex without dashes (may omit leading zeros)

        Args:
            trace_id: trace_id in any format

        Returns:
            Normalized 32-char hex string (no dashes, zero-padded)
        """
        # Remove dashes to get hex string
        normalized = trace_id.replace('-', '')

        # Pad with leading zeros to ensure 32 characters
        # This handles Tempo trace IDs that may be shorter than 32 chars
        return normalized.zfill(32)

    def parse_timestamp(self, timestamp: str) -> int:
        """Parse ISO timestamp to nanoseconds"""
        try:
            dt = datetime.fromisoformat(timestamp.replace('Z', '+00:00'))
            return int(dt.timestamp() * 1_000_000_000)
        except:
            return 0

    def read_file_logs_with_spans(self, file_path: Path) -> Dict[Tuple[str, str], Dict[str, Any]]:
        """
        Read file logs that have span_id, indexed by (trace_id, span_id)

        These are the log entries that should correspond to Tempo spans.
        """
        self.print_info(f"Reading log entries with spans from {file_path}...")
        logs = {}
        line_num = 0

        try:
            with open(file_path, 'r') as f:
                for line in f:
                    line_num += 1
                    line = line.strip()
                    if not line:
                        continue

                    try:
                        log_entry = json.loads(line)
                        trace_id = log_entry.get('trace_id')
                        span_id = log_entry.get('span_id')

                        # Only process logs with span_id (these create spans in Tempo)
                        if trace_id and span_id:
                            # Normalize trace_id for matching
                            normalized_trace_id = self.normalize_trace_id(trace_id)
                            key = (normalized_trace_id, span_id)
                            logs[key] = log_entry

                    except json.JSONDecodeError as e:
                        self.print_warning(f"Line {line_num}: Invalid JSON - {e}")

        except FileNotFoundError:
            self.print_error(f"File not found: {file_path}")
            return {}

        self.print_success(f"Found {len(logs)} log entries with spans")
        return logs

    def read_tempo_spans(self, tempo_path: Path) -> Dict[Tuple[str, str], Dict[str, Any]]:
        """
        Read Tempo traces and extract all spans, indexed by (trace_id, span_id)

        Returns a flat dictionary of all spans from all traces.
        """
        self.print_info(f"Reading Tempo spans from {tempo_path}...")
        spans = {}

        try:
            if str(tempo_path) == '-':
                tempo_data = json.load(sys.stdin)
            else:
                tempo_data = json.loads(tempo_path.read_text())
        except json.JSONDecodeError as e:
            self.print_error(f"Invalid Tempo JSON: {e}")
            return {}
        except FileNotFoundError:
            self.print_error(f"File not found: {tempo_path}")
            return {}

        # Extract spans from all traces
        traces = tempo_data.get('traces', [])
        for trace in traces:
            trace_id = trace.get('traceID')
            if not trace_id:
                continue

            normalized_trace_id = self.normalize_trace_id(trace_id)

            # Extract spans from spanSets
            span_sets = trace.get('spanSets', [])
            for span_set in span_sets:
                spans_list = span_set.get('spans', [])
                for span in spans_list:
                    span_id = span.get('spanID')
                    if span_id:
                        key = (normalized_trace_id, span_id)
                        spans[key] = {
                            'trace_id': normalized_trace_id,
                            'span_id': span_id,
                            'operation_name': span.get('operationName', ''),
                            'start_time_unix_nano': span.get('startTimeUnixNano', 0),
                            'duration_nanos': span.get('durationNanos', 0),
                            'attributes': span.get('attributes', []),
                            'status': span.get('status', {}),
                            'raw_span': span
                        }

        self.print_success(f"Found {len(spans)} spans in Tempo")
        return spans

    def compare_span_with_log(self, log_entry: Dict[str, Any],
                              tempo_span: Dict[str, Any]) -> Dict[str, Tuple[Any, Any]]:
        """
        Compare a log entry with its corresponding Tempo span

        Returns dictionary of mismatched fields
        """
        mismatches = {}

        # 1. Compare operation name vs function_name
        log_function = log_entry.get('function_name', '')
        span_operation = tempo_span.get('operation_name', '')

        if log_function != span_operation:
            mismatches['operation_name'] = (log_function, span_operation)

        # 2. Compare timestamp (allow 1 second tolerance for clock skew)
        log_timestamp = log_entry.get('timestamp', '')
        log_time_ns = self.parse_timestamp(log_timestamp)
        span_time_ns_raw = tempo_span.get('start_time_unix_nano', 0)

        # Convert span timestamp to int if it's a string
        try:
            span_time_ns = int(span_time_ns_raw) if span_time_ns_raw else 0
        except (ValueError, TypeError):
            span_time_ns = 0

        if log_time_ns and span_time_ns:
            time_diff_ms = abs(log_time_ns - span_time_ns) / 1_000_000
            if time_diff_ms > 1000:  # More than 1 second difference
                mismatches['timestamp'] = (
                    f"{log_timestamp} ({log_time_ns}ns)",
                    f"{span_time_ns}ns (diff: {time_diff_ms:.0f}ms)"
                )

        # 3. Compare peer_service in span attributes
        log_peer_service = log_entry.get('peer_service', '')
        span_attrs = tempo_span.get('attributes', [])
        span_peer_service = None

        for attr in span_attrs:
            if attr.get('key') == 'peer_service':
                span_peer_service = attr.get('value', {}).get('stringValue', '')
                break

        if log_peer_service and span_peer_service and log_peer_service != span_peer_service:
            mismatches['peer_service'] = (log_peer_service, span_peer_service)

        # 4. Compare error status
        log_level = log_entry.get('level', 'info')
        span_status = tempo_span.get('status', {})
        span_status_code = span_status.get('code', 0)  # 0 = OK, 2 = ERROR

        log_is_error = log_level in ['error', 'fatal']
        span_is_error = span_status_code == 2

        if log_is_error != span_is_error:
            mismatches['error_status'] = (
                f"log_level={log_level}",
                f"span_status_code={span_status_code}"
            )

        # 5. Compare service_name in span attributes
        log_service = log_entry.get('service_name', '')
        span_service = None

        for attr in span_attrs:
            if attr.get('key') == 'service.name':
                span_service = attr.get('value', {}).get('stringValue', '')
                break

        if log_service and span_service and log_service != span_service:
            mismatches['service_name'] = (log_service, span_service)

        return mismatches

    def compare_logs_and_spans(self, file_logs: Dict, tempo_spans: Dict) -> bool:
        """Compare file logs with Tempo spans"""
        self.print_info("Comparing log entries with Tempo spans...")

        file_keys = set(file_logs.keys())
        tempo_keys = set(tempo_spans.keys())

        # Find matches, mismatches, and missing
        common_keys = file_keys & tempo_keys
        missing_keys = file_keys - tempo_keys
        extra_keys = tempo_keys - file_keys

        # Compare common entries
        for key in common_keys:
            trace_id, span_id = key
            log_entry = file_logs[key]
            tempo_span = tempo_spans[key]

            mismatch_fields = self.compare_span_with_log(log_entry, tempo_span)

            if mismatch_fields:
                self.mismatches.append({
                    'trace_id': trace_id,
                    'span_id': span_id,
                    'mismatches': mismatch_fields
                })
            else:
                self.matches.append({
                    'trace_id': trace_id,
                    'span_id': span_id
                })

        # Record missing spans
        for key in missing_keys:
            trace_id, span_id = key
            log_entry = file_logs[key]
            self.missing_in_tempo.append({
                'trace_id': trace_id,
                'span_id': span_id,
                'function_name': log_entry.get('function_name', '(unknown)')
            })

        # Record extra spans
        for key in extra_keys:
            trace_id, span_id = key
            tempo_span = tempo_spans[key]
            self.extra_in_tempo.append({
                'trace_id': trace_id,
                'span_id': span_id,
                'operation_name': tempo_span.get('operation_name', '(unknown)')
            })

        # Print results
        if self.matches:
            self.print_success(f"{len(self.matches)} spans match perfectly")

        if self.mismatches:
            self.print_error(f"{len(self.mismatches)} spans have field mismatches")
            if not self.json_mode:
                for m in self.mismatches[:3]:  # Show first 3
                    print(f"  {m['trace_id'][:16]}.../{m['span_id'][:8]}:")
                    for field, (log_val, tempo_val) in m['mismatches'].items():
                        print(f"    {field}: log={log_val!r} tempo={tempo_val!r}")
                if len(self.mismatches) > 3:
                    print(f"  ... and {len(self.mismatches) - 3} more mismatches")

        if self.missing_in_tempo:
            self.print_error(f"{len(self.missing_in_tempo)} spans missing in Tempo")
            if not self.json_mode:
                for m in self.missing_in_tempo[:3]:
                    print(f"  {m['trace_id'][:16]}.../{m['span_id'][:8]}: {m['function_name']}")
                if len(self.missing_in_tempo) > 3:
                    print(f"  ... and {len(self.missing_in_tempo) - 3} more missing")

        if self.extra_in_tempo:
            if not self.json_mode:
                print(f"\n{Colors.BLUE}ℹ️  Note: {len(self.extra_in_tempo)} extra spans in Tempo (from previous runs){Colors.NC}")

        # Validation passes if no mismatches and no missing spans
        all_match = (len(self.mismatches) == 0 and len(self.missing_in_tempo) == 0)
        return all_match

    def read_file_trace_ids(self, file_path: Path) -> Set[str]:
        """
        Read unique trace_ids from NDJSON log file that have associated spans

        Only includes trace_ids that have a span_id field, as these are the ones
        that should appear in Tempo. Log entries without spans only have a
        fallback UUID trace_id for correlation, not an OpenTelemetry span.

        Args:
            file_path: Path to NDJSON log file

        Returns:
            Set of unique trace_ids (normalized to 32-char hex) that have spans
        """
        self.print_info(f"Reading trace_ids from {file_path}...")
        trace_ids = set()
        line_num = 0
        total_trace_ids = 0
        trace_ids_with_spans = 0

        try:
            with open(file_path, 'r') as f:
                for line in f:
                    line_num += 1
                    line = line.strip()
                    if not line:
                        continue

                    try:
                        log_entry = json.loads(line)
                        trace_id = log_entry.get('trace_id')
                        span_id = log_entry.get('span_id')

                        if trace_id:
                            total_trace_ids += 1
                            # Only include trace_ids that have an associated span_id
                            # These are the ones that should appear in Tempo
                            if span_id:
                                trace_ids_with_spans += 1
                                # Normalize to 32-char hex format
                                normalized = self.normalize_trace_id(trace_id)
                                trace_ids.add(normalized)

                    except json.JSONDecodeError as e:
                        self.print_warning(f"Line {line_num}: Invalid JSON - {e}")

        except FileNotFoundError:
            self.print_error(f"File not found: {file_path}")
            return set()

        self.print_success(f"Found {len(trace_ids)} unique trace_ids with spans in file")
        if not self.json_mode and trace_ids_with_spans < total_trace_ids:
            self.print_info(f"Note: {total_trace_ids - trace_ids_with_spans} log entries have trace_id but no span_id (not expected in Tempo)")
        return trace_ids

    def read_tempo_trace_ids(self, tempo_path: Path) -> Set[str]:
        """
        Read trace IDs from Tempo API response

        Tempo stores traces with traceID field (32-char hex format).

        Args:
            tempo_path: Path to Tempo response JSON file

        Returns:
            Set of trace IDs from Tempo (32-char hex format)
        """
        self.print_info(f"Reading trace IDs from {tempo_path}...")
        trace_ids = set()

        try:
            if str(tempo_path) == '-':
                tempo_data = json.load(sys.stdin)
            else:
                tempo_data = json.loads(tempo_path.read_text())
        except json.JSONDecodeError as e:
            self.print_error(f"Invalid Tempo JSON: {e}")
            return set()
        except FileNotFoundError:
            self.print_error(f"File not found: {tempo_path}")
            return set()

        # Extract trace IDs from Tempo traces
        traces = tempo_data.get('traces', [])
        for trace in traces:
            trace_id = trace.get('traceID')
            if trace_id:
                # Normalize Tempo trace IDs (they may be shorter than 32 chars)
                normalized = self.normalize_trace_id(trace_id)
                trace_ids.add(normalized)

        self.print_success(f"Found {len(trace_ids)} unique trace IDs in Tempo")
        return trace_ids

    def compare_trace_ids(self, file_trace_ids: Set[str], tempo_trace_ids: Set[str]) -> bool:
        """
        Compare file trace_ids with Tempo trace IDs

        Args:
            file_trace_ids: trace_ids from file (normalized to 32-char hex)
            tempo_trace_ids: trace IDs from Tempo (32-char hex)

        Returns:
            True if all file trace_ids exist in Tempo, False otherwise
        """
        self.print_info("Comparing file trace_ids with Tempo trace IDs...")

        # Find matches, missing, and extra
        matches = file_trace_ids & tempo_trace_ids
        missing = file_trace_ids - tempo_trace_ids
        extra = tempo_trace_ids - file_trace_ids

        # Record results
        self.matches = list(matches)
        self.missing_in_tempo = list(missing)
        self.extra_in_tempo = list(extra)

        # Print results
        if matches:
            self.print_success(f"{len(matches)} trace_ids match perfectly")

        if missing:
            self.print_error(f"{len(missing)} trace_ids missing in Tempo")
            if not self.json_mode:
                for trace_id in list(missing)[:3]:  # Show first 3
                    print(f"  {trace_id[:16]}...")
                if len(missing) > 3:
                    print(f"  ... and {len(missing) - 3} more missing")

        if extra:
            # Don't treat extra traces as a warning - this is expected when tests run multiple times
            # Old traces from previous runs remain in Tempo, which is normal behavior
            if not self.json_mode:
                print(f"\n{Colors.BLUE}ℹ️  Note: {len(extra)} older traces found in Tempo (from previous test runs){Colors.NC}")
                if len(extra) <= 5:
                    for trace_id in list(extra):
                        print(f"  {trace_id[:16]}...")
                else:
                    print(f"  This is normal - Tempo retains traces from multiple test runs")
                    print(f"  Validation only checks that current file trace_ids are present in Tempo")

        # Validation passes if all file trace_ids exist in Tempo
        # Extra traces in Tempo are OK (old traces from previous runs)
        all_match = len(missing) == 0

        return all_match

    def print_summary(self, all_match: bool):
        """Print validation summary"""
        if not self.json_mode:
            print()
            if all_match:
                self.print_success("TRACE CONSISTENCY VALIDATION PASSED")
            else:
                self.print_error("TRACE CONSISTENCY VALIDATION FAILED")
            print()
            print(f"Total matches: {len(self.matches)}")
            print(f"Total mismatches: {len(self.mismatches)}")
            print(f"Missing in Tempo: {len(self.missing_in_tempo)}")
            print(f"Extra in Tempo (from previous runs): {len(self.extra_in_tempo)}")

            if self.warnings:
                print(f"\nWarnings: {len(self.warnings)}")
                for warning in self.warnings[:5]:
                    print(f"  - {warning}")
                if len(self.warnings) > 5:
                    print(f"  ... and {len(self.warnings) - 5} more warnings")

    def get_json_output(self, passed: bool) -> Dict[str, Any]:
        """Generate JSON output for automation"""
        return {
            'validation': 'passed' if passed else 'failed',
            'summary': {
                'matches': len(self.matches),
                'missing_in_tempo': len(self.missing_in_tempo),
                'extra_in_tempo': len(self.extra_in_tempo)
            },
            'missing_in_tempo': self.missing_in_tempo,
            'extra_in_tempo': self.extra_in_tempo,
            'errors': self.errors,
            'warnings': self.warnings
        }


def main():
    parser = argparse.ArgumentParser(
        description='Cross-validate file trace_ids against Tempo backend traces',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__
    )
    parser.add_argument(
        'file_log',
        type=Path,
        help='Path to NDJSON log file (e.g., logs/dev.log)'
    )
    parser.add_argument(
        'tempo_response',
        type=Path,
        help='Path to Tempo response JSON file (use "-" for stdin)'
    )
    parser.add_argument(
        '--json',
        action='store_true',
        help='Output JSON format for automation'
    )

    args = parser.parse_args()

    # Validate file exists (unless stdin)
    if str(args.tempo_response) != '-' and not args.tempo_response.exists():
        print(f"ERROR: Tempo response file not found: {args.tempo_response}", file=sys.stderr)
        sys.exit(2)

    if not args.file_log.exists():
        print(f"ERROR: Log file not found: {args.file_log}", file=sys.stderr)
        sys.exit(2)

    # Run validation
    validator = TraceConsistencyValidator(json_mode=args.json)
    file_logs = validator.read_file_logs_with_spans(args.file_log)
    tempo_spans = validator.read_tempo_spans(args.tempo_response)

    if not file_logs:
        print("ERROR: No log entries with spans found in file", file=sys.stderr)
        sys.exit(2)

    if not tempo_spans:
        validator.print_error("No spans found in Tempo")
        sys.exit(1)

    all_match = validator.compare_logs_and_spans(file_logs, tempo_spans)

    # Print results
    validator.print_summary(all_match)

    if args.json:
        print(json.dumps(validator.get_json_output(all_match), indent=2))

    sys.exit(0 if all_match else 1)


if __name__ == '__main__':
    main()
