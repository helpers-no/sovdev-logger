#!/bin/bash
# File: .devcontainer/clean-devcontainer.sh
# ⚠️  DEVCONTAINER COMPLETE CLEANUP SCRIPT ⚠️
# 
# This script will PERMANENTLY DELETE:
# - The devcontainer container (devcontainer-toolbox)
# - All Docker volumes associated with this project
# - Project-specific Docker images built for this devcontainer
# - Optionally: VS Code devcontainer volumes
# - Optionally: Unused Docker resources
#
# This script will PRESERVE:
# - Base images (mcr.microsoft.com/devcontainers/*)
# - Your source code (lives on your host machine, not in the container)
#
# After cleanup, rebuild with: code .

set -e

CONTAINER_NAME="devcontainer-toolbox"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_NAME="$(basename "$PROJECT_DIR")"

# Display warning and get confirmation
echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                                                                ║"
echo "║              ⚠️  DEVCONTAINER CLEANUP WARNING ⚠️               ║"
echo "║                                                                ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "This script will PERMANENTLY DELETE:"
echo ""
echo "  🗑️  Container: $CONTAINER_NAME"
echo "  🗑️  Project volumes for: $PROJECT_NAME"
echo "  🗑️  Project-specific DevContainer images"
echo "  🗑️  Optionally: VS Code volumes and unused Docker resources"
echo ""
echo "✅ Your source code in $PROJECT_DIR is SAFE"
echo "✅ Files in /workspace are actually on your host machine"
echo "✅ Base images (mcr.microsoft.com/devcontainers/*) are PRESERVED"
echo ""
echo "⚠️  Any files created OUTSIDE /workspace will be LOST"
echo ""
echo "════════════════════════════════════════════════════════════════"
echo ""
read -p "Are you sure you want to continue? Type 'y' to proceed: " -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Cleanup cancelled by user"
    exit 0
fi

echo "✅ Confirmed. Starting cleanup..."
echo ""

# Function to check if Docker is running
check_docker() {
    if ! docker info > /dev/null 2>&1; then
        echo "❌ Error: Docker is not running or not accessible"
        echo "   Please start Docker and try again"
        exit 1
    fi
}

# Function to stop and remove container
remove_container() {
    echo "🔍 Checking for running/stopped containers..."
    
    # Check if container exists (running or stopped)
    if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        echo "📦 Found container: $CONTAINER_NAME"
        
        # Stop if running
        if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
            echo "🛑 Stopping container..."
            docker stop "$CONTAINER_NAME" || true
        fi
        
        # Remove container
        echo "🗑️  Removing container..."
        docker rm -f "$CONTAINER_NAME" || true
        echo "✅ Container removed"
    else
        echo "ℹ️  No container found with name: $CONTAINER_NAME"
    fi
}

# Function to remove volumes
remove_volumes() {
    echo ""
    echo "🔍 Checking for associated volumes..."
    
    # Find volumes related to this project
    VOLUMES=$(docker volume ls --format '{{.Name}}' | grep -i "$PROJECT_NAME" || true)
    
    if [ -n "$VOLUMES" ]; then
        echo "📦 Found volumes:"
        echo "$VOLUMES"
        echo "🗑️  Removing volumes..."
        echo "$VOLUMES" | xargs -r docker volume rm || true
        echo "✅ Volumes removed"
    else
        echo "ℹ️  No project-specific volumes found"
    fi
    
    # Also check for devcontainer-specific volumes
    DEVCONTAINER_VOLUMES=$(docker volume ls --format '{{.Name}}' | grep "vscode" || true)
    if [ -n "$DEVCONTAINER_VOLUMES" ]; then
        echo ""
        echo "📦 Found VS Code devcontainer volumes:"
        echo "$DEVCONTAINER_VOLUMES"
        read -p "Do you want to remove these as well? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "$DEVCONTAINER_VOLUMES" | xargs -r docker volume rm || true
            echo "✅ VS Code volumes removed"
        else
            echo "⏭️  Skipping VS Code volumes"
        fi
    fi
}

# Function to remove images
remove_images() {
    echo ""
    echo "🔍 Checking for project-specific devcontainer images..."
    
    # Find images built specifically for THIS project (vsc- prefix with project name)
    # This will NOT match base images like mcr.microsoft.com/devcontainers/python
    IMAGES=$(docker images --format '{{.Repository}}:{{.Tag}}' | grep -E "vsc-${PROJECT_NAME}" || true)
    
    if [ -n "$IMAGES" ]; then
        echo "📦 Found project-specific images:"
        echo "$IMAGES"
        echo "🗑️  Removing images..."
        echo "$IMAGES" | xargs -r docker rmi -f || true
        echo "✅ Project images removed"
    else
        echo "ℹ️  No project-specific devcontainer images found"
    fi
    
    echo ""
    echo "💾 Base images (like mcr.microsoft.com/devcontainers/*) are preserved"
    echo "   to avoid re-downloading them on rebuild"
}

# Function to clean VS Code devcontainer metadata
clean_vscode_metadata() {
    echo ""
    echo "🔍 Checking for VS Code devcontainer metadata..."
    
    # VS Code stores devcontainer metadata in various places
    VSCODE_DEVCONTAINER_DIR="$HOME/.vscode/devcontainer"
    
    if [ -d "$VSCODE_DEVCONTAINER_DIR" ]; then
        echo "📦 Found VS Code devcontainer metadata directory"
        # Don't remove the entire directory, just project-specific data if possible
        echo "ℹ️  VS Code metadata at: $VSCODE_DEVCONTAINER_DIR"
    fi
}

# Function to prune Docker system (optional)
prune_docker() {
    echo ""
    read -p "Do you want to prune unused Docker resources (dangling images, networks, etc.)? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "🧹 Pruning Docker system..."
        docker system prune -f
        echo "✅ Docker system pruned"
    else
        echo "⏭️  Skipping Docker system prune"
    fi
}

# Main execution
main() {
    check_docker
    remove_container
    remove_volumes
    remove_images
    clean_vscode_metadata
    prune_docker
    
    echo ""
    echo "════════════════════════════════════════════════════════════════"
    echo "✅ Cleanup Complete!"
    echo "════════════════════════════════════════════════════════════════"
    echo ""
    echo "You can now rebuild the devcontainer by running:"
    echo "  cd '$PROJECT_DIR'"
    echo "  code ."
    echo ""
    echo "Then in VS Code, run:"
    echo "  'Dev Containers: Rebuild Container'"
    echo ""
    echo "💡 Base images are cached - rebuild will be much faster!"
    echo "════════════════════════════════════════════════════════════════"
}

# Run main function
main