# MarketSage Monitoring - Staging Setup Guide

## 🎯 Staging Strategy Implementation

### Branch Strategy

```
main (production)
├── staging (pre-production)
├── develop (development)
└── feature/* (feature branches)
```

### Environment Mapping
- **`main` branch** → **Production Environment**
- **`staging` branch** → **Staging Environment** 
- **`develop` branch** → **Development Environment**
- **`feature/*` branches** → **Local Development**

## 🚀 Quick Setup Commands

### 1. Create Staging Infrastructure

```bash
# Create staging branch
git checkout -b staging
git push -u origin staging

# Create develop branch  
git checkout -b develop
git push -u origin develop

# Go back to main
git checkout main
```

### 2. Set up GitHub Environments

In your GitHub repository settings:
1. Go to **Settings** → **Environments**
2. Create these environments:
   - `staging` (auto-deploy from staging branch)
   - `production` (manual approval required)
   - `development` (auto-deploy from develop branch)

### 3. Configure Branch Protection

```bash
# Protect main branch (require PR reviews)
# Protect staging branch (require status checks)
# Allow develop branch (for rapid iteration)
```

## 🏗️ Environment Configurations

### Staging Environment (`staging` branch)
- **Purpose**: Pre-production testing with production-like data
- **Infrastructure**: Separate containers with staging prefixes
- **Data**: Anonymized production data or realistic test data
- **Access**: Development team + QA team
- **Deployment**: Automatic on push to staging branch

### Development Environment (`develop` branch)  
- **Purpose**: Integration testing and development
- **Infrastructure**: Lightweight containers for rapid iteration
- **Data**: Test data and mock services
- **Access**: Development team only
- **Deployment**: Automatic on push to develop branch

### Production Environment (`main` branch)
- **Purpose**: Live production monitoring
- **Infrastructure**: Full production setup
- **Data**: Real production data
- **Access**: Operations team only
- **Deployment**: Manual approval required

## 📁 Environment-Specific Configurations

### Directory Structure
```
environments/
├── staging/
│   ├── docker-compose.staging.yml
│   ├── .env.staging
│   └── config/
├── production/
│   ├── docker-compose.production.yml
│   ├── .env.production
│   └── config/
└── development/
    ├── docker-compose.dev.yml
    ├── .env.development
    └── config/
```

### Workflow Integration
- **Staging deploys** automatically when code is pushed to `staging` branch
- **Production deploys** require manual approval and must come from `main` branch
- **Development deploys** happen on every push to `develop` branch

## 🔄 Recommended Workflow

### For New Features
```bash
# 1. Create feature branch from develop
git checkout develop
git pull origin develop
git checkout -b feature/monitoring-enhancement

# 2. Develop and test locally
make validate
make test

# 3. Push and create PR to develop
git push -u origin feature/monitoring-enhancement
# Create PR: feature/monitoring-enhancement → develop

# 4. After develop testing, create PR to staging
# Create PR: develop → staging

# 5. After staging validation, create PR to main
# Create PR: staging → main (requires approval)
```

### For Hotfixes
```bash
# 1. Create hotfix branch from main
git checkout main
git checkout -b hotfix/critical-fix

# 2. Fix and test
make validate
make test

# 3. Deploy to staging first
git checkout staging
git merge hotfix/critical-fix
git push origin staging

# 4. After validation, deploy to production
git checkout main
git merge hotfix/critical-fix
git push origin main
```

## 🔐 Environment Secrets

### GitHub Repository Secrets
```bash
# Staging Environment
GRAFANA_CLOUD_API_KEY_STAGING
GRAFANA_CLOUD_PROMETHEUS_USER_STAGING
GRAFANA_CLOUD_LOKI_USER_STAGING
STAGING_SLACK_WEBHOOK_URL

# Production Environment  
GRAFANA_CLOUD_API_KEY_PRODUCTION
GRAFANA_CLOUD_PROMETHEUS_USER_PRODUCTION
GRAFANA_CLOUD_LOKI_USER_PRODUCTION
PRODUCTION_SLACK_WEBHOOK_URL

# Development Environment
DEV_SLACK_WEBHOOK_URL
```

### Environment-Specific Variables
```bash
# staging/.env
ENVIRONMENT=staging
GRAFANA_ADMIN_PASSWORD=staging-admin-pass
PROMETHEUS_RETENTION=7d
LOKI_RETENTION=7d

# production/.env  
ENVIRONMENT=production
GRAFANA_ADMIN_PASSWORD_FILE=/run/secrets/grafana_admin_password
PROMETHEUS_RETENTION=30d
LOKI_RETENTION=30d
```

## 🚦 GitHub Actions Integration

### Updated Workflow Triggers
```yaml
on:
  push:
    branches: [main, staging, develop]
  pull_request:
    branches: [main, staging]
```

### Environment-Specific Jobs
```yaml
deploy-development:
  if: github.ref == 'refs/heads/develop'
  environment: development

deploy-staging:
  if: github.ref == 'refs/heads/staging'  
  environment: staging

deploy-production:
  if: github.ref == 'refs/heads/main'
  environment: production
```

## 📊 Monitoring Each Environment

### Environment Isolation
- **Staging**: `http://staging-monitoring.yourdomain.com`
- **Production**: `http://monitoring.yourdomain.com`
- **Development**: `http://localhost:3000` (local only)

### Data Separation
- Different Grafana Cloud workspaces per environment
- Separate Prometheus/Loki instances
- Environment-specific alert channels

## 🎯 Quick Implementation

Choose your approach:

### Option A: Full Branch Strategy (Recommended)
```bash
# Set up complete branch structure
./scripts/setup-staging-branches.sh
```

### Option B: Environment-Only Strategy  
```bash
# Keep single branch, use environment configs
./scripts/setup-environment-configs.sh
```

### Option C: Minimal Staging
```bash
# Just add staging branch for now
git checkout -b staging
git push -u origin staging
```

## ✅ Benefits of This Setup

1. **🔒 Production Safety**: Multiple validation stages before production
2. **🧪 Realistic Testing**: Staging environment mirrors production
3. **🚀 Rapid Development**: Develop branch for quick iterations
4. **🔄 Easy Rollbacks**: Clear version control and deployment history
5. **👥 Team Collaboration**: Clear workflow for multiple developers
6. **📊 Environment Monitoring**: Separate monitoring for each environment

## 🚨 Next Steps

1. **Choose your strategy** (Option A recommended)
2. **Set up GitHub environments** in repository settings
3. **Configure branch protection rules**
4. **Update CI/CD workflows** for new branch structure
5. **Create environment-specific configurations**
6. **Train team on new workflow**

Would you like me to implement any of these options for you?