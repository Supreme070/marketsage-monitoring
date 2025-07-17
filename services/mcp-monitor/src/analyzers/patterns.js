class PatternAnalyzer {
  constructor() {
    this.eventHistory = [];
    this.patterns = new Map();
    this.behaviorProfiles = new Map();
    this.anomalyThresholds = {
      requestFrequency: 100, // requests per minute
      payloadSizeVariation: 0.8, // 80% variation from normal
      errorRateSpike: 0.1, // 10% error rate
      unusualMethodCombinations: 5 // different methods in short time
    };
    this.timeWindows = {
      short: 5 * 60 * 1000,    // 5 minutes
      medium: 30 * 60 * 1000,  // 30 minutes
      long: 2 * 60 * 60 * 1000 // 2 hours
    };
  }

  async trackEvent(event) {
    const enrichedEvent = {
      ...event,
      timestamp: new Date(event.timestamp || Date.now()),
      hour: new Date().getHours(),
      dayOfWeek: new Date().getDay(),
      processed: true
    };

    // Add to history
    this.eventHistory.push(enrichedEvent);
    
    // Maintain history size (keep last 10,000 events)
    if (this.eventHistory.length > 10000) {
      this.eventHistory.shift();
    }

    // Update behavior profiles
    this.updateBehaviorProfile(enrichedEvent);
    
    // Detect patterns
    const detectedPatterns = this.detectPatterns(enrichedEvent);
    
    // Store significant patterns
    if (detectedPatterns.length > 0) {
      for (const pattern of detectedPatterns) {
        this.patterns.set(pattern.id, pattern);
      }
    }

    return {
      event: enrichedEvent,
      patterns: detectedPatterns,
      anomalies: this.detectAnomalies(enrichedEvent)
    };
  }

  updateBehaviorProfile(event) {
    const profileKey = this.generateProfileKey(event);
    
    if (!this.behaviorProfiles.has(profileKey)) {
      this.behaviorProfiles.set(profileKey, {
        requestCount: 0,
        methods: new Set(),
        avgPayloadSize: 0,
        avgResponseTime: 0,
        errorRate: 0,
        lastSeen: null,
        firstSeen: null,
        timePatterns: {
          hourlyDistribution: new Array(24).fill(0),
          dailyDistribution: new Array(7).fill(0)
        },
        resourcePatterns: new Map()
      });
    }

    const profile = this.behaviorProfiles.get(profileKey);
    
    // Update basic stats
    profile.requestCount++;
    profile.methods.add(event.method || 'unknown');
    profile.lastSeen = event.timestamp;
    
    if (!profile.firstSeen) {
      profile.firstSeen = event.timestamp;
    }

    // Update time patterns
    profile.timePatterns.hourlyDistribution[event.hour]++;
    profile.timePatterns.dailyDistribution[event.dayOfWeek]++;

    // Update payload size average
    if (event.payloadSize) {
      profile.avgPayloadSize = (
        (profile.avgPayloadSize * (profile.requestCount - 1) + event.payloadSize) / 
        profile.requestCount
      );
    }

    // Update response time average
    if (event.responseTime) {
      profile.avgResponseTime = (
        (profile.avgResponseTime * (profile.requestCount - 1) + event.responseTime) / 
        profile.requestCount
      );
    }

    // Update error rate
    const errors = this.getRecentErrors(profileKey);
    const total = this.getRecentRequests(profileKey);
    profile.errorRate = total > 0 ? errors / total : 0;

    // Update resource patterns
    if (event.resourceType) {
      const resourceCount = profile.resourcePatterns.get(event.resourceType) || 0;
      profile.resourcePatterns.set(event.resourceType, resourceCount + 1);
    }
  }

  generateProfileKey(event) {
    // Generate a key based on agent/user identification
    const userAgent = event.userAgent || 'unknown';
    const clientId = event.clientId || event.agent?.id || 'unknown';
    const ip = event.ip || 'unknown';
    
    return `${clientId}:${userAgent}:${ip}`.slice(0, 100); // Limit key length
  }

  detectPatterns(event) {
    const patterns = [];
    const now = event.timestamp;
    
    // 1. Request frequency patterns
    const frequencyPattern = this.detectFrequencyPattern(event, now);
    if (frequencyPattern) patterns.push(frequencyPattern);
    
    // 2. Method sequence patterns
    const sequencePattern = this.detectMethodSequencePattern(event, now);
    if (sequencePattern) patterns.push(sequencePattern);
    
    // 3. Resource access patterns
    const resourcePattern = this.detectResourceAccessPattern(event, now);
    if (resourcePattern) patterns.push(resourcePattern);
    
    // 4. Error clustering patterns
    const errorPattern = this.detectErrorClusteringPattern(event, now);
    if (errorPattern) patterns.push(errorPattern);
    
    // 5. Time-based patterns
    const timePattern = this.detectTimeBasedPattern(event, now);
    if (timePattern) patterns.push(timePattern);

    return patterns;
  }

  detectFrequencyPattern(event, now) {
    const profileKey = this.generateProfileKey(event);
    const recentEvents = this.getRecentEventsByProfile(profileKey, this.timeWindows.short);
    
    if (recentEvents.length > this.anomalyThresholds.requestFrequency) {
      return {
        id: `freq_${profileKey}_${now.getTime()}`,
        type: 'high_frequency',
        severity: 'medium',
        description: `High request frequency: ${recentEvents.length} requests in 5 minutes`,
        profileKey,
        eventCount: recentEvents.length,
        timeWindow: this.timeWindows.short,
        confidence: Math.min(1.0, recentEvents.length / (this.anomalyThresholds.requestFrequency * 2))
      };
    }

    return null;
  }

  detectMethodSequencePattern(event, now) {
    const profileKey = this.generateProfileKey(event);
    const recentEvents = this.getRecentEventsByProfile(profileKey, this.timeWindows.medium);
    
    if (recentEvents.length < 5) return null;
    
    const methods = recentEvents.map(e => e.method || 'unknown');
    const uniqueMethods = new Set(methods);
    
    // Detect if agent is using unusual method combinations
    if (uniqueMethods.size > this.anomalyThresholds.unusualMethodCombinations) {
      return {
        id: `method_seq_${profileKey}_${now.getTime()}`,
        type: 'unusual_method_sequence',
        severity: 'low',
        description: `Unusual method combination: ${Array.from(uniqueMethods).join(', ')}`,
        profileKey,
        methods: Array.from(uniqueMethods),
        sequence: methods.slice(-10), // Last 10 methods
        confidence: Math.min(1.0, uniqueMethods.size / 10)
      };
    }

    return null;
  }

  detectResourceAccessPattern(event, now) {
    if (!event.resourceType) return null;
    
    const profileKey = this.generateProfileKey(event);
    const recentEvents = this.getRecentEventsByProfile(profileKey, this.timeWindows.medium);
    
    const resourceAccess = new Map();
    for (const evt of recentEvents) {
      if (evt.resourceType) {
        const count = resourceAccess.get(evt.resourceType) || 0;
        resourceAccess.set(evt.resourceType, count + 1);
      }
    }
    
    // Detect if agent is accessing many different resource types rapidly
    if (resourceAccess.size > 10) {
      return {
        id: `resource_${profileKey}_${now.getTime()}`,
        type: 'diverse_resource_access',
        severity: 'low',
        description: `Accessing ${resourceAccess.size} different resource types`,
        profileKey,
        resourceTypes: Array.from(resourceAccess.keys()),
        accessCounts: Object.fromEntries(resourceAccess),
        confidence: Math.min(1.0, resourceAccess.size / 20)
      };
    }

    return null;
  }

  detectErrorClusteringPattern(event, now) {
    const profileKey = this.generateProfileKey(event);
    const recentEvents = this.getRecentEventsByProfile(profileKey, this.timeWindows.short);
    
    const errors = recentEvents.filter(e => e.error || e.status === 'error');
    const errorRate = recentEvents.length > 0 ? errors.length / recentEvents.length : 0;
    
    if (errorRate > this.anomalyThresholds.errorRateSpike && errors.length > 5) {
      return {
        id: `error_cluster_${profileKey}_${now.getTime()}`,
        type: 'error_clustering',
        severity: 'high',
        description: `High error rate: ${(errorRate * 100).toFixed(1)}% (${errors.length}/${recentEvents.length})`,
        profileKey,
        errorRate,
        errorCount: errors.length,
        totalRequests: recentEvents.length,
        errorTypes: this.categorizeErrors(errors),
        confidence: Math.min(1.0, errorRate * 2)
      };
    }

    return null;
  }

  detectTimeBasedPattern(event, now) {
    const hour = now.getHours();
    const dayOfWeek = now.getDay();
    
    // Detect unusual time patterns (very early morning requests)
    if (hour >= 2 && hour <= 5) {
      const profileKey = this.generateProfileKey(event);
      const profile = this.behaviorProfiles.get(profileKey);
      
      if (profile && profile.requestCount > 100) {
        const nightTimeRequests = profile.timePatterns.hourlyDistribution
          .slice(2, 6)
          .reduce((sum, count) => sum + count, 0);
        
        const totalRequests = profile.timePatterns.hourlyDistribution
          .reduce((sum, count) => sum + count, 0);
        
        const nightTimeRatio = nightTimeRequests / totalRequests;
        
        if (nightTimeRatio > 0.3) { // More than 30% of requests during night hours
          return {
            id: `time_pattern_${profileKey}_${now.getTime()}`,
            type: 'unusual_time_pattern',
            severity: 'medium',
            description: `High activity during night hours: ${(nightTimeRatio * 100).toFixed(1)}%`,
            profileKey,
            nightTimeRatio,
            currentHour: hour,
            confidence: Math.min(1.0, nightTimeRatio * 2)
          };
        }
      }
    }

    return null;
  }

  categorizeErrors(errors) {
    const categories = {};
    
    for (const error of errors) {
      const category = error.errorType || error.error?.type || 'unknown';
      categories[category] = (categories[category] || 0) + 1;
    }
    
    return categories;
  }

  detectAnomalies(event) {
    const anomalies = [];
    const profileKey = this.generateProfileKey(event);
    const profile = this.behaviorProfiles.get(profileKey);
    
    if (!profile || profile.requestCount < 10) {
      return anomalies; // Need baseline data
    }

    // Payload size anomaly
    if (event.payloadSize && profile.avgPayloadSize > 0) {
      const sizeRatio = event.payloadSize / profile.avgPayloadSize;
      if (sizeRatio > (1 + this.anomalyThresholds.payloadSizeVariation) || 
          sizeRatio < (1 - this.anomalyThresholds.payloadSizeVariation)) {
        anomalies.push({
          type: 'payload_size_anomaly',
          severity: sizeRatio > 3 || sizeRatio < 0.3 ? 'high' : 'medium',
          description: `Payload size ${event.payloadSize} vs average ${profile.avgPayloadSize.toFixed(0)}`,
          ratio: sizeRatio,
          expected: profile.avgPayloadSize,
          actual: event.payloadSize
        });
      }
    }

    // Response time anomaly
    if (event.responseTime && profile.avgResponseTime > 0) {
      const timeRatio = event.responseTime / profile.avgResponseTime;
      if (timeRatio > 3) { // Response time 3x higher than average
        anomalies.push({
          type: 'response_time_anomaly',
          severity: timeRatio > 10 ? 'high' : 'medium',
          description: `Response time ${event.responseTime}ms vs average ${profile.avgResponseTime.toFixed(0)}ms`,
          ratio: timeRatio,
          expected: profile.avgResponseTime,
          actual: event.responseTime
        });
      }
    }

    // New method anomaly
    if (event.method && !profile.methods.has(event.method)) {
      anomalies.push({
        type: 'new_method_anomaly',
        severity: 'low',
        description: `First time using method: ${event.method}`,
        method: event.method,
        knownMethods: Array.from(profile.methods)
      });
    }

    return anomalies;
  }

  getRecentEventsByProfile(profileKey, timeWindow) {
    const cutoff = Date.now() - timeWindow;
    
    return this.eventHistory.filter(event => 
      this.generateProfileKey(event) === profileKey &&
      event.timestamp.getTime() > cutoff
    );
  }

  getRecentRequests(profileKey, timeWindow = this.timeWindows.short) {
    return this.getRecentEventsByProfile(profileKey, timeWindow).length;
  }

  getRecentErrors(profileKey, timeWindow = this.timeWindows.short) {
    return this.getRecentEventsByProfile(profileKey, timeWindow)
      .filter(event => event.error || event.status === 'error').length;
  }

  async getCurrentPatterns() {
    const cutoff = Date.now() - this.timeWindows.long;
    const currentPatterns = [];
    
    for (const [id, pattern] of this.patterns.entries()) {
      if (id.includes('_') && parseInt(id.split('_').pop()) > cutoff) {
        currentPatterns.push(pattern);
      }
    }
    
    return currentPatterns.sort((a, b) => {
      const severityOrder = { high: 3, medium: 2, low: 1 };
      return severityOrder[b.severity] - severityOrder[a.severity];
    });
  }

  async getHourlyPatterns(startTime, endTime) {
    const relevantEvents = this.eventHistory.filter(event => 
      event.timestamp >= startTime && event.timestamp <= endTime
    );
    
    const patterns = {
      totalEvents: relevantEvents.length,
      uniqueProfiles: new Set(relevantEvents.map(e => this.generateProfileKey(e))).size,
      methodDistribution: {},
      resourceDistribution: {},
      hourlyDistribution: new Array(24).fill(0),
      anomalyCount: 0,
      patternTypes: {}
    };
    
    for (const event of relevantEvents) {
      // Method distribution
      const method = event.method || 'unknown';
      patterns.methodDistribution[method] = (patterns.methodDistribution[method] || 0) + 1;
      
      // Resource distribution
      if (event.resourceType) {
        patterns.resourceDistribution[event.resourceType] = 
          (patterns.resourceDistribution[event.resourceType] || 0) + 1;
      }
      
      // Hourly distribution
      patterns.hourlyDistribution[event.hour]++;
      
      // Count anomalies
      const anomalies = this.detectAnomalies(event);
      patterns.anomalyCount += anomalies.length;
    }
    
    // Count pattern types
    const currentPatterns = await this.getCurrentPatterns();
    for (const pattern of currentPatterns) {
      patterns.patternTypes[pattern.type] = (patterns.patternTypes[pattern.type] || 0) + 1;
    }
    
    return patterns;
  }

  async initialize() {
    // Initialize any required resources
  }

  async cleanup() {
    const cutoff = Date.now() - (24 * 60 * 60 * 1000); // 24 hours ago
    
    // Clean up old events
    this.eventHistory = this.eventHistory.filter(event => 
      event.timestamp.getTime() > cutoff
    );
    
    // Clean up old patterns
    for (const [id, pattern] of this.patterns.entries()) {
      const timestamp = parseInt(id.split('_').pop());
      if (timestamp && timestamp < cutoff) {
        this.patterns.delete(id);
      }
    }
    
    // Clean up old behavior profiles
    for (const [profileKey, profile] of this.behaviorProfiles.entries()) {
      if (profile.lastSeen && profile.lastSeen.getTime() < cutoff) {
        this.behaviorProfiles.delete(profileKey);
      }
    }
  }

  async shutdown() {
    this.eventHistory = [];
    this.patterns.clear();
    this.behaviorProfiles.clear();
  }
}

module.exports = PatternAnalyzer;