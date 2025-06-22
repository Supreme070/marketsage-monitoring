#!/bin/bash

# MarketSage Grafana Dashboard Restore Script
# Restores dashboards from backup file to Grafana instance

set -e

# Configuration
GRAFANA_URL="http://grafana:3000"
GRAFANA_API_KEY_FILE="/run/secrets/grafana_cloud_api_key"
BACKUP_DIR="./backups/dashboards"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Usage function
usage() {
    echo "Usage: $0 [OPTIONS] <backup_file>"
    echo ""
    echo "Options:"
    echo "  -h, --help          Show this help message"
    echo "  -f, --force         Force restore (overwrite existing dashboards)"
    echo "  -d, --dry-run       Show what would be restored without making changes"
    echo "  -l, --list          List available backup files"
    echo ""
    echo "Examples:"
    echo "  $0 dashboards_backup_20231201_120000.json.gz"
    echo "  $0 --dry-run dashboards_backup_20231201_120000.json.gz"
    echo "  $0 --list"
    exit 1
}

# Function to list available backups
list_backups() {
    echo -e "${BLUE}=== Available Dashboard Backups ===${NC}"
    
    if [[ ! -d "$BACKUP_DIR" ]]; then
        echo -e "${YELLOW}No backup directory found at: $BACKUP_DIR${NC}"
        return 1
    fi
    
    local backups_found=false
    for backup_file in "$BACKUP_DIR"/dashboards_backup_*.json.gz "$BACKUP_DIR"/dashboards_backup_*.json; do
        if [[ -f "$backup_file" ]]; then
            backups_found=true
            local filename=$(basename "$backup_file")
            local size=$(du -h "$backup_file" | cut -f1)
            local date=$(stat -f %Sm -t "%Y-%m-%d %H:%M:%S" "$backup_file" 2>/dev/null || stat -c %y "$backup_file" 2>/dev/null | cut -d. -f1)
            echo "  $filename ($size) - $date"
        fi
    done
    
    if [[ "$backups_found" != true ]]; then
        echo -e "${YELLOW}No backup files found in $BACKUP_DIR${NC}"
        return 1
    fi
}

# Parse command line arguments
FORCE=false
DRY_RUN=false
BACKUP_FILE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            ;;
        -f|--force)
            FORCE=true
            shift
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -l|--list)
            list_backups
            exit 0
            ;;
        *)
            if [[ -z "$BACKUP_FILE" ]]; then
                BACKUP_FILE="$1"
            else
                echo -e "${RED}Error: Multiple backup files specified${NC}"
                usage
            fi
            shift
            ;;
    esac
done

if [[ -z "$BACKUP_FILE" ]]; then
    echo -e "${RED}Error: Backup file not specified${NC}"
    usage
fi

echo -e "${GREEN}=== MarketSage Grafana Dashboard Restore ===${NC}"
echo "Starting restore at $(date)"

# Resolve backup file path
if [[ ! -f "$BACKUP_FILE" ]]; then
    # Try in backup directory
    BACKUP_FILE_PATH="${BACKUP_DIR}/${BACKUP_FILE}"
    if [[ ! -f "$BACKUP_FILE_PATH" ]]; then
        echo -e "${RED}Error: Backup file not found: $BACKUP_FILE${NC}"
        echo "Available backups:"
        list_backups
        exit 1
    fi
    BACKUP_FILE="$BACKUP_FILE_PATH"
fi

echo "Backup file: $BACKUP_FILE"

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

# Function to extract and parse backup file
extract_backup() {
    local temp_file=$(mktemp)
    
    echo "Extracting backup file..."
    
    if [[ "$BACKUP_FILE" == *.gz ]]; then
        if ! gunzip -c "$BACKUP_FILE" > "$temp_file"; then
            echo -e "${RED}Error: Failed to extract compressed backup file${NC}"
            rm -f "$temp_file"
            return 1
        fi
    else
        cp "$BACKUP_FILE" "$temp_file"
    fi
    
    # Validate JSON
    if ! jq . "$temp_file" > /dev/null 2>&1; then
        echo -e "${RED}Error: Backup file is not valid JSON${NC}"
        rm -f "$temp_file"
        return 1
    fi
    
    echo "$temp_file"
}

# Function to restore a single dashboard
restore_dashboard() {
    local dashboard_json="$1"
    local dashboard_title=$(echo "$dashboard_json" | jq -r '.dashboard.title // "Unknown"')
    local dashboard_uid=$(echo "$dashboard_json" | jq -r '.dashboard.uid // ""')
    
    echo "Restoring dashboard: $dashboard_title (UID: $dashboard_uid)"
    
    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${BLUE}  [DRY RUN] Would restore dashboard: $dashboard_title${NC}"
        return 0
    fi
    
    # Check if dashboard already exists
    local existing_dashboard=""
    if [[ -n "$dashboard_uid" ]]; then
        existing_dashboard=$(curl -s -H "Authorization: Bearer $GRAFANA_API_KEY" \
                                 "$GRAFANA_URL/api/dashboards/uid/$dashboard_uid" 2>/dev/null || true)
    fi
    
    if [[ -n "$existing_dashboard" ]] && [[ "$existing_dashboard" != *"Dashboard not found"* ]]; then
        if [[ "$FORCE" != true ]]; then
            echo -e "${YELLOW}  ⚠ Dashboard already exists, skipping (use --force to overwrite)${NC}"
            return 0
        fi
        echo "  Overwriting existing dashboard..."
    fi
    
    # Prepare dashboard for import
    local import_json=$(echo "$dashboard_json" | jq '{
        dashboard: .dashboard,
        overwrite: true,
        inputs: [],
        folderId: (.meta.folderId // 0)
    }')
    
    # Import dashboard
    local response=$(curl -s -w "%{http_code}" -H "Authorization: Bearer $GRAFANA_API_KEY" \
                         -H "Content-Type: application/json" \
                         -X POST "$GRAFANA_URL/api/dashboards/db" \
                         -d "$import_json")
    
    local http_code="${response: -3}"
    local response_body="${response%???}"
    
    if [[ "$http_code" == "200" ]]; then
        echo -e "${GREEN}  ✓ Dashboard restored successfully${NC}"
        return 0
    else
        echo -e "${RED}  ✗ Failed to restore dashboard (HTTP $http_code)${NC}"
        echo "  Response: $response_body"
        return 1
    fi
}

# Main restore process
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
    
    # Extract backup file
    local temp_backup_file
    temp_backup_file=$(extract_backup)
    if [[ $? -ne 0 ]]; then
        exit 1
    fi
    
    # Get backup metadata
    local backup_date=$(jq -r '.backup_date // "Unknown"' "$temp_backup_file")
    local backup_grafana_url=$(jq -r '.grafana_url // "Unknown"' "$temp_backup_file")
    local dashboard_count=$(jq '.dashboards | length' "$temp_backup_file")
    
    echo ""
    echo -e "${BLUE}=== Backup Information ===${NC}"
    echo "Backup Date: $backup_date"
    echo "Original Grafana URL: $backup_grafana_url"
    echo "Dashboards in backup: $dashboard_count"
    echo ""
    
    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${BLUE}=== DRY RUN MODE ===${NC}"
        echo "The following dashboards would be restored:"
        echo ""
    fi
    
    # Restore each dashboard
    local restore_count=0
    local failed_count=0
    local skipped_count=0
    
    for i in $(seq 0 $((dashboard_count - 1))); do
        local dashboard_json=$(jq ".dashboards[$i]" "$temp_backup_file")
        
        if restore_dashboard "$dashboard_json"; then
            ((restore_count++))
        else
            ((failed_count++))
        fi
    done
    
    # Cleanup
    rm -f "$temp_backup_file"
    
    # Summary
    echo ""
    echo -e "${GREEN}=== Restore Summary ===${NC}"
    echo "Date: $(date)"
    echo "Dashboards processed: $dashboard_count"
    
    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${BLUE}Dashboards that would be restored: $restore_count${NC}"
    else
        echo "Dashboards restored: $restore_count"
        echo "Failed restores: $failed_count"
        echo "Skipped dashboards: $skipped_count"
        
        if [[ $failed_count -eq 0 ]]; then
            echo -e "${GREEN}✓ All dashboards restored successfully!${NC}"
            exit 0
        else
            echo -e "${YELLOW}⚠ Some dashboards failed to restore${NC}"
            exit 1
        fi
    fi
}

# Cleanup function
cleanup() {
    echo ""
    echo -e "${YELLOW}Restore interrupted. Cleaning up...${NC}"
    rm -f /tmp/dashboard_restore_*
    exit 1
}

# Set up signal handlers
trap cleanup SIGINT SIGTERM

# Run main function
main "$@"