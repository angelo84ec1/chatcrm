#!/bin/bash


echo "🔧 Fixing permissions for PowerChat Plus instances..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTANCES_DIR="$SCRIPT_DIR/instances"

if [ ! -d "$INSTANCES_DIR" ]; then
    echo "No instances directory found."
    exit 0
fi

for instance_dir in "$INSTANCES_DIR"/*; do
    if [ -d "$instance_dir" ]; then
        instance_name=$(basename "$instance_dir")
        echo "Fixing permissions for instance: $instance_name"
        
        docker-compose -f "$instance_dir/docker-compose.yml" down 2>/dev/null || true
        
        docker volume create "powerchat-app-backups-$instance_name" 2>/dev/null || true
        
        if ! grep -q "app_backups_$instance_name" "$instance_dir/docker-compose.yml"; then
            echo "Updating docker-compose.yml for $instance_name..."
            
            sed -i "/app_logs_$instance_name:\/app\/logs/a\\      - app_backups_$instance_name:/app/backups" "$instance_dir/docker-compose.yml"
            
            sed -i "/app_logs_$instance_name:/a\\  app_backups_$instance_name:\\
    driver: local\\
    name: powerchat-app-backups-$instance_name" "$instance_dir/docker-compose.yml"
        fi
        
        echo "Rebuilding and starting instance: $instance_name"
        docker-compose -f "$instance_dir/docker-compose.yml" up -d --build
        
        echo "✅ Fixed permissions for instance: $instance_name"
    fi
done

echo "🎉 Permission fixes completed!"
