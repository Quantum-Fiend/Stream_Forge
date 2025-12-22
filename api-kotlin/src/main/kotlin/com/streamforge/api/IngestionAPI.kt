package com.streamforge.api

import io.ktor.server.application.*
import io.ktor.server.request.*
import io.ktor.server.response.*
import io.ktor.server.routing.*
import io.ktor.http.*
import com.streamforge.models.Event
import kotlinx.coroutines.*
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.*
import mu.KotlinLogging
import java.util.concurrent.atomic.AtomicLong

private val logger = KotlinLogging.logger {}

/**
 * High-throughput event ingestion API with backpressure handling
 */
class IngestionAPI {
    private val eventChannel = Channel<Event>(capacity = 10000)
    private val eventsIngested = AtomicLong(0)
    private val eventsDropped = AtomicLong(0)
    
    init {
        // Start background processor
        CoroutineScope(Dispatchers.Default).launch {
            processEvents()
        }
    }
    
    fun Application.configureIngestionRoutes() {
        routing {
            route("/api/ingest") {
                // Ingest single event
                post("/event") {
                    try {
                        val event = call.receive<Event>()
                        val success = ingestEvent(event)
                        
                        if (success) {
                            call.respond(
                                HttpStatusCode.Accepted,
                                mapOf("status" to "accepted", "eventId" to event.id)
                            )
                        } else {
                            eventsDropped.incrementAndGet()
                            call.respond(
                                HttpStatusCode.ServiceUnavailable,
                                mapOf("error" to "Buffer full, event dropped")
                            )
                        }
                    } catch (e: Exception) {
                        logger.error(e) { "Failed to ingest event" }
                        call.respond(
                            HttpStatusCode.BadRequest,
                            mapOf("error" to (e.message ?: "Invalid event"))
                        )
                    }
                }
                
                // Batch ingest multiple events
                post("/batch") {
                    try {
                        val events = call.receive<List<Event>>()
                        
                        val results = events.map { event ->
                            ingestEvent(event)
                        }
                        
                        val accepted = results.count { it }
                        val dropped = results.size - accepted
                        
                        eventsDropped.addAndGet(dropped.toLong())
                        
                        call.respond(
                            HttpStatusCode.Accepted,
                            mapOf(
                                "total" to events.size,
                                "accepted" to accepted,
                                "dropped" to dropped
                            )
                        )
                    } catch (e: Exception) {
                        logger.error(e) { "Failed to ingest batch" }
                        call.respond(
                            HttpStatusCode.BadRequest,
                            mapOf("error" to (e.message ?: "Invalid batch"))
                        )
                    }
                }
                
                // Get ingestion stats
                get("/stats") {
                    call.respond(
                        mapOf(
                            "eventsIngested" to eventsIngested.get(),
                            "eventsDropped" to eventsDropped.get(),
                            "bufferSize" to eventChannel.toString(),
                            "throughput" to calculateThroughput()
                        )
                    )
                }
            }
        }
    }
    
    /**
     * Ingest event with backpressure handling
     */
    private suspend fun ingestEvent(event: Event): Boolean {
        return try {
            // Try to offer with timeout
            withTimeout(100) {
                eventChannel.send(event)
            }
            eventsIngested.incrementAndGet()
            true
        } catch (e: TimeoutCancellationException) {
            logger.warn { "Event buffer full, dropping event ${event.id}" }
            false
        }
    }
    
    /**
     * Process events from channel
     */
    private suspend fun processEvents() {
        eventChannel.consumeAsFlow()
            .buffer(capacity = 1000)
            .collect { event ->
                try {
                    // In production, this would forward to the processing engine
                    processEvent(event)
                } catch (e: Exception) {
                    logger.error(e) { "Failed to process event ${event.id}" }
                }
            }
    }
    
    private suspend fun processEvent(event: Event) {
        // Simulate processing delay
        delay(1)
        logger.debug { "Processed event: ${event.id}" }
    }
    
    private fun calculateThroughput(): Double {
        // Simple throughput calculation (events per second)
        // In production, this would track time windows
        return eventsIngested.get() / 60.0
    }
}

/**
 * Backpressure handler for managing flow control
 */
class BackpressureHandler(
    private val maxBufferSize: Int = 10000,
    private val dropThreshold: Double = 0.9
) {
    private val buffer = Channel<Event>(capacity = maxBufferSize)
    private val metrics = BackpressureMetrics()
    
    suspend fun offer(event: Event): Boolean {
        val currentLoad = getCurrentLoad()
        
        return when {
            currentLoad < dropThreshold -> {
                buffer.send(event)
                metrics.recordAccepted()
                true
            }
            else -> {
                metrics.recordDropped()
                false
            }
        }
    }
    
    suspend fun poll(): Event? {
        return buffer.tryReceive().getOrNull()
    }
    
    fun getCurrentLoad(): Double {
        // Estimate based on channel state
        return 0.5 // Simplified
    }
    
    fun getMetrics(): BackpressureMetrics = metrics
    
    data class BackpressureMetrics(
        var accepted: Long = 0,
        var dropped: Long = 0,
        var throttled: Long = 0
    ) {
        fun recordAccepted() { accepted++ }
        fun recordDropped() { dropped++ }
        fun recordThrottled() { throttled++ }
    }
}
