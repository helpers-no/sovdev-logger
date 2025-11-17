#!/bin/bash
# File: .devcontainer/additions/config-git.sh
# Purpose: Configure Git user identity (name and email)
# Usage: bash config-git.sh

#------------------------------------------------------------------------------
# CONFIG METADATA - For dev-setup.sh integration
#------------------------------------------------------------------------------

CONFIG_NAME="Git Identity"
CONFIG_DESCRIPTION="Set your global Git username and email for commits"
CONFIG_CATEGORY="INFRA_CONFIG"
CHECK_CONFIG_COMMAND="git config --global user.name >/dev/null 2>&1 && git config --global user.email >/dev/null 2>&1"

#------------------------------------------------------------------------------

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔧 Git Identity Configuration"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Show current configuration if exists
log_info "Current Git configuration:"
CURRENT_NAME=$(git config --global user.name 2>/dev/null || echo "Not set")
CURRENT_EMAIL=$(git config --global user.email 2>/dev/null || echo "Not set")

echo "  Name:  $CURRENT_NAME"
echo "  Email: $CURRENT_EMAIL"
echo ""

# Prompt for name
read -p "Enter your full name (e.g., John Doe): " GIT_NAME
if [[ -z "$GIT_NAME" ]]; then
    log_warn "Name cannot be empty. Using current value or default."
    if [[ "$CURRENT_NAME" == "Not set" ]]; then
        GIT_NAME="VSCode User"
    else
        GIT_NAME="$CURRENT_NAME"
    fi
fi

# Prompt for email
read -p "Enter your email (e.g., john.doe@organization.no): " GIT_EMAIL
if [[ -z "$GIT_EMAIL" ]]; then
    log_warn "Email cannot be empty. Using current value or default."
    if [[ "$CURRENT_EMAIL" == "Not set" ]]; then
        GIT_EMAIL="user@example.com"
    else
        GIT_EMAIL="$CURRENT_EMAIL"
    fi
fi

echo ""
log_info "Setting Git identity..."

# Set Git configuration
git config --global user.name "$GIT_NAME"
git config --global user.email "$GIT_EMAIL"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_success "Git Identity Configured"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📋 Your Git Configuration:"
echo "  Name:  $(git config --global user.name)"
echo "  Email: $(git config --global user.email)"
echo ""
echo "💡 This will be used for all your Git commits in this container."
echo ""
