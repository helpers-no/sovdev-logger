#!/usr/bin/env python3
"""
Sovdev Logger - Metrics Consistency Validator

Cross-validates that log entries in files match metrics in Prometheus backend.
Ensures data consistency between file logging and OTLP metric export to Prometheus.

This validator counts log entries by (log_type, log_level, peer_service) and compares
with Prometheus metric values to ensure all operations are properly tracked.

Usage:
    # Compare file logs with Prometheus response (human-readable output)
    ./query-prometheus.sh sovdev-test-app --json > /tmp/prometheus.json
    python3 validate-metrics-consistency.py ./logs/dev.log /tmp/prometheus.json

    # JSON output for automation
    python3 validate-metrics-consistency.py ./logs/dev.log /tmp/prometheus.json --json

    # Pipe Prometheus response directly
    python3 validate-metrics-consistency.py ./logs/dev.log <(./query-prometheus.sh sovdev-test-app --json)

Exit Codes:
    0 - All metrics match (consistency verified)
    1 - Mismatches found (counts don't match between file and Prometheus)
    2 - Usage error (missing files, invalid JSON, etc.)

Comparison Strategy:
    - Groups log entries by (log_type, log_level, peer_service)
    - Counts operations in each group from file
    - Compares with Prometheus metric values for same groups
    - Reports matches, mismatches, missing, and extra metrics
"""

import argparse
import json
import sys
from pathlib import Path
from typing import Dict, Tuple, Any

# ANSI color codes
class Colors:
    RED = '\033[0;31m'
    GREEN = '\033[0;32m'
    YELLOW = '\033[1;33m'
    BLUE = '\033[0;34m'
    NC = '\033[0m'


class MetricsConsistencyValidator:
    """Cross-validates file logs against Prometheus metrics"""

    def __init__(self, json_mode: bool = False):
        """
        Initialize validator

        Args:
            json_mode: If True, output JSON instead of human-readable text
        """
        self.json_mode = json_mode
        self.matches = []
        self.mismatches = []
        self.missing_in_prometheus = []
        self.extra_in_prometheus = []
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

    def count_log_operations(self, file_path: Path) -> Dict[Tuple[str, str, str], int]:
        """
        Count log operations by (log_type, log_level, peer_service)

        Args:
            file_path: Path to NDJSON log file

        Returns:
            Dict mapping (log_type, log_level, peer_service) -> count
        """
        self.print_info(f"Counting operations from file: {file_path}...")
        counts = {}
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
                        log_type = log_entry.get('log_type', 'unknown')
                        log_level = log_entry.get('level', 'unknown').lower()
                        peer_service = log_entry.get('peer_service', 'unknown')

                        key = (log_type, log_level, peer_service)
                        counts[key] = counts.get(key, 0) + 1

                    except json.JSONDecodeError as e:
                        self.print_warning(f"Line {line_num}: Invalid JSON - {e}")

        except FileNotFoundError:
            self.print_error(f"File not found: {file_path}")
            return {}

        self.print_success(f"Counted {sum(counts.values())} operations in {len(counts)} groups from file")
        return counts

    def read_prometheus_metrics(self, prometheus_path: Path) -> Dict[Tuple[str, str, str], int]:
        """
        Read Prometheus metric values by (log_type, log_level, peer_service)

        Args:
            prometheus_path: Path to Prometheus response JSON file

        Returns:
            Dict mapping (log_type, log_level, peer_service) -> metric_value
        """
        self.print_info(f"Reading Prometheus metrics from {prometheus_path}...")
        metrics = {}

        try:
            if str(prometheus_path) == '-':
                prom_data = json.load(sys.stdin)
            else:
                prom_data = json.loads(prometheus_path.read_text())
        except json.JSONDecodeError as e:
            self.print_error(f"Invalid Prometheus JSON: {e}")
            return {}
        except FileNotFoundError:
            self.print_error(f"File not found: {prometheus_path}")
            return {}

        # Extract metrics from Prometheus response
        results = prom_data.get('data', {}).get('result', [])

        for series in results:
            metric_labels = series.get('metric', {})
            value = series.get('value', [])

            # Extract labels
            log_type = metric_labels.get('log_type', 'unknown')
            log_level = metric_labels.get('log_level', 'unknown')
            peer_service = metric_labels.get('peer_service', 'unknown')

            # Extract metric value
            if len(value) >= 2:
                try:
                    metric_value = int(float(value[1]))
                except (ValueError, TypeError):
                    self.print_warning(f"Invalid metric value: {value[1]}")
                    continue
            else:
                self.print_warning(f"Metric value missing for {log_type}/{log_level}/{peer_service}")
                continue

            key = (log_type, log_level, peer_service)
            # Note: Prometheus may have multiple series with same labels (different timestamps)
            # We sum them here
            metrics[key] = metrics.get(key, 0) + metric_value

        self.print_success(f"Read {sum(metrics.values())} operations in {len(metrics)} metric series from Prometheus")
        return metrics

    def compare_metrics(self, file_counts: Dict[Tuple[str, str, str], int],
                       prom_metrics: Dict[Tuple[str, str, str], int]) -> bool:
        """
        Compare file operation counts with Prometheus metrics

        Args:
            file_counts: Counts from file indexed by (log_type, log_level, peer_service)
            prom_metrics: Metrics from Prometheus indexed by (log_type, log_level, peer_service)

        Returns:
            True if all counts match, False otherwise
        """
        self.print_info("Comparing file operation counts with Prometheus metrics...")

        file_keys = set(file_counts.keys())
        prom_keys = set(prom_metrics.keys())

        # Find matches, mismatches, and missing entries
        common_keys = file_keys & prom_keys
        missing_keys = file_keys - prom_keys
        extra_keys = prom_keys - file_keys

        # Compare common entries
        for key in common_keys:
            file_count = file_counts[key]
            prom_count = prom_metrics[key]

            if file_count == prom_count:
                self.matches.append({
                    'log_type': key[0],
                    'log_level': key[1],
                    'peer_service': key[2],
                    'count': file_count
                })
            else:
                self.mismatches.append({
                    'log_type': key[0],
                    'log_level': key[1],
                    'peer_service': key[2],
                    'file_count': file_count,
                    'prometheus_count': prom_count,
                    'difference': prom_count - file_count
                })

        # Record missing metrics
        for key in missing_keys:
            self.missing_in_prometheus.append({
                'log_type': key[0],
                'log_level': key[1],
                'peer_service': key[2],
                'file_count': file_counts[key]
            })

        # Record extra metrics
        for key in extra_keys:
            self.extra_in_prometheus.append({
                'log_type': key[0],
                'log_level': key[1],
                'peer_service': key[2],
                'prometheus_count': prom_metrics[key]
            })

        # Print results
        if self.matches:
            self.print_success(f"{len(self.matches)} metric groups match perfectly")
            if not self.json_mode:
                for m in self.matches[:3]:
                    print(f"  {m['log_type']}/{m['log_level']}/{m['peer_service']}: {m['count']} operations")
                if len(self.matches) > 3:
                    print(f"  ... and {len(self.matches) - 3} more matches")

        if self.mismatches:
            self.print_error(f"{len(self.mismatches)} metric groups have count mismatches")
            if not self.json_mode:
                for m in self.mismatches:
                    print(f"  {m['log_type']}/{m['log_level']}/{m['peer_service']}:")
                    print(f"    File: {m['file_count']}, Prometheus: {m['prometheus_count']} (diff: {m['difference']:+d})")

        if self.missing_in_prometheus:
            self.print_error(f"{len(self.missing_in_prometheus)} metric groups missing in Prometheus")
            if not self.json_mode:
                for m in self.missing_in_prometheus:
                    print(f"  {m['log_type']}/{m['log_level']}/{m['peer_service']}: {m['file_count']} operations")

        if self.extra_in_prometheus:
            self.print_warning(f"{len(self.extra_in_prometheus)} extra metric groups in Prometheus (not in file)")
            if not self.json_mode:
                for e in self.extra_in_prometheus[:3]:
                    print(f"  {e['log_type']}/{e['log_level']}/{e['peer_service']}: {e['prometheus_count']} operations")
                if len(self.extra_in_prometheus) > 3:
                    print(f"  ... and {len(self.extra_in_prometheus) - 3} more extra")

        # Validation passes if:
        # 1. No mismatches (all common groups have matching counts)
        # 2. No missing in Prometheus (all file groups are in Prometheus)
        # Note: Extra groups in Prometheus are OK (old metrics from previous runs)
        all_match = (len(self.mismatches) == 0 and
                     len(self.missing_in_prometheus) == 0)

        return all_match

    def print_summary(self, all_match: bool):
        """Print validation summary"""
        if not self.json_mode:
            print()
            if all_match:
                self.print_success("METRICS CONSISTENCY VALIDATION PASSED")
            else:
                self.print_error("METRICS CONSISTENCY VALIDATION FAILED")
            print()
            print(f"Total matches: {len(self.matches)}")
            print(f"Total mismatches: {len(self.mismatches)}")
            print(f"Missing in Prometheus: {len(self.missing_in_prometheus)}")
            print(f"Extra in Prometheus: {len(self.extra_in_prometheus)}")

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
                'missing_in_prometheus': len(self.missing_in_prometheus),
                'extra_in_prometheus': len(self.extra_in_prometheus)
            },
            'matches': self.matches,
            'mismatches': self.mismatches,
            'missing_in_prometheus': self.missing_in_prometheus,
            'extra_in_prometheus': self.extra_in_prometheus,
            'errors': self.errors,
            'warnings': self.warnings
        }


def main():
    parser = argparse.ArgumentParser(
        description='Cross-validate file logs against Prometheus metrics',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__
    )
    parser.add_argument(
        'file_log',
        type=Path,
        help='Path to NDJSON log file (e.g., logs/dev.log)'
    )
    parser.add_argument(
        'prometheus_response',
        type=Path,
        help='Path to Prometheus response JSON file (use "-" for stdin)'
    )
    parser.add_argument(
        '--json',
        action='store_true',
        help='Output JSON format for automation'
    )

    args = parser.parse_args()

    # Validate file exists (unless stdin)
    if str(args.prometheus_response) != '-' and not args.prometheus_response.exists():
        print(f"ERROR: Prometheus response file not found: {args.prometheus_response}", file=sys.stderr)
        sys.exit(2)

    if not args.file_log.exists():
        print(f"ERROR: Log file not found: {args.file_log}", file=sys.stderr)
        sys.exit(2)

    # Run validation
    validator = MetricsConsistencyValidator(json_mode=args.json)
    file_counts = validator.count_log_operations(args.file_log)
    prom_metrics = validator.read_prometheus_metrics(args.prometheus_response)

    if not file_counts:
        print("ERROR: No valid log entries found in file", file=sys.stderr)
        sys.exit(2)

    if not prom_metrics:
        print("ERROR: No valid metrics found in Prometheus response", file=sys.stderr)
        sys.exit(2)

    all_match = validator.compare_metrics(file_counts, prom_metrics)

    # Print results
    validator.print_summary(all_match)

    if args.json:
        print(json.dumps(validator.get_json_output(all_match), indent=2))

    sys.exit(0 if all_match else 1)


if __name__ == '__main__':
    main()
