#!/bin/bash

# MarketSage Monitoring SSL Certificate Management
# Handles SSL certificates for monitoring services

set -euo pipefail

# Configuration
CERT_DIR="/opt/marketsage-monitoring/certs"
CA_DIR="$CERT_DIR/ca"
SERVICE_CERT_DIR="$CERT_DIR/services"
CERT_VALIDITY_DAYS=365
CA_VALIDITY_DAYS=3650

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

success() {
    log "${GREEN}SUCCESS: $1${NC}"
}

warning() {
    log "${YELLOW}WARNING: $1${NC}"
}

error_exit() {
    log "${RED}ERROR: $1${NC}"
    exit 1
}

# Create directory structure
create_cert_structure() {
    log "Creating certificate directory structure..."
    
    mkdir -p "$CA_DIR"
    mkdir -p "$SERVICE_CERT_DIR"/{prometheus,grafana,alertmanager,loki,tempo}
    
    # Set proper permissions
    chmod 700 "$CERT_DIR"
    chmod 755 "$CA_DIR"
    chmod 755 "$SERVICE_CERT_DIR"
    
    success "Certificate directory structure created"
}

# Generate CA certificate
generate_ca() {
    log "Generating Certificate Authority..."
    
    if [[ -f "$CA_DIR/ca.pem" ]]; then
        warning "CA certificate already exists. Skipping generation."
        return 0
    fi
    
    # Generate CA private key
    openssl genrsa -out "$CA_DIR/ca-key.pem" 4096
    
    # Generate CA certificate
    openssl req -new -x509 -days "$CA_VALIDITY_DAYS" -key "$CA_DIR/ca-key.pem" \
        -sha256 -out "$CA_DIR/ca.pem" -subj \
        "/C=ZA/ST=Western Cape/L=Cape Town/O=MarketSage/OU=Monitoring/CN=MarketSage Monitoring CA"
    
    # Set permissions
    chmod 400 "$CA_DIR/ca-key.pem"
    chmod 444 "$CA_DIR/ca.pem"
    
    success "CA certificate generated"
}

# Generate service certificate
generate_service_cert() {
    local service=$1
    local san_entries=$2
    
    log "Generating certificate for $service..."
    
    local service_dir="$SERVICE_CERT_DIR/$service"
    
    # Generate service private key
    openssl genrsa -out "$service_dir/$service-key.pem" 2048
    
    # Create certificate signing request
    openssl req -subj "/CN=$service" -sha256 -new -key "$service_dir/$service-key.pem" \
        -out "$service_dir/$service.csr"
    
    # Create extensions file
    cat > "$service_dir/$service-extensions.cnf" << EOF
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = $san_entries
EOF
    
    # Generate signed certificate
    openssl x509 -req -days "$CERT_VALIDITY_DAYS" -sha256 \
        -in "$service_dir/$service.csr" \
        -CA "$CA_DIR/ca.pem" \
        -CAkey "$CA_DIR/ca-key.pem" \
        -out "$service_dir/$service.pem" \
        -extensions v3_req \
        -extfile "$service_dir/$service-extensions.cnf" \
        -CAcreateserial
    
    # Set permissions
    chmod 400 "$service_dir/$service-key.pem"
    chmod 444 "$service_dir/$service.pem"
    
    # Clean up
    rm "$service_dir/$service.csr" "$service_dir/$service-extensions.cnf"
    
    success "Certificate generated for $service"
}

# Generate all service certificates
generate_all_service_certs() {
    log "Generating certificates for all monitoring services..."
    
    # Prometheus
    generate_service_cert "prometheus" "DNS:prometheus,DNS:localhost,IP:127.0.0.1"
    
    # Grafana
    generate_service_cert "grafana" "DNS:grafana,DNS:localhost,IP:127.0.0.1"
    
    # Alertmanager
    generate_service_cert "alertmanager" "DNS:alertmanager,DNS:localhost,IP:127.0.0.1"
    
    # Loki
    generate_service_cert "loki" "DNS:loki,DNS:localhost,IP:127.0.0.1"
    
    # Tempo
    generate_service_cert "tempo" "DNS:tempo,DNS:localhost,IP:127.0.0.1"
    
    success "All service certificates generated"
}

# Create TLS configuration files
create_tls_configs() {
    log "Creating TLS configuration files..."
    
    # Prometheus web config with TLS
    cat > "$CERT_DIR/prometheus-web-config.yml" << EOF
tls_server_config:
  cert_file: /etc/ssl/certs/prometheus.pem
  key_file: /etc/ssl/private/prometheus-key.pem
  client_ca_file: /etc/ssl/certs/ca.pem
  client_auth_type: RequestClientCert

basic_auth_users:
  admin: \$2b\$12\$hNf2lSsxfm0.i4a.1kVpSOVyBCfIB51VRjgBUyv6kdnyTlgWj81Ay  # monitoring123
EOF

    # Grafana TLS configuration
    cat > "$CERT_DIR/grafana-tls.ini" << EOF
[server]
protocol = https
cert_file = /etc/ssl/certs/grafana.pem
cert_key = /etc/ssl/private/grafana-key.pem
ca_file = /etc/ssl/certs/ca.pem
EOF

    # Alertmanager TLS configuration
    cat > "$CERT_DIR/alertmanager-tls.yml" << EOF
tls_config:
  cert_file: /etc/ssl/certs/alertmanager.pem
  key_file: /etc/ssl/private/alertmanager-key.pem
  ca_file: /etc/ssl/certs/ca.pem
EOF

    success "TLS configuration files created"
}

# Update docker-compose for TLS
update_docker_compose_tls() {
    log "Creating TLS-enabled docker-compose configuration..."
    
    cat > "$CERT_DIR/docker-compose.tls.yml" << 'EOF'
# TLS Configuration for MarketSage Monitoring
# Use this file as an overlay: docker-compose -f docker-compose.yml -f docker-compose.tls.yml up

services:
  prometheus:
    volumes:
      - ./certs/prometheus-web-config.yml:/etc/prometheus/web-config.yml:ro
      - ./certs/ca/ca.pem:/etc/ssl/certs/ca.pem:ro
      - ./certs/services/prometheus/prometheus.pem:/etc/ssl/certs/prometheus.pem:ro
      - ./certs/services/prometheus/prometheus-key.pem:/etc/ssl/private/prometheus-key.pem:ro
    command:
      - --config.file=/etc/prometheus/prometheus.yml
      - --storage.tsdb.path=/prometheus
      - --web.console.libraries=/etc/prometheus/console_libraries
      - --web.console.templates=/etc/prometheus/consoles
      - --storage.tsdb.retention.time=30d
      - --storage.tsdb.retention.size=50GB
      - --web.enable-remote-write-receiver
      - --web.enable-lifecycle
      - --web.config.file=/etc/prometheus/web-config.yml
      - --query.max-concurrency=20
      - --query.max-samples=50000000

  grafana:
    volumes:
      - ./certs/grafana-tls.ini:/etc/grafana/grafana.ini:ro
      - ./certs/ca/ca.pem:/etc/ssl/certs/ca.pem:ro
      - ./certs/services/grafana/grafana.pem:/etc/ssl/certs/grafana.pem:ro
      - ./certs/services/grafana/grafana-key.pem:/etc/ssl/private/grafana-key.pem:ro
    ports:
      - "3443:3000"  # HTTPS port
    environment:
      - GF_SERVER_PROTOCOL=https
      - GF_SERVER_CERT_FILE=/etc/ssl/certs/grafana.pem
      - GF_SERVER_CERT_KEY=/etc/ssl/private/grafana-key.pem

  alertmanager:
    volumes:
      - ./certs/alertmanager-tls.yml:/etc/alertmanager/tls.yml:ro
      - ./certs/ca/ca.pem:/etc/ssl/certs/ca.pem:ro
      - ./certs/services/alertmanager/alertmanager.pem:/etc/ssl/certs/alertmanager.pem:ro
      - ./certs/services/alertmanager/alertmanager-key.pem:/etc/ssl/private/alertmanager-key.pem:ro

  loki:
    volumes:
      - ./certs/ca/ca.pem:/etc/ssl/certs/ca.pem:ro
      - ./certs/services/loki/loki.pem:/etc/ssl/certs/loki.pem:ro
      - ./certs/services/loki/loki-key.pem:/etc/ssl/private/loki-key.pem:ro

  tempo:
    volumes:
      - ./certs/ca/ca.pem:/etc/ssl/certs/ca.pem:ro
      - ./certs/services/tempo/tempo.pem:/etc/ssl/certs/tempo.pem:ro
      - ./certs/services/tempo/tempo-key.pem:/etc/ssl/private/tempo-key.pem:ro
EOF

    success "TLS docker-compose configuration created"
}

# Check certificate expiry
check_cert_expiry() {
    log "Checking certificate expiry dates..."
    
    local warning_days=30
    local current_date=$(date +%s)
    
    for cert_file in $(find "$SERVICE_CERT_DIR" -name "*.pem" ! -name "*-key.pem"); do
        local service=$(basename "$(dirname "$cert_file")")
        local expiry_date=$(openssl x509 -enddate -noout -in "$cert_file" | cut -d= -f2)
        local expiry_timestamp=$(date -d "$expiry_date" +%s)
        local days_until_expiry=$(( (expiry_timestamp - current_date) / 86400 ))
        
        if [[ $days_until_expiry -lt 0 ]]; then
            error_exit "Certificate for $service has EXPIRED!"
        elif [[ $days_until_expiry -lt $warning_days ]]; then
            warning "Certificate for $service expires in $days_until_expiry days"
        else
            success "Certificate for $service is valid (expires in $days_until_expiry days)"
        fi
    done
}

# Renew certificates
renew_certificates() {
    log "Renewing certificates..."
    
    # Backup existing certificates
    local backup_dir="$CERT_DIR/backup-$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    cp -r "$SERVICE_CERT_DIR" "$backup_dir/"
    
    # Regenerate service certificates
    generate_all_service_certs
    
    # Restart services to pick up new certificates
    if command -v docker-compose &> /dev/null; then
        log "Restarting services to load new certificates..."
        docker-compose restart prometheus grafana alertmanager loki tempo
        success "Services restarted with new certificates"
    fi
    
    success "Certificates renewed successfully"
}

# Setup certificate monitoring
setup_cert_monitoring() {
    log "Setting up certificate monitoring..."
    
    # Create certificate monitoring script
    cat > "$CERT_DIR/monitor-certs.sh" << 'EOF'
#!/bin/bash
# Certificate monitoring script for cron

CERT_DIR="/opt/marketsage-monitoring/certs"
WARNING_DAYS=30
ALERT_WEBHOOK="${SLACK_WEBHOOK_URL:-}"

check_and_alert() {
    local service=$1
    local days_until_expiry=$2
    
    if [[ $days_until_expiry -lt $WARNING_DAYS && -n "$ALERT_WEBHOOK" ]]; then
        curl -X POST -H 'Content-type: application/json' \
            --data "{\"text\":\"⚠️ SSL Certificate Warning: $service certificate expires in $days_until_expiry days\"}" \
            "$ALERT_WEBHOOK"
    fi
}

# Check all certificates
for cert_file in $(find "$CERT_DIR/services" -name "*.pem" ! -name "*-key.pem"); do
    service=$(basename "$(dirname "$cert_file")")
    expiry_date=$(openssl x509 -enddate -noout -in "$cert_file" | cut -d= -f2)
    expiry_timestamp=$(date -d "$expiry_date" +%s)
    current_date=$(date +%s)
    days_until_expiry=$(( (expiry_timestamp - current_date) / 86400 ))
    
    check_and_alert "$service" "$days_until_expiry"
done
EOF

    chmod +x "$CERT_DIR/monitor-certs.sh"
    
    # Create systemd timer for certificate monitoring
    cat > /etc/systemd/system/cert-monitor.service << EOF
[Unit]
Description=Monitor SSL certificates for MarketSage monitoring
After=network.target

[Service]
Type=oneshot
ExecStart=$CERT_DIR/monitor-certs.sh
User=root
StandardOutput=journal
StandardError=journal
EOF

    cat > /etc/systemd/system/cert-monitor.timer << EOF
[Unit]
Description=Run certificate monitoring daily
Requires=cert-monitor.service

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
EOF

    systemctl daemon-reload
    systemctl enable cert-monitor.timer
    systemctl start cert-monitor.timer
    
    success "Certificate monitoring configured"
}

# Main function
main() {
    case "${1:-setup}" in
        "setup")
            log "Setting up SSL certificate management..."
            create_cert_structure
            generate_ca
            generate_all_service_certs
            create_tls_configs
            update_docker_compose_tls
            setup_cert_monitoring
            success "SSL certificate management setup complete"
            ;;
        "check")
            check_cert_expiry
            ;;
        "renew")
            renew_certificates
            ;;
        "generate-ca")
            generate_ca
            ;;
        "generate-service")
            if [[ -z "${2:-}" ]]; then
                error_exit "Service name required. Usage: $0 generate-service <service-name>"
            fi
            generate_service_cert "$2" "DNS:$2,DNS:localhost,IP:127.0.0.1"
            ;;
        *)
            echo "Usage: $0 {setup|check|renew|generate-ca|generate-service}"
            echo "  setup           - Complete SSL setup for all services"
            echo "  check           - Check certificate expiry dates"
            echo "  renew           - Renew all service certificates"
            echo "  generate-ca     - Generate only CA certificate"
            echo "  generate-service <name> - Generate certificate for specific service"
            exit 1
            ;;
    esac
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi