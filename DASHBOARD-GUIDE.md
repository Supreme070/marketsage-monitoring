# 📊 MarketSage Monitoring Dashboard Guide

This comprehensive guide explains all three monitoring dashboards, what each card displays, and how to interpret the data for effective system monitoring.

## 🏠 Dashboard Overview

MarketSage monitoring provides three specialized dashboards:

1. **System Overview** - High-level system health and performance
2. **Performance Metrics** - Detailed application and database performance  
3. **Comprehensive Logs** - Log analysis with metrics overview

**Access URLs:**
- Grafana: http://localhost:3000 (admin/admin)
- System Overview: http://localhost:3000/d/679fa408-4a27-4a42-a8de-889721340151
- Performance Metrics: http://localhost:3000/d/43fdff3f-0b84-4eeb-ae47-de7a936c55f8
- Comprehensive Logs: http://localhost:3000/d/5d56161d-1420-4d6e-9896-df86273c9bcd

---

## 📈 Dashboard 1: System Overview

**Purpose**: Quick health check and system-level monitoring
**Best for**: Daily operations, alerting, system administrators

### 🎛️ Card 1: System Load (Gauge)
- **What it shows**: Current 1-minute load average
- **Data source**: `node_load1` from node-exporter
- **Interpretation**:
  - 🟢 **Green (0-2.0)**: System healthy, low load
  - 🟡 **Yellow (2.0-4.0)**: Moderate load, monitor closely  
  - 🔴 **Red (4.0+)**: High load, investigate immediately
- **Action items**: 
  - Red: Check CPU-intensive processes, scale resources
  - Yellow: Monitor trends, prepare for scaling

### 🧠 Card 2: Memory Usage (Gauge)  
- **What it shows**: Percentage of system memory in use
- **Data source**: `(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100`
- **Interpretation**:
  - 🟢 **Green (0-70%)**: Healthy memory usage
  - 🟡 **Yellow (70-85%)**: Memory pressure building
  - 🔴 **Red (85%+)**: Critical memory usage, risk of OOM
- **Action items**:
  - Red: Restart heavy services, add memory, check for leaks
  - Yellow: Monitor memory trends, prepare for optimization

### 🏥 Card 3: Service Health Status (Pie Chart)
- **What it shows**: Up/down status of all monitored services
- **Data source**: `up` metric from Prometheus targets
- **Services monitored**: 
  - MarketSage App, Database, Redis, Prometheus, Grafana, Loki, Alertmanager, Node Exporter, cAdvisor, Alloy
- **Interpretation**:
  - 🟢 **Green slice**: Service operational
  - 🔴 **Red slice**: Service down or unreachable
- **Action items**: 
  - Red services: Check logs, restart services, verify network connectivity

### 💻 Card 4: Container CPU Usage (Time Series)
- **What it shows**: CPU usage trends for MarketSage containers over time
- **Data source**: `rate(container_cpu_usage_seconds_total{id=~"/docker/[container-ids]"}[5m]) * 100`
- **Containers tracked**: MarketSage Web, Database, Redis
- **Interpretation**:
  - **Normal**: 0-30% steady usage
  - **Concerning**: Sustained 50%+ usage
  - **Critical**: 80%+ usage or sudden spikes
- **Action items**: 
  - Spikes: Check application logs, database queries
  - Sustained high: Scale containers, optimize code

---

## ⚡ Dashboard 2: Performance Metrics

**Purpose**: Deep dive into application and database performance
**Best for**: Performance tuning, capacity planning, developers

### 🗃️ Card 1: Database Query Performance (Time Series)
- **What it shows**: Rate of database rows fetched and returned per second
- **Data source**: 
  - `rate(pg_stat_database_tup_fetched{datname="marketsage"}[5m])`
  - `rate(pg_stat_database_tup_returned{datname="marketsage"}[5m])`
- **Interpretation**:
  - **Low rates**: Light database usage
  - **High spikes**: Heavy query load, possible inefficient queries
  - **Fetched vs Returned**: Large difference indicates data filtering
- **Action items**: 
  - High spikes: Analyze slow queries, add indexes, optimize queries

### ⚡ Card 2: Redis Operations Rate (Stat Panel)
- **What it shows**: Redis commands processed per second
- **Data source**: `rate(redis_commands_processed_total[5m])`
- **Thresholds**:
  - 🟢 **Green (0-100 ops/sec)**: Normal cache usage
  - 🟡 **Yellow (100-1000 ops/sec)**: High cache activity
  - 🔴 **Red (1000+ ops/sec)**: Very heavy cache load
- **Action items**: 
  - Red: Check cache hit rates, optimize queries, scale Redis

### 👥 Card 3: Redis Connected Clients (Gauge)
- **What it shows**: Number of active Redis connections
- **Data source**: `redis_connected_clients`
- **Thresholds**:
  - 🟢 **Green (0-50)**: Normal connection pool
  - 🟡 **Yellow (50-80)**: High connection usage
  - 🔴 **Red (80+)**: Connection pool exhaustion risk
- **Action items**: 
  - Red: Check for connection leaks, optimize connection pooling

### 📊 Card 4: Database Transaction Rate (Bar Chart) 
- **What it shows**: Database commits vs rollbacks per second
- **Data source**: 
  - `rate(pg_stat_database_xact_commit[5m])` (Commits)
  - `rate(pg_stat_database_xact_rollback[5m])` (Rollbacks)
- **Interpretation**:
  - **High commits**: Active database writes
  - **High rollbacks**: Application errors, failed transactions
  - **Ratio**: Rollbacks should be <5% of commits
- **Action items**: 
  - High rollbacks: Check application logs, fix transaction logic

### 🥧 Card 5: Memory Usage Comparison (Pie Chart)
- **What it shows**: Memory distribution between Redis and PostgreSQL
- **Data source**: 
  - `redis_memory_used_bytes` (Redis Memory)
  - `pg_database_size_bytes{datname="marketsage"}` (Database Size)
- **Interpretation**:
  - **Balanced**: Both services using appropriate memory
  - **Redis dominant**: Heavy caching, good performance
  - **PostgreSQL dominant**: Large dataset, consider optimization
- **Action items**: 
  - Imbalanced: Tune cache sizes, optimize data storage

### 🌡️ Card 6: Container CPU Usage Heatmap
- **What it shows**: CPU usage patterns across time with color intensity
- **Data source**: `rate(container_cpu_usage_seconds_total{id=~"/docker/[ids]"}[5m]) * 100`
- **Colors**:
  - **Cool (Blue/Green)**: Low CPU usage
  - **Warm (Yellow/Orange)**: Moderate CPU usage  
  - **Hot (Red)**: High CPU usage
- **Interpretation**:
  - **Patterns**: Look for daily/hourly usage cycles
  - **Hot spots**: Identify peak usage times
  - **Anomalies**: Unusual spikes or sustained high usage
- **Action items**: 
  - Hot spots: Plan scaling during peak times
  - Anomalies: Investigate root causes

---

## 📋 Dashboard 3: Comprehensive Logs

**Purpose**: Log analysis and system health monitoring
**Best for**: Troubleshooting, debugging, system health verification

### 📊 Metrics Overview (Top Row)

#### 🎯 Card 1: Loki Status (Stat Panel)
- **What it shows**: Loki log aggregation service health
- **Data source**: `loki_build_info` 
- **Interpretation**:
  - **1**: Loki running and operational
  - **0**: Loki down or unreachable
- **Action items**: 
  - 0: Restart Loki, check logs, verify configuration

#### 🏷️ Card 2: Container Log Sources (Pie Chart)
- **What it shows**: Distribution of monitored services
- **Data source**: `count by (job) (up)`
- **Services**: All Prometheus targets (monitoring stack + applications)
- **Interpretation**: Visual representation of monitoring coverage
- **Action items**: Ensure all expected services are represented

#### ✅ Card 3: Monitoring Health (Stat Panel)
- **What it shows**: Number of healthy monitoring services
- **Data source**: `count(up == 1)`
- **Thresholds**:
  - 🔴 **Red (0-5)**: Many services down
  - 🟡 **Yellow (5-8)**: Some services down  
  - 🟢 **Green (8+)**: Most services healthy
- **Action items**: 
  - <8: Investigate down services, check network connectivity

### 📝 Log Panels (Bottom Section)

#### 📱 Card 4: Application Logs
- **What it shows**: General application logs from all containers
- **Data source**: `{service_name="unknown_service"}`
- **Use cases**: 
  - Application startup/shutdown events
  - General application behavior
  - Error tracking across services

#### 🐳 Card 5: MarketSage Container Logs  
- **What it shows**: Logs specifically from MarketSage containers
- **Data source**: `{service_name="unknown_service"} |~ "marketsage"`
- **Use cases**:
  - MarketSage application debugging
  - Performance monitoring
  - Business logic issues

#### ❌ Card 6: Error Logs
- **What it shows**: All logs containing error indicators
- **Data source**: `{service_name="unknown_service"} |~ "(?i)error|exception|fail"`
- **Use cases**:
  - Quick error identification
  - System health assessment
  - Troubleshooting guidance

#### 🗄️ Card 7: Database Connection Logs
- **What it shows**: Database and Redis connection events
- **Data source**: `{service_name="unknown_service"} |~ "(?i)postgres|redis|database|connection"`
- **Use cases**:
  - Connection pool monitoring
  - Database performance issues
  - Cache connectivity problems

#### 🌐 Card 8: HTTP/Access Logs
- **What it shows**: Web server and API request logs
- **Data source**: `{service_name="unknown_service"} |~ "(?i)GET|POST|PUT|DELETE|HTTP|access|request"`
- **Use cases**:
  - API usage monitoring
  - Request debugging
  - Traffic pattern analysis

#### 🔧 Card 9: Monitoring Stack Logs
- **What it shows**: Logs from Prometheus, Grafana, Loki, Alertmanager
- **Data source**: `{service_name="unknown_service"} |~ "(?i)prometheus|grafana|loki|alertmanager"`
- **Use cases**:
  - Monitoring system health
  - Configuration issues
  - Performance optimization

#### ⚠️ Card 10: Warning Logs
- **What it shows**: Warning messages and performance alerts
- **Data source**: `{service_name="unknown_service"} |~ "(?i)warn|warning|slow|timeout"`
- **Use cases**:
  - Proactive issue detection
  - Performance degradation alerts
  - System optimization opportunities

#### 📜 Card 11: All Recent Logs
- **What it shows**: Complete log stream for comprehensive debugging
- **Data source**: `{service_name="unknown_service"}`
- **Use cases**:
  - Full context debugging
  - Timeline reconstruction
  - Comprehensive system analysis

---

## 🚨 Alert Interpretation

### 🔴 Critical Alerts
- **MarketSage Down**: Application unreachable
- **High Memory Usage**: >85% system memory
- **Database/Redis Down**: Core services offline
- **Container Memory**: >90% container memory

### 🟡 Warning Alerts  
- **High System Load**: >2.0 load average
- **High Container CPU**: >80% CPU usage
- **High Connection Usage**: >80% Redis connections
- **Memory Pressure**: >70% system memory

### ℹ️ Info Alerts
- **Traffic Pattern Changes**: >50% change from yesterday
- **High Log Volume**: Unusual logging activity

---

## 📋 Daily Monitoring Checklist

### ✅ Morning Health Check
1. Check **System Overview** → All gauges green?
2. Review **Service Health** → All services up?
3. Scan **Error Logs** → Any overnight issues?
4. Check **Monitoring Health** → Full monitoring coverage?

### ✅ Performance Review
1. **Database Query Performance** → Reasonable query rates?
2. **Redis Operations** → Cache performing well?
3. **Container CPU** → No sustained high usage?
4. **Memory Usage** → Staying within limits?

### ✅ Troubleshooting Workflow
1. Start with **System Overview** for quick health assessment
2. Drill down to **Performance Metrics** for specific issues
3. Use **Comprehensive Logs** for detailed investigation
4. Check specific log panels based on error type

---

## 🎯 Key Performance Indicators (KPIs)

### 🟢 Healthy System
- System Load: <2.0
- Memory Usage: <70%
- All Services: Up (10/10)
- Database Transactions: >95% commits
- Error Logs: Minimal/expected errors only

### 🟡 Monitor Closely  
- System Load: 2.0-4.0
- Memory Usage: 70-85%
- Services: 8-9/10 up
- Redis Connections: >50
- Warning Logs: Increasing frequency

### 🔴 Take Action
- System Load: >4.0
- Memory Usage: >85%
- Services: <8/10 up
- High rollback rates: >5% of transactions
- Error Logs: Frequent application errors

---

## 🛠️ Maintenance Commands

```bash
# Restart monitoring with auto-sync
make restart

# Manual container sync after MarketSage rebuild
make sync-containers

# Check monitoring health
make health

# View all service URLs
make urls

# Run post-rebuild sync
make post-rebuild
```

---

## 📞 Support Information

**Dashboard URLs:**
- System Overview: http://localhost:3000/d/679fa408-4a27-4a42-a8de-889721340151
- Performance Metrics: http://localhost:3000/d/43fdff3f-0b84-4eeb-ae47-de7a936c55f8  
- Comprehensive Logs: http://localhost:3000/d/5d56161d-1420-4d6e-9896-df86273c9bcd

**Quick Access:**
- Grafana: http://localhost:3000 (admin/admin)
- Prometheus: http://localhost:9090
- Alertmanager: http://localhost:9093

**Documentation:**
- Setup Guide: `SETUP_GUIDE.md`
- Rebuild Guide: `REBUILD-GUIDE.md`
- This Guide: `DASHBOARD-GUIDE.md`

---

*This guide covers the complete MarketSage monitoring setup. All dashboards auto-update with real-time data and include enhanced visualizations (gauges, pie charts, heatmaps, time series) for optimal monitoring experience.*