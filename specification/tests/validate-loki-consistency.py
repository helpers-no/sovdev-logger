#!/usr/bin/env python3
"""
Sovdev Logger - Log Consistency Validator

Cross-validates that logs written to files match logs retrieved from Loki backend.
Ensures data consistency between file logging and OTLP export to Loki.

Usage:
    # Compare file logs with Loki response (human-readable output)
    ./query-loki.sh sovdev-test-app --json > /tmp/loki.json
    python3 validate-log-consistency.py ./logs/dev.log /tmp/loki.json

    # JSON output for automation
    python3 validate-log-consistency.py ./logs/dev.log /tmp/loki.json --json

    # Pipe Loki response directly
    python3 validate-log-consistency.py ./logs/dev.log <(./query-loki.sh sovdev-test-app --json)

Exit Codes:
    0 - All logs match (consistency verified)
    1 - Mismatches found (logs don't match between file and Loki)
    2 - Usage error (missing files, invalid JSON, etc.)

Output:
    - Matches: Log entries that match between file and Loki
    - Mismatches: Entries exist in both but have different field values
    - Missing in Loki: Entries in file but not found in Loki (ERROR)
    - Older entries in Loki: Entries in Loki from previous test runs (expected)

Comparison Strategy:
    - Uses trace_id + event_id as unique identifier pair
    - Compares critical fields: message, function_name, log_type, level
    - Ignores timestamp precision differences (file vs backend)
    - Normalizes level values (case-insensitive)

Integration:
    Can be integrated into run-company-lookup-validate.sh:
    ```bash
    if python3 validate-log-consistency.py logs/dev.log <(query-loki.sh app --json); then
        print_success "Log consistency validated"
    else
        print_error "File logs don't match Loki logs"
    fi
    ```

Dependencies:
    - Python 3.7+
    - No external libraries required (uses stdlib only)

Troubleshooting:
    - "No matching logs": Check trace_id/event_id format (must be UUIDs)
    - "Field mismatch": Check for camelCase vs snake_case issues
    - "Missing in Loki": Verify OTLP export is configured correctly
    - "Older entries in Loki": This is normal - logs from previous test runs remain in Loki

Related:
    - validate-log-format.sh: Validates file logs against schema
    - validate-loki-response.py: Validates Loki API response structure
    - query-loki.sh: Queries Loki for log entries
"""

import argparse
import json
import sys
from pathlib import Path
from typing import Dict, List, Set, Any, Tuple


# ANSI color codes
class Colors:
    RED = '\033[0;31m'
    GREEN = '\033[0;32m'
    YELLOW = '\033[1;33m'
    BLUE = '\033[0;34m'
    NC = '\033[0m'


class LogConsistencyValidator:
    """Cross-validates file logs against Loki backend logs"""

    def __init__(self, json_mode: bool = False):
        """
        Initialize validator

        Args:
            json_mode: If True, output JSON instead of human-readable text
        """
        self.json_mode = json_mode
        self.matches = []
        self.mismatches = []
        self.missing_in_loki = []
        self.extra_in_loki = []
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

    def read_file_logs(self, file_path: Path) -> Dict[Tuple[str, str], Dict[str, Any]]:
        """
        Read NDJSON log file and index by (trace_id, event_id)

        Args:
            file_path: Path to NDJSON log file

        Returns:
            Dict mapping (trace_id, event_id) -> log_entry
        """
        self.print_info(f"Reading file logs from {file_path}...")
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
                        event_id = log_entry.get('event_id')

                        if not trace_id or not event_id:
                            self.print_warning(f"Line {line_num}: Missing trace_id or event_id")
                            continue

                        key = (trace_id, event_id)
                        if key in logs:
                            self.print_warning(f"Duplicate entry: {trace_id}/{event_id}")
                        logs[key] = log_entry

                    except json.JSONDecodeError as e:
                        self.print_error(f"Line {line_num}: Invalid JSON - {e}")

        except FileNotFoundError:
            self.print_error(f"File not found: {file_path}")
            return {}

        self.print_success(f"Read {len(logs)} log entries from file")
        return logs

    def read_loki_logs(self, loki_path: Path) -> Dict[Tuple[str, str], Dict[str, Any]]:
        """
        Read Loki API response and index by (trace_id, event_id)

        Loki stores logs in a split format:
        - Structured fields (service_name, function_name, etc.) → stream labels
        - Message text → values array as plain string

        This method reconstructs complete log entries by merging both sources.

        Args:
            loki_path: Path to Loki response JSON file

        Returns:
            Dict mapping (trace_id, event_id) -> log_entry
        """
        self.print_info(f"Reading Loki logs from {loki_path}...")
        logs = {}

        try:
            if str(loki_path) == '-':
                loki_data = json.load(sys.stdin)
            else:
                loki_data = json.loads(loki_path.read_text())
        except json.JSONDecodeError as e:
            self.print_error(f"Invalid Loki JSON: {e}")
            return {}
        except FileNotFoundError:
            self.print_error(f"File not found: {loki_path}")
            return {}

        # Extract log entries from Loki streams
        results = loki_data.get('data', {}).get('result', [])
        for stream_data in results:
            # Get stream labels (structured fields)
            stream_labels = stream_data.get('stream', {})

            # Get values (timestamp + message text)
            values = stream_data.get('values', [])

            for value_pair in values:
                if len(value_pair) < 2:
                    self.print_warning(f"Loki value pair incomplete: {value_pair}")
                    continue

                timestamp_ns, message_text = value_pair

                # Reconstruct log entry by merging stream labels + message
                log_entry = dict(stream_labels)  # Copy all stream labels
                log_entry['message'] = message_text  # Add message text

                # Extract identifiers
                trace_id = log_entry.get('trace_id')
                event_id = log_entry.get('event_id')

                if not trace_id or not event_id:
                    self.print_warning(f"Loki entry missing trace_id or event_id")
                    continue

                key = (trace_id, event_id)
                if key in logs:
                    self.print_warning(f"Duplicate entry in Loki: {trace_id}/{event_id}")
                logs[key] = log_entry

        self.print_success(f"Read {len(logs)} log entries from Loki")
        return logs

    def compare_logs(self, file_logs: Dict[Tuple[str, str], Dict[str, Any]],
                     loki_logs: Dict[Tuple[str, str], Dict[str, Any]]) -> bool:
        """
        Compare file logs with Loki logs

        Args:
            file_logs: Logs from file indexed by (trace_id, event_id)
            loki_logs: Logs from Loki indexed by (trace_id, event_id)

        Returns:
            True if all logs match, False otherwise
        """
        self.print_info("Comparing file logs with Loki logs...")

        file_keys = set(file_logs.keys())
        loki_keys = set(loki_logs.keys())

        # Find matches, mismatches, and missing entries
        common_keys = file_keys & loki_keys
        missing_keys = file_keys - loki_keys
        extra_keys = loki_keys - file_keys

        # Compare common entries
        for key in common_keys:
            file_entry = file_logs[key]
            loki_entry = loki_logs[key]

            mismatch_fields = self._compare_entries(file_entry, loki_entry)
            if mismatch_fields:
                self.mismatches.append({
                    'trace_id': key[0],
                    'event_id': key[1],
                    'mismatches': mismatch_fields
                })
            else:
                self.matches.append({
                    'trace_id': key[0],
                    'event_id': key[1]
                })

        # Record missing entries
        for key in missing_keys:
            self.missing_in_loki.append({
                'trace_id': key[0],
                'event_id': key[1],
                'message': file_logs[key].get('message', '(no message)')
            })

        # Record extra entries
        for key in extra_keys:
            self.extra_in_loki.append({
                'trace_id': key[0],
                'event_id': key[1],
                'message': loki_logs[key].get('message', '(no message)')
            })

        # Print results
        if self.matches:
            self.print_success(f"{len(self.matches)} entries match perfectly")

        if self.mismatches:
            self.print_error(f"{len(self.mismatches)} entries have field mismatches")
            if not self.json_mode:
                for m in self.mismatches[:3]:  # Show first 3
                    print(f"  {m['trace_id']}/{m['event_id'][:8]}:")
                    for field, (file_val, loki_val) in m['mismatches'].items():
                        print(f"    {field}: file={file_val!r} loki={loki_val!r}")
                if len(self.mismatches) > 3:
                    print(f"  ... and {len(self.mismatches) - 3} more mismatches")

        if self.missing_in_loki:
            self.print_error(f"{len(self.missing_in_loki)} entries missing in Loki")
            if not self.json_mode:
                for m in self.missing_in_loki[:3]:  # Show first 3
                    print(f"  {m['trace_id']}/{m['event_id'][:8]}: {m['message']}")
                if len(self.missing_in_loki) > 3:
                    print(f"  ... and {len(self.missing_in_loki) - 3} more missing")

        if self.extra_in_loki:
            # Don't treat extra entries as a warning - this is expected when tests run multiple times
            # Old logs from previous runs remain in Loki, which is normal behavior
            if not self.json_mode:
                print(f"\n{Colors.BLUE}ℹ️  Note: {len(self.extra_in_loki)} older entries found in Loki (from previous test runs){Colors.NC}")
                if len(self.extra_in_loki) <= 5:
                    for e in self.extra_in_loki:
                        print(f"  {e['trace_id']}/{e['event_id'][:8]}: {e['message']}")
                else:
                    print(f"  This is normal - Loki retains logs from multiple test runs")
                    print(f"  Validation only checks that current file logs are present in Loki")

        # Validation passes if:
        # 1. No mismatches (all common entries match)
        # 2. No missing in Loki (all file entries are in Loki)
        # Note: Extra entries in Loki are OK (old logs from previous runs)
        all_match = (len(self.mismatches) == 0 and
                     len(self.missing_in_loki) == 0)

        return all_match

    def _compare_entries(self, file_entry: Dict[str, Any],
                        loki_entry: Dict[str, Any]) -> Dict[str, Tuple[Any, Any]]:
        """
        Compare individual log entries field-by-field

        Handles field name differences between file logs and Loki:
        - File logs: 'level' field
        - Loki: 'severity_text' or 'detected_level' fields (OTEL convention)

        Args:
            file_entry: Log entry from file
            loki_entry: Log entry from Loki

        Returns:
            Dict of mismatched fields: {field_name: (file_value, loki_value)}
        """
        # Fields to compare (critical fields only)
        compare_fields = [
            'message',
            'function_name',
            'log_type',
            'service_name',
            'service_version',
            'peer_service',
            'trace_id',
            'span_id',
            'event_id'
        ]

        mismatches = {}
        for field in compare_fields:
            file_val = file_entry.get(field)
            loki_val = loki_entry.get(field)

            if file_val != loki_val:
                mismatches[field] = (file_val, loki_val)

        # Special handling for 'level' field (file) vs 'severity_text' (Loki)
        file_level = file_entry.get('level')
        loki_level = loki_entry.get('severity_text') or loki_entry.get('detected_level')

        if file_level and loki_level:
            # Normalize for comparison (case-insensitive)
            file_level_norm = str(file_level).upper()
            loki_level_norm = str(loki_level).upper()

            if file_level_norm != loki_level_norm:
                mismatches['level'] = (file_level, loki_level)

        return mismatches

    def print_summary(self, all_match: bool):
        """Print validation summary"""
        if not self.json_mode:
            print()
            if all_match:
                self.print_success("LOG CONSISTENCY VALIDATION PASSED")
            else:
                self.print_error("LOG CONSISTENCY VALIDATION FAILED")
            print()
            print(f"Total matches: {len(self.matches)}")
            print(f"Total mismatches: {len(self.mismatches)}")
            print(f"Missing in Loki: {len(self.missing_in_loki)}")
            print(f"Older entries in Loki (from previous runs): {len(self.extra_in_loki)}")

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
                'mismatches': len(self.mismatches),
                'missing_in_loki': len(self.missing_in_loki),
                'extra_in_loki': len(self.extra_in_loki)
            },
            'mismatches': self.mismatches,
            'missing_in_loki': self.missing_in_loki,
            'extra_in_loki': self.extra_in_loki,
            'errors': self.errors,
            'warnings': self.warnings
        }


def main():
    parser = argparse.ArgumentParser(
        description='Cross-validate file logs against Loki backend logs',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__
    )
    parser.add_argument(
        'file_log',
        type=Path,
        help='Path to NDJSON log file (e.g., logs/dev.log)'
    )
    parser.add_argument(
        'loki_response',
        type=Path,
        help='Path to Loki response JSON file (use "-" for stdin)'
    )
    parser.add_argument(
        '--json',
        action='store_true',
        help='Output JSON format for automation'
    )

    args = parser.parse_args()

    # Validate file exists (unless stdin)
    if str(args.loki_response) != '-' and not args.loki_response.exists():
        print(f"ERROR: Loki response file not found: {args.loki_response}", file=sys.stderr)
        sys.exit(2)

    if not args.file_log.exists():
        print(f"ERROR: Log file not found: {args.file_log}", file=sys.stderr)
        sys.exit(2)

    # Run validation
    validator = LogConsistencyValidator(json_mode=args.json)
    file_logs = validator.read_file_logs(args.file_log)
    loki_logs = validator.read_loki_logs(args.loki_response)

    if not file_logs:
        print("ERROR: No valid logs found in file", file=sys.stderr)
        sys.exit(2)

    if not loki_logs:
        print("ERROR: No valid logs found in Loki response", file=sys.stderr)
        sys.exit(2)

    all_match = validator.compare_logs(file_logs, loki_logs)

    # Print results
    validator.print_summary(all_match)

    if args.json:
        print(json.dumps(validator.get_json_output(all_match), indent=2))

    sys.exit(0 if all_match else 1)


if __name__ == '__main__':
    main()
