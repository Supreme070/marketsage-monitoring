#!/bin/bash

# MarketSage Log Rotation Setup Script
# Configures log rotation for monitoring services and application logs

set -e

# Configuration
LOGROTATE_CONFIG_DIR="/etc/logrotate.d"
CUSTOM_CONFIG_DIR="./config/logrotate"
LOG_DIRS=(
    "/var/log/marketsage"
    "/var/log/grafana"
    "/var/log/prometheus" 
    "/var/log/loki"
    "/var/log/alertmanager"
    "/var/log/alloy"
)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== MarketSage Log Rotation Setup ===${NC}"
echo "Configuring log rotation for monitoring services"
echo ""

# Function to check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        echo -e "${GREEN}✓ Running as root${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠ Not running as root. Some operations may require sudo.${NC}"
        return 1
    fi
}

# Function to create log directories
create_log_dirs() {
    echo -e "${BLUE}Creating log directories...${NC}"
    
    for log_dir in "${LOG_DIRS[@]}"; do
        if [[ ! -d "$log_dir" ]]; then
            echo "Creating directory: $log_dir"
            if check_root; then
                mkdir -p "$log_dir"
                chown root:root "$log_dir"
                chmod 755 "$log_dir"
            else
                sudo mkdir -p "$log_dir"
                sudo chown root:root "$log_dir"
                sudo chmod 755 "$log_dir"
            fi
            echo -e "${GREEN}  ✓ Created: $log_dir${NC}"
        else
            echo -e "${GREEN}  ✓ Already exists: $log_dir${NC}"
        fi
    done
    echo ""
}

# Function to create custom logrotate config directory
create_custom_config_dir() {
    echo -e "${BLUE}Creating custom logrotate config directory...${NC}"
    mkdir -p "$CUSTOM_CONFIG_DIR"
    echo -e "${GREEN}  ✓ Created: $CUSTOM_CONFIG_DIR${NC}"
    echo ""
}

# Function to create MarketSage application log rotation config
create_marketsage_config() {
    local config_file="$CUSTOM_CONFIG_DIR/marketsage"
    
    echo -e "${BLUE}Creating MarketSage log rotation config...${NC}"
    
    cat > "$config_file" << 'EOF'
# MarketSage Application Log Rotation Configuration

/var/log/marketsage/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 644 root root
    sharedscripts
    postrotate
        # Signal MarketSage application to reopen log files
        if [ -f /var/run/marketsage.pid ]; then
            kill -USR1 $(cat /var/run/marketsage.pid) 2>/dev/null || true
        fi
        # Restart MarketSage container if running in Docker
        docker restart marketsage-web 2>/dev/null || true
    endscript
}

/var/log/marketsage/api/*.log {
    daily
    rotate 14
    compress
    delaycompress
    missingok
    notifempty
    create 644 root root
    size 100M
    sharedscripts
    postrotate
        docker restart marketsage-api 2>/dev/null || true
    endscript
}

/var/log/marketsage/worker/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 644 root root
    size 50M
    sharedscripts
    postrotate
        docker restart marketsage-worker 2>/dev/null || true
    endscript
}

/var/log/marketsage/campaigns/*.log {
    weekly
    rotate 8
    compress
    delaycompress
    missingok
    notifempty
    create 644 root root
    size 200M
}

/var/log/marketsage/analytics/*.log {
    weekly
    rotate 12
    compress
    delaycompress
    missingok
    notifempty
    create 644 root root
    size 500M
}

/var/log/marketsage/ai/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 644 root root
    size 100M
}

/var/log/marketsage/payments/*.log {
    daily
    rotate 90
    compress
    delaycompress
    missingok
    notifempty
    create 644 root root
    size 50M
    # Keep payment logs longer for compliance
}

/var/log/marketsage/security/*.log {
    daily
    rotate 365
    compress
    delaycompress
    missingok
    notifempty
    create 600 root root
    size 100M
    # Keep security logs for 1 year
}

/var/log/marketsage/sms/*.log
/var/log/marketsage/email/*.log
/var/log/marketsage/whatsapp/*.log
/var/log/marketsage/notifications/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 644 root root
    size 200M
    sharedscripts
    postrotate
        # Restart communication services
        docker restart marketsage-communications 2>/dev/null || true
    endscript
}
EOF
    
    echo -e "${GREEN}  ✓ Created MarketSage config: $config_file${NC}"
}

# Function to create Grafana log rotation config
create_grafana_config() {
    local config_file="$CUSTOM_CONFIG_DIR/grafana"
    
    echo -e "${BLUE}Creating Grafana log rotation config...${NC}"
    
    cat > "$config_file" << 'EOF'
# Grafana Log Rotation Configuration

/var/log/grafana/*.log {
    daily
    rotate 14
    compress
    delaycompress
    missingok
    notifempty
    create 644 grafana grafana
    size 100M
    sharedscripts
    postrotate
        # Restart Grafana container
        docker restart grafana 2>/dev/null || true
        # Or send HUP signal if running as service
        systemctl reload grafana-server 2>/dev/null || true
    endscript
}

# Docker container logs for Grafana
/var/lib/docker/containers/*/grafana*-json.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    copytruncate
    size 50M
}
EOF
    
    echo -e "${GREEN}  ✓ Created Grafana config: $config_file${NC}"
}

# Function to create Prometheus log rotation config
create_prometheus_config() {
    local config_file="$CUSTOM_CONFIG_DIR/prometheus"
    
    echo -e "${BLUE}Creating Prometheus log rotation config...${NC}"
    
    cat > "$config_file" << 'EOF'
# Prometheus Log Rotation Configuration

/var/log/prometheus/*.log {
    daily
    rotate 14
    compress
    delaycompress
    missingok
    notifempty
    create 644 prometheus prometheus
    size 100M
    sharedscripts
    postrotate
        # Restart Prometheus container
        docker restart prometheus 2>/dev/null || true
        # Or send HUP signal if running as service
        systemctl reload prometheus 2>/dev/null || true
    endscript
}

# Docker container logs for Prometheus
/var/lib/docker/containers/*/prometheus*-json.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    copytruncate
    size 50M
}
EOF
    
    echo -e "${GREEN}  ✓ Created Prometheus config: $config_file${NC}"
}

# Function to create Loki log rotation config
create_loki_config() {
    local config_file="$CUSTOM_CONFIG_DIR/loki"
    
    echo -e "${BLUE}Creating Loki log rotation config...${NC}"
    
    cat > "$config_file" << 'EOF'
# Loki Log Rotation Configuration

/var/log/loki/*.log {
    daily
    rotate 14
    compress
    delaycompress
    missingok
    notifempty
    create 644 loki loki
    size 200M
    sharedscripts
    postrotate
        # Restart Loki container
        docker restart loki 2>/dev/null || true
        # Or send HUP signal if running as service
        systemctl reload loki 2>/dev/null || true
    endscript
}

# Docker container logs for Loki
/var/lib/docker/containers/*/loki*-json.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    copytruncate
    size 100M
}
EOF
    
    echo -e "${GREEN}  ✓ Created Loki config: $config_file${NC}"
}

# Function to create Alertmanager log rotation config
create_alertmanager_config() {
    local config_file="$CUSTOM_CONFIG_DIR/alertmanager"
    
    echo -e "${BLUE}Creating Alertmanager log rotation config...${NC}"
    
    cat > "$config_file" << 'EOF'
# Alertmanager Log Rotation Configuration

/var/log/alertmanager/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 644 alertmanager alertmanager
    size 50M
    sharedscripts
    postrotate
        # Restart Alertmanager container
        docker restart alertmanager 2>/dev/null || true
        # Or send HUP signal if running as service
        systemctl reload alertmanager 2>/dev/null || true
    endscript
}

# Docker container logs for Alertmanager
/var/lib/docker/containers/*/alertmanager*-json.log {
    daily
    rotate 14
    compress
    delaycompress
    missingok
    notifempty
    copytruncate
    size 25M
}
EOF
    
    echo -e "${GREEN}  ✓ Created Alertmanager config: $config_file${NC}"
}

# Function to create Alloy log rotation config
create_alloy_config() {
    local config_file="$CUSTOM_CONFIG_DIR/alloy"
    
    echo -e "${BLUE}Creating Alloy log rotation config...${NC}"
    
    cat > "$config_file" << 'EOF'
# Grafana Alloy Log Rotation Configuration

/var/log/alloy/*.log {
    daily
    rotate 14
    compress
    delaycompress
    missingok
    notifempty
    create 644 alloy alloy
    size 100M
    sharedscripts
    postrotate
        # Restart Alloy container
        docker restart alloy 2>/dev/null || true
        # Or send HUP signal if running as service
        systemctl reload alloy 2>/dev/null || true
    endscript
}

# Docker container logs for Alloy
/var/lib/docker/containers/*/alloy*-json.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    copytruncate
    size 50M
}
EOF
    
    echo -e "${GREEN}  ✓ Created Alloy config: $config_file${NC}"
}

# Function to create general Docker log rotation config
create_docker_config() {
    local config_file="$CUSTOM_CONFIG_DIR/docker-marketsage"
    
    echo -e "${BLUE}Creating Docker MarketSage log rotation config...${NC}"
    
    cat > "$config_file" << 'EOF'
# Docker MarketSage Container Log Rotation Configuration

/var/lib/docker/containers/*/marketsage*-json.log {
    daily
    rotate 14
    compress
    delaycompress
    missingok
    notifempty
    copytruncate
    size 100M
}

# General monitoring stack container logs
/var/lib/docker/containers/*/{grafana,prometheus,loki,alertmanager,alloy,cadvisor,redis-exporter,postgres-exporter}*-json.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    copytruncate
    size 50M
}
EOF
    
    echo -e "${GREEN}  ✓ Created Docker config: $config_file${NC}"
}

# Function to install logrotate configs
install_configs() {
    echo -e "${BLUE}Installing logrotate configurations...${NC}"
    
    if check_root; then
        for config_file in "$CUSTOM_CONFIG_DIR"/*; do
            if [[ -f "$config_file" ]]; then
                local filename=$(basename "$config_file")
                local target_file="$LOGROTATE_CONFIG_DIR/$filename"
                
                echo "Installing $filename to $target_file"
                cp "$config_file" "$target_file"
                chown root:root "$target_file"
                chmod 644 "$target_file"
                echo -e "${GREEN}  ✓ Installed: $target_file${NC}"
            fi
        done
    else
        echo -e "${YELLOW}  ⚠ Root access required to install to $LOGROTATE_CONFIG_DIR${NC}"
        echo "  You can manually copy the configs:"
        for config_file in "$CUSTOM_CONFIG_DIR"/*; do
            if [[ -f "$config_file" ]]; then
                local filename=$(basename "$config_file")
                echo "    sudo cp $config_file $LOGROTATE_CONFIG_DIR/$filename"
            fi
        done
    fi
    echo ""
}

# Function to test logrotate configuration
test_logrotate() {
    echo -e "${BLUE}Testing logrotate configuration...${NC}"
    
    if command -v logrotate &> /dev/null; then
        echo "Testing logrotate syntax..."
        
        if check_root; then
            logrotate -d /etc/logrotate.conf
        else
            echo -e "${YELLOW}  ⚠ Root access required to test system logrotate config${NC}"
            echo "  You can test manually with:"
            echo "    sudo logrotate -d /etc/logrotate.conf"
        fi
        
        # Test custom configs
        for config_file in "$CUSTOM_CONFIG_DIR"/*; do
            if [[ -f "$config_file" ]]; then
                local filename=$(basename "$config_file")
                echo "Testing $filename..."
                logrotate -d "$config_file" || {
                    echo -e "${RED}  ✗ Error in $filename${NC}"
                    continue
                }
                echo -e "${GREEN}  ✓ $filename syntax OK${NC}"
            fi
        done
    else
        echo -e "${YELLOW}⚠ logrotate not found. Install it to test configurations.${NC}"
    fi
    echo ""
}

# Function to create cron job for logrotate
setup_cron() {
    echo -e "${BLUE}Setting up cron job for logrotate...${NC}"
    
    local cron_script="./scripts/run-logrotate.sh"
    
    # Create logrotate runner script
    cat > "$cron_script" << 'EOF'
#!/bin/bash

# MarketSage Logrotate Runner
# Runs logrotate for custom configurations

CUSTOM_CONFIG_DIR="$(dirname "$0")/../config/logrotate"
LOG_DIR="/var/log/marketsage-logrotate"

# Create log directory
mkdir -p "$LOG_DIR"

# Run logrotate for each custom config
for config_file in "$CUSTOM_CONFIG_DIR"/*; do
    if [[ -f "$config_file" ]]; then
        config_name=$(basename "$config_file")
        logrotate -s "$LOG_DIR/logrotate-${config_name}.state" "$config_file" >> "$LOG_DIR/logrotate-${config_name}.log" 2>&1
    fi
done

# Also run system logrotate
/usr/sbin/logrotate /etc/logrotate.conf >> "$LOG_DIR/system-logrotate.log" 2>&1
EOF
    
    chmod +x "$cron_script"
    
    echo -e "${GREEN}  ✓ Created logrotate runner: $cron_script${NC}"
    echo ""
    echo -e "${YELLOW}To add to crontab (run daily at 2 AM):${NC}"
    echo "  0 2 * * * $PWD/$cron_script"
    echo ""
    echo -e "${BLUE}Add to crontab with:${NC}"
    echo "  (crontab -l 2>/dev/null; echo '0 2 * * * $PWD/$cron_script') | crontab -"
    echo ""
}

# Function to display summary
display_summary() {
    echo -e "${GREEN}=== Log Rotation Setup Summary ===${NC}"
    echo "Custom config directory: $CUSTOM_CONFIG_DIR"
    echo "System config directory: $LOGROTATE_CONFIG_DIR"
    echo ""
    echo -e "${BLUE}Created configurations for:${NC}"
    for config_file in "$CUSTOM_CONFIG_DIR"/*; do
        if [[ -f "$config_file" ]]; then
            local filename=$(basename "$config_file")
            echo "  - $filename"
        fi
    done
    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo "1. Review the generated configurations in $CUSTOM_CONFIG_DIR"
    echo "2. Install to system logrotate directory (requires root):"
    echo "   sudo cp $CUSTOM_CONFIG_DIR/* $LOGROTATE_CONFIG_DIR/"
    echo "3. Test the configuration:"
    echo "   sudo logrotate -d /etc/logrotate.conf"
    echo "4. Set up cron job to run logrotate daily"
    echo "5. Monitor log rotation with:"
    echo "   sudo logrotate -v /etc/logrotate.conf"
    echo ""
}

# Main execution
main() {
    # Check prerequisites
    if ! command -v logrotate &> /dev/null; then
        echo -e "${YELLOW}⚠ logrotate not found. Installing...${NC}"
        if check_root; then
            # Try to install logrotate
            apt-get update && apt-get install -y logrotate 2>/dev/null || \
            yum install -y logrotate 2>/dev/null || \
            echo -e "${RED}Failed to install logrotate. Please install it manually.${NC}"
        else
            echo -e "${RED}Please install logrotate manually:${NC}"
            echo "  Ubuntu/Debian: sudo apt-get install logrotate"
            echo "  RHEL/CentOS: sudo yum install logrotate"
            echo "  macOS: brew install logrotate"
        fi
    fi
    
    # Create log directories
    create_log_dirs
    
    # Create custom config directory
    create_custom_config_dir
    
    # Create all logrotate configurations
    create_marketsage_config
    create_grafana_config
    create_prometheus_config
    create_loki_config
    create_alertmanager_config
    create_alloy_config
    create_docker_config
    
    # Install configurations
    install_configs
    
    # Test configurations
    test_logrotate
    
    # Setup cron job
    setup_cron
    
    # Display summary
    display_summary
    
    echo -e "${GREEN}✓ Log rotation setup completed!${NC}"
}

# Cleanup function
cleanup() {
    echo ""
    echo -e "${YELLOW}Setup interrupted. Cleaning up...${NC}"
    exit 1
}

# Set up signal handlers
trap cleanup SIGINT SIGTERM

# Run main function
main "$@"