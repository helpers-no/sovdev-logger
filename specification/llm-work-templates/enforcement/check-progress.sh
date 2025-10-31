#!/bin/bash
#
# check-progress.sh
#
# Enforcement script that validates ROADMAP.md progress before allowing validation.
#
# Usage:
#   ./check-progress.sh <language> [--phase N]
#
# Example:
#   ./check-progress.sh go
#   ./check-progress.sh python --phase 2
#
# This script:
# 1. Checks if ROADMAP.md exists
# 2. Parses task completion status
# 3. Validates phase completion before allowing next phase
# 4. Blocks validation if ROADMAP.md not being updated
# 5. Provides helpful feedback about progress
#
# Exit codes:
#   0 - Progress is satisfactory, may proceed
#   1 - Progress check failed, must update ROADMAP.md
#   2 - Invalid arguments or missing files
#

set -e  # Exit on error (but we handle errors explicitly)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Usage function
usage() {
    echo "Usage: $0 <language> [--phase N]"
    echo ""
    echo "Example:"
    echo "  $0 go"
    echo "  $0 python --phase 2"
    echo ""
    echo "Checks ROADMAP.md progress before allowing validation to proceed."
    exit 2
}

# Check arguments
if [ $# -lt 1 ]; then
    echo -e "${RED}Error: Missing language argument${NC}"
    usage
fi

LANGUAGE="$1"
REQUIRED_PHASE=""

# Parse optional --phase argument
if [ $# -ge 3 ] && [ "$2" = "--phase" ]; then
    REQUIRED_PHASE="$3"
    if ! [[ "$REQUIRED_PHASE" =~ ^[0-3]$ ]]; then
        echo -e "${RED}Error: Phase must be 0, 1, 2, or 3${NC}"
        exit 2
    fi
fi

# Determine paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
ROADMAP_FILE="$PROJECT_ROOT/$LANGUAGE/llm-work/ROADMAP.md"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Progress Check: ${GREEN}${LANGUAGE}${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if ROADMAP.md exists
if [ ! -f "$ROADMAP_FILE" ]; then
    echo -e "${RED}❌ ROADMAP.md not found${NC}"
    echo -e "${RED}Expected location: $ROADMAP_FILE${NC}"
    echo ""
    echo -e "${YELLOW}Did you run init-language-workspace.sh?${NC}"
    echo -e "${YELLOW}  ./specification/llm-work-templates/enforcement/init-language-workspace.sh $LANGUAGE${NC}"
    echo ""
    exit 2
fi

echo -e "${GREEN}✓${NC} Found ROADMAP.md: $ROADMAP_FILE"
echo ""

# Function to count tasks in a phase
count_phase_tasks() {
    local phase="$1"
    local status="$2"  # "all", "completed", "in_progress", "pending"

    # Extract phase section
    local phase_section=$(sed -n "/^## Phase $phase:/,/^## /p" "$ROADMAP_FILE")

    case "$status" in
        "all")
            echo "$phase_section" | grep -c "^- \[" || echo "0"
            ;;
        "completed")
            echo "$phase_section" | grep -c "^- \[x\]" || echo "0"
            ;;
        "in_progress")
            echo "$phase_section" | grep -c "^- \[-\]" || echo "0"
            ;;
        "pending")
            echo "$phase_section" | grep -c "^- \[ \]" || echo "0"
            ;;
    esac
}

# Function to check if phase is locked
is_phase_locked() {
    local phase="$1"

    # Check if phase header contains "LOCKED"
    if grep -q "^## Phase $phase:.*🔒 LOCKED" "$ROADMAP_FILE"; then
        return 0  # Phase is locked (true)
    else
        return 1  # Phase is not locked (false)
    fi
}

# Function to get phase completion percentage
get_phase_progress() {
    local phase="$1"

    # Extract phase progress line like "Phase 0: Planning (2/4 complete)"
    local progress_line=$(grep "^## Phase $phase:" "$ROADMAP_FILE" | head -1)

    # Extract "2/4" pattern
    if [[ "$progress_line" =~ \(([0-9]+)/([0-9]+) ]]; then
        local completed="${BASH_REMATCH[1]}"
        local total="${BASH_REMATCH[2]}"
        echo "$completed/$total"
    else
        echo "unknown"
    fi
}

# Check all phases
echo -e "${BLUE}Phase Progress:${NC}"
echo ""

for phase in 0 1 2 3; do
    progress=$(get_phase_progress $phase)

    # Extract completed and total
    if [[ "$progress" =~ ([0-9]+)/([0-9]+) ]]; then
        completed="${BASH_REMATCH[1]}"
        total="${BASH_REMATCH[2]}"

        # Calculate percentage
        if [ "$total" -gt 0 ]; then
            percentage=$((completed * 100 / total))
        else
            percentage=0
        fi

        # Determine status icon
        if [ "$completed" -eq "$total" ] && [ "$total" -gt 0 ]; then
            status_icon="${GREEN}✅${NC}"
            status_text="${GREEN}Complete${NC}"
        elif [ "$completed" -gt 0 ]; then
            status_icon="${YELLOW}🔄${NC}"
            status_text="${YELLOW}In Progress${NC}"
        elif is_phase_locked $phase; then
            status_icon="${RED}🔒${NC}"
            status_text="${RED}Locked${NC}"
        else
            status_icon="${BLUE}📋${NC}"
            status_text="${BLUE}Not Started${NC}"
        fi

        echo -e "  Phase $phase: $progress ($percentage%) $status_icon $status_text"
    else
        echo -e "  Phase $phase: ${YELLOW}Unable to parse progress${NC}"
    fi
done

echo ""

# Check if ANY progress has been made
total_completed=0
for phase in 0 1 2 3; do
    phase_completed=$(count_phase_tasks $phase "completed")
    total_completed=$((total_completed + phase_completed))
done

if [ "$total_completed" -eq 0 ]; then
    echo -e "${RED}❌ PROGRESS CHECK FAILED${NC}"
    echo ""
    echo -e "${RED}${BOLD}No tasks have been marked complete in ROADMAP.md${NC}"
    echo ""
    echo -e "${YELLOW}This is the EXACT problem we had with C# implementation!${NC}"
    echo -e "${YELLOW}You MUST update ROADMAP.md as you work.${NC}"
    echo ""
    echo -e "${BLUE}To fix:${NC}"
    echo -e "  1. Open: $ROADMAP_FILE"
    echo -e "  2. Mark completed tasks: [ ] → [x] ✅ $(date +%Y-%m-%d)"
    echo -e "  3. Update 'Last updated' date at top of file"
    echo -e "  4. Run this check again"
    echo ""
    exit 1
fi

# If specific phase was requested, check if that phase is complete
if [ -n "$REQUIRED_PHASE" ]; then
    progress=$(get_phase_progress $REQUIRED_PHASE)

    if [[ "$progress" =~ ([0-9]+)/([0-9]+) ]]; then
        completed="${BASH_REMATCH[1]}"
        total="${BASH_REMATCH[2]}"

        if [ "$completed" -ne "$total" ]; then
            echo -e "${RED}❌ PHASE $REQUIRED_PHASE NOT COMPLETE${NC}"
            echo ""
            echo -e "${RED}Progress: $completed/$total tasks complete${NC}"
            echo ""
            echo -e "${YELLOW}You must complete Phase $REQUIRED_PHASE before proceeding.${NC}"
            echo ""
            echo -e "${BLUE}Remaining tasks in Phase $REQUIRED_PHASE:${NC}"

            # Show pending tasks
            sed -n "/^## Phase $REQUIRED_PHASE:/,/^## /p" "$ROADMAP_FILE" | grep "^- \[ \]" | while read -r line; do
                echo -e "  ${YELLOW}$line${NC}"
            done

            # Show in-progress tasks
            sed -n "/^## Phase $REQUIRED_PHASE:/,/^## /p" "$ROADMAP_FILE" | grep "^- \[-\]" | while read -r line; do
                echo -e "  ${BLUE}$line${NC}"
            done

            echo ""
            exit 1
        fi
    fi

    echo -e "${GREEN}✓${NC} Phase $REQUIRED_PHASE is complete ($progress)"
    echo ""
fi

# Check if phases are being completed in order (Phase 1 shouldn't start before Phase 0 is done)
for phase in 0 1 2; do
    next_phase=$((phase + 1))

    phase_progress=$(get_phase_progress $phase)
    next_phase_progress=$(get_phase_progress $next_phase)

    if [[ "$phase_progress" =~ ([0-9]+)/([0-9]+) ]] && [[ "$next_phase_progress" =~ ([0-9]+)/([0-9]+) ]]; then
        phase_completed="${BASH_REMATCH[1]}"
        phase_total="${BASH_REMATCH[2]}"

        # Get next phase numbers from second match
        if [[ "$next_phase_progress" =~ ([0-9]+)/([0-9]+) ]]; then
            next_completed="${BASH_REMATCH[1]}"
        fi

        # If current phase not complete but next phase has progress, warn
        if [ "$phase_completed" -ne "$phase_total" ] && [ "$next_completed" -gt 0 ]; then
            echo -e "${YELLOW}⚠ WARNING: Phase $next_phase started before Phase $phase complete${NC}"
            echo -e "${YELLOW}  Phase $phase: $phase_progress${NC}"
            echo -e "${YELLOW}  Phase $next_phase: $next_phase_progress${NC}"
            echo ""
            echo -e "${YELLOW}Recommended: Complete Phase $phase before moving to Phase $next_phase${NC}"
            echo ""
            # Don't fail, just warn
        fi
    fi
done

# Check when ROADMAP.md was last updated
echo -e "${BLUE}Last Updated Check:${NC}"
echo ""

last_updated_line=$(grep "^**Last updated**:" "$ROADMAP_FILE" | head -1)
if [ -n "$last_updated_line" ]; then
    echo -e "  ${GREEN}✓${NC} $last_updated_line"

    # Extract date
    if [[ "$last_updated_line" =~ ([0-9]{4}-[0-9]{2}-[0-9]{2}) ]]; then
        last_updated_date="${BASH_REMATCH[1]}"
        today_date=$(date +%Y-%m-%d)

        if [ "$last_updated_date" != "$today_date" ]; then
            echo -e "  ${YELLOW}⚠${NC} ROADMAP.md was last updated on $last_updated_date (not today)"
            echo -e "  ${YELLOW}  If you worked on tasks today, remember to update the date!${NC}"
        fi
    fi
else
    echo -e "  ${YELLOW}⚠${NC} 'Last updated' line not found in ROADMAP.md"
fi

echo ""

# Success summary
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✓ Progress check passed${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${BLUE}Summary:${NC}"
echo -e "  • Total completed tasks: ${GREEN}$total_completed${NC}"
echo -e "  • ROADMAP.md exists and is being updated"

if [ -n "$REQUIRED_PHASE" ]; then
    echo -e "  • Phase $REQUIRED_PHASE is complete"
fi

echo ""
echo -e "${GREEN}You may proceed with validation.${NC}"
echo ""

exit 0
