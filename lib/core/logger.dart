import 'package:flutter/foundation.dart';

/// Centralized logger for the NSBSA Admin System.
/// Standardizes debug outputs and prepares for future remote logging integrations (e.g., Sentry, Crashlytics).
class AppLogger {
  /// Logs general informational messages.
  static void info(String message, [String? tag]) {
    if (kDebugMode) {
      debugPrint('[INFO] ${tag != null ? '[$tag] ' : ''}$message');
    }
  }

  /// Logs warnings that do not stop execution but should be noted.
  static void warning(String message, [String? tag]) {
    if (kDebugMode) {
      debugPrint('[WARNING] ${tag != null ? '[$tag] ' : ''}$message');
    }
  }

  /// Logs errors, optionally including the exception object and stack trace.
  static void error(String message, {Object? error, StackTrace? stackTrace, String? tag}) {
    if (kDebugMode) {
      debugPrint('[ERROR] ${tag != null ? '[$tag] ' : ''}$message');
      if (error != null) {
        debugPrint('Details: $error');
      }
      if (stackTrace != null) {
        debugPrint('StackTrace: $stackTrace');
      }
    }
    // Future: send to Crashlytics / Sentry here
  }

  /// Logs critical data specifically for debugging complex flows.
  static void debug(String message, [String? tag]) {
    if (kDebugMode) {
      debugPrint('[DEBUG] ${tag != null ? '[$tag] ' : ''}$message');
    }
  }
}
