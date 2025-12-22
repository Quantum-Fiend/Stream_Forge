package com.streamforge.api

import kotlinx.coroutines.*
import com.streamforge.models.Event
import mu.KotlinLogging
import java.time.Instant
import java.util.UUID
import kotlin.random.Random

private val logger = KotlinLogging.logger {}

/**
 * Sample data generator for testing and demos
 */
class DataGenerator {
    private var running = false
    private var job: Job? = null
    
    /**
     * Generate click stream events
     */
    fun generateClickStream(
        eventsPerSecond: Int = 100,
        onEvent: suspend (Event) -> Unit
    ): Job {
        return CoroutineScope(Dispatchers.Default).launch {
            running = true
            val delayMs = 1000L / eventsPerSecond
            
            while (running && isActive) {
                val event = createClickEvent()
                onEvent(event)
                delay(delayMs)
            }
        }.also { job = it }
    }
    
    /**
     * Generate IoT sensor events
     */
    fun generateIoTEvents(
        eventsPerSecond: Int = 50,
        onEvent: suspend (Event) -> Unit
    ): Job {
        return CoroutineScope(Dispatchers.Default).launch {
            running = true
            val delayMs = 1000L / eventsPerSecond
            
            while (running && isActive) {
                val event = createIoTEvent()
                onEvent(event)
                delay(delayMs)
            }
        }.also { job = it }
    }
    
    /**
     * Generate transaction events
     */
    fun generateTransactions(
        eventsPerSecond: Int = 20,
        onEvent: suspend (Event) -> Unit
    ): Job {
        return CoroutineScope(Dispatchers.Default).launch {
            running = true
            val delayMs = 1000L / eventsPerSecond
            
            while (running && isActive) {
                val event = createTransactionEvent()
                onEvent(event)
                delay(delayMs)
            }
        }.also { job = it }
    }
    
    fun stop() {
        running = false
        job?.cancel()
    }
    
    private fun createClickEvent(): Event {
        val pages = listOf("/home", "/products", "/cart", "/checkout", "/profile")
        val sources = listOf("web", "mobile-ios", "mobile-android")
        
        return Event(
            id = UUID.randomUUID().toString(),
            type = "click",
            timestamp = Instant.now(),
            source = sources.random(),
            payload = mapOf(
                "page" to pages.random(),
                "userId" to "user-${Random.nextInt(1000)}",
                "sessionId" to "sess-${Random.nextInt(10000)}",
                "value" to Random.nextInt(100)
            ),
            metadata = mapOf("generator" to "data-generator")
        )
    }
    
    private fun createIoTEvent(): Event {
        val sensorTypes = listOf("temperature", "humidity", "pressure", "motion")
        val locations = listOf("building-A", "building-B", "warehouse", "office")
        
        return Event(
            id = UUID.randomUUID().toString(),
            type = "sensor-reading",
            timestamp = Instant.now(),
            source = "iot-gateway",
            payload = mapOf(
                "sensorId" to "sensor-${Random.nextInt(100)}",
                "sensorType" to sensorTypes.random(),
                "location" to locations.random(),
                "value" to Random.nextDouble(0.0, 100.0),
                "unit" to "units"
            ),
            metadata = mapOf("generator" to "data-generator")
        )
    }
    
    private fun createTransactionEvent(): Event {
        val merchantTypes = listOf("retail", "restaurant", "online", "gas")
        
        return Event(
            id = UUID.randomUUID().toString(),
            type = "transaction",
            timestamp = Instant.now(),
            source = "payment-gateway",
            payload = mapOf(
                "transactionId" to "txn-${UUID.randomUUID().toString().take(8)}",
                "userId" to "user-${Random.nextInt(1000)}",
                "merchantId" to "merchant-${Random.nextInt(500)}",
                "merchantType" to merchantTypes.random(),
                "amount" to Random.nextDouble(1.0, 5000.0),
                "currency" to "USD"
            ),
            metadata = mapOf("generator" to "data-generator")
        )
    }
}
