const { trace, context, SpanStatusCode, SpanKind } = require('@opentelemetry/api');

class TracingService {
  constructor() {
    this.tracer = null;
    this.activeSpans = new Map();
    this.traceBuffer = [];
    this.maxBufferSize = 1000;
  }

  async initialize() {
    try {
      // Initialize OpenTelemetry tracer
      this.tracer = trace.getTracer('mcp-monitor', '1.0.0');
      
      console.log('Tracing service initialized successfully');
    } catch (error) {
      console.error('Failed to initialize tracing service:', error);
      // Continue without tracing if initialization fails
    }
  }

  async recordSpan(event) {
    if (!this.tracer) {
      // Store in buffer if tracer not available
      this.bufferTrace(event);
      return;
    }

    try {
      const spanName = this.generateSpanName(event);
      const span = this.tracer.startSpan(spanName, {
        kind: SpanKind.SERVER,
        attributes: this.extractAttributes(event)
      });

      // Set span context
      if (event.traceId) {
        span.setAttributes({
          'trace.id': event.traceId,
          'span.id': event.spanId || this.generateSpanId()
        });
      }

      // Add event-specific attributes
      this.addEventAttributes(span, event);

      // Set span status based on event
      this.setSpanStatus(span, event);

      // Store active span
      if (event.requestId) {
        this.activeSpans.set(event.requestId, span);
      }

      // End span if it's a complete event
      if (event.type === 'response' || event.completed) {
        this.endSpan(event.requestId || event.traceId, event);
      }

    } catch (error) {
      console.error('Error recording span:', error);
    }
  }

  generateSpanName(event) {
    if (event.method) {
      return `mcp.${event.method}`;
    }
    
    if (event.type) {
      return `mcp.${event.type}`;
    }
    
    return 'mcp.operation';
  }

  extractAttributes(event) {
    const attributes = {
      'service.name': 'mcp-monitor',
      'service.version': '1.0.0',
      'mcp.event.type': event.type || 'unknown',
      'mcp.timestamp': event.timestamp || new Date().toISOString()
    };

    // Add request metadata
    if (event.requestId) attributes['mcp.request.id'] = event.requestId;
    if (event.method) attributes['mcp.method'] = event.method;
    if (event.userAgent) attributes['http.user_agent'] = event.userAgent;
    if (event.clientId) attributes['mcp.client.id'] = event.clientId;
    if (event.ip) attributes['net.peer.ip'] = event.ip;

    return attributes;
  }

  addEventAttributes(span, event) {
    // Add payload information
    if (event.payload) {
      span.setAttributes({
        'mcp.payload.size': JSON.stringify(event.payload).length,
        'mcp.payload.type': typeof event.payload
      });
      
      if (event.payload.method) {
        span.setAttribute('mcp.jsonrpc.method', event.payload.method);
      }
      
      if (event.payload.id) {
        span.setAttribute('mcp.jsonrpc.id', event.payload.id.toString());
      }
    }

    // Add performance metrics
    if (event.duration) {
      span.setAttribute('mcp.duration.ms', event.duration);
    }
    
    if (event.responseTime) {
      span.setAttribute('mcp.response_time.ms', event.responseTime);
    }

    // Add resource information
    if (event.resourceType) {
      span.setAttribute('mcp.resource.type', event.resourceType);
    }
    
    if (event.resourcePath) {
      span.setAttribute('mcp.resource.path', event.resourcePath);
    }

    // Add authentication information
    if (event.authentication) {
      span.setAttributes({
        'mcp.auth.method': event.authentication.method || 'unknown',
        'mcp.auth.success': event.authentication.success || false
      });
    }

    // Add agent information
    if (event.agent) {
      span.setAttributes({
        'mcp.agent.id': event.agent.id || 'unknown',
        'mcp.agent.type': event.agent.type || 'unknown'
      });
    }

    // Add error information
    if (event.error) {
      span.setAttributes({
        'error': true,
        'error.type': event.error.type || event.error.constructor?.name || 'Error',
        'error.message': event.error.message || event.error.toString(),
        'mcp.error.code': event.error.code || 'unknown'
      });
    }

    // Add business context
    if (event.businessContext) {
      for (const [key, value] of Object.entries(event.businessContext)) {
        span.setAttribute(`mcp.business.${key}`, value.toString());
      }
    }
  }

  setSpanStatus(span, event) {
    if (event.error || event.status === 'error') {
      span.setStatus({
        code: SpanStatusCode.ERROR,
        message: event.error?.message || 'Operation failed'
      });
    } else if (event.success === false) {
      span.setStatus({
        code: SpanStatusCode.ERROR,
        message: 'Operation unsuccessful'
      });
    } else {
      span.setStatus({ code: SpanStatusCode.OK });
    }
  }

  endSpan(identifier, event = {}) {
    if (!identifier) return;
    
    const span = this.activeSpans.get(identifier);
    if (span) {
      // Add final attributes
      if (event.finalStatus) {
        span.setAttribute('mcp.final.status', event.finalStatus);
      }
      
      if (event.totalDuration) {
        span.setAttribute('mcp.total.duration.ms', event.totalDuration);
      }

      // Record any final events
      if (event.events) {
        for (const evt of event.events) {
          span.addEvent(evt.name, evt.attributes, evt.timestamp);
        }
      }

      span.end();
      this.activeSpans.delete(identifier);
    }
  }

  bufferTrace(event) {
    if (this.traceBuffer.length >= this.maxBufferSize) {
      this.traceBuffer.shift(); // Remove oldest trace
    }
    
    this.traceBuffer.push({
      ...event,
      bufferedAt: new Date().toISOString()
    });
  }

  async flushBuffer() {
    if (!this.tracer || this.traceBuffer.length === 0) {
      return;
    }

    const traces = [...this.traceBuffer];
    this.traceBuffer = [];

    for (const trace of traces) {
      try {
        await this.recordSpan(trace);
      } catch (error) {
        console.error('Error flushing buffered trace:', error);
      }
    }
  }

  generateSpanId() {
    return Math.random().toString(16).substr(2, 16);
  }

  async createChildSpan(parentSpanId, operation, attributes = {}) {
    if (!this.tracer) return null;

    const parentSpan = this.activeSpans.get(parentSpanId);
    if (!parentSpan) return null;

    const childSpan = this.tracer.startSpan(`mcp.${operation}`, {
      parent: parentSpan,
      kind: SpanKind.INTERNAL,
      attributes: {
        'service.name': 'mcp-monitor',
        'mcp.operation': operation,
        ...attributes
      }
    });

    return childSpan;
  }

  async recordEvent(spanId, eventName, attributes = {}) {
    const span = this.activeSpans.get(spanId);
    if (span) {
      span.addEvent(eventName, {
        timestamp: new Date().toISOString(),
        ...attributes
      });
    }
  }

  async getActiveSpansCount() {
    return this.activeSpans.size;
  }

  async getBufferedTracesCount() {
    return this.traceBuffer.length;
  }

  async getTracingStats() {
    return {
      activeSpans: this.activeSpans.size,
      bufferedTraces: this.traceBuffer.length,
      tracerInitialized: !!this.tracer,
      maxBufferSize: this.maxBufferSize
    };
  }

  async cleanup() {
    // End any remaining active spans
    for (const [id, span] of this.activeSpans.entries()) {
      try {
        span.setStatus({
          code: SpanStatusCode.ERROR,
          message: 'Span cleanup - service shutdown'
        });
        span.end();
      } catch (error) {
        console.error('Error cleaning up span:', error);
      }
    }
    
    this.activeSpans.clear();
    
    // Clear old buffered traces (keep only last 100)
    if (this.traceBuffer.length > 100) {
      this.traceBuffer = this.traceBuffer.slice(-100);
    }
  }

  async shutdown() {
    await this.cleanup();
    this.traceBuffer = [];
    
    if (this.tracer) {
      // Flush any remaining traces
      try {
        await this.flushBuffer();
      } catch (error) {
        console.error('Error flushing traces during shutdown:', error);
      }
    }
  }
}

module.exports = TracingService;