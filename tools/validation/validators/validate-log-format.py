#!/usr/bin/env python3
"""
Sovdev Logger - Log Format Validator

Validates log files against the sovdev-logger specification.
Checks both JSON Schema compliance and custom business rules.

Usage:
    # Human-readable output
    python3 validate-log-format.py /path/to/dev.log

    # JSON output for automation
    python3 validate-log-format.py /path/to/dev.log --json

    # Validate error log
    python3 validate-log-format.py /path/to/error.log --error-log
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


class LogValidator:
    def __init__(self, schema_path: Path, json_mode: bool = False, is_error_log: bool = False):
        self.schema = json.loads(schema_path.read_text())
        self.validator = Draft7Validator(self.schema)
        self.json_mode = json_mode
        self.is_error_log = is_error_log
        self.errors = []
        self.warnings = []
        self.stats = {}

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

    def validate_file(self, log_file: Path) -> bool:
        """Validate log file and return True if valid"""
        if not log_file.exists():
            self.print_error(f"Log file not found: {log_file}")
            return False

        # Read log entries (NDJSON format)
        try:
            log_content = log_file.read_text()
            if not log_content.strip():
                self.print_warning("Log file is empty")
                return True  # Empty is valid

            logs = [json.loads(line) for line in log_content.splitlines() if line.strip()]
        except json.JSONDecodeError as e:
            self.print_error(f"Invalid JSON in log file: {e}")
            return False

        if not logs:
            self.print_warning("No log entries found")
            return True

        self.print_info(f"Validating {len(logs)} log entries...")

        # Step 1: Schema validation
        schema_valid = self._validate_schema(logs)

        # Step 2: Custom validations
        custom_valid = self._validate_custom_rules(logs)

        # Step 3: Error log specific validation
        if self.is_error_log:
            error_log_valid = self._validate_error_log(logs)
        else:
            error_log_valid = True

        # Collect stats
        self.stats = {
            "total_logs": len(logs),
            "severities": self._count_severities(logs),
            "log_types": self._count_log_types(logs),
            "unique_session_ids": len(self._extract_session_ids(logs)),
            "unique_trace_ids": len(self._extract_trace_ids(logs)),
            "unique_span_ids": len(self._extract_span_ids(logs))
        }

        return schema_valid and custom_valid and error_log_valid

    def _validate_schema(self, logs: List[Dict[str, Any]]) -> bool:
        """Validate each log entry against JSON Schema"""
        valid = True

        for i, log in enumerate(logs, start=1):
            errors = list(self.validator.iter_errors(log))
            if errors:
                valid = False
                for error in errors:
                    field_path = ".".join(str(p) for p in error.path) if error.path else "root"
                    self.print_error(f"Line {i}, field '{field_path}': {error.message}")

        if valid:
            self.print_success(f"All {len(logs)} log entries match schema")

        return valid

    def _validate_custom_rules(self, logs: List[Dict[str, Any]]) -> bool:
        """Validate custom business rules"""
        valid = True

        # Rule 1: Trace ID consistency (each trace should exist)
        trace_ids = self._extract_trace_ids(logs)
        if trace_ids:
            self.print_success(f"Found {len(trace_ids)} unique trace IDs")
        else:
            self.print_warning("No trace IDs found in logs")

        # Rule 1b: Span ID presence (logs with active spans should have span_id)
        span_ids = self._extract_span_ids(logs)
        if span_ids:
            self.print_success(f"Found {len(span_ids)} unique span IDs")
        else:
            self.print_warning("No span IDs found in logs")

        # Rule 1c: Log level validation (must be valid lowercase level)
        allowed_levels = ["trace", "debug", "info", "warn", "error", "fatal"]
        for i, log in enumerate(logs, start=1):
            level = log.get("level", "")
            if level and level not in allowed_levels:
                valid = False
                self.print_error(
                    f"Line {i}: Invalid log level '{level}' (must be one of {allowed_levels})"
                )
                self.print_error(
                    f"         Common issue: enum conversion - use enum.value not str(enum)"
                )

        # Rule 2: Exception fields for error logs (snake_case)
        for i, log in enumerate(logs, start=1):
            level = log.get("level", log.get("severity", "")).lower()
            if level in ["error", "fatal"]:
                # Check for snake_case exception fields (project standard)
                has_exception_type = "exception_type" in log
                has_exception_msg = "exception_message" in log
                has_exception_stack = "exception_stacktrace" in log

                if not has_exception_type:
                    self.print_warning(f"Line {i}: ERROR log missing exception_type field")

                if not has_exception_msg:
                    self.print_warning(f"Line {i}: ERROR log missing exception_message field")

                if not has_exception_stack:
                    self.print_warning(f"Line {i}: ERROR log missing exception_stacktrace field")

                # Note: exception_type can be any exception class name (Error, TypeError, etc.)
                # No validation of specific exception type value needed

        # Rule 3: Stack trace length limit
        for i, log in enumerate(logs, start=1):
            stack = log.get("exception_stacktrace")
            if stack:
                stack_len = len(stack)
                if stack_len > 350:
                    valid = False
                    self.print_error(f"Line {i}: Stack trace is {stack_len} chars (max 350)")

        return valid

    def _validate_error_log(self, logs: List[Dict[str, Any]]) -> bool:
        """Validate error.log specific rules"""
        valid = True

        # Rule: error.log must only contain ERROR severity logs
        for i, log in enumerate(logs, start=1):
            if log.get("severity") != "ERROR":
                valid = False
                self.print_error(
                    f"Line {i}: error.log contains non-ERROR log (severity: {log.get('severity')})"
                )

        if valid:
            self.print_success("error.log contains only ERROR logs")

        return valid

    def _extract_session_ids(self, logs: List[Dict[str, Any]]) -> Set[str]:
        """Extract unique session_ids from logs"""
        return {log.get("session_id") for log in logs if "session_id" in log}

    def _extract_trace_ids(self, logs: List[Dict[str, Any]]) -> Set[str]:
        """Extract unique trace_ids from logs"""
        return {log.get("trace_id") for log in logs if "trace_id" in log}

    def _extract_span_ids(self, logs: List[Dict[str, Any]]) -> Set[str]:
        """Extract unique span_ids from logs"""
        return {log.get("span_id") for log in logs if "span_id" in log}

    def _count_severities(self, logs: List[Dict[str, Any]]) -> Dict[str, int]:
        """Count logs by severity"""
        counts = {}
        for log in logs:
            severity = log.get("severity", "UNKNOWN")
            counts[severity] = counts.get(severity, 0) + 1
        return counts

    def _count_log_types(self, logs: List[Dict[str, Any]]) -> Dict[str, int]:
        """Count logs by log_type"""
        counts = {}
        for log in logs:
            log_type = log.get("log_type", "unknown")
            counts[log_type] = counts.get(log_type, 0) + 1
        return counts

    def output_result(self, valid: bool):
        """Output final result"""
        if self.json_mode:
            result = {
                "valid": valid,
                "errors": self.errors,
                "warnings": self.warnings,
                "stats": self.stats
            }
            print(json.dumps(result, indent=2))
        else:
            print()
            if valid:
                print(f"{Colors.GREEN}✅ VALIDATION PASSED{Colors.NC}")
            else:
                print(f"{Colors.RED}❌ VALIDATION FAILED{Colors.NC}")

            print()
            print(f"Total logs: {self.stats.get('total_logs', 0)}")
            print(f"Severities: {self.stats.get('severities', {})}")
            print(f"Log types: {self.stats.get('log_types', {})}")
            print(f"Errors: {len(self.errors)}")
            print(f"Warnings: {len(self.warnings)}")


def main():
    parser = argparse.ArgumentParser(
        description="Validate sovdev-logger log file format",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Validate main log file
  python3 validate-log-format.py /workspace/python/test/.../logs/dev.log

  # Validate error log file
  python3 validate-log-format.py /workspace/python/test/.../logs/error.log --error-log

  # JSON output for automation
  python3 validate-log-format.py /workspace/python/test/.../logs/dev.log --json
        """
    )
    parser.add_argument("log_file", type=Path, help="Path to log file to validate")
    parser.add_argument("--json", action="store_true", help="Output JSON format for automation")
    parser.add_argument("--error-log", action="store_true", help="Validate as error.log (only ERROR logs)")
    parser.add_argument(
        "--schema",
        type=Path,
        default=Path(__file__).parent.parent / "schemas" / "log-entry-schema.json",
        help="Path to JSON Schema file (default: ../schemas/log-entry-schema.json)"
    )

    args = parser.parse_args()

    if not args.schema.exists():
        print(f"ERROR: Schema file not found: {args.schema}", file=sys.stderr)
        sys.exit(1)

    validator = LogValidator(args.schema, json_mode=args.json, is_error_log=args.error_log)

    if not args.json:
        print(f"{Colors.BLUE}🔍 Validating log file: {args.log_file}{Colors.NC}")
        if args.error_log:
            print(f"{Colors.BLUE}   Mode: error.log (ERROR logs only){Colors.NC}")
        print()

    valid = validator.validate_file(args.log_file)
    validator.output_result(valid)

    sys.exit(0 if valid else 1)


if __name__ == "__main__":
    main()
