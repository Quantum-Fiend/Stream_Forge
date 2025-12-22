import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  final String baseUrl;

  ApiService({required this.baseUrl});

  Future<Map<String, dynamic>> getClusterMetrics() async {
    final response = await http.get(Uri.parse('$baseUrl/api/metrics/cluster'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Failed to load cluster metrics');
  }

  Future<List<dynamic>> getJobs() async {
    final response = await http.get(Uri.parse('$baseUrl/api/jobs'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Failed to load jobs');
  }

  Future<Map<String, dynamic>> getJobStatus(String jobId) async {
    final response = await http.get(Uri.parse('$baseUrl/api/jobs/$jobId'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Failed to load job status');
  }

  Future<Map<String, dynamic>> submitJob(Map<String, dynamic> jobDef) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/jobs'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(jobDef),
    );
    if (response.statusCode == 201 || response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Failed to submit job');
  }

  Future<void> pauseJob(String jobId) async {
    await http.post(Uri.parse('$baseUrl/api/jobs/$jobId/pause'));
  }

  Future<void> resumeJob(String jobId) async {
    await http.post(Uri.parse('$baseUrl/api/jobs/$jobId/resume'));
  }

  Future<void> cancelJob(String jobId) async {
    await http.delete(Uri.parse(' $baseUrl/api/jobs/$jobId'));
  }
}
