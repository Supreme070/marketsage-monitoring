class AuthAnalyzer {
  constructor() {
    this.recentEvents = new Map();
    this.suspiciousPatterns = {
      failedLoginThreshold: 5,
      timeWindow: 5 * 60 * 1000, // 5 minutes
      rateLimitThreshold: 100,
      suspiciousUserAgents: [
        /bot/i,
        /crawler/i,
        /scanner/i,
        /hack/i
      ],
      privilegeEscalationKeywords: [
        'admin',
        'root',
        'superuser',
        'elevated',
        'privilege'
      ]
    };
    this.authStats = {
      totalAttempts: 0,
      successfulAttempts: 0,
      failedAttempts: 0,
      suspiciousActivities: 0
    };
  }

  async analyze(authData, metadata = {}) {
    const analysis = {
      timestamp: new Date(),
      requestId: metadata.requestId,
      userAgent: metadata.userAgent,
      authType: this.determineAuthType(authData),
      tokenInfo: this.analyzeToken(authData),
      riskScore: this.calculateRiskScore(authData, metadata),
      anomalies: this.detectAnomalies(authData, metadata),
      permissions: this.analyzePermissions(authData)
    };

    // Store recent event for pattern analysis
    this.recentEvents.set(metadata.requestId, analysis);
    
    // Update statistics
    this.updateStats(analysis);
    
    // Detect suspicious patterns
    const suspiciousActivity = this.detectSuspiciousActivity(analysis, metadata);
    if (suspiciousActivity) {
      analysis.suspicious = suspiciousActivity;
      this.authStats.suspiciousActivities++;
    }

    // Clean up old events
    this.cleanupOldEvents();

    return analysis;
  }

  determineAuthType(authData) {
    if (authData.token) {
      if (authData.token.startsWith('Bearer ')) return 'bearer_token';
      if (authData.token.startsWith('Basic ')) return 'basic_auth';
      if (authData.token.includes('jwt')) return 'jwt';
      return 'custom_token';
    }
    
    if (authData.apiKey) return 'api_key';
    if (authData.certificate) return 'client_certificate';
    if (authData.oauth) return 'oauth';
    
    return 'unknown';
  }

  analyzeToken(authData) {
    if (!authData.token) return null;
    
    const tokenInfo = {
      type: this.determineAuthType(authData),
      length: authData.token.length,
      entropy: this.calculateEntropy(authData.token),
      structure: this.analyzeTokenStructure(authData.token)
    };
    
    // JWT specific analysis
    if (tokenInfo.type === 'jwt') {
      tokenInfo.jwt = this.analyzeJWT(authData.token);
    }
    
    return tokenInfo;
  }

  calculateEntropy(str) {
    const freq = {};
    for (const char of str) {
      freq[char] = (freq[char] || 0) + 1;
    }
    
    let entropy = 0;
    const len = str.length;
    
    for (const count of Object.values(freq)) {
      const p = count / len;
      entropy -= p * Math.log2(p);
    }
    
    return entropy;
  }

  analyzeTokenStructure(token) {
    return {
      hasNumbers: /\d/.test(token),
      hasLowercase: /[a-z]/.test(token),
      hasUppercase: /[A-Z]/.test(token),
      hasSpecialChars: /[^a-zA-Z0-9]/.test(token),
      segments: token.split('.').length,
      encoding: this.detectEncoding(token)
    };
  }

  detectEncoding(token) {
    if (/^[A-Za-z0-9+/]*={0,2}$/.test(token)) return 'base64';
    if (/^[A-Fa-f0-9]+$/.test(token)) return 'hex';
    if (/^[A-Za-z0-9_-]+$/.test(token)) return 'base64url';
    return 'unknown';
  }

  analyzeJWT(token) {
    try {
      const parts = token.split('.');
      if (parts.length !== 3) return { valid: false, reason: 'invalid_structure' };
      
      const header = JSON.parse(Buffer.from(parts[0], 'base64').toString());
      const payload = JSON.parse(Buffer.from(parts[1], 'base64').toString());
      
      return {
        valid: true,
        algorithm: header.alg,
        type: header.typ,
        issuer: payload.iss,
        subject: payload.sub,
        audience: payload.aud,
        expiresAt: payload.exp ? new Date(payload.exp * 1000) : null,
        issuedAt: payload.iat ? new Date(payload.iat * 1000) : null,
        notBefore: payload.nbf ? new Date(payload.nbf * 1000) : null,
        isExpired: payload.exp ? Date.now() / 1000 > payload.exp : false,
        customClaims: Object.keys(payload).filter(key => 
          !['iss', 'sub', 'aud', 'exp', 'iat', 'nbf', 'jti'].includes(key)
        )
      };
    } catch (error) {
      return { valid: false, reason: 'parse_error', error: error.message };
    }
  }

  calculateRiskScore(authData, metadata) {
    let score = 0;
    
    // User agent risk
    if (metadata.userAgent) {
      for (const pattern of this.suspiciousPatterns.suspiciousUserAgents) {
        if (pattern.test(metadata.userAgent)) {
          score += 30;
          break;
        }
      }
    }
    
    // Token quality risk
    if (authData.token) {
      const tokenInfo = this.analyzeToken(authData);
      if (tokenInfo.entropy < 3) score += 20;
      if (tokenInfo.length < 16) score += 15;
    }
    
    // Time-based risk (unusual hours)
    const hour = new Date().getHours();
    if (hour < 6 || hour > 22) score += 10;
    
    // Frequency risk
    const recentRequests = this.getRecentRequestsByIP(metadata.ip);
    if (recentRequests > this.suspiciousPatterns.rateLimitThreshold) {
      score += 40;
    }
    
    return Math.min(100, score);
  }

  detectAnomalies(authData, metadata) {
    const anomalies = [];
    
    // Unusual token patterns
    if (authData.token) {
      const tokenInfo = this.analyzeToken(authData);
      
      if (tokenInfo.type === 'jwt' && tokenInfo.jwt.isExpired) {
        anomalies.push({
          type: 'expired_token',
          severity: 'high',
          description: 'JWT token is expired'
        });
      }
      
      if (tokenInfo.entropy < 2) {
        anomalies.push({
          type: 'low_entropy_token',
          severity: 'medium',
          description: 'Token has unusually low entropy'
        });
      }
    }
    
    // Geographic anomalies (if IP geolocation data available)
    // This would require additional IP geolocation service
    
    // Time-based anomalies
    const hour = new Date().getHours();
    if (hour >= 2 && hour <= 5) {
      anomalies.push({
        type: 'unusual_time',
        severity: 'low',
        description: 'Request during unusual hours (2-5 AM)'
      });
    }
    
    return anomalies;
  }

  analyzePermissions(authData) {
    const permissions = {
      scope: [],
      roles: [],
      resourceAccess: [],
      elevatedPrivileges: false
    };
    
    // Extract permissions from JWT
    if (authData.token) {
      const tokenInfo = this.analyzeToken(authData);
      if (tokenInfo.type === 'jwt' && tokenInfo.jwt.valid) {
        try {
          const payload = JSON.parse(
            Buffer.from(authData.token.split('.')[1], 'base64').toString()
          );
          
          if (payload.scope) {
            permissions.scope = Array.isArray(payload.scope) 
              ? payload.scope 
              : payload.scope.split(' ');
          }
          
          if (payload.roles) {
            permissions.roles = Array.isArray(payload.roles) 
              ? payload.roles 
              : [payload.roles];
          }
          
          if (payload.permissions) {
            permissions.resourceAccess = payload.permissions;
          }
          
          // Check for elevated privileges
          const elevatedKeywords = this.suspiciousPatterns.privilegeEscalationKeywords;
          const allPermissions = [
            ...permissions.scope,
            ...permissions.roles,
            ...Object.keys(payload)
          ].join(' ').toLowerCase();
          
          permissions.elevatedPrivileges = elevatedKeywords.some(keyword => 
            allPermissions.includes(keyword)
          );
          
        } catch (error) {
          // JWT parsing already handled in analyzeJWT
        }
      }
    }
    
    return permissions;
  }

  detectSuspiciousActivity(analysis, metadata) {
    const suspicious = [];
    
    // High risk score
    if (analysis.riskScore > 70) {
      suspicious.push({
        type: 'high_risk_score',
        severity: 'high',
        score: analysis.riskScore,
        description: 'Authentication request has high risk score'
      });
    }
    
    // Multiple anomalies
    if (analysis.anomalies.length >= 3) {
      suspicious.push({
        type: 'multiple_anomalies',
        severity: 'medium',
        count: analysis.anomalies.length,
        description: 'Multiple authentication anomalies detected'
      });
    }
    
    // Privilege escalation attempt
    if (analysis.permissions.elevatedPrivileges) {
      suspicious.push({
        type: 'privilege_escalation',
        severity: 'high',
        description: 'Request involves elevated privileges'
      });
    }
    
    // Rate limiting violation
    const recentRequests = this.getRecentRequestsByIP(metadata.ip);
    if (recentRequests > this.suspiciousPatterns.rateLimitThreshold) {
      suspicious.push({
        type: 'rate_limit_violation',
        severity: 'medium',
        requestCount: recentRequests,
        description: 'Excessive requests from IP address'
      });
    }
    
    return suspicious.length > 0 ? suspicious : null;
  }

  getRecentRequestsByIP(ip) {
    if (!ip) return 0;
    
    const now = Date.now();
    const cutoff = now - this.suspiciousPatterns.timeWindow;
    
    return Array.from(this.recentEvents.values())
      .filter(event => 
        event.timestamp.getTime() > cutoff && 
        event.metadata && 
        event.metadata.ip === ip
      ).length;
  }

  updateStats(analysis) {
    this.authStats.totalAttempts++;
    
    if (analysis.riskScore < 30) {
      this.authStats.successfulAttempts++;
    } else {
      this.authStats.failedAttempts++;
    }
  }

  cleanupOldEvents() {
    const cutoff = Date.now() - (2 * 60 * 60 * 1000); // 2 hours
    
    for (const [requestId, event] of this.recentEvents.entries()) {
      if (event.timestamp.getTime() < cutoff) {
        this.recentEvents.delete(requestId);
      }
    }
    
    // Keep maximum 5000 events
    if (this.recentEvents.size > 5000) {
      const entries = Array.from(this.recentEvents.entries());
      entries.sort((a, b) => a[1].timestamp - b[1].timestamp);
      
      // Remove oldest 1000 events
      for (let i = 0; i < 1000; i++) {
        this.recentEvents.delete(entries[i][0]);
      }
    }
  }

  async getRecentEvents() {
    const cutoff = Date.now() - (60 * 60 * 1000); // Last hour
    
    return Array.from(this.recentEvents.values())
      .filter(event => event.timestamp.getTime() > cutoff)
      .sort((a, b) => b.timestamp - a.timestamp)
      .slice(0, 100); // Return last 100 events
  }

  async getHourlyStats(startTime, endTime) {
    const events = Array.from(this.recentEvents.values())
      .filter(event => 
        event.timestamp >= startTime && event.timestamp <= endTime
      );
    
    if (events.length === 0) {
      return {
        totalEvents: 0,
        averageRiskScore: 0,
        suspiciousEvents: 0,
        authTypes: {},
        anomalies: {}
      };
    }
    
    const totalRiskScore = events.reduce((sum, e) => sum + e.riskScore, 0);
    const suspiciousEvents = events.filter(e => e.suspicious).length;
    
    const authTypes = {};
    const anomalies = {};
    
    for (const event of events) {
      authTypes[event.authType] = (authTypes[event.authType] || 0) + 1;
      
      for (const anomaly of event.anomalies) {
        anomalies[anomaly.type] = (anomalies[anomaly.type] || 0) + 1;
      }
    }
    
    return {
      totalEvents: events.length,
      averageRiskScore: totalRiskScore / events.length,
      suspiciousEvents,
      authTypes,
      anomalies,
      period: {
        start: startTime.toISOString(),
        end: endTime.toISOString()
      }
    };
  }

  async initialize() {
    // Initialize any required resources
  }

  async cleanup() {
    this.cleanupOldEvents();
  }

  async shutdown() {
    this.recentEvents.clear();
  }
}

module.exports = AuthAnalyzer;