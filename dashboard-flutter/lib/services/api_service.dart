import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, {this.statusCode});

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiService {
  final String baseUrl;

  ApiService({required this.baseUrl});

  Future<Map<String, dynamic>> getClusterMetrics() async {
    try {
      final response =
          await http.get(Uri.parse('$baseUrl/api/metrics/cluster'));
      if (response.statusCode == 200) return json.decode(response.body);
      throw ApiException('Failed to load cluster metrics',
          statusCode: response.statusCode);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Network error: $e');
    }
  }

  Future<List<dynamic>> getJobs() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/jobs'));
      if (response.statusCode == 200) return json.decode(response.body);
      throw ApiException('Failed to load jobs', statusCode: response.statusCode);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Network error: $e');
    }
  }

  Future<Map<String, dynamic>> getJobStatus(String jobId) async {
    try {
      final response =
          await http.get(Uri.parse('$baseUrl/api/jobs/$jobId'));
      if (response.statusCode == 200) return json.decode(response.body);
      throw ApiException('Failed to load job status',
          statusCode: response.statusCode);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Network error: $e');
    }
  }

  Future<Map<String, dynamic>> submitJob(Map<String, dynamic> jobDef) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/jobs'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(jobDef),
      );
      if (response.statusCode == 201 || response.statusCode == 200) {
        return json.decode(response.body);
      }
      throw ApiException('Failed to submit job', statusCode: response.statusCode);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Network error: $e');
    }
  }

  Future<void> pauseJob(String jobId) async {
    try {
      await http.post(Uri.parse('$baseUrl/api/jobs/$jobId/pause'));
    } catch (_) {}
  }

  Future<void> resumeJob(String jobId) async {
    try {
      await http.post(Uri.parse('$baseUrl/api/jobs/$jobId/resume'));
    } catch (_) {}
  }

  // Fixed: removed stray leading space that caused malformed URI
  Future<void> cancelJob(String jobId) async {
    try {
      await http.delete(Uri.parse('$baseUrl/api/jobs/$jobId'));
    } catch (_) {}
  }
}
