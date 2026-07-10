#!/usr/bin/env python3
"""
Sovdev Logger - Doc Consistency Check

Catches the exact class of documentation drift found (by accident) across
PLAN-002 through PLAN-005: inconsistent GitHub remotes across READMEs, and
a Supported Languages table that doesn't match which language READMEs
actually exist. A five-minute script, not a subsystem -- see
website/docs/ai-developer/plans/backlog/PLAN-005-documentation-restructure.md.

Usage:
    python3 check-doc-consistency.py
"""

import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
EXPECTED_REMOTE = "helpers-no/sovdev-logger"

DOC_FILES = [
    REPO_ROOT / "README.md",
    REPO_ROOT / "typescript" / "README.md",
    REPO_ROOT / "python" / "README.md",
    *sorted((REPO_ROOT / "docs").glob("*.md")),
]

GITHUB_URL_RE = re.compile(r"github\.com/([\w.-]+/sovdev-logger)\b")

# Supported Languages table rows look like:
# | **TypeScript** | ✅ Available | [typescript/README.md](typescript/README.md) |
LANGUAGE_ROW_RE = re.compile(r"^\|\s*\*\*([A-Za-z#]+)\*\*\s*\|\s*(✅ Available|📅 Planned)\s*\|")

LANGUAGE_TO_DIR = {
    "TypeScript": "typescript",
    "Python": "python",
    "Go": "go",
    "C#": "csharp",
    "Rust": "rust",
    "PHP": "php",
}


def check_remotes():
    errors = []
    for path in DOC_FILES:
        if not path.exists():
            continue
        text = path.read_text(encoding="utf-8")
        for match in GITHUB_URL_RE.finditer(text):
            remote = match.group(1)
            if remote != EXPECTED_REMOTE:
                line_no = text.count("\n", 0, match.start()) + 1
                errors.append(
                    f"{path.relative_to(REPO_ROOT)}:{line_no}: references "
                    f"'{remote}', expected '{EXPECTED_REMOTE}'"
                )
    return errors


def check_supported_languages_table():
    errors = []
    readme = REPO_ROOT / "README.md"
    text = readme.read_text(encoding="utf-8")
    for line in text.splitlines():
        match = LANGUAGE_ROW_RE.match(line.strip())
        if not match:
            continue
        language, status = match.groups()
        lang_dir = LANGUAGE_TO_DIR.get(language)
        if lang_dir is None:
            errors.append(f"README.md: unrecognized language '{language}' in Supported Languages table")
            continue
        readme_exists = (REPO_ROOT / lang_dir / "README.md").exists()
        if status == "✅ Available" and not readme_exists:
            errors.append(
                f"README.md: '{language}' marked Available but {lang_dir}/README.md does not exist"
            )
        if status == "📅 Planned" and readme_exists:
            errors.append(
                f"README.md: '{language}' marked Planned but {lang_dir}/README.md exists -- table is stale"
            )
    return errors


def main():
    errors = check_remotes() + check_supported_languages_table()
    if errors:
        print(f"FAIL: {len(errors)} doc consistency issue(s) found:\n", file=sys.stderr)
        for error in errors:
            print(f"  - {error}", file=sys.stderr)
        sys.exit(1)
    print("OK: GitHub remotes consistent, Supported Languages table matches reality.")
    sys.exit(0)


if __name__ == "__main__":
    main()
