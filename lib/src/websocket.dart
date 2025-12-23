/// WebSocket support for real-time transcription.
///
/// Stream transcription results over WebSocket connections.
library;

import 'dart:async';
import 'dart:convert';

/// WebSocket message types.
enum WebSocketMessageType {
  /// Transcription started.
  started,

  /// Partial transcription result.
  partial,

  /// Final transcription result.
  complete,

  /// Error occurred.
  error,

  /// Ping/pong for keep-alive.
  ping,
  pong,
}

/// WebSocket message.
class WebSocketMessage {
  const WebSocketMessage({
    required this.type,
    this.data,
    this.timestamp,
    this.sessionId,
  });

  /// Message type.
  final WebSocketMessageType type;

  /// Message data.
  final Map<String, dynamic>? data;

  /// Message timestamp.
  final DateTime? timestamp;

  /// Session ID.
  final String? sessionId;

  String toJson() => jsonEncode({
        'type': type.name,
        'data': data,
        'timestamp': (timestamp ?? DateTime.now()).toIso8601String(),
        'sessionId': sessionId,
      });

  factory WebSocketMessage.fromJson(String json) {
    final map = jsonDecode(json) as Map<String, dynamic>;
    return WebSocketMessage(
      type: WebSocketMessageType.values.firstWhere(
        (t) => t.name == map['type'],
        orElse: () => WebSocketMessageType.error,
      ),
      data: map['data'] as Map<String, dynamic>?,
      timestamp: map['timestamp'] != null
          ? DateTime.parse(map['timestamp'] as String)
          : null,
      sessionId: map['sessionId'] as String?,
    );
  }
}

/// WebSocket connection configuration.
class WebSocketConfig {
  const WebSocketConfig({
    required this.url,
    this.headers,
    this.pingInterval = const Duration(seconds: 30),
    this.reconnectDelay = const Duration(seconds: 5),
    this.maxReconnectAttempts = 5,
  });

  /// WebSocket URL.
  final String url;

  /// Custom headers.
  final Map<String, String>? headers;

  /// Ping interval for keep-alive.
  final Duration pingInterval;

  /// Delay before reconnect attempts.
  final Duration reconnectDelay;

  /// Maximum reconnect attempts.
  final int maxReconnectAttempts;
}

/// Abstract WebSocket handler interface.
abstract class WebSocketHandler {
  /// Connect to server.
  Future<void> connect(WebSocketConfig config);

  /// Disconnect from server.
  Future<void> disconnect();

  /// Send a message.
  void send(WebSocketMessage message);

  /// Stream of incoming messages.
  Stream<WebSocketMessage> get messages;

  /// Connection state stream.
  Stream<bool> get connectionState;

  /// Check if connected.
  bool get isConnected;
}

/// WebSocket transcription client.
class WebSocketTranscriptionClient {
  WebSocketTranscriptionClient({
    this.handler,
    this.onTranscription,
    this.onError,
  });

  /// WebSocket handler.
  final WebSocketHandler? handler;

  /// Callback for transcription results.
  final void Function(String text, bool isFinal)? onTranscription;

  /// Callback for errors.
  final void Function(String error)? onError;

  StreamSubscription<WebSocketMessage>? _subscription;
  String? _sessionId;

  /// Start a transcription session.
  Future<String> startSession() async {
    _sessionId = DateTime.now().microsecondsSinceEpoch.toString();

    handler?.send(WebSocketMessage(
      type: WebSocketMessageType.started,
      sessionId: _sessionId,
    ));

    _subscription = handler?.messages.listen(_handleMessage);

    return _sessionId!;
  }

  /// End the transcription session.
  Future<void> endSession() async {
    await _subscription?.cancel();
    _subscription = null;
    _sessionId = null;
  }

  void _handleMessage(WebSocketMessage message) {
    if (message.sessionId != _sessionId) return;

    switch (message.type) {
      case WebSocketMessageType.partial:
        onTranscription?.call(
          message.data?['text'] as String? ?? '',
          false,
        );
        break;
      case WebSocketMessageType.complete:
        onTranscription?.call(
          message.data?['text'] as String? ?? '',
          true,
        );
        break;
      case WebSocketMessageType.error:
        onError?.call(message.data?['error'] as String? ?? 'Unknown error');
        break;
      default:
        break;
    }
  }
}
