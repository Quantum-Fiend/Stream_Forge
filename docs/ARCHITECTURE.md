# StreamForge Architecture

## Table of Contents
- [Overview](#overview)
- [System Design](#system-design)
- [Component Architecture](#component-architecture)
- [Data Flow](#data-flow)
- [State Management](#state-management)
- [Fault Tolerance](#fault-tolerance)
- [Scalability](#scalability)

---

## Overview

StreamForge is designed as a layered architecture where each language handles specific responsibilities optimized for its strengths:

- **Scala**: Functional stream processing with immutable data structures
- **Java**: Low-level performance-critical infrastructure
- **Kotlin**: Coroutines for high-throughput async I/O
- **Dart/Flutter**: Reactive UI with real-time updates

---

## System Design

### High-Level Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                        DATA SOURCES                           │
│              (IoT Sensors, Logs, Web Events, etc.)           │
└───────────────────────┬──────────────────────────────────────┘
                        │
                        ▼
┌──────────────────────────────────────────────────────────────┐
│                    INGESTION LAYER (Kotlin)                   │
│  ┌─────────────┐  ┌──────────────┐  ┌───────────────────┐   │
│  │ REST API    │  │ gRPC Service │  │ WebSocket Handler │   │
│  │ (HTTP/JSON) │  │ (Protobuf)   │  │ (Binary Frames)   │   │
│  └─────────────┘  └──────────────┘  └───────────────────┘   │
│                   Coroutines + Backpressure                   │
└───────────────────────┬──────────────────────────────────────┘
                        │
                        ▼
┌──────────────────────────────────────────────────────────────┐
│               PROCESSING ENGINE (Scala + Akka)                │
│  ┌─────────────┐  ┌──────────────┐  ┌───────────────────┐   │
│  │ DSL Parser  │→ │ Stream Graph │→ │ Execution Plan    │   │
│  └─────────────┘  └──────────────┘  └───────────────────┘   │
│                                                               │
│  ┌──────────────────────────────────────────────────────┐   │
│  │              Operators                                │   │
│  │  Map │ Filter │ Window │ Aggregate │ Join │ Stateful │   │
│  └──────────────────────────────────────────────────────┘   │
└───────────────────────┬──────────────────────────────────────┘
                        │
                        ▼
┌──────────────────────────────────────────────────────────────┐
│              INFRASTRUCTURE LAYER (Java)                      │
│  ┌─────────────────┐  ┌────────────────┐  ┌──────────────┐  │
│  │ Checkpoint Mgr  │  │ State Store    │  │ Cluster Coord│  │
│  │ (RocksDB)       │  │ (RocksDB)      │  │ (Curator/ZK) │  │
│  └─────────────────┘  └────────────────┘  └──────────────┘  │
└───────────────────────┬──────────────────────────────────────┘
                        │
                        ▼
┌──────────────────────────────────────────────────────────────┐
│                     STORAGE LAYER                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐   │
│  │ SQL Database │  │ NoSQL Store  │  │ Object Storage   │   │
│  └──────────────┘  └──────────────┘  └──────────────────┘   │
└───────────────────────┬──────────────────────────────────────┘
                        │
                        ▼
┌──────────────────────────────────────────────────────────────┐
│              VISUALIZATION LAYER (Flutter)                    │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                  WebSocket Connection                    │ │
│  └─────────────────────────────────────────────────────────┘ │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐   │
│  │ Cluster Page │  │ Metrics Page │  │ Management Page  │   │
│  └──────────────┘  └──────────────┘  └──────────────────┘   │
└──────────────────────────────────────────────────────────────┘
```

---

## Component Architecture

### 1. Ingestion Layer (Kotlin + Ktor)

**Purpose**: High-throughput event ingestion with backpressure handling

**Key Components**:
- `IngestionAPI`: REST endpoints for event submission
- `BackpressureHandler`: Flow control using Kotlin Channels
- `JobAPI`: Job submission and lifecycle management

**Design Patterns**:
- **Coroutines**: Non-blocking async I/O
- **Channels**: Buffered event queues with backpressure
- **Structured Concurrency**: Automatic cleanup and cancellation

**Implementation**:
```kotlin
class IngestionAPI {
    private val eventChannel = Channel<Event>(capacity = 10000)
    
    suspend fun ingestEvent(event: Event): Boolean {
        return try {
            withTimeout(100) {
                eventChannel.send(event)
            }
            true
        } catch (e: TimeoutCancellationException) {
            false // Backpressure
        }
    }
}
```

---

### 2. Processing Engine (Scala + Akka Streams)

**Purpose**: Execute data processing pipelines with windowing and state

**Key Components**:
- `DSL`: Declarative pipeline definition language
- `StreamProcessor`: Akka Streams runtime
- `Window`: Time-based and count-based windows
- `Operators`: Map, filter, aggregate, join

**Design Patterns**:
- **Reactive Streams**: Backpressure-aware processing
- **Immutability**: All transformations create new instances
- **Type Safety**: Compile-time pipeline validation

**DSL Example**:
```scala
val pipeline = stream("events")
  .filter(_.getType == "click")
  .window(sliding(size = 5.minutes, slide = 1.minute))
  .aggregate(
    key = _.getSource,
    aggregator = sum("value")
  )
  .sink("dashboard")
```

**Stream Graph Execution**:
1. **Parse** DSL into operation sequence
2. **Build** Akka Streams Flow  
3. **Connect** source and sink
4. **Materialize** and start processing

---

### 3. Infrastructure Layer (Java)

**Purpose**: Fault tolerance, state management, cluster coordination

#### Checkpoint Manager

**Responsibilities**:
- Create periodic state snapshots
- Persist to RocksDB
- Restore on failure

**Data Structure**:
```
Checkpoint {
  id: String
  jobId: String
  timestamp: Instant
  offset: Long
  stateSnapshot: Map<String, ByteArray>
}
```

**Recovery Process**:
1. Detect failure
2. Find latest checkpoint for job
3. Restore state from RocksDB
4. Resume from checkpoint offset

#### State Store

**Implementation**: RocksDB with column families

**Features**:
- Key-value storage per operator
- Namespace isolation
- Atomic snapshots
- Efficient scans

**Optimizations**:
- Write-ahead log (WAL)
- Block cache for reads
- LZ4 compression
- Bloom filters

---

## Data Flow

### Event Lifecycle

```
1. INGESTION
   Event arrives → POST /api/ingest/event
   ↓
   Backpressure check (buffer < 90%)
   ↓
   Enqueue to Channel

2. PROCESSING
   Dequeue from Channel
   ↓
   Apply operators (filter, map, window)
   ↓
   Update operator state
   ↓
   Emit results

3. CHECKPOINTING
   Every N events or T seconds:
   ↓
   Snapshot all operator state
   ↓
   Persist to RocksDB
   ↓
   Record checkpoint metadata

4. OUTPUT
   Write to sink (DB, dashboard, Kafka)
   ↓
   Update metrics
   ↓
   Ack to source
```

---

## State Management

### Operator State

Each stateful operator maintains:
- **Local State**: In-memory data structures
- **Snapshots**: Periodic serialized copies
- **Recovery**: Restore from latest snapshot

**Example: Windowed Aggregation**

```scala
class AggregationOperator {
  // In-memory state
  private val windows: Map[Key, Window] = mutable.Map()
  
  // Called periodically
  def snapshot(): Map[String, ByteArray] = {
    windows.map { case (k, w) =>
      k.toString -> serialize(w)
    }
  }
  
  // Called on recovery
  def restore(snapshot: Map[String, ByteArray]): Unit = {
    snapshot.foreach { case (k, bytes) =>
      windows(k) = deserialize(bytes)
    }
  }
}
```

### Global State Coordination

**ZooKeeper** is used for:
- Leader election (job coordinator)
- Node registration
- Configuration management
- Distributed locks

---

## Fault Tolerance

### Exactly-Once Semantics

**Guarantees**:
1. Each event is processed exactly once
2. No duplicate results
3. No data loss on failure

**Mechanism**:
```
Source → Process → Checkpoint → Sink
  ↓         ↓          ↓          ↓
Track    Update    Snapshot    Write
Offset    State      State     Results

On Failure:
1. Restore state from latest checkpoint
2. Rewind source to checkpoint offset
3. Replay events
4. Deduplicate based on event ID
```

### Failure Scenarios

| Scenario | Detection | Recovery |
|----------|-----------|----------|
| Node crash | Heartbeat timeout | Reschedule jobs to healthy nodes |
| Network partition | ZooKeeper session loss | New leader election |
| Operator failure | Exception caught | Restore from checkpoint |
| State corruption | Checksum validation | Fallback to previous checkpoint |

---

## Scalability

### Horizontal Scaling

**Add Nodes**:
```bash
docker-compose scale engine=5
```

**Automatic Rebalancing**:
1. New node joins cluster (registers in ZooKeeper)
2. Coordinator detects topology change
3. Redistribute partitions across nodes
4. Migrate state to new owners

### Partitioning Strategy

- **Key-based**: Hash(key) % partitions
- **Round-robin**: For keyless streams
- **Custom**: User-defined partitioner

### Performance Optimizations

1. **Zero-Copy**: Direct buffer transfers where possible
2. **Batch Processing**: Group events for I/O efficiency
3. **Object Pooling**: Reuse buffers and objects
4. **Lazy Evaluation**: Defer computation until materialization
5. **Parallel Execution**: Multi-threaded operator execution

---

## Monitoring & Observability

### Metrics Collection

**Infrastructure Metrics**:
- CPU, memory, disk I/O per node
- JVM heap and GC stats
- RocksDB compaction stats

**Job Metrics**:
- Events processed / sec
- Processing latency (p50, p95, p99)
- Checkpoint duration
- Backpressure events

**WebSocket Streaming**:
```kotlin
websocket("/ws/metrics") {
    while (true) {
        val metrics = metricsCollector.snapshot()
        send(Frame.Text(json.encode(metrics)))
        delay(1000)
    }
}
```

---

## Security Considerations

1. **Authentication**: API key or JWT for REST endpoints
2. **Encryption**: TLS for all network communication
3. **Authorization**: Role-based access control (RBAC)
4. **Data Privacy**: Redact sensitive fields in logs
5. **Audit Logs**: Track all job submissions and state changes

---

## Future Enhancements

- [ ] Dynamic scaling based on load
- [ ] SQL query interface for ad-hoc analysis
- [ ] Pluggable storage backends (S3, HDFS)
- [ ] Job versioning and rollback
- [ ] Advanced windowing (session with gaps, custom)
- [ ] Geo-distributed deployments

---

**Conclusion**: StreamForge combines battle-tested patterns from industry leaders (Spark, Flink, Kafka) with modern language features to deliver a production-ready distributed processing platform.
