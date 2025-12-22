package com.streamforge.models

import com.fasterxml.jackson.annotation.JsonProperty
import java.time.Instant

/**
 * Base event structure for all data flowing through the platform
 */
data class Event(
    @JsonProperty("id") val id: String,
    @JsonProperty("type") val type: String,
    @JsonProperty("timestamp") val timestamp: Instant,
    @JsonProperty("source") val source: String,
    @JsonProperty("payload") val payload: Map<String, Any>,
    @JsonProperty("metadata") val metadata: Map<String, String> = emptyMap()
) {
    fun withMetadata(key: String, value: String): Event {
        return copy(metadata = metadata + (key to value))
    }
}

/**
 * Job definition for processing pipelines
 */
data class JobDefinition(
    @JsonProperty("id") val id: String,
    @JsonProperty("name") val name: String,
    @JsonProperty("type") val type: JobType,
    @JsonProperty("config") val config: JobConfig,
    @JsonProperty("createdAt") val createdAt: Instant = Instant.now()
)

enum class JobType {
    STREAMING,
    BATCH
}

data class JobConfig(
    @JsonProperty("source") val source: String,
    @JsonProperty("sink") val sink: String,
    @JsonProperty("parallelism") val parallelism: Int = 1,
    @JsonProperty("checkpointInterval") val checkpointInterval: Long = 60000, // ms
    @JsonProperty("maxRetries") val maxRetries: Int = 3
)

/**
 * Job execution status
 */
data class JobStatus(
    @JsonProperty("jobId") val jobId: String,
    @JsonProperty("state") val state: JobState,
    @JsonProperty("startTime") val startTime: Instant?,
    @JsonProperty("endTime") val endTime: Instant?,
    @JsonProperty("eventsProcessed") val eventsProcessed: Long = 0,
    @JsonProperty("lastCheckpoint") val lastCheckpoint: Instant?,
    @JsonProperty("error") val error: String? = null
)

enum class JobState {
    SUBMITTED,
    RUNNING,
    PAUSED,
    COMPLETED,
    FAILED,
    CANCELLED
}

/**
 * Checkpoint metadata
 */
data class Checkpoint(
    @JsonProperty("id") val id: String,
    @JsonProperty("jobId") val jobId: String,
    @JsonProperty("timestamp") val timestamp: Instant,
    @JsonProperty("offset") val offset: Long,
    @JsonProperty("stateSnapshot") val stateSnapshot: Map<String, ByteArray>
)

/**
 * Cluster health metrics
 */
data class ClusterMetrics(
    @JsonProperty("timestamp") val timestamp: Instant,
    @JsonProperty("activeNodes") val activeNodes: Int,
    @JsonProperty("totalJobs") val totalJobs: Int,
    @JsonProperty("runningJobs") val runningJobs: Int,
    @JsonProperty("eventsPerSecond") val eventsPerSecond: Double,
    @JsonProperty("cpuUsage") val cpuUsage: Double,
    @JsonProperty("memoryUsage") val memoryUsage: Double
)
