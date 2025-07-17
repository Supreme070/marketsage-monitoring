class TaskExecutionAnalyzer {
  constructor() {
    this.activeTasks = new Map();
    this.completedTasks = new Map();
    this.taskHistory = [];
    this.taskMetrics = {
      totalStarted: 0,
      totalCompleted: 0,
      totalFailed: 0,
      totalCancelled: 0,
      totalTimedOut: 0
    };
    this.taskTypes = new Map();
    this.performanceBaselines = new Map();
    this.maxHistorySize = 10000;
    this.maxActiveTaskAge = 30 * 60 * 1000; // 30 minutes
  }

  async trackTaskStart(taskEvent) {
    const task = {
      id: taskEvent.taskId || this.generateTaskId(),
      type: taskEvent.taskType || 'unknown',
      method: taskEvent.method,
      startTime: new Date(taskEvent.timestamp || Date.now()),
      agentId: taskEvent.agentId || taskEvent.agent?.id,
      clientId: taskEvent.clientId,
      requestId: taskEvent.requestId,
      priority: taskEvent.priority || 'normal',
      expectedDuration: taskEvent.expectedDuration,
      context: {
        userAgent: taskEvent.userAgent,
        ip: taskEvent.ip,
        resourceType: taskEvent.resourceType,
        resourcePath: taskEvent.resourcePath,
        parameters: taskEvent.parameters,
        dependencies: taskEvent.dependencies || []
      },
      status: 'running',
      progress: 0,
      steps: [],
      errors: [],
      warnings: [],
      retryCount: 0,
      lastHeartbeat: new Date()
    };

    this.activeTasks.set(task.id, task);
    this.taskMetrics.totalStarted++;
    
    // Track task type statistics
    const typeStats = this.taskTypes.get(task.type) || {
      count: 0,
      avgDuration: 0,
      successRate: 0,
      failures: 0
    };
    typeStats.count++;
    this.taskTypes.set(task.type, typeStats);

    // Set timeout monitoring if expected duration provided
    if (task.expectedDuration) {
      setTimeout(() => {
        this.checkTaskTimeout(task.id);
      }, task.expectedDuration * 1.5); // 150% of expected duration
    }

    return {
      taskId: task.id,
      status: 'started',
      startTime: task.startTime,
      analysis: this.analyzeTaskStart(task)
    };
  }

  async trackTaskProgress(progressEvent) {
    const task = this.activeTasks.get(progressEvent.taskId);
    if (!task) {
      return { error: 'Task not found', taskId: progressEvent.taskId };
    }

    // Update progress
    task.progress = Math.max(0, Math.min(100, progressEvent.progress || 0));
    task.lastHeartbeat = new Date();
    
    // Add step if provided
    if (progressEvent.step) {
      task.steps.push({
        name: progressEvent.step,
        timestamp: new Date(),
        duration: progressEvent.stepDuration,
        status: progressEvent.stepStatus || 'completed',
        output: progressEvent.stepOutput,
        metrics: progressEvent.stepMetrics
      });
    }

    // Track warnings
    if (progressEvent.warning) {
      task.warnings.push({
        message: progressEvent.warning,
        timestamp: new Date(),
        severity: progressEvent.warningSeverity || 'medium',
        code: progressEvent.warningCode
      });
    }

    // Update estimated completion time
    if (task.progress > 0) {
      const elapsed = Date.now() - task.startTime.getTime();
      task.estimatedCompletion = new Date(
        task.startTime.getTime() + (elapsed / task.progress * 100)
      );
    }

    return {
      taskId: task.id,
      progress: task.progress,
      estimatedCompletion: task.estimatedCompletion,
      analysis: this.analyzeTaskProgress(task)
    };
  }

  async trackTaskCompletion(completionEvent) {
    const task = this.activeTasks.get(completionEvent.taskId);
    if (!task) {
      return { error: 'Task not found', taskId: completionEvent.taskId };
    }

    // Update task completion
    task.endTime = new Date(completionEvent.timestamp || Date.now());
    task.duration = task.endTime.getTime() - task.startTime.getTime();
    task.status = completionEvent.status || 'completed';
    task.result = completionEvent.result;
    task.output = completionEvent.output;
    task.exitCode = completionEvent.exitCode;
    task.finalProgress = task.progress;

    // Handle different completion types
    switch (task.status) {
      case 'completed':
      case 'success':
        this.taskMetrics.totalCompleted++;
        task.status = 'completed';
        break;
      case 'failed':
      case 'error':
        this.taskMetrics.totalFailed++;
        task.status = 'failed';
        if (completionEvent.error) {
          task.errors.push({
            message: completionEvent.error.message || completionEvent.error,
            timestamp: task.endTime,
            code: completionEvent.error.code,
            stack: completionEvent.error.stack,
            type: completionEvent.error.type || 'execution_error'
          });
        }
        break;
      case 'cancelled':
        this.taskMetrics.totalCancelled++;
        task.cancellationReason = completionEvent.reason;
        break;
      case 'timeout':
        this.taskMetrics.totalTimedOut++;
        task.timeoutReason = completionEvent.reason || 'exceeded_expected_duration';
        break;
    }

    // Calculate performance metrics
    task.performance = this.calculateTaskPerformance(task);
    
    // Update baselines
    this.updatePerformanceBaseline(task);
    
    // Move to completed tasks
    this.activeTasks.delete(task.id);
    this.completedTasks.set(task.id, task);
    
    // Add to history
    this.addToHistory(task);
    
    // Cleanup old completed tasks
    this.cleanupCompletedTasks();

    return {
      taskId: task.id,
      status: task.status,
      duration: task.duration,
      performance: task.performance,
      analysis: this.analyzeTaskCompletion(task)
    };
  }

  async trackTaskRetry(retryEvent) {
    const task = this.activeTasks.get(retryEvent.taskId);
    if (!task) {
      return { error: 'Task not found', taskId: retryEvent.taskId };
    }

    task.retryCount++;
    task.lastRetry = new Date();
    task.retryReason = retryEvent.reason;
    
    // Reset progress on retry
    task.progress = 0;
    task.steps = [];
    
    // Track retry error
    if (retryEvent.previousError) {
      task.errors.push({
        message: retryEvent.previousError.message,
        timestamp: new Date(),
        type: 'retry_trigger',
        retryAttempt: task.retryCount
      });
    }

    return {
      taskId: task.id,
      retryCount: task.retryCount,
      status: 'retrying'
    };
  }

  generateTaskId() {
    return `task_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  }

  analyzeTaskStart(task) {
    const analysis = {
      risk: 'low',
      estimatedSuccess: 0.9,
      concerns: [],
      recommendations: []
    };

    // Check if task type has historical issues
    const typeStats = this.taskTypes.get(task.type);
    if (typeStats && typeStats.successRate < 0.8) {
      analysis.risk = 'medium';
      analysis.estimatedSuccess = typeStats.successRate;
      analysis.concerns.push(`Task type ${task.type} has ${(typeStats.successRate * 100).toFixed(1)}% success rate`);
    }

    // Check for dependency risks
    if (task.context.dependencies && task.context.dependencies.length > 5) {
      analysis.risk = 'medium';
      analysis.concerns.push(`High dependency count: ${task.context.dependencies.length}`);
    }

    // Check agent load
    const agentTasks = Array.from(this.activeTasks.values())
      .filter(t => t.agentId === task.agentId);
    
    if (agentTasks.length > 10) {
      analysis.risk = 'high';
      analysis.concerns.push(`Agent ${task.agentId} has ${agentTasks.length} active tasks`);
      analysis.recommendations.push('Consider load balancing or task queuing');
    }

    return analysis;
  }

  analyzeTaskProgress(task) {
    const analysis = {
      onTrack: true,
      concerns: [],
      predictions: {}
    };

    // Check progress rate
    if (task.estimatedCompletion) {
      const timeRemaining = task.estimatedCompletion.getTime() - Date.now();
      if (timeRemaining < 0) {
        analysis.onTrack = false;
        analysis.concerns.push('Task is running behind estimated completion time');
      }
    }

    // Check for stalled progress
    const progressAge = Date.now() - task.lastHeartbeat.getTime();
    if (progressAge > 5 * 60 * 1000) { // 5 minutes without progress
      analysis.onTrack = false;
      analysis.concerns.push('No progress updates received in 5+ minutes');
    }

    // Analyze step performance
    if (task.steps.length > 0) {
      const avgStepDuration = task.steps
        .filter(s => s.duration)
        .reduce((sum, s) => sum + s.duration, 0) / task.steps.length;
      
      analysis.predictions.averageStepDuration = avgStepDuration;
      
      const slowSteps = task.steps.filter(s => s.duration > avgStepDuration * 2);
      if (slowSteps.length > 0) {
        analysis.concerns.push(`${slowSteps.length} steps running slower than average`);
      }
    }

    return analysis;
  }

  analyzeTaskCompletion(task) {
    const analysis = {
      performance: task.performance,
      issues: [],
      insights: [],
      recommendations: []
    };

    // Performance analysis
    if (task.performance.efficiency < 0.7) {
      analysis.issues.push('Low efficiency score');
      analysis.recommendations.push('Review task implementation for optimization opportunities');
    }

    if (task.retryCount > 0) {
      analysis.issues.push(`Task required ${task.retryCount} retries`);
      analysis.recommendations.push('Investigate retry causes for reliability improvements');
    }

    if (task.warnings.length > 0) {
      analysis.issues.push(`Task generated ${task.warnings.length} warnings`);
    }

    // Compare with baseline
    const baseline = this.performanceBaselines.get(task.type);
    if (baseline) {
      if (task.duration > baseline.avgDuration * 1.5) {
        analysis.issues.push('Task duration significantly above baseline');
      }
      
      if (task.duration < baseline.avgDuration * 0.5) {
        analysis.insights.push('Task completed faster than typical');
      }
    }

    return analysis;
  }

  calculateTaskPerformance(task) {
    const performance = {
      efficiency: 1.0,
      reliability: 1.0,
      speed: 1.0,
      overall: 1.0
    };

    // Efficiency based on retries and warnings
    if (task.retryCount > 0) {
      performance.efficiency *= Math.max(0.1, 1 - (task.retryCount * 0.2));
    }
    
    if (task.warnings.length > 0) {
      performance.efficiency *= Math.max(0.5, 1 - (task.warnings.length * 0.1));
    }

    // Reliability based on completion status
    switch (task.status) {
      case 'completed':
        performance.reliability = 1.0;
        break;
      case 'failed':
        performance.reliability = 0.0;
        break;
      case 'cancelled':
        performance.reliability = 0.3;
        break;
      case 'timeout':
        performance.reliability = 0.2;
        break;
    }

    // Speed based on expected vs actual duration
    if (task.expectedDuration && task.duration) {
      const speedRatio = task.expectedDuration / (task.duration / 1000);
      performance.speed = Math.min(1.0, Math.max(0.1, speedRatio));
    }

    // Overall score
    performance.overall = (
      performance.efficiency * 0.3 +
      performance.reliability * 0.5 +
      performance.speed * 0.2
    );

    return performance;
  }

  updatePerformanceBaseline(task) {
    if (task.status !== 'completed') return;

    const baseline = this.performanceBaselines.get(task.type) || {
      count: 0,
      totalDuration: 0,
      avgDuration: 0,
      successCount: 0,
      successRate: 0
    };

    baseline.count++;
    baseline.totalDuration += task.duration;
    baseline.avgDuration = baseline.totalDuration / baseline.count;
    
    if (task.status === 'completed') {
      baseline.successCount++;
    }
    baseline.successRate = baseline.successCount / baseline.count;

    this.performanceBaselines.set(task.type, baseline);
  }

  addToHistory(task) {
    this.taskHistory.push({
      id: task.id,
      type: task.type,
      startTime: task.startTime,
      endTime: task.endTime,
      duration: task.duration,
      status: task.status,
      agentId: task.agentId,
      retryCount: task.retryCount,
      performance: task.performance
    });

    // Maintain history size
    if (this.taskHistory.length > this.maxHistorySize) {
      this.taskHistory.shift();
    }
  }

  checkTaskTimeout(taskId) {
    const task = this.activeTasks.get(taskId);
    if (!task) return;

    const age = Date.now() - task.startTime.getTime();
    if (age > this.maxActiveTaskAge) {
      // Force timeout
      this.trackTaskCompletion({
        taskId,
        status: 'timeout',
        reason: 'exceeded_maximum_age',
        timestamp: Date.now()
      });
    }
  }

  cleanupCompletedTasks() {
    const cutoff = Date.now() - (24 * 60 * 60 * 1000); // 24 hours
    
    for (const [taskId, task] of this.completedTasks.entries()) {
      if (task.endTime.getTime() < cutoff) {
        this.completedTasks.delete(taskId);
      }
    }

    // Keep only last 1000 completed tasks
    if (this.completedTasks.size > 1000) {
      const sorted = Array.from(this.completedTasks.entries())
        .sort((a, b) => b[1].endTime - a[1].endTime)
        .slice(0, 1000);
      
      this.completedTasks.clear();
      for (const [id, task] of sorted) {
        this.completedTasks.set(id, task);
      }
    }
  }

  async getTaskExecutionStats() {
    const stats = {
      ...this.taskMetrics,
      activeTasks: this.activeTasks.size,
      completedTasks: this.completedTasks.size,
      taskTypes: Object.fromEntries(this.taskTypes),
      performanceBaselines: Object.fromEntries(this.performanceBaselines),
      averageTaskDuration: this.calculateAverageTaskDuration(),
      successRate: this.calculateSuccessRate(),
      topFailureReasons: this.getTopFailureReasons(),
      agentPerformance: this.getAgentPerformance()
    };

    return stats;
  }

  calculateAverageTaskDuration() {
    if (this.taskHistory.length === 0) return 0;
    
    const totalDuration = this.taskHistory
      .filter(t => t.duration)
      .reduce((sum, t) => sum + t.duration, 0);
    
    return totalDuration / this.taskHistory.length;
  }

  calculateSuccessRate() {
    const total = this.taskMetrics.totalCompleted + this.taskMetrics.totalFailed;
    return total > 0 ? this.taskMetrics.totalCompleted / total : 0;
  }

  getTopFailureReasons() {
    const reasons = new Map();
    
    for (const task of this.completedTasks.values()) {
      if (task.status === 'failed' && task.errors.length > 0) {
        for (const error of task.errors) {
          const reason = error.type || error.code || 'unknown';
          reasons.set(reason, (reasons.get(reason) || 0) + 1);
        }
      }
    }

    return Array.from(reasons.entries())
      .sort((a, b) => b[1] - a[1])
      .slice(0, 10)
      .map(([reason, count]) => ({ reason, count }));
  }

  getAgentPerformance() {
    const agentStats = new Map();
    
    for (const task of this.taskHistory) {
      if (!task.agentId) continue;
      
      const stats = agentStats.get(task.agentId) || {
        totalTasks: 0,
        completedTasks: 0,
        failedTasks: 0,
        avgDuration: 0,
        totalDuration: 0
      };
      
      stats.totalTasks++;
      stats.totalDuration += task.duration || 0;
      stats.avgDuration = stats.totalDuration / stats.totalTasks;
      
      if (task.status === 'completed') {
        stats.completedTasks++;
      } else if (task.status === 'failed') {
        stats.failedTasks++;
      }
      
      agentStats.set(task.agentId, stats);
    }

    return Object.fromEntries(agentStats);
  }

  async getCurrentTasks() {
    return Array.from(this.activeTasks.values());
  }

  async getTaskDetails(taskId) {
    return this.activeTasks.get(taskId) || this.completedTasks.get(taskId);
  }

  async initialize() {
    // Initialize any required resources
  }

  async cleanup() {
    this.cleanupCompletedTasks();
    
    // Clean up stale active tasks
    const staleTime = Date.now() - this.maxActiveTaskAge;
    for (const [taskId, task] of this.activeTasks.entries()) {
      if (task.startTime.getTime() < staleTime) {
        this.trackTaskCompletion({
          taskId,
          status: 'timeout',
          reason: 'cleanup_stale_task'
        });
      }
    }
  }

  async shutdown() {
    // Force complete all active tasks
    for (const taskId of this.activeTasks.keys()) {
      this.trackTaskCompletion({
        taskId,
        status: 'cancelled',
        reason: 'service_shutdown'
      });
    }
  }
}

module.exports = TaskExecutionAnalyzer;