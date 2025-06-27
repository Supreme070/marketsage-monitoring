# 🔧 MarketSage Rebuild Guide

This guide explains how to handle rebuilding MarketSage while maintaining monitoring functionality.

## 🎯 The Issue

When MarketSage containers are rebuilt, they get new container IDs. The monitoring dashboards use these IDs to track specific containers, so they need to be updated after rebuilds.

## ✅ Automatic Solution

We've automated this process! The monitoring stack now automatically syncs with MarketSage containers.

## 🚀 Rebuild Workflows

### **Scenario 1: Rebuilding MarketSage App**

```bash
# 1. Rebuild MarketSage
cd /Users/supreme/Desktop/marketsage
docker-compose down
docker-compose build
docker-compose up -d

# 2. Sync monitoring (from monitoring directory)
cd /Users/supreme/Desktop/marketsage-monitoring
make post-rebuild
```

### **Scenario 2: Rebuilding Monitoring Stack**

```bash
# No extra steps needed - monitoring configs are preserved!
cd /Users/supreme/Desktop/marketsage-monitoring
make restart
```

### **Scenario 3: Rebuilding Everything**

```bash
# 1. Rebuild MarketSage first
cd /Users/supreme/Desktop/marketsage
docker-compose down && docker-compose build && docker-compose up -d

# 2. Restart monitoring (auto-syncs)
cd /Users/supreme/Desktop/marketsage-monitoring
make restart
```

## 🛠️ Available Commands

### **From Monitoring Directory:**

```bash
make start           # Start monitoring (auto-syncs)
make restart         # Restart monitoring (auto-syncs)
make sync-containers # Manual sync with MarketSage
make post-rebuild    # Full post-rebuild hook
make help           # Show all commands
```

### **Manual Sync Script:**

```bash
./update-container-ids.sh    # Direct script execution
./post-rebuild-hook.sh       # Full rebuild hook
```

## 🔍 What Gets Updated

When syncing, these files are automatically updated:

- ✅ `grafana/dashboards/marketsage-overview.json`
- ✅ `grafana/dashboards/metrics-performance.json` 
- ✅ `alloy/rules/marketsage-alerts.yml`
- ✅ Prometheus configuration reloaded

## 📊 Verification

After rebuilding, verify everything works:

```bash
# Check dashboards
make urls
# Visit: http://localhost:3000

# Check container sync worked
docker ps --filter "name=marketsage"
```

## 🎉 Benefits

- **🔄 Automatic**: Sync happens automatically on `make start`
- **🛡️ Safe**: Creates backups before updating configs
- **⚡ Fast**: Takes seconds to sync
- **🔒 Persistent**: All fixes survive rebuilds
- **📈 Robust**: Graceful fallback if MarketSage isn't running

## 🆘 Troubleshooting

**Issue**: "MarketSage containers not found"
**Solution**: Make sure MarketSage is running before syncing

**Issue**: Dashboard shows no data
**Solution**: Run `make sync-containers` manually

**Issue**: Prometheus not reloading
**Solution**: Run `docker restart prometheus`

---

**💡 Pro Tip**: Add `make post-rebuild` to your MarketSage deployment scripts for full automation!