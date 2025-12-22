package com.streamforge.infra.recovery;

import com.streamforge.infra.checkpoint.CheckpointManager;
import com.streamforge.infra.state.StateStore;
import com.streamforge.models.Checkpoint;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.Optional;
import java.util.concurrent.*;

/**
 * Manages fault recovery and job restart logic
 * Coordinates checkpoint restoration and state replay
 */
public class RecoveryManager {
    private static final Logger logger = LoggerFactory.getLogger(RecoveryManager.class);
    
    private final CheckpointManager checkpointManager;
    private final StateStore stateStore;
    private final ScheduledExecutorService healthCheckExecutor;
    private final ConcurrentHashMap<String, JobHealth> jobHealthMap;
    
    public RecoveryManager(CheckpointManager checkpointManager, StateStore stateStore) {
        this.checkpointManager = checkpointManager;
        this.stateStore = stateStore;
        this.healthCheckExecutor = Executors.newScheduledThreadPool(2);
        this.jobHealthMap = new ConcurrentHashMap<>();
        
        // Start health monitoring
        startHealthMonitoring();
    }
    
    /**
     * Attempt to recover a job from failure
     */
    public RecoveryResult recoverJob(String jobId) {
        logger.info("Starting recovery for job {}", jobId);
        
        try {
            // 1. Find latest checkpoint
            Optional<Checkpoint> checkpointOpt = checkpointManager.restoreLatest(jobId);
            
            if (checkpointOpt.isEmpty()) {
                logger.warn("No checkpoint found for job {}, starting from beginning", jobId);
                return new RecoveryResult(jobId, RecoveryStatus.NO_CHECKPOINT, 0);
            }
            
            Checkpoint checkpoint = checkpointOpt.get();
            
            // 2. Restore state from checkpoint
            try {
                stateStore.restore(checkpoint.getStateSnapshot());
                logger.info("Restored state for job {} from checkpoint at offset {}", 
                    jobId, checkpoint.getOffset());
            } catch (Exception e) {
                logger.error("Failed to restore state for job {}", jobId, e);
                return new RecoveryResult(jobId, RecoveryStatus.STATE_RESTORE_FAILED, 0);
            }
            
            // 3. Verify state integrity
            if (!verifyStateIntegrity(jobId)) {
                logger.error("State integrity check failed for job {}", jobId);
                return new RecoveryResult(jobId, RecoveryStatus.INTEGRITY_CHECK_FAILED, 0);
            }
            
            // 4. Mark recovery as successful
            logger.info("Successfully recovered job {} to offset {}", jobId, checkpoint.getOffset());
            return new RecoveryResult(jobId, RecoveryStatus.SUCCESS, checkpoint.getOffset());
            
        } catch (Exception e) {
            logger.error("Recovery failed for job {}", jobId, e);
            return new RecoveryResult(jobId, RecoveryStatus.RECOVERY_FAILED, 0);
        }
    }
    
    /**
     * Register a job for health monitoring
     */
    public void registerJob(String jobId) {
        JobHealth health = new JobHealth(jobId);
        jobHealthMap.put(jobId, health);
        logger.info("Registered job {} for health monitoring", jobId);
    }
    
    /**
     * Update heartbeat for a job
     */
    public void heartbeat(String jobId) {
        JobHealth health = jobHealthMap.get(jobId);
        if (health != null) {
            health.updateHeartbeat();
        }
    }
    
    /**
     * Check if a job is healthy
     */
    public boolean isHealthy(String jobId) {
        JobHealth health = jobHealthMap.get(jobId);
        return health != null && health.isHealthy();
    }
    
    /**
     * Unregister a job from monitoring
     */
    public void unregisterJob(String jobId) {
        jobHealthMap.remove(jobId);
        logger.info("Unregistered job {} from health monitoring", jobId);
    }
    
    /**
     * Get recovery statistics for a job
     */
    public RecoveryStats getStats(String jobId) {
        JobHealth health = jobHealthMap.get(jobId);
        if (health == null) {
            return new RecoveryStats(jobId, 0, 0, true);
        }
        
        return new RecoveryStats(
            jobId,
            health.failureCount,
            health.recoveryCount,
            health.isHealthy()
        );
    }
    
    private void startHealthMonitoring() {
        healthCheckExecutor.scheduleAtFixedRate(() -> {
            try {
                checkJobHealth();
            } catch (Exception e) {
                logger.error("Health check failed", e);
            }
        }, 10, 10, TimeUnit.SECONDS);
    }
    
    private void checkJobHealth() {
        long now = System.currentTimeMillis();
        
        for (JobHealth health : jobHealthMap.values()) {
            long timeSinceHeartbeat = now - health.lastHeartbeat;
            
            if (timeSinceHeartbeat > 30000) { // 30 seconds timeout
                logger.warn("Job {} appears unhealthy, last heartbeat {} ms ago", 
                    health.jobId, timeSinceHeartbeat);
                
                health.markUnhealthy();
                
                // Attempt auto-recovery
                if (health.failureCount < 3) {
                    logger.info("Attempting auto-recovery for job {}", health.jobId);
                    RecoveryResult result = recoverJob(health.jobId);
                    
                    if (result.status == RecoveryStatus.SUCCESS) {
                        health.markRecovered();
                    } else {
                        health.failureCount++;
                    }
                }
            }
        }
    }
    
    private boolean verifyStateIntegrity(String jobId) {
        // In production, implement checksum verification
        // For now, simple existence check
        try {
            stateStore.get("metadata", "jobId");
            return true;
        } catch (Exception e) {
            return false;
        }
    }
    
    public void shutdown() {
        healthCheckExecutor.shutdown();
        try {
            if (!healthCheckExecutor.awaitTermination(5, TimeUnit.SECONDS)) {
                healthCheckExecutor.shutdownNow();
            }
        } catch (InterruptedException e) {
            healthCheckExecutor.shutdownNow();
            Thread.currentThread().interrupt();
        }
    }
    
    private static class JobHealth {
        final String jobId;
        long lastHeartbeat;
        int failureCount;
        int recoveryCount;
        boolean healthy;
        
        JobHealth(String jobId) {
            this.jobId = jobId;
            this.lastHeartbeat = System.currentTimeMillis();
            this.failureCount = 0;
            this.recoveryCount = 0;
            this.healthy = true;
        }
        
        void updateHeartbeat() {
            this.lastHeartbeat = System.currentTimeMillis();
            this.healthy = true;
        }
        
        void markUnhealthy() {
            this.healthy = false;
        }
        
        void markRecovered() {
            this.healthy = true;
            this.recoveryCount++;
        }
        
        boolean isHealthy() {
            return healthy;
        }
    }
    
    public enum RecoveryStatus {
        SUCCESS,
        NO_CHECKPOINT,
        STATE_RESTORE_FAILED,
        INTEGRITY_CHECK_FAILED,
        RECOVERY_FAILED
    }
    
    public static class RecoveryResult {
        public final String jobId;
        public final RecoveryStatus status;
        public final long recoveredOffset;
        
        public RecoveryResult(String jobId, RecoveryStatus status, long recoveredOffset) {
            this.jobId = jobId;
            this.status = status;
            this.recoveredOffset = recoveredOffset;
        }
    }
    
    public static class RecoveryStats {
        public final String jobId;
        public final int failureCount;
        public final int recoveryCount;
        public final boolean healthy;
        
        public RecoveryStats(String jobId, int failureCount, int recoveryCount, boolean healthy) {
            this.jobId = jobId;
            this.failureCount = failureCount;
            this.recoveryCount = recoveryCount;
            this.healthy = healthy;
        }
    }
}
