/// REST API wrapper for transcription services.
///
/// Integrate with remote transcription APIs.
library;

import 'dart:async';
import 'dart:convert';

/// HTTP method types.
enum HttpMethod { get, post, put, delete, patch }

/// API response wrapper.
class ApiResponse<T> {
  const ApiResponse({
    required this.statusCode,
    this.data,
    this.error,
    this.headers,
  });

  /// HTTP status code.
  final int statusCode;

  /// Response data.
  final T? data;

  /// Error message.
  final String? error;

  /// Response headers.
  final Map<String, String>? headers;

  /// Whether the request was successful.
  bool get isSuccess => statusCode >= 200 && statusCode < 300;

  factory ApiResponse.success(T data, {int statusCode = 200}) =>
      ApiResponse(statusCode: statusCode, data: data);

  factory ApiResponse.error(String error, {int statusCode = 500}) =>
      ApiResponse(statusCode: statusCode, error: error);
}

/// API authentication configuration.
class ApiAuth {
  const ApiAuth({
    this.apiKey,
    this.bearerToken,
    this.basicAuth,
    this.customHeaders,
  });

  /// API key.
  final String? apiKey;

  /// Bearer token.
  final String? bearerToken;

  /// Basic auth credentials (username:password).
  final String? basicAuth;

  /// Custom auth headers.
  final Map<String, String>? customHeaders;

  Map<String, String> toHeaders() {
    final headers = <String, String>{};

    if (apiKey != null) {
      headers['X-API-Key'] = apiKey!;
    }
    if (bearerToken != null) {
      headers['Authorization'] = 'Bearer $bearerToken';
    }
    if (basicAuth != null) {
      final encoded = base64Encode(utf8.encode(basicAuth!));
      headers['Authorization'] = 'Basic $encoded';
    }
    if (customHeaders != null) {
      headers.addAll(customHeaders!);
    }

    return headers;
  }
}

/// REST API client configuration.
class RestApiConfig {
  const RestApiConfig({
    required this.baseUrl,
    this.auth,
    this.timeout = const Duration(seconds: 30),
    this.headers,
  });

  /// Base URL for the API.
  final String baseUrl;

  /// Authentication configuration.
  final ApiAuth? auth;

  /// Request timeout.
  final Duration timeout;

  /// Default headers.
  final Map<String, String>? headers;
}

/// Transcription API request.
class TranscriptionApiRequest {
  const TranscriptionApiRequest({
    required this.audioPath,
    this.language,
    this.model,
    this.translate = false,
    this.timestamps = true,
  });

  /// Path to audio file.
  final String audioPath;

  /// Source language.
  final String? language;

  /// Model to use.
  final String? model;

  /// Whether to translate.
  final bool translate;

  /// Include timestamps.
  final bool timestamps;
}

/// Transcription API response.
class TranscriptionApiResponse {
  const TranscriptionApiResponse({
    required this.text,
    this.segments,
    this.language,
    this.duration,
  });

  /// Transcribed text.
  final String text;

  /// Segments with timestamps.
  final List<Map<String, dynamic>>? segments;

  /// Detected language.
  final String? language;

  /// Audio duration in seconds.
  final double? duration;

  factory TranscriptionApiResponse.fromJson(Map<String, dynamic> json) {
    return TranscriptionApiResponse(
      text: json['text'] as String? ?? '',
      segments:
          (json['segments'] as List<dynamic>?)?.cast<Map<String, dynamic>>(),
      language: json['language'] as String?,
      duration: (json['duration'] as num?)?.toDouble(),
    );
  }
}

/// Abstract REST API client interface.
abstract class TranscriptionApiClient {
  /// Configure the client.
  void configure(RestApiConfig config);

  /// Transcribe audio file.
  Future<ApiResponse<TranscriptionApiResponse>> transcribe(
    TranscriptionApiRequest request,
  );

  /// Get available models.
  Future<ApiResponse<List<String>>> getModels();

  /// Check API health.
  Future<ApiResponse<bool>> healthCheck();
}

/// OpenAI-compatible API client.
class OpenAICompatibleClient implements TranscriptionApiClient {
  RestApiConfig? _config;

  @override
  void configure(RestApiConfig config) {
    _config = config;
  }

  @override
  Future<ApiResponse<TranscriptionApiResponse>> transcribe(
    TranscriptionApiRequest request,
  ) async {
    if (_config == null) {
      return ApiResponse.error('Client not configured');
    }

    try {
      // This is a placeholder for actual HTTP implementation
      // In real usage, you'd use http or dio package
      return ApiResponse.error('Not implemented - use with http package');
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }

  @override
  Future<ApiResponse<List<String>>> getModels() async {
    if (_config == null) {
      return ApiResponse.error('Client not configured');
    }

    // Placeholder
    return ApiResponse.success(['whisper-1']);
  }

  @override
  Future<ApiResponse<bool>> healthCheck() async {
    if (_config == null) {
      return ApiResponse.error('Client not configured');
    }

    return ApiResponse.success(true);
  }
}
