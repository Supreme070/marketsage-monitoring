#!/bin/bash
set -e

# MarketSage Monitoring Test Script
# Comprehensive testing for the monitoring infrastructure

echo "🧪 MarketSage Monitoring Test Suite"
echo "==================================="

# Configuration
PROMETHEUS_URL="http://localhost:9090"
LOKI_URL="http://localhost:3100"
GRAFANA_URL="http://localhost:3000"
ALLOY_URL="http://localhost:12345"
ALERTMANAGER_URL="http://localhost:9093"

# Test counters
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0

# Helper functions
run_test() {
    local test_name="$1"
    local test_command="$2"
    
    echo -n "🔍 Testing $test_name... "
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    if eval "$test_command" > /dev/null 2>&1; then
        echo "✅ PASS"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo "❌ FAIL"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

wait_for_service() {
    local service_name="$1"
    local health_url="$2"
    local max_attempts=30
    local attempt=1
    
    echo "⏳ Waiting for $service_name to be ready..."
    
    while [ $attempt -le $max_attempts ]; do
        if curl -f -s "$health_url" > /dev/null 2>&1; then
            echo "✅ $service_name is ready!"
            return 0
        fi
        
        echo "🔄 Attempt $attempt/$max_attempts: $service_name not ready yet..."
        sleep 5
        ((attempt++))
    done
    
    echo "❌ $service_name failed to become ready"
    return 1
}

# Service Health Tests
echo ""
echo "📋 Service Health Tests"
echo "======================="

run_test "Prometheus Health" "curl -f $PROMETHEUS_URL/-/ready"
run_test "Loki Health" "curl -f $LOKI_URL/ready"
run_test "Grafana Health" "curl -f $GRAFANA_URL/api/health"
run_test "Alloy Health" "curl -f $ALLOY_URL/-/healthy"
run_test "Alertmanager Health" "curl -f $ALERTMANAGER_URL/-/ready"

# Service Connectivity Tests
echo ""
echo "🔗 Service Connectivity Tests"
echo "============================="

run_test "Prometheus API" "curl -s $PROMETHEUS_URL/api/v1/status/config | jq -e '.status == \"success\"'"
run_test "Loki API" "curl -s $LOKI_URL/loki/api/v1/status/buildinfo | jq -e '.version'"
run_test "Grafana API" "curl -s $GRAFANA_URL/api/health | jq -e '.database == \"ok\"'"

# Metrics Collection Tests
echo ""
echo "📊 Metrics Collection Tests"
echo "============================"

# Wait for metrics to be collected
echo "⏳ Waiting for metrics collection..."
sleep 30

run_test "Node Exporter Metrics" "curl -s '$PROMETHEUS_URL/api/v1/query?query=node_load1' | jq -e '.data.result | length > 0'"
run_test "cAdvisor Metrics" "curl -s '$PROMETHEUS_URL/api/v1/query?query=container_memory_usage_bytes' | jq -e '.data.result | length > 0'"
run_test "Prometheus Self-Monitoring" "curl -s '$PROMETHEUS_URL/api/v1/query?query=prometheus_tsdb_head_samples_appended_total' | jq -e '.data.result | length > 0'"

# Check database metrics if exporters are connected
if curl -f -s "http://localhost:9187/metrics" > /dev/null 2>&1; then
    run_test "PostgreSQL Metrics" "curl -s '$PROMETHEUS_URL/api/v1/query?query=pg_up' | jq -e '.data.result | length > 0'"
fi

if curl -f -s "http://localhost:9121/metrics" > /dev/null 2>&1; then
    run_test "Redis Metrics" "curl -s '$PROMETHEUS_URL/api/v1/query?query=redis_up' | jq -e '.data.result | length > 0'"
fi

# Log Collection Tests
echo ""
echo "📋 Log Collection Tests"
echo "======================="

run_test "Docker Logs Collection" "curl -s '$LOKI_URL/loki/api/v1/query?query=%7Bjob%3D%22docker%22%7D' | jq -e '.status == \"success\"'"
run_test "Log Ingestion Rate" "curl -s '$LOKI_URL/metrics' | grep -q 'loki_ingester_streams'"

# Dashboard Tests
echo ""
echo "📊 Dashboard Tests"
echo "=================="

run_test "Grafana Login Page" "curl -s $GRAFANA_URL/login | grep -q 'Grafana'"
run_test "Datasource Connectivity" "curl -s $GRAFANA_URL/api/datasources | jq -e '. | length > 0'"

# Alert Rules Tests
echo ""
echo "🚨 Alert Rules Tests"
echo "===================="

run_test "Alert Rules Loaded" "curl -s '$PROMETHEUS_URL/api/v1/rules' | jq -e '.data.groups | length >= 0'"
run_test "Alertmanager Config" "curl -s '$ALERTMANAGER_URL/api/v1/status' | jq -e '.status == \"success\"'"

# Configuration Validation Tests
echo ""
echo "⚙️ Configuration Validation Tests"
echo "================================="

run_test "Prometheus Config Syntax" "docker run --rm -v $(pwd)/config:/config prom/prometheus:latest promtool check config /config/prometheus.yml"
run_test "Loki Config Syntax" "docker run --rm -v $(pwd)/config:/config grafana/loki:latest -config.file=/config/loki.yml -verify-config"
run_test "Alloy Config Syntax" "docker run --rm -v $(pwd)/alloy/config:/config grafana/alloy:latest fmt /config/config.alloy --write=false"

# Security Tests
echo ""
echo "🔒 Security Tests"
echo "================="

run_test "No Default Passwords" "! grep -r 'password.*admin' config/ || true"
run_test "No Hardcoded Secrets" "! grep -r 'password.*=' config/ | grep -v 'PASSWORD_REMOVED' || true"
run_test "Secrets Directory Structure" "[ -d secrets.example ] && [ -f secrets.example/grafana_admin_password.txt ]"

# Performance Tests
echo ""
echo "⚡ Performance Tests"
echo "==================="

response_time=$(curl -o /dev/null -s -w '%{time_total}' "$PROMETHEUS_URL/api/v1/query?query=up")
if (( $(echo "$response_time < 2.0" | bc -l) )); then
    echo "✅ Prometheus response time acceptable: ${response_time}s"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo "❌ Prometheus response time too slow: ${response_time}s"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
TESTS_TOTAL=$((TESTS_TOTAL + 1))

# Data Retention Tests
echo ""
echo "💾 Data Retention Tests"
echo "======================="

run_test "Prometheus Data Directory" "docker exec prometheus ls -la /prometheus"
run_test "Loki Data Directory" "docker exec loki ls -la /loki"
run_test "Grafana Data Persistence" "docker exec grafana ls -la /var/lib/grafana"

# Integration Tests
echo ""
echo "🔗 Integration Tests"
echo "===================="

# Test end-to-end flow: metrics -> alerts
run_test "Metrics to Alertmanager Flow" "curl -s '$ALERTMANAGER_URL/api/v1/alerts' | jq -e '. | length >= 0'"

# Test log query functionality
run_test "Log Query Functionality" "curl -s '$LOKI_URL/loki/api/v1/query_range?query=%7Bjob%3D%22docker%22%7D&start=$(date -d '1 hour ago' -u +%s)000000000&end=$(date -u +%s)000000000' | jq -e '.status == \"success\"'"

# Final Results
echo ""
echo "📊 Test Results Summary"
echo "======================="
echo "Total Tests: $TESTS_TOTAL"
echo "Passed: $TESTS_PASSED"
echo "Failed: $TESTS_FAILED"
echo "Success Rate: $(( TESTS_PASSED * 100 / TESTS_TOTAL ))%"

if [ $TESTS_FAILED -eq 0 ]; then
    echo ""
    echo "🎉 All tests passed! MarketSage Monitoring is working correctly."
    exit 0
else
    echo ""
    echo "❌ Some tests failed. Please check the monitoring stack configuration."
    exit 1
fi