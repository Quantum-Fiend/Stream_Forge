import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/mock_data_service.dart';
import 'dart:async';

class ClusterHealthPage extends StatefulWidget {
  const ClusterHealthPage({Key? key}) : super(key: key);

  @override
  State<ClusterHealthPage> createState() => _ClusterHealthPageState();
}

class _ClusterHealthPageState extends State<ClusterHealthPage> {
  Timer? _timer;
  bool _isLoading = true;

  Map<String, dynamic> _metrics = {
    'activeNodes': 0,
    'totalJobs': 0,
    'runningJobs': 0,
    'eventsPerSecond': 0.0,
    'cpuUsage': 0.0,
    'memoryUsage': 0.0,
  };

  // Rolling X counter — never resets, so index stays correct after trimming
  int _xCounter = 0;
  final int _maxDataPoints = 25;

  final List<FlSpot> _cpuData = [];
  final List<FlSpot> _memoryData = [];
  final List<FlSpot> _throughputData = [];

  final _mockData = MockDataService();

  @override
  void initState() {
    super.initState();
    _fetchMetrics(); // immediate first fetch
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _fetchMetrics());
  }

  void _fetchMetrics() {
    final metrics = _mockData.getClusterMetrics();
    setState(() {
      _isLoading = false;
      _metrics = metrics;

      final x = _xCounter.toDouble();
      _xCounter++;

      if (_cpuData.length >= _maxDataPoints) {
        _cpuData.removeAt(0);
        _memoryData.removeAt(0);
        _throughputData.removeAt(0);
      }

      _cpuData.add(FlSpot(x, metrics['cpuUsage']));
      _memoryData.add(FlSpot(x, metrics['memoryUsage']));
      // Normalise throughput to 0-100 scale for chart (divide by 50)
      _throughputData.add(
          FlSpot(x, (metrics['eventsPerSecond'] as double).clamp(0, 5000) / 50));
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text(
          'Cluster Health',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // Live indicator
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              children: [
                _PulseDot(color: const Color(0xFF10B981)),
                const SizedBox(width: 6),
                const Text(
                  'LIVE',
                  style: TextStyle(
                    color: Color(0xFF10B981),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF6366F1)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Top metric cards ───────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                          child: _buildMetricCard(
                        'Active Nodes',
                        _metrics['activeNodes'].toString(),
                        Icons.dns_rounded,
                        const Color(0xFF10B981),
                        subtitle: 'Healthy',
                      )),
                      const SizedBox(width: 16),
                      Expanded(
                          child: _buildMetricCard(
                        'Running Jobs',
                        '${_metrics['runningJobs']}/${_metrics['totalJobs']}',
                        Icons.play_circle_rounded,
                        const Color(0xFF6366F1),
                        subtitle: 'Active streams',
                      )),
                      const SizedBox(width: 16),
                      Expanded(
                          child: _buildMetricCard(
                        'Events / sec',
                        _formatNumber(_metrics['eventsPerSecond']),
                        Icons.bolt_rounded,
                        const Color(0xFFF59E0B),
                        subtitle: 'Throughput',
                      )),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // ── CPU Chart ──────────────────────────────────────────
                  _buildChartCard(
                    title: 'CPU Usage',
                    currentValue: '${_metrics['cpuUsage'].toStringAsFixed(1)}%',
                    valueColor: _gaugeColor(_metrics['cpuUsage']),
                    chart: _buildLineChart(_cpuData, const Color(0xFF6366F1),
                        maxY: 100),
                  ),

                  const SizedBox(height: 20),

                  // ── Memory Chart ───────────────────────────────────────
                  _buildChartCard(
                    title: 'Memory Usage',
                    currentValue:
                        '${_metrics['memoryUsage'].toStringAsFixed(1)}%',
                    valueColor: _gaugeColor(_metrics['memoryUsage']),
                    chart: _buildLineChart(_memoryData, const Color(0xFF10B981),
                        maxY: 100),
                  ),

                  const SizedBox(height: 20),

                  // ── Throughput Chart ───────────────────────────────────
                  _buildChartCard(
                    title: 'Throughput',
                    currentValue:
                        '${_formatNumber(_metrics['eventsPerSecond'])}/s',
                    valueColor: const Color(0xFFF59E0B),
                    chart: _buildLineChart(
                        _throughputData, const Color(0xFFF59E0B),
                        maxY: 100),
                  ),
                ],
              ),
            ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  String _formatNumber(dynamic value) {
    final v = (value as double);
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }

  Color _gaugeColor(dynamic value) {
    final v = (value as double);
    if (v >= 85) return const Color(0xFFEF4444);
    if (v >= 70) return const Color(0xFFF59E0B);
    return const Color(0xFF10B981);
  }

  Widget _buildMetricCard(
    String title,
    String value,
    IconData icon,
    Color color, {
    String subtitle = '',
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1E293B),
            const Color(0xFF1E293B).withOpacity(0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.25), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
                fontSize: 13, color: Colors.white.withOpacity(0.55)),
          ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                  fontSize: 11,
                  color: color.withOpacity(0.8),
                  fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChartCard({
    required String title,
    required String currentValue,
    required Color valueColor,
    required Widget chart,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: Colors.white.withOpacity(0.07), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              Text(
                currentValue,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: valueColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(height: 180, child: chart),
        ],
      ),
    );
  }

  Widget _buildLineChart(List<FlSpot> data, Color color,
      {double maxY = 100}) {
    if (data.isEmpty) {
      return const Center(
          child: Text('Collecting data…',
              style: TextStyle(color: Colors.white38)));
    }

    // Compute minX / maxX from actual data
    final minX = data.first.x;
    final maxX = data.first.x == data.last.x ? data.first.x + 1 : data.last.x;

    return LineChart(
      LineChartData(
        clipData: const FlClipData.all(),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 25,
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
        maxY: maxY,
        lineBarsData: [
          LineChartBarData(
            spots: data,
            isCurved: true,
            curveSmoothness: 0.35,
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
}

/// Animated pulsing dot for the LIVE indicator
class _PulseDot extends StatefulWidget {
  final Color color;
  const _PulseDot({required this.color});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
