#!/bin/bash
set -e

# MarketSage Monitoring Stack Entrypoint
echo "🚀 Starting MarketSage Monitoring Stack..."

# Function to wait for service to be ready
wait_for_service() {
    local service_name=$1
    local health_url=$2
    local max_attempts=30
    local attempt=1
    
    echo "⏳ Waiting for $service_name to be ready..."
    
    while [ $attempt -le $max_attempts ]; do
        if curl -f -s "$health_url" > /dev/null 2>&1; then
            echo "✅ $service_name is ready!"
            return 0
        fi
        
        echo "🔄 Attempt $attempt/$max_attempts: $service_name not ready yet..."
        sleep 5
        ((attempt++))
    done
    
    echo "❌ $service_name failed to become ready after $max_attempts attempts"
    return 1
}

# Function to check if required environment variables are set
check_environment() {
    echo "🔍 Checking environment configuration..."
    
    # Check if .env file exists, if not copy from example
    if [ ! -f .env ]; then
        echo "📋 Creating .env from example..."
        cp .env.example .env
    fi
    
    # Check if secrets directory exists, if not copy from example
    if [ ! -d secrets ]; then
        echo "🔐 Creating secrets from example..."
        cp -r secrets.example secrets
        echo "⚠️  Warning: Using example secrets. Please update with real credentials!"
    fi
    
    echo "✅ Environment configuration checked"
}

# Function to validate configurations before starting
validate_configs() {
    echo "🔧 Validating configurations..."
    
    # Validate docker-compose
    if ! docker-compose config --quiet; then
        echo "❌ Docker Compose configuration is invalid"
        exit 1
    fi
    
    echo "✅ All configurations are valid"
}

# Function to sync container IDs
sync_container_ids() {
    echo "🔄 Syncing with MarketSage container IDs..."
    
    if [ -f "./update-container-ids.sh" ]; then
        chmod +x ./update-container-ids.sh
        ./update-container-ids.sh
    else
        echo "⚠️  Container sync script not found - continuing without sync"
    fi
}

# Function to start monitoring services
start_monitoring() {
    echo "🎯 Starting monitoring services..."
    
    # Start services
    docker-compose up -d
    
    # Wait for core services to be ready
    wait_for_service "Prometheus" "http://localhost:9090/-/ready"
    wait_for_service "Loki" "http://localhost:3100/ready"
    wait_for_service "Grafana" "http://localhost:3000/api/health"
    wait_for_service "Alloy" "http://localhost:12345/-/healthy"
    
    # Sync with MarketSage containers after services are ready
    sync_container_ids
    
    echo "🎉 All monitoring services are ready!"
}

# Function to display service URLs
show_urls() {
    echo ""
    echo "📊 MarketSage Monitoring Stack is ready!"
    echo "=================================="
    echo "🏠 Grafana Dashboard: http://localhost:3000 (admin/admin)"
    echo "📈 Prometheus: http://localhost:9090"
    echo "📋 Loki Logs: http://localhost:3100"
    echo "🔔 Alertmanager: http://localhost:9093"
    echo "⚙️  Alloy Agent: http://localhost:12345"
    echo "=================================="
    echo ""
    echo "📖 Available Log Categories:"
    echo "  1. Application Logs: {job=\"docker\"}"
    echo "  2. System Logs: {job=\"system\"}"
    echo "  3. Security Logs: {job=\"security\"}"
    echo "  4. Error Logs: {job=\"errors\"}"
    echo "  5. Access Logs: {job=\"access\"}"
    echo "  6. Database Logs: {job=\"database\"}"
    echo "  7. Performance Logs: {job=\"performance\"}"
    echo "  8. Business Logs: {job=\"business\"}"
    echo ""
}

# Function to run health checks
health_check() {
    echo "🏥 Running health checks..."
    
    local failed_services=()
    
    # Check each service
    services=("Prometheus:http://localhost:9090/-/ready" 
              "Loki:http://localhost:3100/ready" 
              "Grafana:http://localhost:3000/api/health" 
              "Alloy:http://localhost:12345/-/healthy")
    
    for service_info in "${services[@]}"; do
        IFS=':' read -r service_name service_url <<< "$service_info"
        if ! curl -f -s "$service_url" > /dev/null 2>&1; then
            failed_services+=("$service_name")
        fi
    done
    
    if [ ${#failed_services[@]} -eq 0 ]; then
        echo "✅ All services are healthy"
        return 0
    else
        echo "❌ Failed services: ${failed_services[*]}"
        return 1
    fi
}

# Main execution
main() {
    case "${1:-start}" in
        start)
            check_environment
            validate_configs
            start_monitoring
            show_urls
            ;;
        health)
            health_check
            ;;
        stop)
            echo "🛑 Stopping monitoring services..."
            docker-compose down
            echo "✅ Services stopped"
            ;;
        restart)
            echo "🔄 Restarting monitoring services..."
            docker-compose down
            sleep 5
            start_monitoring
            show_urls
            ;;
        sync)
            sync_container_ids
            ;;
        logs)
            echo "📋 Showing service logs..."
            docker-compose logs -f
            ;;
        *)
            echo "Usage: $0 {start|stop|restart|health|logs|sync}"
            echo ""
            echo "Commands:"
            echo "  start   - Start the monitoring stack (default)"
            echo "  stop    - Stop all monitoring services"
            echo "  restart - Restart all monitoring services"
            echo "  health  - Check health of all services"
            echo "  logs    - Show logs from all services"
            echo "  sync    - Sync with MarketSage container IDs"
            exit 1
            ;;
    esac
}

# Execute main function with all arguments
main "$@"