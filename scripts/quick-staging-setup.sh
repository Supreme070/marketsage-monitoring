#!/bin/bash
set -e

echo "🚀 Quick Staging Setup for MarketSage Monitoring"
echo "==============================================="

# Simple approach: Just create staging branch and basic environment configs

echo "📋 Current branch: $(git branch --show-current)"

# Ensure we're on main and up to date
if [ "$(git branch --show-current)" != "main" ]; then
    echo "🔄 Switching to main branch..."
    git checkout main
fi

echo "📥 Pulling latest changes..."
git pull origin main

# Create staging branch
echo "🏗️ Creating staging branch..."
if git show-ref --verify --quiet refs/heads/staging; then
    echo "ℹ️  Staging branch already exists"
    git checkout staging
else
    echo "✨ Creating new staging branch from main..."
    git checkout -b staging
    git push -u origin staging
fi

# Create simple staging environment file
echo "⚙️ Creating staging environment configuration..."
cat > .env.staging << 'EOF'
# Staging Environment Configuration
ENVIRONMENT=staging

# Grafana Cloud (Staging) - Update these with your staging credentials
GRAFANA_CLOUD_API_KEY=your_staging_api_key_here
GRAFANA_CLOUD_PROMETHEUS_URL=https://prometheus-prod-your-region.grafana.net/api/prom/push
GRAFANA_CLOUD_PROMETHEUS_USER=your_staging_prometheus_user
GRAFANA_CLOUD_LOKI_URL=https://logs-prod-your-region.grafana.net/loki/api/v1/push
GRAFANA_CLOUD_LOKI_USER=your_staging_loki_user

# MarketSage Connection - Staging network
MARKETSAGE_NETWORK=marketsage_staging
MARKETSAGE_APP_URL=marketsage-web-staging:3000

# Database Configuration
POSTGRES_PASSWORD=staging_password
REDIS_PASSWORD=

# Shorter retention for staging
PROMETHEUS_RETENTION=7d
LOKI_RETENTION=7d
EOF

# Create staging docker-compose override
echo "🐳 Creating staging Docker Compose override..."
cat > docker-compose.staging.yml << 'EOF'
# Staging environment overrides
version: '3.8'

services:
  grafana:
    container_name: grafana-staging
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=staging123
      - GF_SERVER_ROOT_URL=http://localhost:3001
    ports:
      - "3001:3000"

  prometheus:
    container_name: prometheus-staging
    ports:
      - "9091:9090"

  loki:
    container_name: loki-staging
    ports:
      - "3101:3100"

  alloy:
    container_name: alloy-staging
    ports:
      - "12346:12345"

  alertmanager:
    container_name: alertmanager-staging
    ports:
      - "9094:9093"

networks:
  monitoring:
    name: monitoring-staging
EOF

# Update Makefile with staging commands
echo "📝 Adding staging commands to Makefile..."
cat >> Makefile << 'EOF'

# Staging environment commands
start-staging: ## Start staging environment on different ports
	@echo "🏗️ Starting staging environment..."
	@docker-compose -f docker-compose.yml -f docker-compose.staging.yml --env-file .env.staging up -d

stop-staging: ## Stop staging environment
	@echo "🛑 Stopping staging environment..."
	@docker-compose -f docker-compose.yml -f docker-compose.staging.yml down

restart-staging: ## Restart staging environment
	@echo "🔄 Restarting staging environment..."
	@make stop-staging
	@sleep 5
	@make start-staging

urls-staging: ## Display staging service URLs
	@echo "🏗️ Staging Environment URLs:"
	@echo "================================"
	@echo "🏠 Grafana: http://localhost:3001 (admin/staging123)"
	@echo "📈 Prometheus: http://localhost:9091"
	@echo "📋 Loki: http://localhost:3101"
	@echo "🔔 Alertmanager: http://localhost:9094"
	@echo "⚙️ Alloy: http://localhost:12346"
	@echo "================================"

logs-staging: ## Show staging environment logs
	@docker-compose -f docker-compose.yml -f docker-compose.staging.yml logs -f

health-staging: ## Check staging environment health
	@echo "🏥 Checking staging environment health..."
	@curl -f http://localhost:3001/api/health && echo "✅ Grafana staging OK" || echo "❌ Grafana staging FAIL"
	@curl -f http://localhost:9091/-/ready && echo "✅ Prometheus staging OK" || echo "❌ Prometheus staging FAIL"
	@curl -f http://localhost:3101/ready && echo "✅ Loki staging OK" || echo "❌ Loki staging FAIL"
EOF

# Commit changes to staging branch
echo "💾 Committing staging configuration..."
git add .env.staging docker-compose.staging.yml Makefile
git commit -m "Add staging environment configuration

🏗️ Staging setup:
- .env.staging with staging-specific variables
- docker-compose.staging.yml with port overrides
- Makefile commands for staging operations

Staging URLs:
- Grafana: http://localhost:3001 (admin/staging123)
- Prometheus: http://localhost:9091
- Loki: http://localhost:3101
- Alertmanager: http://localhost:9094
- Alloy: http://localhost:12346

Usage:
  make start-staging
  make urls-staging
  make health-staging

🤖 Generated with Claude Code

Co-Authored-By: Claude <noreply@anthropic.com>"

echo "📤 Pushing staging branch..."
git push origin staging

# Go back to main and merge the Makefile updates
echo "🔄 Updating main branch with Makefile changes..."
git checkout main
git cherry-pick staging -- Makefile
git add Makefile
git commit -m "Add staging commands to Makefile

Added staging-specific commands:
- make start-staging
- make stop-staging  
- make restart-staging
- make urls-staging
- make logs-staging
- make health-staging

🤖 Generated with Claude Code

Co-Authored-By: Claude <noreply@anthropic.com>" || echo "ℹ️ Makefile already updated"

git push origin main

echo ""
echo "🎉 Quick staging setup complete!"
echo "================================"
echo ""
echo "📋 What was created:"
echo "  ✅ staging branch with staging configuration"
echo "  ✅ .env.staging with staging variables"
echo "  ✅ docker-compose.staging.yml with port overrides"
echo "  ✅ Makefile commands for staging operations"
echo ""
echo "🚀 To use staging environment:"
echo "  git checkout staging"
echo "  make start-staging"
echo "  make urls-staging"
echo ""
echo "🏗️ Staging runs on different ports to avoid conflicts:"
echo "  Grafana: http://localhost:3001 (admin/staging123)"
echo "  Prometheus: http://localhost:9091"
echo "  Loki: http://localhost:3101"
echo ""
echo "📖 Next steps:"
echo "  1. Set up GitHub environments in repository settings"
echo "  2. Configure staging secrets in GitHub"
echo "  3. Update .env.staging with real staging credentials"
echo "  4. Test: git checkout staging && make start-staging"
echo ""
EOF