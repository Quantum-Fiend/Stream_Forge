import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import 'dart:async';

class ClusterHealthPage extends StatefulWidget {
  const ClusterHealthPage({Key? key}) : super(key: key);

  @override
  State<ClusterHealthPage> createState() => _ClusterHealthPageState();
}

class _ClusterHealthPageState extends State<ClusterHealthPage> {
  Timer? _timer;
  Map<String, dynamic> _metrics = {
    'activeNodes': 3,
    'totalJobs': 12,
    'runningJobs': 5,
    'eventsPerSecond': 1250.5,
    'cpuUsage': 65.3,
    'memoryUsage': 72.1,
  };
  
  final List<FlSpot> _cpuData = [];
  final List<FlSpot> _memoryData = [];
  final List<FlSpot> _throughputData = [];
  
  @override
  void initState() {
    super.initState();
    _startMetricsPolling();
  }
  
  void _startMetricsPolling() {
    _timer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _fetchMetrics();
    });
  }
  
  Future<void> _fetchMetrics() async {
    try {
      final apiService = context.read<ApiService>();
      // Simulate metrics - in production would call: apiService.getClusterMetrics()
      setState(() {
        // Simulate varying metrics
        _metrics = {
          'activeNodes': 3,
          'totalJobs': 12 + (DateTime.now().second % 5),
          'runningJobs': 5 + (DateTime.now().second % 3),
          'eventsPerSecond': 1000 + (DateTime.now().second * 20.5),
          'cpuUsage': 60 + (DateTime.now().second % 30),
          'memoryUsage': 70 + (DateTime.now().second % 20),
        };
        
        // Add to time series
        final time = _cpuData.length.toDouble();
        if (_cpuData.length > 20) {
          _cpuData.removeAt(0);
          _memoryData.removeAt(0);
          _throughputData.removeAt(0);
        }
        
        _cpuData.add(FlSpot(time, _metrics['cpuUsage']));
        _memoryData.add(FlSpot(time, _metrics['memoryUsage']));
        _throughputData.add(FlSpot(time, _metrics['eventsPerSecond'] / 100));
      });
    } catch (e) {
      print('Error fetching metrics: $e');
    }
  }
  
  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cluster Health'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Metrics cards
            Row(
              children: [
                Expanded(child: _buildMetricCard(
                  'Active Nodes',
                  _metrics['activeNodes'].toString(),
                  Icons.dns,
                  const Color(0xFF10B981),
                )),
                const SizedBox(width: 16),
                Expanded(child: _buildMetricCard(
                  'Running Jobs',
                  '${_metrics['runningJobs']}/${_metrics['totalJobs']}',
                  Icons.work,
                  const Color(0xFF6366F1),
                )),
                const SizedBox(width: 16),
                Expanded(child: _buildMetricCard(
                  'Events/Sec',
                  _metrics['eventsPerSecond'].toStringAsFixed(1),
                  Icons.speed,
                  const Color(0xFFF59E0B),
                )),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Charts
            _buildChartCard(
              'CPU Usage',
              _buildLineChart(_cpuData, const Color(0xFF6366F1)),
              '${_metrics['cpuUsage'].toStringAsFixed(1)}%',
            ),
            
            const SizedBox(height: 24),
            
            _buildChartCard(
              'Memory Usage',
              _buildLineChart(_memoryData, const Color(0xFF10B981)),
              '${_metrics['memoryUsage'].toStringAsFixed(1)}%',
            ),
            
            const SizedBox(height: 24),
            
            _buildChartCard(
              'Throughput',
              _buildLineChart(_throughputData, const Color(0xFFF59E0B)),
              '${(_metrics['eventsPerSecond'] / 1000).toStringAsFixed(2)}K/s',
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1E293B),
            const Color(0xFF1E293B).withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildChartCard(String title, Widget chart, String currentValue) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              Text(
                currentValue,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF6366F1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: chart,
          ),
        ],
      ),
    );
  }
  
  Widget _buildLineChart(List<FlSpot> data, Color color) {
    if (data.isEmpty) {
      return const Center(child: Text('No data'));
    }
    
    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 20,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.white.withOpacity(0.1),
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: data,
            isCurved: true,
            color: color,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  color.withOpacity(0.3),
                  color.withOpacity(0.0),
                ],
              ),
            ),
          ),
        ],
        minY: 0,
        maxY: 100,
      ),
    );
  }
}
