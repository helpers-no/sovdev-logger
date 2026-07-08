#!/usr/bin/env python3
"""
Sovdev Logger - Master-Comparison Log Diff

Compares a candidate language's file log against TypeScript's (the master
implementation's) file log for the same fixed E2E scenario, field by field.
TypeScript's output is always the live answer key -- there is no stored
"golden" fixture to go stale.

See: website/docs/ai-developer/plans/active/PLAN-001-master-comparison-mode.md

Usage:
    # Human-readable output
    python3 compare-log-files.py <master-log> <candidate-log>

    # JSON output for automation
    python3 compare-log-files.py <master-log> <candidate-log> --json
"""

import argparse
import json
import sys
from pathlib import Path
from typing import Any, Dict, List, Tuple


# ANSI color codes (matches validate-log-format.py)
class Colors:
    RED = '\033[0;31m'
    GREEN = '\033[0;32m'
    YELLOW = '\033[1;33m'
    BLUE = '\033[0;34m'
    NC = '\033[0m'


# Fields that legitimately/expectedly differ per run or per language.
# Never compared -- not even for presence.
EXCLUDED_FIELDS = {
    "timestamp",    # wall-clock, differs every run
    "trace_id",     # per-run UUID/span-derived hex
    "span_id",      # per-run hex
    "event_id",     # per-run UUID
    "session_id",   # per-run UUID
    "service_name", # differs by design: OTEL_SERVICE_NAME defaults to
                     # sovdev-test-company-lookup-{typescript,python}
}

# Checked for presence only (non-empty iff exception_type is set) --
# language-specific stack trace formatting/file-paths will never literally
# match across languages, so content is never compared.
PRESENCE_ONLY_FIELDS = {
    "exception_stacktrace",
}


class LogComparator:
    def __init__(self, json_mode: bool = False):
        self.json_mode = json_mode
        self.errors: List[str] = []
        self.warnings: List[str] = []

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

    def _load(self, log_file: Path) -> List[Dict[str, Any]]:
        if not log_file.exists():
            raise FileNotFoundError(f"Log file not found: {log_file}")

        content = log_file.read_text()
        if not content.strip():
            return []

        return [json.loads(line) for line in content.splitlines() if line.strip()]

    def compare(self, master_file: Path, candidate_file: Path) -> bool:
        """Compare candidate against master. Returns True if they match."""
        try:
            master_logs = self._load(master_file)
        except (FileNotFoundError, json.JSONDecodeError) as e:
            self.print_error(f"Could not read master log ({master_file}): {e}")
            return False

        try:
            candidate_logs = self._load(candidate_file)
        except (FileNotFoundError, json.JSONDecodeError) as e:
            self.print_error(f"Could not read candidate log ({candidate_file}): {e}")
            return False

        if not master_logs:
            self.print_error(f"Master log is empty: {master_file}")
            return False

        # Top-level check: entry count must match before comparing entries.
        if len(master_logs) != len(candidate_logs):
            self.print_error(
                f"Entry count mismatch: master has {len(master_logs)} entries, "
                f"candidate has {len(candidate_logs)}"
            )
            return False

        self.print_info(f"Comparing {len(master_logs)} log entries (position-matched)...")

        valid = True
        for i, (master_entry, candidate_entry) in enumerate(
            zip(master_logs, candidate_logs), start=1
        ):
            if not self._compare_entry(i, master_entry, candidate_entry):
                valid = False

        if valid:
            self.print_success(f"All {len(master_logs)} entries match TypeScript's output")

        return valid

    def _compare_entry(
        self, index: int, master: Dict[str, Any], candidate: Dict[str, Any]
    ) -> bool:
        valid = True

        compared_fields = (set(master.keys()) | set(candidate.keys())) - EXCLUDED_FIELDS

        for field in sorted(compared_fields):
            if field == "peer_service":
                # PEER_SERVICES.INTERNAL resolves at runtime to that run's own
                # service_name (confirmed empirically: both TypeScript and
                # Python set peer_service == service_name for INTERNAL calls).
                # Since service_name legitimately differs per language, an
                # INTERNAL-resolved peer_service differs right along with it --
                # that's not a bug. Only compare peer_service when it's NOT
                # self-referential on both sides (i.e., a real external peer
                # service ID like "SYS1234567").
                master_is_internal = master.get("peer_service") == master.get("service_name")
                candidate_is_internal = candidate.get("peer_service") == candidate.get(
                    "service_name"
                )
                if master_is_internal and candidate_is_internal:
                    continue
                if master_is_internal != candidate_is_internal:
                    valid = False
                    self.print_error(
                        f"Entry {index}, field 'peer_service': INTERNAL-resolution mismatch "
                        f"(master {'is' if master_is_internal else 'is not'} INTERNAL-resolved, "
                        f"candidate {'is' if candidate_is_internal else 'is not'})"
                    )
                    continue
                # Neither side is INTERNAL-resolved -- fall through to the
                # normal exact-match comparison below.

            if field in PRESENCE_ONLY_FIELDS:
                master_present = bool(master.get(field))
                candidate_present = bool(candidate.get(field))
                if master_present != candidate_present:
                    valid = False
                    self.print_error(
                        f"Entry {index}, field '{field}': presence mismatch "
                        f"(master {'has' if master_present else 'lacks'} it, "
                        f"candidate {'has' if candidate_present else 'lacks'} it)"
                    )
                continue

            master_value = master.get(field, "<missing>")
            candidate_value = candidate.get(field, "<missing>")

            if master_value != candidate_value:
                valid = False
                self.print_error(
                    f"Entry {index}, field '{field}': "
                    f"expected {master_value!r} (TypeScript), got {candidate_value!r}"
                )

        return valid

    def output_result(self, valid: bool):
        if self.json_mode:
            result = {
                "valid": valid,
                "errors": self.errors,
                "warnings": self.warnings,
            }
            print(json.dumps(result, indent=2))
        else:
            print()
            if valid:
                print(f"{Colors.GREEN}✅ MATCH — output is identical to TypeScript's{Colors.NC}")
            else:
                print(f"{Colors.RED}❌ MISMATCH — output differs from TypeScript's{Colors.NC}")
            print()
            print(f"Errors: {len(self.errors)}")
            print(f"Warnings: {len(self.warnings)}")


def main():
    parser = argparse.ArgumentParser(
        description="Compare a candidate language's log file against TypeScript's (the master)",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Compare Python's output against TypeScript's for the same E2E run
  python3 compare-log-files.py \\
      /workspace/typescript/test/e2e/company-lookup/logs/dev.log \\
      /workspace/python/test/e2e/company-lookup/logs/dev.log

  # JSON output for automation
  python3 compare-log-files.py <master-log> <candidate-log> --json
        """,
    )
    parser.add_argument("master_log", type=Path, help="Path to TypeScript's (master) log file")
    parser.add_argument("candidate_log", type=Path, help="Path to the candidate language's log file")
    parser.add_argument("--json", action="store_true", help="Output JSON format for automation")

    args = parser.parse_args()

    comparator = LogComparator(json_mode=args.json)

    if not args.json:
        print(f"{Colors.BLUE}🔍 Comparing against master: {args.master_log}{Colors.NC}")
        print(f"{Colors.BLUE}   Candidate: {args.candidate_log}{Colors.NC}")
        print()

    valid = comparator.compare(args.master_log, args.candidate_log)
    comparator.output_result(valid)

    sys.exit(0 if valid else 1)


if __name__ == "__main__":
    main()
