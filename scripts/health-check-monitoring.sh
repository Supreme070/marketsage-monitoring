#!/bin/bash

# MarketSage Monitoring Health Check Script
# Monitors the health of monitoring components themselves

set -euo pipefail

# Configuration
HEALTH_CHECK_INTERVAL=60
LOG_FILE="/var/log/monitoring-health.log"
ALERT_WEBHOOK_URL="${SLACK_WEBHOOK_URL:-}"
METRICS_FILE="/var/lib/monitoring/health-metrics.prom"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Logging
log() {
    echo -e "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

error_exit() {
    log "${RED}ERROR: $1${NC}"
    exit 1
}

success() {
    log "${GREEN}SUCCESS: $1${NC}"
}

warning() {
    log "${YELLOW}WARNING: $1${NC}"
}

# Health check functions
check_container_health() {
    local container=$1
    local expected_status="running"
    
    if docker ps --filter "name=$container" --filter "status=running" --format "table {{.Names}}" | grep -q "$container"; then
        echo "1"
    else
        echo "0"
    fi
}

check_http_endpoint() {
    local url=$1
    local expected_code=${2:-200}
    local timeout=${3:-10}
    
    if curl -s -o /dev/null -w "%{http_code}" --connect-timeout "$timeout" "$url" | grep -q "$expected_code"; then
        echo "1"
    else
        echo "0"
    fi
}

check_prometheus_health() {
    log "Checking Prometheus health..."
    
    local container_health=$(check_container_health "prometheus")
    local api_health=$(check_http_endpoint "http://localhost:9090/-/healthy")
    local ready_health=$(check_http_endpoint "http://localhost:9090/-/ready")
    
    # Check if Prometheus can query itself
    local query_health="0"
    if curl -s "http://localhost:9090/api/v1/query?query=up" | grep -q '"status":"success"'; then
        query_health="1"
    fi
    
    # Check TSDB health
    local tsdb_health="0"
    local tsdb_info=$(curl -s "http://localhost:9090/api/v1/status/tsdb" || echo "")
    if echo "$tsdb_info" | grep -q '"status":"success"'; then
        tsdb_health="1"
    fi
    
    # Update metrics
    cat >> "$METRICS_FILE" << EOF
# HELP monitoring_prometheus_container_health Prometheus container health status
# TYPE monitoring_prometheus_container_health gauge
monitoring_prometheus_container_health $container_health

# HELP monitoring_prometheus_api_health Prometheus API health status
# TYPE monitoring_prometheus_api_health gauge
monitoring_prometheus_api_health $api_health

# HELP monitoring_prometheus_ready_health Prometheus ready status
# TYPE monitoring_prometheus_ready_health gauge
monitoring_prometheus_ready_health $ready_health

# HELP monitoring_prometheus_query_health Prometheus query capability
# TYPE monitoring_prometheus_query_health gauge
monitoring_prometheus_query_health $query_health

# HELP monitoring_prometheus_tsdb_health Prometheus TSDB health
# TYPE monitoring_prometheus_tsdb_health gauge
monitoring_prometheus_tsdb_health $tsdb_health

EOF

    if [[ "$container_health" == "1" && "$api_health" == "1" && "$ready_health" == "1" ]]; then
        success "Prometheus is healthy"
        return 0
    else
        warning "Prometheus health issues detected"
        return 1
    fi
}

check_grafana_health() {
    log "Checking Grafana health..."
    
    local container_health=$(check_container_health "grafana")
    local api_health=$(check_http_endpoint "http://localhost:3000/api/health")
    
    # Check database connectivity
    local db_health="0"
    if curl -s -u "admin:admin" "http://localhost:3000/api/datasources" | grep -q "prometheus"; then
        db_health="1"
    fi
    
    # Check dashboard count
    local dashboard_count="0"
    dashboard_info=$(curl -s -u "admin:admin" "http://localhost:3000/api/search?type=dash-db" || echo "[]")
    dashboard_count=$(echo "$dashboard_info" | grep -o '"id":' | wc -l)
    
    cat >> "$METRICS_FILE" << EOF
# HELP monitoring_grafana_container_health Grafana container health status
# TYPE monitoring_grafana_container_health gauge
monitoring_grafana_container_health $container_health

# HELP monitoring_grafana_api_health Grafana API health status
# TYPE monitoring_grafana_api_health gauge
monitoring_grafana_api_health $api_health

# HELP monitoring_grafana_db_health Grafana database connectivity
# TYPE monitoring_grafana_db_health gauge
monitoring_grafana_db_health $db_health

# HELP monitoring_grafana_dashboard_count Number of Grafana dashboards
# TYPE monitoring_grafana_dashboard_count gauge
monitoring_grafana_dashboard_count $dashboard_count

EOF

    if [[ "$container_health" == "1" && "$api_health" == "1" ]]; then
        success "Grafana is healthy ($dashboard_count dashboards)"
        return 0
    else
        warning "Grafana health issues detected"
        return 1
    fi
}

check_loki_health() {
    log "Checking Loki health..."
    
    local container_health=$(check_container_health "loki")
    local api_health=$(check_http_endpoint "http://localhost:3100/ready")
    
    # Check ingester health
    local ingester_health="0"
    if curl -s "http://localhost:3100/metrics" | grep -q "loki_ingester_chunks_created_total"; then
        ingester_health="1"
    fi
    
    cat >> "$METRICS_FILE" << EOF
# HELP monitoring_loki_container_health Loki container health status
# TYPE monitoring_loki_container_health gauge
monitoring_loki_container_health $container_health

# HELP monitoring_loki_api_health Loki API health status
# TYPE monitoring_loki_api_health gauge
monitoring_loki_api_health $api_health

# HELP monitoring_loki_ingester_health Loki ingester health status
# TYPE monitoring_loki_ingester_health gauge
monitoring_loki_ingester_health $ingester_health

EOF

    if [[ "$container_health" == "1" && "$api_health" == "1" ]]; then
        success "Loki is healthy"
        return 0
    else
        warning "Loki health issues detected"
        return 1
    fi
}

check_tempo_health() {
    log "Checking Tempo health..."
    
    local container_health=$(check_container_health "tempo")
    local api_health=$(check_http_endpoint "http://localhost:3200/ready")
    
    # Check if Tempo is receiving traces
    local traces_health="0"
    if curl -s "http://localhost:3200/metrics" | grep -q "tempo_ingester_traces_created_total"; then
        traces_health="1"
    fi
    
    cat >> "$METRICS_FILE" << EOF
# HELP monitoring_tempo_container_health Tempo container health status
# TYPE monitoring_tempo_container_health gauge
monitoring_tempo_container_health $container_health

# HELP monitoring_tempo_api_health Tempo API health status
# TYPE monitoring_tempo_api_health gauge
monitoring_tempo_api_health $api_health

# HELP monitoring_tempo_traces_health Tempo traces ingestion health
# TYPE monitoring_tempo_traces_health gauge
monitoring_tempo_traces_health $traces_health

EOF

    if [[ "$container_health" == "1" && "$api_health" == "1" ]]; then
        success "Tempo is healthy"
        return 0
    else
        warning "Tempo health issues detected"
        return 1
    fi
}

check_alertmanager_health() {
    log "Checking Alertmanager health..."
    
    local container_health=$(check_container_health "alertmanager")
    local api_health=$(check_http_endpoint "http://localhost:9093/-/healthy")
    
    # Check silences and alerts
    local silences_health="0"
    if curl -s "http://localhost:9093/api/v1/silences" | grep -q '"status":"success"'; then
        silences_health="1"
    fi
    
    cat >> "$METRICS_FILE" << EOF
# HELP monitoring_alertmanager_container_health Alertmanager container health status
# TYPE monitoring_alertmanager_container_health gauge
monitoring_alertmanager_container_health $container_health

# HELP monitoring_alertmanager_api_health Alertmanager API health status
# TYPE monitoring_alertmanager_api_health gauge
monitoring_alertmanager_api_health $api_health

# HELP monitoring_alertmanager_silences_health Alertmanager silences API health
# TYPE monitoring_alertmanager_silences_health gauge
monitoring_alertmanager_silences_health $silences_health

EOF

    if [[ "$container_health" == "1" && "$api_health" == "1" ]]; then
        success "Alertmanager is healthy"
        return 0
    else
        warning "Alertmanager health issues detected"
        return 1
    fi
}

check_business_metrics_exporter() {
    log "Checking Business Metrics Exporter health..."
    
    local container_health=$(check_container_health "business-metrics-exporter")
    local api_health=$(check_http_endpoint "http://localhost:8081/health")
    
    # Check if metrics are being generated
    local metrics_health="0"
    if curl -s "http://localhost:8081/metrics" | grep -q "marketsage_total_users"; then
        metrics_health="1"
    fi
    
    cat >> "$METRICS_FILE" << EOF
# HELP monitoring_business_metrics_container_health Business metrics exporter container health
# TYPE monitoring_business_metrics_container_health gauge
monitoring_business_metrics_container_health $container_health

# HELP monitoring_business_metrics_api_health Business metrics exporter API health
# TYPE monitoring_business_metrics_api_health gauge
monitoring_business_metrics_api_health $api_health

# HELP monitoring_business_metrics_generation_health Business metrics generation health
# TYPE monitoring_business_metrics_generation_health gauge
monitoring_business_metrics_generation_health $metrics_health

EOF

    if [[ "$container_health" == "1" && "$api_health" == "1" ]]; then
        success "Business Metrics Exporter is healthy"
        return 0
    else
        warning "Business Metrics Exporter health issues detected"
        return 1
    fi
}

check_synthetic_monitoring() {
    log "Checking Synthetic Monitoring health..."
    
    local container_health=$(check_container_health "synthetic-monitoring")
    local api_health=$(check_http_endpoint "http://localhost:8082/health")
    
    # Check if synthetic checks are running
    local checks_health="0"
    if curl -s "http://localhost:8082/metrics" | grep -q "marketsage_uptime_status"; then
        checks_health="1"
    fi
    
    cat >> "$METRICS_FILE" << EOF
# HELP monitoring_synthetic_monitoring_container_health Synthetic monitoring container health
# TYPE monitoring_synthetic_monitoring_container_health gauge
monitoring_synthetic_monitoring_container_health $container_health

# HELP monitoring_synthetic_monitoring_api_health Synthetic monitoring API health
# TYPE monitoring_synthetic_monitoring_api_health gauge
monitoring_synthetic_monitoring_api_health $api_health

# HELP monitoring_synthetic_monitoring_checks_health Synthetic checks execution health
# TYPE monitoring_synthetic_monitoring_checks_health gauge
monitoring_synthetic_monitoring_checks_health $checks_health

EOF

    if [[ "$container_health" == "1" && "$api_health" == "1" ]]; then
        success "Synthetic Monitoring is healthy"
        return 0
    else
        warning "Synthetic Monitoring health issues detected"
        return 1
    fi
}

# Resource usage checks
check_resource_usage() {
    log "Checking resource usage..."
    
    # CPU usage
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//')
    
    # Memory usage
    local memory_usage=$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100.0}')
    
    # Disk usage
    local disk_usage=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
    
    cat >> "$METRICS_FILE" << EOF
# HELP monitoring_host_cpu_usage_percent Host CPU usage percentage
# TYPE monitoring_host_cpu_usage_percent gauge
monitoring_host_cpu_usage_percent ${cpu_usage:-0}

# HELP monitoring_host_memory_usage_percent Host memory usage percentage
# TYPE monitoring_host_memory_usage_percent gauge
monitoring_host_memory_usage_percent ${memory_usage:-0}

# HELP monitoring_host_disk_usage_percent Host disk usage percentage
# TYPE monitoring_host_disk_usage_percent gauge
monitoring_host_disk_usage_percent ${disk_usage:-0}

EOF

    # Alert on high resource usage
    if [[ $(echo "$memory_usage > 90" | bc -l 2>/dev/null || echo 0) -eq 1 ]]; then
        warning "High memory usage: ${memory_usage}%"
        send_alert "High Memory Usage" "Memory usage is ${memory_usage}% on monitoring host"
    fi
    
    if [[ $disk_usage -gt 85 ]]; then
        warning "High disk usage: ${disk_usage}%"
        send_alert "High Disk Usage" "Disk usage is ${disk_usage}% on monitoring host"
    fi
}

# Send alert to Slack
send_alert() {
    local title="$1"
    local message="$2"
    
    if [[ -n "$ALERT_WEBHOOK_URL" ]]; then
        curl -X POST -H 'Content-type: application/json' \
            --data "{\"text\":\"🚨 **$title**\n$message\n\nHost: $(hostname)\nTime: $(date)\"}" \
            "$ALERT_WEBHOOK_URL" || warning "Failed to send alert to Slack"
    fi
}

# Generate health summary
generate_health_summary() {
    log "Generating health summary..."
    
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local total_services=7
    local healthy_services=0
    local unhealthy_services=()
    
    # Check each service and count healthy ones
    if check_prometheus_health; then ((healthy_services++)); else unhealthy_services+=("Prometheus"); fi
    if check_grafana_health; then ((healthy_services++)); else unhealthy_services+=("Grafana"); fi
    if check_loki_health; then ((healthy_services++)); else unhealthy_services+=("Loki"); fi
    if check_tempo_health; then ((healthy_services++)); else unhealthy_services+=("Tempo"); fi
    if check_alertmanager_health; then ((healthy_services++)); else unhealthy_services+=("Alertmanager"); fi
    if check_business_metrics_exporter; then ((healthy_services++)); else unhealthy_services+=("Business Metrics"); fi
    if check_synthetic_monitoring; then ((healthy_services++)); else unhealthy_services+=("Synthetic Monitoring"); fi
    
    # Check resource usage
    check_resource_usage
    
    # Add summary metrics
    cat >> "$METRICS_FILE" << EOF
# HELP monitoring_health_check_timestamp Last health check timestamp
# TYPE monitoring_health_check_timestamp gauge
monitoring_health_check_timestamp $(date +%s)

# HELP monitoring_services_healthy_total Number of healthy monitoring services
# TYPE monitoring_services_healthy_total gauge
monitoring_services_healthy_total $healthy_services

# HELP monitoring_services_total Total number of monitoring services
# TYPE monitoring_services_total gauge
monitoring_services_total $total_services

# HELP monitoring_stack_health_percent Overall monitoring stack health percentage
# TYPE monitoring_stack_health_percent gauge
monitoring_stack_health_percent $(echo "scale=1; $healthy_services * 100 / $total_services" | bc)

EOF

    # Log summary
    local health_percentage=$(echo "scale=1; $healthy_services * 100 / $total_services" | bc)
    log "Health Summary: $healthy_services/$total_services services healthy (${health_percentage}%)"
    
    if [[ ${#unhealthy_services[@]} -gt 0 ]]; then
        warning "Unhealthy services: ${unhealthy_services[*]}"
        
        # Send alert if multiple services are down
        if [[ ${#unhealthy_services[@]} -ge 2 ]]; then
            send_alert "Multiple Monitoring Services Down" "Unhealthy services: ${unhealthy_services[*]}"
        fi
    else
        success "All monitoring services are healthy"
    fi
    
    # Make metrics available to Prometheus
    chmod 644 "$METRICS_FILE"
}

# Main monitoring loop
monitoring_loop() {
    log "Starting monitoring health check loop..."
    
    while true; do
        # Clear previous metrics
        mkdir -p "$(dirname "$METRICS_FILE")"
        > "$METRICS_FILE"
        
        generate_health_summary
        
        log "Health check completed. Next check in ${HEALTH_CHECK_INTERVAL} seconds."
        sleep "$HEALTH_CHECK_INTERVAL"
    done
}

# One-time health check
one_time_check() {
    log "Running one-time health check..."
    
    mkdir -p "$(dirname "$METRICS_FILE")"
    > "$METRICS_FILE"
    
    generate_health_summary
    
    log "One-time health check completed"
}

# Setup systemd service for continuous monitoring
setup_service() {
    log "Setting up systemd service for continuous monitoring..."
    
    cat > /etc/systemd/system/marketsage-monitoring-health.service << EOF
[Unit]
Description=MarketSage Monitoring Health Check
After=docker.service
Requires=docker.service

[Service]
Type=simple
ExecStart=/opt/marketsage-monitoring/scripts/health-check-monitoring.sh loop
Restart=always
RestartSec=30
User=root
StandardOutput=journal
StandardError=journal
Environment=SLACK_WEBHOOK_URL=${ALERT_WEBHOOK_URL}

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable marketsage-monitoring-health.service
    systemctl start marketsage-monitoring-health.service
    
    success "Systemd service configured and started"
}

# Main function
main() {
    case "${1:-check}" in
        "loop")
            monitoring_loop
            ;;
        "check")
            one_time_check
            ;;
        "setup")
            setup_service
            ;;
        *)
            echo "Usage: $0 {check|loop|setup}"
            echo "  check - Run one-time health check (default)"
            echo "  loop  - Run continuous monitoring loop"
            echo "  setup - Setup systemd service for continuous monitoring"
            exit 1
            ;;
    esac
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi