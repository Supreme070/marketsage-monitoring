class PayloadAnalyzer {
  constructor() {
    this.sensitivePatterns = [
      { pattern: /\b\d{4}[\s-]?\d{4}[\s-]?\d{4}[\s-]?\d{4}\b/g, type: 'credit_card', severity: 'high' },
      { pattern: /\b\d{3}-\d{2}-\d{4}\b/g, type: 'ssn', severity: 'high' },
      { pattern: /[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/g, type: 'email', severity: 'medium' },
      { pattern: /(?:password|pwd|secret|token|key)\s*[=:]\s*["']?([^\s"']+)/gi, type: 'credentials', severity: 'high' },
      { pattern: /Bearer\s+[A-Za-z0-9\-._~+/]+=*/g, type: 'bearer_token', severity: 'high' },
      { pattern: /\b(?:AKIA|ASIA)[0-9A-Z]{16}\b/g, type: 'aws_access_key', severity: 'high' }
    ];
    this.complexityThresholds = {
      low: 10,
      medium: 50,
      high: 200
    };
    this.recentAnalyses = new Map();
  }

  async analyze(payload, metadata = {}) {
    const analysis = {
      timestamp: new Date(),
      requestId: metadata.requestId,
      size: this.calculateSize(payload),
      complexity: this.calculateComplexity(payload),
      sensitiveData: this.detectSensitiveData(payload),
      structure: this.analyzeStructure(payload),
      performance: this.analyzePerformance(payload)
    };

    // Store recent analysis for pattern detection
    this.recentAnalyses.set(metadata.requestId, analysis);
    
    // Clean up old analyses (keep last 1000)
    if (this.recentAnalyses.size > 1000) {
      const oldestKey = this.recentAnalyses.keys().next().value;
      this.recentAnalyses.delete(oldestKey);
    }

    return analysis;
  }

  calculateSize(payload) {
    try {
      return JSON.stringify(payload).length;
    } catch (error) {
      return 0;
    }
  }

  calculateComplexity(obj, depth = 0) {
    if (depth > 10) return 0; // Prevent infinite recursion
    
    let complexity = 1;
    
    if (Array.isArray(obj)) {
      complexity += obj.length;
      for (const item of obj) {
        if (typeof item === 'object' && item !== null) {
          complexity += this.calculateComplexity(item, depth + 1);
        }
      }
    } else if (typeof obj === 'object' && obj !== null) {
      const keys = Object.keys(obj);
      complexity += keys.length;
      
      for (const key of keys) {
        if (typeof obj[key] === 'object' && obj[key] !== null) {
          complexity += this.calculateComplexity(obj[key], depth + 1);
        }
      }
    }
    
    return complexity;
  }

  detectSensitiveData(payload) {
    const detections = [];
    const payloadStr = JSON.stringify(payload);
    
    for (const { pattern, type, severity } of this.sensitivePatterns) {
      const matches = payloadStr.match(pattern);
      if (matches) {
        detections.push({
          type,
          severity,
          count: matches.length,
          samples: matches.slice(0, 3).map(match => 
            match.length > 20 ? match.substring(0, 17) + '...' : match
          )
        });
      }
    }
    
    return detections;
  }

  analyzeStructure(payload) {
    const structure = {
      type: Array.isArray(payload) ? 'array' : typeof payload,
      depth: this.getMaxDepth(payload),
      arrayCount: this.countArrays(payload),
      objectCount: this.countObjects(payload),
      primitiveCount: this.countPrimitives(payload)
    };
    
    return structure;
  }

  getMaxDepth(obj, currentDepth = 0) {
    if (typeof obj !== 'object' || obj === null) {
      return currentDepth;
    }
    
    let maxDepth = currentDepth;
    
    for (const value of Object.values(obj)) {
      const depth = this.getMaxDepth(value, currentDepth + 1);
      maxDepth = Math.max(maxDepth, depth);
    }
    
    return maxDepth;
  }

  countArrays(obj) {
    if (typeof obj !== 'object' || obj === null) return 0;
    
    let count = Array.isArray(obj) ? 1 : 0;
    
    for (const value of Object.values(obj)) {
      count += this.countArrays(value);
    }
    
    return count;
  }

  countObjects(obj) {
    if (typeof obj !== 'object' || obj === null) return 0;
    
    let count = Array.isArray(obj) ? 0 : 1;
    
    for (const value of Object.values(obj)) {
      count += this.countObjects(value);
    }
    
    return count;
  }

  countPrimitives(obj) {
    if (typeof obj !== 'object' || obj === null) return 1;
    
    let count = 0;
    
    for (const value of Object.values(obj)) {
      count += this.countPrimitives(value);
    }
    
    return count;
  }

  analyzePerformance(payload) {
    const size = this.calculateSize(payload);
    const complexity = this.calculateComplexity(payload);
    
    return {
      estimatedParseTime: this.estimateParseTime(size),
      estimatedSerializeTime: this.estimateSerializeTime(complexity),
      memoryFootprint: this.estimateMemoryUsage(payload),
      compressionPotential: this.estimateCompressionRatio(payload)
    };
  }

  estimateParseTime(size) {
    // Rough estimate: 1MB takes ~10ms to parse
    return (size / 1024 / 1024) * 10;
  }

  estimateSerializeTime(complexity) {
    // Rough estimate based on complexity
    return Math.log(complexity) * 2;
  }

  estimateMemoryUsage(payload) {
    // Estimate memory usage (JSON in memory is typically 2-4x the string size)
    const stringSize = this.calculateSize(payload);
    return stringSize * 3;
  }

  estimateCompressionRatio(payload) {
    const str = JSON.stringify(payload);
    
    // Simple compression ratio estimation based on repetition
    const unique = new Set(str.split(''));
    const compressionRatio = unique.size / str.length;
    
    return Math.max(0.1, Math.min(1.0, compressionRatio));
  }

  async getHourlyStats(startTime, endTime) {
    const analyses = Array.from(this.recentAnalyses.values())
      .filter(analysis => 
        analysis.timestamp >= startTime && analysis.timestamp <= endTime
      );
    
    if (analyses.length === 0) {
      return { count: 0, averageSize: 0, averageComplexity: 0, sensitiveDetections: 0 };
    }
    
    const totalSize = analyses.reduce((sum, a) => sum + a.size, 0);
    const totalComplexity = analyses.reduce((sum, a) => sum + a.complexity, 0);
    const totalSensitive = analyses.reduce((sum, a) => sum + a.sensitiveData.length, 0);
    
    return {
      count: analyses.length,
      averageSize: totalSize / analyses.length,
      averageComplexity: totalComplexity / analyses.length,
      sensitiveDetections: totalSensitive,
      sizeDistribution: this.calculateSizeDistribution(analyses),
      complexityDistribution: this.calculateComplexityDistribution(analyses)
    };
  }

  calculateSizeDistribution(analyses) {
    const buckets = { small: 0, medium: 0, large: 0, xlarge: 0 };
    
    for (const analysis of analyses) {
      if (analysis.size < 1024) buckets.small++;
      else if (analysis.size < 10240) buckets.medium++;
      else if (analysis.size < 102400) buckets.large++;
      else buckets.xlarge++;
    }
    
    return buckets;
  }

  calculateComplexityDistribution(analyses) {
    const buckets = { low: 0, medium: 0, high: 0, extreme: 0 };
    
    for (const analysis of analyses) {
      if (analysis.complexity < this.complexityThresholds.low) buckets.low++;
      else if (analysis.complexity < this.complexityThresholds.medium) buckets.medium++;
      else if (analysis.complexity < this.complexityThresholds.high) buckets.high++;
      else buckets.extreme++;
    }
    
    return buckets;
  }

  async initialize() {
    // Initialize any required resources
  }

  async cleanup() {
    // Clean up old analyses
    const cutoff = Date.now() - (24 * 60 * 60 * 1000); // 24 hours ago
    
    for (const [requestId, analysis] of this.recentAnalyses.entries()) {
      if (analysis.timestamp.getTime() < cutoff) {
        this.recentAnalyses.delete(requestId);
      }
    }
  }

  async shutdown() {
    this.recentAnalyses.clear();
  }
}

module.exports = PayloadAnalyzer;