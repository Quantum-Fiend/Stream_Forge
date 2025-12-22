package com.streamforge.engine.dsl

import com.streamforge.models.Event
import scala.concurrent.duration.FiniteDuration
import java.time.Duration

/**
 * Custom DSL for defining data processing pipelines
 * Provides fluent API for stream operations
 */
sealed trait PipelineOp

case class SourceOp(name: String) extends PipelineOp
case class FilterOp(predicate: Event => Boolean) extends PipelineOp  
case class MapOp(fn: Event => Event) extends PipelineOp
case class FlatMapOp(fn: Event => Seq[Event]) extends PipelineOp
case class WindowOp(config: WindowConfig) extends PipelineOp
case class AggregateOp(key: Event => String, aggregator: Aggregator) extends PipelineOp
case class SinkOp(name: String) extends PipelineOp

// Window configurations
sealed trait WindowConfig
case class SlidingWindow(size: Duration, slide: Duration) extends WindowConfig
case class TumblingWindow(size: Duration) extends WindowConfig
case class SessionWindow(gap: Duration) extends WindowConfig
case class CountWindow(count: Int) extends WindowConfig

// Aggregation functions
sealed trait Aggregator
case class Sum(field: String) extends Aggregator
case class Count() extends Aggregator
case class Average(field: String) extends Aggregator
case class Min(field: String) extends Aggregator
case class Max(field: String) extends Aggregator
case class Custom(fn: Seq[Event] => Event) extends Aggregator

/**
 * Pipeline builder with fluent API
 */
class Pipeline(val operations: List[PipelineOp] = List.empty) {
  
  def filter(predicate: Event => Boolean): Pipeline = 
    new Pipeline(operations :+ FilterOp(predicate))
  
  def map(fn: Event => Event): Pipeline = 
    new Pipeline(operations :+ MapOp(fn))
  
  def flatMap(fn: Event => Seq[Event]): Pipeline = 
    new Pipeline(operations :+ FlatMapOp(fn))
  
  def window(config: WindowConfig): Pipeline = 
    new Pipeline(operations :+ WindowOp(config))
  
  def aggregate(key: Event => String, aggregator: Aggregator): Pipeline = 
    new Pipeline(operations :+ AggregateOp(key, aggregator))
  
  def sink(name: String): Pipeline = 
    new Pipeline(operations :+ SinkOp(name))
}

/**
 * DSL entry point
 */
object DSL {
  
  def stream(source: String): Pipeline = 
    new Pipeline(List(SourceOp(source)))
  
  // Implicit conversions for duration syntax
  implicit class DurationOps(val value: Int) extends AnyVal {
    def seconds: Duration = Duration.ofSeconds(value.toLong)
    def minutes: Duration = Duration.ofMinutes(value.toLong)
    def hours: Duration = Duration.ofHours(value.toLong)
  }
  
  // Helper for creating aggregators
  def sum(field: String): Aggregator = Sum(field)
  def count(): Aggregator = Count()
  def avg(field: String): Aggregator = Average(field)
  def min(field: String): Aggregator = Min(field)
  def max(field: String): Aggregator = Max(field)
  
  // Helper for creating windows
  def sliding(size: Duration, slide: Duration): WindowConfig = 
    SlidingWindow(size, slide)
  
  def tumbling(size: Duration): WindowConfig = 
    TumblingWindow(size)
  
  def session(gap: Duration): WindowConfig = 
    SessionWindow(gap)
  
  def countBased(count: Int): WindowConfig = 
    CountWindow(count)
}

/**
 * Example usage:
 * 
 * import DSL._
 * 
 * val pipeline = stream("events")
 *   .filter(_.getType == "click")
 *   .window(sliding(5.minutes, 1.minute))
 *   .aggregate(_.getSource, sum("value"))
 *   .sink("dashboard")
 */
