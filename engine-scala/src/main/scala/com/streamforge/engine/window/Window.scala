package com.streamforge.engine.window

import com.streamforge.models.Event
import com.streamforge.engine.dsl.WindowConfig
import com.streamforge.engine.dsl._
import java.time.{Duration, Instant}
import scala.collection.mutable

/**
 * Window implementation for time-based and count-based grouping
 */
sealed trait Window {
  def add(event: Event): Unit
  def shouldTrigger(): Boolean
  def getEvents(): Seq[Event]
  def clear(): Unit
}

/**
 * Sliding window with configurable size and slide
 */
class SlidingWindowImpl(size: Duration, slide: Duration) extends Window {
  private val buffer = new mutable.Queue[Event]()
  private var lastSlide: Instant = Instant.now()
  
  override def add(event: Event): Unit = {
    buffer.enqueue(event)
    
    // Remove events outside window
    val cutoff = event.getTimestamp.minus(size)
    while (buffer.nonEmpty && buffer.head.getTimestamp.isBefore(cutoff)) {
      buffer.dequeue()
    }
  }
  
  override def shouldTrigger(): Boolean = {
    val now = Instant.now()
    val elapsed = Duration.between(lastSlide, now)
    elapsed.compareTo(slide) >= 0
  }
  
  override def getEvents(): Seq[Event] = buffer.toSeq
  
  override def clear(): Unit = {
    lastSlide = Instant.now()
    // Don't clear buffer for sliding windows - they overlap
  }
}

/**
 * Tumbling window - non-overlapping fixed-size windows
 */
class TumblingWindowImpl(size: Duration) extends Window {
  private val buffer = new mutable.ArrayBuffer[Event]()
  private var windowStart: Instant = Instant.now()
  
  override def add(event: Event): Unit = {
    buffer += event
  }
  
  override def shouldTrigger(): Boolean = {
    val now = Instant.now()
    val elapsed = Duration.between(windowStart, now)
    elapsed.compareTo(size) >= 0
  }
  
  override def getEvents(): Seq[Event] = buffer.toSeq
  
  override def clear(): Unit = {
    buffer.clear()
    windowStart = Instant.now()
  }
}

/**
 * Session window - groups events separated by gaps
 */
class SessionWindowImpl(gap: Duration) extends Window {
  private val buffer = new mutable.ArrayBuffer[Event]()
  private var lastEventTime: Option[Instant] = None
  
  override def add(event: Event): Unit = {
    buffer += event
    lastEventTime = Some(event.getTimestamp)
  }
  
  override def shouldTrigger(): Boolean = {
    lastEventTime match {
      case Some(lastTime) =>
        val elapsed = Duration.between(lastTime, Instant.now())
        elapsed.compareTo(gap) >= 0
      case None => false
    }
  }
  
  override def getEvents(): Seq[Event] = buffer.toSeq
  
  override def clear(): Unit = {
    buffer.clear()
    lastEventTime = None
  }
}

/**
 * Count-based window - triggers after N events
 */
class CountWindowImpl(count: Int) extends Window {
  private val buffer = new mutable.ArrayBuffer[Event]()
  
  override def add(event: Event): Unit = {
    buffer += event
  }
  
  override def shouldTrigger(): Boolean = buffer.size >= count
  
  override def getEvents(): Seq[Event] = buffer.toSeq
  
  override def clear(): Unit = {
    buffer.clear()
  }
}

/**
 * Window factory
 */
object Window {
  def create(config: WindowConfig): Window = config match {
    case SlidingWindow(size, slide) => new SlidingWindowImpl(size, slide)
    case TumblingWindow(size) => new TumblingWindowImpl(size)
    case SessionWindow(gap) => new SessionWindowImpl(gap)
    case CountWindow(count) => new CountWindowImpl(count)
  }
}

/**
 * Keyed window manager - manages separate windows per key
 */
class KeyedWindowManager(config: WindowConfig) {
  private val windows = new mutable.HashMap[String, Window]()
  
  def addEvent(key: String, event: Event): Option[(String, Seq[Event])] = {
    val window = windows.getOrElseUpdate(key, Window.create(config))
    window.add(event)
    
    if (window.shouldTrigger()) {
      val events = window.getEvents()
      window.clear()
      Some((key, events))
    } else {
      None
    }
  }
  
  def forceFlush(): Seq[(String, Seq[Event])] = {
    val results = windows.flatMap { case (key, window) =>
      val events = window.getEvents()
      if (events.nonEmpty) {
        window.clear()
        Some((key, events))
      } else {
        None
      }
    }.toSeq
    
    results
  }
  
  def clear(): Unit = {
    windows.clear()
  }
}
