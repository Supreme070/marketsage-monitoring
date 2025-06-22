#!/bin/bash

# MarketSage Grafana Dashboard Backup Script
# Backs up all dashboards from Grafana instance

set -e

# Configuration
GRAFANA_URL="http://grafana:3000"
GRAFANA_API_KEY_FILE="/run/secrets/grafana_cloud_api_key"
BACKUP_DIR="./backups/dashboards"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="dashboards_backup_${DATE}.json"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== MarketSage Grafana Dashboard Backup ===${NC}"
echo "Starting backup at $(date)"

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Check if API key file exists
if [[ ! -f "$GRAFANA_API_KEY_FILE" ]]; then
    echo -e "${RED}Error: Grafana API key file not found at $GRAFANA_API_KEY_FILE${NC}"
    exit 1
fi

# Read API key
GRAFANA_API_KEY=$(cat "$GRAFANA_API_KEY_FILE")

if [[ -z "$GRAFANA_API_KEY" ]]; then
    echo -e "${RED}Error: Grafana API key is empty${NC}"
    exit 1
fi

# Function to check Grafana connectivity
check_grafana_connection() {
    echo "Checking Grafana connectivity..."
    if curl -s -f -H "Authorization: Bearer $GRAFANA_API_KEY" "$GRAFANA_URL/api/health" > /dev/null; then
        echo -e "${GREEN}✓ Grafana is accessible${NC}"
        return 0
    else
        echo -e "${RED}✗ Cannot connect to Grafana at $GRAFANA_URL${NC}"
        return 1
    fi
}

# Function to get all dashboard UIDs
get_dashboard_uids() {
    echo "Fetching dashboard list..."
    curl -s -H "Authorization: Bearer $GRAFANA_API_KEY" \
         "$GRAFANA_URL/api/search?type=dash-db" | \
         jq -r '.[].uid' 2>/dev/null || {
        echo -e "${RED}Error: Failed to fetch dashboard list${NC}"
        return 1
    }
}

# Function to backup a single dashboard
backup_dashboard() {
    local uid="$1"
    local dashboard_file="${BACKUP_DIR}/dashboard_${uid}_${DATE}.json"
    
    echo "Backing up dashboard: $uid"
    
    if curl -s -H "Authorization: Bearer $GRAFANA_API_KEY" \
            "$GRAFANA_URL/api/dashboards/uid/$uid" \
            -o "$dashboard_file"; then
        
        # Verify the backup file is valid JSON
        if jq . "$dashboard_file" > /dev/null 2>&1; then
            echo -e "${GREEN}✓ Dashboard $uid backed up successfully${NC}"
            return 0
        else
            echo -e "${RED}✗ Dashboard $uid backup is invalid JSON${NC}"
            rm -f "$dashboard_file"
            return 1
        fi
    else
        echo -e "${RED}✗ Failed to backup dashboard $uid${NC}"
        return 1
    fi
}

# Function to create combined backup file
create_combined_backup() {
    local combined_file="${BACKUP_DIR}/${BACKUP_FILE}"
    echo "Creating combined backup file: $combined_file"
    
    echo "{" > "$combined_file"
    echo "  \"backup_date\": \"$(date -Iseconds)\"," >> "$combined_file"
    echo "  \"grafana_url\": \"$GRAFANA_URL\"," >> "$combined_file"
    echo "  \"dashboards\": [" >> "$combined_file"
    
    local first=true
    for dashboard_file in "${BACKUP_DIR}"/dashboard_*_${DATE}.json; do
        if [[ -f "$dashboard_file" ]]; then
            if [[ "$first" != true ]]; then
                echo "," >> "$combined_file"
            fi
            cat "$dashboard_file" >> "$combined_file"
            first=false
        fi
    done
    
    echo "" >> "$combined_file"
    echo "  ]" >> "$combined_file"
    echo "}" >> "$combined_file"
    
    # Validate combined backup
    if jq . "$combined_file" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Combined backup created successfully${NC}"
        
        # Clean up individual files
        rm -f "${BACKUP_DIR}"/dashboard_*_${DATE}.json
        
        # Compress backup
        gzip "$combined_file"
        echo -e "${GREEN}✓ Backup compressed: ${combined_file}.gz${NC}"
    else
        echo -e "${RED}✗ Combined backup is invalid JSON${NC}"
        return 1
    fi
}

# Main backup process
main() {
    # Check prerequisites
    if ! command -v curl &> /dev/null; then
        echo -e "${RED}Error: curl is required but not installed${NC}"
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        echo -e "${RED}Error: jq is required but not installed${NC}"
        exit 1
    fi
    
    # Check Grafana connection
    if ! check_grafana_connection; then
        exit 1
    fi
    
    # Get dashboard UIDs
    dashboard_uids=$(get_dashboard_uids)
    if [[ -z "$dashboard_uids" ]]; then
        echo -e "${YELLOW}Warning: No dashboards found to backup${NC}"
        exit 0
    fi
    
    echo "Found $(echo "$dashboard_uids" | wc -l) dashboards to backup"
    
    # Backup each dashboard
    backup_count=0
    failed_count=0
    
    while IFS= read -r uid; do
        if [[ -n "$uid" ]]; then
            if backup_dashboard "$uid"; then
                ((backup_count++))
            else
                ((failed_count++))
            fi
        fi
    done <<< "$dashboard_uids"
    
    # Create combined backup if we have successful backups
    if [[ $backup_count -gt 0 ]]; then
        create_combined_backup
    fi
    
    # Summary
    echo ""
    echo -e "${GREEN}=== Backup Summary ===${NC}"
    echo "Date: $(date)"
    echo "Dashboards backed up: $backup_count"
    echo "Failed backups: $failed_count"
    echo "Backup location: $BACKUP_DIR"
    
    if [[ $failed_count -eq 0 ]]; then
        echo -e "${GREEN}✓ All dashboards backed up successfully!${NC}"
        exit 0
    else
        echo -e "${YELLOW}⚠ Some dashboards failed to backup${NC}"
        exit 1
    fi
}

# Cleanup function
cleanup() {
    echo ""
    echo -e "${YELLOW}Backup interrupted. Cleaning up...${NC}"
    rm -f "${BACKUP_DIR}"/dashboard_*_${DATE}.json
    exit 1
}

# Set up signal handlers
trap cleanup SIGINT SIGTERM

# Run main function
main "$@"