package com.streamforge.engine.dsl

import org.scalatest.flatspec.AnyFlatSpec
import org.scalatest.matchers.should.Matchers
import com.streamforge.engine.window._
import DSL._
import java.time.Duration

class DSLSpec extends AnyFlatSpec with Matchers {
  
  "Pipeline DSL" should "create a simple filter pipeline" in {
    val pipeline = stream("events")
      .filter(_.getType == "click")
      .sink("output")
    
    pipeline.operations should have length 3
    pipeline.operations.head shouldBe a [SourceOp]
    pipeline.operations(1) shouldBe a [FilterOp]
    pipeline.operations.last shouldBe a [SinkOp]
  }
  
  it should "chain multiple operations" in {
    val pipeline = stream("events")
      .filter(_ => true)
      .map(e => e)
      .filter(_ => true)
      .sink("output")
    
    pipeline.operations should have length 5
  }
  
  it should "support windowing" in {
    val pipeline = stream("events")
      .window(sliding(Duration.ofMinutes(5), Duration.ofMinutes(1)))
      .sink("output")
    
    pipeline.operations should have length 3
    pipeline.operations(1) shouldBe a [WindowOp]
  }
  
  it should "support aggregations" in {
    val pipeline = stream("events")
      .aggregate(_.getSource, sum("value"))
      .sink("output")
    
    pipeline.operations should have length 3
    pipeline.operations(1) shouldBe a [AggregateOp]
  }
  
  "Window configurations" should "create sliding windows" in {
    val config = sliding(Duration.ofMinutes(5), Duration.ofMinutes(1))
    config shouldBe a [SlidingWindow]
  }
  
  it should "create tumbling windows" in {
    val config = tumbling(Duration.ofHours(1))
    config shouldBe a [TumblingWindow]
  }
  
  it should "create session windows" in {
    val config = session(Duration.ofMinutes(10))
    config shouldBe a [SessionWindow]
  }
  
  it should "create count-based windows" in {
    val config = countBased(100)
    config shouldBe a [CountWindow]
  }
  
  "Aggregators" should "create sum aggregator" in {
    val agg = sum("value")
    agg shouldBe Sum("value")
  }
  
  it should "create count aggregator" in {
    val agg = count()
    agg shouldBe Count()
  }
  
  it should "create average aggregator" in {
    val agg = avg("value")
    agg shouldBe Average("value")
  }
}
