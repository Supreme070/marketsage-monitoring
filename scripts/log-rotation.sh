#!/bin/bash

# MarketSage Monitoring Log Rotation Script
# Manages log rotation for all monitoring services

set -euo pipefail

# Configuration
LOG_BASE_DIR="/var/log/monitoring"
RETENTION_DAYS=30
COMPRESS_LOGS=true
LOG_FILE="/var/log/log-rotation.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Logging function
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

# Create logrotate configuration
create_logrotate_config() {
    log "Creating logrotate configuration..."
    
    cat > /etc/logrotate.d/marketsage-monitoring << 'EOF'
# MarketSage Monitoring Log Rotation Configuration

# Docker container logs
/var/lib/docker/containers/*/*-json.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 0644 root root
    postrotate
        docker kill --signal="USR1" $(docker ps -q) 2>/dev/null || true
    endscript
}

# Application logs
/var/log/monitoring/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 0644 root root
    sharedscripts
    postrotate
        systemctl reload rsyslog 2>/dev/null || true
    endscript
}

# Prometheus logs
/var/log/prometheus/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 0644 nobody nogroup
    postrotate
        docker kill --signal="USR1" prometheus 2>/dev/null || true
    endscript
}

# Grafana logs
/var/log/grafana/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 0644 grafana grafana
    postrotate
        docker kill --signal="USR1" grafana 2>/dev/null || true
    endscript
}

# Loki logs
/var/log/loki/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 0644 root root
    postrotate
        docker kill --signal="USR1" loki 2>/dev/null || true
    endscript
}

# Alertmanager logs
/var/log/alertmanager/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 0644 root root
    postrotate
        docker kill --signal="USR1" alertmanager 2>/dev/null || true
    endscript
}

# Business metrics exporter logs
/var/log/business-metrics/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 0644 root root
    postrotate
        docker kill --signal="USR1" business-metrics-exporter 2>/dev/null || true
    endscript
}

# Synthetic monitoring logs
/var/log/synthetic-monitoring/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 0644 root root
    postrotate
        docker kill --signal="USR1" synthetic-monitoring 2>/dev/null || true
    endscript
}
EOF
    
    success "Logrotate configuration created"
}

# Manual log rotation for immediate cleanup
manual_log_rotation() {
    log "Performing manual log rotation..."
    
    # Create directories if they don't exist
    mkdir -p "$LOG_BASE_DIR"/{prometheus,grafana,loki,alertmanager,business-metrics,synthetic-monitoring}
    
    # Function to rotate logs for a service
    rotate_service_logs() {
        local service=$1
        local log_dir="$LOG_BASE_DIR/$service"
        
        if [[ ! -d "$log_dir" ]]; then
            warning "Log directory $log_dir does not exist"
            return
        fi
        
        log "Rotating logs for $service..."
        
        # Find and rotate .log files
        find "$log_dir" -name "*.log" -type f | while read -r logfile; do
            if [[ -s "$logfile" ]]; then
                # Create timestamp for rotation
                timestamp=$(date +"%Y%m%d_%H%M%S")
                rotated_name="${logfile}.${timestamp}"
                
                # Copy current log and truncate
                cp "$logfile" "$rotated_name"
                > "$logfile"
                
                # Compress if enabled
                if [[ "$COMPRESS_LOGS" == "true" ]]; then
                    gzip "$rotated_name"
                    rotated_name="${rotated_name}.gz"
                fi
                
                log "Rotated: $(basename "$logfile") -> $(basename "$rotated_name")"
            fi
        done
        
        # Clean old logs
        find "$log_dir" -name "*.log.*" -type f -mtime +$RETENTION_DAYS -delete
        
        # Signal service to reopen log files
        docker kill --signal="USR1" "$service" 2>/dev/null || warning "Could not signal $service"
    }
    
    # Rotate logs for each service
    for service in prometheus grafana loki alertmanager business-metrics-exporter synthetic-monitoring; do
        rotate_service_logs "$service"
    done
    
    success "Manual log rotation completed"
}

# Clean docker logs
clean_docker_logs() {
    log "Cleaning Docker container logs..."
    
    # Get all container IDs
    containers=$(docker ps -aq)
    
    for container in $containers; do
        container_name=$(docker inspect --format='{{.Name}}' "$container" | sed 's/^\//')
        log_file="/var/lib/docker/containers/$container/$container-json.log"
        
        if [[ -f "$log_file" ]]; then
            log_size=$(du -h "$log_file" | cut -f1)
            
            # If log file is larger than 100MB, truncate it
            if [[ $(du -k "$log_file" | cut -f1) -gt 102400 ]]; then
                log "Truncating large log file for container $container_name ($log_size)"
                > "$log_file"
            fi
        fi
    done
    
    success "Docker log cleanup completed"
}

# Monitor disk usage
monitor_disk_usage() {
    log "Monitoring disk usage..."
    
    # Check overall disk usage
    disk_usage=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
    
    if [[ $disk_usage -gt 85 ]]; then
        warning "High disk usage detected: ${disk_usage}%"
        
        # Find largest log files
        log "Largest log files:"
        find /var/log -name "*.log*" -type f -exec du -h {} + 2>/dev/null | sort -hr | head -10 | while read -r size file; do
            log "  $size - $file"
        done
        
        # Find largest docker logs
        log "Largest Docker logs:"
        find /var/lib/docker/containers -name "*-json.log" -type f -exec du -h {} + 2>/dev/null | sort -hr | head -5 | while read -r size file; do
            container_id=$(basename "$(dirname "$file")")
            container_name=$(docker inspect --format='{{.Name}}' "$container_id" 2>/dev/null | sed 's/^\//' || echo "unknown")
            log "  $size - $container_name ($container_id)"
        done
    else
        success "Disk usage is healthy: ${disk_usage}%"
    fi
}

# Setup systemd timer for automatic rotation
setup_systemd_timer() {
    log "Setting up systemd timer for log rotation..."
    
    # Create service file
    cat > /etc/systemd/system/marketsage-log-rotation.service << EOF
[Unit]
Description=MarketSage Monitoring Log Rotation
After=docker.service

[Service]
Type=oneshot
ExecStart=/opt/marketsage-monitoring/scripts/log-rotation.sh
User=root
StandardOutput=journal
StandardError=journal
EOF

    # Create timer file
    cat > /etc/systemd/system/marketsage-log-rotation.timer << EOF
[Unit]
Description=Run MarketSage log rotation daily
Requires=marketsage-log-rotation.service

[Timer]
OnCalendar=daily
Persistent=true
RandomizedDelaySec=30m

[Install]
WantedBy=timers.target
EOF

    # Reload systemd and enable timer
    systemctl daemon-reload
    systemctl enable marketsage-log-rotation.timer
    systemctl start marketsage-log-rotation.timer
    
    success "Systemd timer configured and started"
}

# Create log monitoring alerts
create_log_monitoring() {
    log "Creating log monitoring configuration..."
    
    cat > /tmp/log-monitoring-rules.yml << 'EOF'
groups:
  - name: log_monitoring
    rules:
      - alert: HighLogVolume
        expr: increase(loki_ingester_chunks_created_total[1h]) > 10000
        for: 5m
        labels:
          severity: warning
          service: loki
        annotations:
          summary: "High log ingestion volume detected"
          description: "Loki is ingesting {{ $value }} chunks per hour, which is above normal"

      - alert: LogIngestionFailed
        expr: rate(loki_ingester_chunks_failed_total[5m]) > 0.1
        for: 2m
        labels:
          severity: critical
          service: loki
        annotations:
          summary: "Log ingestion failures detected"
          description: "Loki is failing to ingest logs at {{ $value }} failures per second"

      - alert: DiskUsageHigh
        expr: (node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}) * 100 < 15
        for: 5m
        labels:
          severity: critical
          service: system
        annotations:
          summary: "Critical disk usage on monitoring host"
          description: "Disk usage is {{ $value }}% free. Log rotation may be needed"

      - alert: LogRotationFailed
        expr: absent_over_time(up{job="log-rotation"}[25h])
        for: 1h
        labels:
          severity: warning
          service: log-rotation
        annotations:
          summary: "Log rotation has not run in 24 hours"
          description: "The log rotation service appears to have failed or not executed"
EOF
    
    # Copy to rules directory
    cp /tmp/log-monitoring-rules.yml ./alloy/rules/
    
    success "Log monitoring rules created"
}

# Generate log rotation report
generate_report() {
    log "Generating log rotation report..."
    
    report_file="/var/log/log-rotation-report-$(date +%Y%m%d).txt"
    
    cat > "$report_file" << EOF
MarketSage Monitoring Log Rotation Report
========================================
Generated: $(date)

Disk Usage Summary:
$(df -h)

Log Directory Sizes:
$(du -sh /var/log/* 2>/dev/null | sort -hr)

Docker Container Log Sizes:
$(find /var/lib/docker/containers -name "*-json.log" -exec du -sh {} + 2>/dev/null | sort -hr | head -10)

Recent Log Files (last 7 days):
$(find /var/log -name "*.log*" -type f -mtime -7 -exec ls -lh {} + 2>/dev/null | tail -20)

Service Status:
$(systemctl status marketsage-log-rotation.timer --no-pager 2>/dev/null || echo "Timer not configured")

Log Rotation Statistics:
- Retention period: $RETENTION_DAYS days
- Compression enabled: $COMPRESS_LOGS
- Last rotation: $(date)

Recommendations:
EOF

    # Add recommendations based on disk usage
    disk_usage=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
    if [[ $disk_usage -gt 80 ]]; then
        echo "- URGENT: Disk usage is ${disk_usage}%. Consider reducing retention period or increasing storage." >> "$report_file"
    elif [[ $disk_usage -gt 70 ]]; then
        echo "- WARNING: Disk usage is ${disk_usage}%. Monitor closely." >> "$report_file"
    else
        echo "- Disk usage is healthy at ${disk_usage}%." >> "$report_file"
    fi
    
    echo "- Consider enabling log compression if not already enabled." >> "$report_file"
    echo "- Review log levels to reduce unnecessary logging." >> "$report_file"
    
    success "Report generated: $report_file"
}

# Main function
main() {
    case "${1:-manual}" in
        "setup")
            log "Setting up log rotation..."
            create_logrotate_config
            setup_systemd_timer
            create_log_monitoring
            ;;
        "manual")
            log "Running manual log rotation..."
            manual_log_rotation
            clean_docker_logs
            monitor_disk_usage
            generate_report
            ;;
        "monitor")
            log "Monitoring disk usage only..."
            monitor_disk_usage
            ;;
        "report")
            log "Generating report only..."
            generate_report
            ;;
        *)
            echo "Usage: $0 {setup|manual|monitor|report}"
            echo "  setup  - Configure automatic log rotation"
            echo "  manual - Run manual log rotation (default)"
            echo "  monitor - Check disk usage only"
            echo "  report - Generate report only"
            exit 1
            ;;
    esac
    
    success "Log rotation operation completed"
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi