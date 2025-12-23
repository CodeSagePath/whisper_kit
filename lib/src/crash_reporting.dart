/// Crash reporting utilities.
///
/// Capture and report errors for debugging.
library;

import 'dart:async';

/// Error severity levels.
enum ErrorSeverity {
  /// Debug - for development only.
  debug,

  /// Info - informational.
  info,

  /// Warning - potential issues.
  warning,

  /// Error - something went wrong.
  error,

  /// Fatal - app crashed.
  fatal,
}

/// Crash report data.
class CrashReport {
  CrashReport({
    required this.error,
    this.stackTrace,
    this.severity = ErrorSeverity.error,
    DateTime? timestamp,
    this.context,
    this.tags,
    this.userId,
    this.deviceInfo,
  }) : timestamp = timestamp ?? DateTime.now();

  /// The error that occurred.
  final Object error;

  /// Stack trace.
  final StackTrace? stackTrace;

  /// Error severity.
  final ErrorSeverity severity;

  /// When the error occurred.
  final DateTime timestamp;

  /// Additional context.
  final Map<String, dynamic>? context;

  /// Tags for categorization.
  final List<String>? tags;

  /// User ID if available.
  final String? userId;

  /// Device information.
  final Map<String, String>? deviceInfo;

  Map<String, dynamic> toJson() => {
        'error': error.toString(),
        'stackTrace': stackTrace?.toString(),
        'severity': severity.name,
        'timestamp': timestamp.toIso8601String(),
        'context': context,
        'tags': tags,
        'userId': userId,
        'deviceInfo': deviceInfo,
      };
}

/// Abstract crash reporter interface.
abstract class CrashReporter {
  /// Initialize the reporter.
  Future<void> initialize();

  /// Report a crash.
  Future<void> report(CrashReport report);

  /// Set user ID for reports.
  void setUserId(String? userId);

  /// Add default context.
  void setContext(String key, dynamic value);

  /// Enable/disable crash reporting.
  void setEnabled(bool enabled);
}

/// Crash reporting manager.
class CrashReporting {
  CrashReporting._();

  static CrashReporting? _instance;

  /// Singleton instance.
  static CrashReporting get instance {
    _instance ??= CrashReporting._();
    return _instance!;
  }

  CrashReporter? _reporter;
  bool _enabled = true;
  String? _userId;
  final Map<String, dynamic> _context = {};
  final List<CrashReport> _pendingReports = [];

  /// Set the crash reporter implementation.
  void setReporter(CrashReporter reporter) {
    _reporter = reporter;
    _flushPending();
  }

  /// Enable or disable crash reporting.
  void setEnabled(bool enabled) {
    _enabled = enabled;
    _reporter?.setEnabled(enabled);
  }

  /// Set user ID for reports.
  void setUserId(String? userId) {
    _userId = userId;
    _reporter?.setUserId(userId);
  }

  /// Add context to all future reports.
  void setContext(String key, dynamic value) {
    _context[key] = value;
    _reporter?.setContext(key, value);
  }

  /// Report an error.
  Future<void> reportError(
    Object error, {
    StackTrace? stackTrace,
    ErrorSeverity severity = ErrorSeverity.error,
    Map<String, dynamic>? context,
    List<String>? tags,
  }) async {
    if (!_enabled) return;

    final report = CrashReport(
      error: error,
      stackTrace: stackTrace,
      severity: severity,
      context: {..._context, ...?context},
      tags: tags,
      userId: _userId,
    );

    if (_reporter != null) {
      await _reporter!.report(report);
    } else {
      _pendingReports.add(report);
    }
  }

  /// Capture exception with automatic stack trace.
  Future<void> captureException(
    Object exception, {
    ErrorSeverity severity = ErrorSeverity.error,
    Map<String, dynamic>? context,
  }) async {
    await reportError(
      exception,
      stackTrace: StackTrace.current,
      severity: severity,
      context: context,
    );
  }

  /// Record a breadcrumb for debugging.
  void recordBreadcrumb(String message, {Map<String, dynamic>? data}) {
    setContext('lastBreadcrumb', {
      'message': message,
      'timestamp': DateTime.now().toIso8601String(),
      'data': data,
    });
  }

  /// Wrap a function with crash reporting.
  Future<T> runGuarded<T>(
    Future<T> Function() fn, {
    T? fallbackValue,
  }) async {
    try {
      return await fn();
    } catch (e, st) {
      await reportError(e, stackTrace: st);
      if (fallbackValue != null) {
        return fallbackValue;
      }
      rethrow;
    }
  }

  void _flushPending() {
    if (_reporter == null) return;
    for (final report in _pendingReports) {
      _reporter!.report(report);
    }
    _pendingReports.clear();
  }
}

/// In-memory crash reporter for testing/debugging.
class InMemoryCrashReporter implements CrashReporter {
  final List<CrashReport> reports = [];
  bool _enabled = true;
  String? _userId;
  final Map<String, dynamic> _context = {};

  @override
  Future<void> initialize() async {}

  @override
  Future<void> report(CrashReport report) async {
    if (_enabled) {
      reports.add(report);
    }
  }

  @override
  void setUserId(String? userId) => _userId = userId;

  /// Get current user ID.
  String? get userId => _userId;

  @override
  void setContext(String key, dynamic value) => _context[key] = value;

  @override
  void setEnabled(bool enabled) => _enabled = enabled;

  /// Clear all reports.
  void clear() => reports.clear();

  /// Get reports by severity.
  List<CrashReport> getBySeverity(ErrorSeverity severity) {
    return reports.where((r) => r.severity == severity).toList();
  }
}
