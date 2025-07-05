# Sentry Integration Guide

## Installation

From your MarketSage project root, install Sentry packages:

```bash
npm install @sentry/nextjs @sentry/tracing
```

## Configuration Files

### 1. Create `sentry.client.config.ts` in project root:

```typescript
import * as Sentry from "@sentry/nextjs";

Sentry.init({
  dsn: process.env.SENTRY_DSN,
  environment: process.env.SENTRY_ENVIRONMENT || "development",
  release: process.env.SENTRY_RELEASE || "1.0.0",
  
  // Performance Monitoring
  tracesSampleRate: parseFloat(process.env.SENTRY_TRACES_SAMPLE_RATE || "1.0"),
  
  // Session Replay
  replaysSessionSampleRate: parseFloat(process.env.SENTRY_REPLAYS_SESSION_SAMPLE_RATE || "0.1"),
  replaysOnErrorSampleRate: parseFloat(process.env.SENTRY_REPLAYS_ON_ERROR_SAMPLE_RATE || "1.0"),
  
  // Error Filtering
  beforeSend(event, hint) {
    // Filter out development errors
    if (process.env.NODE_ENV === "development") {
      return null;
    }
    return event;
  },
  
  // Integration with existing monitoring
  integrations: [
    new Sentry.Replay({
      maskAllText: true,
      blockAllMedia: true,
    }),
  ],
});
```

### 2. Create `sentry.server.config.ts` in project root:

```typescript
import * as Sentry from "@sentry/nextjs";

Sentry.init({
  dsn: process.env.SENTRY_DSN,
  environment: process.env.SENTRY_ENVIRONMENT || "development",
  release: process.env.SENTRY_RELEASE || "1.0.0",
  
  // Performance Monitoring
  tracesSampleRate: parseFloat(process.env.SENTRY_TRACES_SAMPLE_RATE || "1.0"),
  
  // Error Filtering
  beforeSend(event, hint) {
    // Filter out development errors
    if (process.env.NODE_ENV === "development") {
      return null;
    }
    return event;
  },
  
  // Database and external service tracing
  integrations: [
    new Sentry.Integrations.Postgres(),
    new Sentry.Integrations.Redis(),
  ],
});
```

### 3. Create `sentry.edge.config.ts` in project root:

```typescript
import * as Sentry from "@sentry/nextjs";

Sentry.init({
  dsn: process.env.SENTRY_DSN,
  environment: process.env.SENTRY_ENVIRONMENT || "development",
  release: process.env.SENTRY_RELEASE || "1.0.0",
  
  tracesSampleRate: parseFloat(process.env.SENTRY_TRACES_SAMPLE_RATE || "1.0"),
});
```

### 4. Update `next.config.js`:

```javascript
const { withSentryConfig } = require("@sentry/nextjs");

/** @type {import('next').NextConfig} */
const nextConfig = {
  // Your existing Next.js config
  experimental: {
    serverComponentsExternalPackages: ["puppeteer"],
  },
  
  // Sentry configuration
  sentry: {
    hideSourceMaps: true,
    widenClientFileUpload: true,
  },
};

module.exports = withSentryConfig(nextConfig, {
  org: "your-sentry-org",
  project: "marketsage",
  
  // Upload source maps during build
  silent: true,
  
  // Automatically annotate React components for better stack traces
  reactComponentAnnotation: {
    enabled: true,
  },
});
```

## Environment Variables

Add these to your `.env` file:

```env
# Sentry Configuration
SENTRY_DSN=your-sentry-dsn-here
SENTRY_ENVIRONMENT=development
SENTRY_RELEASE=1.0.0
SENTRY_TRACES_SAMPLE_RATE=1.0
SENTRY_REPLAYS_SESSION_SAMPLE_RATE=0.1
SENTRY_REPLAYS_ON_ERROR_SAMPLE_RATE=1.0
```

## Custom Error Tracking

### Add to error boundaries and API routes:

```typescript
// In API routes (pages/api/*)
import * as Sentry from "@sentry/nextjs";

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  try {
    // Your API logic
  } catch (error) {
    Sentry.captureException(error, {
      tags: {
        api_route: req.url,
        method: req.method,
      },
      extra: {
        requestBody: req.body,
        userAgent: req.headers["user-agent"],
      },
    });
    
    res.status(500).json({ error: "Internal server error" });
  }
}
```

### Add to React components:

```typescript
// In components with error boundaries
import * as Sentry from "@sentry/nextjs";

export function MyComponent() {
  const handleError = (error: Error) => {
    Sentry.captureException(error, {
      tags: {
        component: "MyComponent",
        feature: "dashboard",
      },
    });
  };

  return (
    <Sentry.ErrorBoundary fallback={ErrorFallback} beforeCapture={handleError}>
      {/* Your component */}
    </Sentry.ErrorBoundary>
  );
}
```

## Performance Monitoring

### Add custom transactions:

```typescript
import * as Sentry from "@sentry/nextjs";

// For AI operations
export async function processAIRequest(prompt: string) {
  return await Sentry.startSpan({
    name: "ai.process_request",
    op: "ai.inference",
    attributes: {
      "ai.model": "gpt-4o-mini",
      "ai.prompt_length": prompt.length,
    },
  }, async () => {
    // Your AI processing logic
    const result = await openai.chat.completions.create({
      model: "gpt-4o-mini",
      messages: [{ role: "user", content: prompt }],
    });
    
    Sentry.getCurrentScope().setTag("ai.tokens_used", result.usage?.total_tokens);
    return result;
  });
}

// For database operations
export async function getUserData(userId: string) {
  return await Sentry.startSpan({
    name: "db.query.user",
    op: "db.query",
    attributes: {
      "db.operation": "SELECT",
      "db.table": "users",
      "user.id": userId,
    },
  }, async () => {
    return await prisma.user.findUnique({
      where: { id: userId },
      include: { campaigns: true, contacts: true },
    });
  });
}
```

## Integration with Existing Monitoring

### Add Sentry correlation to your metrics:

```typescript
// In your metrics collection
import * as Sentry from "@sentry/nextjs";

function collectBusinessMetrics() {
  const span = Sentry.getCurrentScope().getSpan();
  const traceId = span?.getSpanContext()?.traceId;
  
  // Add trace correlation to your Prometheus metrics
  businessMetrics.inc({
    trace_id: traceId,
    user_id: userId,
    campaign_id: campaignId,
  });
}
```

## Dashboard Integration

### Add Sentry metrics to your Grafana dashboards:

1. Configure Sentry as a data source in Grafana
2. Create panels for:
   - Error rates by endpoint
   - Performance metrics (LCP, FID, CLS)
   - User session replays
   - Release performance comparison

### Example Grafana query:

```promql
# Error rate by API endpoint
sum(rate(sentry_errors_total[5m])) by (endpoint)

# Performance metrics
histogram_quantile(0.95, sum(rate(sentry_transaction_duration_seconds_bucket[5m])) by (le, transaction))
```

## Alerting Integration

### Update your Alertmanager configuration:

```yaml
routes:
  - match:
      alertname: SentryErrorSpike
    receiver: sentry-critical
    group_wait: 10s
    group_interval: 10s
    repeat_interval: 1h
    
receivers:
  - name: sentry-critical
    webhook_configs:
      - url: 'https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK'
        send_resolved: true
        title: '🚨 High Error Rate Detected'
        text: 'Sentry detected {{ .GroupLabels.error_count }} errors in the last 5 minutes'
```

## Next Steps

1. **Set up Sentry project**: Create a new project at sentry.io
2. **Get DSN**: Copy your project's DSN from Sentry dashboard
3. **Update environment variables**: Add your actual Sentry DSN
4. **Deploy and test**: Deploy your app and generate some errors to test
5. **Configure alerts**: Set up Sentry alerts for critical errors
6. **Add dashboards**: Create Grafana dashboards with Sentry metrics

This integration will provide:
- ✅ Real-time error tracking with stack traces
- ✅ Performance monitoring with Web Vitals
- ✅ Session replay for debugging
- ✅ Integration with existing monitoring stack
- ✅ Business context in error reports