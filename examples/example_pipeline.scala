import com.streamforge.engine.dsl.DSL._

/**
 * Example pipeline demonstrating StreamForge capabilities
 * 
 * Scenario: Real-time click stream analysis
 * - Filter invalid events
 * - Window by 5-minute sliding windows
 * - Aggregate clicks by source
 * - Output to dashboard
 */
object ClickStreamPipeline {
  
  def main(args: Array[String]): Unit = {
    // Define pipeline using DSL
    val pipeline = stream("click-events")
      // Filter out bot traffic
      .filter(event => {
        val userAgent = event.getPayload.get("userAgent").toString
        !userAgent.contains("bot") && !userAgent.contains("crawler")
      })
      
      // Enrich with session information
      .map(event => {
        import scala.jdk.CollectionConverters._
        val payload = event.getPayload.asScala.toMap
        val enrichedPayload = payload + ("sessionId" -> generateSessionId(event))
        event.withMetadata("enriched", "true")
      })
      
      // Apply sliding window (5 min window, 1 min slide)
      .window(sliding(5.minutes, 1.minute))
      
      // Aggregate clicks per source
      .aggregate(
        key = _.getSource,
        aggregator = count()
      )
      
      // Filter for high-traffic sources
      .filter(event => {
        event.getPayload.get("value").toString.toInt > 100
      })
      
      // Output to dashboard
      .sink("dashboard")
    
    println("Pipeline definition:")
    println(pipeline)
  }
  
  private def generateSessionId(event: com.streamforge.models.Event): String = {
    // Simple session ID generation
    s"${event.getSource}-${event.getTimestamp.toEpochMilli / (30 * 60 * 1000)}"
  }
}

/**
 * Example 2: Batch processing for historical data
 */
object HistoricalDataProcessor {
  
  def main(args: Array[String]): Unit = {
    val pipeline = stream("historical-logs")
      // Parse log format
      .map(event => {
        import scala.jdk.CollectionConverters._
        val logLine = event.getPayload.get("raw").toString
        val parts = logLine.split("\\s+")
        
        val parsedPayload = Map(
          "timestamp" -> parts(0),
          "level" -> parts(1),
          "message" -> parts.drop(2).mkString(" ")
        ).map { case (k, v) => k -> v.asInstanceOf[Object] }.asJava
        
        new com.streamforge.models.Event(
          event.getId,
          "parsed-log",
          event.getTimestamp,
          event.getSource,
          parsedPayload,
          event.getMetadata
        )
      })
      
      // Filter errors only
      .filter(_.getPayload.get("level").toString == "ERROR")
      
      // Window by hour
      .window(tumbling(1.hour))
      
      // Count errors per hour
      .aggregate(_ => "global", count())
      
      .sink("error-report")
    
    println("Batch pipeline created")
  }
}

/**
 * Example 3: Complex multi-stage pipeline with state
 */
object FraudDetectionPipeline {
  
  def main(args: Array[String]): Unit = {
    val pipeline = stream("transactions")
      // Validate transaction format
      .filter(event => {
        val payload = event.getPayload
        payload.containsKey("amount") && 
        payload.containsKey("userId") &&
        payload.containsKey("merchantId")
      })
      
      // Detect high-value transactions
      .map(event => {
        val amount = event.getPayload.get("amount").toString.toDouble
        if (amount > 5000) {
          event.withMetadata("highValue", "true")
        } else {
          event
        }
      })
      
      // Session window: group by inactivity
      .window(session(gap = 10.minutes))
      
      // Aggregate transaction count and total per user
      .aggregate(
        key = event => event.getPayload.get("userId").toString,
        aggregator = Custom { events =>
          import scala.jdk.CollectionConverters._
          
          val userId = events.head.getPayload.get("userId")
          val totalAmount = events.map(
            _.getPayload.get("amount").toString.toDouble
          ).sum
          val count = events.size
          
          val payload = Map(
            "userId" -> userId,
            "transactionCount" -> Int.box(count),
            "totalAmount" -> Double.box(totalAmount),
            "avgAmount" -> Double.box(totalAmount / count)
          ).asJava
          
          new com.streamforge.models.Event(
            s"fraud-check-${userId}",
            "fraud-analysis",
            java.time.Instant.now(),
            "fraud-detector",
            payload,
            Map("windowSize" -> events.size.toString).asJava
          )
        }
      )
      
      // Flag suspicious patterns
      .filter(event => {
        val count = event.getPayload.get("transactionCount").toString.toInt
        val avgAmount = event.getPayload.get("avgAmount").toString.toDouble
        
        // Suspicious if >10 transactions OR avg >$1000
        count > 10 || avgAmount > 1000
      })
      
      .sink("fraud-alerts")
    
    println("Fraud detection pipeline ready")
  }
}
