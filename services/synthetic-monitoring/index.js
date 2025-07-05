const express = require('express');
const puppeteer = require('puppeteer');
const client = require('prom-client');
const axios = require('axios');
const cron = require('node-cron');
const winston = require('winston');
require('dotenv').config();

const app = express();
const port = process.env.PORT || 8082;

// Configure logging
const logger = winston.createLogger({
  level: 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json()
  ),
  transports: [
    new winston.transports.Console(),
    new winston.transports.File({ filename: 'synthetic-monitoring.log' })
  ]
});

// Initialize Prometheus metrics
const register = new client.Registry();
client.collectDefaultMetrics({ register });

// Synthetic monitoring metrics
const syntheticMetrics = {
  // Uptime metrics
  uptimeCheck: new client.Gauge({
    name: 'marketsage_uptime_status',
    help: 'Service uptime status (1 = up, 0 = down)',
    labelNames: ['service', 'endpoint', 'method'],
    registers: [register]
  }),
  
  responseTime: new client.Histogram({
    name: 'marketsage_response_time_seconds',
    help: 'Response time for synthetic checks in seconds',
    labelNames: ['service', 'endpoint', 'method'],
    buckets: [0.1, 0.5, 1.0, 2.0, 5.0, 10.0, 30.0],
    registers: [register]
  }),
  
  // User journey metrics
  userJourneySuccess: new client.Gauge({
    name: 'marketsage_user_journey_success',
    help: 'User journey success rate (1 = success, 0 = failure)',
    labelNames: ['journey', 'step'],
    registers: [register]
  }),
  
  userJourneyDuration: new client.Histogram({
    name: 'marketsage_user_journey_duration_seconds',
    help: 'User journey completion time in seconds',
    labelNames: ['journey'],
    buckets: [1, 5, 10, 30, 60, 120, 300],
    registers: [register]
  }),
  
  // SSL certificate metrics
  sslCertExpiry: new client.Gauge({
    name: 'marketsage_ssl_cert_expiry_days',
    help: 'Days until SSL certificate expiry',
    labelNames: ['domain'],
    registers: [register]
  }),
  
  // Performance metrics
  pageLoadTime: new client.Histogram({
    name: 'marketsage_page_load_time_seconds',
    help: 'Page load time in seconds',
    labelNames: ['page', 'metric_type'],
    buckets: [0.5, 1.0, 2.0, 5.0, 10.0, 20.0],
    registers: [register]
  }),
  
  // API health metrics
  apiHealthScore: new client.Gauge({
    name: 'marketsage_api_health_score',
    help: 'API health score (0-100)',
    labelNames: ['api_group'],
    registers: [register]
  }),
  
  // Error rate metrics
  errorRate: new client.Gauge({
    name: 'marketsage_synthetic_error_rate',
    help: 'Error rate percentage for synthetic checks',
    labelNames: ['check_type'],
    registers: [register]
  })
};

// Configuration
const config = {
  baseUrl: process.env.MARKETSAGE_BASE_URL || 'http://marketsage-web:3000',
  puppeteerOptions: {
    headless: true,
    args: [
      '--no-sandbox',
      '--disable-setuid-sandbox',
      '--disable-dev-shm-usage',
      '--disable-accelerated-2d-canvas',
      '--disable-gpu',
      '--window-size=1920,1080'
    ]
  },
  timeouts: {
    navigation: 30000,
    element: 10000,
    request: 5000
  }
};

// API Endpoints to monitor
const apiEndpoints = [
  {
    name: 'health',
    url: '/api/health',
    method: 'GET',
    expectedStatus: 200
  },
  {
    name: 'metrics',
    url: '/api/metrics',
    method: 'GET',
    expectedStatus: 200
  },
  {
    name: 'auth-status',
    url: '/api/auth/session',
    method: 'GET',
    expectedStatus: [200, 401] // Both are valid responses
  },
  {
    name: 'dashboard-data',
    url: '/api/dashboard/stats',
    method: 'GET',
    expectedStatus: [200, 401]
  }
];

// User Journeys to test
const userJourneys = [
  {
    name: 'landing_page_load',
    description: 'Load landing page and check key elements',
    steps: [
      { name: 'load_homepage', url: '/' },
      { name: 'check_navigation', selector: 'nav' },
      { name: 'check_hero_section', selector: '[data-testid="hero-section"]' },
      { name: 'check_cta_button', selector: '[data-testid="cta-button"]' }
    ]
  },
  {
    name: 'login_flow',
    description: 'Test login page accessibility',
    steps: [
      { name: 'load_login_page', url: '/login' },
      { name: 'check_login_form', selector: 'form[data-testid="login-form"]' },
      { name: 'check_email_field', selector: 'input[type="email"]' },
      { name: 'check_password_field', selector: 'input[type="password"]' },
      { name: 'check_submit_button', selector: 'button[type="submit"]' }
    ]
  },
  {
    name: 'signup_flow',
    description: 'Test signup page accessibility',
    steps: [
      { name: 'load_signup_page', url: '/signup' },
      { name: 'check_signup_form', selector: 'form[data-testid="signup-form"]' },
      { name: 'check_terms_checkbox', selector: 'input[type="checkbox"]' }
    ]
  },
  {
    name: 'dashboard_accessibility',
    description: 'Test dashboard page loads (should redirect to login)',
    steps: [
      { name: 'load_dashboard', url: '/dashboard' },
      { name: 'check_redirect', expectedUrl: '/login' }
    ]
  }
];

// Utility functions
async function makeHttpRequest(endpoint) {
  const startTime = Date.now();
  const url = `${config.baseUrl}${endpoint.url}`;
  
  try {
    const response = await axios({
      method: endpoint.method,
      url: url,
      timeout: config.timeouts.request * 1000,
      validateStatus: function (status) {
        return Array.isArray(endpoint.expectedStatus) 
          ? endpoint.expectedStatus.includes(status)
          : status === endpoint.expectedStatus;
      }
    });
    
    const duration = (Date.now() - startTime) / 1000;
    
    syntheticMetrics.uptimeCheck.set(
      { service: 'api', endpoint: endpoint.name, method: endpoint.method },
      1
    );
    
    syntheticMetrics.responseTime.observe(
      { service: 'api', endpoint: endpoint.name, method: endpoint.method },
      duration
    );
    
    logger.info(`✅ API check passed: ${endpoint.name}`, {
      url,
      status: response.status,
      duration: duration
    });
    
    return { success: true, duration, status: response.status };
    
  } catch (error) {
    const duration = (Date.now() - startTime) / 1000;
    
    syntheticMetrics.uptimeCheck.set(
      { service: 'api', endpoint: endpoint.name, method: endpoint.method },
      0
    );
    
    syntheticMetrics.responseTime.observe(
      { service: 'api', endpoint: endpoint.name, method: endpoint.method },
      duration
    );
    
    logger.error(`❌ API check failed: ${endpoint.name}`, {
      url,
      error: error.message,
      duration: duration
    });
    
    return { success: false, duration, error: error.message };
  }
}

async function runUserJourney(journey) {
  const startTime = Date.now();
  let browser;
  
  try {
    browser = await puppeteer.launch(config.puppeteerOptions);
    const page = await browser.newPage();
    
    // Set viewport and user agent
    await page.setViewport({ width: 1920, height: 1080 });
    await page.setUserAgent('MarketSage-SyntheticMonitoring/1.0');
    
    // Enable request interception for performance monitoring
    await page.setRequestInterception(true);
    
    const requests = [];
    page.on('request', (request) => {
      requests.push({
        url: request.url(),
        method: request.method(),
        startTime: Date.now()
      });
      request.continue();
    });
    
    page.on('response', (response) => {
      const request = requests.find(r => r.url === response.url());
      if (request) {
        request.endTime = Date.now();
        request.status = response.status();
      }
    });
    
    // Run journey steps
    let stepsPassed = 0;
    for (const step of journey.steps) {
      try {
        if (step.url) {
          await page.goto(`${config.baseUrl}${step.url}`, {
            waitUntil: 'networkidle2',
            timeout: config.timeouts.navigation
          });
        }
        
        if (step.selector) {
          await page.waitForSelector(step.selector, {
            timeout: config.timeouts.element
          });
        }
        
        if (step.expectedUrl) {
          const currentUrl = page.url();
          if (!currentUrl.includes(step.expectedUrl)) {
            throw new Error(`Expected URL to contain ${step.expectedUrl}, got ${currentUrl}`);
          }
        }
        
        syntheticMetrics.userJourneySuccess.set(
          { journey: journey.name, step: step.name },
          1
        );
        
        stepsPassed++;
        
        logger.info(`✅ Journey step passed: ${journey.name} - ${step.name}`);
        
      } catch (error) {
        syntheticMetrics.userJourneySuccess.set(
          { journey: journey.name, step: step.name },
          0
        );
        
        logger.error(`❌ Journey step failed: ${journey.name} - ${step.name}`, {
          error: error.message
        });
        
        break; // Stop on first failure
      }
    }
    
    // Collect performance metrics
    const performanceMetrics = await page.evaluate(() => {
      const navigation = performance.getEntriesByType('navigation')[0];
      return {
        loadTime: navigation.loadEventEnd - navigation.loadEventStart,
        domContentLoaded: navigation.domContentLoadedEventEnd - navigation.domContentLoadedEventStart,
        firstPaint: performance.getEntriesByName('first-paint')[0]?.startTime || 0,
        firstContentfulPaint: performance.getEntriesByName('first-contentful-paint')[0]?.startTime || 0
      };
    });
    
    // Record performance metrics
    Object.entries(performanceMetrics).forEach(([metric, value]) => {
      if (value > 0) {
        syntheticMetrics.pageLoadTime.observe(
          { page: journey.name, metric_type: metric },
          value / 1000 // Convert to seconds
        );
      }
    });
    
    const totalDuration = (Date.now() - startTime) / 1000;
    const successRate = stepsPassed / journey.steps.length;
    
    syntheticMetrics.userJourneyDuration.observe(
      { journey: journey.name },
      totalDuration
    );
    
    logger.info(`🎯 Journey completed: ${journey.name}`, {
      duration: totalDuration,
      stepsPassed,
      totalSteps: journey.steps.length,
      successRate
    });
    
    return {
      success: successRate === 1,
      duration: totalDuration,
      stepsPassed,
      totalSteps: journey.steps.length,
      performanceMetrics
    };
    
  } catch (error) {
    logger.error(`❌ Journey failed: ${journey.name}`, {
      error: error.message
    });
    
    return {
      success: false,
      error: error.message,
      duration: (Date.now() - startTime) / 1000
    };
    
  } finally {
    if (browser) {
      await browser.close();
    }
  }
}

// Check SSL certificate expiry
async function checkSSLCertificate(domain) {
  try {
    const response = await axios.get(`https://${domain}`, {
      timeout: 5000
    });
    
    // This is a simplified check - in production, you'd want to use a proper SSL checker
    syntheticMetrics.sslCertExpiry.set(
      { domain },
      30 // Placeholder - would need proper SSL cert checking
    );
    
    logger.info(`✅ SSL check passed for ${domain}`);
    return { success: true };
    
  } catch (error) {
    logger.error(`❌ SSL check failed for ${domain}`, {
      error: error.message
    });
    
    return { success: false, error: error.message };
  }
}

// Run all synthetic checks
async function runSyntheticChecks() {
  logger.info('🔄 Starting synthetic monitoring checks...');
  
  const results = {
    timestamp: new Date().toISOString(),
    api: [],
    journeys: [],
    ssl: []
  };
  
  // API endpoint checks
  for (const endpoint of apiEndpoints) {
    const result = await makeHttpRequest(endpoint);
    results.api.push({ endpoint: endpoint.name, ...result });
  }
  
  // User journey checks
  for (const journey of userJourneys) {
    const result = await runUserJourney(journey);
    results.journeys.push({ journey: journey.name, ...result });
  }
  
  // SSL certificate checks (if configured)
  if (process.env.CHECK_SSL_DOMAINS) {
    const domains = process.env.CHECK_SSL_DOMAINS.split(',');
    for (const domain of domains) {
      const result = await checkSSLCertificate(domain.trim());
      results.ssl.push({ domain: domain.trim(), ...result });
    }
  }
  
  // Calculate overall health scores
  const apiSuccessRate = results.api.filter(r => r.success).length / results.api.length;
  const journeySuccessRate = results.journeys.filter(r => r.success).length / results.journeys.length;
  
  syntheticMetrics.apiHealthScore.set(
    { api_group: 'all' },
    apiSuccessRate * 100
  );
  
  syntheticMetrics.errorRate.set(
    { check_type: 'api' },
    (1 - apiSuccessRate) * 100
  );
  
  syntheticMetrics.errorRate.set(
    { check_type: 'journey' },
    (1 - journeySuccessRate) * 100
  );
  
  logger.info('✅ Synthetic monitoring checks completed', {
    apiSuccessRate,
    journeySuccessRate,
    totalChecks: results.api.length + results.journeys.length
  });
  
  return results;
}

// Routes
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    version: process.env.npm_package_version || '1.0.0'
  });
});

app.get('/run-checks', async (req, res) => {
  try {
    const results = await runSyntheticChecks();
    res.json(results);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get('/status', (req, res) => {
  res.json({
    service: 'synthetic-monitoring',
    uptime: process.uptime(),
    memory: process.memoryUsage(),
    config: {
      baseUrl: config.baseUrl,
      apiEndpoints: apiEndpoints.length,
      userJourneys: userJourneys.length
    }
  });
});

// Start server
app.listen(port, () => {
  logger.info(`🚀 Synthetic Monitoring service running on port ${port}`);
  
  // Run initial checks
  runSyntheticChecks().then(() => {
    logger.info('✅ Initial synthetic checks completed');
  });
  
  // Schedule checks every 5 minutes
  cron.schedule('*/5 * * * *', () => {
    runSyntheticChecks();
  });
  
  logger.info('📅 Synthetic checks scheduled every 5 minutes');
});

// Graceful shutdown
process.on('SIGTERM', () => {
  logger.info('📴 Shutting down gracefully...');
  process.exit(0);
});

process.on('SIGINT', () => {
  logger.info('📴 Shutting down gracefully...');
  process.exit(0);
});