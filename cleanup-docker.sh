#!/bin/bash

# Docker Cleanup Script for PowerChat Plus
# Fixes network subnet exhaustion issues

echo "🧹 Docker Cleanup Script for PowerChat Plus"
echo "============================================"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to show Docker resource usage
show_docker_usage() {
    echo
    print_status "Current Docker resource usage:"
    echo "Networks:"
    docker network ls | wc -l
    echo "Volumes:"
    docker volume ls | wc -l
    echo "Images:"
    docker images | wc -l
    echo "Containers:"
    docker ps -a | wc -l
    echo
}

# Function to clean up unused networks
cleanup_networks() {
    print_status "Cleaning up unused Docker networks..."
    
    # Show networks before cleanup
    local networks_before=$(docker network ls | wc -l)
    
    # Remove unused networks
    docker network prune -f
    
    # Show networks after cleanup
    local networks_after=$(docker network ls | wc -l)
    local removed=$((networks_before - networks_after))
    
    print_success "Removed $removed unused networks"
}

# Function to clean up unused volumes (with confirmation)
cleanup_volumes() {
    print_warning "This will remove ALL unused Docker volumes!"
    print_warning "This may delete data that is not currently mounted."
    echo -n "Are you sure you want to continue? (y/N): "
    read -r confirm
    
    if [[ $confirm =~ ^[Yy]$ ]]; then
        print_status "Cleaning up unused Docker volumes..."
        docker volume prune -f
        print_success "Unused volumes cleaned up"
    else
        print_status "Volume cleanup skipped"
    fi
}

# Function to clean up unused images
cleanup_images() {
    print_status "Cleaning up unused Docker images..."
    
    # Remove dangling images
    docker image prune -f
    
    print_success "Unused images cleaned up"
}

# Function to clean up stopped containers
cleanup_containers() {
    print_status "Cleaning up stopped containers..."
    
    # Remove stopped containers
    docker container prune -f
    
    print_success "Stopped containers cleaned up"
}

# Function to show PowerChat Plus specific resources
show_powerchat_resources() {
    print_status "PowerChat Plus specific resources:"
    echo
    echo "Networks:"
    docker network ls | grep powerchat || echo "No PowerChat networks found"
    echo
    echo "Volumes:"
    docker volume ls | grep powerchat || echo "No PowerChat volumes found"
    echo
    echo "Containers:"
    docker ps -a | grep powerchat || echo "No PowerChat containers found"
    echo
}

# Function to fix network subnet exhaustion
fix_network_exhaustion() {
    print_status "Fixing Docker network subnet exhaustion..."
    
    # Stop all PowerChat containers first
    print_status "Stopping PowerChat containers..."
    docker ps | grep powerchat | awk '{print $1}' | xargs -r docker stop
    
    # Remove PowerChat networks
    print_status "Removing PowerChat networks..."
    docker network ls | grep powerchat | awk '{print $1}' | xargs -r docker network rm
    
    # Clean up unused networks
    cleanup_networks
    
    # Restart Docker daemon (requires sudo)
    print_warning "You may need to restart Docker daemon to fully reset network pools"
    echo "Run: sudo systemctl restart docker"
    
    print_success "Network exhaustion fix completed"
}

# Main menu
case "${1:-menu}" in
    "networks")
        show_docker_usage
        cleanup_networks
        ;;
    "volumes")
        show_docker_usage
        cleanup_volumes
        ;;
    "images")
        show_docker_usage
        cleanup_images
        ;;
    "containers")
        show_docker_usage
        cleanup_containers
        ;;
    "all")
        show_docker_usage
        cleanup_networks
        cleanup_containers
        cleanup_images
        echo
        print_warning "Skipping volume cleanup (run with 'volumes' option if needed)"
        ;;
    "fix-networks")
        show_docker_usage
        fix_network_exhaustion
        ;;
    "status")
        show_docker_usage
        show_powerchat_resources
        ;;
    "help"|"-h"|"--help")
        cat << EOF
Docker Cleanup Script for PowerChat Plus

Usage: $0 [command]

Commands:
  networks      Clean up unused networks only
  volumes       Clean up unused volumes (with confirmation)
  images        Clean up unused images only
  containers    Clean up stopped containers only
  all           Clean up networks, containers, and images (not volumes)
  fix-networks  Fix network subnet exhaustion (stops PowerChat containers)
  status        Show current Docker resource usage
  help          Show this help message

Examples:
  $0 networks       # Clean up unused networks
  $0 fix-networks   # Fix subnet exhaustion
  $0 all           # Clean up most resources
  $0 status        # Show current usage

EOF
        ;;
    "menu"|*)
        echo
        print_status "Docker Cleanup Options:"
        echo "1. Clean up unused networks (recommended)"
        echo "2. Fix network subnet exhaustion"
        echo "3. Clean up all unused resources"
        echo "4. Show current status"
        echo "5. Exit"
        echo
        echo -n "Choose an option (1-5): "
        read -r choice
        
        case $choice in
            1)
                cleanup_networks
                ;;
            2)
                fix_network_exhaustion
                ;;
            3)
                show_docker_usage
                cleanup_networks
                cleanup_containers
                cleanup_images
                ;;
            4)
                show_docker_usage
                show_powerchat_resources
                ;;
            5)
                echo "Goodbye!"
                exit 0
                ;;
            *)
                print_error "Invalid option"
                exit 1
                ;;
        esac
        ;;
esac

echo
print_success "Docker cleanup completed!"
