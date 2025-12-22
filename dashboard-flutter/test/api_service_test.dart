import 'package:flutter_test/flutter_test.dart';
import 'package:streamforge_dashboard/services/api_service.dart';

void main() {
  group('ApiService', () {
    late ApiService apiService;

    setUp(() {
      apiService = ApiService(baseUrl: 'http://localhost:8080');
    });

    test('should construct proper URLs', () {
      expect(apiService.baseUrl, 'http://localhost:8080');
    });
  });
}
