package com.streamforge.api

import io.ktor.server.application.*
import io.ktor.server.request.*
import io.ktor.server.response.*
import io.ktor.server.routing.*
import io.ktor.http.*
import com.streamforge.models.*
import mu.KotlinLogging
import java.time.Instant
import java.util.concurrent.ConcurrentHashMap
import kotlinx.coroutines.*

private val logger = KotlinLogging.logger {}

/**
 * REST API for job submission, management, and monitoring
 */
class JobAPI {
    private val jobs = ConcurrentHashMap<String, JobStatus>()
    private val jobDefinitions = ConcurrentHashMap<String, JobDefinition>()
    
    fun Application.configureJobRoutes() {
        routing {
            route("/api/jobs") {
                // Submit a new job
                post {
                    try {
                        val jobDef = call.receive<JobDefinition>()
                        
                        // Store job definition
                        jobDefinitions[jobDef.id] = jobDef
                        
                        // Create initial status
                        val status = JobStatus(
                            jobId = jobDef.id,
                            state = JobState.SUBMITTED,
                            startTime = null,
                            endTime = null,
                            eventsProcessed = 0,
                            lastCheckpoint = null,
                            error = null
                        )
                        jobs[jobDef.id] = status
                        
                        logger.info { "Job submitted: ${jobDef.id} - ${jobDef.name}" }
                        
                        // Start job asynchronously
                        CoroutineScope(Dispatchers.Default).launch {
                            startJob(jobDef)
                        }
                        
                        call.respond(HttpStatusCode.Created, status)
                    } catch (e: Exception) {
                        logger.error(e) { "Failed to submit job" }
                        call.respond(
                            HttpStatusCode.BadRequest,
                            mapOf("error" to (e.message ?: "Invalid job definition"))
                        )
                    }
                }
                
                // Get all jobs
                get {
                    call.respond(jobs.values.toList())
                }
                
                // Get specific job status
                get("/{id}") {
                    val jobId = call.parameters["id"] ?: return@get call.respond(
                        HttpStatusCode.BadRequest,
                        mapOf("error" to "Job ID required")
                    )
                    
                    val status = jobs[jobId]
                    if (status != null) {
                        call.respond(status)
                    } else {
                        call.respond(
                            HttpStatusCode.NotFound,
                            mapOf("error" to "Job not found")
                        )
                    }
                }
                
                // Pause a job
                post("/{id}/pause") {
                    val jobId = call.parameters["id"] ?: return@post call.respond(
                        HttpStatusCode.BadRequest,
                        mapOf("error" to "Job ID required")
                    )
                    
                    val status = jobs[jobId]
                    if (status != null && status.state == JobState.RUNNING) {
                        val updated = JobStatus(
                            jobId = status.jobId,
                            state = JobState.PAUSED,
                            startTime = status.startTime,
                            endTime = null,
                            eventsProcessed = status.eventsProcessed,
                            lastCheckpoint = status.lastCheckpoint,
                            error = null
                        )
                        jobs[jobId] = updated
                        logger.info { "Job paused: $jobId" }
                        call.respond(updated)
                    } else {
                        call.respond(
                            HttpStatusCode.BadRequest,
                            mapOf("error" to "Job cannot be paused")
                        )
                    }
                }
                
                // Resume a job
                post("/{id}/resume") {
                    val jobId = call.parameters["id"] ?: return@post call.respond(
                        HttpStatusCode.BadRequest,
                        mapOf("error" to "Job ID required")
                    )
                    
                    val status = jobs[jobId]
                    if (status != null && status.state == JobState.PAUSED) {
                        val updated = JobStatus(
                            jobId = status.jobId,
                            state = JobState.RUNNING,
                            startTime = status.startTime,
                            endTime = null,
                            eventsProcessed = status.eventsProcessed,
                            lastCheckpoint = status.lastCheckpoint,
                            error = null
                        )
                        jobs[jobId] = updated
                        logger.info { "Job resumed: $jobId" }
                        
                        // Resume job execution
                        CoroutineScope(Dispatchers.Default).launch {
                            val jobDef = jobDefinitions[jobId]
                            if (jobDef != null) {
                                startJob(jobDef)
                            }
                        }
                        
                        call.respond(updated)
                    } else {
                        call.respond(
                            HttpStatusCode.BadRequest,
                            mapOf("error" to "Job cannot be resumed")
                        )
                    }
                }
                
                // Cancel a job
                delete("/{id}") {
                    val jobId = call.parameters["id"] ?: return@delete call.respond(
                        HttpStatusCode.BadRequest,
                        mapOf("error" to "Job ID required")
                    )
                    
                    val status = jobs[jobId]
                    if (status != null) {
                        val updated = JobStatus(
                            jobId = status.jobId,
                            state = JobState.CANCELLED,
                            startTime = status.startTime,
                            endTime = Instant.now(),
                            eventsProcessed = status.eventsProcessed,
                            lastCheckpoint = status.lastCheckpoint,
                            error = null
                        )
                        jobs[jobId] = updated
                        logger.info { "Job cancelled: $jobId" }
                        call.respond(updated)
                    } else {
                        call.respond(
                            HttpStatusCode.NotFound,
                            mapOf("error" to "Job not found")
                        )
                    }
                }
            }
        }
    }
    
    private suspend fun startJob(jobDef: JobDefinition) {
        try {
            // Update status to running
            val status = jobs[jobDef.id]?.copy(
                state = JobState.RUNNING,
                startTime = Instant.now()
            ) ?: return
            
            jobs[jobDef.id] = status
            
            logger.info { "Starting job execution: ${jobDef.id}" }
            
            // Simulate job execution (in production, this would invoke the Scala engine)
            delay(100)
            
            // Update events processed periodically
            repeat(10) {
                delay(1000)
                val current = jobs[jobDef.id] ?: return
                if (current.state != JobState.RUNNING) return
                
                jobs[jobDef.id] = current.copy(
                    eventsProcessed = current.eventsProcessed + 100,
                    lastCheckpoint = Instant.now()
                )
            }
            
            // Mark as completed
            val final = jobs[jobDef.id]?.copy(
                state = JobState.COMPLETED,
                endTime = Instant.now()
            )
            if (final != null) {
                jobs[jobDef.id] = final
            }
            
            logger.info { "Job completed: ${jobDef.id}" }
            
        } catch (e: Exception) {
            logger.error(e) { "Job execution failed: ${jobDef.id}" }
            val failed = jobs[jobDef.id]?.copy(
                state = JobState.FAILED,
                endTime = Instant.now(),
                error = e.message
            )
            if (failed != null) {
                jobs[jobDef.id] = failed
            }
        }
    }
}
