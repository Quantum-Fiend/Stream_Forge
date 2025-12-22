package com.streamforge.api.scheduler

import kotlinx.coroutines.*
import mu.KotlinLogging
import org.quartz.*
import org.quartz.impl.StdSchedulerFactory
import java.time.Instant
import java.util.concurrent.ConcurrentHashMap

private val logger = KotlinLogging.logger {}

/**
 * Job scheduler using Quartz for cron-based and interval-based scheduling
 */
class Scheduler {
    private val quartzScheduler: org.quartz.Scheduler = StdSchedulerFactory.getDefaultScheduler()
    private val scheduledJobs = ConcurrentHashMap<String, ScheduledJobInfo>()
    
    init {
        quartzScheduler.start()
        logger.info { "Scheduler initialized" }
    }
    
    /**
     * Schedule a job to run at fixed intervals
     */
    suspend fun scheduleInterval(
        jobId: String,
        intervalSeconds: Long,
        action: suspend () -> Unit
    ): String {
        return withContext(Dispatchers.Default) {
            val scheduleId = "schedule-$jobId-${System.currentTimeMillis()}"
            
            val job = JobBuilder.newJob(CoroutineJob::class.java)
                .withIdentity(scheduleId, "streamforge")
                .usingJobData("jobId", jobId)
                .build()
            
            val trigger = TriggerBuilder.newTrigger()
                .withIdentity("trigger-$scheduleId", "streamforge")
                .startNow()
                .withSchedule(
                    SimpleScheduleBuilder.simpleSchedule()
                        .withIntervalInSeconds(intervalSeconds.toInt())
                        .repeatForever()
                )
                .build()
            
            // Store the action in the job registry
            CoroutineJobRegistry.register(scheduleId, action)
            
            quartzScheduler.scheduleJob(job, trigger)
            
            scheduledJobs[scheduleId] = ScheduledJobInfo(
                scheduleId = scheduleId,
                jobId = jobId,
                type = ScheduleType.INTERVAL,
                schedule = "${intervalSeconds}s",
                nextRun = Instant.now().plusSeconds(intervalSeconds)
            )
            
            logger.info { "Scheduled job $jobId with interval ${intervalSeconds}s" }
            scheduleId
        }
    }
    
    /**
     * Schedule a job using cron expression
     */
    suspend fun scheduleCron(
        jobId: String,
        cronExpression: String,
        action: suspend () -> Unit
    ): String {
        return withContext(Dispatchers.Default) {
            val scheduleId = "schedule-$jobId-${System.currentTimeMillis()}"
            
            val job = JobBuilder.newJob(CoroutineJob::class.java)
                .withIdentity(scheduleId, "streamforge")
                .usingJobData("jobId", jobId)
                .build()
            
            val trigger = TriggerBuilder.newTrigger()
                .withIdentity("trigger-$scheduleId", "streamforge")
                .startNow()
                .withSchedule(CronScheduleBuilder.cronSchedule(cronExpression))
                .build()
            
            CoroutineJobRegistry.register(scheduleId, action)
            
            quartzScheduler.scheduleJob(job, trigger)
            
            scheduledJobs[scheduleId] = ScheduledJobInfo(
                scheduleId = scheduleId,
                jobId = jobId,
                type = ScheduleType.CRON,
                schedule = cronExpression,
                nextRun = trigger.nextFireTime?.toInstant() ?: Instant.now()
            )
            
            logger.info { "Scheduled job $jobId with cron expression: $cronExpression" }
            scheduleId
        }
    }
    
    /**
     * Cancel a scheduled job
     */
    suspend fun cancelSchedule(scheduleId: String): Boolean {
        return withContext(Dispatchers.Default) {
            val jobKey = JobKey.jobKey(scheduleId, "streamforge")
            val result = quartzScheduler.deleteJob(jobKey)
            
            if (result) {
                scheduledJobs.remove(scheduleId)
                CoroutineJobRegistry.unregister(scheduleId)
                logger.info { "Cancelled schedule $scheduleId" }
            }
            
            result
        }
    }
    
    /**
     * Get all scheduled jobs
     */
    fun getScheduledJobs(): List<ScheduledJobInfo> {
        return scheduledJobs.values.toList()
    }
    
    /**
     * Pause a scheduled job
     */
    suspend fun pauseSchedule(scheduleId: String) {
        withContext(Dispatchers.Default) {
            val jobKey = JobKey.jobKey(scheduleId, "streamforge")
            quartzScheduler.pauseJob(jobKey)
            logger.info { "Paused schedule $scheduleId" }
        }
    }
    
    /**
     * Resume a paused job
     */
    suspend fun resumeSchedule(scheduleId: String) {
        withContext(Dispatchers.Default) {
            val jobKey = JobKey.jobKey(scheduleId, "streamforge")
            quartzScheduler.resumeJob(jobKey)
            logger.info { "Resumed schedule $scheduleId" }
        }
    }
    
    fun shutdown() {
        quartzScheduler.shutdown(true)
        logger.info { "Scheduler shut down" }
    }
}

/**
 * Quartz job that executes Kotlin coroutines
 */
class CoroutineJob : Job {
    override fun execute(context: JobExecutionContext) {
        val scheduleId = context.jobDetail.jobDataMap.getString("jobId")
        val action = CoroutineJobRegistry.get(context.jobDetail.key.name)
        
        if (action != null) {
            runBlocking {
                try {
                    action()
                } catch (e: Exception) {
                    logger.error(e) { "Scheduled job execution failed: $scheduleId" }
                }
            }
        }
    }
}

/**
 * Registry to store coroutine actions for Quartz jobs
 */
object CoroutineJobRegistry {
    private val actions = ConcurrentHashMap<String, suspend () -> Unit>()
    
    fun register(scheduleId: String, action: suspend () -> Unit) {
        actions[scheduleId] = action
    }
    
    fun get(scheduleId: String): (suspend () -> Unit)? {
        return actions[scheduleId]
    }
    
    fun unregister(scheduleId: String) {
        actions.remove(scheduleId)
    }
}

data class ScheduledJobInfo(
    val scheduleId: String,
    val jobId: String,
    val type: ScheduleType,
    val schedule: String,
    val nextRun: Instant
)

enum class ScheduleType {
    INTERVAL,
    CRON
}
