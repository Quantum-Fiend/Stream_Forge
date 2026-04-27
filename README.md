<div align="center">

# ⚡ StreamForge

### Real-Time Distributed Data Processing Platform

<img src="docs/assets/banner.png" alt="StreamForge Banner" width="100%"/>

[![Scala](https://img.shields.io/badge/Scala-DC322F?style=for-the-badge&logo=scala&logoColor=white)](https://scala-lang.org)
[![Java](https://img.shields.io/badge/Java-ED8B00?style=for-the-badge&logo=openjdk&logoColor=white)](https://openjdk.org)
[![Kotlin](https://img.shields.io/badge/Kotlin-7F52FF?style=for-the-badge&logo=kotlin&logoColor=white)](https://kotlinlang.org)
[![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Docker](https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white)](https://docker.com)

**Mini Spark + Flink + Firebase** — Built for Production Scale

[Features](#-features) • [Architecture](#-architecture) • [Quick Start](#-quick-start) • [Dashboard](#-dashboard) • [API](#-api) • [Documentation](#-documentation)

---

<img src="https://raw.githubusercontent.com/andreasbm/readme/master/assets/lines/rainbow.png" alt="divider"/>

</div>

## 🎯 What is StreamForge?

StreamForge is a **production-ready, fault-tolerant distributed data processing platform** that handles high-volume event streams with:

<table>
<tr>
<td width="50%">

### 🚀 Real-Time Processing
- 10K+ events/second throughput
- Sub-20ms processing latency
- Windowed aggregations
- Stateful computations

</td>
<td width="50%">

### 🛡️ Fault Tolerance
- Exactly-once semantics
- Automatic checkpointing
- Instant recovery (<2s)
- Zero data loss guarantee

</td>
</tr>
</table>

---

## ✨ Features

<table>
<tr>
<td align="center" width="25%">

### 📊 Custom DSL

```scala
stream("events")
  .filter(_.type == "click")
  .window(sliding(5.min))
  .aggregate(sum("value"))
  .sink("dashboard")
```

</td>
<td align="center" width="25%">

### ⏱️ Windowing

- Sliding Windows
- Tumbling Windows
- Session Windows
- Count Windows

</td>
<td align="center" width="25%">

### 🔄 Operators

- Map / Filter
- Aggregate
- Join
- Stateful

</td>
<td align="center" width="25%">

### 📈 Dashboard

- Real-time charts
- Cluster health
- Job management
- Live metrics

</td>
</tr>
</table>

---

## 🏗 Architecture

```
                                    ┌─────────────────────────────────────────────────────────┐
                                    │                   DATA SOURCES                          │
                                    │            IoT • Logs • Web Events • APIs               │
                                    └─────────────────────────┬───────────────────────────────┘
                                                              │
                                                              ▼
┌─────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                                                                                         │
│    ┌───────────────────────────────────────────────────────────────────────────────────────────────┐    │
│    │                        🔵 KOTLIN API LAYER (Port 8080)                                        │    │
│    │                                                                                               │    │
│    │   ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐                    │    │
│    │   │  REST API   │    │   gRPC      │    │  WebSocket  │    │  Scheduler  │                    │    │
│    │   │   (Ktor)    │    │  Service    │    │   Metrics   │    │  (Quartz)   │                    │    │
│    │   └─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘                    │    │
│    │                              Coroutines • Backpressure • Flow Control                         │    │
│    └───────────────────────────────────────────────────────────────────────────────────────────────┘    │
│                                                              │                                          │
│                                                              ▼                                          │
│    ┌───────────────────────────────────────────────────────────────────────────────────────────────┐    │
│    │                        🔴 SCALA PROCESSING ENGINE                                            │    │
│    │                                                                                               │    │
│    │   ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐                    │    │
│    │   │ Custom DSL  │───▶│ Stream Graph│───▶│  Operators  │───▶│  Windowing  │                  │    │
│    │   │   Parser    │    │   Builder   │    │ Map/Filter  │    │  Aggregate  │                    │    │
│    │   └─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘                    │    │
│    │                              Akka Streams • Reactive • Backpressure                           │    │
│    └───────────────────────────────────────────────────────────────────────────────────────────────┘    │
│                                                              │                                          │
│                                                              ▼                                          │
│    ┌───────────────────────────────────────────────────────────────────────────────────────────────┐    │
│    │                        🟢 JAVA INFRASTRUCTURE LAYER                                           │    │
│    │                                                                                               │    │
│    │   ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐                    │    │
│    │   │ Checkpoint  │    │   State     │    │  Cluster    │    │  Recovery   │                    │    │
│    │   │  Manager    │    │   Store     │    │ Coordinator │    │  Manager    │                    │    │
│    │   │ (RocksDB)   │    │ (RocksDB)   │    │ (ZooKeeper) │    │  (Health)   │                    │    │
│    │   └─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘                    │    │
│    │                          Exactly-Once • Fault Tolerance • High Availability                   │    │
│    └───────────────────────────────────────────────────────────────────────────────────────────────┘    │
│                                                                                                         │
└─────────────────────────────────────────────────────────────────────────────────────────────────────────┘
                                                              │
                                                              ▼
                                    ┌─────────────────────────────────────────────────────────┐
                                    │                   🟡 FLUTTER DASHBOARD                 │
                                    │                      (Port 3000)                        │
                                    │                                                         │
                                    │   ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │
                                    │   │   Cluster   │  │     Job     │  │     Job     │     │
                                    │   │   Health    │  │   Metrics   │  │  Management │     │
                                    │   └─────────────┘  └─────────────┘  └─────────────┘     │
                                    │                                                         │
                                    │          Real-Time Charts • WebSocket • Material 3      │
                                    └─────────────────────────────────────────────────────────┘
```

---

## 🎨 Dashboard Preview

<table>
<tr>
<td width="33%" align="center">

### 📊 Cluster Health

```
┌────────────────────────────┐
│  🟢 Active Nodes: 3        │
│  📊 Running Jobs: 5        │
│  ⚡ Events/sec: 1,250      │
├────────────────────────────┤
│  CPU Usage                 │
│  ████████████░░░░░ 65%     │
├────────────────────────────┤
│  Memory Usage              │
│  ██████████████░░░ 72%     │
├────────────────────────────┤
│  Throughput (events/s)     │
│  📈 ▁▂▄▆█▇▅▆▇█▆▇█▅▆      │
└────────────────────────────┘
```

</td>
<td width="33%" align="center">

### 📈 Job Metrics

```
┌────────────────────────────┐
│  Click Stream Analysis     │
│  ● RUNNING                 │
├────────────────────────────┤
│  Events: 125,000           │
│  Rate: 850/s               │
│  Latency: 12ms             │
├────────────────────────────┤
│  Throughput                │
│  📈 ▂▃▅▆▇█▇▆▇█▇▅▆█         
├────────────────────────────┤
│  Latency (ms)              │
│  📉 ▅▄▃▂▁▂▃▂▁▂▃     │
└────────────────────────────┘
```

</td>
<td width="33%" align="center">

### ⚙️ Job Management

```
┌────────────────────────────┐
│  [+ New Job]               │
├────────────────────────────┤
│  ● Click Analysis          │
│    STREAMING │ 2h ago      │
│    [Pause] [Details]       │
├────────────────────────────┤
│  ● User Activity           │
│    STREAMING │ 1h ago      │
│    [Pause] [Details]       │
├────────────────────────────┤
│  ○ Transaction Monitor     │
│    PAUSED │ 30m ago        │
│    [Resume] [Cancel]       │
└────────────────────────────┘
```

</td>
</tr>
</table>

---

## 🚀 Getting Started (Zero to Hero Guide)

StreamForge consists of a **Kotlin/Scala/Java Backend** and a **Cross-Platform Flutter Dashboard**. You can run the dashboard completely standalone (using its Mock Engine) or alongside the real backend.

### Prerequisites

- **Flutter 3.0+** — Required for the Dashboard App/Website.
- **JDK 17+** — Required if running the Kotlin/Scala Backend.
- **Docker** — Required for running the full cluster easily.

---

### 🎨 Running the Dashboard (Frontend Only)

The dashboard has a built-in **Stateful Mock Engine**. This means you can run it perfectly without ever starting the backend—ideal for testing, design, or showcasing the UI. Because it's built with Flutter, you can run it on **any platform** from the exact same codebase!

First, navigate to the dashboard directory:
```bash
cd dashboard-flutter
flutter pub get
```

#### 🌐 Option A: Run as a Website (Web App)
To run the dashboard locally in your browser:
```bash
flutter run -d web-server --web-port 3000
```
Then, open `http://localhost:3000` in your browser. *(Note: On small screens, the UI automatically transforms into a mobile-friendly layout with a bottom navigation bar!)*

#### 📱 Option B: Run as a Mobile App (Android/iOS)
To run the dashboard as a native mobile application on your connected smartphone or an emulator:
```bash
# To see available devices (Emulators, physical devices)
flutter devices

# Run on Android or iOS
flutter run
```

#### 💻 Option C: Run as a Desktop App (Windows/macOS/Linux)
To compile it into a high-performance native desktop application:
```bash
# Enable desktop support if you haven't already
flutter config --enable-windows-desktop
flutter config --enable-macos-desktop

# Run the app natively
flutter run -d windows  # or -d macos
```

---

### ⚙️ Running the Full Stack (Backend + UI)

If you want to run the real Scala processing engine and Kotlin API:

#### Method 1: Using Docker (Recommended)
```bash
# Start all microservices (API, Engine, ZooKeeper, Dashboard)
docker-compose up -d

# API is available at:       http://localhost:8080
# Dashboard is available at: http://localhost:3000
```

#### Method 2: Build from Source
Open two separate terminals in the project root:

**Terminal 1 (Backend):**
```bash
# Build all Java/Scala/Kotlin modules
./gradlew build

# Run the API server
./gradlew :api-kotlin:run
```

**Terminal 2 (Dashboard):**
```bash
cd dashboard-flutter
flutter run -d web-server --web-port 3000
```

---

## 📡 API

### Submit a Job

```bash
curl -X POST http://localhost:8080/api/jobs \
  -H "Content-Type: application/json" \
  -d '{
    "id": "click-analysis",
    "name": "Click Stream Analysis",
    "type": "STREAMING",
    "config": {
      "source": "events",
      "sink": "dashboard",
      "parallelism": 4,
      "checkpointInterval": 60000
    }
  }'
```

### Ingest Events

```bash
curl -X POST http://localhost:8080/api/ingest/event \
  -H "Content-Type: application/json" \
  -d '{
    "id": "evt-001",
    "type": "click",
    "timestamp": "2025-12-22T20:00:00Z",
    "source": "web-app",
    "payload": {"page": "/products", "userId": "user-123"}
  }'
```

### Monitor Status

```bash
curl http://localhost:8080/api/jobs/click-analysis
```

---

## 🧩 Language Stack

<table>
<tr>
<td align="center" width="25%">
<img src="https://raw.githubusercontent.com/devicons/devicon/master/icons/scala/scala-original.svg" width="60"/>
<br><b>Scala</b>
<br><sub>Processing Engine</sub>
<br><sub>DSL • Windowing • Operators</sub>
</td>
<td align="center" width="25%">
<img src="https://raw.githubusercontent.com/devicons/devicon/master/icons/java/java-original.svg" width="60"/>
<br><b>Java</b>
<br><sub>Infrastructure</sub>
<br><sub>Checkpoints • State • Recovery</sub>
</td>
<td align="center" width="25%">
<img src="https://raw.githubusercontent.com/devicons/devicon/master/icons/kotlin/kotlin-original.svg" width="60"/>
<br><b>Kotlin</b>
<br><sub>API Layer</sub>
<br><sub>REST • WebSocket • Scheduler</sub>
</td>
<td align="center" width="25%">
<img src="https://raw.githubusercontent.com/devicons/devicon/master/icons/flutter/flutter-original.svg" width="60"/>
<br><b>Flutter</b>
<br><sub>Dashboard</sub>
<br><sub>Charts • Monitoring • Control</sub>
</td>
</tr>
</table>

---

## 📊 Performance

| Metric | Value |
|--------|-------|
| **Throughput** | 10,000+ events/second per node |
| **Latency** | < 20ms average processing |
| **Recovery** | < 2 seconds from checkpoint |
| **Scalability** | Horizontal scaling with ZooKeeper |

---

## 📁 Project Structure

```
streamforge/
├── 📄 README.md, LICENSE, CONTRIBUTING.md, CHANGELOG.md
├── 🐳 docker-compose.yml, Dockerfile.api, Dockerfile.engine
│
├── 🔴 engine-scala/           # Scala Processing Engine
│   └── dsl/, window/, operators/, StreamProcessor, BatchProcessor
│
├── 🟢 infrastructure-java/    # Java Infrastructure
│   └── checkpoint/, state/, cluster/, recovery/
│
├── 🔵 api-kotlin/             # Kotlin API Layer
│   └── Application, JobAPI, IngestionAPI, MetricsAPI, Scheduler
│
├── 🟡 dashboard-flutter/      # Flutter Dashboard
│   └── pages/, services/, Dockerfile, nginx.conf
│
├── 📚 docs/                   # Documentation
│   └── ARCHITECTURE.md, API.md, DEPLOYMENT.md
│
└── 📝 examples/               # Examples
    └── example_pipeline.scala, sample_job.json
```

---

## 📚 Documentation

| Document | Description |
|----------|-------------|
| [**Architecture**](docs/ARCHITECTURE.md) | System design, data flow, components |
| [**API Reference**](docs/API.md) | REST endpoints, WebSocket, models |
| [**Deployment**](docs/DEPLOYMENT.md) | Docker, Kubernetes, production setup |

---

## 🌟 Why StreamForge?

<table>
<tr>
<td>✅ <b>Production Ready</b></td>
<td>Fault-tolerant with exactly-once semantics</td>
</tr>
<tr>
<td>✅ <b>Modern Stack</b></td>
<td>Multi-language architecture optimized for each layer</td>
</tr>
<tr>
<td>✅ <b>Beautiful Dashboard</b></td>
<td>Real-time visualization with Flutter</td>
</tr>
<tr>
<td>✅ <b>Developer Friendly</b></td>
<td>Declarative DSL, comprehensive APIs</td>
</tr>
<tr>
<td>✅ <b>Big-Tech Patterns</b></td>
<td>Implements designs from Spark, Flink, Samza</td>
</tr>
</table>

---

## 📜 License

This project is licensed under the **MIT License** — see [LICENSE](LICENSE) for details.

---

<div align="center">

### Built with 💜 by Tushar 💫

[![GitHub stars](https://img.shields.io/github/stars/yourusername/streamforge?style=social)](https://github.com/yourusername/streamforge)
[![GitHub forks](https://img.shields.io/github/forks/yourusername/streamforge?style=social)](https://github.com/yourusername/streamforge/fork)

**[⬆ Back to Top](#-streamforge)**

</div>
