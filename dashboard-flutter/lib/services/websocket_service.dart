import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketService {
  final String url;
  WebSocketChannel? _channel;
  final _metricsController = StreamController<Map<String, dynamic>>.broadcast();
  
  Stream<Map<String, dynamic>> get metricsStream => _metricsController.stream;

  WebSocketService({required this.url});

  void connect() {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));
      
      _channel!.stream.listen(
        (message) {
          final data = json.decode(message as String);
          _metricsController.add(data);
        },
        onError: (error) {
          print('WebSocket error: $error');
          // Attempt reconnection
          Future.delayed(const Duration(seconds: 5), () => connect());
        },
        onDone: () {
          print('WebSocket connection closed');
          // Attempt reconnection
          Future.delayed(const Duration(seconds: 5), () => connect());
        },
      );
    } catch (e) {
      print('Failed to connect WebSocket: $e');
    }
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
  }

  void send(Map<String, dynamic> message) {
    _channel?.sink.add(json.encode(message));
  }

  void dispose() {
    disconnect();
    _metricsController.close();
  }
}
