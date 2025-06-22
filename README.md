# MarketSage Monitoring

Comprehensive monitoring infrastructure for MarketSage application with Grafana, Prometheus, Loki, and Alloy.

## Features

- **Grafana Dashboard**: Local visualization and monitoring dashboards
- **Prometheus**: Metrics collection and storage with alerting rules
- **Loki**: Log aggregation and analysis
- **Alloy**: Unified metrics and log collection agent
- **Alertmanager**: Alert routing and notifications (email/Slack)
- **Dual Storage**: Local storage + Grafana Cloud backup
- **Security**: Docker secrets for credential management

## Quick Setup

1. **Copy configuration files:**
   ```bash
   cp .env.example .env
   cp -r secrets.example secrets
   ```

2. **Configure credentials:**
   - Edit `.env` with your Grafana Cloud credentials
   - Edit files in `secrets/` directory with actual passwords/tokens

3. **Make sure MarketSage is running first**

4. **Start monitoring stack:**
   ```bash
   docker-compose up -d
   ```

## Access Points

- **Local Grafana**: http://localhost:3000 (admin/[password from secrets])
- **Prometheus**: http://localhost:9090 (admin/monitoring123)
- **Loki**: http://localhost:3100
- **Alloy**: http://localhost:12345
- **Alertmanager**: http://localhost:9093
- **Grafana Cloud**: https://marketsageafrica.grafana.net

## Services

| Service | Purpose | Port |
|---------|---------|------|
| Grafana | Dashboards & Visualization | 3000 |
| Prometheus | Metrics Storage | 9090 |
| Loki | Log Aggregation | 3100 |
| Alloy | Data Collection Agent | 12345 |
| Alertmanager | Alert Management | 9093 |
| cAdvisor | Container Metrics | 8080 |
| Node Exporter | System Metrics | 9100 |
| PostgreSQL Exporter | Database Metrics | 9187 |
| Redis Exporter | Cache Metrics | 9121 |

## Monitoring Capabilities

- **Application Metrics**: MarketSage application performance
- **Infrastructure Metrics**: CPU, memory, disk, network
- **Container Metrics**: Docker container performance
- **Database Metrics**: PostgreSQL performance and health
- **Cache Metrics**: Redis performance and health
- **Log Collection**: Application and system logs
- **Alerting**: Comprehensive alerting rules for all components
