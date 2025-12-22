package com.streamforge.api

import io.ktor.server.application.*
import io.ktor.server.response.*
import io.ktor.server.routing.*
import io.ktor.server.websocket.*
import io.ktor.websocket.*
import kotlinx.coroutines.*
import mu.KotlinLogging
import java.time.Instant

private val logger = KotlinLogging.logger {}

/**
 * Real-time metrics streaming via WebSocket
 */
class MetricsAPI {
    private val metricsCollector = MetricsCollector()
    
    fun Application.configureMetricsRoutes() {
        routing {
            // REST endpoint for cluster metrics
            get("/api/metrics/cluster") {
                val metrics = metricsCollector.getClusterMetrics()
                call.respond(metrics)
            }
            
            // WebSocket for real-time streaming
            webSocket("/ws/metrics") {
                logger.info { "New WebSocket connection for metrics" }
                
                try {
                    while (true) {
                        val metrics = metricsCollector.getClusterMetrics()
                        send(Frame.Text(metricsCollector.toJson(metrics)))
                        delay(1000)
                    }
                } catch (e: Exception) {
                    logger.debug { "WebSocket closed: ${e.message}" }
                }
            }
        }
    }
}

class MetricsCollector {
    fun getClusterMetrics(): Map<String, Any> {
        return mapOf(
            "timestamp" to Instant.now().toString(),
            "activeNodes" to 3,
            "totalJobs" to 12,
            "runningJobs" to 5,
            "eventsPerSecond" to (1000 + (System.currentTimeMillis() % 500)),
            "cpuUsage" to (60.0 + (System.currentTimeMillis() % 30)),
            "memoryUsage" to (70.0 + (System.currentTimeMillis() % 20))
        )
    }
    
    fun toJson(data: Map<String, Any>): String {
        return data.entries.joinToString(",", "{", "}") { (k, v) ->
            "\"$k\":${if (v is String) "\"$v\"" else v}"
        }
    }
}
