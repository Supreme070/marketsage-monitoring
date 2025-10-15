# MarketSage Monitoring CI/CD Pipeline

This document describes the comprehensive CI/CD pipeline for the MarketSage monitoring infrastructure.

## 🏗️ Pipeline Overview

The CI/CD pipeline consists of multiple workflows that handle different aspects of the monitoring infrastructure:

### 1. Main CI/CD Workflow (`ci-cd.yml`)
**Triggers**: Push to main/develop, Pull Requests to main
- ✅ Configuration validation
- 🔒 Security scanning
- 🧪 Deployment testing
- 📦 Image building and publishing
- 🚀 Automated staging deployment
- 🎯 Production deployment (manual approval)

### 2. Configuration Validation (`config-validation.yml`)
**Triggers**: Changes to config files
- Validates Prometheus configuration
- Validates Loki configuration  
- Validates Alloy configuration
- Validates Alertmanager configuration
- Validates Grafana dashboards
- Security and performance checks

### 3. Deployment Workflow (`deploy.yml`)
**Triggers**: Manual dispatch
- Pre-deployment checks
- Environment-specific deployments
- Health checks and integration tests
- Rollback capabilities
- Notification system

### 4. Monitoring Health Check (`monitoring.yml`)
**Triggers**: Scheduled (every 6 hours), Manual dispatch
- Production health monitoring
- Performance monitoring
- Alert delivery testing
- Health report generation
- Failure notifications

## 🚀 Getting Started

### Prerequisites
1. GitHub repository with Actions enabled
2. Docker Hub or GitHub Container Registry access
3. Required secrets configured (see [Secrets Configuration](#secrets-configuration))

### Setup Steps

1. **Clone and Configure**
   ```bash
   git clone <repository-url>
   cd marketsage-monitoring
   make install
   ```

2. **Configure Secrets**
   - Update `.env` with your environment variables
   - Update `secrets/` directory with actual credentials
   - Configure GitHub repository secrets

3. **Test Locally**
   ```bash
   make validate
   make test
   make start
   ```

## 🔐 Secrets Configuration

Configure these secrets in your GitHub repository:

### Required Secrets
- `GRAFANA_CLOUD_API_KEY_STAGING` - Grafana Cloud API key for staging
- `GRAFANA_CLOUD_API_KEY_PRODUCTION` - Grafana Cloud API key for production
- `GRAFANA_CLOUD_PROMETHEUS_USER_STAGING` - Prometheus user ID for staging
- `GRAFANA_CLOUD_PROMETHEUS_USER_PRODUCTION` - Prometheus user ID for production
- `GRAFANA_CLOUD_LOKI_USER_STAGING` - Loki user ID for staging
- `GRAFANA_CLOUD_LOKI_USER_PRODUCTION` - Loki user ID for production
- `SLACK_WEBHOOK_URL` - Slack webhook for notifications

### Optional Secrets
- `DOCKER_REGISTRY_USERNAME` - Docker registry username
- `DOCKER_REGISTRY_PASSWORD` - Docker registry password
- `SSH_PRIVATE_KEY` - SSH key for production deployments
- `PRODUCTION_HOST` - Production server hostname

## 🛠️ Available Commands

### Development Commands
```bash
make help              # Show all available commands
make install           # Setup environment
make validate          # Validate configurations
make start             # Start monitoring stack
make stop              # Stop monitoring stack
make restart           # Restart monitoring stack
make health            # Check service health
make test              # Run comprehensive tests
```

### CI/CD Commands
```bash
make ci-validate       # Run CI validation checks
make ci-test           # Run CI tests
make deploy-staging    # Deploy to staging
make deploy-production # Deploy to production
```

### Monitoring Commands
```bash
make logs              # Show all service logs
make metrics           # Show key metrics
make alerts            # Show active alerts
make urls              # Display service URLs
```

## 📊 Workflow Details

### Validation Stage
- **Configuration Syntax**: Validates all YAML/JSON files
- **Security Scanning**: Checks for vulnerabilities and secrets
- **Dependency Updates**: Automated via Dependabot
- **Code Quality**: Linting and formatting checks

### Testing Stage
- **Unit Tests**: Configuration validation
- **Integration Tests**: Service connectivity
- **End-to-End Tests**: Full monitoring stack
- **Performance Tests**: Response times and resource usage

### Build Stage
- **Docker Images**: Multi-stage builds for optimization
- **Registry Push**: Automated image publishing
- **Vulnerability Scanning**: Container security analysis
- **Artifact Generation**: Configuration packages

### Deployment Stage
- **Staging Deployment**: Automated on main branch
- **Production Deployment**: Manual approval required
- **Health Checks**: Post-deployment validation
- **Rollback**: Automatic on failure

## 🔄 Deployment Environments

### Staging Environment
- **Purpose**: Pre-production testing
- **Trigger**: Automatic on main branch push
- **Features**: Full monitoring stack with test data
- **Access**: Development team

### Production Environment
- **Purpose**: Live monitoring infrastructure
- **Trigger**: Manual approval required
- **Features**: Full monitoring with real data
- **Access**: Operations team only

## 📈 Monitoring the Pipeline

### Pipeline Health
- GitHub Actions dashboard shows workflow status
- Automated notifications on failures
- Health check workflows run regularly
- Performance metrics tracked

### Key Metrics
- **Build Success Rate**: Target 95%+
- **Deployment Frequency**: Multiple per week
- **Mean Time to Recovery**: <30 minutes
- **Pipeline Duration**: <15 minutes

## 🚨 Incident Response

### Pipeline Failures
1. **Check GitHub Actions logs**
2. **Review configuration changes**
3. **Run local validation**
4. **Apply fixes and rerun**

### Deployment Issues
1. **Automatic rollback triggered**
2. **Incident notifications sent**
3. **Health checks validate rollback**
4. **Post-incident review scheduled**

### Emergency Procedures
```bash
# Emergency rollback
make deploy-production FORCE_ROLLBACK=true

# Emergency stop
make stop

# Emergency health check
make health
```

## 🔧 Customization

### Adding New Services
1. Update `docker-compose.yml`
2. Add configuration files
3. Update validation workflows
4. Add health checks
5. Update documentation

### Modifying Workflows
1. Edit workflow files in `.github/workflows/`
2. Test changes on feature branch
3. Review with team
4. Merge to main

### Environment Variables
Configure in `.env`:
```bash
# Monitoring Configuration
GRAFANA_CLOUD_API_KEY=your_key_here
PROMETHEUS_RETENTION=30d
LOKI_RETENTION=30d

# Network Configuration
MARKETSAGE_NETWORK=marketsage_marketsage
MARKETSAGE_APP_URL=marketsage-web:3000
```

## 📚 Best Practices

### Security
- ✅ Never commit secrets to repository
- ✅ Use GitHub secrets for sensitive data
- ✅ Regular security scanning
- ✅ Principle of least privilege

### Configuration Management
- ✅ Validate all changes
- ✅ Use version control for all configs
- ✅ Document breaking changes
- ✅ Test before production

### Monitoring
- ✅ Monitor the monitoring pipeline
- ✅ Set up alerting for failures
- ✅ Regular health checks
- ✅ Performance benchmarking

## 🆘 Troubleshooting

### Common Issues

**Q: Pipeline fails on configuration validation**
A: Check syntax of YAML/JSON files, validate locally first

**Q: Docker build fails**
A: Check Dockerfile syntax, ensure base images are available

**Q: Health checks fail after deployment**
A: Verify service dependencies, check network connectivity

**Q: Secrets not loading**
A: Verify GitHub secrets are configured, check environment variable names

### Getting Help
1. Check GitHub Actions logs
2. Review this documentation
3. Run local diagnostics: `make health`
4. Contact DevOps team

## 📞 Support

- **Documentation**: This file and inline comments
- **Issues**: GitHub Issues tracker
- **Team**: @devops-team @monitoring-team
- **Emergency**: Slack #monitoring-alerts

---

🤖 **Generated with Claude Code**

Co-Authored-By: Claude <noreply@anthropic.com>