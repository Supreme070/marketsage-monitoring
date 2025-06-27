#!/bin/bash
# Post-rebuild hook for MarketSage monitoring
# Call this from the monitoring directory after MarketSage containers are rebuilt
# Usage: ./post-rebuild-hook.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🚀 MarketSage Post-Rebuild Hook"
echo "==============================="

# Function to check if monitoring stack is running
check_monitoring_running() {
    if ! docker ps --format "{{.Names}}" | grep -q "prometheus\|grafana"; then
        echo "⚠️  Monitoring stack not running. Starting it first..."
        cd "$MONITORING_DIR"
        make start
        return $?
    fi
    return 0
}

# Function to wait for MarketSage containers to be ready
wait_for_marketsage() {
    echo "⏳ Waiting for MarketSage containers to be ready..."
    
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if docker ps --filter "name=marketsage-web" --format "{{.Names}}" | grep -q "marketsage-web"; then
            # Check if the web container is healthy
            if curl -f -s "http://localhost:3030/api/health" > /dev/null 2>&1; then
                echo "✅ MarketSage is ready!"
                return 0
            fi
        fi
        
        echo "🔄 Attempt $attempt/$max_attempts: MarketSage not ready yet..."
        sleep 5
        ((attempt++))
    done
    
    echo "❌ MarketSage failed to become ready after $max_attempts attempts"
    return 1
}

# Main execution
main() {
    echo "📍 Current working directory: $(pwd)"
    
    # Ensure we're in the monitoring directory
    cd "$SCRIPT_DIR"
    
    # Ensure monitoring stack is running
    if ! check_monitoring_running; then
        echo "❌ Failed to start monitoring stack"
        exit 1
    fi
    
    # Wait for MarketSage to be ready
    if wait_for_marketsage; then
        echo "🔄 Syncing monitoring with new MarketSage containers..."
        
        # Run the container ID sync
        make sync-containers
        
        echo ""
        echo "✅ Post-rebuild hook completed successfully!"
        echo "📊 Your monitoring dashboards are now synced with the rebuilt containers."
        echo ""
        echo "🔗 Access your monitoring at:"
        echo "   Grafana: http://localhost:3000 (admin/admin)"
        echo "   Prometheus: http://localhost:9090"
        echo ""
    else
        echo "❌ MarketSage containers are not ready. Please check the application deployment."
        exit 1
    fi
}

# Execute main function
main "$@"