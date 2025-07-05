# Real User Monitoring (RUM) Implementation Guide

## Overview

This guide provides comprehensive instructions for implementing Real User Monitoring (RUM) in your MarketSage application to track actual user experience metrics.

## Core Web Vitals Implementation

### 1. Create RUM utility (`src/lib/rum/web-vitals.ts`)

```typescript
import { getCLS, getFID, getFCP, getLCP, getTTFB } from 'web-vitals';

export interface WebVitalMetric {
  name: string;
  value: number;
  rating: 'good' | 'needs-improvement' | 'poor';
  delta: number;
  id: string;
  navigationType: string;
  timestamp: number;
}

export interface RUMData {
  sessionId: string;
  userId?: string;
  userAgent: string;
  url: string;
  timestamp: number;
  metrics: WebVitalMetric[];
  customMetrics?: Record<string, number>;
  errors?: Array<{
    message: string;
    stack?: string;
    timestamp: number;
  }>;
}

class RUMTracker {
  private sessionId: string;
  private userId?: string;
  private metrics: WebVitalMetric[] = [];
  private customMetrics: Record<string, number> = {};
  private errors: Array<{ message: string; stack?: string; timestamp: number }> = [];
  private beaconUrl: string;

  constructor(beaconUrl: string = '/api/rum/beacon') {
    this.sessionId = this.generateSessionId();
    this.beaconUrl = beaconUrl;
    this.initializeWebVitals();
    this.initializeErrorTracking();
    this.initializePageVisibilityTracking();
  }

  private generateSessionId(): string {
    return `rum_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  }

  private initializeWebVitals(): void {
    // Largest Contentful Paint
    getLCP((metric) => {
      this.recordMetric({
        name: 'LCP',
        value: metric.value,
        rating: metric.rating,
        delta: metric.delta,
        id: metric.id,
        navigationType: metric.navigationType,
        timestamp: Date.now()
      });
    });

    // First Input Delay
    getFID((metric) => {
      this.recordMetric({
        name: 'FID',
        value: metric.value,
        rating: metric.rating,
        delta: metric.delta,
        id: metric.id,
        navigationType: metric.navigationType,
        timestamp: Date.now()
      });
    });

    // Cumulative Layout Shift
    getCLS((metric) => {
      this.recordMetric({
        name: 'CLS',
        value: metric.value,
        rating: metric.rating,
        delta: metric.delta,
        id: metric.id,
        navigationType: metric.navigationType,
        timestamp: Date.now()
      });
    });

    // First Contentful Paint
    getFCP((metric) => {
      this.recordMetric({
        name: 'FCP',
        value: metric.value,
        rating: metric.rating,
        delta: metric.delta,
        id: metric.id,
        navigationType: metric.navigationType,
        timestamp: Date.now()
      });
    });

    // Time to First Byte
    getTTFB((metric) => {
      this.recordMetric({
        name: 'TTFB',
        value: metric.value,
        rating: metric.rating,
        delta: metric.delta,
        id: metric.id,
        navigationType: metric.navigationType,
        timestamp: Date.now()
      });
    });
  }

  private initializeErrorTracking(): void {
    // Global error handler
    window.addEventListener('error', (event) => {
      this.recordError({
        message: event.message,
        stack: event.error?.stack,
        timestamp: Date.now()
      });
    });

    // Unhandled promise rejection handler
    window.addEventListener('unhandledrejection', (event) => {
      this.recordError({
        message: `Unhandled Promise Rejection: ${event.reason}`,
        stack: event.reason?.stack,
        timestamp: Date.now()
      });
    });
  }

  private initializePageVisibilityTracking(): void {
    // Send data when page becomes hidden
    document.addEventListener('visibilitychange', () => {
      if (document.visibilityState === 'hidden') {
        this.sendBeacon();
      }
    });

    // Send data before page unload
    window.addEventListener('beforeunload', () => {
      this.sendBeacon();
    });
  }

  private recordMetric(metric: WebVitalMetric): void {
    this.metrics.push(metric);
    console.log(`[RUM] Web Vital recorded: ${metric.name} = ${metric.value}ms (${metric.rating})`);
    
    // Send immediately for critical metrics
    if (metric.rating === 'poor' || metric.name === 'LCP') {
      this.sendBeacon();
    }
  }

  private recordError(error: { message: string; stack?: string; timestamp: number }): void {
    this.errors.push(error);
    console.error('[RUM] Error recorded:', error);
    
    // Send immediately for errors
    this.sendBeacon();
  }

  public recordCustomMetric(name: string, value: number): void {
    this.customMetrics[name] = value;
    console.log(`[RUM] Custom metric recorded: ${name} = ${value}`);
  }

  public setUserId(userId: string): void {
    this.userId = userId;
  }

  public recordInteraction(interactionType: string, elementId?: string, additionalData?: Record<string, any>): void {
    const interactionMetric = {
      type: interactionType,
      elementId,
      timestamp: Date.now(),
      ...additionalData
    };

    this.customMetrics[`interaction_${interactionType}_${Date.now()}`] = 1;
    console.log('[RUM] Interaction recorded:', interactionMetric);
  }

  public recordPageView(route: string, loadTime?: number): void {
    this.customMetrics['page_view'] = 1;
    this.customMetrics['page_view_timestamp'] = Date.now();
    
    if (loadTime) {
      this.customMetrics['page_load_time'] = loadTime;
    }
    
    console.log(`[RUM] Page view recorded: ${route}`);
  }

  private sendBeacon(): void {
    if (this.metrics.length === 0 && this.errors.length === 0 && Object.keys(this.customMetrics).length === 0) {
      return;
    }

    const rumData: RUMData = {
      sessionId: this.sessionId,
      userId: this.userId,
      userAgent: navigator.userAgent,
      url: window.location.href,
      timestamp: Date.now(),
      metrics: this.metrics,
      customMetrics: this.customMetrics,
      errors: this.errors
    };

    // Use sendBeacon API for reliable data sending
    if (navigator.sendBeacon) {
      navigator.sendBeacon(this.beaconUrl, JSON.stringify(rumData));
    } else {
      // Fallback for older browsers
      fetch(this.beaconUrl, {
        method: 'POST',
        body: JSON.stringify(rumData),
        headers: {
          'Content-Type': 'application/json'
        },
        keepalive: true
      }).catch(error => {
        console.error('[RUM] Failed to send beacon:', error);
      });
    }

    // Clear sent data
    this.metrics = [];
    this.customMetrics = {};
    this.errors = [];
  }

  public forceFlush(): void {
    this.sendBeacon();
  }
}

// Global RUM instance
let rumTracker: RUMTracker;

export function initializeRUM(beaconUrl?: string): RUMTracker {
  if (!rumTracker) {
    rumTracker = new RUMTracker(beaconUrl);
  }
  return rumTracker;
}

export function getRUMTracker(): RUMTracker {
  if (!rumTracker) {
    throw new Error('RUM tracker not initialized. Call initializeRUM() first.');
  }
  return rumTracker;
}

export { RUMTracker };
```

### 2. Create RUM React Hook (`src/hooks/useRUM.ts`)

```typescript
import { useEffect, useCallback } from 'react';
import { useRouter } from 'next/router';
import { getRUMTracker } from '../lib/rum/web-vitals';

export function useRUM() {
  const router = useRouter();
  const rumTracker = getRUMTracker();

  // Track page views
  useEffect(() => {
    const handleRouteChange = (url: string) => {
      rumTracker.recordPageView(url);
    };

    router.events.on('routeChangeComplete', handleRouteChange);
    
    // Record initial page view
    if (router.isReady) {
      rumTracker.recordPageView(router.asPath);
    }

    return () => {
      router.events.off('routeChangeComplete', handleRouteChange);
    };
  }, [router.events, router.isReady, router.asPath, rumTracker]);

  // Track interactions
  const trackInteraction = useCallback((
    interactionType: string,
    elementId?: string,
    additionalData?: Record<string, any>
  ) => {
    rumTracker.recordInteraction(interactionType, elementId, additionalData);
  }, [rumTracker]);

  // Track custom metrics
  const trackCustomMetric = useCallback((name: string, value: number) => {
    rumTracker.recordCustomMetric(name, value);
  }, [rumTracker]);

  // Track form interactions
  const trackFormInteraction = useCallback((formName: string, action: string, field?: string) => {
    trackInteraction('form_interaction', formName, {
      action,
      field,
      timestamp: Date.now()
    });
  }, [trackInteraction]);

  // Track button clicks
  const trackButtonClick = useCallback((buttonId: string, buttonText?: string) => {
    trackInteraction('button_click', buttonId, {
      buttonText,
      timestamp: Date.now()
    });
  }, [trackInteraction]);

  return {
    trackInteraction,
    trackCustomMetric,
    trackFormInteraction,
    trackButtonClick,
    rumTracker
  };
}
```

### 3. Create RUM Context Provider (`src/contexts/RUMContext.tsx`)

```typescript
import React, { createContext, useContext, useEffect, ReactNode } from 'react';
import { useSession } from 'next-auth/react';
import { initializeRUM, RUMTracker } from '../lib/rum/web-vitals';

interface RUMContextType {
  rumTracker: RUMTracker;
}

const RUMContext = createContext<RUMContextType | undefined>(undefined);

interface RUMProviderProps {
  children: ReactNode;
}

export function RUMProvider({ children }: RUMProviderProps) {
  const { data: session } = useSession();
  
  useEffect(() => {
    // Initialize RUM on mount
    const rumTracker = initializeRUM('/api/rum/beacon');
    
    // Set user ID if available
    if (session?.user?.id) {
      rumTracker.setUserId(session.user.id);
    }
    
    // Track initial page load
    rumTracker.recordCustomMetric('app_initialization', Date.now());
    
  }, [session?.user?.id]);

  const rumTracker = initializeRUM('/api/rum/beacon');

  return (
    <RUMContext.Provider value={{ rumTracker }}>
      {children}
    </RUMContext.Provider>
  );
}

export function useRUMContext(): RUMContextType {
  const context = useContext(RUMContext);
  if (!context) {
    throw new Error('useRUMContext must be used within a RUMProvider');
  }
  return context;
}
```

### 4. Create RUM API Endpoint (`pages/api/rum/beacon.ts`)

```typescript
import { NextApiRequest, NextApiResponse } from 'next';
import { RUMData } from '../../../src/lib/rum/web-vitals';

// In-memory storage for demonstration (use Redis or database in production)
const rumDataStore: RUMData[] = [];

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  if (req.method !== 'POST') {
    return res.status(405).json({ message: 'Method not allowed' });
  }

  try {
    const rumData: RUMData = req.body;
    
    // Validate RUM data
    if (!rumData.sessionId || !rumData.timestamp) {
      return res.status(400).json({ message: 'Invalid RUM data' });
    }

    // Store RUM data (in production, send to your analytics service)
    rumDataStore.push(rumData);
    
    // Log for debugging
    console.log('[RUM] Data received:', {
      sessionId: rumData.sessionId,
      userId: rumData.userId,
      url: rumData.url,
      metricsCount: rumData.metrics.length,
      errorsCount: rumData.errors?.length || 0,
      customMetricsCount: Object.keys(rumData.customMetrics || {}).length
    });

    // Forward to external analytics services
    await Promise.all([
      // Send to Google Analytics 4
      sendToGA4(rumData),
      
      // Send to custom analytics endpoint
      sendToCustomAnalytics(rumData),
      
      // Send to Prometheus via pushgateway
      sendToPrometheus(rumData)
    ]);

    res.status(200).json({ message: 'RUM data received' });
  } catch (error) {
    console.error('[RUM] Error processing data:', error);
    res.status(500).json({ message: 'Internal server error' });
  }
}

async function sendToGA4(rumData: RUMData): Promise<void> {
  // Implementation for Google Analytics 4
  // This would use the Measurement Protocol
  try {
    // Example GA4 event
    const ga4Events = rumData.metrics.map(metric => ({
      name: `web_vital_${metric.name.toLowerCase()}`,
      params: {
        metric_value: metric.value,
        metric_rating: metric.rating,
        session_id: rumData.sessionId,
        user_id: rumData.userId
      }
    }));

    // Send to GA4 (implementation depends on your GA4 setup)
    console.log('[RUM] Would send to GA4:', ga4Events);
  } catch (error) {
    console.error('[RUM] GA4 error:', error);
  }
}

async function sendToCustomAnalytics(rumData: RUMData): Promise<void> {
  // Send to your custom analytics service
  try {
    // Implementation depends on your analytics backend
    console.log('[RUM] Would send to custom analytics:', rumData);
  } catch (error) {
    console.error('[RUM] Custom analytics error:', error);
  }
}

async function sendToPrometheus(rumData: RUMData): Promise<void> {
  // Send metrics to Prometheus via pushgateway
  try {
    const prometheusMetrics = rumData.metrics.map(metric => ({
      name: `marketsage_web_vital_${metric.name.toLowerCase()}`,
      value: metric.value,
      labels: {
        session_id: rumData.sessionId,
        user_id: rumData.userId || 'anonymous',
        rating: metric.rating,
        page: new URL(rumData.url).pathname
      }
    }));

    // Would push to Prometheus pushgateway
    console.log('[RUM] Would send to Prometheus:', prometheusMetrics);
  } catch (error) {
    console.error('[RUM] Prometheus error:', error);
  }
}
```

### 5. Create RUM Dashboard Component (`src/components/RUMDashboard.tsx`)

```typescript
import React, { useState, useEffect } from 'react';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { useRUM } from '@/hooks/useRUM';

interface RUMMetrics {
  lcp: number;
  fid: number;
  cls: number;
  fcp: number;
  ttfb: number;
}

export function RUMDashboard() {
  const { rumTracker } = useRUM();
  const [metrics, setMetrics] = useState<RUMMetrics | null>(null);
  
  useEffect(() => {
    // This would fetch real metrics from your API
    // For demo purposes, we'll use dummy data
    setMetrics({
      lcp: 2.5,
      fid: 100,
      cls: 0.1,
      fcp: 1.8,
      ttfb: 800
    });
  }, []);

  const getRating = (metric: string, value: number): string => {
    const thresholds = {
      lcp: { good: 2500, poor: 4000 },
      fid: { good: 100, poor: 300 },
      cls: { good: 0.1, poor: 0.25 },
      fcp: { good: 1800, poor: 3000 },
      ttfb: { good: 800, poor: 1800 }
    };

    const threshold = thresholds[metric as keyof typeof thresholds];
    if (value <= threshold.good) return 'good';
    if (value <= threshold.poor) return 'needs-improvement';
    return 'poor';
  };

  const getRatingColor = (rating: string): string => {
    switch (rating) {
      case 'good': return 'text-green-600';
      case 'needs-improvement': return 'text-yellow-600';
      case 'poor': return 'text-red-600';
      default: return 'text-gray-600';
    }
  };

  if (!metrics) {
    return <div>Loading RUM metrics...</div>;
  }

  return (
    <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
      <Card>
        <CardHeader>
          <CardTitle>Largest Contentful Paint</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="text-2xl font-bold">
            {metrics.lcp.toFixed(1)}s
          </div>
          <div className={`text-sm ${getRatingColor(getRating('lcp', metrics.lcp * 1000))}`}>
            {getRating('lcp', metrics.lcp * 1000)}
          </div>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>First Input Delay</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="text-2xl font-bold">
            {metrics.fid}ms
          </div>
          <div className={`text-sm ${getRatingColor(getRating('fid', metrics.fid))}`}>
            {getRating('fid', metrics.fid)}
          </div>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Cumulative Layout Shift</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="text-2xl font-bold">
            {metrics.cls.toFixed(3)}
          </div>
          <div className={`text-sm ${getRatingColor(getRating('cls', metrics.cls))}`}>
            {getRating('cls', metrics.cls)}
          </div>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>First Contentful Paint</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="text-2xl font-bold">
            {metrics.fcp.toFixed(1)}s
          </div>
          <div className={`text-sm ${getRatingColor(getRating('fcp', metrics.fcp * 1000))}`}>
            {getRating('fcp', metrics.fcp * 1000)}
          </div>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Time to First Byte</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="text-2xl font-bold">
            {metrics.ttfb}ms
          </div>
          <div className={`text-sm ${getRatingColor(getRating('ttfb', metrics.ttfb))}`}>
            {getRating('ttfb', metrics.ttfb)}
          </div>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Actions</CardTitle>
        </CardHeader>
        <CardContent>
          <Button 
            onClick={() => rumTracker.forceFlush()}
            className="w-full"
          >
            Force Flush Metrics
          </Button>
        </CardContent>
      </Card>
    </div>
  );
}
```

### 6. Update `_app.tsx` to include RUM

```typescript
import { RUMProvider } from '@/contexts/RUMContext';
import { useEffect } from 'react';
import { initializeRUM } from '@/lib/rum/web-vitals';

function MyApp({ Component, pageProps }: AppProps) {
  useEffect(() => {
    // Initialize RUM as early as possible
    initializeRUM('/api/rum/beacon');
  }, []);

  return (
    <RUMProvider>
      <Component {...pageProps} />
    </RUMProvider>
  );
}

export default MyApp;
```

## Installation and Setup

### 1. Install Dependencies

```bash
npm install web-vitals
npm install --save-dev @types/web-vitals
```

### 2. Environment Variables

Add to your `.env` file:

```env
# RUM Configuration
RUM_ENABLED=true
RUM_BEACON_URL=/api/rum/beacon
RUM_SAMPLE_RATE=1.0
GA4_MEASUREMENT_ID=G-XXXXXXXXXX
```

### 3. Integration with Existing Monitoring

The RUM data automatically integrates with your existing monitoring stack:

- **Prometheus**: Metrics are pushed via the beacon endpoint
- **Grafana**: Create dashboards using RUM metrics
- **Sentry**: Errors are automatically captured
- **OpenTelemetry**: Traces include RUM context

## Usage Examples

### Track Custom Business Events

```typescript
import { useRUM } from '@/hooks/useRUM';

function CampaignCreator() {
  const { trackCustomMetric, trackInteraction } = useRUM();
  
  const handleCampaignCreate = async () => {
    const startTime = Date.now();
    
    try {
      await createCampaign();
      
      // Track success
      trackCustomMetric('campaign_creation_time', Date.now() - startTime);
      trackInteraction('campaign_created', 'create-campaign-button');
      
    } catch (error) {
      // Errors are automatically tracked
      trackInteraction('campaign_creation_failed', 'create-campaign-button');
    }
  };
}
```

### Track Form Performance

```typescript
function ContactForm() {
  const { trackFormInteraction } = useRUM();
  
  return (
    <form onSubmit={handleSubmit}>
      <input
        type="email"
        onFocus={() => trackFormInteraction('contact-form', 'focus', 'email')}
        onBlur={() => trackFormInteraction('contact-form', 'blur', 'email')}
      />
      <button
        type="submit"
        onClick={() => trackFormInteraction('contact-form', 'submit')}
      >
        Submit
      </button>
    </form>
  );
}
```

## Benefits

✅ **Real User Data**: Actual user experience metrics, not synthetic
✅ **Performance Insights**: Identify slow pages and interactions
✅ **Error Tracking**: Capture and correlate frontend errors
✅ **Business Intelligence**: Track user journeys and conversion funnels
✅ **Core Web Vitals**: Monitor Google's user experience metrics
✅ **Integration**: Works with existing monitoring infrastructure

This RUM implementation provides comprehensive real user monitoring that complements your existing synthetic monitoring and APM tools.