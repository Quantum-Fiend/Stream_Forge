package com.streamforge.engine.window

import org.scalatest.flatspec.AnyFlatSpec
import org.scalatest.matchers.should.Matchers
import com.streamforge.models.Event
import java.time.{Duration, Instant}
import scala.jdk.CollectionConverters._

class WindowSpec extends AnyFlatSpec with Matchers {
  
  private def createEvent(timestamp: Instant = Instant.now()): Event = {
    new Event(
      s"test-${System.nanoTime()}",
      "test",
      timestamp,
      "test-source",
      Map("value" -> Int.box(1)).asJava,
      Map.empty[String, String].asJava
    )
  }
  
  "TumblingWindow" should "trigger after size elapsed" in {
    val window = new TumblingWindowImpl(Duration.ofMillis(100))
    
    window.add(createEvent())
    window.shouldTrigger() shouldBe false
    
    Thread.sleep(150)
    window.shouldTrigger() shouldBe true
  }
  
  it should "clear events after trigger" in {
    val window = new TumblingWindowImpl(Duration.ofMillis(50))
    
    window.add(createEvent())
    window.add(createEvent())
    window.getEvents() should have length 2
    
    window.clear()
    window.getEvents() should have length 0
  }
  
  "CountWindow" should "trigger after count reached" in {
    val window = new CountWindowImpl(3)
    
    window.add(createEvent())
    window.shouldTrigger() shouldBe false
    
    window.add(createEvent())
    window.shouldTrigger() shouldBe false
    
    window.add(createEvent())
    window.shouldTrigger() shouldBe true
  }
  
  "KeyedWindowManager" should "maintain separate windows per key" in {
    import com.streamforge.engine.dsl._
    
    val manager = new KeyedWindowManager(CountWindow(2))
    
    val event1 = createEvent()
    val event2 = createEvent()
    val event3 = createEvent()
    
    manager.addEvent("key1", event1) shouldBe None
    manager.addEvent("key2", event2) shouldBe None
    manager.addEvent("key1", event3) should not be None
  }
  
  it should "force flush all windows" in {
    import com.streamforge.engine.dsl._
    
    val manager = new KeyedWindowManager(CountWindow(10))
    
    manager.addEvent("key1", createEvent())
    manager.addEvent("key2", createEvent())
    
    val flushed = manager.forceFlush()
    flushed should have length 2
  }
}
