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
