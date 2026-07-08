#!/bin/bash
#
# init-language-workspace.sh
#
# Initialize a new language implementation workspace from templates.
#
# Usage:
#   ./init-language-workspace.sh <language>
#
# Example:
#   ./init-language-workspace.sh go
#   ./init-language-workspace.sh python
#   ./init-language-workspace.sh csharp
#
# This script:
# 1. Creates <language>/llm-work/ directory
# 2. Copies templates from specification/llm-work-templates/
# 3. Replaces [LANGUAGE] placeholder with actual language name
# 4. Replaces [DATE] placeholder with current date
# 5. Makes scripts executable
#

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Usage function
usage() {
    echo "Usage: $0 <language>"
    echo ""
    echo "Example:"
    echo "  $0 go"
    echo "  $0 python"
    echo "  $0 csharp"
    echo ""
    echo "This script creates a new language workspace from templates."
    exit 1
}

# Check arguments
if [ $# -ne 1 ]; then
    echo -e "${RED}Error: Missing language argument${NC}"
    usage
fi

LANGUAGE="$1"
CURRENT_DATE=$(date +%Y-%m-%d)

# Validate language name (alphanumeric and dash only)
if ! [[ "$LANGUAGE" =~ ^[a-zA-Z0-9-]+$ ]]; then
    echo -e "${RED}Error: Language name must be alphanumeric (with dashes allowed)${NC}"
    echo "Invalid: $LANGUAGE"
    exit 1
fi

# Determine project root (script is in specification/llm-work-templates/enforcement/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
TEMPLATES_DIR="$PROJECT_ROOT/specification/llm-work-templates"
TARGET_DIR="$PROJECT_ROOT/$LANGUAGE/llm-work"

echo -e "${BLUE}Initializing workspace for language: ${GREEN}${LANGUAGE}${NC}"
echo -e "${BLUE}Project root: ${NC}$PROJECT_ROOT"
echo -e "${BLUE}Templates: ${NC}$TEMPLATES_DIR"
echo -e "${BLUE}Target: ${NC}$TARGET_DIR"
echo ""

# Check if target directory already exists
if [ -d "$TARGET_DIR" ]; then
    echo -e "${YELLOW}Warning: Directory already exists: $TARGET_DIR${NC}"
    read -p "Overwrite existing files? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${RED}Aborted by user${NC}"
        exit 1
    fi
fi

# Create target directory
echo -e "${BLUE}Creating directory structure...${NC}"
mkdir -p "$TARGET_DIR"

# Copy ROADMAP template
echo -e "${BLUE}Copying ROADMAP template...${NC}"
if [ ! -f "$TEMPLATES_DIR/ROADMAP-template.md" ]; then
    echo -e "${RED}Error: ROADMAP-template.md not found in templates directory${NC}"
    exit 1
fi

cp "$TEMPLATES_DIR/ROADMAP-template.md" "$TARGET_DIR/ROADMAP.md"
echo -e "${GREEN}✓${NC} Created ROADMAP.md"

# Copy CLAUDE template
echo -e "${BLUE}Copying CLAUDE template...${NC}"
if [ ! -f "$TEMPLATES_DIR/CLAUDE-template.md" ]; then
    echo -e "${RED}Error: CLAUDE-template.md not found in templates directory${NC}"
    exit 1
fi

cp "$TEMPLATES_DIR/CLAUDE-template.md" "$TARGET_DIR/CLAUDE.md"
echo -e "${GREEN}✓${NC} Created CLAUDE.md"

# Copy task templates (if any exist)
echo -e "${BLUE}Copying task templates...${NC}"
TASK_COUNT=0
if [ -d "$TEMPLATES_DIR/task-templates" ]; then
    for task_file in "$TEMPLATES_DIR/task-templates"/*.md; do
        if [ -f "$task_file" ]; then
            filename=$(basename "$task_file")
            # Remove "-template" suffix if present
            target_filename="${filename//-template/}"
            cp "$task_file" "$TARGET_DIR/$target_filename"
            echo -e "${GREEN}✓${NC} Created $target_filename"
            TASK_COUNT=$((TASK_COUNT + 1))
        fi
    done
fi

if [ $TASK_COUNT -eq 0 ]; then
    echo -e "${YELLOW}  No task templates found${NC}"
else
    echo -e "${GREEN}✓${NC} Copied $TASK_COUNT task template(s)"
fi

# Replace placeholders
echo ""
echo -e "${BLUE}Replacing placeholders...${NC}"

# Function to replace placeholders in a file
replace_placeholders() {
    local file="$1"

    # Check if file exists
    if [ ! -f "$file" ]; then
        echo -e "${YELLOW}  Skipping: $file (not found)${NC}"
        return
    fi

    # Use sed to replace placeholders
    # macOS sed requires -i '' while Linux sed requires -i
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i '' "s/\[LANGUAGE\]/$LANGUAGE/g" "$file"
        sed -i '' "s/\[DATE\]/$CURRENT_DATE/g" "$file"
    else
        # Linux
        sed -i "s/\[LANGUAGE\]/$LANGUAGE/g" "$file"
        sed -i "s/\[DATE\]/$CURRENT_DATE/g" "$file"
    fi

    echo -e "${GREEN}✓${NC} Updated placeholders in $(basename "$file")"
}

# Replace in all copied files
replace_placeholders "$TARGET_DIR/ROADMAP.md"
replace_placeholders "$TARGET_DIR/CLAUDE.md"

for task_file in "$TARGET_DIR"/task-*.md; do
    if [ -f "$task_file" ]; then
        replace_placeholders "$task_file"
    fi
done

# Create placeholder files for implementation notes
echo ""
echo -e "${BLUE}Creating placeholder files...${NC}"

if [ ! -f "$TARGET_DIR/otel-sdk-comparison.md" ]; then
    cat > "$TARGET_DIR/otel-sdk-comparison.md" <<EOF
# OpenTelemetry SDK Comparison - $LANGUAGE

**Created**: $CURRENT_DATE
**Status**: To be completed in Phase 0, Task 4

---

## SDK Maturity Status

Visit https://opentelemetry.io/docs/languages/ and document:

- **Traces**: [Development/Beta/Stable]
- **Metrics**: [Development/Beta/Stable]
- **Logs**: [Development/Beta/Stable]

---

## Packages Required

List packages/libraries needed for OTLP exporters.

---

## OTLP Exporter Configuration

Document how to configure OTLP exporters in $LANGUAGE.

Include code examples.

---

## HTTP Headers Configuration

**Critical**: Document how to add \`Host: otel.localhost\` header.

Include exact API/method/property name and code example.

---

## Metric Attributes Pattern

**Critical**: Document how to add attributes with underscores (not dots).

Include code examples showing:
- peer_service (correct)
- peer.service (wrong - breaks Grafana)

---

## Differences from TypeScript

List key differences from TypeScript implementation.

---

## References

- [Link to SDK documentation]
- [Link to OTLP exporter docs]
- [Link to metrics docs]
EOF
    echo -e "${GREEN}✓${NC} Created otel-sdk-comparison.md placeholder"
fi

if [ ! -f "$TARGET_DIR/implementation-notes.md" ]; then
    cat > "$TARGET_DIR/implementation-notes.md" <<EOF
# Implementation Notes - $LANGUAGE

**Created**: $CURRENT_DATE

---

## Overview

Notes and decisions made during $LANGUAGE implementation.

---

## Key Decisions

### OTLP Exporters
- [Document exporter configuration decisions]

### File Logging
- [Document logging library choice and configuration]

### API Design
- [Document any language-specific API adaptations]

---

## Challenges Encountered

### Challenge 1: [Title]
**Problem**: [Description]
**Solution**: [How it was solved]

---

## Deviations from Specification

List any intentional deviations from specification with justification.

---

## Performance Notes

- [Any performance observations]
- [Optimization decisions]

---

## Testing Notes

- [Notes about E2E test implementation]
- [Any test-specific challenges]

---

## References

- [Links to helpful resources]
- [SDK documentation]
- [Community discussions]
EOF
    echo -e "${GREEN}✓${NC} Created implementation-notes.md placeholder"
fi

# Summary
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Workspace initialization complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${BLUE}Created files in: ${NC}$TARGET_DIR"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo -e "  1. Read ${GREEN}$TARGET_DIR/CLAUDE.md${NC} for instructions"
echo -e "  2. Read ${GREEN}$TARGET_DIR/ROADMAP.md${NC} for your task list"
echo -e "  3. Start with Phase 0, Task 1 in ROADMAP.md"
echo ""
echo -e "${BLUE}Always start each session by reading ROADMAP.md!${NC}"
echo ""

# Create .gitignore entry reminder
if [ -f "$PROJECT_ROOT/.gitignore" ]; then
    if ! grep -q "^$LANGUAGE/llm-work/" "$PROJECT_ROOT/.gitignore"; then
        echo -e "${YELLOW}Reminder: Consider adding to .gitignore:${NC}"
        echo -e "  ${YELLOW}$LANGUAGE/llm-work/*.md${NC}"
        echo -e "  ${YELLOW}# (Or keep them in git for collaboration)${NC}"
        echo ""
    fi
fi

exit 0
