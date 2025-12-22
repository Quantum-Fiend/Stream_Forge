package com.streamforge.engine.operators

import com.streamforge.models.Event
import com.streamforge.engine.dsl._
import java.time.Instant
import scala.collection.mutable

/**
 * Operators for transforming and aggregating events
 */
object Operators {
  
  /**
   * Map operator - transform each event
   */
  class MapOperator(fn: Event => Event) {
    def apply(event: Event): Event = fn(event)
  }
  
  /**
   * Filter operator - select events matching predicate
   */
  class FilterOperator(predicate: Event => Boolean) {
    def apply(event: Event): Boolean = predicate(event)
  }
  
  /**
   * FlatMap operator - transform one event into multiple
   */
  class FlatMapOperator(fn: Event => Seq[Event]) {
    def apply(event: Event): Seq[Event] = fn(event)
  }
  
  /**
   * Aggregation operator - combine events based on aggregation function
   */
  class AggregationOperator(aggregator: Aggregator) {
    
    def aggregate(events: Seq[Event]): Event = aggregator match {
      case Sum(field) => aggregateSum(events, field)
      case Count() => aggregateCount(events)
      case Average(field) => aggregateAverage(events, field)
      case Min(field) => aggregateMin(events, field)
      case Max(field) => aggregateMax(events, field)
      case Custom(fn) => fn(events)
    }
    
    private def aggregateSum(events: Seq[Event], field: String): Event = {
      val total = events.map(e => getNumericValue(e, field)).sum
      createAggregateEvent(events, "sum", Map("value" -> total, "field" -> field))
    }
    
    private def aggregateCount(events: Seq[Event]): Event = {
      createAggregateEvent(events, "count", Map("value" -> events.size))
    }
    
    private def aggregateAverage(events: Seq[Event], field: String): Event = {
      val values = events.map(e => getNumericValue(e, field))
      val avg = if (values.nonEmpty) values.sum / values.size else 0.0
      createAggregateEvent(events, "average", Map("value" -> avg, "field" -> field))
    }
    
    private def aggregateMin(events: Seq[Event], field: String): Event = {
      val min = events.map(e => getNumericValue(e, field)).minOption.getOrElse(0.0)
      createAggregateEvent(events, "min", Map("value" -> min, "field" -> field))
    }
    
    private def aggregateMax(events: Seq[Event], field: String): Event = {
      val max = events.map(e => getNumericValue(e, field)).maxOption.getOrElse(0.0)
      createAggregateEvent(events, "max", Map("value" -> max, "field" -> field))
    }
    
    private def getNumericValue(event: Event, field: String): Double = {
      event.getPayload.get(field) match {
        case value: Number => value.doubleValue()
        case value: String => value.toDoubleOption.getOrElse(0.0)
        case _ => 0.0
      }
    }
    
    private def createAggregateEvent(
      events: Seq[Event], 
      aggType: String, 
      result: Map[String, Any]
    ): Event = {
      val firstEvent = events.headOption.getOrElse(
        throw new IllegalArgumentException("Cannot aggregate empty event sequence")
      )
      
      import scala.jdk.CollectionConverters._
      
      val payload = result.map { case (k, v) => k -> v.asInstanceOf[Object] }.asJava
      val metadata = Map(
        "aggregation" -> aggType,
        "eventCount" -> events.size.toString,
        "windowStart" -> events.map(_.getTimestamp).minBy(_.toEpochMilli).toString,
        "windowEnd" -> events.map(_.getTimestamp).maxBy(_.toEpochMilli).toString
      ).asJava
      
      new Event(
        s"agg-${java.util.UUID.randomUUID()}",
        s"aggregated.$aggType",
        Instant.now(),
        firstEvent.getSource,
        payload,
        metadata
      )
    }
  }
  
  /**
   * Stateful operator - maintains state between events
   */
  class StatefulOperator[S](
    initialState: S,
    updateFn: (S, Event) => (S, Option[Event])
  ) {
    private var state: S = initialState
    
    def apply(event: Event): Option[Event] = {
      val (newState, result) = updateFn(state, event)
      state = newState
      result
    }
    
    def getState: S = state
    def setState(newState: S): Unit = { state = newState }
  }
  
  /**
   * Join operator - combines events from multiple streams
   */
  class JoinOperator(
    leftKey: Event => String,
    rightKey: Event => String,
    windowSize: java.time.Duration
  ) {
    private val leftBuffer = mutable.Map[String, mutable.Queue[Event]]()
    private val rightBuffer = mutable.Map[String, mutable.Queue[Event]]()
    
    def processLeft(event: Event): Seq[Event] = {
      val key = leftKey(event)
      leftBuffer.getOrElseUpdate(key, mutable.Queue.empty).enqueue(event)
      
      // Try to join with right
      rightBuffer.get(key) match {
        case Some(rightEvents) =>
          rightEvents.flatMap(rightEvent => join(event, rightEvent)).toSeq
        case None => Seq.empty
      }
    }
    
    def processRight(event: Event): Seq[Event] = {
      val key = rightKey(event)
      rightBuffer.getOrElseUpdate(key, mutable.Queue.empty).enqueue(event)
      
      // Try to join with left
      leftBuffer.get(key) match {
        case Some(leftEvents) =>
          leftEvents.flatMap(leftEvent => join(leftEvent, event)).toSeq
        case None => Seq.empty
      }
    }
    
    private def join(left: Event, right: Event): Option[Event] = {
      val timeDiff = java.time.Duration.between(left.getTimestamp, right.getTimestamp).abs()
      
      if (timeDiff.compareTo(windowSize) <= 0) {
        import scala.jdk.CollectionConverters._
        
        val combinedPayload = (left.getPayload.asScala ++ right.getPayload.asScala).asJava
        
        Some(new Event(
          s"join-${java.util.UUID.randomUUID()}",
          "joined",
          Instant.now(),
          left.getSource,
          combinedPayload,
          Map("leftId" -> left.getId, "rightId" -> right.getId).asJava
        ))
      } else {
        None
      }
    }
    
    def cleanup(): Unit = {
      val cutoff = Instant.now().minus(windowSize)
      
      def cleanBuffer(buffer: mutable.Map[String, mutable.Queue[Event]]): Unit = {
        buffer.foreach { case (key, queue) =>
          while (queue.nonEmpty && queue.head.getTimestamp.isBefore(cutoff)) {
            queue.dequeue()
          }
          if (queue.isEmpty) {
            buffer.remove(key)
          }
        }
      }
      
      cleanBuffer(leftBuffer)
      cleanBuffer(rightBuffer)
    }
  }
}
