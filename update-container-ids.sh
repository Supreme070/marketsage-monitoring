#!/bin/bash
# Script to update dashboard container IDs after MarketSage rebuild
# This script is automatically called by the monitoring stack

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

update_container_ids() {
    echo "🔍 Getting current MarketSage container IDs..."

    # Get current container IDs (handles both short and long IDs)
    WEB_ID=$(docker ps --filter "name=marketsage-web" --format "{{.ID}}" | head -1)
    DB_ID=$(docker ps --filter "name=marketsage-db" --format "{{.ID}}" | head -1)
    REDIS_ID=$(docker ps --filter "name=marketsage-valkey" --format "{{.ID}}" | head -1)

    echo "📊 Current container IDs:"
    echo "  Web: $WEB_ID"
    echo "  DB: $DB_ID" 
    echo "  Redis: $REDIS_ID"

    # Check if MarketSage containers are running
    if [ -z "$WEB_ID" ]; then
        echo "⚠️  MarketSage web container not found - monitoring will use general container metrics"
        return 0
    fi

    echo "🔧 Updating dashboard configurations..."

    # Update System Overview dashboard
    if [ -f "$SCRIPT_DIR/grafana/dashboards/marketsage-overview.json" ]; then
        # Create backup
        cp "$SCRIPT_DIR/grafana/dashboards/marketsage-overview.json" "$SCRIPT_DIR/grafana/dashboards/marketsage-overview.json.bak"
        
        # Update with new container IDs (match any existing pattern)
        sed -i '' "s|/docker/[a-f0-9]*|/docker/$WEB_ID|g" "$SCRIPT_DIR/grafana/dashboards/marketsage-overview.json"
        echo "✅ Updated System Overview dashboard"
    fi

    # Update Performance Metrics dashboard
    if [ -f "$SCRIPT_DIR/grafana/dashboards/metrics-performance.json" ]; then
        cp "$SCRIPT_DIR/grafana/dashboards/metrics-performance.json" "$SCRIPT_DIR/grafana/dashboards/metrics-performance.json.bak"
        sed -i '' "s|/docker/[a-f0-9]*|/docker/$WEB_ID|g" "$SCRIPT_DIR/grafana/dashboards/metrics-performance.json"
        echo "✅ Updated Performance Metrics dashboard"
    fi

    # Update alert rules for web container
    if [ -f "$SCRIPT_DIR/alloy/rules/marketsage-alerts.yml" ]; then
        cp "$SCRIPT_DIR/alloy/rules/marketsage-alerts.yml" "$SCRIPT_DIR/alloy/rules/marketsage-alerts.yml.bak"
        sed -i '' "s|/docker/[a-f0-9]*|/docker/$WEB_ID|g" "$SCRIPT_DIR/alloy/rules/marketsage-alerts.yml"
        echo "✅ Updated alert rules"
    fi

    echo "✅ Container IDs updated successfully!"
    
    # Reload Prometheus if it's running
    if docker ps --format "{{.Names}}" | grep -q "prometheus"; then
        echo "🔄 Reloading Prometheus configuration..."
        docker exec prometheus kill -HUP 1 2>/dev/null || echo "⚠️  Could not reload Prometheus - restart may be needed"
    fi
    
    return 0
}

# Main execution
if [ "${1:-update}" = "update" ]; then
    update_container_ids
else
    echo "Usage: $0 [update]"
    echo "Automatically updates monitoring dashboards with current MarketSage container IDs"
fi