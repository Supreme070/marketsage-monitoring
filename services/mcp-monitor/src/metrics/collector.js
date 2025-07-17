const promClient = require('prom-client');

class MetricsCollector {
  constructor() {
    // Create a Registry which registers the metrics
    this.register = new promClient.Registry();
    
    // Add a default label which is added to all metrics
    this.register.setDefaultLabels({
      service: 'mcp-monitor'
    });

    // Enable the collection of default metrics
    promClient.collectDefaultMetrics({ register: this.register });

    this.initializeMetrics();
  }

  initializeMetrics() {
    // 1. Request/Response Patterns - JSON-RPC call frequency and success rates
    this.jsonRpcRequestsTotal = new promClient.Counter({
      name: 'mcp_jsonrpc_requests_total',
      help: 'Total number of JSON-RPC requests',
      labelNames: ['method', 'status', 'user_agent', 'client_id'],
      registers: [this.register]
    });

    this.jsonRpcRequestDuration = new promClient.Histogram({
      name: 'mcp_jsonrpc_request_duration_seconds',
      help: 'Duration of JSON-RPC requests in seconds',
      labelNames: ['method', 'status'],
      buckets: [0.001, 0.01, 0.1, 0.5, 1, 2, 5, 10],
      registers: [this.register]
    });

    this.jsonRpcErrorsTotal = new promClient.Counter({
      name: 'mcp_jsonrpc_errors_total',
      help: 'Total number of JSON-RPC errors',
      labelNames: ['method', 'error_code', 'error_type'],
      registers: [this.register]
    });

    // 2. Payload Analysis - Deep visibility into MCP protocol messages
    this.payloadSizeBytes = new promClient.Histogram({
      name: 'mcp_payload_size_bytes',
      help: 'Size of MCP payloads in bytes',
      labelNames: ['direction', 'method', 'content_type'],
      buckets: [100, 1000, 10000, 100000, 1000000, 10000000],
      registers: [this.register]
    });

    this.payloadComplexity = new promClient.Histogram({
      name: 'mcp_payload_complexity_score',
      help: 'Complexity score of MCP payloads (nested objects, arrays)',
      labelNames: ['method', 'payload_type'],
      buckets: [1, 5, 10, 25, 50, 100, 200],
      registers: [this.register]
    });

    this.sensitiveDataDetected = new promClient.Counter({
      name: 'mcp_sensitive_data_detected_total',
      help: 'Total number of sensitive data detections in payloads',
      labelNames: ['data_type', 'method', 'severity'],
      registers: [this.register]
    });

    // 3. User/Agent Identification - Track which AI agents are accessing what resources
    this.uniqueAgentsGauge = new promClient.Gauge({
      name: 'mcp_unique_agents_active',
      help: 'Number of unique AI agents currently active',
      labelNames: ['time_window'],
      registers: [this.register]
    });

    this.agentResourceAccess = new promClient.Counter({
      name: 'mcp_agent_resource_access_total',
      help: 'Total resource access attempts by AI agents',
      labelNames: ['agent_id', 'agent_type', 'resource_type', 'access_result'],
      registers: [this.register]
    });

    this.agentSessionDuration = new promClient.Histogram({
      name: 'mcp_agent_session_duration_seconds',
      help: 'Duration of AI agent sessions in seconds',
      labelNames: ['agent_id', 'agent_type'],
      buckets: [60, 300, 900, 1800, 3600, 7200, 14400],
      registers: [this.register]
    });

    // 4. Performance Metrics - Latency, throughput, error rates
    this.throughputRate = new promClient.Gauge({
      name: 'mcp_throughput_requests_per_second',
      help: 'Current throughput in requests per second',
      labelNames: ['method', 'time_window'],
      registers: [this.register]
    });

    this.concurrentConnections = new promClient.Gauge({
      name: 'mcp_concurrent_connections',
      help: 'Number of concurrent MCP connections',
      registers: [this.register]
    });

    this.queueDepth = new promClient.Gauge({
      name: 'mcp_queue_depth',
      help: 'Current depth of MCP processing queues',
      labelNames: ['queue_type'],
      registers: [this.register]
    });

    // 5. Resource Access Patterns - What data is being requested and by whom
    this.resourceAccessFrequency = new promClient.Counter({
      name: 'mcp_resource_access_frequency_total',
      help: 'Frequency of resource access by type',
      labelNames: ['resource_type', 'resource_path', 'access_method', 'requester_type'],
      registers: [this.register]
    });

    this.dataVolumeTransferred = new promClient.Counter({
      name: 'mcp_data_volume_transferred_bytes_total',
      help: 'Total volume of data transferred through MCP',
      labelNames: ['direction', 'data_type', 'compression'],
      registers: [this.register]
    });

    this.resourceCacheHitRate = new promClient.Gauge({
      name: 'mcp_resource_cache_hit_rate',
      help: 'Cache hit rate for resource requests',
      labelNames: ['resource_type', 'cache_layer'],
      registers: [this.register]
    });

    // 6. Authorization Events - Token usage and access control
    this.authenticationAttempts = new promClient.Counter({
      name: 'mcp_authentication_attempts_total',
      help: 'Total authentication attempts',
      labelNames: ['method', 'result', 'client_type'],
      registers: [this.register]
    });

    this.authorizationChecks = new promClient.Counter({
      name: 'mcp_authorization_checks_total',
      help: 'Total authorization checks performed',
      labelNames: ['resource_type', 'permission_type', 'result'],
      registers: [this.register]
    });

    this.tokenUsage = new promClient.Counter({
      name: 'mcp_token_usage_total',
      help: 'Total token usage events',
      labelNames: ['token_type', 'operation', 'scope'],
      registers: [this.register]
    });

    this.suspiciousActivity = new promClient.Counter({
      name: 'mcp_suspicious_activity_total',
      help: 'Total suspicious activity detections',
      labelNames: ['activity_type', 'severity', 'source'],
      registers: [this.register]
    });

    // Task execution metrics
    this.taskExecutionTotal = new promClient.Counter({
      name: 'mcp_task_execution_total',
      help: 'Total number of task executions',
      labelNames: ['task_type', 'status', 'agent_id'],
      registers: [this.register]
    });

    this.taskExecutionDuration = new promClient.Histogram({
      name: 'mcp_task_execution_duration_seconds',
      help: 'Duration of task executions in seconds',
      labelNames: ['task_type', 'status'],
      buckets: [0.1, 0.5, 1, 5, 10, 30, 60, 300, 600, 1800],
      registers: [this.register]
    });

    this.activeTasksGauge = new promClient.Gauge({
      name: 'mcp_active_tasks',
      help: 'Number of currently active tasks',
      labelNames: ['task_type', 'agent_id'],
      registers: [this.register]
    });

    this.taskRetryTotal = new promClient.Counter({
      name: 'mcp_task_retry_total',
      help: 'Total number of task retries',
      labelNames: ['task_type', 'retry_reason'],
      registers: [this.register]
    });

    this.taskStepsTotal = new promClient.Counter({
      name: 'mcp_task_steps_total',
      help: 'Total number of task steps executed',
      labelNames: ['task_type', 'step_status'],
      registers: [this.register]
    });

    this.taskQueueDepth = new promClient.Gauge({
      name: 'mcp_task_queue_depth',
      help: 'Current depth of task execution queues',
      labelNames: ['queue_type', 'agent_id'],
      registers: [this.register]
    });

    this.taskPerformanceScore = new promClient.Histogram({
      name: 'mcp_task_performance_score',
      help: 'Task performance scores (0-1)',
      labelNames: ['task_type', 'performance_dimension'],
      buckets: [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0],
      registers: [this.register]
    });

    this.taskSuccessRate = new promClient.Gauge({
      name: 'mcp_task_success_rate',
      help: 'Success rate of tasks by type',
      labelNames: ['task_type', 'time_window'],
      registers: [this.register]
    });

    this.taskTimeoutTotal = new promClient.Counter({
      name: 'mcp_task_timeout_total',
      help: 'Total number of task timeouts',
      labelNames: ['task_type', 'timeout_reason'],
      registers: [this.register]
    });

    this.taskProgressGauge = new promClient.Gauge({
      name: 'mcp_task_progress_percent',
      help: 'Current progress of active tasks',
      labelNames: ['task_id', 'task_type'],
      registers: [this.register]
    });

    // Internal monitoring metrics
    this.eventsProcessed = new promClient.Counter({
      name: 'mcp_monitor_events_processed_total',
      help: 'Total events processed by MCP monitor',
      labelNames: ['event_type', 'status'],
      registers: [this.register]
    });

    this.processingErrors = new promClient.Counter({
      name: 'mcp_monitor_processing_errors_total',
      help: 'Total processing errors in MCP monitor',
      labelNames: ['error_type', 'component'],
      registers: [this.register]
    });

    // Time-based aggregations
    this.hourlyStats = new Map();
    this.dailyStats = new Map();
  }

  recordEvent(eventType, event) {
    const labels = this.extractLabels(event);
    
    try {
      switch (eventType) {
        case 'jsonrpc_request':
          this.recordJsonRpcRequest(event, labels);
          break;
        case 'payload_analysis':
          this.recordPayloadAnalysis(event, labels);
          break;
        case 'agent_activity':
          this.recordAgentActivity(event, labels);
          break;
        case 'resource_access':
          this.recordResourceAccess(event, labels);
          break;
        case 'auth_event':
          this.recordAuthEvent(event, labels);
          break;
        case 'task_start':
          this.recordTaskStart(event, labels);
          break;
        case 'task_progress':
          this.recordTaskProgress(event, labels);
          break;
        case 'task_completion':
          this.recordTaskCompletion(event, labels);
          break;
        case 'task_retry':
          this.recordTaskRetry(event, labels);
          break;
        default:
          this.eventsProcessed.inc({ event_type: eventType, status: 'unknown' });
      }
      
      this.eventsProcessed.inc({ event_type: eventType, status: 'success' });
      
    } catch (error) {
      this.processingErrors.inc({ 
        error_type: error.constructor.name, 
        component: 'metrics_collector' 
      });
      throw error;
    }
  }

  recordJsonRpcRequest(event, labels) {
    const method = event.method || 'unknown';
    const status = event.success ? 'success' : 'error';
    const duration = event.duration || 0;

    this.jsonRpcRequestsTotal.inc({
      method,
      status,
      user_agent: labels.userAgent,
      client_id: labels.clientId
    });

    this.jsonRpcRequestDuration.observe({ method, status }, duration / 1000);

    if (!event.success && event.error) {
      this.jsonRpcErrorsTotal.inc({
        method,
        error_code: event.error.code || 'unknown',
        error_type: event.error.type || 'unknown'
      });
    }
  }

  recordPayloadAnalysis(event, labels) {
    if (event.payload) {
      const payloadSize = JSON.stringify(event.payload).length;
      const method = event.method || 'unknown';
      
      this.payloadSizeBytes.observe({
        direction: event.direction || 'unknown',
        method,
        content_type: event.contentType || 'application/json'
      }, payloadSize);

      if (event.complexity) {
        this.payloadComplexity.observe({
          method,
          payload_type: event.payloadType || 'unknown'
        }, event.complexity);
      }

      if (event.sensitiveData) {
        event.sensitiveData.forEach(detection => {
          this.sensitiveDataDetected.inc({
            data_type: detection.type,
            method,
            severity: detection.severity
          });
        });
      }
    }
  }

  recordAgentActivity(event, labels) {
    if (event.agent) {
      this.agentResourceAccess.inc({
        agent_id: event.agent.id || 'unknown',
        agent_type: event.agent.type || 'unknown',
        resource_type: event.resourceType || 'unknown',
        access_result: event.success ? 'success' : 'failed'
      });

      if (event.sessionDuration) {
        this.agentSessionDuration.observe({
          agent_id: event.agent.id || 'unknown',
          agent_type: event.agent.type || 'unknown'
        }, event.sessionDuration);
      }
    }
  }

  recordResourceAccess(event, labels) {
    this.resourceAccessFrequency.inc({
      resource_type: event.resourceType || 'unknown',
      resource_path: event.resourcePath || 'unknown',
      access_method: event.method || 'unknown',
      requester_type: event.requesterType || 'unknown'
    });

    if (event.dataSize) {
      this.dataVolumeTransferred.inc({
        direction: event.direction || 'unknown',
        data_type: event.dataType || 'unknown',
        compression: event.compression || 'none'
      }, event.dataSize);
    }

    if (event.cacheHit !== undefined) {
      this.resourceCacheHitRate.set({
        resource_type: event.resourceType || 'unknown',
        cache_layer: event.cacheLayer || 'unknown'
      }, event.cacheHit ? 1 : 0);
    }
  }

  recordAuthEvent(event, labels) {
    if (event.authentication) {
      this.authenticationAttempts.inc({
        method: event.authentication.method || 'unknown',
        result: event.authentication.success ? 'success' : 'failed',
        client_type: event.authentication.clientType || 'unknown'
      });
    }

    if (event.authorization) {
      this.authorizationChecks.inc({
        resource_type: event.authorization.resourceType || 'unknown',
        permission_type: event.authorization.permissionType || 'unknown',
        result: event.authorization.granted ? 'granted' : 'denied'
      });
    }

    if (event.token) {
      this.tokenUsage.inc({
        token_type: event.token.type || 'unknown',
        operation: event.token.operation || 'unknown',
        scope: event.token.scope || 'unknown'
      });
    }

    if (event.suspicious) {
      this.suspiciousActivity.inc({
        activity_type: event.suspicious.type || 'unknown',
        severity: event.suspicious.severity || 'unknown',
        source: event.suspicious.source || 'unknown'
      });
    }
  }

  recordTaskStart(event, labels) {
    const taskType = event.taskType || 'unknown';
    const agentId = event.agentId || 'unknown';

    this.taskExecutionTotal.inc({
      task_type: taskType,
      status: 'started',
      agent_id: agentId
    });

    this.activeTasksGauge.inc({
      task_type: taskType,
      agent_id: agentId
    });

    if (event.queueDepth !== undefined) {
      this.taskQueueDepth.set({
        queue_type: event.queueType || 'default',
        agent_id: agentId
      }, event.queueDepth);
    }
  }

  recordTaskProgress(event, labels) {
    const taskType = event.taskType || 'unknown';
    const taskId = event.taskId || 'unknown';

    if (event.progress !== undefined) {
      this.taskProgressGauge.set({
        task_id: taskId,
        task_type: taskType
      }, event.progress);
    }

    if (event.step) {
      this.taskStepsTotal.inc({
        task_type: taskType,
        step_status: event.stepStatus || 'completed'
      });
    }
  }

  recordTaskCompletion(event, labels) {
    const taskType = event.taskType || 'unknown';
    const agentId = event.agentId || 'unknown';
    const status = event.status || 'completed';
    const duration = (event.duration || 0) / 1000; // Convert to seconds

    this.taskExecutionTotal.inc({
      task_type: taskType,
      status: status,
      agent_id: agentId
    });

    this.taskExecutionDuration.observe({
      task_type: taskType,
      status: status
    }, duration);

    this.activeTasksGauge.dec({
      task_type: taskType,
      agent_id: agentId
    });

    // Clear progress gauge
    this.taskProgressGauge.remove({
      task_id: event.taskId,
      task_type: taskType
    });

    // Record performance metrics
    if (event.performance) {
      const perf = event.performance;
      this.taskPerformanceScore.observe({
        task_type: taskType,
        performance_dimension: 'efficiency'
      }, perf.efficiency || 0);

      this.taskPerformanceScore.observe({
        task_type: taskType,
        performance_dimension: 'reliability'
      }, perf.reliability || 0);

      this.taskPerformanceScore.observe({
        task_type: taskType,
        performance_dimension: 'speed'
      }, perf.speed || 0);

      this.taskPerformanceScore.observe({
        task_type: taskType,
        performance_dimension: 'overall'
      }, perf.overall || 0);
    }

    // Record timeouts
    if (status === 'timeout') {
      this.taskTimeoutTotal.inc({
        task_type: taskType,
        timeout_reason: event.timeoutReason || 'unknown'
      });
    }
  }

  recordTaskRetry(event, labels) {
    const taskType = event.taskType || 'unknown';
    const retryReason = event.retryReason || 'unknown';

    this.taskRetryTotal.inc({
      task_type: taskType,
      retry_reason: retryReason
    });
  }

  extractLabels(event) {
    return {
      userAgent: event.userAgent || 'unknown',
      clientId: event.clientId || 'unknown',
      timestamp: new Date(event.timestamp || Date.now())
    };
  }

  async getSummary() {
    const metrics = await this.register.getMetricsAsJSON();
    
    return {
      timestamp: new Date().toISOString(),
      totalMetrics: metrics.length,
      categories: {
        requests: metrics.filter(m => m.name.includes('request')).length,
        payload: metrics.filter(m => m.name.includes('payload')).length,
        agent: metrics.filter(m => m.name.includes('agent')).length,
        resource: metrics.filter(m => m.name.includes('resource')).length,
        auth: metrics.filter(m => m.name.includes('auth')).length
      },
      health: 'healthy'
    };
  }

  async getHourlyStats(startTime, endTime) {
    // Implementation would aggregate metrics for the time window
    // This is a simplified version
    return {
      period: {
        start: startTime.toISOString(),
        end: endTime.toISOString()
      },
      summary: await this.getSummary()
    };
  }

  async initialize() {
    // Register all metrics with Prometheus
    promClient.register.registerMetric(this.jsonRpcRequestsTotal);
    promClient.register.registerMetric(this.jsonRpcRequestDuration);
    promClient.register.registerMetric(this.jsonRpcErrorsTotal);
    promClient.register.registerMetric(this.payloadSizeBytes);
    promClient.register.registerMetric(this.payloadComplexity);
    promClient.register.registerMetric(this.sensitiveDataDetected);
    promClient.register.registerMetric(this.uniqueAgentsGauge);
    promClient.register.registerMetric(this.agentResourceAccess);
    promClient.register.registerMetric(this.agentSessionDuration);
    promClient.register.registerMetric(this.throughputRate);
    promClient.register.registerMetric(this.concurrentConnections);
    promClient.register.registerMetric(this.queueDepth);
    promClient.register.registerMetric(this.resourceAccessFrequency);
    promClient.register.registerMetric(this.dataVolumeTransferred);
    promClient.register.registerMetric(this.resourceCacheHitRate);
    promClient.register.registerMetric(this.authenticationAttempts);
    promClient.register.registerMetric(this.authorizationChecks);
    promClient.register.registerMetric(this.tokenUsage);
    promClient.register.registerMetric(this.suspiciousActivity);
    promClient.register.registerMetric(this.eventsProcessed);
    promClient.register.registerMetric(this.processingErrors);
  }

  async cleanup() {
    // Clean up old hourly and daily stats
    const now = Date.now();
    const hourAgo = now - (60 * 60 * 1000);
    const dayAgo = now - (24 * 60 * 60 * 1000);

    // Remove old hourly stats (keep last 24 hours)
    for (const [timestamp, stats] of this.hourlyStats.entries()) {
      if (timestamp < hourAgo) {
        this.hourlyStats.delete(timestamp);
      }
    }

    // Remove old daily stats (keep last 30 days)
    for (const [timestamp, stats] of this.dailyStats.entries()) {
      if (timestamp < dayAgo) {
        this.dailyStats.delete(timestamp);
      }
    }
  }

  async shutdown() {
    // Clear all metrics
    this.register.clear();
  }
}

module.exports = MetricsCollector;