const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const promClient = require('prom-client');
const winston = require('winston');
const cron = require('node-cron');

const MetricsCollector = require('./metrics/collector');
const PayloadAnalyzer = require('./analyzers/payload');
const AuthAnalyzer = require('./analyzers/auth');
const PatternAnalyzer = require('./analyzers/patterns');
const TaskExecutionAnalyzer = require('./analyzers/task-execution');
const TracingService = require('./tracing/service');

class MCPMonitor {
  constructor() {
    this.app = express();
    this.port = process.env.PORT || 8084;
    this.logger = this.setupLogger();
    this.metrics = new MetricsCollector();
    this.payloadAnalyzer = new PayloadAnalyzer();
    this.authAnalyzer = new AuthAnalyzer();
    this.patternAnalyzer = new PatternAnalyzer();
    this.taskExecutionAnalyzer = new TaskExecutionAnalyzer();
    this.tracingService = new TracingService();
    
    this.setupMiddleware();
    this.setupRoutes();
    this.setupScheduledTasks();
  }

  setupLogger() {
    return winston.createLogger({
      level: process.env.LOG_LEVEL || 'info',
      format: winston.format.combine(
        winston.format.timestamp(),
        winston.format.errors({ stack: true }),
        winston.format.json()
      ),
      defaultMeta: { service: 'mcp-monitor' },
      transports: [
        new winston.transports.File({ filename: '/app/logs/error.log', level: 'error' }),
        new winston.transports.File({ filename: '/app/logs/combined.log' }),
        new winston.transports.Console({
          format: winston.format.simple()
        })
      ]
    });
  }

  setupMiddleware() {
    // Security middleware
    this.app.use(helmet());
    this.app.use(cors());
    
    // Rate limiting
    const limiter = rateLimit({
      windowMs: 15 * 60 * 1000, // 15 minutes
      max: 1000, // limit each IP to 1000 requests per windowMs
      message: 'Too many requests from this IP'
    });
    this.app.use(limiter);

    // Body parsing
    this.app.use(express.json({ limit: '10mb' }));
    this.app.use(express.urlencoded({ extended: true }));

    // Request logging
    this.app.use((req, res, next) => {
      this.logger.info('Request received', {
        method: req.method,
        url: req.url,
        ip: req.ip,
        userAgent: req.get('User-Agent'),
        timestamp: new Date().toISOString()
      });
      next();
    });
  }

  setupRoutes() {
    // Health check endpoint
    this.app.get('/health', (req, res) => {
      res.status(200).json({
        status: 'healthy',
        timestamp: new Date().toISOString(),
        uptime: process.uptime(),
        service: 'mcp-monitor'
      });
    });

    // Metrics endpoint for Prometheus
    this.app.get('/metrics', async (req, res) => {
      try {
        res.set('Content-Type', promClient.register.contentType);
        res.end(await promClient.register.metrics());
      } catch (error) {
        this.logger.error('Error generating metrics', { error: error.message });
        res.status(500).end();
      }
    });

    // MCP event ingestion endpoint
    this.app.post('/mcp/events', async (req, res) => {
      try {
        const event = req.body;
        await this.processEvent(event);
        res.status(200).json({ status: 'processed' });
      } catch (error) {
        this.logger.error('Error processing MCP event', { error: error.message, event: req.body });
        res.status(500).json({ error: 'Processing failed' });
      }
    });

    // MCP metrics summary endpoint
    this.app.get('/mcp/summary', async (req, res) => {
      try {
        const summary = await this.metrics.getSummary();
        res.status(200).json(summary);
      } catch (error) {
        this.logger.error('Error getting metrics summary', { error: error.message });
        res.status(500).json({ error: 'Failed to get summary' });
      }
    });

    // Real-time MCP patterns endpoint
    this.app.get('/mcp/patterns', async (req, res) => {
      try {
        const patterns = await this.patternAnalyzer.getCurrentPatterns();
        res.status(200).json(patterns);
      } catch (error) {
        this.logger.error('Error getting patterns', { error: error.message });
        res.status(500).json({ error: 'Failed to get patterns' });
      }
    });

    // MCP authorization events endpoint
    this.app.get('/mcp/auth-events', async (req, res) => {
      try {
        const events = await this.authAnalyzer.getRecentEvents();
        res.status(200).json(events);
      } catch (error) {
        this.logger.error('Error getting auth events', { error: error.message });
        res.status(500).json({ error: 'Failed to get auth events' });
      }
    });

    // Task execution endpoints
    this.app.get('/mcp/tasks/active', async (req, res) => {
      try {
        const tasks = await this.taskExecutionAnalyzer.getCurrentTasks();
        res.status(200).json(tasks);
      } catch (error) {
        this.logger.error('Error getting active tasks', { error: error.message });
        res.status(500).json({ error: 'Failed to get active tasks' });
      }
    });

    this.app.get('/mcp/tasks/stats', async (req, res) => {
      try {
        const stats = await this.taskExecutionAnalyzer.getTaskExecutionStats();
        res.status(200).json(stats);
      } catch (error) {
        this.logger.error('Error getting task stats', { error: error.message });
        res.status(500).json({ error: 'Failed to get task stats' });
      }
    });

    this.app.get('/mcp/tasks/:taskId', async (req, res) => {
      try {
        const task = await this.taskExecutionAnalyzer.getTaskDetails(req.params.taskId);
        if (!task) {
          return res.status(404).json({ error: 'Task not found' });
        }
        res.status(200).json(task);
      } catch (error) {
        this.logger.error('Error getting task details', { error: error.message });
        res.status(500).json({ error: 'Failed to get task details' });
      }
    });

    // Task execution tracking endpoints
    this.app.post('/mcp/tasks/start', async (req, res) => {
      try {
        const result = await this.taskExecutionAnalyzer.trackTaskStart(req.body);
        await this.metrics.recordEvent('task_start', req.body);
        res.status(200).json(result);
      } catch (error) {
        this.logger.error('Error tracking task start', { error: error.message });
        res.status(500).json({ error: 'Failed to track task start' });
      }
    });

    this.app.post('/mcp/tasks/progress', async (req, res) => {
      try {
        const result = await this.taskExecutionAnalyzer.trackTaskProgress(req.body);
        await this.metrics.recordEvent('task_progress', req.body);
        res.status(200).json(result);
      } catch (error) {
        this.logger.error('Error tracking task progress', { error: error.message });
        res.status(500).json({ error: 'Failed to track task progress' });
      }
    });

    this.app.post('/mcp/tasks/complete', async (req, res) => {
      try {
        const result = await this.taskExecutionAnalyzer.trackTaskCompletion(req.body);
        await this.metrics.recordEvent('task_completion', req.body);
        res.status(200).json(result);
      } catch (error) {
        this.logger.error('Error tracking task completion', { error: error.message });
        res.status(500).json({ error: 'Failed to track task completion' });
      }
    });

    this.app.post('/mcp/tasks/retry', async (req, res) => {
      try {
        const result = await this.taskExecutionAnalyzer.trackTaskRetry(req.body);
        await this.metrics.recordEvent('task_retry', req.body);
        res.status(200).json(result);
      } catch (error) {
        this.logger.error('Error tracking task retry', { error: error.message });
        res.status(500).json({ error: 'Failed to track task retry' });
      }
    });
  }

  async processEvent(event) {
    const startTime = Date.now();
    
    try {
      // Extract event metadata
      const eventType = event.type || 'unknown';
      const timestamp = new Date(event.timestamp || Date.now());
      const requestId = event.requestId || 'unknown';
      const userAgent = event.userAgent || 'unknown';
      
      // Update metrics
      this.metrics.recordEvent(eventType, event);
      
      // Analyze payload if present
      if (event.payload) {
        await this.payloadAnalyzer.analyze(event.payload, {
          requestId,
          timestamp,
          userAgent
        });
      }
      
      // Analyze authorization if present
      if (event.authorization) {
        await this.authAnalyzer.analyze(event.authorization, {
          requestId,
          timestamp,
          userAgent
        });
      }
      
      // Track patterns
      await this.patternAnalyzer.trackEvent(event);
      
      // Handle task execution events
      if (event.type === 'task_start') {
        await this.taskExecutionAnalyzer.trackTaskStart(event);
      } else if (event.type === 'task_progress') {
        await this.taskExecutionAnalyzer.trackTaskProgress(event);
      } else if (event.type === 'task_completion') {
        await this.taskExecutionAnalyzer.trackTaskCompletion(event);
      } else if (event.type === 'task_retry') {
        await this.taskExecutionAnalyzer.trackTaskRetry(event);
      }
      
      // Record tracing data
      if (event.traceId) {
        await this.tracingService.recordSpan(event);
      }
      
      const processingTime = Date.now() - startTime;
      this.logger.info('Event processed', {
        eventType,
        requestId,
        processingTime,
        timestamp: timestamp.toISOString()
      });
      
    } catch (error) {
      const processingTime = Date.now() - startTime;
      this.logger.error('Event processing failed', {
        error: error.message,
        processingTime,
        event
      });
      throw error;
    }
  }

  setupScheduledTasks() {
    // Clean up old data every hour
    cron.schedule('0 * * * *', async () => {
      try {
        await this.metrics.cleanup();
        await this.payloadAnalyzer.cleanup();
        await this.authAnalyzer.cleanup();
        await this.patternAnalyzer.cleanup();
        this.logger.info('Scheduled cleanup completed');
      } catch (error) {
        this.logger.error('Scheduled cleanup failed', { error: error.message });
      }
    });

    // Generate hourly reports
    cron.schedule('0 * * * *', async () => {
      try {
        const report = await this.generateHourlyReport();
        this.logger.info('Hourly report generated', { report });
      } catch (error) {
        this.logger.error('Hourly report generation failed', { error: error.message });
      }
    });
  }

  async generateHourlyReport() {
    const now = new Date();
    const hourAgo = new Date(now.getTime() - 60 * 60 * 1000);
    
    return {
      period: {
        start: hourAgo.toISOString(),
        end: now.toISOString()
      },
      metrics: await this.metrics.getHourlyStats(hourAgo, now),
      patterns: await this.patternAnalyzer.getHourlyPatterns(hourAgo, now),
      authEvents: await this.authAnalyzer.getHourlyStats(hourAgo, now),
      payloadAnalysis: await this.payloadAnalyzer.getHourlyStats(hourAgo, now)
    };
  }

  async start() {
    try {
      // Initialize components
      await this.metrics.initialize();
      await this.payloadAnalyzer.initialize();
      await this.authAnalyzer.initialize();
      await this.patternAnalyzer.initialize();
      await this.taskExecutionAnalyzer.initialize();
      await this.tracingService.initialize();

      // Start server
      this.server = this.app.listen(this.port, () => {
        this.logger.info(`MCP Monitor started on port ${this.port}`);
      });

      // Graceful shutdown
      process.on('SIGTERM', () => this.shutdown());
      process.on('SIGINT', () => this.shutdown());
      
    } catch (error) {
      this.logger.error('Failed to start MCP Monitor', { error: error.message });
      process.exit(1);
    }
  }

  async shutdown() {
    this.logger.info('Shutting down MCP Monitor...');
    
    if (this.server) {
      this.server.close(() => {
        this.logger.info('HTTP server closed');
      });
    }
    
    // Cleanup resources
    await this.metrics.shutdown();
    await this.payloadAnalyzer.shutdown();
    await this.authAnalyzer.shutdown();
    await this.patternAnalyzer.shutdown();
    await this.tracingService.shutdown();
    
    process.exit(0);
  }
}

// Start the service
if (require.main === module) {
  const monitor = new MCPMonitor();
  monitor.start().catch(error => {
    console.error('Failed to start MCP Monitor:', error);
    process.exit(1);
  });
}

module.exports = MCPMonitor;