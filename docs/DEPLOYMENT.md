# StreamForge Deployment Guide

## Table of Contents
- [Local Development](#local-development)
- [Docker Deployment](#docker-deployment)
- [Production Deployment](#production-deployment)
- [Configuration](#configuration)
- [Monitoring](#monitoring)
- [Troubleshooting](#troubleshooting)

---

## Local Development

### Prerequisites

- **JDK 17+**: Required for all JVM components
- **Gradle 8+**: Build tool for backend
- **Flutter 3.0+**: For dashboard development
- **Docker & Docker Compose**: For containerized services

### Build from Source

1. **Clone Repository**
```bash
git clone https://github.com/yourusername/streamforge.git
cd streamforge
```

2. **Build Backend**
```bash
./gradlew build
```

3. **Build Dashboard**
```bash
cd dashboard-flutter
flutter pub get
flutter build web
```

### Run Locally

**Option 1: Docker Compose (Recommended)**
```bash
docker-compose up -d
```

**Option 2: Individual Components**

Terminal 1 - ZooKeeper:
```bash
docker run -p 2181:2181 confluentinc/cp-zookeeper:7.5.0
```

Terminal 2 - API Server:
```bash
./gradlew :api-kotlin:run
```

Terminal 3 - Dashboard:
```bash
cd dashboard-flutter
flutter run -d web-server --web-port 3000
```

---

## Docker Deployment

### Build Images

**Backend API**:
```dockerfile
# Dockerfile.api
FROM gradle:8-jdk17 AS build
WORKDIR /app
COPY . .
RUN ./gradlew :api-kotlin:build

FROM openjdk:17-slim
WORKDIR /app
COPY --from=build /app/api-kotlin/build/libs/*.jar app.jar
EXPOSE 8080
CMD ["java", "-jar", "app.jar"]
```

**Dashboard**:
```dockerfile
# dashboard-flutter/Dockerfile
FROM ghcr.io/cirruslabs/flutter:stable AS build
WORKDIR /app
COPY pubspec.* ./
RUN flutter pub get
COPY . .
RUN flutter build web

FROM nginx:alpine
COPY --from=build /app/build/web /usr/share/nginx/html
EXPOSE 80
```

### Build and Run

```bash
# Build images
docker build -f Dockerfile.api -t streamforge-api .
docker build -f dashboard-flutter/Dockerfile -t streamforge-dashboard ./dashboard-flutter

# Run with docker-compose
docker-compose up -d
```

---

## Production Deployment

### Kubernetes Deployment

**Namespace**:
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: streamforge
```

**API Deployment**:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: streamforge-api
  namespace: streamforge
spec:
  replicas: 3
  selector:
    matchLabels:
      app: streamforge-api
  template:
    metadata:
      labels:
        app: streamforge-api
    spec:
      containers:
      - name: api
        image: streamforge-api:latest
        ports:
        - containerPort: 8080
        env:
        - name: DATA_DIR
          value: /data
        - name: ZOOKEEPER_HOSTS
          value: zookeeper:2181
        volumeMounts:
        - name: data
          mountPath: /data
        resources:
          requests:
            memory: "512Mi"
            cpu: "500m"
          limits:
            memory: "2Gi"
            cpu: "2000m"
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: streamforge-data
---
apiVersion: v1
kind: Service
metadata:
  name: streamforge-api
  namespace: streamforge
spec:
  selector:
    app: streamforge-api
  ports:
  - port: 8080
    targetPort: 8080
  type: LoadBalancer
```

**Engine Deployment**:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: streamforge-engine
  namespace: streamforge
spec:
  replicas: 5
  selector:
    matchLabels:
      app: streamforge-engine
  template:
    metadata:
      labels:
        app: streamforge-engine
    spec:
      containers:
      - name: engine
        image: streamforge-engine:latest
        env:
        - name: DATA_DIR
          value: /data
        - name: API_URL
          value: http://streamforge-api:8080
        volumeMounts:
        - name: data
          mountPath: /data
        resources:
          requests:
            memory: "1Gi"
            cpu: "1000m"
          limits:
            memory: "4Gi"
            cpu: "4000m"
```

**Deploy to Kubernetes**:
```bash
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/api-deployment.yaml
kubectl apply -f k8s/engine-deployment.yaml
kubectl apply -f k8s/dashboard-deployment.yaml
```

---

## Configuration

### Environment Variables

**API Server**:
```bash
DATA_DIR=/data                    # Data directory for checkpoints/state
ZOOKEEPER_HOSTS=zookeeper:2181   # ZooKeeper connection string
SERVER_PORT=8080                  # HTTP server port
LOG_LEVEL=INFO                    # Logging level
```

**Processing Engine**:
```bash
DATA_DIR=/data
API_URL=http://api:8080
PARALLELISM=4                     # Default parallelism
CHECKPOINT_INTERVAL=60000         # Checkpoint interval (ms)
```

**Dashboard**:
```bash
API_BASE_URL=http://localhost:8080
WS_URL=ws://localhost:8080/ws
```

### Configuration Files

**application.conf** (Backend):
```hocon
streamforge {
  cluster {
    node-id = "node-1"
    zookeeper = "localhost:2181"
  }
  
  checkpoints {
    interval = 60 seconds
    retention = 7 days
    dir = ${DATA_DIR}"/checkpoints"
  }
  
  state {
    dir = ${DATA_DIR}"/state"
    cache-size = 64MB
  }
}
```

---

## Monitoring

### Metrics Endpoints

**Health Check**:
```bash
curl http://localhost:8080/health
```

**Cluster Metrics**:
```bash
curl http://localhost:8080/api/metrics/cluster
```

**Job Metrics**:
```bash
curl http://localhost:8080/api/jobs/{jobId}
```

### Prometheus Integration

Add to `prometheus.yml`:
```yaml
scrape_configs:
  - job_name: 'streamforge'
    static_configs:
      - targets: ['localhost:8080']
    metrics_path: '/metrics'
```

### Grafana Dashboard

Import dashboard template from `monitoring/grafana-dashboard.json`

Key metrics to monitor:
- Events per second
- Processing latency (p50, p95, p99)
- Checkpoint duration
- CPU and memory usage
- Active jobs count
- Backpressure events

---

## Scaling

### Horizontal Scaling

**Add more API nodes**:
```bash
docker-compose up -d --scale api=3
```

**Add more engine nodes**:
```bash
docker-compose up -d --scale engine=5
```

**Kubernetes auto-scaling**:
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: streamforge-engine
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: streamforge-engine
  minReplicas: 3
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

### Vertical Scaling

Adjust resource limits in deployment manifests based on workload.

---

## Backup & Recovery

### Backup Checkpoints

```bash
# Backup checkpoint data
tar -czf checkpoints-backup-$(date +%Y%m%d).tar.gz data/checkpoints/

# Backup to S3
aws s3 cp checkpoints-backup-*.tar.gz s3://streamforge-backups/
```

### Restore from Backup

```bash
# Download from S3
aws s3 cp s3://streamforge-backups/checkpoints-backup-20251222.tar.gz .

# Extract
tar -xzf checkpoints-backup-20251222.tar.gz -C data/
```

---

## Troubleshooting

### Common Issues

**Issue**: Jobs not starting
```bash
# Check API logs
docker-compose logs api

# Check ZooKeeper connectivity
telnet localhost 2181
```

**Issue**: High memory usage
```bash
# Increase JVM heap
JAVA_OPTS="-Xmx4g -Xms2g"

# Check RocksDB cache size
# Reduce in application.conf
```

**Issue**: Events being dropped
```bash
# Check ingestion stats
curl http://localhost:8080/api/ingest/stats

# Increase buffer size in IngestionAPI
# Or add more API nodes
```

**Issue**: Slow recovery
```bash
# Check checkpoint size
ls -lh data/checkpoints/

# Reduce checkpoint interval
# Or implement incremental checkpoints
```

### Logs

**View all logs**:
```bash
docker-compose logs -f
```

**View specific service**:
```bash
docker-compose logs -f api
docker-compose logs -f engine
```

**Kubernetes logs**:
```bash
kubectl logs -f deployment/streamforge-api -n streamforge
kubectl logs -f deployment/streamforge-engine -n streamforge
```

---

## Security

### Production Checklist

- [ ] Enable HTTPS/TLS for all endpoints
- [ ] Implement API key authentication
- [ ] Configure firewall rules
- [ ] Enable ZooKeeper authentication
- [ ] Encrypt data at rest (RocksDB encryption)
- [ ] Set up audit logging
- [ ] Configure network policies (Kubernetes)
- [ ] Use secrets management (Vault, k8s Secrets)

### Example TLS Configuration

```yaml
# Nginx SSL config for dashboard
ssl_certificate /etc/ssl/certs/streamforge.crt;
ssl_certificate_key /etc/ssl/private/streamforge.key;
ssl_protocols TLSv1.2 TLSv1.3;
ssl_ciphers HIGH:!aNULL:!MD5;
```

---

## Performance Tuning

### JVM Tuning

```bash
JAVA_OPTS="
  -Xmx4g 
  -Xms2g 
  -XX:+UseG1GC 
  -XX:MaxGCPauseMillis=200 
  -XX:+UseStringDeduplication
"
```

### RocksDB Tuning

```java
options.setWriteBufferSize(128 * 1024 * 1024);  // 128MB
options.setMaxWriteBufferNumber(4);
options.setTargetFileSizeBase(128 * 1024 * 1024);
options.setCompressionType(CompressionType.LZ4_COMPRESSION);
```

### Network Tuning

```bash
# Linux kernel tuning
sysctl -w net.core.rmem_max=134217728
sysctl -w net.core.wmem_max=134217728
sysctl -w net.ipv4.tcp_rmem="4096 87380 134217728"
sysctl -w net.ipv4.tcp_wmem="4096 65536 134217728"
```

---

For additional support, see [GitHub Issues](https://github.com/yourusername/streamforge/issues) or [Documentation](https://github.com/yourusername/streamforge/docs).
