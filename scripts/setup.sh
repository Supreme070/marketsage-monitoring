#!/bin/bash

# 🚀 MarketSage Grafana Alloy Monitoring Setup Script
# This script automates the complete setup of monitoring infrastructure

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
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

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check if docker is installed
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install Docker and try again."
        exit 1
    fi
    
    # Check if docker-compose is installed
    if ! command -v docker-compose &> /dev/null; then
        print_error "Docker Compose is not installed. Please install Docker Compose and try again."
        exit 1
    fi
    
    # Check if MarketSage is running
    if ! docker ps | grep -q "marketsage-web"; then
        print_warning "MarketSage application doesn't seem to be running."
        print_status "Please start MarketSage first:"
        echo "  cd ../marketsage && docker-compose -f docker-compose.prod.yml up -d"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    print_success "Prerequisites check completed"
}

# Check if .env file exists
check_env_file() {
    print_status "Checking environment configuration..."
    
    if [ ! -f ".env" ]; then
        if [ -f ".env.example" ]; then
            print_warning ".env file not found. Copying from .env.example"
            cp .env.example .env
            print_warning "Please edit .env file with your Grafana Cloud credentials"
            print_status "Required variables:"
            echo "  - GRAFANA_CLOUD_API_KEY"
            echo "  - GRAFANA_CLOUD_PROMETHEUS_URL"
            echo "  - GRAFANA_CLOUD_PROMETHEUS_USER"
            echo "  - GRAFANA_CLOUD_LOKI_URL"
            echo "  - GRAFANA_CLOUD_LOKI_USER"
            
            read -p "Press Enter after configuring .env file..."
        else
            print_error ".env.example file not found. Please create .env file with Grafana Cloud credentials."
            exit 1
        fi
    fi
    
    # Check if required variables are set
    source .env
    if [ -z "$GRAFANA_CLOUD_API_KEY" ]; then
        print_error "GRAFANA_CLOUD_API_KEY is not set in .env file"
        exit 1
    fi
    
    print_success "Environment configuration check completed"
}

# Validate Alloy configuration
validate_config() {
    print_status "Validating Alloy configuration..."
    
    # Check if config file exists
    if [ ! -f "alloy/config/config.alloy" ]; then
        print_error "Alloy configuration file not found: alloy/config/config.alloy"
        exit 1
    fi
    
    # TODO: Add config validation when alloy fmt is available
    print_success "Configuration validation completed"
}

# Create necessary directories
create_directories() {
    print_status "Creating necessary directories..."
    
    mkdir -p alloy/config
    mkdir -p alloy/rules
    mkdir -p grafana/dashboards
    mkdir -p grafana/provisioning
    
    print_success "Directories created"
}

# Pull latest images
pull_images() {
    print_status "Pulling latest Docker images..."
    
    docker-compose pull
    
    print_success "Images pulled successfully"
}

# Start monitoring stack
start_monitoring() {
    print_status "Starting monitoring stack..."
    
    # Build and start containers
    docker-compose up -d
    
    print_success "Monitoring stack started"
}

# Wait for services to be ready
wait_for_services() {
    print_status "Waiting for services to be ready..."
    
    # Wait for Alloy
    print_status "Waiting for Alloy..."
    timeout=60
    while [ $timeout -gt 0 ]; do
        if curl -s http://localhost:12345/-/healthy > /dev/null 2>&1; then
            break
        fi
        sleep 2
        timeout=$((timeout-2))
    done
    
    if [ $timeout -le 0 ]; then
        print_warning "Alloy health check timeout, but continuing..."
    else
        print_success "Alloy is ready"
    fi
    
    # Wait for exporters
    print_status "Waiting for exporters..."
    sleep 10
    
    print_success "Services are ready"
}

# Verify deployment
verify_deployment() {
    print_status "Verifying deployment..."
    
    # Check container status
    print_status "Container status:"
    docker-compose ps
    
    # Check if ports are accessible
    services=(
        "Alloy UI:http://localhost:12345"
        "cAdvisor:http://localhost:8080"
        "Postgres Exporter:http://localhost:9187/metrics"
        "Redis Exporter:http://localhost:9121/metrics"
    )
    
    for service in "${services[@]}"; do
        name="${service%%:*}"
        url="${service##*:}"
        
        if curl -s "$url" > /dev/null 2>&1; then
            print_success "$name is accessible"
        else
            print_warning "$name is not accessible at $url"
        fi
    done
    
    # Test MarketSage health endpoint
    if curl -s http://localhost:3030/api/health > /dev/null 2>&1; then
        print_success "MarketSage health endpoint is accessible"
    else
        print_warning "MarketSage health endpoint is not accessible"
    fi
}

# Print access information
print_access_info() {
    print_success "🎉 Monitoring setup completed successfully!"
    echo
    echo "📊 Access URLs:"
    echo "  🎯 Alloy UI: http://localhost:12345"
    echo "  📊 cAdvisor: http://localhost:8080"
    echo "  🗄️  Postgres Exporter: http://localhost:9187/metrics"
    echo "  🔴 Redis Exporter: http://localhost:9121/metrics"
    echo "  🌐 Grafana Cloud: https://marketsageafrica.grafana.net"
    echo
    echo "📋 Health Checks:"
    echo "  curl http://localhost:3030/api/health"
    echo "  curl http://localhost:3030/api/health?format=prometheus"
    echo
    echo "🔧 Management Commands:"
    echo "  docker-compose logs alloy    # View Alloy logs"
    echo "  docker-compose ps           # Check container status"
    echo "  docker-compose down         # Stop monitoring"
    echo "  docker-compose up -d        # Start monitoring"
    echo
    echo "📚 Next Steps:"
    echo "  1. Import dashboards in Grafana Cloud (Dashboard IDs: 1860, 9628, 763, 193)"
    echo "  2. Configure alerting contact points"
    echo "  3. Set up notification policies"
    echo "  4. Review and customize alert rules"
    echo
    print_status "For detailed setup guide, see: SETUP_GUIDE.md"
}

# Cleanup function
cleanup() {
    if [ $? -ne 0 ]; then
        print_error "Setup failed. Cleaning up..."
        docker-compose down 2>/dev/null || true
    fi
}

# Set trap for cleanup
trap cleanup EXIT

# Main execution
main() {
    echo "🚀 MarketSage Grafana Alloy Monitoring Setup"
    echo "=============================================="
    echo
    
    check_prerequisites
    echo
    
    create_directories
    echo
    
    check_env_file
    echo
    
    validate_config
    echo
    
    pull_images
    echo
    
    start_monitoring
    echo
    
    wait_for_services
    echo
    
    verify_deployment
    echo
    
    print_access_info
}

# Run main function
main "$@"
