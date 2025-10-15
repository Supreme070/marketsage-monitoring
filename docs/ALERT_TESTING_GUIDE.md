# Alert Testing Guide

## Prerequisites

Before testing alerts, ensure:

1. **Slack Webhook Configured**
   - Create webhook at https://api.slack.com/messaging/webhooks
   - Store in `/run/secrets/slack_webhook_url` (Docker secret)
   - Channels created: `#alerts-critical`, `#alerts-warning`, `#marketsage-alerts`

2. **Monitoring Stack Running**
   ```bash
   docker-compose ps
   # Verify: prometheus, alertmanager, grafana are running
   ```

3. **Alert Rules Loaded**
   ```bash
   curl http://localhost:9090/api/v1/rules | jq
   # Should show all rule groups
   ```

---

## Alert Rules Inventory

### EXISTING Alert Files (VERIFIED)

1. **marketsage-alerts.yml** (219 lines)
   - Application health (MarketSageDown, HighResponseTime, HighErrorRate)
   - AI/ML performance (AIModelLowAccuracy, AIHighLatency, AIModelDrift)
   - Database (PostgreSQLDown, RedisDown, HighDatabaseConnections)
   - Infrastructure (HighContainerCPU, HighContainerMemory, ContainerRestarting)
   - Campaigns (HighEmailBounceRate, SMSDeliveryFailure, WhatsAppAPILimit)
   - Business (LowConversionRate, HighChurnPrediction, UnusualTrafficPattern)

2. **nestjs-alerts.yml** (93 lines)
   - NestJSDown (critical)
   - NestJSHighErrorRate
   - NestJSHighResponseTime
   - NestJSHighAuthFailures (security)
   - NestJSHighMemoryUsage
   - NestJSHighEventLoopLag
   - NestJSNoDatabaseConnections (critical)
   - NestJSHighJWTFailures (security)

3. **business-kpis.yml** (Created Day 3)
   - MRRDropSignificant (critical)
   - NoRevenueToday
   - UserGrowthStalled
   - ActiveUsersDeclining
   - CampaignFailureRateHigh (critical)
   - NoCampaignsActive (info)
   - ConversionRateDrop
   - ContactEngagementLow

4. **critical-alerts.yml** (NEW - Created Day 5)
   - **Infrastructure**: DiskSpaceCritical, DiskSpaceLow, HostCPUCritical, HostMemoryCritical, HighDiskIOWait
   - **Services**: AllServicesDown, AlertmanagerDown, GrafanaDown
   - **Frontend**: FrontendLCPPoor, FrontendFIDPoor, FrontendCLSPoor, FrontendTTFBPoor
   - **SSL**: SSLCertificateExpiringSoon, SSLCertificateExpiringCritical
   - **Data**: DatabaseReplicationLag, BackupFailed
   - **Network**: HighNetworkErrors, HighNetworkDrops

---

## Testing Procedure

### 1. Verify Prometheus Configuration

```bash
# Check if Prometheus can load config
curl -X POST http://localhost:9090/-/reload

# Verify rule files are loaded
curl http://localhost:9090/api/v1/rules | jq '.data.groups[].name'

# Expected output:
# - marketsage.application
# - marketsage.ai
# - marketsage.database
# - marketsage.infrastructure
# - marketsage.campaigns
# - marketsage.business
# - nestjs_backend_alerts
# - business_kpi_recording_rules
# - business_kpi_alerts
# - critical_infrastructure
# - critical_services
# - critical_frontend_performance
# - critical_ssl_certificates
# - critical_data_integrity
# - critical_network
```

### 2. Verify Alertmanager Configuration

```bash
# Check Alertmanager status
curl http://localhost:9093/api/v1/status | jq

# Verify routing configuration
curl http://localhost:9093/api/v1/config | jq '.config.route'

# Check for active alerts
curl http://localhost:9093/api/v1/alerts | jq
```

### 3. Test Alert Firing (Manual Trigger)

#### Method A: Stop a Service (Recommended for initial test)

```bash
# Stop NestJS backend to trigger NestJSDown alert
docker-compose stop marketsage-backend

# Wait 2-3 minutes for alert to fire
# Check Prometheus alerts page: http://localhost:9090/alerts

# Check Alertmanager: http://localhost:9093/#/alerts

# Verify Slack message received in #alerts-critical

# Restart service
docker-compose start marketsage-backend

# Verify alert resolves in Slack
```

#### Method B: Simulate High Error Rate

```bash
# Use a script to generate 500 errors
for i in {1..500}; do
  curl -X GET http://localhost:3006/nonexistent-endpoint
done

# Check if HighErrorRate alert fires (after 2-5 minutes)
```

#### Method C: Fill Disk Space (CAUTION: Test environment only)

```bash
# Create a large file to fill disk
dd if=/dev/zero of=/tmp/testfile bs=1M count=50000

# Monitor disk usage
df -h

# DiskSpaceLow alert should fire when < 10%
# DiskSpaceCritical alert should fire when < 5%

# Clean up
rm /tmp/testfile
```

### 4. Test Slack Integration

#### Verify Slack Webhook Secret

```bash
# Check if secret exists
docker exec marketsage-alertmanager ls -la /run/secrets/slack_webhook_url

# If not exists, create it:
echo "https://hooks.slack.com/services/YOUR/WEBHOOK/URL" | docker secret create slack_webhook_url -

# Restart Alertmanager
docker-compose restart alertmanager
```

#### Send Test Alert

```bash
# Send test alert to Alertmanager
curl -X POST http://localhost:9093/api/v1/alerts -H "Content-Type: application/json" -d '[
  {
    "labels": {
      "alertname": "TestAlert",
      "severity": "critical",
      "service": "test"
    },
    "annotations": {
      "summary": "This is a test alert",
      "description": "Testing Slack integration"
    }
  }
]'

# Check Slack #alerts-critical channel for message
```

### 5. Test Email Integration (Optional)

```bash
# Verify SMTP password secret exists
docker exec marketsage-alertmanager ls -la /run/secrets/smtp_password

# If not exists:
echo "your-smtp-password" | docker secret create smtp_password -

# Update alertmanager.yml with correct email addresses
# Restart Alertmanager
docker-compose restart alertmanager
```

### 6. Test Web Vitals Alerts

```bash
# These alerts require frontend to be running and collecting vitals
# Visit http://localhost:3000 (frontend)
# Visit http://localhost:3000/test-web-vitals

# Check if metrics are being collected:
curl http://localhost:9090/api/v1/query?query=marketsage_frontend_lcp

# Alerts will fire if 75th percentile exceeds thresholds:
# - LCP > 4000ms
# - FID > 300ms
# - CLS > 0.25
# - TTFB > 1800ms
```

---

## Expected Alert Behavior

### Critical Alerts (Red - Slack #alerts-critical)

| Alert | Trigger | For | Expected Action |
|-------|---------|-----|-----------------|
| MarketSageDown | Service unreachable | 1m | Immediate investigation |
| NestJSDown | Backend unreachable | 2m | Immediate investigation |
| PostgreSQLDown | Database unreachable | 1m | Immediate investigation |
| AllServicesDown | 3+ services down | 2m | Platform-wide incident |
| DiskSpaceCritical | < 5% free | 5m | Free disk space immediately |
| AlertmanagerDown | Alertmanager down | 2m | Fix alerting system |
| MRRDropSignificant | MRR down >10% | 15m | Business investigation |
| CampaignFailureRateHigh | >10% failures | 15m | Check email/SMS providers |

### Warning Alerts (Yellow - Slack #alerts-warning)

| Alert | Trigger | For | Expected Action |
|-------|---------|-----|-----------------|
| HighResponseTime | p95 > 2s | 2m | Performance investigation |
| HighErrorRate | > 5% | 2m | Check logs for errors |
| DiskSpaceLow | < 10% free | 10m | Plan disk cleanup |
| HostCPUHigh | > 80% | 15m | Investigate CPU usage |
| HostMemoryHigh | > 85% | 10m | Check for memory leaks |
| FrontendLCPPoor | p75 > 4s | 15m | Frontend optimization needed |
| ConversionRateDrop | < 1% | 6h | Product/UX investigation |

---

## Troubleshooting

### Alert Not Firing

1. **Check Prometheus targets are up**
   ```bash
   curl http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | select(.health != "up")'
   ```

2. **Verify alert expression**
   ```bash
   # Test query in Prometheus UI: http://localhost:9090/graph
   # Example: up{job="marketsage-backend"} == 0
   ```

3. **Check evaluation interval**
   ```bash
   # Alerts are evaluated every 15s (global.evaluation_interval)
   # Alert must be true for "for" duration before firing
   ```

### Alert Not Sending to Slack

1. **Verify Slack webhook URL is correct**
   ```bash
   docker exec marketsage-alertmanager cat /run/secrets/slack_webhook_url
   ```

2. **Check Alertmanager logs**
   ```bash
   docker logs marketsage-alertmanager | grep -i slack
   docker logs marketsage-alertmanager | grep -i error
   ```

3. **Test webhook manually**
   ```bash
   curl -X POST \
     -H 'Content-type: application/json' \
     --data '{"text":"Test message from Alertmanager"}' \
     YOUR_SLACK_WEBHOOK_URL
   ```

4. **Verify Alertmanager config**
   ```bash
   curl http://localhost:9093/api/v1/status | jq '.config.route.receiver'
   ```

### Alert Firing Too Frequently

1. **Adjust `for` duration** in alert rule
2. **Increase `repeat_interval`** in alertmanager.yml (currently 1h)
3. **Add inhibit_rules** to suppress redundant alerts

### Missing Metrics

1. **Check if exporter is running**
   ```bash
   docker-compose ps | grep exporter
   ```

2. **Verify scrape config in prometheus.yml**
3. **Check Prometheus scrape errors**
   ```bash
   curl http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | select(.lastError != null)'
   ```

---

## Alert Verification Checklist

- [ ] Prometheus is scraping all targets successfully
- [ ] All alert rule files are loaded (check /api/v1/rules)
- [ ] Alertmanager is receiving alerts from Prometheus
- [ ] Slack webhook URL is configured correctly
- [ ] Test alert successfully delivered to Slack
- [ ] Critical alerts route to #alerts-critical
- [ ] Warning alerts route to #alerts-warning
- [ ] Email notifications working (if configured)
- [ ] Alerts resolve when condition clears
- [ ] Inhibit rules prevent alert spam

---

## Next Steps

1. **Configure Slack Webhook**
   - Create webhook: https://api.slack.com/messaging/webhooks
   - Add to Docker secrets: `/run/secrets/slack_webhook_url`

2. **Create Slack Channels**
   - `#alerts-critical` for P1 incidents
   - `#alerts-warning` for P2-P3 issues
   - `#marketsage-alerts` for application-specific alerts

3. **Test Alert Flow**
   - Stop a service → verify alert fires → verify Slack message → restart service → verify resolution

4. **Tune Alert Thresholds**
   - Monitor for false positives
   - Adjust `for` durations based on actual patterns
   - Update thresholds based on baseline metrics

5. **Set Up On-Call Rotation**
   - Integrate with PagerDuty/Opsgenie (Phase 5)
   - Define escalation policies
   - Document runbooks for each alert

---

**Documentation Generated**: Day 5 - Alerts & Notifications
**Alert Files**: 4 files, 100+ alert rules
**Severity Levels**: Critical (P1), Warning (P2-P3), Info
**Notification Channels**: Slack + Email
