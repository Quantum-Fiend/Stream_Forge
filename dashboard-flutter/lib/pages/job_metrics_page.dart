import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/mock_data_service.dart';
import 'dart:async';

class JobMetricsPage extends StatefulWidget {
  const JobMetricsPage({Key? key}) : super(key: key);

  @override
  State<JobMetricsPage> createState() => _JobMetricsPageState();
}

class _JobMetricsPageState extends State<JobMetricsPage> {
  Timer? _timer;
  List<Map<String, dynamic>> _jobs = [];
  String? _selectedJobId;

  // Rolling X counter — never resets so chart stays correct after trimming
  int _xCounter = 0;
  final int _maxDataPoints = 40;

  final List<FlSpot> _throughputData = [];
  final List<FlSpot> _latencyData = [];

  final _mockData = MockDataService();

  @override
  void initState() {
    super.initState();
    _loadJobs();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _loadJobs();
      if (_selectedJobId != null) _tick();
    });
  }

  void _loadJobs() {
    final jobs = _mockData.getJobs();
    setState(() {
      _jobs = jobs;
      // If selected job was cancelled, fall back to first available
      if (_selectedJobId != null &&
          !_jobs.any((j) => j['jobId'] == _selectedJobId)) {
        _selectedJobId = _jobs.isNotEmpty ? _jobs.first['jobId'] : null;
        _throughputData.clear();
        _latencyData.clear();
        _xCounter = 0;
      }
      if (_selectedJobId == null && _jobs.isNotEmpty) {
        _selectedJobId = _jobs.first['jobId'];
      }
    });
  }

  void _tick() {
    final job = _jobs.firstWhere(
      (j) => j['jobId'] == _selectedJobId,
      orElse: () => {},
    );
    if (job.isEmpty) return;

    setState(() {
      final x = _xCounter.toDouble();
      _xCounter++;

      if (_throughputData.length >= _maxDataPoints) {
        _throughputData.removeAt(0);
        _latencyData.removeAt(0);
      }

      final isRunning = job['state'] == 'RUNNING';
      final eps = isRunning ? (job['eventsPerSecond'] as double) : 0.0;
      final lat = isRunning ? (job['avgLatency'] as double) : 0.0;

      _throughputData.add(FlSpot(x, eps));
      _latencyData.add(FlSpot(x, lat));
    });
  }

  void _switchJob(String? jobId) {
    setState(() {
      _selectedJobId = jobId;
      _throughputData.clear();
      _latencyData.clear();
      _xCounter = 0;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Map<String, dynamic> get _selectedJob =>
      _jobs.firstWhere((j) => j['jobId'] == _selectedJobId, orElse: () => {});

  bool get _isRunning => _selectedJob['state'] == 'RUNNING';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Job Metrics',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _jobs.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.analytics_outlined,
                      size: 56, color: Colors.white24),
                  SizedBox(height: 12),
                  Text('No jobs to monitor.',
                      style: TextStyle(color: Colors.white38)),
                ],
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Job selector ─────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.1)),
                    ),
                    child: DropdownButton<String>(
                      value: _selectedJobId,
                      isExpanded: true,
                      underline: const SizedBox(),
                      dropdownColor: const Color(0xFF1E293B),
                      style: const TextStyle(
                          color: Colors.white, fontSize: 15),
                      items: _jobs.map((job) {
                        final color = _stateColor(job['state']);
                        return DropdownMenuItem<String>(
                          value: job['jobId'],
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  job['name'],
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  job['state'],
                                  style: TextStyle(
                                      fontSize: 9,
                                      color: color,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: _switchJob,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Metric cards ─────────────────────────────────────
                  if (_selectedJob.isNotEmpty) ...[
                    Row(
                      children: [
                        Expanded(
                            child: _buildMetricCard(
                          'Events Processed',
                          _formatNum(_selectedJob['eventsProcessed']),
                          Icons.bar_chart_rounded,
                          const Color(0xFF6366F1),
                        )),
                        const SizedBox(width: 16),
                        Expanded(
                            child: _buildMetricCard(
                          'Events / sec',
                          _isRunning
                              ? '${(_selectedJob['eventsPerSecond'] as double).toStringAsFixed(0)}'
                              : '—',
                          Icons.bolt_rounded,
                          const Color(0xFF10B981),
                        )),
                        const SizedBox(width: 16),
                        Expanded(
                            child: _buildMetricCard(
                          'Avg Latency',
                          _isRunning
                              ? '${(_selectedJob['avgLatency'] as double).toStringAsFixed(1)} ms'
                              : '—',
                          Icons.timer_outlined,
                          const Color(0xFFF59E0B),
                        )),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // ── Charts ──────────────────────────────────────────
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildChartCard(
                              title: 'Throughput (events/s)',
                              chart: _buildLineChart(
                                  _throughputData,
                                  const Color(0xFF6366F1),
                                  dynamicMax: true),
                              badge: _isRunning
                                  ? _liveBadge()
                                  : _pausedBadge(_selectedJob['state']),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildChartCard(
                              title: 'Latency (ms)',
                              chart: _buildLineChart(
                                  _latencyData,
                                  const Color(0xFFF59E0B),
                                  maxY: 60),
                              badge: _isRunning
                                  ? _liveBadge()
                                  : _pausedBadge(_selectedJob['state']),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  // ── Widgets ────────────────────────────────────────────────────────────

  Widget _liveBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
            color: const Color(0xFF10B981).withOpacity(0.5)),
      ),
      child: const Text('● LIVE',
          style: TextStyle(
              fontSize: 10,
              color: Color(0xFF10B981),
              fontWeight: FontWeight.bold)),
    );
  }

  Widget _pausedBadge(String state) {
    final color = _stateColor(state);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(state,
          style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildMetricCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 14),
          Text(value,
              style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
          const SizedBox(height: 4),
          Text(title,
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.5))),
        ],
      ),
    );
  }

  Widget _buildChartCard(
      {required String title,
      required Widget chart,
      required Widget badge}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              const Spacer(),
              badge,
            ],
          ),
          const SizedBox(height: 16),
          Expanded(child: chart),
        ],
      ),
    );
  }

  Widget _buildLineChart(List<FlSpot> data, Color color,
      {double maxY = 100, bool dynamicMax = false}) {
    if (data.isEmpty) {
      return const Center(
          child: Text('Collecting data…',
              style: TextStyle(color: Colors.white38)));
    }

    final minX = data.first.x;
    final maxX = data.first.x == data.last.x ? data.first.x + 1 : data.last.x;

    double computedMax = maxY;
    if (dynamicMax && data.isNotEmpty) {
      final peak = data.map((s) => s.y).reduce((a, b) => a > b ? a : b);
      computedMax = (peak * 1.3).clamp(10.0, double.infinity);
    }

    return LineChart(
      LineChartData(
        clipData: const FlClipData.all(),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: computedMax / 4,
          getDrawingHorizontalLine: (_) => FlLine(
            color: Colors.white.withOpacity(0.07),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        minX: minX,
        maxX: maxX,
        minY: 0,
        maxY: computedMax,
        lineBarsData: [
          LineChartBarData(
            spots: data,
            isCurved: true,
            curveSmoothness: 0.3,
            color: color,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  color.withOpacity(0.25),
                  color.withOpacity(0.0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Utils ──────────────────────────────────────────────────────────────

  Color _stateColor(String state) {
    switch (state) {
      case 'RUNNING':
        return const Color(0xFF10B981);
      case 'PAUSED':
        return const Color(0xFFF59E0B);
      case 'FAILED':
        return const Color(0xFFEF4444);
      case 'COMPLETED':
        return const Color(0xFF8B5CF6);
      default:
        return Colors.grey;
    }
  }

  String _formatNum(dynamic n) {
    final v = n is int ? n : (n as double).toInt();
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(2)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toString();
  }
}
