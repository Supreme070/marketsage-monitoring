# NestJS Backend Monitoring Guide

## Overview

The NestJS backend monitoring has been successfully integrated into the MarketSage monitoring stack. This guide covers the monitoring setup, dashboards, alerts, and best practices.

## Architecture

```
NestJS Backend (Port 3006)
     ↓
Metrics Endpoint (/api/v2/metrics)
     ↓
Prometheus Scraper
     ↓
Grafana Dashboard + Alerting
```

## Metrics Collection

### 1. Prometheus Configuration
The NestJS backend is configured as a scrape target in Prometheus:

```yaml
- job_name: 'marketsage-nestjs'
  static_configs:
    - targets: ['host.docker.internal:3006']
  metrics_path: '/api/v2/metrics'
  scrape_interval: 15s
```

### 2. Available Metrics

#### HTTP Metrics
- `nestjs_http_requests_total` - Total HTTP requests by method, route, and status
- `nestjs_http_request_duration_seconds` - Request duration histogram

#### Authentication Metrics
- `nestjs_auth_attempts_total` - Authentication attempts by type and status
- `nestjs_auth_duration_seconds` - Authentication operation duration
- `nestjs_jwt_tokens_issued_total` - Total JWT tokens issued
- `nestjs_jwt_tokens_validated_total` - JWT validation attempts by status

#### System Metrics
- `nestjs_process_cpu_seconds_total` - CPU usage
- `nestjs_nodejs_heap_size_total_bytes` - Total heap size
- `nestjs_nodejs_heap_size_used_bytes` - Used heap size
- `nestjs_nodejs_eventloop_lag_seconds` - Event loop lag
- `nestjs_nodejs_gc_duration_seconds` - Garbage collection duration

#### Business Metrics
- `nestjs_users_created_total` - Total users created
- `nestjs_active_users` - Currently active users
- `nestjs_db_connections_active` - Active database connections
- `nestjs_errors_total` - Total errors by type and code

## Grafana Dashboard

### Accessing the Dashboard
1. Open Grafana: http://localhost:3000
2. Login with admin/admin
3. Navigate to Dashboards → NestJS Backend Monitoring

### Dashboard Panels

#### Overview Row
- **Service Status**: Shows if NestJS is up/down
- **Request Rate**: Real-time request rate graph
- **P95 Latency**: 95th percentile response time
- **Error Rate**: Current error rate
- **CPU Usage**: Current CPU utilization

#### HTTP Metrics Row
- **Request Duration Percentiles**: P50, P95, P99 latencies
- **Response Status Codes**: Distribution of HTTP status codes

#### Authentication & Security Row
- **Authentication Attempts**: Success/failure rates by auth type
- **JWT Token Operations**: Token issuance and validation metrics

#### System Resources Row
- **CPU Usage**: CPU utilization over time
- **Memory Usage**: Heap and external memory usage

#### Event Loop & Performance Row
- **Event Loop Lag**: Current and P99 event loop lag
- **Garbage Collection Duration**: GC performance metrics

#### Business Metrics Row
- **User Metrics**: User creation rate and active users

## Alerting Rules

### Critical Alerts
1. **NestJSDown**: Service is down for >2 minutes
2. **NestJSNoDatabaseConnections**: No active DB connections

### Warning Alerts
1. **NestJSHighErrorRate**: Error rate >0.05/sec
2. **NestJSHighResponseTime**: P95 latency >500ms
3. **NestJSHighAuthFailures**: Auth failure rate >0.1/sec
4. **NestJSHighMemoryUsage**: Heap usage >90%
5. **NestJSHighEventLoopLag**: Event loop lag >100ms
6. **NestJSHighJWTFailures**: JWT validation failures >0.1/sec

## Using Metrics in Code

### Recording Custom Metrics

```typescript
// In your NestJS service
constructor(private metricsService: MetricsService) {}

// Record HTTP request
this.metricsService.recordHttpRequest('POST', '/api/users', 201, 0.025);

// Record auth attempt
this.metricsService.recordAuthAttempt('login', 'success', 0.150);

// Record business event
this.metricsService.recordUserCreated();

// Update gauge
this.metricsService.updateActiveUsers(150);
```

### Adding New Metrics

1. Add metric definition in `metrics.service.ts`
2. Create recording method
3. Call from relevant service/controller
4. Update Grafana dashboard if needed

## Troubleshooting

### Metrics Not Appearing
1. Check NestJS is running: `curl http://localhost:3006/api/v2/health`
2. Verify metrics endpoint: `curl http://localhost:3006/api/v2/metrics`
3. Check Prometheus targets: http://localhost:9090/targets
4. Verify scrape config in Prometheus

### Dashboard Not Loading
1. Ensure Grafana is running: `docker-compose ps grafana`
2. Check datasource configuration
3. Verify Prometheus is collecting data
4. Re-import dashboard if needed

### Alerts Not Firing
1. Check alert rules loaded: http://localhost:9090/rules
2. Verify alertmanager is running
3. Check alert conditions are met
4. Review alertmanager configuration

## Best Practices

### 1. Metric Naming
- Use consistent prefixes: `nestjs_`
- Follow Prometheus conventions
- Use labels for cardinality

### 2. Performance
- Avoid high-cardinality labels
- Use histograms for latencies
- Cache metric calculations

### 3. Dashboard Design
- Group related metrics
- Use appropriate visualizations
- Set meaningful thresholds

### 4. Alerting
- Avoid alert fatigue
- Set appropriate thresholds
- Include runbooks in annotations

## Integration with CI/CD

### Health Checks
```bash
# Check service health
curl -f http://localhost:3006/api/v2/health

# Verify metrics endpoint
curl -s http://localhost:3006/api/v2/metrics | grep nestjs_http_requests_total
```

### Load Testing
```bash
# Generate load for testing
ab -n 1000 -c 10 http://localhost:3000/api/v2/health
```

## Next Steps

1. **Add distributed tracing**: Integrate with Tempo
2. **Custom business dashboards**: Create role-specific views
3. **SLO monitoring**: Define and track SLIs/SLOs
4. **Capacity planning**: Use metrics for scaling decisions