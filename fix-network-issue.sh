#!/bin/bash

# Quick fix for Docker network subnet exhaustion

echo "🔧 Fixing Docker network subnet exhaustion..."

# Stop all PowerChat containers
echo "Stopping PowerChat containers..."
docker ps | grep powerchat | awk '{print $1}' | xargs -r docker stop 2>/dev/null || true

# Remove all PowerChat networks
echo "Removing PowerChat networks..."
docker network ls | grep powerchat-network | awk '{print $1}' | xargs -r docker network rm 2>/dev/null || true

# Clean up all unused networks
echo "Cleaning up unused networks..."
docker network prune -f

# Clean up unused containers
echo "Cleaning up unused containers..."
docker container prune -f

# Remove any project-specific default networks
echo "Removing project default networks..."
docker network ls | grep "_default" | awk '{print $1}' | xargs -r docker network rm 2>/dev/null || true

# Create shared network for all PowerChat instances
echo "Creating shared PowerChat network..."
docker network create powerchat-shared-network --driver bridge --subnet=172.20.0.0/16 2>/dev/null || \
docker network create powerchat-shared-network --driver bridge 2>/dev/null || \
echo "Shared network already exists or creation failed"

# Show remaining networks
echo "Remaining networks:"
docker network ls

echo "✅ Network cleanup completed!"
echo ""
echo "Now you can retry your deployment:"
echo "./multi-instance-deploy.sh"
