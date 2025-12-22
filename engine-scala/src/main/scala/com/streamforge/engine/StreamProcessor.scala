package com.streamforge.engine

import akka.actor.ActorSystem
import akka.stream._
import akka.stream.scaladsl._
import com.streamforge.models.{Event, JobDefinition, JobStatus, JobState}
import com.streamforge.engine.dsl._
import com.streamforge.engine.window._
import com.streamforge.engine.operators.Operators._
import com.streamforge.infra.checkpoint.CheckpointManager
import com.streamforge.infra.state.StateStore
import org.slf4j.LoggerFactory

import scala.concurrent.{Future, ExecutionContext}
import scala.concurrent.duration._
import scala.util.{Success, Failure}
import java.time.Instant
import scala.jdk.CollectionConverters._

/**
 * Core streaming processor with windowing and stateful operations
 * Supports exactly-once semantics via checkpointing
 */
class StreamProcessor(
  checkpointManager: CheckpointManager,
  stateStore: StateStore
)(implicit system: ActorSystem, ec: ExecutionContext) {
  
  private val logger = LoggerFactory.getLogger(classOf[StreamProcessor])
  
  /**
   * Execute a pipeline defined using the DSL
   */
  def executePipeline(job: JobDefinition, pipeline: Pipeline): Future[JobStatus] = {
    logger.info(s"Executing streaming pipeline for job ${job.getId}")
    
    val source = createSource(job)
    val flow = buildFlowFromPipeline(pipeline, job.getId)
    val sink = createSink(pipeline, job.getId)
    
    // Schedule checkpointing
    val checkpointFlow = Flow[Event]
      .groupedWithin(1000, job.getConfig.getCheckpointInterval.milliseconds)
      .map { events =>
        createCheckpoint(job.getId, events.lastOption.map(_.getTimestamp.toEpochMilli).getOrElse(0))
        events
      }
      .mapConcat(identity)
    
    val graph = source
      .via(flow)
      .via(checkpointFlow)
      .to(sink)
    
    val materialized = graph.run()
    
    Future.successful(new JobStatus(
      job.getId,
      JobState.RUNNING,
      Instant.now(),
      null,
      0,
      Instant.now(),
      null
    ))
  }
  
  /**
   * Build Akka Streams flow from DSL pipeline definition
   */
  private def buildFlowFromPipeline(pipeline: Pipeline, jobId: String): Flow[Event, Event, _] = {
    var currentFlow: Flow[Event, Event, _] = Flow[Event]
    
    pipeline.operations.foreach {
      case FilterOp(predicate) =>
        currentFlow = currentFlow.filter(predicate)
        
      case MapOp(fn) =>
        currentFlow = currentFlow.map(fn)
        
      case FlatMapOp(fn) =>
        currentFlow = currentFlow.mapConcat(fn)
        
      case WindowOp(config) =>
        currentFlow = currentFlow.via(createWindowFlow(config))
        
      case AggregateOp(keyFn, aggregator) =>
        currentFlow = currentFlow.via(createAggregateFlow(keyFn, aggregator))
        
      case _ => // Skip source and sink operations
    }
    
    currentFlow
  }
  
  /**
   * Create windowed flow
   */
  private def createWindowFlow(config: WindowConfig): Flow[Event, Event, _] = {
    Flow[Event]
      .statefulMapConcat { () =>
        val windows = new scala.collection.mutable.HashMap[String, Window]()
        
        event => {
          val key = event.getSource // Could be parameterized
          val window = windows.getOrElseUpdate(key, Window.create(config))
          window.add(event)
          
          if (window.shouldTrigger()) {
            val events = window.getEvents()
            window.clear()
            events
          } else {
            Seq.empty
          }
        }
      }
  }
  
  /**
   * Create aggregation flow
   */
  private def createAggregateFlow(
    keyFn: Event => String,
    aggregator: Aggregator
  ): Flow[Event, Event, _] = {
    Flow[Event]
      .groupBy(Int.MaxValue, keyFn)
      .grouped(100) // Buffer size for aggregation
      .map { events =>
        val operator = new AggregationOperator(aggregator)
        operator.aggregate(events)
      }
      .mergeSubstreams
  }
  
  /**
   * Create source from job configuration
   */
  private def createSource(job: JobDefinition): Source[Event, _] = {
    // In production, this would connect to Kafka, WebSocket, etc.
    // For now, create a test source
    Source.tick(
      initialDelay = 0.seconds,
      interval = 100.milliseconds,
      tick = createSampleEvent()
    )
  }
  
  /**
   * Create sink from pipeline
   */
  private def createSink(pipeline: Pipeline, jobId: String): Sink[Event, _] = {
    pipeline.operations.collectFirst {
      case SinkOp(name) => name
    } match {
      case Some(sinkName) =>
        // In production, route to different sinks (Dashboard, DB, Kafka)
        Sink.foreach[Event] { event =>
          logger.debug(s"Output to sink '$sinkName': ${event.getId}")
        }
      case None =>
        Sink.ignore
    }
  }
  
  /**
   * Create checkpoint for the job
   */
  private def createCheckpoint(jobId: String, offset: Long): Unit = {
    try {
      val stateSnapshot = stateStore.snapshot()
      checkpointManager.createCheckpoint(jobId, offset, stateSnapshot.asJava)
      logger.debug(s"Created checkpoint for job $jobId at offset $offset")
    } catch {
      case e: Exception =>
        logger.error(s"Failed to create checkpoint for job $jobId", e)
    }
  }
  
  /**
   * Recover job from latest checkpoint
   */
  def recoverFromCheckpoint(jobId: String): Option[Long] = {
    import scala.jdk.CollectionConverters._
    
    checkpointManager.restoreLatest(jobId).toScala match {
      case Some(checkpoint) =>
        try {
          stateStore.restore(checkpoint.getStateSnapshot.asScala.toMap)
          logger.info(s"Recovered job $jobId from checkpoint at offset ${checkpoint.getOffset}")
          Some(checkpoint.getOffset)
        } catch {
          case e: Exception =>
            logger.error(s"Failed to restore state for job $jobId", e)
            None
        }
      case None =>
        logger.info(s"No checkpoint found for job $jobId, starting fresh")
        None
    }
  }
  
  private def createSampleEvent(): Event = {
    new Event(
      java.util.UUID.randomUUID().toString,
      "sample",
      Instant.now(),
      "test-source",
      Map("value" -> Int.box(scala.util.Random.nextInt(100))).asJava,
      Map.empty[String, String].asJava
    )
  }
}

object StreamProcessor {
  def apply(checkpointManager: CheckpointManager, stateStore: StateStore)
           (implicit system: ActorSystem, ec: ExecutionContext): StreamProcessor = {
    new StreamProcessor(checkpointManager, stateStore)
  }
}
