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
# 2. Checks if .env file exists and is properly configured (for Task 6+)
# 3. Parses task completion status
# 4. Validates phase completion before allowing next phase
# 5. Blocks validation if ROADMAP.md not being updated
# 6. Provides helpful feedback about progress
#
# Exit codes:
#   0 - Progress is satisfactory, may proceed
#   1 - Progress check failed, must update ROADMAP.md
#   2 - Invalid arguments or missing files
#
# Changelog:
#   2025-11-12: Added .env file validation (prevents missing .env issue from C# implementation)
#   2025-11-12: Fixed regex to support decimal progress values (e.g., "1.5/4")
#   2025-11-12: Fixed arithmetic error in count_phase_tasks (double-zero output bug)
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

# Check if .env file exists (mandatory for Task 5 and beyond)
ENV_FILE="$PROJECT_ROOT/$LANGUAGE/test/e2e/company-lookup/.env"

echo -e "${BLUE}Checking .env file...${NC}"

# Check if we're past Task 5 (project structure setup)
# If any Task 6+ is in progress or complete, .env MUST exist
task_6_or_later=$(grep -E "^- \[(x|-)\].*6\. Implement OTLP" "$ROADMAP_FILE" || echo "")

if [ -n "$task_6_or_later" ]; then
    # Task 6+ has been started or completed, .env is MANDATORY
    if [ ! -f "$ENV_FILE" ]; then
        echo -e "${RED}❌ .env FILE MISSING${NC}"
        echo -e "${RED}Expected location: $ENV_FILE${NC}"
        echo ""
        echo -e "${RED}${BOLD}Task 6 (OTLP exporters) has been started but .env file doesn't exist!${NC}"
        echo ""
        echo -e "${YELLOW}This is EXACTLY what happened in C# implementation:${NC}"
        echo -e "${YELLOW}  - Spent 4+ hours debugging 'why no logs in Loki?'${NC}"
        echo -e "${YELLOW}  - Answer: .env file was never created${NC}"
        echo -e "${YELLOW}  - OTLP endpoints were wrong/missing${NC}"
        echo ""
        echo -e "${BLUE}To fix:${NC}"
        echo -e "  1. Copy TypeScript .env as template:"
        echo -e "     cp typescript/test/e2e/company-lookup/.env $ENV_FILE"
        echo ""
        echo -e "  2. Update service name to: sovdev-test-company-lookup-${LANGUAGE}"
        echo ""
        echo -e "  3. Verify required variables:"
        echo -e "     - OTEL_SERVICE_NAME"
        echo -e "     - OTEL_EXPORTER_OTLP_LOGS_ENDPOINT"
        echo -e "     - OTEL_EXPORTER_OTLP_METRICS_ENDPOINT"
        echo -e "     - OTEL_EXPORTER_OTLP_TRACES_ENDPOINT"
        echo -e "     - OTEL_EXPORTER_OTLP_HEADERS"
        echo ""
        echo -e "  4. See task-05-setup-project.md for language-specific adaptations"
        echo ""
        exit 1
    fi

    # .env exists, validate content
    echo -e "${GREEN}✓${NC} Found .env file: $ENV_FILE"

    # Check for required variables
    missing_vars=()

    if ! grep -q "OTEL_SERVICE_NAME" "$ENV_FILE"; then
        missing_vars+=("OTEL_SERVICE_NAME")
    fi

    if ! grep -q "OTEL_EXPORTER_OTLP_LOGS_ENDPOINT" "$ENV_FILE"; then
        missing_vars+=("OTEL_EXPORTER_OTLP_LOGS_ENDPOINT")
    fi

    if ! grep -q "OTEL_EXPORTER_OTLP_METRICS_ENDPOINT" "$ENV_FILE"; then
        missing_vars+=("OTEL_EXPORTER_OTLP_METRICS_ENDPOINT")
    fi

    if ! grep -q "OTEL_EXPORTER_OTLP_TRACES_ENDPOINT" "$ENV_FILE"; then
        missing_vars+=("OTEL_EXPORTER_OTLP_TRACES_ENDPOINT")
    fi

    if ! grep -q "OTEL_EXPORTER_OTLP_HEADERS" "$ENV_FILE"; then
        missing_vars+=("OTEL_EXPORTER_OTLP_HEADERS")
    fi

    if [ ${#missing_vars[@]} -gt 0 ]; then
        echo -e "${RED}❌ .env FILE INCOMPLETE${NC}"
        echo ""
        echo -e "${RED}Missing required variables:${NC}"
        for var in "${missing_vars[@]}"; do
            echo -e "  ${RED}  - $var${NC}"
        done
        echo ""
        echo -e "${YELLOW}Copy complete template from typescript/test/e2e/company-lookup/.env${NC}"
        echo ""
        exit 1
    fi

    # Check service name includes language
    service_name=$(grep "OTEL_SERVICE_NAME" "$ENV_FILE" | cut -d '=' -f2)
    if ! echo "$service_name" | grep -qi "$LANGUAGE"; then
        echo -e "${YELLOW}⚠ WARNING: Service name doesn't include language${NC}"
        echo -e "${YELLOW}  Current: $service_name${NC}"
        echo -e "${YELLOW}  Expected: sovdev-test-company-lookup-${LANGUAGE}${NC}"
        echo ""
        echo -e "${YELLOW}You may want to update this for easier filtering in Grafana.${NC}"
        echo ""
        # Don't fail, just warn
    fi

    echo -e "${GREEN}✓${NC} .env file contains all required variables"
    echo ""
else
    # Task 6 not started yet, .env is optional but recommended
    if [ -f "$ENV_FILE" ]; then
        echo -e "${GREEN}✓${NC} .env file exists (good preparation!)"
        echo ""
    else
        echo -e "${BLUE}ℹ${NC} .env file not created yet (will be required for Task 6)"
        echo ""
    fi
fi

# Function to count tasks in a phase
count_phase_tasks() {
    local phase="$1"
    local status="$2"  # "all", "completed", "in_progress", "pending"

    # Extract phase section
    local phase_section=$(sed -n "/^## Phase $phase:/,/^## /p" "$ROADMAP_FILE")

    # FIX 2025-11-12: Capture count in variable before echoing to avoid double-zero output
    # Previous: grep -c || echo "0" caused "0\n0" when no matches (grep outputs 0 and exits 1)
    # This caused arithmetic errors like: "0 0: syntax error in expression"
    local count
    case "$status" in
        "all")
            count=$(echo "$phase_section" | grep -c "^- \[" || true)
            ;;
        "completed")
            count=$(echo "$phase_section" | grep -c "^- \[x\]" || true)
            ;;
        "in_progress")
            count=$(echo "$phase_section" | grep -c "^- \[-\]" || true)
            ;;
        "pending")
            count=$(echo "$phase_section" | grep -c "^- \[ \]" || true)
            ;;
    esac

    # Ensure we return a number (default to 0 if empty)
    echo "${count:-0}"
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

    # Extract phase progress line like "Phase 0: Planning (2/4 complete)" or "Phase 1: (1.5/4 complete)"
    local progress_line=$(grep "^## Phase $phase:" "$ROADMAP_FILE" | head -1)

    # Extract "2/4" or "1.5/4" pattern (supports decimals)
    # FIX 2025-11-12: Changed from ([0-9]+) to ([0-9.]+) to support decimal progress like "1.5/4"
    if [[ "$progress_line" =~ \(([0-9.]+)/([0-9]+) ]]; then
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
    # Ensure we have a number (default to 0 if empty)
    phase_completed=${phase_completed:-0}
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
