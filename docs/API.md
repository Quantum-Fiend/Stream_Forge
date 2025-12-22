# StreamForge API Reference

## Table of Contents
- [Base URL](#base-url)
- [Authentication](#authentication)
- [Job Management API](#job-management-api)
- [Event Ingestion API](#event-ingestion-api)
- [Metrics API](#metrics-api)
- [Models](#models)

---

## Base URL

```
http://localhost:8080
```

For production deployments, replace with your actual domain.

---

## Authentication

Currently operates in development mode without authentication. For production:

```http
Authorization: Bearer <your-api-key>
```

---

## Job Management API

### Submit a Job

**Endpoint**: `POST /api/jobs`

**Description**: Submit a new streaming or batch processing job

**Request Body**:
```json
{
  "id": "job-123",
  "name": "Click Stream Analysis",
  "type": "STREAMING",
  "config": {
    "source": "events",
    "sink": "dashboard",
    "parallelism": 4,
    "checkpointInterval": 60000,
    "maxRetries": 3
  }
}
```

**Response**: `201 Created`
```json
{
  "jobId": "job-123",
  "state": "SUBMITTED",
  "startTime": null,
  "endTime": null,
  "eventsProcessed": 0,
  "lastCheckpoint": null,
  "error": null
}
```

---

### Get Job Status

**Endpoint**: `GET /api/jobs/{jobId}`

**Description**: Retrieve current status of a job

**Response**: `200 OK`
```json
{
  "jobId": "job-123",
  "state": "RUNNING",
  "startTime": "2025-12-22T20:00:00Z",
  "endTime": null,
  "eventsProcessed": 125000,
  "lastCheckpoint": "2025-12-22T20:05:00Z",
  "error": null
}
```

**Job States**:
- `SUBMITTED` - Job accepted but not yet started
- `RUNNING` - Currently processing
- `PAUSED` - Temporarily stopped
- `COMPLETED` - Successfully finished
- `FAILED` - Terminated with error
- `CANCELLED` - Manually cancelled

---

### List All Jobs

**Endpoint**: `GET /api/jobs`

**Description**: Get all jobs in the system

**Response**: `200 OK`
```json
[
  {
    "jobId": "job-123",
    "state": "RUNNING",
    "startTime": "2025-12-22T20:00:00Z",
    "eventsProcessed": 125000
  },
  {
    "jobId": "job-456",
    "state": "COMPLETED",
    "startTime": "2025-12-22T19:00:00Z",
    "endTime": "2025-12-22T19:30:00Z",
    "eventsProcessed": 500000
  }
]
```

---

### Pause a Job

**Endpoint**: `POST /api/jobs/{jobId}/pause`

**Description**: Pause a running job (state persisted)

**Response**: `200 OK`
```json
{
  "jobId": "job-123",
  "state": "PAUSED",
  "eventsProcessed": 125000
}
```

---

### Resume a Job

**Endpoint**: `POST /api/jobs/{jobId}/resume`

**Description**: Resume a paused job from last checkpoint

**Response**: `200 OK`
```json
{
  "jobId": "job-123",
  "state": "RUNNING"
}
```

---

### Cancel a Job

**Endpoint**: `DELETE /api/jobs/{jobId}`

**Description**: Cancel and remove a job

**Response**: `200 OK`
```json
{
  "jobId": "job-123",
  "state": "CANCELLED",
  "endTime": "2025-12-22T20:10:00Z"
}
```

---

## Event Ingestion API

### Ingest Single Event

**Endpoint**: `POST /api/ingest/event`

**Description**: Submit a single event for processing

**Request Body**:
```json
{
  "id": "evt-001",
  "type": "click",
  "timestamp": "2025-12-22T20:00:00Z",
  "source": "web-app",
  "payload": {
    "value": 100,
    "userId": "user-123",
    "page": "/products"
  },
  "metadata": {
    "userAgent": "Mozilla/5.0",
    "ip": "192.168.1.1"
  }
}
```

**Response**: `202 Accepted`
```json
{
  "status": "accepted",
  "eventId": "evt-001"
}
```

**Error Response**: `503 Service Unavailable` (backpressure)
```json
{
  "error": "Buffer full, event dropped"
}
```

---

### Batch Ingest Events

**Endpoint**: `POST /api/ingest/batch`

**Description**: Submit multiple events in a single request

**Request Body**:
```json
[
  {
    "id": "evt-001",
    "type": "click",
    "timestamp": "2025-12-22T20:00:00Z",
    "source": "web-app",
    "payload": {"value": 100}
  },
  {
    "id": "evt-002",
    "type": "click",
    "timestamp": "2025-12-22T20:00:01Z",
    "source": "mobile-app",
    "payload": {"value": 200}
  }
]
```

**Response**: `202 Accepted`
```json
{
  "total": 2,
  "accepted": 2,
  "dropped": 0
}
```

---

### Get Ingestion Stats

**Endpoint**: `GET /api/ingest/stats`

**Description**: Retrieve ingestion metrics

**Response**: `200 OK`
```json
{
  "eventsIngested": 1250000,
  "eventsDropped": 150,
  "throughput": 2083.5
}
```

---

## Metrics API

### Get Cluster Metrics

**Endpoint**: `GET /api/metrics/cluster`

**Description**: Get cluster-wide health metrics

**Response**: `200 OK`
```json
{
  "timestamp": "2025-12-22T20:00:00Z",
  "activeNodes": 3,
  "totalJobs": 12,
  "runningJobs": 5,
  "eventsPerSecond": 1250.5,
  "cpuUsage": 65.3,
  "memoryUsage": 72.1
}
```

---

## Models

### Event

```typescript
{
  id: string,              // Unique event identifier
  type: string,            // Event type (e.g., "click", "purchase")
  timestamp: ISO8601,      // Event timestamp
  source: string,          // Source identifier
  payload: object,         // Event data (flexible schema)
  metadata: object         // Additional metadata
}
```

### JobDefinition

```typescript
{
  id: string,
  name: string,
  type: "STREAMING" | "BATCH",
  config: {
    source: string,
    sink: string,
    parallelism: number,
    checkpointInterval: number,  // milliseconds
    maxRetries: number
  }
}
```

### JobStatus

```typescript
{
  jobId: string,
  state: JobState,
  startTime: ISO8601 | null,
  endTime: ISO8601 | null,
  eventsProcessed: number,
  lastCheckpoint: ISO8601 | null,
  error: string | null
}
```

---

## Error Codes

| Code | Description |
|------|-------------|
| 200 | Success |
| 201 | Created |
| 202 | Accepted (async processing) |
| 400 | Bad Request (invalid input) |
| 404 | Not Found |
| 500 | Internal Server Error |
| 503 | Service Unavailable (backpressure) |

---

## Rate Limiting

Default limits:
- **Event Ingestion**: 10,000 events/second per node
- **API Requests**: 1,000 requests/minute

When limits are exceeded, returns `429 Too Many Requests`.

---

## WebSocket API

### Real-Time Metrics Stream

**Endpoint**: `ws://localhost:8080/ws/metrics`

**Description**: Subscribe to real-time cluster and job metrics

**Message Format**:
```json
{
  "type": "metrics",
  "timestamp": "2025-12-22T20:00:00Z",
  "data": {
    "eventsPerSecond": 1250.5,
    "cpuUsage": 65.3,
    "memoryUsage": 72.1
  }
}
```

**Connection Example**:
```javascript
const ws = new WebSocket('ws://localhost:8080/ws/metrics');
ws.onmessage = (event) => {
  const metrics = JSON.parse(event.data);
  console.log('Metrics:', metrics);
};
```

---

## Example Workflows

### Complete Job Lifecycle

1. **Submit Job**
```bash
curl -X POST http://localhost:8080/api/jobs \
  -H "Content-Type: application/json" \
  -d @job-definition.json
```

2. **Ingest Events**
```bash
curl -X POST http://localhost:8080/api/ingest/event \
  -H "Content-Type: application/json" \
  -d @event.json
```

3. **Monitor Status**
```bash
curl http://localhost:8080/api/jobs/job-123
```

4. **Pause if Needed**
```bash
curl -X POST http://localhost:8080/api/jobs/job-123/pause
```

5. **Resume**
```bash
curl -X POST http://localhost:8080/api/jobs/job-123/resume
```

6. **Cancel When Done**
```bash
curl -X DELETE http://localhost:8080/api/jobs/job-123
```

---

For more examples, see the [GitHub repository](https://github.com/yourusername/streamforge).
