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
        *)
            print_error "Unknown action: $action"
            echo "Available actions: start, stop, restart, logs, status, info, backup"
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
  start-all                     Start all instances
  stop-all                      Stop all instances
  help                          Show this help message

Examples:
  $0 list
  $0 start my-company
  $0 logs my-company
  $0 info my-company
  $0 backup my-company

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
