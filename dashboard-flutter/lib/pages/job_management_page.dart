import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import 'dart:async';

class JobManagementPage extends StatefulWidget {
  const JobManagementPage({Key? key}) : super(key: key);

  @override
  State<JobManagementPage> createState() => _JobManagementPageState();
}

class _JobManagementPageState extends State<JobManagementPage> {
  List<Map<String, dynamic>> _jobs = [];
  Timer? _timer;
  
  @override
  void initState() {
    super.initState();
    _loadJobs();
    _startPolling();
  }
  
  Future<void> _loadJobs() async {
    try {
      // Simulate loading jobs
      setState(() {
        _jobs = [
          {
            'jobId': 'job-001',
            'name': 'Click Stream Aggregation',
            'type': 'STREAMING',
            'state': 'RUNNING',
            'startTime': DateTime.now().subtract(const Duration(hours: 2)),
            'eventsProcessed': 125000,
          },
          {
            'jobId': 'job-002',
            'name': 'User Activity Analysis',
            'type': 'STREAMING',
            'state': 'RUNNING',
            'startTime': DateTime.now().subtract(const Duration(hours: 1)),
            'eventsProcessed': 89000,
          },
          {
            'jobId': 'job-003',
            'name': 'Transaction Monitoring',
            'type': 'BATCH',
            'state': 'PAUSED',
            'startTime': DateTime.now().subtract(const Duration(minutes: 30)),
            'eventsProcessed': 45000,
          },
          {
            'jobId': 'job-004',
            'name': 'Error Log Analysis',
            'type': 'BATCH',
            'state': 'COMPLETED',
            'startTime': DateTime.now().subtract(const Duration(hours: 3)),
            'eventsProcessed': 320000,
          },
        ];
      });
    } catch (e) {
      print('Error loading jobs: $e');
    }
  }
  
  void _startPolling() {
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _loadJobs();
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
        title: const Text('Job Management'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              onPressed: _showCreateJobDialog,
              icon: const Icon(Icons.add),
              label: const Text('New Job'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stats summary
            Row(
              children: [
                _buildStatCard('Total Jobs', _jobs.length.toString(), Icons.work_outline),
                const SizedBox(width: 16),
                _buildStatCard('Running', _jobs.where((j) => j['state'] == 'RUNNING').length.toString(), Icons.play_circle_outline),
                const SizedBox(width: 16),
                _buildStatCard('Completed', _jobs.where((j) => j['state'] == 'COMPLETED').length.toString(), Icons.check_circle_outline),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Jobs list
            Expanded(
              child: ListView.builder(
                itemCount: _jobs.length,
                itemBuilder: (context, index) {
                  final job = _jobs[index];
                  return _buildJobCard(job);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatCard(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF6366F1)),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildJobCard(Map<String, dynamic> job) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          job['name'],
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        _buildJobBadge(job['type']),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'ID: ${job['jobId']}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
              _buildStateChip(job['state']),
            ],
          ),
          
          const SizedBox(height: 16),
          
          Row(
            children: [
              Icon(Icons.schedule, size: 16, color: Colors.white.withOpacity(0.5)),
              const SizedBox(width: 8),
              Text(
                'Started ${_formatDuration(DateTime.now().difference(job['startTime']))} ago',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
              const SizedBox(width: 24),
              Icon(Icons.numbers, size: 16, color: Colors.white.withOpacity(0.5)),
              const SizedBox(width: 8),
              Text(
                '${job['eventsProcessed']} events',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Action buttons
          Row(
            children: [
              if (job['state'] == 'RUNNING') ...[
                _buildActionButton('Pause', Icons.pause, () => _pauseJob(job['jobId'])),
              ] else if (job['state'] == 'PAUSED') ...[
                _buildActionButton('Resume', Icons.play_arrow, () => _resumeJob(job['jobId'])),
              ],
              const SizedBox(width: 12),
              _buildActionButton('Details', Icons.info_outline, () {}),
              const SizedBox(width: 12),
              _buildActionButton('Cancel', Icons.close, () => _cancelJob(job['jobId']), isDestructive: true),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildJobBadge(String type) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: type == 'STREAMING' 
            ? const Color(0xFF6366F1).withOpacity(0.2)
            : const Color(0xFF10B981).withOpacity(0.2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        type,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: type == 'STREAMING' 
              ? const Color(0xFF6366F1)
              : const Color(0xFF10B981),
        ),
      ),
    );
  }
  
  Widget _buildStateChip(String state) {
    Color color;
    switch (state) {
      case 'RUNNING':
        color = const Color(0xFF10B981);
        break;
      case 'PAUSED':
        color = const Color(0xFFF59E0B);
        break;
      case 'FAILED':
        color = const Color(0xFFEF4444);
        break;
      case 'COMPLETED':
        color = const Color(0xFF6366F1);
        break;
      default:
        color = Colors.grey;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            state,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildActionButton(String label, IconData icon, VoidCallback onPressed, {bool isDestructive = false}) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: isDestructive ? const Color(0xFFEF4444) : Colors.white70,
        side: BorderSide(
          color: isDestructive  ? const Color(0xFFEF4444) : Colors.white.withOpacity(0.2),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
  
  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    } else {
      return '${duration.inMinutes}m';
    }
  }
  
  Future<void> _pauseJob(String jobId) async {
    print('Pausing job: $jobId');
    // await context.read<ApiService>().pauseJob(jobId);
    await _loadJobs();
  }
  
  Future<void> _resumeJob(String jobId) async {
    print('Resuming job: $jobId');
    // await context.read<ApiService>().resumeJob(jobId);
    await _loadJobs();
  }
  
  Future<void> _cancelJob(String jobId) async {
    print('Cancelling job: $jobId');
    // await context.read<ApiService>().cancelJob(jobId);
    await _loadJobs();
  }
  
  void _showCreateJobDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Create New Job'),
        content: const Text('Job creation form would go here'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // Create job
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
            ),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}
