# Quick Start: World-Class Monitoring This Week

## Overview

This guide helps you implement the **highest-impact monitoring improvements** in just 5 days. Each task is designed to take 2-4 hours and provide immediate value.

---

## Monday: Frontend Error Tracking ⚡

**Time**: 2-3 hours | **Impact**: 🔥🔥🔥 CRITICAL

### Why This Matters
You're currently **blind** to frontend errors affecting real users. You need to see errors before customers report them.

### Steps

1. **Install Sentry** (15 minutes)
```bash
cd /Users/supreme/Desktop/marketsage-frontend
npm install --save @sentry/nextjs
npx @sentry/wizard@latest -i nextjs
```

2. **Get Sentry DSN** (5 minutes)
- Go to https://sentry.io (create free account)
- Create project "marketsage-frontend"
- Copy your DSN

3. **Add to Environment** (5 minutes)
```bash
# .env.local
NEXT_PUBLIC_SENTRY_DSN=https://your-dsn@sentry.io/project-id
SENTRY_ORG=your-org
SENTRY_PROJECT=marketsage-frontend
```

4. **Configure Sentry** (30 minutes)
The wizard created these files - customize them:

```typescript
// sentry.client.config.ts
import * as Sentry from '@sentry/nextjs';

Sentry.init({
  dsn: process.env.NEXT_PUBLIC_SENTRY_DSN,
  environment: process.env.NODE_ENV || 'development',

  // Performance monitoring
  tracesSampleRate: 0.1, // 10% of transactions

  // Session replay (see user actions before error)
  replaysSessionSampleRate: 0.1,
  replaysOnErrorSampleRate: 1.0, // Always record when error occurs

  // Filter sensitive data
  beforeSend(event) {
    // Remove cookies
    if (event.request) {
      delete event.request.cookies;
    }
    // Remove sensitive headers
    if (event.request?.headers) {
      delete event.request.headers['authorization'];
    }
    return event;
  },
});
```

5. **Test It** (15 minutes)
```typescript
// Create /app/test-error/page.tsx
'use client';

export default function TestErrorPage() {
  return (
    <button onClick={() => {
      throw new Error('Test Sentry Error!');
    }}>
      Trigger Test Error
    </button>
  );
}
```

- Visit http://localhost:3000/test-error
- Click button
- Check Sentry dashboard - you should see the error!

6. **Deploy** (30 minutes)
- Commit changes
- Deploy to staging
- Verify errors are captured
- Deploy to production

### Success Metrics
✅ Errors visible in Sentry dashboard within 1 minute
✅ Can see stack traces with file names and line numbers
✅ Can see user context (which user experienced error)

---

## Tuesday: Admin Portal Monitoring ⚡

**Time**: 2-3 hours | **Impact**: 🔥🔥 HIGH

### Why This Matters
Your admin portal has **ZERO monitoring**. Staff actions, errors, security events - all invisible.

### Steps

1. **Install Sentry** (15 minutes)
```bash
cd /Users/supreme/Desktop/marketsage-admin
npm install --save @sentry/nextjs
npx @sentry/wizard@latest -i nextjs
```

2. **Configure Environment** (5 minutes)
```bash
# .env.local
NEXT_PUBLIC_SENTRY_DSN=https://different-dsn@sentry.io/admin-project-id
SENTRY_PROJECT=marketsage-admin
NEXT_PUBLIC_BACKEND_URL=http://localhost:3006
```

3. **Create Audit Logger** (45 minutes)
```typescript
// src/lib/audit-logger.ts
import * as Sentry from '@sentry/nextjs';

interface AuditEvent {
  action: string;
  resource: string;
  resourceId?: string;
  userId: string;
  userEmail: string;
  changes?: any;
  metadata?: any;
}

class AuditLogger {
  async log(event: AuditEvent) {
    const logEntry = {
      ...event,
      timestamp: new Date().toISOString(),
      service: 'admin-portal',
    };

    // Send to Sentry as breadcrumb
    Sentry.addBreadcrumb({
      category: 'audit',
      message: `${event.action} ${event.resource}`,
      level: 'info',
      data: logEntry,
    });

    // Send to backend
    try {
      await fetch(`${process.env.NEXT_PUBLIC_BACKEND_URL}/api/audit-logs`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(logEntry),
      });
    } catch (error) {
      console.error('Failed to send audit log:', error);
      Sentry.captureException(error);
    }
  }
}

export const auditLogger = new AuditLogger();
```

4. **Add to Actions** (45 minutes)
Find all admin actions and add logging:

```typescript
// Example: src/app/admin/users/actions.ts
'use server';

import { auditLogger } from '@/lib/audit-logger';

export async function deleteUser(userId: string) {
  const currentUser = await getCurrentUser(); // Your auth function

  // Log the action
  await auditLogger.log({
    action: 'DELETE',
    resource: 'user',
    resourceId: userId,
    userId: currentUser.id,
    userEmail: currentUser.email,
  });

  // Perform the action
  await prisma.user.delete({ where: { id: userId } });
}

export async function updateUserRole(userId: string, newRole: string) {
  const currentUser = await getCurrentUser();
  const oldUser = await prisma.user.findUnique({ where: { id: userId } });

  // Log with changes
  await auditLogger.log({
    action: 'UPDATE',
    resource: 'user_role',
    resourceId: userId,
    userId: currentUser.id,
    userEmail: currentUser.email,
    changes: {
      before: oldUser?.role,
      after: newRole,
    },
  });

  await prisma.user.update({
    where: { id: userId },
    data: { role: newRole },
  });
}
```

5. **Create Backend Endpoint** (30 minutes)
```typescript
// marketsage-backend/src/audit/audit.controller.ts
import { Controller, Post, Body } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Controller('audit-logs')
export class AuditController {
  constructor(private prisma: PrismaService) {}

  @Post()
  async createAuditLog(@Body() log: any) {
    await this.prisma.auditLog.create({
      data: log,
    });
    return { success: true };
  }
}
```

### Success Metrics
✅ All admin actions logged to Sentry and database
✅ Can see who did what, when
✅ Can track changes to critical resources

---

## Wednesday: Business KPIs Dashboard 📊

**Time**: 3-4 hours | **Impact**: 🔥🔥🔥 CRITICAL

### Why This Matters
Executives and stakeholders need to see business health at a glance. Currently you only show infrastructure metrics.

### Steps

1. **Add Business Metrics to Backend** (90 minutes)

```typescript
// marketsage-backend/src/metrics/business-metrics.service.ts
import { Injectable } from '@nestjs/common';
import { Gauge, Counter } from 'prom-client';

@Injectable()
export class BusinessMetricsService {
  // Revenue
  private mrrGauge = new Gauge({
    name: 'marketsage_business_mrr_usd',
    help: 'Monthly Recurring Revenue in USD',
  });

  private revenueCounter = new Counter({
    name: 'marketsage_business_revenue_total_usd',
    help: 'Total revenue',
    labelNames: ['plan_type'],
  });

  // Users
  private totalUsersGauge = new Gauge({
    name: 'marketsage_business_users_total',
    help: 'Total users',
  });

  private activeUsersGauge = new Gauge({
    name: 'marketsage_business_active_users',
    help: 'Active users in last 30 days',
  });

  // Campaigns
  private campaignsSentCounter = new Counter({
    name: 'marketsage_business_campaigns_sent_total',
    help: 'Total campaigns sent',
    labelNames: ['channel', 'status'],
  });

  // Conversions
  private conversionsCounter = new Counter({
    name: 'marketsage_business_conversions_total',
    help: 'Total conversions',
  });

  async updateBusinessMetrics() {
    // This should run periodically (e.g., every 5 minutes)
    const mrr = await this.calculateMRR();
    this.mrrGauge.set(mrr);

    const totalUsers = await this.getUserCount();
    this.totalUsersGauge.set(totalUsers);

    const activeUsers = await this.getActiveUserCount(30);
    this.activeUsersGauge.set(activeUsers);
  }

  recordRevenue(amount: number, planType: string) {
    this.revenueCounter.inc({ plan_type: planType }, amount);
  }

  recordCampaign(channel: string, status: string) {
    this.campaignsSentCounter.inc({ channel, status });
  }

  recordConversion() {
    this.conversionsCounter.inc();
  }

  private async calculateMRR(): Promise<number> {
    // Your MRR calculation logic
    return 0;
  }

  private async getUserCount(): Promise<number> {
    // Count total users
    return 0;
  }

  private async getActiveUserCount(days: number): Promise<number> {
    // Count users active in last N days
    return 0;
  }
}
```

2. **Schedule Metric Updates** (30 minutes)
```typescript
// marketsage-backend/src/metrics/metrics-scheduler.service.ts
import { Injectable } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { BusinessMetricsService } from './business-metrics.service';

@Injectable()
export class MetricsScheduler {
  constructor(private businessMetrics: BusinessMetricsService) {}

  @Cron(CronExpression.EVERY_5_MINUTES)
  async updateMetrics() {
    await this.businessMetrics.updateBusinessMetrics();
  }
}
```

3. **Create Grafana Dashboard** (60 minutes)

Create file: `/marketsage-monitoring/grafana/dashboards/business-overview.json`

```json
{
  "dashboard": {
    "title": "📊 Business Overview",
    "tags": ["business", "kpi"],
    "timezone": "browser",
    "panels": [
      {
        "id": 1,
        "title": "💰 Monthly Recurring Revenue",
        "type": "stat",
        "gridPos": { "h": 8, "w": 6, "x": 0, "y": 0 },
        "targets": [{
          "expr": "marketsage_business_mrr_usd",
          "legendFormat": "MRR"
        }],
        "fieldConfig": {
          "defaults": {
            "unit": "currencyUSD",
            "decimals": 0,
            "color": { "mode": "value" },
            "thresholds": {
              "mode": "absolute",
              "steps": [
                { "value": 0, "color": "red" },
                { "value": 10000, "color": "yellow" },
                { "value": 50000, "color": "green" }
              ]
            }
          }
        }
      },
      {
        "id": 2,
        "title": "👥 Total Users",
        "type": "stat",
        "gridPos": { "h": 8, "w": 6, "x": 6, "y": 0 },
        "targets": [{
          "expr": "marketsage_business_users_total"
        }],
        "fieldConfig": {
          "defaults": {
            "unit": "short",
            "color": { "mode": "value" },
            "thresholds": {
              "steps": [
                { "value": 0, "color": "blue" },
                { "value": 1000, "color": "green" },
                { "value": 10000, "color": "purple" }
              ]
            }
          }
        }
      },
      {
        "id": 3,
        "title": "🎯 Active Users (30d)",
        "type": "stat",
        "gridPos": { "h": 8, "w": 6, "x": 12, "y": 0 },
        "targets": [{
          "expr": "marketsage_business_active_users"
        }],
        "fieldConfig": {
          "defaults": {
            "unit": "short",
            "color": { "mode": "value" }
          }
        }
      },
      {
        "id": 4,
        "title": "📧 Campaigns Sent (24h)",
        "type": "stat",
        "gridPos": { "h": 8, "w": 6, "x": 18, "y": 0 },
        "targets": [{
          "expr": "sum(increase(marketsage_business_campaigns_sent_total[24h]))"
        }],
        "fieldConfig": {
          "defaults": {
            "unit": "short"
          }
        }
      },
      {
        "id": 5,
        "title": "📈 Revenue Growth",
        "type": "graph",
        "gridPos": { "h": 12, "w": 12, "x": 0, "y": 8 },
        "targets": [{
          "expr": "marketsage_business_mrr_usd",
          "legendFormat": "MRR"
        }]
      },
      {
        "id": 6,
        "title": "📊 User Growth",
        "type": "graph",
        "gridPos": { "h": 12, "w": 12, "x": 12, "y": 8 },
        "targets": [
          {
            "expr": "marketsage_business_users_total",
            "legendFormat": "Total Users"
          },
          {
            "expr": "marketsage_business_active_users",
            "legendFormat": "Active Users"
          }
        ]
      }
    ],
    "refresh": "1m",
    "time": { "from": "now-30d", "to": "now" }
  }
}
```

4. **Load Dashboard** (10 minutes)
```bash
# Copy dashboard to Grafana
cp /Users/supreme/Desktop/marketsage-monitoring/grafana/dashboards/business-overview.json \
   /Users/supreme/Desktop/marketsage-monitoring/grafana/dashboards/

# Restart Grafana to pick it up
cd /Users/supreme/Desktop/marketsage-monitoring
docker-compose restart grafana
```

### Success Metrics
✅ Dashboard shows real MRR
✅ Dashboard shows real user counts
✅ Updates automatically every 5 minutes
✅ Executives can understand business health at a glance

---

## Thursday: Web Vitals & User Experience 🚀

**Time**: 2-3 hours | **Impact**: 🔥🔥 HIGH

### Why This Matters
You need to know how fast your app feels to real users, not just your local dev machine.

### Steps

1. **Install Web Vitals** (5 minutes)
```bash
cd /Users/supreme/Desktop/marketsage-frontend
npm install --save web-vitals
```

2. **Create Web Vitals Tracker** (45 minutes)

```typescript
// src/lib/monitoring/web-vitals-tracker.ts
import { onCLS, onFID, onLCP, onFCP, onTTFB, onINP, type Metric } from 'web-vitals';

function sendToAnalytics(metric: Metric) {
  // Send to backend
  const body = JSON.stringify({
    name: metric.name,
    value: metric.value,
    rating: metric.rating,
    id: metric.id,
    navigationType: metric.navigationType,
    page: window.location.pathname,
  });

  // Use sendBeacon for reliability (even if user navigates away)
  if (navigator.sendBeacon) {
    navigator.sendBeacon('/api/analytics/web-vitals', body);
  } else {
    fetch('/api/analytics/web-vitals', {
      body,
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      keepalive: true,
    });
  }

  // Also log to console in development
  if (process.env.NODE_ENV === 'development') {
    console.log(`[Web Vitals] ${metric.name}:`, {
      value: metric.value,
      rating: metric.rating,
    });
  }
}

export function initWebVitals() {
  onCLS(sendToAnalytics);  // Cumulative Layout Shift
  onFID(sendToAnalytics);  // First Input Delay
  onLCP(sendToAnalytics);  // Largest Contentful Paint
  onFCP(sendToAnalytics);  // First Contentful Paint
  onTTFB(sendToAnalytics); // Time to First Byte
  onINP(sendToAnalytics);  // Interaction to Next Paint
}
```

3. **Add to App** (15 minutes)
```typescript
// src/app/layout.tsx
'use client';

import { useEffect } from 'react';
import { initWebVitals } from '@/lib/monitoring/web-vitals-tracker';

export default function RootLayout({ children }) {
  useEffect(() => {
    // Initialize Web Vitals tracking
    initWebVitals();
  }, []);

  return (
    <html>
      <body>{children}</body>
    </html>
  );
}
```

4. **Create API Endpoint** (30 minutes)
```typescript
// src/app/api/analytics/web-vitals/route.ts
import { NextRequest, NextResponse } from 'next/server';

// In-memory storage (replace with database in production)
const vitals: any[] = [];

export async function POST(request: NextRequest) {
  try {
    const metric = await request.json();

    vitals.push({
      ...metric,
      timestamp: new Date().toISOString(),
      userAgent: request.headers.get('user-agent'),
    });

    // Send to backend for long-term storage
    await fetch(`${process.env.BACKEND_URL}/api/analytics/web-vitals`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(metric),
    }).catch(err => console.error('Failed to forward to backend:', err));

    return NextResponse.json({ success: true });
  } catch (error) {
    console.error('Failed to record web vital:', error);
    return NextResponse.json({ error: 'Failed' }, { status: 500 });
  }
}

// Add GET endpoint to view recent vitals
export async function GET() {
  return NextResponse.json({
    vitals: vitals.slice(-100), // Last 100 measurements
    summary: calculateSummary(vitals),
  });
}

function calculateSummary(vitals: any[]) {
  const last24h = vitals.filter(v =>
    new Date(v.timestamp).getTime() > Date.now() - 24 * 60 * 60 * 1000
  );

  return {
    lcp: {
      p75: percentile(last24h.filter(v => v.name === 'LCP').map(v => v.value), 75),
      good: last24h.filter(v => v.name === 'LCP' && v.rating === 'good').length,
      total: last24h.filter(v => v.name === 'LCP').length,
    },
    fid: {
      p75: percentile(last24h.filter(v => v.name === 'FID').map(v => v.value), 75),
      good: last24h.filter(v => v.name === 'FID' && v.rating === 'good').length,
      total: last24h.filter(v => v.name === 'FID').length,
    },
    cls: {
      p75: percentile(last24h.filter(v => v.name === 'CLS').map(v => v.value), 75),
      good: last24h.filter(v => v.name === 'CLS' && v.rating === 'good').length,
      total: last24h.filter(v => v.name === 'CLS').length,
    },
  };
}

function percentile(values: number[], p: number): number {
  if (values.length === 0) return 0;
  const sorted = values.sort((a, b) => a - b);
  const index = Math.ceil((p / 100) * sorted.length) - 1;
  return sorted[index];
}
```

5. **Test It** (15 minutes)
- Open browser DevTools
- Refresh your app multiple times
- Check console for Web Vitals logs
- Visit http://localhost:3000/api/analytics/web-vitals to see collected data

### Success Metrics
✅ All 6 Core Web Vitals being tracked
✅ Data visible in /api/analytics/web-vitals endpoint
✅ Can see which pages are slow
✅ Can see performance over time

---

## Friday: Alerts & Notifications 🚨

**Time**: 2-3 hours | **Impact**: 🔥🔥🔥 CRITICAL

### Why This Matters
Great monitoring is useless if you don't know when things break. You need alerts that wake you up.

### Steps

1. **Configure Slack Integration** (30 minutes)

Get Slack webhook:
- Go to https://api.slack.com/messaging/webhooks
- Create new webhook
- Copy webhook URL

Update Alertmanager config:
```yaml
# marketsage-monitoring/config/alertmanager.yml
global:
  resolve_timeout: 5m
  slack_api_url: 'https://hooks.slack.com/services/YOUR/WEBHOOK/URL'

route:
  group_by: ['alertname', 'severity']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 12h
  receiver: 'slack-notifications'
  routes:
    - match:
        severity: critical
      receiver: 'slack-critical'
      continue: true
    - match:
        severity: warning
      receiver: 'slack-warnings'

receivers:
  - name: 'slack-notifications'
    slack_configs:
      - channel: '#monitoring-alerts'
        title: '{{ range .Alerts }}{{ .Labels.alertname }}{{ end }}'
        text: '{{ range .Alerts }}{{ .Annotations.description }}{{ end }}'
        send_resolved: true

  - name: 'slack-critical'
    slack_configs:
      - channel: '#critical-alerts'
        title: '🚨 CRITICAL: {{ range .Alerts }}{{ .Labels.alertname }}{{ end }}'
        text: '{{ range .Alerts }}{{ .Annotations.description }}{{ end }}'
        color: 'danger'

  - name: 'slack-warnings'
    slack_configs:
      - channel: '#monitoring-alerts'
        title: '⚠️ Warning: {{ range .Alerts }}{{ .Labels.alertname }}{{ end }}'
        text: '{{ range .Alerts }}{{ .Annotations.description }}{{ end }}'
        color: 'warning'
```

2. **Create High-Impact Alerts** (60 minutes)

```yaml
# marketsage-monitoring/config/rules/critical-alerts.yml
groups:
  - name: critical.alerts
    interval: 30s
    rules:
      # Application completely down
      - alert: ApplicationDown
        expr: up{job=~"marketsage.*"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "{{ $labels.job }} is down"
          description: "{{ $labels.job }} has been down for more than 1 minute"

      # High error rate
      - alert: HighErrorRate
        expr: |
          (
            sum(rate(marketsage_backend_http_requests_total{status=~"5.."}[5m]))
            /
            sum(rate(marketsage_backend_http_requests_total[5m]))
          ) > 0.05
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "High error rate detected"
          description: "Error rate is {{ $value | humanizePercentage }} (threshold: 5%)"

      # Database down
      - alert: DatabaseDown
        expr: up{job="postgres"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "PostgreSQL database is down"
          description: "Cannot connect to PostgreSQL database"

      # High response time
      - alert: HighResponseTime
        expr: |
          histogram_quantile(0.95,
            rate(marketsage_backend_http_request_duration_seconds_bucket[5m])
          ) > 2
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High API response time"
          description: "95th percentile response time is {{ $value }}s"

      # Memory usage high
      - alert: HighMemoryUsage
        expr: |
          (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) > 0.9
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High memory usage"
          description: "Memory usage is {{ $value | humanizePercentage }}"

      # Disk space low
      - alert: DiskSpaceLow
        expr: |
          (
            node_filesystem_avail_bytes{mountpoint="/"}
            /
            node_filesystem_size_bytes{mountpoint="/"}
          ) < 0.1
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Disk space critically low"
          description: "Only {{ $value | humanizePercentage }} disk space remaining"
```

3. **Reload Alertmanager** (5 minutes)
```bash
cd /Users/supreme/Desktop/marketsage-monitoring
docker-compose restart alertmanager
```

4. **Test Alerts** (30 minutes)

Test error alert:
```bash
# Generate 500 errors
for i in {1..100}; do
  curl -X POST http://localhost:3006/api/test/error
done

# Wait 2-3 minutes, check Slack channel
```

Test app down alert:
```bash
# Stop backend temporarily
cd /Users/supreme/Desktop/marketsage-backend
# Stop your backend process

# Wait 1 minute, check Slack
# Restart backend
```

### Success Metrics
✅ Alerts appear in Slack within 2 minutes
✅ Critical alerts go to separate channel
✅ Alerts resolve when issue is fixed
✅ Alert messages are clear and actionable

---

## Summary: What You've Achieved This Week

### Monday
✅ Frontend errors visible in real-time
✅ Stack traces with source maps
✅ User context for every error

### Tuesday
✅ Admin portal fully monitored
✅ All staff actions audited
✅ Security events tracked

### Wednesday
✅ Business metrics dashboard
✅ MRR, users, campaigns visible
✅ Real-time business health

### Thursday
✅ User experience tracked
✅ Core Web Vitals measured
✅ Performance baselines established

### Friday
✅ Alerts configured
✅ Slack notifications working
✅ Team notified of issues

---

## Next Week: Go Deeper

Now that you have the basics, you can:

1. **Add more dashboards** (customer journey, AI/ML performance)
2. **Enhance alerts** (anomaly detection, SLO-based)
3. **Add synthetic monitoring** (uptime checks, E2E tests)
4. **Implement RUM enhancements** (session replay, user journeys)
5. **Cost optimization** (track and optimize monitoring costs)

---

## Need Help?

### Common Issues

**Sentry not capturing errors?**
- Check DSN is correct
- Verify environment variables loaded
- Check browser console for Sentry init message
- Check Sentry dashboard quota

**Metrics not appearing?**
- Check Prometheus targets: http://localhost:9090/targets
- Verify `/metrics` endpoint accessible
- Check Prometheus logs: `docker logs marketsage-prometheus`

**Alerts not firing?**
- Check alert rules: http://localhost:9090/alerts
- Verify Alertmanager config: `docker logs marketsage-alertmanager`
- Check Slack webhook URL is correct
- Test webhook manually with curl

**Dashboard not loading?**
- Check Grafana datasource configured
- Verify Prometheus URL in datasource
- Check Grafana logs: `docker logs marketsage-grafana`

---

**Ready to start? Pick Monday's task and go! 🚀**
