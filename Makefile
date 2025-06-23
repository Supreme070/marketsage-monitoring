# MarketSage Monitoring Makefile
# Provides convenient commands for development and deployment

.PHONY: help install start stop restart logs health validate clean deploy test

# Default target
help: ## Show this help message
	@echo "MarketSage Monitoring - Available Commands:"
	@echo "==========================================="
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

install: ## Install dependencies and setup environment
	@echo "🔧 Setting up MarketSage Monitoring..."
	@cp .env.example .env || true
	@cp -r secrets.example secrets || true
	@echo "✅ Environment setup complete"
	@echo "⚠️  Please update .env and secrets/ with your actual credentials"

validate: ## Validate all configurations
	@echo "🔍 Validating configurations..."
	@docker-compose config --quiet && echo "✅ Docker Compose config valid" || (echo "❌ Docker Compose config invalid" && exit 1)
	@docker run --rm -v $(PWD)/config:/config prom/prometheus:latest promtool check config /config/prometheus.yml && echo "✅ Prometheus config valid" || (echo "❌ Prometheus config invalid" && exit 1)
	@docker run --rm -v $(PWD)/config:/config grafana/loki:latest -config.file=/config/loki.yml -verify-config && echo "✅ Loki config valid" || (echo "❌ Loki config invalid" && exit 1)
	@docker run --rm -v $(PWD)/alloy/config:/config grafana/alloy:latest fmt /config/config.alloy --write=false && echo "✅ Alloy config valid" || (echo "❌ Alloy config invalid" && exit 1)
	@echo "🎉 All configurations are valid!"

start: ## Start the monitoring stack
	@echo "🚀 Starting MarketSage Monitoring Stack..."
	@docker-compose up -d
	@echo "⏳ Waiting for services to be ready..."
	@sleep 30
	@make health

stop: ## Stop the monitoring stack
	@echo "🛑 Stopping MarketSage Monitoring Stack..."
	@docker-compose down

restart: ## Restart the monitoring stack
	@echo "🔄 Restarting MarketSage Monitoring Stack..."
	@make stop
	@sleep 5
	@make start

logs: ## Show logs from all services
	@echo "📋 Showing logs from all services..."
	@docker-compose logs -f

logs-service: ## Show logs from specific service (usage: make logs-service SERVICE=prometheus)
	@echo "📋 Showing logs from $(SERVICE)..."
	@docker-compose logs -f $(SERVICE)

health: ## Check health of all monitoring services
	@echo "🏥 Checking health of monitoring services..."
	@./docker-entrypoint.sh health

status: ## Show status of all containers
	@echo "📊 Container Status:"
	@docker-compose ps

clean: ## Clean up containers, volumes, and networks
	@echo "🧹 Cleaning up monitoring infrastructure..."
	@docker-compose down -v --remove-orphans
	@docker system prune -f
	@echo "✅ Cleanup complete"

backup: ## Backup monitoring data and configurations
	@echo "💾 Creating backup..."
	@mkdir -p backups/$(shell date +%Y%m%d_%H%M%S)
	@docker-compose exec prometheus tar czf - /prometheus > backups/$(shell date +%Y%m%d_%H%M%S)/prometheus-data.tar.gz
	@docker-compose exec loki tar czf - /loki > backups/$(shell date +%Y%m%d_%H%M%S)/loki-data.tar.gz
	@docker-compose exec grafana tar czf - /var/lib/grafana > backups/$(shell date +%Y%m%d_%H%M%S)/grafana-data.tar.gz
	@echo "✅ Backup complete"

test: ## Run comprehensive tests
	@echo "🧪 Running comprehensive tests..."
	@make validate
	@./scripts/test-monitoring.sh
	@echo "✅ All tests passed!"

deploy-staging: ## Deploy to staging environment
	@echo "🚀 Deploying to staging..."
	@gh workflow run deploy.yml --field environment=staging
	@echo "✅ Staging deployment triggered"

deploy-production: ## Deploy to production environment
	@echo "🚀 Deploying to production..."
	@read -p "Are you sure you want to deploy to production? (y/N): " confirm && [ "$$confirm" = "y" ] || exit 1
	@gh workflow run deploy.yml --field environment=production
	@echo "✅ Production deployment triggered"

update: ## Update to latest configurations
	@echo "🔄 Updating MarketSage Monitoring..."
	@git pull origin main
	@make validate
	@make restart
	@echo "✅ Update complete"

urls: ## Display service URLs
	@echo ""
	@echo "📊 MarketSage Monitoring Service URLs:"
	@echo "======================================"
	@echo "🏠 Grafana Dashboard: http://localhost:3000 (admin/admin)"
	@echo "📈 Prometheus: http://localhost:9090"
	@echo "📋 Loki Logs: http://localhost:3100"
	@echo "🔔 Alertmanager: http://localhost:9093"
	@echo "⚙️  Alloy Agent: http://localhost:12345"
	@echo "======================================"
	@echo ""

dev: ## Start development environment with live reload
	@echo "🛠️ Starting development environment..."
	@docker-compose -f docker-compose.yml -f docker-compose.dev.yml up -d
	@make urls

# CI/CD Commands
ci-validate: ## Run CI validation checks
	@echo "🔍 Running CI validation..."
	@make validate
	@./scripts/security-check.sh
	@echo "✅ CI validation complete"

ci-test: ## Run CI tests
	@echo "🧪 Running CI tests..."
	@./scripts/ci-test.sh
	@echo "✅ CI tests complete"

# Monitoring Commands
metrics: ## Show key metrics
	@echo "📊 Key Monitoring Metrics:"
	@echo "=========================="
	@curl -s "http://localhost:9090/api/v1/query?query=up" | jq -r '.data.result[] | "\(.metric.job): \(.value[1])"' | while read line; do echo "✅ $$line"; done
	@echo "=========================="

alerts: ## Show active alerts
	@echo "🚨 Active Alerts:"
	@echo "================"
	@curl -s "http://localhost:9093/api/v1/alerts" | jq -r '.data[] | select(.state=="firing") | "\(.labels.alertname): \(.annotations.summary)"'
	@echo "================"

dashboard-import: ## Import Grafana dashboards
	@echo "📊 Importing Grafana dashboards..."
	@./scripts/import-dashboards.sh
	@echo "✅ Dashboards imported"