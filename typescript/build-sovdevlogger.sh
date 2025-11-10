#!/bin/bash
# filename: typescript/build-sovdevlogger.sh
# description: Build the TypeScript sovdev-logger library
#
# Purpose:
#   Compiles the TypeScript sovdev-logger library into JavaScript for distribution.
#   This script handles the complete build process including dependency installation
#   and TypeScript compilation.
#
# Usage:
#   ./build-sovdevlogger.sh              # Standard build
#   ./build-sovdevlogger.sh clean        # Clean build (remove dist/ first)
#   ./build-sovdevlogger.sh watch        # Watch mode for development
#
# Environment:
#   - Must run inside devcontainer (uses Node.js toolchain)
#   - Requires package.json with build scripts configured
#   - Outputs compiled JavaScript to dist/ directory
#
# Exit Codes:
#   0 - Build successful
#   1 - Build failed (compilation errors, missing dependencies, etc.)
#
# Examples:
#   # From inside DevContainer at /workspace/:
#   cd typescript
#   ./build-sovdevlogger.sh
#
#   # Or with absolute path:
#   cd /workspace/typescript && ./build-sovdevlogger.sh
#
# Related:
#   - package.json: Contains build scripts and dependencies
#   - tsconfig.json: TypeScript compiler configuration
#   - specification/09-development-loop.md: Development workflow documentation

set -e  # Exit on error
set -o pipefail  # Catch errors in pipes

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Change to script directory
cd "$(dirname "$0")"

# Parse command line arguments
CLEAN_BUILD=false
WATCH_MODE=false

if [ "$1" == "clean" ]; then
  CLEAN_BUILD=true
elif [ "$1" == "watch" ]; then
  WATCH_MODE=true
fi

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Building TypeScript sovdev-logger${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Clean build if requested
if [ "$CLEAN_BUILD" = true ]; then
  echo -e "${YELLOW}🧹 Cleaning previous build...${NC}"
  rm -rf dist/
  echo -e "${GREEN}✅ Clean complete${NC}"
  echo ""
fi

# Check if node_modules exists
if [ ! -d "node_modules" ]; then
  echo -e "${YELLOW}📦 Installing dependencies (first time)...${NC}"
  npm install
  echo -e "${GREEN}✅ Dependencies installed${NC}"
  echo ""
fi

# Build or watch
if [ "$WATCH_MODE" = true ]; then
  echo -e "${BLUE}👀 Starting watch mode (Ctrl+C to stop)...${NC}"
  echo ""
  npm run build -- --watch
else
  echo -e "${BLUE}🔨 Compiling TypeScript → JavaScript...${NC}"
  npm run build
  echo ""

  # Check if dist directory was created
  if [ -d "dist" ]; then
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}✅ Build successful!${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "📂 Output directory: dist/"
    echo "📄 Files generated:"
    ls -lh dist/ | tail -n +2 | awk '{print "   - " $9 " (" $5 ")"}'
    echo ""
  else
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}❌ Build failed - dist/ directory not created${NC}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    exit 1
  fi
fi
