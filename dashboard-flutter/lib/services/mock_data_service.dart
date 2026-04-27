import 'dart:math';

/// Central in-memory mock data store.
/// All pages share this single instance so state changes (pause/resume/cancel)
/// are visible across the entire dashboard immediately.
class MockDataService {
  static final MockDataService _instance = MockDataService._internal();
  factory MockDataService() => _instance;
  MockDataService._internal();

  final _rand = Random();

  // ── Cluster metrics ────────────────────────────────────────────────────
  double _cpu = 65.0;
  double _memory = 72.0;
  double _eventsPerSecond = 1250.0;

  Map<String, dynamic> getClusterMetrics() {
    // Realistic random walk
    _cpu = (_cpu + (_rand.nextDouble() * 6 - 3)).clamp(30.0, 95.0);
    _memory = (_memory + (_rand.nextDouble() * 4 - 2)).clamp(40.0, 92.0);
    _eventsPerSecond =
        (_eventsPerSecond + (_rand.nextDouble() * 200 - 100)).clamp(200.0, 5000.0);

    final running = _jobs.where((j) => j['state'] == 'RUNNING').length;
    return {
      'activeNodes': 3,
      'totalJobs': _jobs.length,
      'runningJobs': running,
      'eventsPerSecond': double.parse(_eventsPerSecond.toStringAsFixed(1)),
      'cpuUsage': double.parse(_cpu.toStringAsFixed(1)),
      'memoryUsage': double.parse(_memory.toStringAsFixed(1)),
    };
  }

  // ── Jobs ───────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _jobs = [
    {
      'jobId': 'job-001',
      'name': 'Click Stream Aggregation',
      'type': 'STREAMING',
      'state': 'RUNNING',
      'startTime': DateTime.now().subtract(const Duration(hours: 2)),
      'eventsProcessed': 125000,
      'eventsPerSecond': 850.5,
      'avgLatency': 12.3,
      'parallelism': 4,
      'source': 'events',
      'sink': 'dashboard',
    },
    {
      'jobId': 'job-002',
      'name': 'User Activity Analysis',
      'type': 'STREAMING',
      'state': 'RUNNING',
      'startTime': DateTime.now().subtract(const Duration(hours: 1)),
      'eventsProcessed': 89000,
      'eventsPerSecond': 620.2,
      'avgLatency': 15.7,
      'parallelism': 2,
      'source': 'user-events',
      'sink': 'analytics',
    },
    {
      'jobId': 'job-003',
      'name': 'Transaction Monitoring',
      'type': 'BATCH',
      'state': 'PAUSED',
      'startTime': DateTime.now().subtract(const Duration(minutes: 30)),
      'eventsProcessed': 45000,
      'eventsPerSecond': 0.0,
      'avgLatency': 0.0,
      'parallelism': 1,
      'source': 'transactions',
      'sink': 'alerts',
    },
    {
      'jobId': 'job-004',
      'name': 'Error Log Analysis',
      'type': 'BATCH',
      'state': 'COMPLETED',
      'startTime': DateTime.now().subtract(const Duration(hours: 3)),
      'eventsProcessed': 320000,
      'eventsPerSecond': 0.0,
      'avgLatency': 0.0,
      'parallelism': 2,
      'source': 'logs',
      'sink': 'report',
    },
  ];

  List<Map<String, dynamic>> getJobs() {
    // Tick up metrics for running jobs
    for (final job in _jobs) {
      if (job['state'] == 'RUNNING') {
        final eps = (job['eventsPerSecond'] as double) +
            (_rand.nextDouble() * 100 - 50);
        job['eventsPerSecond'] = eps.clamp(100.0, 2000.0);
        job['eventsProcessed'] =
            (job['eventsProcessed'] as int) + _rand.nextInt(500) + 100;
        job['avgLatency'] = (10 + _rand.nextDouble() * 20).roundToDouble();
      }
    }
    // Return deep copies so UI can't mutate store directly
    return _jobs.map((j) => Map<String, dynamic>.from(j)).toList();
  }

  Map<String, dynamic> getJob(String jobId) {
    return Map<String, dynamic>.from(
        _jobs.firstWhere((j) => j['jobId'] == jobId));
  }

  void pauseJob(String jobId) {
    final idx = _jobs.indexWhere((j) => j['jobId'] == jobId);
    if (idx != -1 && _jobs[idx]['state'] == 'RUNNING') {
      _jobs[idx]['state'] = 'PAUSED';
      _jobs[idx]['eventsPerSecond'] = 0.0;
      _jobs[idx]['avgLatency'] = 0.0;
    }
  }

  void resumeJob(String jobId) {
    final idx = _jobs.indexWhere((j) => j['jobId'] == jobId);
    if (idx != -1 && _jobs[idx]['state'] == 'PAUSED') {
      _jobs[idx]['state'] = 'RUNNING';
      _jobs[idx]['eventsPerSecond'] = 400.0;
      _jobs[idx]['avgLatency'] = 14.0;
    }
  }

  void cancelJob(String jobId) {
    _jobs.removeWhere((j) => j['jobId'] == jobId);
  }

  void createJob({
    required String name,
    required String type,
    required int parallelism,
    required String source,
    required String sink,
  }) {
    final id = 'job-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
    _jobs.add({
      'jobId': id,
      'name': name,
      'type': type,
      'state': 'RUNNING',
      'startTime': DateTime.now(),
      'eventsProcessed': 0,
      'eventsPerSecond': 50.0,
      'avgLatency': 20.0,
      'parallelism': parallelism,
      'source': source,
      'sink': sink,
    });
  }
}
