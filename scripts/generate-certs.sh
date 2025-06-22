#!/bin/bash

# MarketSage SSL Certificate Generation Script
# Generates self-signed certificates for internal services

set -e

# Configuration
CERT_DIR="./certs"
DAYS_VALID=365
KEY_SIZE=2048

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Services requiring certificates
declare -A SERVICES=(
    ["prometheus"]="prometheus"
    ["grafana"]="grafana"
    ["loki"]="loki"
    ["alertmanager"]="alertmanager"
    ["alloy"]="alloy"
)

echo -e "${GREEN}=== MarketSage SSL Certificate Generator ===${NC}"
echo "Generating self-signed certificates for monitoring services"
echo "Certificate validity: $DAYS_VALID days"
echo ""

# Create certificate directory
mkdir -p "$CERT_DIR"

# Function to generate certificate for a service
generate_cert() {
    local service="$1"
    local common_name="$2"
    local cert_file="${CERT_DIR}/${service}.crt"
    local key_file="${CERT_DIR}/${service}.key"
    local csr_file="${CERT_DIR}/${service}.csr"
    
    echo -e "${BLUE}Generating certificate for $service...${NC}"
    
    # Generate private key
    openssl genrsa -out "$key_file" $KEY_SIZE 2>/dev/null
    
    # Generate certificate signing request
    openssl req -new -key "$key_file" -out "$csr_file" -subj "/C=US/ST=CA/L=San Francisco/O=MarketSage/OU=Monitoring/CN=$common_name" 2>/dev/null
    
    # Generate self-signed certificate
    openssl x509 -req -in "$csr_file" -signkey "$key_file" -out "$cert_file" -days $DAYS_VALID \
        -extensions v3_req -extfile <(cat <<EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
C = US
ST = CA
L = San Francisco
O = MarketSage
OU = Monitoring
CN = $common_name

[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = $common_name
DNS.2 = localhost
DNS.3 = $service
IP.1 = 127.0.0.1
EOF
    ) 2>/dev/null
    
    # Clean up CSR file
    rm -f "$csr_file"
    
    # Set appropriate permissions
    chmod 600 "$key_file"
    chmod 644 "$cert_file"
    
    echo -e "${GREEN}  ✓ Certificate generated: $cert_file${NC}"
    echo -e "${GREEN}  ✓ Private key generated: $key_file${NC}"
    
    # Verify certificate
    local cert_info=$(openssl x509 -in "$cert_file" -text -noout | grep -A 1 "Subject:")
    local expiry_date=$(openssl x509 -in "$cert_file" -enddate -noout | cut -d= -f2)
    echo "  Subject: $(echo "$cert_info" | tail -n 1 | xargs)"
    echo "  Expires: $expiry_date"
    echo ""
}

# Function to generate CA certificate
generate_ca() {
    local ca_key="${CERT_DIR}/ca.key"
    local ca_cert="${CERT_DIR}/ca.crt"
    
    echo -e "${BLUE}Generating Certificate Authority...${NC}"
    
    # Generate CA private key
    openssl genrsa -out "$ca_key" 4096 2>/dev/null
    
    # Generate CA certificate
    openssl req -new -x509 -key "$ca_key" -out "$ca_cert" -days $((DAYS_VALID * 2)) \
        -subj "/C=US/ST=CA/L=San Francisco/O=MarketSage/OU=Monitoring/CN=MarketSage Monitoring CA" 2>/dev/null
    
    # Set appropriate permissions
    chmod 600 "$ca_key"
    chmod 644 "$ca_cert"
    
    echo -e "${GREEN}  ✓ CA certificate generated: $ca_cert${NC}"
    echo -e "${GREEN}  ✓ CA private key generated: $ca_key${NC}"
    echo ""
}

# Function to create combined certificate bundle
create_bundle() {
    local bundle_file="${CERT_DIR}/bundle.crt"
    
    echo -e "${BLUE}Creating certificate bundle...${NC}"
    
    # Combine all certificates
    cat "${CERT_DIR}/ca.crt" > "$bundle_file"
    for service in "${!SERVICES[@]}"; do
        if [[ -f "${CERT_DIR}/${service}.crt" ]]; then
            echo "" >> "$bundle_file"
            cat "${CERT_DIR}/${service}.crt" >> "$bundle_file"
        fi
    done
    
    echo -e "${GREEN}  ✓ Certificate bundle created: $bundle_file${NC}"
    echo ""
}

# Function to create trust store
create_truststore() {
    local truststore_file="${CERT_DIR}/truststore.jks"
    local truststore_password="changeit"
    
    echo -e "${BLUE}Creating Java truststore...${NC}"
    
    # Check if keytool is available
    if ! command -v keytool &> /dev/null; then
        echo -e "${YELLOW}  ⚠ keytool not found, skipping truststore creation${NC}"
        return 0
    fi
    
    # Create truststore with CA certificate
    keytool -import -trustcacerts -alias marketsage-ca -file "${CERT_DIR}/ca.crt" \
        -keystore "$truststore_file" -storepass "$truststore_password" -noprompt 2>/dev/null
    
    echo -e "${GREEN}  ✓ Truststore created: $truststore_file${NC}"
    echo "  Password: $truststore_password"
    echo ""
}

# Function to generate Prometheus basic auth hash
generate_prometheus_auth() {
    local auth_file="${CERT_DIR}/../secrets/prometheus_basic_auth.txt"
    local username="admin"
    local password="monitoring123"
    
    echo -e "${BLUE}Generating Prometheus basic auth...${NC}"
    
    # Create secrets directory if it doesn't exist
    mkdir -p "$(dirname "$auth_file")"
    
    # Check if htpasswd is available
    if command -v htpasswd &> /dev/null; then
        # Use htpasswd if available
        htpasswd -nb "$username" "$password" > "$auth_file"
    else
        # Use openssl as fallback
        local hash=$(openssl passwd -apr1 "$password")
        echo "${username}:${hash}" > "$auth_file"
    fi
    
    echo -e "${GREEN}  ✓ Basic auth file created: $auth_file${NC}"
    echo "  Username: $username"
    echo "  Password: $password"
    echo ""
}

# Function to display certificate information
display_cert_info() {
    echo -e "${BLUE}=== Certificate Summary ===${NC}"
    echo "Certificate directory: $CERT_DIR"
    echo "Certificate validity: $DAYS_VALID days"
    echo ""
    
    for cert_file in "$CERT_DIR"/*.crt; do
        if [[ -f "$cert_file" ]]; then
            local filename=$(basename "$cert_file")
            local subject=$(openssl x509 -in "$cert_file" -subject -noout | cut -d= -f2-)
            local expiry=$(openssl x509 -in "$cert_file" -enddate -noout | cut -d= -f2)
            echo "Certificate: $filename"
            echo "  Subject: $subject"
            echo "  Expires: $expiry"
            echo ""
        fi
    done
}

# Function to create docker-compose override for TLS
create_docker_override() {
    local override_file="${CERT_DIR}/../docker-compose.override.yml"
    
    echo -e "${BLUE}Creating Docker Compose TLS override...${NC}"
    
    cat > "$override_file" << EOF
# TLS/SSL configuration override for MarketSage monitoring
version: '3.8'

services:
  prometheus:
    volumes:
      - ./certs:/etc/ssl/certs:ro
      - ./certs:/etc/ssl/private:ro
    environment:
      - PROMETHEUS_TLS_CERT_FILE=/etc/ssl/certs/prometheus.crt
      - PROMETHEUS_TLS_KEY_FILE=/etc/ssl/private/prometheus.key

  grafana:
    volumes:
      - ./certs:/etc/ssl/certs:ro
      - ./certs:/etc/ssl/private:ro
    environment:
      - GF_SERVER_PROTOCOL=https
      - GF_SERVER_CERT_FILE=/etc/ssl/certs/grafana.crt
      - GF_SERVER_CERT_KEY=/etc/ssl/private/grafana.key

  loki:
    volumes:
      - ./certs:/etc/ssl/certs:ro
      - ./certs:/etc/ssl/private:ro

  alertmanager:
    volumes:
      - ./certs:/etc/ssl/certs:ro
      - ./certs:/etc/ssl/private:ro

  alloy:
    volumes:
      - ./certs:/etc/ssl/certs:ro
      - ./certs:/etc/ssl/private:ro
EOF
    
    echo -e "${GREEN}  ✓ Docker Compose override created: $override_file${NC}"
    echo ""
}

# Main execution
main() {
    # Check prerequisites
    if ! command -v openssl &> /dev/null; then
        echo -e "${RED}Error: openssl is required but not installed${NC}"
        exit 1
    fi
    
    # Generate CA certificate first
    generate_ca
    
    # Generate certificates for each service
    for service in "${!SERVICES[@]}"; do
        generate_cert "$service" "${SERVICES[$service]}"
    done
    
    # Create certificate bundle
    create_bundle
    
    # Create truststore (optional)
    create_truststore
    
    # Generate Prometheus basic auth
    generate_prometheus_auth
    
    # Create Docker Compose override
    create_docker_override
    
    # Display summary
    display_cert_info
    
    echo -e "${GREEN}=== Certificate generation completed! ===${NC}"
    echo ""
    echo -e "${YELLOW}Important notes:${NC}"
    echo "1. These are self-signed certificates for development/testing"
    echo "2. For production, use certificates from a trusted CA"
    echo "3. Update your services to use the generated certificates"
    echo "4. The Docker Compose override file has been created for TLS configuration"
    echo "5. Restart your services to apply the new certificates"
    echo ""
    echo -e "${BLUE}To trust the CA certificate system-wide (Linux):${NC}"
    echo "  sudo cp $CERT_DIR/ca.crt /usr/local/share/ca-certificates/marketsage-ca.crt"
    echo "  sudo update-ca-certificates"
    echo ""
    echo -e "${BLUE}To trust the CA certificate system-wide (macOS):${NC}"
    echo "  sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain $CERT_DIR/ca.crt"
}

# Cleanup function
cleanup() {
    echo ""
    echo -e "${YELLOW}Certificate generation interrupted. Cleaning up...${NC}"
    # Remove any incomplete certificate files
    find "$CERT_DIR" -name "*.csr" -delete 2>/dev/null || true
    exit 1
}

# Set up signal handlers
trap cleanup SIGINT SIGTERM

# Run main function
main "$@"