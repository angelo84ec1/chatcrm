#!/bin/bash

# Prompt or use first argument
DOMAIN="$1"

# Ask if not provided
if [[ -z "$DOMAIN" ]]; then
  read -rp "Enter domain to clean up (e.g. app.powerchatapp.net): " DOMAIN
fi

# Final validation
if [[ -z "$DOMAIN" ]]; then
  echo "❌ Domain is required. Exiting."
  exit 1
fi

echo "🛠 Cleaning up domain: $DOMAIN"

echo "🔍 Deleting from database..."
sqlite3 /www/server/panel/data/default.db "DELETE FROM sites WHERE name = '$DOMAIN';"
sqlite3 /www/server/panel/data/default.db "DELETE FROM domain WHERE name = '$DOMAIN';"
sqlite3 /www/server/panel/data/default.db "DELETE FROM ssl_info WHERE subject = '$DOMAIN';"
sqlite3 /www/server/panel/data/default.db "DELETE FROM dns_domain_task WHERE log_path LIKE '%$DOMAIN%';"

echo "🧹 Cleaning JSON config..."
sed -i "/$DOMAIN/d" /www/server/panel/data/search.json 2>/dev/null

echo "🗑️ Removing config and site files..."
rm -f /www/server/panel/vhost/nginx/$DOMAIN.conf
rm -f /www/server/panel/vhost/nginx/well-known/$DOMAIN.conf
rm -f /www/server/panel/vhost/openlitespeed/detail/$DOMAIN.conf
rm -f /www/server/panel/vhost/openlitespeed/detail/ssl/$DOMAIN.conf
rm -rf /www/wwwroot/$DOMAIN
rm -rf /www/server/proxy_project/sites/$DOMAIN

echo "🔄 Restarting aaPanel and NGINX..."
pkill -f BT-Panel
pkill -f gunicorn
sleep 2
bt start
nginx -t && nginx -s reload

echo "✅ Cleanup completed for $DOMAIN"
