package com.streamforge.api

import io.ktor.client.request.*
import io.ktor.client.statement.*
import io.ktor.http.*
import io.ktor.server.testing.*
import kotlin.test.*

class JobAPITest {
    
    @Test
    fun `health endpoint returns healthy status`() = testApplication {
        application {
            configureMonitoring()
            configureSerialization()
            configureRouting()
        }
        
        val response = client.get("/health")
        
        assertEquals(HttpStatusCode.OK, response.status)
        assertTrue(response.bodyAsText().contains("healthy"))
    }
    
    @Test
    fun `submit job returns created status`() = testApplication {
        application {
            configureMonitoring()
            configureSerialization()
            configureHTTP()
            configureRouting()
            with(JobAPI()) { configureJobRoutes() }
        }
        
        val response = client.post("/api/jobs") {
            contentType(ContentType.Application.Json)
            setBody("""
                {
                    "id": "test-job",
                    "name": "Test Job",
                    "type": "STREAMING",
                    "config": {
                        "source": "events",
                        "sink": "output",
                        "parallelism": 1,
                        "checkpointInterval": 60000,
                        "maxRetries": 3
                    }
                }
            """.trimIndent())
        }
        
        assertEquals(HttpStatusCode.Created, response.status)
    }
    
    @Test
    fun `get jobs returns list`() = testApplication {
        application {
            configureSerialization()
            configureRouting()
            with(JobAPI()) { configureJobRoutes() }
        }
        
        val response = client.get("/api/jobs")
        
        assertEquals(HttpStatusCode.OK, response.status)
    }
}
