#!/usr/bin/env python3
"""
Sovdev Logger - Prometheus Response Validator

Validates Prometheus query responses against JSON Schema to ensure metrics are properly
stored with correct label names (snake_case only) and all required labels.

Uses: tools/validation/schemas/prometheus-response-schema.json

Usage:
    # Validate Prometheus response (human-readable output)
    ./query-prometheus.sh sovdev-test-app --json > /tmp/prometheus.json
    python3 validate-prometheus-response.py /tmp/prometheus.json

    # JSON output for automation
    python3 validate-prometheus-response.py /tmp/prometheus.json --json

    # Pipe directly from query
    ./query-prometheus.sh sovdev-test-app --json | python3 validate-prometheus-response.py -

Exit Codes:
    0 - Validation passed
    1 - Validation failed
    2 - Usage error
"""

import argparse
import json
import sys
from pathlib import Path
from typing import Dict, Any, Set

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


class PrometheusResponseValidator:
    """Validates Prometheus API responses using JSON Schema"""

    def __init__(self, schema_path: Path, json_mode: bool = False):
        """
        Initialize validator with JSON Schema

        Args:
            schema_path: Path to prometheus-response-schema.json
            json_mode: If True, output JSON instead of human-readable text
        """
        self.schema = json.loads(schema_path.read_text())
        self.validator = Draft7Validator(self.schema)
        self.json_mode = json_mode
        self.errors = []
        self.warnings = []
        self.stats = {
            'total_series': 0,
            'total_operations': 0,
            'unique_services': set(),
            'log_types': {},
            'log_levels': {},
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

    def validate_response(self, prometheus_data: Dict[str, Any]) -> bool:
        """Validate Prometheus API response using JSON Schema"""

        # Step 1: Validate response structure against schema
        if not self._validate_schema(prometheus_data):
            return False

        # Step 2: Validate metric labels for snake_case compliance
        if not self._validate_metric_labels(prometheus_data):
            return False

        # Success!
        self._print_summary()
        return True

    def _validate_schema(self, prometheus_data: Dict[str, Any]) -> bool:
        """Validate response against JSON Schema"""
        self.print_info("Validating Prometheus response structure against schema...")

        # Validate using jsonschema
        errors = list(self.validator.iter_errors(prometheus_data))

        if errors:
            self.print_error(f"Schema validation failed with {len(errors)} error(s)")
            for error in errors[:5]:  # Show first 5 errors
                error_path = " -> ".join(str(p) for p in error.path) if error.path else "root"
                self.print_error(f"  {error_path}: {error.message}")
            if len(errors) > 5:
                self.print_warning(f"  ... and {len(errors) - 5} more errors")
            return False

        # Check if we have results
        results = prometheus_data.get('data', {}).get('result', [])
        if len(results) == 0:
            self.print_warning("No metrics found in Prometheus response")
            return True  # Empty is valid

        self.stats['total_series'] = len(results)
        self.print_success(f"Schema validation passed - found {len(results)} metric series")
        return True

    def _validate_metric_labels(self, prometheus_data: Dict[str, Any]) -> bool:
        """
        Validate metric labels for snake_case compliance

        In Prometheus metrics:
        - Labels should use snake_case (service_name, log_type, etc.)
        - No camelCase labels should exist
        """
        results = prometheus_data.get('data', {}).get('result', [])
        if not results:
            return True  # No metrics to validate

        self.print_info("Validating metric labels (must be snake_case)...")

        all_valid = True
        total_operations = 0

        # Required labels that should be in Prometheus metrics
        # These are essential for querying and filtering metrics
        required_labels = [
            'service_name',  # Service identifier (or peer_service for external calls)
            'log_type',      # Type of operation (transaction, job.status, job.progress)
            'log_level',     # Log level (info, error, etc.)
        ]

        # List of camelCase labels that should NOT exist
        camel_case_labels = [
            'serviceName', 'logType', 'logLevel', 'peerService',
            'serviceVersion', 'functionName', 'traceId', 'eventId'
        ]

        for series_idx, series_data in enumerate(results):
            metric_labels = series_data.get('metric', {})
            value = series_data.get('value', [])

            # Extract metric value
            if len(value) >= 2:
                try:
                    metric_value = float(value[1])
                    total_operations += metric_value
                except (ValueError, TypeError):
                    self.print_warning(f"Series {series_idx}: Invalid metric value: {value[1]}")

            # Check for required labels
            missing_labels = []
            for label in required_labels:
                if label not in metric_labels:
                    # Special case: service_name OR peer_service can satisfy service requirement
                    if label == 'service_name' and 'peer_service' in metric_labels:
                        continue  # peer_service is acceptable instead of service_name
                    missing_labels.append(label)

            if missing_labels:
                self.print_error(f"Series {series_idx}: Missing required labels: {missing_labels}")
                self.print_error(f"    Metric has: {list(metric_labels.keys())}")
                all_valid = False

            # Check for camelCase labels (should not exist)
            found_camel = [label for label in camel_case_labels if label in metric_labels]
            if found_camel:
                self.print_error(f"Series {series_idx}: Found camelCase labels: {found_camel}")
                self.print_error(f"    All labels must use snake_case")
                all_valid = False

            # Track stats
            if 'service_name' in metric_labels:
                self.stats['unique_services'].add(metric_labels['service_name'])
            if 'log_type' in metric_labels:
                log_type = metric_labels['log_type']
                self.stats['log_types'][log_type] = self.stats['log_types'].get(log_type, 0) + 1
            if 'log_level' in metric_labels:
                log_level = metric_labels['log_level']
                self.stats['log_levels'][log_level] = self.stats['log_levels'].get(log_level, 0) + 1

        self.stats['total_operations'] = int(total_operations)

        if all_valid:
            self.print_success(f"Metric label validation passed - {len(results)} series, {int(total_operations)} total operations")

        return all_valid

    def _print_summary(self):
        """Print validation summary"""
        if not self.json_mode:
            print()
            self.print_success("PROMETHEUS RESPONSE VALIDATION PASSED")
            print()
            print(f"Total metric series: {self.stats['total_series']}")
            print(f"Total operations: {self.stats['total_operations']}")
            print(f"Services: {', '.join(sorted(self.stats['unique_services']))}")
            if self.stats['log_types']:
                print(f"Log types: {dict(self.stats['log_types'])}")
            if self.stats['log_levels']:
                print(f"Log levels: {dict(self.stats['log_levels'])}")
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
                'total_series': self.stats['total_series'],
                'total_operations': self.stats['total_operations'],
                'unique_services': list(self.stats['unique_services']),
                'log_types': self.stats['log_types'],
                'log_levels': self.stats['log_levels'],
            }
        }


def main():
    parser = argparse.ArgumentParser(
        description='Validate Prometheus query response against JSON Schema',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__
    )
    parser.add_argument(
        'response_file',
        help='Path to Prometheus response JSON file (use "-" for stdin)'
    )
    parser.add_argument(
        '--json',
        action='store_true',
        help='Output JSON format for automation'
    )
    parser.add_argument(
        '--schema',
        type=Path,
        help='Path to prometheus-response-schema.json (default: auto-detect)'
    )

    args = parser.parse_args()

    # Locate schema file
    if args.schema:
        schema_path = args.schema
    else:
        # Auto-detect: look in ../schemas/ relative to this script
        script_dir = Path(__file__).parent
        schema_path = script_dir.parent / 'schemas' / 'prometheus-response-schema.json'

    if not schema_path.exists():
        print(f"ERROR: Schema file not found: {schema_path}", file=sys.stderr)
        print("Specify schema location with --schema option", file=sys.stderr)
        sys.exit(2)

    # Read Prometheus response
    try:
        if args.response_file == '-':
            prometheus_data = json.load(sys.stdin)
        else:
            prometheus_data = json.loads(Path(args.response_file).read_text())
    except FileNotFoundError:
        print(f"ERROR: File not found: {args.response_file}", file=sys.stderr)
        sys.exit(2)
    except json.JSONDecodeError as e:
        print(f"ERROR: Invalid JSON: {e}", file=sys.stderr)
        sys.exit(2)

    # Validate
    validator = PrometheusResponseValidator(schema_path=schema_path, json_mode=args.json)
    passed = validator.validate_response(prometheus_data)

    # Output results
    if args.json:
        print(json.dumps(validator.get_json_output(passed), indent=2))

    sys.exit(0 if passed else 1)


if __name__ == '__main__':
    main()
