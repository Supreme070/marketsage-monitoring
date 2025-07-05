#!/bin/bash

# MarketSage Monitoring Backup Script
# Backs up all monitoring configurations, dashboards, and critical data

set -euo pipefail

# Configuration
BACKUP_DIR="/backup/monitoring"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_PATH="${BACKUP_DIR}/${TIMESTAMP}"
RETENTION_DAYS=30
LOG_FILE="/var/log/monitoring-backup.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Error handling
error_exit() {
    log "${RED}ERROR: $1${NC}"
    exit 1
}

# Success logging
success() {
    log "${GREEN}SUCCESS: $1${NC}"
}

# Warning logging
warning() {
    log "${YELLOW}WARNING: $1${NC}"
}

# Check if running as root or with sudo
check_permissions() {
    if [[ $EUID -ne 0 ]]; then
        error_exit "This script must be run as root or with sudo"
    fi
}

# Create backup directory structure
create_backup_structure() {
    log "Creating backup directory structure..."
    
    mkdir -p "$BACKUP_PATH"/{config,dashboards,data,scripts,secrets}
    
    success "Backup directory structure created: $BACKUP_PATH"
}

# Backup Prometheus configuration and data
backup_prometheus() {
    log "Backing up Prometheus..."
    
    # Backup configuration
    cp -r ./config/prometheus.yml "$BACKUP_PATH/config/" || warning "Failed to backup Prometheus config"
    cp -r ./config/web-config.yml "$BACKUP_PATH/config/" || warning "Failed to backup Prometheus web config"
    cp -r ./alloy/rules/ "$BACKUP_PATH/config/prometheus-rules/" || warning "Failed to backup Prometheus rules"
    
    # Backup TSDB data (optional - can be large)
    if [[ "${BACKUP_PROMETHEUS_DATA:-false}" == "true" ]]; then
        log "Backing up Prometheus TSDB data (this may take a while)..."
        docker exec prometheus prometheus --config.file=/etc/prometheus/prometheus.yml \
            --storage.tsdb.path=/prometheus --storage.tsdb.retention.time=1d \
            --storage.tsdb.retention.size=1GB \
            --query.timeout=30s \
            --web.enable-admin-api \
            --storage.tsdb.snapshot.dir=/backup \
            --storage.tsdb.create-snapshot || warning "Failed to create Prometheus snapshot"
        
        # Copy snapshot if created
        SNAPSHOT_DIR=$(docker exec prometheus ls -t /backup | head -n1)
        if [[ -n "$SNAPSHOT_DIR" ]]; then
            docker cp prometheus:/backup/"$SNAPSHOT_DIR" "$BACKUP_PATH/data/prometheus-snapshot" || warning "Failed to copy Prometheus snapshot"
        fi
    fi
    
    success "Prometheus backup completed"
}

# Backup Grafana dashboards and datasources
backup_grafana() {
    log "Backing up Grafana..."
    
    # Backup dashboard files
    cp -r ./grafana/dashboards/ "$BACKUP_PATH/dashboards/" || warning "Failed to backup Grafana dashboards"
    cp -r ./grafana/provisioning/ "$BACKUP_PATH/config/grafana-provisioning/" || warning "Failed to backup Grafana provisioning"
    
    # Backup Grafana database (SQLite)
    docker exec grafana sqlite3 /var/lib/grafana/grafana.db ".backup /tmp/grafana-backup.db" || warning "Failed to backup Grafana database"
    docker cp grafana:/tmp/grafana-backup.db "$BACKUP_PATH/data/grafana.db" || warning "Failed to copy Grafana database backup"
    
    # Export dashboards via API
    if command -v curl &> /dev/null; then
        log "Exporting Grafana dashboards via API..."
        mkdir -p "$BACKUP_PATH/dashboards/api-export"
        
        # Get dashboard UIDs
        DASHBOARD_UIDS=$(curl -s -H "Authorization: Bearer admin:admin" \
            "http://localhost:3000/api/search?type=dash-db" | \
            grep -o '"uid":"[^"]*"' | cut -d'"' -f4 || echo "")
        
        for uid in $DASHBOARD_UIDS; do
            if [[ -n "$uid" ]]; then
                curl -s -H "Authorization: Bearer admin:admin" \
                    "http://localhost:3000/api/dashboards/uid/$uid" > \
                    "$BACKUP_PATH/dashboards/api-export/${uid}.json" || warning "Failed to export dashboard $uid"
            fi
        done
    fi
    
    success "Grafana backup completed"
}

# Backup Loki configuration and indices
backup_loki() {
    log "Backing up Loki..."
    
    # Backup configuration
    cp ./config/loki.yml "$BACKUP_PATH/config/" || warning "Failed to backup Loki config"
    
    # Backup Loki indices and metadata (excluding chunks for size)
    if [[ "${BACKUP_LOKI_DATA:-false}" == "true" ]]; then
        log "Backing up Loki indices..."
        docker exec loki tar -czf /tmp/loki-indices.tar.gz -C /loki index_* || warning "Failed to create Loki indices archive"
        docker cp loki:/tmp/loki-indices.tar.gz "$BACKUP_PATH/data/" || warning "Failed to copy Loki indices backup"
    fi
    
    success "Loki backup completed"
}

# Backup Tempo configuration
backup_tempo() {
    log "Backing up Tempo..."
    
    # Backup configuration
    cp ./config/tempo.yml "$BACKUP_PATH/config/" || warning "Failed to backup Tempo config"
    
    success "Tempo backup completed"
}

# Backup Alertmanager configuration
backup_alertmanager() {
    log "Backing up Alertmanager..."
    
    # Backup configuration
    cp ./config/alertmanager.yml "$BACKUP_PATH/config/" || warning "Failed to backup Alertmanager config"
    cp ./config/alertmanager-enhanced.yml "$BACKUP_PATH/config/" || warning "Failed to backup enhanced Alertmanager config"
    
    # Backup silences and notification log
    docker exec alertmanager tar -czf /tmp/alertmanager-data.tar.gz -C /alertmanager . || warning "Failed to create Alertmanager data archive"
    docker cp alertmanager:/tmp/alertmanager-data.tar.gz "$BACKUP_PATH/data/" || warning "Failed to copy Alertmanager data backup"
    
    success "Alertmanager backup completed"
}

# Backup secrets (encrypted)
backup_secrets() {
    log "Backing up secrets..."
    
    # Create encrypted backup of secrets
    if command -v gpg &> /dev/null && [[ -n "${BACKUP_GPG_RECIPIENT:-}" ]]; then
        tar -czf - ./secrets/ | gpg --trust-model always --encrypt -r "$BACKUP_GPG_RECIPIENT" > "$BACKUP_PATH/secrets/secrets.tar.gz.gpg" || warning "Failed to backup encrypted secrets"
    else
        warning "GPG not available or recipient not set - skipping secrets backup"
    fi
    
    success "Secrets backup completed"
}

# Backup docker-compose and scripts
backup_infrastructure() {
    log "Backing up infrastructure files..."
    
    # Backup compose files
    cp ./docker-compose.yml "$BACKUP_PATH/scripts/" || warning "Failed to backup docker-compose.yml"
    cp ./docker-compose.override.yml "$BACKUP_PATH/scripts/" || warning "Failed to backup docker-compose.override.yml"
    
    # Backup scripts
    cp -r ./scripts/ "$BACKUP_PATH/scripts/monitoring-scripts/" || warning "Failed to backup monitoring scripts"
    
    # Backup service configurations
    cp -r ./services/ "$BACKUP_PATH/config/services/" || warning "Failed to backup service configurations"
    
    success "Infrastructure backup completed"
}

# Create backup manifest
create_manifest() {
    log "Creating backup manifest..."
    
    cat > "$BACKUP_PATH/MANIFEST.txt" << EOF
MarketSage Monitoring Backup Manifest
=====================================

Backup Date: $(date)
Backup Path: $BACKUP_PATH
Script Version: 1.0

Contents:
---------
config/                 - All monitoring service configurations
dashboards/            - Grafana dashboards and provisioning
data/                  - Service data backups (if enabled)
scripts/               - Infrastructure and deployment scripts
secrets/               - Encrypted secrets backup (if GPG configured)

Backup Sizes:
$(du -sh "$BACKUP_PATH"/* 2>/dev/null || echo "No size information available")

Services Backed Up:
- Prometheus (config + rules)
- Grafana (dashboards + database)
- Loki (config + indices)
- Tempo (config)
- Alertmanager (config + data)
- Business Metrics Exporter (config)
- Synthetic Monitoring (config)

Notes:
- TSDB data backup: ${BACKUP_PROMETHEUS_DATA:-false}
- Loki data backup: ${BACKUP_LOKI_DATA:-false}
- Secrets encryption: ${BACKUP_GPG_RECIPIENT:-"not configured"}

Verification:
- Total backup size: $(du -sh "$BACKUP_PATH" | cut -f1)
- File count: $(find "$BACKUP_PATH" -type f | wc -l)
EOF
    
    success "Backup manifest created"
}

# Compress backup
compress_backup() {
    log "Compressing backup..."
    
    cd "$BACKUP_DIR"
    tar -czf "${TIMESTAMP}.tar.gz" "$TIMESTAMP/"
    
    if [[ $? -eq 0 ]]; then
        rm -rf "$TIMESTAMP/"
        success "Backup compressed: ${BACKUP_DIR}/${TIMESTAMP}.tar.gz"
    else
        warning "Compression failed, keeping uncompressed backup"
    fi
}

# Clean old backups
cleanup_old_backups() {
    log "Cleaning up old backups..."
    
    find "$BACKUP_DIR" -name "*.tar.gz" -type f -mtime +$RETENTION_DAYS -delete
    find "$BACKUP_DIR" -maxdepth 1 -type d -mtime +$RETENTION_DAYS ! -name "." -exec rm -rf {} +
    
    REMAINING_BACKUPS=$(find "$BACKUP_DIR" -name "*.tar.gz" -type f | wc -l)
    success "Old backups cleaned up. Remaining backups: $REMAINING_BACKUPS"
}

# Main backup function
main() {
    log "Starting MarketSage monitoring backup..."
    
    check_permissions
    create_backup_structure
    
    backup_prometheus
    backup_grafana
    backup_loki
    backup_tempo
    backup_alertmanager
    backup_secrets
    backup_infrastructure
    
    create_manifest
    compress_backup
    cleanup_old_backups
    
    success "Backup completed successfully: ${BACKUP_DIR}/${TIMESTAMP}.tar.gz"
    log "Backup summary: $(du -sh "${BACKUP_DIR}/${TIMESTAMP}.tar.gz" 2>/dev/null || echo "Compressed backup size unavailable")"
}

# Script execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi