import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Severity of a log line, ordered low → high.
enum LogLevel { debug, info, warn, error }

/// Lightweight, dependency-free app logger.
///
/// Why this exists: when something fails in the field the only thing the user
/// can hand back is the `flutter run` console. Bare `debugPrint` calls are
/// inconsistent and hard to grep, and they tend to swallow the *useful* part
/// of an error (e.g. an HTTP response body). [AppLog] gives every line a
/// timestamp, level and tag so logs read like `[12:34:56.789][E][API] ...`
/// and can be filtered by tag.
///
/// Conventions (see CLAUDE.md → "Logging"):
/// - Tag is a short SCREAMING-or-PascalCase subsystem name: `API`, `Sync`,
///   `Downloads`, `Audio`, `DB`, `Router`, or a screen name like `LikedSongs`.
/// - Use [d] for verbose tracing, [i] for notable lifecycle events, [w] for
///   recoverable problems, [e] for failures (always pass the error object).
/// - Logging is a no-op in release builds, so leave calls in committed code.
class AppLog {
  AppLog._();

  /// Master switch. On in debug/profile builds, off in release.
  static bool enabled = !kReleaseMode;

  /// When true, the API interceptor logs full request/response bodies. Noisy
  /// but invaluable when debugging a misbehaving endpoint; flip off if the
  /// console is flooded.
  static bool logNetworkBodies = true;

  /// Lines below this level are dropped. Lower to [LogLevel.info] to quiet
  /// down verbose tracing.
  static LogLevel minLevel = LogLevel.debug;

  static void d(String tag, String message) =>
      _log(LogLevel.debug, tag, message);

  static void i(String tag, String message) =>
      _log(LogLevel.info, tag, message);

  static void w(
    String tag,
    String message, [
    Object? error,
    StackTrace? stackTrace,
  ]) =>
      _log(LogLevel.warn, tag, message, error, stackTrace);

  static void e(
    String tag,
    String message, [
    Object? error,
    StackTrace? stackTrace,
  ]) =>
      _log(LogLevel.error, tag, message, error, stackTrace);

  static void _log(
    LogLevel level,
    String tag,
    String message, [
    Object? error,
    StackTrace? stackTrace,
  ]) {
    if (!enabled || level.index < minLevel.index) return;

    // HH:mm:ss.SSS — enough to correlate with backend logs without the date.
    final ts = DateTime.now().toIso8601String().substring(11, 23);
    final lvl = switch (level) {
      LogLevel.debug => 'D',
      LogLevel.info => 'I',
      LogLevel.warn => 'W',
      LogLevel.error => 'E',
    };

    final buffer = StringBuffer('[$ts][$lvl][$tag] $message');
    if (error != null) buffer.write('\n    └─ error: $error');
    if (stackTrace != null && level == LogLevel.error) {
      buffer.write('\n$stackTrace');
    }
    final line = buffer.toString();

    // debugPrint is what surfaces as `flutter: ...` in the run console (and is
    // rate-limit-safe for long lines). Also mirror to dart:developer so the
    // line is structured in DevTools / IDE log views.
    debugPrint(line);
    developer.log(
      message,
      time: DateTime.now(),
      level: switch (level) {
        LogLevel.debug => 500,
        LogLevel.info => 800,
        LogLevel.warn => 900,
        LogLevel.error => 1000,
      },
      name: tag,
      error: error,
      stackTrace: stackTrace,
    );
  }
}
