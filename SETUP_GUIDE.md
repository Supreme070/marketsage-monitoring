# 🚀 MarketSage Grafana Alloy Monitoring Setup Guide

## 📋 Overview

This guide will help you set up comprehensive observability for your MarketSage application using **Grafana Alloy** - a unified observability agent that combines metrics, logs, and traces collection.

## 🎯 What You'll Get

- **📊 Metrics**: Application performance, database, Redis, AI/ML models
- **📝 Logs**: Centralized log collection and analysis
- **🔍 Traces**: Distributed tracing for request flows
- **🚨 Alerts**: Proactive monitoring and alerting
- **📈 Dashboards**: Pre-built Grafana dashboards

## 🛠️ Prerequisites

1. **Grafana Cloud Account** (Free tier available)
   - Sign up at: https://grafana.com/auth/sign-up/create-user
   - Create a new stack: https://grafana.com/orgs/YOUR_ORG/stacks

2. **MarketSage Application Running**
   ```bash
   cd /path/to/marketsage
   docker-compose -f docker-compose.prod.yml up -d
   ```

3. **Docker & Docker Compose**

## 🔧 Step-by-Step Setup

### Step 1: Get Grafana Cloud Credentials

1. Go to your Grafana Cloud stack
2. Navigate to **"Connections" > "Add new connection"**
3. Select **"Hosted Prometheus metrics"** and note:
   - **URL**: `https://prometheus-blocks-prod-us-central1.grafana.net/api/prom/push`
   - **User ID**: Your numeric user ID
   - **API Key**: Generate a new API token

4. For **Loki (Logs)**:
   - URL: `https://logs-prod-us-central1.grafana.net/loki/api/v1/push`
   - User ID: Your numeric user ID (same as above)

5. For **Tempo (Traces)**:
   - Endpoint: `https://tempo-prod-us-central1.grafana.net:443`
   - User ID: Your numeric user ID (same as above)

### Step 2: Configure Environment Variables

1. **Copy environment template:**
   ```bash
   cd marketsage-monitoring
   cp .env.example .env
   ```

2. **Edit `.env` file with your credentials:**
   ```bash
   # Grafana Cloud Configuration
   GRAFANA_CLOUD_API_KEY=your_api_key_here
   GRAFANA_CLOUD_PROMETHEUS_URL=https://prometheus-blocks-prod-us-central1.grafana.net/api/prom/push
   GRAFANA_CLOUD_PROMETHEUS_USER=123456
   GRAFANA_CLOUD_LOKI_URL=https://logs-prod-us-central1.grafana.net/loki/api/v1/push
   GRAFANA_CLOUD_LOKI_USER=123456
   GRAFANA_CLOUD_TEMPO_ENDPOINT=https://tempo-prod-us-central1.grafana.net:443
   GRAFANA_CLOUD_TEMPO_USER=123456
   ```

### Step 3: Start Monitoring Stack

1. **Ensure MarketSage is running first:**
   ```bash
   cd ../marketsage
   docker-compose -f docker-compose.prod.yml ps
   ```

2. **Start Alloy monitoring:**
   ```bash
   cd ../marketsage-monitoring
   docker-compose up -d
   ```

3. **Verify services are running:**
   ```bash
   docker-compose ps
   ```

### Step 4: Access Monitoring Interfaces

- **🎯 Alloy UI**: http://localhost:12345
- **📊 cAdvisor**: http://localhost:8080
- **🗄️ Postgres Exporter**: http://localhost:9187/metrics
- **🔴 Redis Exporter**: http://localhost:9121/metrics
- **🌐 Grafana Cloud**: https://marketsageafrica.grafana.net

### Step 5: Import Pre-built Dashboards

1. Go to your Grafana Cloud instance
2. Navigate to **"Dashboards" > "New" > "Import"**
3. Use these dashboard IDs:

   ```
   📱 Application Monitoring: 1860
   🗄️  PostgreSQL: 9628
   🔴 Redis: 763
   📦 Docker Containers: 193
   🔧 Node Exporter: 1860
   ```

## 🎯 Monitoring Endpoints

Your MarketSage application now exposes these monitoring endpoints:

### Health Check (Enhanced)
```bash
# JSON format
curl http://localhost:3030/api/health

# Prometheus metrics format
curl http://localhost:3030/api/health?format=prometheus
```

### Performance Metrics
```bash
curl http://localhost:3030/api/monitoring/performance
```

### AI/ML Monitoring
```bash
curl http://localhost:3030/api/ai/enhance
```

## 🚨 Alerting Setup

### Slack Integration (Recommended)

1. **Create Slack App:**
   - Go to https://api.slack.com/apps
   - Create new app > "From scratch"
   - Add "Incoming Webhooks" feature
   - Get webhook URL

2. **Configure in Grafana:**
   - Go to **"Alerting" > "Contact points"**
   - Add new contact point
   - Type: Slack
   - Webhook URL: Your Slack webhook

3. **Set up notification policies:**
   - **Critical**: Immediate Slack notification
   - **Warning**: Slack notification (grouped)
   - **Info**: Email notification

### Email Alerts

1. **Configure SMTP in Grafana:**
   ```
   Settings > Alerting > Contact points > Email
   SMTP Host: smtp.gmail.com:587
   Username: your-email@gmail.com
   Password: your-app-password
   ```

## 📊 Key Metrics to Monitor

### Application Health
- **Response Time**: `marketsage_response_time_milliseconds`
- **Request Rate**: `marketsage_requests_total`
- **Error Rate**: `marketsage_errors_total`
- **Uptime**: `marketsage_uptime_seconds`

### AI/ML Performance
- **Model Accuracy**: `ai_model_accuracy`
- **Prediction Latency**: `ai_prediction_latency_seconds`
- **Model Drift**: `ai_model_drift_score`

### Infrastructure
- **Database Connections**: `pg_stat_database_numbackends`
- **Redis Memory**: `redis_memory_used_bytes`
- **Container CPU**: `container_cpu_usage_seconds_total`
- **Container Memory**: `container_memory_usage_bytes`

## 🔍 Troubleshooting

### Common Issues

1. **Alloy not collecting metrics:**
   ```bash
   # Check Alloy logs
   docker logs marketsage-alloy
   
   # Check Alloy configuration
   docker exec marketsage-alloy alloy fmt /etc/alloy/config.alloy
   ```

2. **Database exporter failing:**
   ```bash
   # Check database connectivity
   docker exec marketsage-postgres-exporter pg_isready -h marketsage-db
   ```

3. **Metrics not appearing in Grafana:**
   - Verify credentials in `.env`
   - Check network connectivity
   - Ensure time sync is correct

### Health Check Commands

```bash
# Test health endpoint
curl -s http://localhost:3030/api/health | jq .

# Check Alloy status
curl -s http://localhost:12345/-/healthy

# Verify metrics collection
curl -s http://localhost:12345/api/v1/metrics/targets
```

## 🎯 Performance Optimization

### For High-Traffic Applications

1. **Increase scrape intervals:**
   ```alloy
   scrape_interval = "60s"  # Instead of 15s
   ```

2. **Add metric filtering:**
   ```alloy
   metric_relabel_configs = [
     {
       source_labels = ["__name__"]
       regex = "go_.*|process_.*"
       action = "drop"
     }
   ]
   ```

3. **Configure remote write batching:**
   ```alloy
   queue_config {
     capacity = 10000
     max_shards = 50
     batch_send_deadline = "10s"
   }
   ```

## 🔄 Maintenance

### Weekly Tasks
- Review alert noise and tune thresholds
- Check storage usage in Grafana Cloud
- Update dashboard configurations

### Monthly Tasks
- Review and optimize expensive queries
- Archive old metrics data
- Update Alloy and exporter versions

## 📚 Resources

### Documentation
- [Grafana Alloy Docs](https://grafana.com/docs/alloy/latest/)
- [Prometheus Query Guide](https://prometheus.io/docs/prometheus/latest/querying/basics/)
- [Grafana Dashboard Guide](https://grafana.com/docs/grafana/latest/dashboards/)

### Community
- [Grafana Community Slack](https://grafana.slack.com)
- [r/grafana](https://reddit.com/r/grafana)
- [Grafana Community Forum](https://community.grafana.com/)

## 🎉 Success Criteria

You'll know everything is working when:

✅ **Alloy UI shows green status**: http://localhost:12345  
✅ **Metrics appearing in Grafana Cloud**  
✅ **Alerts configured and testing**  
✅ **Dashboards showing real data**  
✅ **Health checks passing**  

## 🚀 Advanced Features

Once basic monitoring is working, consider:

1. **Custom Business Metrics**
2. **SLO/SLI Monitoring**
3. **User Journey Tracking**
4. **Cost Monitoring**
5. **Security Monitoring**

---

**🎯 Need Help?**
- Check logs: `docker logs marketsage-alloy`
- Test configuration: `alloy fmt /path/to/config.alloy`
- Grafana Support: https://grafana.com/support/ 