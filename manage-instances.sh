#!/bin/bash


set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTANCES_DIR="$SCRIPT_DIR/instances"

print_header() {
    echo -e "\n${PURPLE}🔧 PowerChat Plus - Instance Manager${NC}\n"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_step() {
    echo -e "${CYAN}[STEP]${NC} $1"
}

validate_instance() {
    local instance_name="$1"
    local instance_dir="$INSTANCES_DIR/$instance_name"

    if [ ! -d "$instance_dir" ]; then
        print_error "Instance directory '$instance_name' not found"
        return 1
    fi

    if [ ! -f "$instance_dir/docker-compose.yml" ]; then
        print_error "docker-compose.yml not found in instance '$instance_name'"
        return 1
    fi

    if [ ! -f "$instance_dir/.env" ]; then
        print_error ".env file not found in instance '$instance_name'"
        return 1
    fi

    # Validate docker-compose.yml syntax
    if ! docker-compose -f "$instance_dir/docker-compose.yml" config > /dev/null 2>&1; then
        print_error "Invalid docker-compose.yml in instance '$instance_name'"
        return 1
    fi

    return 0
}

update_instance() {
    local instance_name="$1"
    local instance_dir="$INSTANCES_DIR/$instance_name"

    print_status "Updating instance '$instance_name'..."

    # Validate instance before updating
    if ! validate_instance "$instance_name"; then
        print_error "Validation failed for instance '$instance_name', skipping update"
        return 1
    fi

    # Check if Docker is running
    if ! docker info > /dev/null 2>&1; then
        print_error "Docker is not running or not accessible"
        return 1
    fi

    local update_failed=0
    local start_time=$(date +%s)

    # Step 1: Stop containers
    print_step "Stopping containers for '$instance_name'..."
    if ! docker-compose -f "$instance_dir/docker-compose.yml" down; then
        print_error "Failed to stop containers for '$instance_name'"
        update_failed=1
    else
        print_success "Containers stopped for '$instance_name'"
    fi

    # Step 2: Build images (only if stop was successful)
    if [ $update_failed -eq 0 ]; then
        print_step "Building images for '$instance_name'..."
        if ! docker-compose -f "$instance_dir/docker-compose.yml" build --no-cache; then
            print_error "Failed to build images for '$instance_name'"
            update_failed=1
        else
            print_success "Images built for '$instance_name'"
        fi
    fi

    # Step 3: Start containers (attempt even if build failed, in case old images work)
    print_step "Starting containers for '$instance_name'..."
    if ! docker-compose -f "$instance_dir/docker-compose.yml" up -d; then
        print_error "Failed to start containers for '$instance_name'"
        update_failed=1
    else
        print_success "Containers started for '$instance_name'"
    fi

    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    if [ $update_failed -eq 0 ]; then
        print_success "Instance '$instance_name' updated successfully in ${duration}s"
        return 0
    else
        print_error "Instance '$instance_name' update completed with errors in ${duration}s"
        return 1
    fi
}

confirm_update_all() {
    echo -e "${YELLOW}⚠️  WARNING: This will update ALL instances!${NC}"
    echo "This process will:"
    echo "  1. Stop all running containers"
    echo "  2. Rebuild all Docker images"
    echo "  3. Start all containers"
    echo
    echo "This may cause temporary downtime for all instances."
    echo
    read -p "Are you sure you want to continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status "Update cancelled by user"
        return 1
    fi
    return 0
}

update_all_instances() {
    local bulk_start_time=$(date +%s)
    print_status "Starting bulk update for all instances..."

    if [ ! -d "$INSTANCES_DIR" ] || [ -z "$(ls -A "$INSTANCES_DIR" 2>/dev/null)" ]; then
        print_warning "No instances found to update"
        echo
        echo "Deploy your first instance with: ./multi-instance-deploy.sh"
        return 0
    fi

    # Check if Docker is running
    if ! docker info > /dev/null 2>&1; then
        print_error "Docker is not running or not accessible"
        return 1
    fi

    local total_instances=0
    local successful_updates=0
    local failed_updates=0
    local failed_instances=()

    # Count total instances
    for instance_dir in "$INSTANCES_DIR"/*; do
        if [ -d "$instance_dir" ]; then
            total_instances=$((total_instances + 1))
        fi
    done

    print_status "Found $total_instances instance(s) to update"
    echo

    # Update each instance
    local current_instance=0
    for instance_dir in "$INSTANCES_DIR"/*; do
        if [ -d "$instance_dir" ]; then
            current_instance=$((current_instance + 1))
            local instance_name=$(basename "$instance_dir")

            echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo -e "${PURPLE}Updating Instance [$current_instance/$total_instances]: $instance_name${NC}"
            echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

            if update_instance "$instance_name"; then
                successful_updates=$((successful_updates + 1))
            else
                failed_updates=$((failed_updates + 1))
                failed_instances+=("$instance_name")
            fi

            echo
        fi
    done

    # Summary
    local bulk_end_time=$(date +%s)
    local bulk_duration=$((bulk_end_time - bulk_start_time))

    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${PURPLE}Bulk Update Summary${NC}"
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "Total instances: $total_instances"
    echo -e "${GREEN}Successful updates: $successful_updates${NC}"
    echo -e "${RED}Failed updates: $failed_updates${NC}"
    echo -e "Total time: ${bulk_duration}s"

    if [ $failed_updates -gt 0 ]; then
        echo
        echo -e "${RED}Failed instances:${NC}"
        for failed_instance in "${failed_instances[@]}"; do
            echo -e "  - $failed_instance"
        done
        echo
        echo -e "${YELLOW}Recommendation: Check the logs for failed instances and retry individual updates${NC}"
        return 1
    else
        echo
        print_success "All instances updated successfully!"
        return 0
    fi
}

list_instances() {
    if [ ! -d "$INSTANCES_DIR" ] || [ -z "$(ls -A "$INSTANCES_DIR" 2>/dev/null)" ]; then
        print_status "No instances found."
        echo
        echo "Deploy your first instance with: ./multi-instance-deploy.sh"
        return 0
    fi
    
    echo
    printf "%-20s %-10s %-10s %-15s %-12s %-30s\n" "INSTANCE" "APP_PORT" "DB_PORT" "STATUS" "CREATED" "URL"
    printf "%-20s %-10s %-10s %-15s %-12s %-30s\n" "--------" "--------" "-------" "------" "-------" "---"
    
    for instance_dir in "$INSTANCES_DIR"/*; do
        if [ -d "$instance_dir" ]; then
            local instance_name=$(basename "$instance_dir")
            local env_file="$instance_dir/.env"
            
            if [ -f "$env_file" ]; then
                local app_port=$(grep "^APP_PORT=" "$env_file" | cut -d'=' -f2)
                local db_port=$(grep "^DB_PORT=" "$env_file" | cut -d'=' -f2)
                local created_date=$(grep "^CREATED_DATE=" "$env_file" | cut -d'=' -f2 | cut -d'T' -f1)
                
                local status="Stopped"
                if docker-compose -f "$instance_dir/docker-compose.yml" ps | grep -q "Up"; then
                    status="Running"
                fi
                
                local url="http://localhost:$app_port"
                
                printf "%-20s %-10s %-10s %-15s %-12s %-30s\n" "$instance_name" "$app_port" "$db_port" "$status" "$created_date" "$url"
            fi
        fi
    done
    echo
}

manage_instance() {
    local instance_name="$1"
    local action="$2"
    
    if [ -z "$instance_name" ]; then
        print_error "Instance name required"
        return 1
    fi
    
    local instance_dir="$INSTANCES_DIR/$instance_name"
    
    if [ ! -d "$instance_dir" ]; then
        print_error "Instance '$instance_name' not found"
        echo
        echo "Available instances:"
        list_instances
        return 1
    fi
    
    case "$action" in
        "start")
            print_status "Starting instance '$instance_name'..."
            docker-compose -f "$instance_dir/docker-compose.yml" up -d
            print_success "Instance '$instance_name' started"
            ;;
        "stop")
            print_status "Stopping instance '$instance_name'..."
            docker-compose -f "$instance_dir/docker-compose.yml" down
            print_success "Instance '$instance_name' stopped"
            ;;
        "restart")
            print_status "Restarting instance '$instance_name'..."
            docker-compose -f "$instance_dir/docker-compose.yml" restart
            print_success "Instance '$instance_name' restarted"
            ;;
        "logs")
            echo "Following logs for instance '$instance_name' (Press Ctrl+C to stop)..."
            docker-compose -f "$instance_dir/docker-compose.yml" logs -f
            ;;
        "status")
            echo "Status for instance '$instance_name':"
            docker-compose -f "$instance_dir/docker-compose.yml" ps
            ;;
        "info")
            show_instance_info "$instance_name"
            ;;
        "backup")
            backup_instance "$instance_name"
            ;;
        "update")
            update_instance "$instance_name"
            ;;
        *)
            print_error "Unknown action: $action"
            echo "Available actions: start, stop, restart, logs, status, info, backup, update"
            return 1
            ;;
    esac
}

show_instance_info() {
    local instance_name="$1"
    local instance_dir="$INSTANCES_DIR/$instance_name"
    local env_file="$instance_dir/.env"
    
    if [ ! -f "$env_file" ]; then
        print_error "Instance configuration not found"
        return 1
    fi
    
    echo
    echo "Instance: $instance_name"
    echo "----------------------------------------"
    
    local app_port=$(grep "^APP_PORT=" "$env_file" | cut -d'=' -f2)
    local db_port=$(grep "^DB_PORT=" "$env_file" | cut -d'=' -f2)
    local admin_email=$(grep "^ADMIN_EMAIL=" "$env_file" | cut -d'=' -f2)
    local company_name=$(grep "^COMPANY_NAME=" "$env_file" | cut -d'=' -f2)
    local created_date=$(grep "^CREATED_DATE=" "$env_file" | cut -d'=' -f2)
    local database_name=$(grep "^POSTGRES_DB=" "$env_file" | cut -d'=' -f2)
    
    echo "Application URL: http://localhost:$app_port"
    echo "Database Port: $db_port"
    echo "Database Name: $database_name"
    echo "Admin Email: $admin_email"
    echo "Company: $company_name"
    echo "Created: $created_date"
    echo
    
    echo "Container Status:"
    docker-compose -f "$instance_dir/docker-compose.yml" ps
    echo
    
    echo "Resource Usage:"
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}" \
        $(docker-compose -f "$instance_dir/docker-compose.yml" ps -q) 2>/dev/null || echo "Containers not running"
    echo
}

backup_instance() {
    local instance_name="$1"
    local instance_dir="$INSTANCES_DIR/$instance_name"
    local backup_dir="$SCRIPT_DIR/backups/$instance_name"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    
    print_status "Creating backup for instance '$instance_name'..."
    
    mkdir -p "$backup_dir"
    
    print_status "Backing up database..."
    docker-compose -f "$instance_dir/docker-compose.yml" exec -T postgres-$instance_name \
        pg_dump -U powerchat $(grep "^POSTGRES_DB=" "$instance_dir/.env" | cut -d'=' -f2) \
        > "$backup_dir/database_$timestamp.sql"
    
    print_status "Backing up application data..."
    docker run --rm \
        -v powerchat-app-uploads-$instance_name:/data/uploads \
        -v powerchat-app-public-$instance_name:/data/public \
        -v "$backup_dir":/backup \
        alpine tar czf /backup/volumes_$timestamp.tar.gz -C /data .
    
    cp "$instance_dir/.env" "$backup_dir/config_$timestamp.env"
    cp "$instance_dir/docker-compose.yml" "$backup_dir/docker-compose_$timestamp.yml"
    
    print_success "Backup completed: $backup_dir/"
    echo "Files created:"
    echo "  - database_$timestamp.sql"
    echo "  - volumes_$timestamp.tar.gz"
    echo "  - config_$timestamp.env"
    echo "  - docker-compose_$timestamp.yml"
}

show_usage() {
    cat << EOF
PowerChat Plus Instance Manager

Usage: $0 <command> [options]

Commands:
  list                          List all instances with status
  start <instance>              Start an instance
  stop <instance>               Stop an instance
  restart <instance>            Restart an instance
  logs <instance>               Show logs for an instance
  status <instance>             Show status of an instance
  info <instance>               Show detailed information about an instance
  backup <instance>             Create backup of an instance
  update <instance>             Update a specific instance (down → build → up)
  start-all                     Start all instances
  stop-all                      Stop all instances
  update-all                    Update all instances (down → build → up for each)
  update-all --force            Update all instances without confirmation
  help                          Show this help message

Examples:
  $0 list
  $0 start my-company
  $0 logs my-company
  $0 info my-company
  $0 backup my-company
  $0 update my-company
  $0 update-all

Update Process:
  The update command performs these steps for each instance:
  1. Stop containers (docker-compose down)
  2. Build images (docker-compose build --no-cache)
  3. Start containers (docker-compose up -d)

EOF
}

case "${1:-help}" in
    "list")
        print_header
        list_instances
        ;;
    "start")
        print_header
        manage_instance "$2" "start"
        ;;
    "stop")
        print_header
        manage_instance "$2" "stop"
        ;;
    "restart")
        print_header
        manage_instance "$2" "restart"
        ;;
    "logs")
        manage_instance "$2" "logs"
        ;;
    "status")
        print_header
        manage_instance "$2" "status"
        ;;
    "info")
        print_header
        show_instance_info "$2"
        ;;
    "backup")
        print_header
        manage_instance "$2" "backup"
        ;;
    "update")
        print_header
        if [ -z "$2" ]; then
            print_error "Instance name required for update command"
            echo
            echo "Usage: $0 update <instance-name>"
            echo "   or: $0 update-all"
            exit 1
        fi
        manage_instance "$2" "update"
        ;;
    "update-all")
        print_header
        if [ "$2" = "--force" ]; then
            print_status "Force flag detected, skipping confirmation"
            update_all_instances
        elif confirm_update_all; then
            update_all_instances
        fi
        ;;
    "start-all")
        print_header
        print_status "Starting all instances..."
        if [ -d "$INSTANCES_DIR" ]; then
            for instance_dir in "$INSTANCES_DIR"/*; do
                if [ -d "$instance_dir" ]; then
                    local instance_name=$(basename "$instance_dir")
                    print_status "Starting $instance_name..."
                    docker-compose -f "$instance_dir/docker-compose.yml" up -d
                fi
            done
        fi
        print_success "All instances started"
        ;;
    "stop-all")
        print_header
        print_status "Stopping all instances..."
        if [ -d "$INSTANCES_DIR" ]; then
            for instance_dir in "$INSTANCES_DIR"/*; do
                if [ -d "$instance_dir" ]; then
                    local instance_name=$(basename "$instance_dir")
                    print_status "Stopping $instance_name..."
                    docker-compose -f "$instance_dir/docker-compose.yml" down
                fi
            done
        fi
        print_success "All instances stopped"
        ;;
    "help"|"-h"|"--help")
        show_usage
        ;;
    *)
        print_error "Unknown command: $1"
        echo
        show_usage
        exit 1
        ;;
esac
