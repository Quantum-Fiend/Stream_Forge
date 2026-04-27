import 'package:flutter/material.dart';
import '../services/mock_data_service.dart';
import 'dart:async';

class JobManagementPage extends StatefulWidget {
  const JobManagementPage({Key? key}) : super(key: key);

  @override
  State<JobManagementPage> createState() => _JobManagementPageState();
}

class _JobManagementPageState extends State<JobManagementPage> {
  List<Map<String, dynamic>> _jobs = [];
  Timer? _timer;
  final _mockData = MockDataService();

  @override
  void initState() {
    super.initState();
    _loadJobs();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _loadJobs());
  }

  void _loadJobs() {
    setState(() => _jobs = _mockData.getJobs());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // ── Actions ──────────────────────────────────────────────────────────────

  Future<void> _pauseJob(String jobId, String name) async {
    _mockData.pauseJob(jobId);
    _loadJobs();
    _showSnack('⏸  Paused "$name"', const Color(0xFFF59E0B));
  }

  Future<void> _resumeJob(String jobId, String name) async {
    _mockData.resumeJob(jobId);
    _loadJobs();
    _showSnack('▶  Resumed "$name"', const Color(0xFF10B981));
  }

  Future<void> _cancelJob(String jobId, String name) async {
    final confirmed = await _showConfirmDialog(
      'Cancel Job',
      'Are you sure you want to cancel "$name"? This action cannot be undone.',
    );
    if (!confirmed) return;
    _mockData.cancelJob(jobId);
    _loadJobs();
    _showSnack('🗑  Cancelled "$name"', const Color(0xFFEF4444));
  }

  void _showSnack(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        backgroundColor: color.withOpacity(0.9),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<bool> _showConfirmDialog(String title, String message) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title:
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            content: Text(message,
                style: TextStyle(color: Colors.white.withOpacity(0.7))),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text('Cancel',
                      style: TextStyle(color: Colors.white.withOpacity(0.6)))),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Confirm',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showDetailsSheet(Map<String, dynamic> job) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _JobDetailsSheet(job: job),
    );
  }

  void _showCreateJobDialog() {
    showDialog(
      context: context,
      builder: (ctx) => _CreateJobDialog(
        onCreated: (name, type, parallelism, source, sink) {
          _mockData.createJob(
            name: name,
            type: type,
            parallelism: parallelism,
            source: source,
            sink: sink,
          );
          _loadJobs();
          _showSnack('✅  Job "$name" created', const Color(0xFF6366F1));
        },
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Job Management',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              onPressed: _showCreateJobDialog,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('New Job'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                _buildStatCard(
                    'Total', _jobs.length.toString(), Icons.work_outline_rounded,
                    const Color(0xFF6366F1)),
                const SizedBox(width: 12),
                _buildStatCard(
                    'Running',
                    _jobs.where((j) => j['state'] == 'RUNNING').length.toString(),
                    Icons.play_circle_outline_rounded,
                    const Color(0xFF10B981)),
                const SizedBox(width: 12),
                _buildStatCard(
                    'Paused',
                    _jobs.where((j) => j['state'] == 'PAUSED').length.toString(),
                    Icons.pause_circle_outline_rounded,
                    const Color(0xFFF59E0B)),
                const SizedBox(width: 12),
                _buildStatCard(
                    'Completed',
                    _jobs.where((j) => j['state'] == 'COMPLETED').length.toString(),
                    Icons.check_circle_outline_rounded,
                    const Color(0xFF8B5CF6)),
              ],
            ),

            const SizedBox(height: 24),

            // Jobs list
            Expanded(
              child: _jobs.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.work_off_outlined,
                              size: 56, color: Colors.white24),
                          SizedBox(height: 12),
                          Text('No jobs yet. Create one!',
                              style: TextStyle(color: Colors.white38)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _jobs.length,
                      itemBuilder: (context, i) => _buildJobCard(_jobs[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                Text(label,
                    style: TextStyle(
                        fontSize: 11, color: Colors.white.withOpacity(0.5))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJobCard(Map<String, dynamic> job) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            job['name'],
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 10),
                        _buildTypeBadge(job['type']),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'ID: ${job['jobId']}',
                      style: TextStyle(
                          fontSize: 11, color: Colors.white.withOpacity(0.4)),
                    ),
                  ],
                ),
              ),
              _buildStateChip(job['state']),
            ],
          ),

          const SizedBox(height: 14),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 14),

          // Metrics row
          Row(
            children: [
              _buildMiniMetric(Icons.schedule_rounded,
                  _formatDuration(DateTime.now().difference(job['startTime']))),
              const SizedBox(width: 20),
              _buildMiniMetric(
                  Icons.bolt_rounded,
                  job['state'] == 'RUNNING'
                      ? '${(job['eventsPerSecond'] as double).toStringAsFixed(0)}/s'
                      : '—'),
              const SizedBox(width: 20),
              _buildMiniMetric(
                  Icons.timer_outlined,
                  job['state'] == 'RUNNING'
                      ? '${(job['avgLatency'] as double).toStringAsFixed(1)} ms'
                      : '—'),
            ],
          ),

          const SizedBox(height: 14),

          // Action buttons
          Row(
            children: [
              if (job['state'] == 'RUNNING')
                _buildActionBtn('Pause', Icons.pause_rounded,
                    () => _pauseJob(job['jobId'], job['name'])),
              if (job['state'] == 'PAUSED')
                _buildActionBtn('Resume', Icons.play_arrow_rounded,
                    () => _resumeJob(job['jobId'], job['name'])),
              const SizedBox(width: 10),
              _buildActionBtn(
                  'Details', Icons.info_outline_rounded, () => _showDetailsSheet(job)),
              const SizedBox(width: 10),
              if (job['state'] != 'COMPLETED')
                _buildActionBtn(
                    'Cancel', Icons.close_rounded,
                    () => _cancelJob(job['jobId'], job['name']),
                    isDestructive: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniMetric(IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.white38),
        const SizedBox(width: 4),
        Text(value,
            style:
                const TextStyle(fontSize: 13, color: Colors.white60)),
      ],
    );
  }

  Widget _buildTypeBadge(String type) {
    final isStreaming = type == 'STREAMING';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isStreaming
            ? const Color(0xFF6366F1).withOpacity(0.15)
            : const Color(0xFF10B981).withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        type,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: isStreaming ? const Color(0xFF6366F1) : const Color(0xFF10B981),
        ),
      ),
    );
  }

  Widget _buildStateChip(String state) {
    final map = {
      'RUNNING': const Color(0xFF10B981),
      'PAUSED': const Color(0xFFF59E0B),
      'FAILED': const Color(0xFFEF4444),
      'COMPLETED': const Color(0xFF8B5CF6),
    };
    final color = map[state] ?? Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 7,
              height: 7,
              decoration:
                  BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(state,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: color)),
        ],
      ),
    );
  }

  Widget _buildActionBtn(String label, IconData icon, VoidCallback onPressed,
      {bool isDestructive = false}) {
    final color =
        isDestructive ? const Color(0xFFEF4444) : Colors.white60;
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 14),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withOpacity(0.5)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  String _formatDuration(Duration d) {
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes % 60}m';
    if (d.inMinutes > 0) return '${d.inMinutes}m';
    return '${d.inSeconds}s';
  }
}

// ── Details Bottom Sheet ───────────────────────────────────────────────────

class _JobDetailsSheet extends StatelessWidget {
  final Map<String, dynamic> job;
  const _JobDetailsSheet({required this.job});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            job['name'],
            style: const TextStyle(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text('ID: ${job['jobId']}',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.4), fontSize: 12)),
          const SizedBox(height: 20),
          _row('Type', job['type']),
          _row('State', job['state']),
          _row('Parallelism', '${job['parallelism']} workers'),
          _row('Source', job['source']),
          _row('Sink', job['sink']),
          _row('Events Processed',
              _formatNum(job['eventsProcessed'])),
          _row('Events / sec',
              job['state'] == 'RUNNING'
                  ? '${(job['eventsPerSecond'] as double).toStringAsFixed(1)}/s'
                  : '—'),
          _row('Avg Latency',
              job['state'] == 'RUNNING'
                  ? '${(job['avgLatency'] as double).toStringAsFixed(1)} ms'
                  : '—'),
          _row('Started',
              _formatDuration(DateTime.now().difference(job['startTime'])) +
                  ' ago'),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(label,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.5), fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  String _formatNum(dynamic n) {
    final v = n is int ? n : (n as double).toInt();
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(2)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toString();
  }

  String _formatDuration(Duration d) {
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes % 60}m';
    if (d.inMinutes > 0) return '${d.inMinutes}m';
    return '${d.inSeconds}s';
  }
}

// ── Create Job Dialog ──────────────────────────────────────────────────────

class _CreateJobDialog extends StatefulWidget {
  final void Function(
      String name, String type, int parallelism, String source, String sink)
      onCreated;

  const _CreateJobDialog({required this.onCreated});

  @override
  State<_CreateJobDialog> createState() => _CreateJobDialogState();
}

class _CreateJobDialogState extends State<_CreateJobDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _sourceCtrl = TextEditingController();
  final _sinkCtrl = TextEditingController();
  String _type = 'STREAMING';
  int _parallelism = 2;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _sourceCtrl.dispose();
    _sinkCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Create New Job',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field('Job Name', _nameCtrl, 'e.g. Click Stream Aggregation'),
              const SizedBox(height: 14),
              _field('Source', _sourceCtrl, 'e.g. events'),
              const SizedBox(height: 14),
              _field('Sink', _sinkCtrl, 'e.g. dashboard'),
              const SizedBox(height: 16),
              // Type selector
              Row(
                children: ['STREAMING', 'BATCH'].map((t) {
                  final selected = _type == t;
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                          right: t == 'STREAMING' ? 8 : 0),
                      child: GestureDetector(
                        onTap: () => setState(() => _type = t),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: selected
                                ? const Color(0xFF6366F1).withOpacity(0.2)
                                : Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: selected
                                  ? const Color(0xFF6366F1)
                                  : Colors.white.withOpacity(0.15),
                            ),
                          ),
                          child: Text(
                            t,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: selected
                                  ? const Color(0xFF6366F1)
                                  : Colors.white54,
                              fontWeight: selected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              // Parallelism slider
              Row(
                children: [
                  Text('Parallelism',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.6), fontSize: 13)),
                  const Spacer(),
                  Text('$_parallelism workers',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                ],
              ),
              Slider(
                value: _parallelism.toDouble(),
                min: 1,
                max: 8,
                divisions: 7,
                activeColor: const Color(0xFF6366F1),
                inactiveColor: Colors.white12,
                label: '$_parallelism',
                onChanged: (v) => setState(() => _parallelism = v.toInt()),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel',
              style: TextStyle(color: Colors.white.withOpacity(0.5))),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              widget.onCreated(
                _nameCtrl.text.trim(),
                _type,
                _parallelism,
                _sourceCtrl.text.trim(),
                _sinkCtrl.text.trim(),
              );
              Navigator.pop(context);
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6366F1),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Create', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  Widget _field(String label, TextEditingController ctrl, String hint) {
    return TextFormField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
        hintStyle:
            TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 13),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              BorderSide(color: Colors.white.withOpacity(0.15)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF6366F1)),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFEF4444)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFEF4444)),
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      validator: (v) =>
          (v == null || v.trim().isEmpty) ? 'Required' : null,
    );
  }
}
