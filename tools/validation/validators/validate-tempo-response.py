#!/usr/bin/env python3
"""
Sovdev Logger - Tempo Response Validator

Validates Tempo trace search responses against JSON Schema to ensure traces
are properly stored and retrievable.

Uses: tools/validation/schemas/tempo-response-schema.json

Usage:
    # Validate Tempo response (human-readable output)
    ./query-tempo.sh sovdev-test-app --json > /tmp/tempo.json
    python3 validate-tempo-response.py /tmp/tempo.json

    # JSON output for automation
    python3 validate-tempo-response.py /tmp/tempo.json --json

    # Pipe directly from query
    ./query-tempo.sh sovdev-test-app --json | python3 validate-tempo-response.py -

Exit Codes:
    0 - Validation passed
    1 - Validation failed
    2 - Usage error
"""

import argparse
import json
import sys
from pathlib import Path
from typing import List, Dict, Any, Set

try:
    import jsonschema
    from jsonschema import Draft7Validator
except ImportError:
    print("ERROR: jsonschema library not found", file=sys.stderr)
    print("Install with: pip install jsonschema", file=sys.stderr)
    sys.exit(1)


# ANSI color codes
class Colors:
    RED = '\033[0;31m'
    GREEN = '\033[0;32m'
    YELLOW = '\033[1;33m'
    BLUE = '\033[0;34m'
    NC = '\033[0m'


class TempoResponseValidator:
    """Validates Tempo API responses using JSON Schema"""

    def __init__(self, schema_path: Path, json_mode: bool = False):
        """
        Initialize validator with JSON Schema

        Args:
            schema_path: Path to tempo-response-schema.json
            json_mode: If True, output JSON instead of human-readable text
        """
        self.schema = json.loads(schema_path.read_text())
        self.validator = Draft7Validator(self.schema)
        self.json_mode = json_mode
        self.errors = []
        self.warnings = []
        self.stats = {
            'total_traces': 0,
            'unique_services': set(),
            'trace_ids': set(),
        }

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

    def validate_response(self, tempo_data: Dict[str, Any]) -> bool:
        """Validate Tempo API response using JSON Schema"""

        # Step 1: Validate response structure against schema
        if not self._validate_schema(tempo_data):
            return False

        # Step 2: Validate trace entries
        if not self._validate_traces(tempo_data):
            return False

        # Success!
        self._print_summary()
        return True

    def _validate_schema(self, tempo_data: Dict[str, Any]) -> bool:
        """Validate response against JSON Schema"""
        self.print_info("Validating Tempo response structure against schema...")

        # Validate using jsonschema
        errors = list(self.validator.iter_errors(tempo_data))

        if errors:
            self.print_error(f"Schema validation failed with {len(errors)} error(s)")
            for error in errors[:5]:  # Show first 5 errors
                error_path = " -> ".join(str(p) for p in error.path) if error.path else "root"
                self.print_error(f"  {error_path}: {error.message}")
            if len(errors) > 5:
                self.print_warning(f"  ... and {len(errors) - 5} more errors")
            return False

        # Check if we have results
        traces = tempo_data.get('traces', [])
        if len(traces) == 0:
            self.print_warning("No traces found in Tempo response")
            return True  # Empty is valid

        self.stats['total_traces'] = len(traces)
        self.print_success(f"Schema validation passed - found {len(traces)} trace(s)")
        return True

    def _validate_traces(self, tempo_data: Dict[str, Any]) -> bool:
        """
        Validate trace entries from Tempo response

        Checks required trace-level fields:
        - traceID: OpenTelemetry trace identifier (16-32 char hex)
        - rootServiceName: Name of the root service
        - startTimeUnixNano: Trace start time in nanoseconds
        """
        traces = tempo_data.get('traces', [])
        if not traces:
            return True  # No traces to validate

        self.print_info("Validating trace entries (required fields)...")

        all_valid = True

        # Required fields that must be present in each trace
        required_fields = [
            'traceID',           # Trace identifier
            'rootServiceName',   # Root service name
            'startTimeUnixNano', # Trace start timestamp
        ]

        for trace_idx, trace in enumerate(traces):
            # Check for required fields
            missing_fields = []
            for field in required_fields:
                if field not in trace or not trace.get(field):
                    missing_fields.append(field)

            if missing_fields:
                self.print_error(f"Trace {trace_idx}: Missing required fields: {missing_fields}")
                self.print_error(f"    Trace has: {list(trace.keys())}")
                all_valid = False
                continue

            trace_id = trace.get('traceID')
            root_service = trace.get('rootServiceName')
            start_time = trace.get('startTimeUnixNano')

            # Validate trace_id format (16-32 char hex)
            if trace_id and not self._is_valid_trace_id(trace_id):
                self.print_error(f"Trace {trace_idx}: Invalid traceID format: {trace_id}")
                self.print_error(f"    Expected: 16-32 character hex string")
                all_valid = False

            # Validate startTimeUnixNano format (19-digit nanosecond timestamp)
            if start_time and not self._is_valid_timestamp(start_time):
                self.print_error(f"Trace {trace_idx}: Invalid startTimeUnixNano format: {start_time}")
                self.print_error(f"    Expected: 19-digit nanosecond timestamp (e.g., 1234567890123456789)")
                all_valid = False

            # Track stats
            if trace_id:
                self.stats['trace_ids'].add(trace_id)
            if root_service:
                self.stats['unique_services'].add(root_service)

        if all_valid:
            self.print_success(f"Trace validation passed - {len(traces)} traces")

        return all_valid

    def _is_valid_trace_id(self, trace_id: str) -> bool:
        """Check if trace_id is valid 16-32 char hex format (Tempo may omit leading zeros)"""
        if not trace_id or len(trace_id) < 16 or len(trace_id) > 32:
            return False
        try:
            int(trace_id, 16)  # Check if it's valid hex
            return True
        except ValueError:
            return False

    def _is_valid_timestamp(self, timestamp: str) -> bool:
        """Check if timestamp is valid 19-digit nanosecond Unix timestamp"""
        if not timestamp or not isinstance(timestamp, str):
            return False
        if len(timestamp) != 19:
            return False
        try:
            int(timestamp)  # Check if it's a valid number
            return True
        except ValueError:
            return False

    def _print_summary(self):
        """Print validation summary"""
        if not self.json_mode:
            print()
            self.print_success("TEMPO RESPONSE VALIDATION PASSED")
            print()
            print(f"Total traces: {self.stats['total_traces']}")
            print(f"Unique trace IDs: {len(self.stats['trace_ids'])}")
            print(f"Services: {', '.join(sorted(self.stats['unique_services']))}")
            if self.warnings:
                print(f"\nWarnings: {len(self.warnings)}")
                for warning in self.warnings:
                    print(f"  - {warning}")

    def get_json_output(self, passed: bool) -> Dict[str, Any]:
        """Generate JSON output for automation"""
        return {
            'validation': 'passed' if passed else 'failed',
            'errors': self.errors,
            'warnings': self.warnings,
            'stats': {
                'total_traces': self.stats['total_traces'],
                'unique_trace_ids': len(self.stats['trace_ids']),
                'unique_services': list(self.stats['unique_services']),
            }
        }


def main():
    parser = argparse.ArgumentParser(
        description='Validate Tempo trace search response against JSON Schema',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__
    )
    parser.add_argument(
        'response_file',
        help='Path to Tempo response JSON file (use "-" for stdin)'
    )
    parser.add_argument(
        '--json',
        action='store_true',
        help='Output JSON format for automation'
    )
    parser.add_argument(
        '--schema',
        type=Path,
        help='Path to tempo-response-schema.json (default: auto-detect)'
    )

    args = parser.parse_args()

    # Locate schema file
    if args.schema:
        schema_path = args.schema
    else:
        # Auto-detect: look in ../schemas/ relative to this script
        script_dir = Path(__file__).parent
        schema_path = script_dir.parent / 'schemas' / 'tempo-response-schema.json'

    if not schema_path.exists():
        print(f"ERROR: Schema file not found: {schema_path}", file=sys.stderr)
        print("Specify schema location with --schema option", file=sys.stderr)
        sys.exit(2)

    # Read Tempo response
    try:
        if args.response_file == '-':
            tempo_data = json.load(sys.stdin)
        else:
            tempo_data = json.loads(Path(args.response_file).read_text())
    except FileNotFoundError:
        print(f"ERROR: File not found: {args.response_file}", file=sys.stderr)
        sys.exit(2)
    except json.JSONDecodeError as e:
        print(f"ERROR: Invalid JSON: {e}", file=sys.stderr)
        sys.exit(2)

    # Validate
    validator = TempoResponseValidator(schema_path=schema_path, json_mode=args.json)
    passed = validator.validate_response(tempo_data)

    # Output results
    if args.json:
        print(json.dumps(validator.get_json_output(passed), indent=2))

    sys.exit(0 if passed else 1)


if __name__ == '__main__':
    main()
