# World-Class Monitoring Implementation Guide

## Quick Start: High-Impact Wins (This Week)

### 1. Frontend Error Tracking with Sentry (30 minutes)

**Install Sentry**
```bash
cd /Users/supreme/Desktop/marketsage-frontend
npm install @sentry/nextjs
npx @sentry/wizard@latest -i nextjs
```

**Configure Environment Variables**
```bash
# .env.local
NEXT_PUBLIC_SENTRY_DSN=your-sentry-dsn
SENTRY_ORG=your-org
SENTRY_PROJECT=marketsage-frontend
SENTRY_AUTH_TOKEN=your-auth-token
```

**Create Sentry Configuration**
```typescript
// marketsage-frontend/sentry.client.config.ts
import * as Sentry from '@sentry/nextjs';

Sentry.init({
  dsn: process.env.NEXT_PUBLIC_SENTRY_DSN,
  environment: process.env.NODE_ENV,
  tracesSampleRate: 0.1,
  profilesSampleRate: 0.1,
  beforeSend(event, hint) {
    // Filter out sensitive data
    if (event.request) {
      delete event.request.cookies;
    }
    return event;
  },
  integrations: [
    new Sentry.BrowserTracing({
      tracePropagationTargets: ['localhost', /^https:\/\/api\.marketsage\.com/],
    }),
    new Sentry.Replay({
      maskAllText: true,
      blockAllMedia: true,
    }),
  ],
});
```

**Impact**: Immediate visibility into frontend errors, user impact, and performance issues.

---

### 2. Admin Portal Error Tracking (30 minutes)

**Install Sentry**
```bash
cd /Users/supreme/Desktop/marketsage-admin
npm install @sentry/nextjs
npx @sentry/wizard@latest -i nextjs
```

**Configure Environment Variables**
```bash
# .env.local
NEXT_PUBLIC_SENTRY_DSN=your-admin-sentry-dsn
SENTRY_ORG=your-org
SENTRY_PROJECT=marketsage-admin
```

**Create Audit Logging Middleware**
```typescript
// marketsage-admin/src/middleware/audit-logger.ts
import { NextRequest, NextResponse } from 'next/server';
import * as Sentry from '@sentry/nextjs';

export async function auditLogger(request: NextRequest) {
  const start = Date.now();
  const response = NextResponse.next();
  const duration = Date.now() - start;

  // Log all admin actions
  if (request.method !== 'GET') {
    const user = request.headers.get('x-user-id');
    const action = {
      method: request.method,
      path: request.nextUrl.pathname,
      user,
      duration,
      timestamp: new Date().toISOString(),
    };

    // Send to Sentry as breadcrumb
    Sentry.addBreadcrumb({
      category: 'admin.action',
      message: `${request.method} ${request.nextUrl.pathname}`,
      level: 'info',
      data: action,
    });

    // Send to backend for audit trail
    fetch(`${process.env.NEXT_PUBLIC_BACKEND_URL}/api/audit-logs`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(action),
    }).catch(console.error);
  }

  return response;
}
```

**Impact**: Complete visibility into all admin portal actions and errors.

---

### 3. Web Vitals Collection (1 hour)

**Install Web Vitals**
```bash
cd /Users/supreme/Desktop/marketsage-frontend
npm install web-vitals
```

**Create Web Vitals Reporter**
```typescript
// marketsage-frontend/src/lib/monitoring/web-vitals.ts
import { onCLS, onFID, onLCP, onFCP, onTTFB, Metric } from 'web-vitals';

// Send to your analytics endpoint
function sendToAnalytics(metric: Metric) {
  const body = JSON.stringify({
    name: metric.name,
    value: metric.value,
    rating: metric.rating,
    delta: metric.delta,
    id: metric.id,
    page: window.location.pathname,
    userAgent: navigator.userAgent,
  });

  // Use sendBeacon if available for reliability
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

  // Also send to Prometheus via pushgateway
  sendToPrometheus(metric);
}

function sendToPrometheus(metric: Metric) {
  const metricName = `marketsage_frontend_webvital_${metric.name.toLowerCase()}_${metric.rating}`;

  fetch('/api/metrics/push', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      name: metricName,
      value: metric.value,
      labels: {
        page: window.location.pathname,
        rating: metric.rating,
      },
    }),
  });
}

// Report all Web Vitals
export function reportWebVitals() {
  onCLS(sendToAnalytics);
  onFID(sendToAnalytics);
  onLCP(sendToAnalytics);
  onFCP(sendToAnalytics);
  onTTFB(sendToAnalytics);
}
```

**Add to Root Layout**
```typescript
// marketsage-frontend/src/app/layout.tsx
'use client';

import { useEffect } from 'react';
import { reportWebVitals } from '@/lib/monitoring/web-vitals';

export default function RootLayout({ children }) {
  useEffect(() => {
    reportWebVitals();
  }, []);

  return (
    <html>
      <body>{children}</body>
    </html>
  );
}
```

**Create API Endpoint**
```typescript
// marketsage-frontend/src/app/api/analytics/web-vitals/route.ts
import { NextRequest, NextResponse } from 'next/server';

export async function POST(request: NextRequest) {
  try {
    const metric = await request.json();

    // Store in database or send to backend
    await fetch(`${process.env.BACKEND_URL}/api/analytics/web-vitals`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(metric),
    });

    // Log to console for now
    console.log('Web Vital:', metric);

    return NextResponse.json({ success: true });
  } catch (error) {
    console.error('Failed to record web vital:', error);
    return NextResponse.json({ error: 'Failed to record metric' }, { status: 500 });
  }
}
```

**Impact**: Real-time visibility into user experience metrics.

---

### 4. Business KPI Dashboard (2 hours)

**Create Prometheus Recording Rules**
```yaml
# marketsage-monitoring/config/rules/business-kpis.yml
groups:
  - name: business.kpis
    interval: 5m
    rules:
      # Daily Active Users (DAU)
      - record: marketsage_business_dau
        expr: count(count by (user_id) (marketsage_backend_http_requests_total{job="marketsage-backend"} offset 1h))

      # Monthly Recurring Revenue (MRR) - requires custom metric from backend
      - record: marketsage_business_mrr_dollars
        expr: sum(marketsage_backend_subscription_revenue_total)

      # Conversion Rate
      - record: marketsage_business_conversion_rate
        expr: |
          rate(marketsage_backend_conversions_total[1h]) /
          rate(marketsage_backend_visitors_total[1h])

      # Average Session Duration
      - record: marketsage_business_avg_session_duration_seconds
        expr: |
          avg(marketsage_backend_session_duration_seconds)

      # Churn Rate (last 30 days)
      - record: marketsage_business_churn_rate
        expr: |
          (sum(marketsage_backend_users_churned_total{period="30d"}) /
           sum(marketsage_backend_users_total{period="30d"})) * 100
```

**Create Grafana Dashboard JSON**
```json
{
  "dashboard": {
    "title": "Business KPIs - Executive Overview",
    "panels": [
      {
        "title": "Monthly Recurring Revenue (MRR)",
        "type": "stat",
        "targets": [{
          "expr": "marketsage_business_mrr_dollars",
          "legendFormat": "MRR"
        }],
        "fieldConfig": {
          "defaults": {
            "unit": "currencyUSD",
            "color": { "mode": "thresholds" },
            "thresholds": {
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
        "title": "Daily Active Users (DAU)",
        "type": "graph",
        "targets": [{
          "expr": "marketsage_business_dau",
          "legendFormat": "DAU"
        }]
      },
      {
        "title": "Conversion Rate",
        "type": "gauge",
        "targets": [{
          "expr": "marketsage_business_conversion_rate * 100",
          "legendFormat": "Conversion %"
        }],
        "fieldConfig": {
          "defaults": {
            "unit": "percent",
            "min": 0,
            "max": 100,
            "thresholds": {
              "steps": [
                { "value": 0, "color": "red" },
                { "value": 2, "color": "yellow" },
                { "value": 5, "color": "green" }
              ]
            }
          }
        }
      },
      {
        "title": "Churn Rate (30d)",
        "type": "stat",
        "targets": [{
          "expr": "marketsage_business_churn_rate",
          "legendFormat": "Churn %"
        }],
        "fieldConfig": {
          "defaults": {
            "unit": "percent",
            "color": { "mode": "thresholds" },
            "thresholds": {
              "steps": [
                { "value": 0, "color": "green" },
                { "value": 5, "color": "yellow" },
                { "value": 10, "color": "red" }
              ]
            }
          }
        }
      }
    ]
  }
}
```

**Impact**: Executive visibility into business health in real-time.

---

### 5. Enhanced Backend Metrics (1 hour)

**Add Business Metrics to Backend**
```typescript
// marketsage-backend/src/metrics/business-metrics.service.ts
import { Injectable } from '@nestjs/common';
import { Counter, Gauge } from 'prom-client';

@Injectable()
export class BusinessMetricsService {
  // Revenue Metrics
  private readonly revenueCounter = new Counter({
    name: 'marketsage_backend_revenue_total',
    help: 'Total revenue generated',
    labelNames: ['currency', 'plan_type', 'organization_id'],
  });

  private readonly mrrGauge = new Gauge({
    name: 'marketsage_backend_mrr_dollars',
    help: 'Current Monthly Recurring Revenue',
  });

  // User Metrics
  private readonly userSignupsCounter = new Counter({
    name: 'marketsage_backend_user_signups_total',
    help: 'Total user signups',
    labelNames: ['source', 'plan'],
  });

  private readonly activeUsersGauge = new Gauge({
    name: 'marketsage_backend_active_users',
    help: 'Currently active users',
    labelNames: ['period'], // 1h, 24h, 30d
  });

  // Conversion Metrics
  private readonly conversionsCounter = new Counter({
    name: 'marketsage_backend_conversions_total',
    help: 'Total conversions',
    labelNames: ['type', 'campaign_id'],
  });

  private readonly visitorsCounter = new Counter({
    name: 'marketsage_backend_visitors_total',
    help: 'Total unique visitors',
  });

  // Campaign Metrics
  private readonly campaignsSentCounter = new Counter({
    name: 'marketsage_backend_campaigns_sent_total',
    help: 'Total campaigns sent',
    labelNames: ['channel', 'status'],
  });

  private readonly campaignEngagementCounter = new Counter({
    name: 'marketsage_backend_campaign_engagement_total',
    help: 'Total campaign engagements',
    labelNames: ['type', 'campaign_id'], // open, click, reply
  });

  // Methods to record metrics
  recordRevenue(amount: number, currency: string, planType: string, orgId: string) {
    this.revenueCounter.inc({ currency, plan_type: planType, organization_id: orgId }, amount);
  }

  updateMRR(amount: number) {
    this.mrrGauge.set(amount);
  }

  recordUserSignup(source: string, plan: string) {
    this.userSignupsCounter.inc({ source, plan });
  }

  updateActiveUsers(count: number, period: '1h' | '24h' | '30d') {
    this.activeUsersGauge.set({ period }, count);
  }

  recordConversion(type: string, campaignId?: string) {
    this.conversionsCounter.inc({ type, campaign_id: campaignId || 'organic' });
  }

  recordVisitor() {
    this.visitorsCounter.inc();
  }

  recordCampaignSent(channel: string, status: string) {
    this.campaignsSentCounter.inc({ channel, status });
  }

  recordCampaignEngagement(type: 'open' | 'click' | 'reply', campaignId: string) {
    this.campaignEngagementCounter.inc({ type, campaign_id: campaignId });
  }
}
```

**Integrate into Existing Services**
```typescript
// marketsage-backend/src/billing/billing.service.ts
import { BusinessMetricsService } from '../metrics/business-metrics.service';

@Injectable()
export class BillingService {
  constructor(
    private businessMetrics: BusinessMetricsService,
  ) {}

  async processSubscription(subscription: Subscription) {
    // ... existing code ...

    // Record metrics
    this.businessMetrics.recordRevenue(
      subscription.amount,
      subscription.currency,
      subscription.plan,
      subscription.organizationId
    );

    // Update MRR
    const totalMRR = await this.calculateTotalMRR();
    this.businessMetrics.updateMRR(totalMRR);
  }
}
```

**Impact**: Real-time business metrics exposed to Prometheus.

---

### 6. SLO Tracking (2 hours)

**Define SLOs**
```yaml
# marketsage-monitoring/config/slos/api-availability.yml
apiVersion: v1
kind: SLO
metadata:
  name: api-availability
spec:
  service: marketsage-backend
  sli:
    metric: |
      sum(rate(marketsage_backend_http_requests_total{status!~"5.."}[5m]))
      /
      sum(rate(marketsage_backend_http_requests_total[5m]))
  objective: 0.999  # 99.9% availability
  window: 30d
```

**Create SLO Alert Rules**
```yaml
# marketsage-monitoring/config/rules/slo-alerts.yml
groups:
  - name: slo.alerts
    interval: 1m
    rules:
      # API Availability SLO
      - alert: APIAvailabilitySLOBreach
        expr: |
          (
            1 - (
              sum(rate(marketsage_backend_http_requests_total{status!~"5.."}[30d]))
              /
              sum(rate(marketsage_backend_http_requests_total[30d]))
            )
          ) > 0.001  # 99.9% target
        for: 5m
        labels:
          severity: critical
          slo: api-availability
        annotations:
          summary: "API Availability SLO breached"
          description: "Current availability: {{ $value | humanizePercentage }}"

      # Error Budget Burn Rate (fast burn)
      - alert: HighErrorBudgetBurnRate
        expr: |
          (
            sum(rate(marketsage_backend_http_requests_total{status=~"5.."}[1h]))
            /
            sum(rate(marketsage_backend_http_requests_total[1h]))
          ) > (14.4 * 0.001)  # 14.4x the acceptable error rate
        for: 5m
        labels:
          severity: critical
          slo: error-budget
        annotations:
          summary: "Error budget burning too fast"
          description: "At this rate, error budget will be exhausted in <2 hours"

      # Frontend Performance SLO
      - alert: FrontendPerformanceSLOBreach
        expr: |
          (
            sum(rate(marketsage_frontend_webvital_lcp_good[30d]))
            /
            sum(rate(marketsage_frontend_webvital_lcp_total[30d]))
          ) < 0.90  # 90% of pages should have LCP < 2.5s
        for: 10m
        labels:
          severity: warning
          slo: frontend-performance
        annotations:
          summary: "Frontend performance SLO breached"
          description: "Only {{ $value | humanizePercentage }} of pages meet LCP target"
```

**Create SLO Dashboard**
```json
{
  "dashboard": {
    "title": "SRE - SLO Tracking",
    "panels": [
      {
        "title": "API Availability (30d)",
        "type": "gauge",
        "targets": [{
          "expr": "sum(rate(marketsage_backend_http_requests_total{status!~\"5..\"}[30d])) / sum(rate(marketsage_backend_http_requests_total[30d])) * 100"
        }],
        "fieldConfig": {
          "defaults": {
            "unit": "percent",
            "min": 99,
            "max": 100,
            "thresholds": {
              "steps": [
                { "value": 99, "color": "red" },
                { "value": 99.9, "color": "yellow" },
                { "value": 99.95, "color": "green" }
              ]
            }
          }
        }
      },
      {
        "title": "Error Budget Remaining",
        "type": "graph",
        "targets": [{
          "expr": "1 - (sum(increase(marketsage_backend_http_requests_total{status=~\"5..\"}[30d])) / (sum(increase(marketsage_backend_http_requests_total[30d])) * 0.001))"
        }]
      }
    ]
  }
}
```

**Impact**: Clear visibility into service reliability and error budget consumption.

---

## Phase-by-Phase Implementation

### Phase 1: Frontend Monitoring (Week 1-2)

#### 1.1 Real User Monitoring Setup

**Files to Create:**

**1. `/marketsage-frontend/src/lib/monitoring/rum.ts`**
```typescript
import * as Sentry from '@sentry/nextjs';

export interface PageView {
  page: string;
  loadTime: number;
  userId?: string;
  organizationId?: string;
}

export interface UserAction {
  action: string;
  target: string;
  page: string;
  timestamp: number;
}

class RealUserMonitoring {
  private pageLoadStart: number = 0;

  init() {
    if (typeof window === 'undefined') return;

    this.trackPageLoad();
    this.trackUserActions();
    this.trackNetworkErrors();
  }

  private trackPageLoad() {
    this.pageLoadStart = performance.now();

    window.addEventListener('load', () => {
      const loadTime = performance.now() - this.pageLoadStart;

      this.sendPageView({
        page: window.location.pathname,
        loadTime,
      });

      // Track navigation timing
      if (performance.getEntriesByType) {
        const [navigationTiming] = performance.getEntriesByType('navigation') as PerformanceNavigationTiming[];

        if (navigationTiming) {
          this.sendMetrics({
            dns: navigationTiming.domainLookupEnd - navigationTiming.domainLookupStart,
            tcp: navigationTiming.connectEnd - navigationTiming.connectStart,
            request: navigationTiming.responseStart - navigationTiming.requestStart,
            response: navigationTiming.responseEnd - navigationTiming.responseStart,
            dom: navigationTiming.domContentLoadedEventEnd - navigationTiming.domContentLoadedEventStart,
          });
        }
      }
    });
  }

  private trackUserActions() {
    // Track clicks
    document.addEventListener('click', (e) => {
      const target = e.target as HTMLElement;
      this.sendUserAction({
        action: 'click',
        target: this.getElementSelector(target),
        page: window.location.pathname,
        timestamp: Date.now(),
      });
    });

    // Track form submissions
    document.addEventListener('submit', (e) => {
      const target = e.target as HTMLFormElement;
      this.sendUserAction({
        action: 'form_submit',
        target: target.id || target.name,
        page: window.location.pathname,
        timestamp: Date.now(),
      });
    });
  }

  private trackNetworkErrors() {
    // Track failed API calls
    const originalFetch = window.fetch;
    window.fetch = async (...args) => {
      const start = performance.now();
      try {
        const response = await originalFetch(...args);
        const duration = performance.now() - start;

        if (!response.ok) {
          this.sendNetworkError({
            url: args[0].toString(),
            status: response.status,
            duration,
          });
        }

        return response;
      } catch (error) {
        const duration = performance.now() - start;
        this.sendNetworkError({
          url: args[0].toString(),
          error: error.message,
          duration,
        });
        throw error;
      }
    };
  }

  private getElementSelector(element: HTMLElement): string {
    if (element.id) return `#${element.id}`;
    if (element.className) return `.${element.className.split(' ')[0]}`;
    return element.tagName.toLowerCase();
  }

  private async sendPageView(pageView: PageView) {
    await fetch('/api/analytics/page-view', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(pageView),
    });
  }

  private async sendUserAction(action: UserAction) {
    await fetch('/api/analytics/user-action', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(action),
    });
  }

  private async sendMetrics(metrics: any) {
    await fetch('/api/analytics/performance', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(metrics),
    });
  }

  private async sendNetworkError(error: any) {
    Sentry.captureException(new Error('Network request failed'), {
      extra: error,
    });
  }
}

export const rum = new RealUserMonitoring();
```

**2. `/marketsage-frontend/src/app/api/analytics/page-view/route.ts`**
```typescript
import { NextRequest, NextResponse } from 'next/server';
import { Counter, Histogram } from 'prom-client';

const pageViewCounter = new Counter({
  name: 'marketsage_frontend_page_views_total',
  help: 'Total page views',
  labelNames: ['page', 'user_id', 'organization_id'],
});

const pageLoadHistogram = new Histogram({
  name: 'marketsage_frontend_page_load_duration_seconds',
  help: 'Page load duration',
  labelNames: ['page'],
  buckets: [0.1, 0.5, 1, 2, 5, 10],
});

export async function POST(request: NextRequest) {
  try {
    const { page, loadTime, userId, organizationId } = await request.json();

    pageViewCounter.inc({ page, user_id: userId, organization_id: organizationId });
    pageLoadHistogram.observe({ page }, loadTime / 1000);

    // Store in database for analytics
    await storePageView({ page, loadTime, userId, organizationId });

    return NextResponse.json({ success: true });
  } catch (error) {
    console.error('Failed to record page view:', error);
    return NextResponse.json({ error: 'Failed to record page view' }, { status: 500 });
  }
}

async function storePageView(data: any) {
  // Send to backend for storage
  await fetch(`${process.env.BACKEND_URL}/api/analytics/page-views`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data),
  });
}
```

---

### Phase 2: Backend Enhancements

#### 2.1 Structured Logging

**Create Logging Service**
```typescript
// marketsage-backend/src/common/services/logger.service.ts
import { Injectable, LoggerService } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

interface LogContext {
  traceId?: string;
  spanId?: string;
  userId?: string;
  organizationId?: string;
  [key: string]: any;
}

@Injectable()
export class StructuredLogger implements LoggerService {
  constructor(private configService: ConfigService) {}

  log(message: string, context?: LogContext) {
    this.write('info', message, context);
  }

  error(message: string, trace?: string, context?: LogContext) {
    this.write('error', message, { ...context, trace });
  }

  warn(message: string, context?: LogContext) {
    this.write('warn', message, context);
  }

  debug(message: string, context?: LogContext) {
    if (this.configService.get('NODE_ENV') === 'development') {
      this.write('debug', message, context);
    }
  }

  private write(level: string, message: string, context?: LogContext) {
    const logEntry = {
      timestamp: new Date().toISOString(),
      level,
      service: 'marketsage-backend',
      message,
      ...context,
    };

    // Write as JSON for Loki to parse
    console.log(JSON.stringify(logEntry));
  }
}
```

---

### Phase 3: Advanced Dashboards

#### 3.1 Customer Journey Dashboard

**Create Customer Journey Tracking**
```typescript
// marketsage-backend/src/analytics/customer-journey.service.ts
import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

interface JourneyStep {
  userId: string;
  step: string;
  timestamp: Date;
  metadata?: any;
}

@Injectable()
export class CustomerJourneyService {
  constructor(private prisma: PrismaService) {}

  async trackStep(step: JourneyStep) {
    await this.prisma.journeyStep.create({
      data: step,
    });

    // Also send to metrics
    this.recordMetric(step);
  }

  async getJourney(userId: string, days: number = 30) {
    const steps = await this.prisma.journeyStep.findMany({
      where: {
        userId,
        timestamp: {
          gte: new Date(Date.now() - days * 24 * 60 * 60 * 1000),
        },
      },
      orderBy: { timestamp: 'asc' },
    });

    return this.analyzeJourney(steps);
  }

  private analyzeJourney(steps: any[]) {
    // Common patterns
    const patterns = this.identifyPatterns(steps);

    // Drop-off points
    const dropoffs = this.identifyDropoffs(steps);

    // Conversion paths
    const paths = this.identifyPaths(steps);

    return { patterns, dropoffs, paths };
  }

  private identifyPatterns(steps: any[]) {
    // Implement pattern detection
    return [];
  }

  private identifyDropoffs(steps: any[]) {
    // Implement dropoff detection
    return [];
  }

  private identifyPaths(steps: any[]) {
    // Implement path analysis
    return [];
  }

  private recordMetric(step: JourneyStep) {
    // Send to Prometheus
  }
}
```

---

## Monitoring Integration Checklist

### Backend Integration
- [ ] Add `BusinessMetricsService` to all revenue-generating services
- [ ] Add `StructuredLogger` to all controllers and services
- [ ] Instrument all database queries with timing
- [ ] Add custom metrics for all business events
- [ ] Configure Sentry for backend error tracking

### Frontend Integration
- [ ] Install and configure Sentry
- [ ] Implement Web Vitals reporting
- [ ] Add RUM tracking to all pages
- [ ] Instrument all API calls
- [ ] Add error boundaries to all routes

### Admin Portal Integration
- [ ] Install and configure Sentry
- [ ] Implement audit logging middleware
- [ ] Track all admin actions
- [ ] Monitor security events
- [ ] Add performance tracking

### Monitoring Stack Configuration
- [ ] Deploy new Grafana dashboards
- [ ] Configure alert rules
- [ ] Set up PagerDuty/Opsgenie integration
- [ ] Configure Slack notifications
- [ ] Set up on-call rotation

---

## Testing Your Monitoring

### 1. Test Error Tracking
```bash
# Frontend
curl -X POST http://localhost:3000/api/test/error

# Backend
curl -X POST http://localhost:3006/api/test/error
```

### 2. Test Metrics
```bash
# Check Prometheus targets
curl http://localhost:9090/api/v1/targets

# Check specific metric
curl http://localhost:9090/api/v1/query?query=marketsage_backend_http_requests_total
```

### 3. Test Alerts
```bash
# Trigger alert by causing errors
for i in {1..100}; do
  curl -X POST http://localhost:3006/api/fail
done

# Check Alertmanager
curl http://localhost:9093/api/v2/alerts
```

### 4. Test Dashboards
- Visit http://localhost:3010 (Grafana)
- Verify all panels load
- Check data sources are connected
- Test alert rules

---

## Maintenance & Operations

### Daily Tasks
- Review overnight alerts
- Check error rates
- Verify SLO compliance
- Review critical dashboards

### Weekly Tasks
- Review monitoring costs
- Update dashboards based on feedback
- Fine-tune alert thresholds
- Review incident responses

### Monthly Tasks
- Review SLO compliance
- Analyze error budget consumption
- Update monitoring strategy
- Plan capacity

### Quarterly Tasks
- Evaluate new monitoring tools
- Review overall monitoring architecture
- Update documentation
- Train team on new features

---

## Troubleshooting

### Common Issues

**1. Metrics not appearing in Prometheus**
```bash
# Check if endpoint is accessible
curl http://localhost:3006/metrics

# Check Prometheus config
docker exec marketsage-prometheus cat /etc/prometheus/prometheus.yml

# Check Prometheus logs
docker logs marketsage-prometheus
```

**2. Dashboards not loading**
```bash
# Check Grafana datasources
curl -u admin:password http://localhost:3010/api/datasources

# Check Grafana logs
docker logs marketsage-grafana
```

**3. Alerts not firing**
```bash
# Check alert rules
curl http://localhost:9090/api/v1/rules

# Check Alertmanager config
docker exec marketsage-alertmanager cat /etc/alertmanager/alertmanager.yml
```

---

**Last Updated**: 2025-10-08
**Version**: 1.0
