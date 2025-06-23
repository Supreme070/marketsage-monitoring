#!/bin/bash
set -e

echo "🎯 Setting up MarketSage Monitoring Staging Strategy"
echo "=================================================="

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "❌ Not in a git repository. Please run this from the project root."
    exit 1
fi

# Ensure we're on main branch and up to date
echo "📋 Checking current branch and status..."
current_branch=$(git branch --show-current)
if [ "$current_branch" != "main" ]; then
    echo "⚠️  You're on branch '$current_branch'. Switching to main..."
    git checkout main
fi

echo "🔄 Pulling latest changes from main..."
git pull origin main

# Create staging branch
echo "🏗️ Creating staging branch..."
if git show-ref --verify --quiet refs/heads/staging; then
    echo "ℹ️  Staging branch already exists. Updating..."
    git checkout staging
    git merge main
else
    echo "✨ Creating new staging branch from main..."
    git checkout -b staging
fi

# Push staging branch
echo "📤 Pushing staging branch to remote..."
git push -u origin staging

# Create develop branch
echo "🔧 Creating develop branch..."
if git show-ref --verify --quiet refs/heads/develop; then
    echo "ℹ️  Develop branch already exists. Updating..."
    git checkout develop
    git merge main
else
    echo "✨ Creating new develop branch from main..."
    git checkout -b develop
fi

# Push develop branch
echo "📤 Pushing develop branch to remote..."
git push -u origin develop

# Create environment-specific configurations
echo "⚙️ Creating environment-specific configurations..."

# Create environments directory
mkdir -p environments/{staging,production,development}

# Staging configuration
cat > environments/staging/docker-compose.staging.yml << 'EOF'
# Staging environment overrides for MarketSage Monitoring
version: '3.8'

services:
  grafana:
    container_name: grafana-staging
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=staging-admin-pass
      - GF_SERVER_ROOT_URL=http://localhost:3001
    ports:
      - "3001:3000"

  prometheus:
    container_name: prometheus-staging
    ports:
      - "9091:9090"
    command:
      - --config.file=/etc/prometheus/prometheus.yml
      - --storage.tsdb.path=/prometheus
      - --web.console.libraries=/etc/prometheus/console_libraries
      - --web.console.templates=/etc/prometheus/consoles
      - --storage.tsdb.retention.time=7d
      - --web.enable-remote-write-receiver

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

# Staging environment variables
cat > environments/staging/.env.staging << 'EOF'
# Staging Environment Configuration
ENVIRONMENT=staging

# Grafana Cloud (Staging)
GRAFANA_CLOUD_API_KEY=your_staging_api_key_here
GRAFANA_CLOUD_PROMETHEUS_URL=https://prometheus-prod-your-region.grafana.net/api/prom/push
GRAFANA_CLOUD_PROMETHEUS_USER=your_staging_prometheus_user
GRAFANA_CLOUD_LOKI_URL=https://logs-prod-your-region.grafana.net/loki/api/v1/push
GRAFANA_CLOUD_LOKI_USER=your_staging_loki_user

# MarketSage Connection (Staging)
MARKETSAGE_NETWORK=marketsage_staging
MARKETSAGE_APP_URL=marketsage-web-staging:3000

# Database Configuration (Staging)
POSTGRES_PASSWORD=staging_password
REDIS_PASSWORD=

# Retention (Shorter for staging)
PROMETHEUS_RETENTION=7d
LOKI_RETENTION=7d
EOF

# Development configuration
cat > environments/development/docker-compose.dev.yml << 'EOF'
# Development environment overrides for MarketSage Monitoring
version: '3.8'

services:
  grafana:
    container_name: grafana-dev
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=dev
      - GF_SERVER_ROOT_URL=http://localhost:3002
    ports:
      - "3002:3000"

  prometheus:
    container_name: prometheus-dev
    ports:
      - "9092:9090"
    command:
      - --config.file=/etc/prometheus/prometheus.yml
      - --storage.tsdb.path=/prometheus
      - --web.console.libraries=/etc/prometheus/console_libraries
      - --web.console.templates=/etc/prometheus/consoles
      - --storage.tsdb.retention.time=1d
      - --web.enable-remote-write-receiver

  loki:
    container_name: loki-dev
    ports:
      - "3102:3100"

  alloy:
    container_name: alloy-dev
    ports:
      - "12347:12345"

  alertmanager:
    container_name: alertmanager-dev
    ports:
      - "9095:9093"

networks:
  monitoring:
    name: monitoring-dev
EOF

# Development environment variables
cat > environments/development/.env.development << 'EOF'
# Development Environment Configuration
ENVIRONMENT=development

# No Grafana Cloud for development (local only)
GRAFANA_CLOUD_API_KEY=disabled
GRAFANA_CLOUD_PROMETHEUS_URL=disabled
GRAFANA_CLOUD_PROMETHEUS_USER=disabled
GRAFANA_CLOUD_LOKI_URL=disabled
GRAFANA_CLOUD_LOKI_USER=disabled

# MarketSage Connection (Development)
MARKETSAGE_NETWORK=marketsage_dev
MARKETSAGE_APP_URL=marketsage-web-dev:3000

# Database Configuration (Development)
POSTGRES_PASSWORD=dev_password
REDIS_PASSWORD=

# Retention (Very short for development)
PROMETHEUS_RETENTION=1d
LOKI_RETENTION=1d
EOF

# Production configuration (copy from current)
cat > environments/production/docker-compose.production.yml << 'EOF'
# Production environment - uses base docker-compose.yml
# This file exists for potential production-specific overrides
version: '3.8'

services:
  grafana:
    environment:
      - GF_SECURITY_ADMIN_PASSWORD_FILE=/run/secrets/grafana_admin_password
EOF

cp .env environments/production/.env.production

# Update Makefile with environment support
cat >> Makefile << 'EOF'

# Environment-specific commands
start-staging: ## Start staging environment
	@echo "🏗️ Starting staging environment..."
	@docker-compose -f docker-compose.yml -f environments/staging/docker-compose.staging.yml --env-file environments/staging/.env.staging up -d

start-dev: ## Start development environment
	@echo "🔧 Starting development environment..."
	@docker-compose -f docker-compose.yml -f environments/development/docker-compose.dev.yml --env-file environments/development/.env.development up -d

start-production: ## Start production environment
	@echo "🚀 Starting production environment..."
	@docker-compose -f docker-compose.yml -f environments/production/docker-compose.production.yml --env-file environments/production/.env.production up -d

stop-staging: ## Stop staging environment
	@docker-compose -f docker-compose.yml -f environments/staging/docker-compose.staging.yml down

stop-dev: ## Stop development environment
	@docker-compose -f docker-compose.yml -f environments/development/docker-compose.dev.yml down

stop-production: ## Stop production environment
	@docker-compose -f docker-compose.yml -f environments/production/docker-compose.production.yml down

# Environment URLs
urls-staging: ## Show staging URLs
	@echo "🏗️ Staging Environment URLs:"
	@echo "Grafana: http://localhost:3001 (admin/staging-admin-pass)"
	@echo "Prometheus: http://localhost:9091"
	@echo "Loki: http://localhost:3101"

urls-dev: ## Show development URLs
	@echo "🔧 Development Environment URLs:"
	@echo "Grafana: http://localhost:3002 (admin/dev)"
	@echo "Prometheus: http://localhost:9092"
	@echo "Loki: http://localhost:3102"

urls-production: ## Show production URLs
	@echo "🚀 Production Environment URLs:"
	@echo "Grafana: http://localhost:3000 (admin/[from secrets])"
	@echo "Prometheus: http://localhost:9090"
	@echo "Loki: http://localhost:3100"
EOF

# Create environment setup script
cat > scripts/switch-environment.sh << 'EOF'
#!/bin/bash
set -e

ENVIRONMENT=${1:-staging}

case $ENVIRONMENT in
    staging)
        echo "🏗️ Switching to staging environment..."
        git checkout staging
        cp environments/staging/.env.staging .env
        echo "✅ Staging environment ready"
        echo "Run: make start-staging"
        ;;
    develop|development)
        echo "🔧 Switching to development environment..."
        git checkout develop
        cp environments/development/.env.development .env
        echo "✅ Development environment ready"
        echo "Run: make start-dev"
        ;;
    production|prod)
        echo "🚀 Switching to production environment..."
        git checkout main
        cp environments/production/.env.production .env
        echo "✅ Production environment ready"
        echo "Run: make start-production"
        ;;
    *)
        echo "❌ Unknown environment: $ENVIRONMENT"
        echo "Available environments: staging, development, production"
        exit 1
        ;;
esac
EOF

chmod +x scripts/switch-environment.sh

# Go back to main branch
git checkout main

# Add all new files
echo "📝 Adding new environment configurations..."
git add environments/ scripts/switch-environment.sh
git add Makefile

# Commit the changes
echo "💾 Committing staging setup..."
git commit -m "Set up staging strategy with multi-environment support

🎯 Added complete staging strategy:
- Created staging and develop branches
- Environment-specific configurations
- Docker Compose overrides for each environment
- Makefile commands for environment management
- Environment switching script

Environments:
- staging: Pre-production testing (ports 3001, 9091, etc.)
- development: Local development (ports 3002, 9092, etc.)
- production: Live environment (ports 3000, 9090, etc.)

Usage:
  make start-staging    # Start staging environment
  make start-dev        # Start development environment
  make start-production # Start production environment

🤖 Generated with Claude Code

Co-Authored-By: Claude <noreply@anthropic.com>"

# Push the changes
echo "📤 Pushing changes to main..."
git push origin main

# Update staging and develop branches with the new setup
echo "🔄 Updating staging branch..."
git checkout staging
git merge main
git push origin staging

echo "🔄 Updating develop branch..."
git checkout develop
git merge main
git push origin develop

# Return to main
git checkout main

echo ""
echo "🎉 Staging strategy setup complete!"
echo "=================================="
echo ""
echo "📋 Created Branches:"
echo "  - main (production)"
echo "  - staging (pre-production)"  
echo "  - develop (development)"
echo ""
echo "⚙️ Environment Configurations:"
echo "  - environments/staging/ (ports 3001+)"
echo "  - environments/development/ (ports 3002+)"
echo "  - environments/production/ (ports 3000+)"
echo ""
echo "🚀 Quick Start:"
echo "  ./scripts/switch-environment.sh staging"
echo "  make start-staging"
echo ""
echo "📖 Next Steps:"
echo "  1. Update GitHub repository settings:"
echo "     - Create 'staging' and 'production' environments"
echo "     - Set up branch protection rules"
echo "     - Configure environment secrets"
echo "  2. Test each environment:"
echo "     - make start-staging && make urls-staging"
echo "     - make start-dev && make urls-dev"
echo "  3. Update CI/CD workflows for new branch structure"
echo ""
EOF