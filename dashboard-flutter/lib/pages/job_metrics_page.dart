import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
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
  
  final List<FlSpot> _eventsProcessedData = [];
  final List<FlSpot> _latencyData = [];
  
  @override
  void initState() {
    super.initState();
    _loadJobs();
    _startMetricsPolling();
  }
  
  Future<void> _loadJobs() async {
    try {
      // Simulate loading jobs
      setState(() {
        _jobs = [
          {
            'jobId': 'job-001',
            'name': 'Click Stream Aggregation',
            'state': 'RUNNING',
            'eventsProcessed': 125000,
            'eventsPerSecond': 850.5,
            'avgLatency': 12.3,
          },
          {
            'jobId': 'job-002',
            'name': 'User Activity Analysis',
            'state': 'RUNNING',
            'eventsProcessed': 89000,
            'eventsPerSecond': 620.2,
            'avgLatency': 15.7,
          },
          {
            'jobId': 'job-003',
            'name': 'Transaction Monitoring',
            'state': 'PAUSED',
            'eventsProcessed': 45000,
            'eventsPerSecond': 0,
            'avgLatency': 0,
          },
        ];
        
        if (_jobs.isNotEmpty) {
          _selectedJobId = _jobs.first['jobId'];
        }
      });
    } catch (e) {
      print('Error loading jobs: $e');
    }
  }
  
  void _startMetricsPolling() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_selectedJobId != null) {
        _updateJobMetrics();
      }
    });
  }
  
  void _updateJobMetrics() {
    setState(() {
      final time = _eventsProcessedData.length.toDouble();
      if (_eventsProcessedData.length > 30) {
        _eventsProcessedData.removeAt(0);
        _latencyData.removeAt(0);
      }
      
      // Simulate metrics
      final job = _jobs.firstWhere((j) => j['jobId'] == _selectedJobId);
      _eventsProcessedData.add(FlSpot(time, job['eventsPerSecond'] / 10));
      _latencyData.add(FlSpot(time, 10 + (DateTime.now().millisecond % 20).toDouble()));
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
      appBar: AppBar(
        title: const Text('Job Metrics'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Job selector
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
              child: DropdownButton<String>(
                value: _selectedJobId,
                isExpanded: true,
                underline: const SizedBox(),
                dropdownColor: const Color(0xFF1E293B),
                style: const TextStyle(color: Colors.white, fontSize: 16),
                items: _jobs.map((job) {
                  return DropdownMenuItem<String>(
                    value: job['jobId'],
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _getStateColor(job['state']),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(job['name']),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedJobId = value;
                    _eventsProcessedData.clear();
                    _latencyData.clear();
                  });
                },
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Metrics cards for selected job
            if (_selectedJobId != null) ...[
              Row(
                children: [
                  Expanded(child: _buildMetricCard(
                    'Events Processed',
                    _getSelectedJob()['eventsProcessed'].toString(),
                    Icons.bar_chart,
                    const Color(0xFF6366F1),
                  )),
                  const SizedBox(width: 16),
                  Expanded(child: _buildMetricCard(
                    'Events/Sec',
                    _getSelectedJob()['eventsPerSecond'].toStringAsFixed(1),
                    Icons.speed,
                    const Color(0xFF10B981),
                  )),
                  const SizedBox(width: 16),
                  Expanded(child: _buildMetricCard(
                    'Avg Latency',
                    '${_getSelectedJob()['avgLatency']} ms',
                    Icons.timer,
                    const Color(0xFFF59E0B),
                  )),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Charts
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: _buildChartCard(
                        'Throughput',
                        _buildLineChart(_eventsProcessedData, const Color(0xFF6366F1)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildChartCard(
                        'Latency (ms)',
                        _buildLineChart(_latencyData, const Color(0xFFF59E0B), maxY: 40),
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
  
  Map<String, dynamic> _getSelectedJob() {
    return _jobs.firstWhere((j) => j['jobId'] == _selectedJobId, orElse: () => {});
  }
  
  Color _getStateColor(String state) {
    switch (state) {
      case 'RUNNING':
        return const Color(0xFF10B981);
      case 'PAUSED':
        return const Color(0xFFF59E0B);
      case 'FAILED':
        return const Color(0xFFEF4444);
      default:
        return Colors.grey;
    }
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
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
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
  
  Widget _buildChartCard(String title, Widget chart) {
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
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(child: chart),
        ],
      ),
    );
  }
  
  Widget _buildLineChart(List<FlSpot> data, Color color, {double maxY = 100}) {
    if (data.isEmpty) {
      return const Center(
        child: Text(
          'No data yet',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }
    
    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
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
        maxY: maxY,
      ),
    );
  }
}
