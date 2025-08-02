#!/bin/bash

# Import NestJS Dashboard to Grafana

GRAFANA_URL="${GRAFANA_URL:-http://localhost:3000}"
GRAFANA_USER="${GRAFANA_USER:-admin}"
GRAFANA_PASSWORD="${GRAFANA_PASSWORD:-admin}"

echo "Importing NestJS Backend Monitoring dashboard..."

# Read the dashboard JSON
DASHBOARD_JSON=$(cat /Users/supreme/Desktop/marketsage-monitoring/grafana/dashboards/nestjs-backend-monitoring.json)

# Wrap it in the import format
IMPORT_JSON=$(cat <<EOF
{
  "dashboard": ${DASHBOARD_JSON},
  "overwrite": true,
  "inputs": [],
  "folderId": 0
}
EOF
)

# Import the dashboard
response=$(curl -s -X POST \
  -H "Content-Type: application/json" \
  -u "${GRAFANA_USER}:${GRAFANA_PASSWORD}" \
  -d "${IMPORT_JSON}" \
  "${GRAFANA_URL}/api/dashboards/db")

if echo "$response" | grep -q '"status":"success"'; then
  echo "✅ Dashboard imported successfully!"
  dashboard_url=$(echo "$response" | grep -o '"url":"[^"]*' | cut -d'"' -f4)
  echo "📊 View dashboard at: ${GRAFANA_URL}${dashboard_url}"
else
  echo "❌ Failed to import dashboard:"
  echo "$response"
  exit 1
fi