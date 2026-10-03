import 'dart:developer' as developer;

/// A logger used by backend internals.
abstract interface class SmartSaveLogger {
  /// Logs a debug message.
  void debug(String message);
  /// Logs an informational message.
  void info(String message);
  /// Logs a warning message.
  void warn(String message);
  /// Logs an error message with an optional cause.
  void error(String message, [Object? cause]);
}

/// A logger that discards all messages.
final class NoopLogger implements SmartSaveLogger {
  /// Creates a no-op logger.
  const NoopLogger();

  @override
  void debug(String message) {}
  @override
  void info(String message) {}
  @override
  void warn(String message) {}
  @override
  void error(String message, [Object? cause]) {}
}

/// A logger backed by `dart:developer`.
final class PrintLogger implements SmartSaveLogger {
  /// Creates a developer log logger.
  const PrintLogger();

  void _log(String message, {String level = 'INFO', Object? error}) {
    developer.log(message, name: 'SmartSave', level: level == 'ERROR' ? 1000 : 0, error: error);
  }

  @override
  void debug(String message) => _log(message, level: 'DEBUG');
  @override
  void info(String message) => _log(message);
  @override
  void warn(String message) => _log(message, level: 'WARN');
  @override
  void error(String message, [Object? cause]) =>
      _log(message, level: 'ERROR', error: cause);
}

/// Redacts PIN values in privileged protocol lines.
String redactPin(String line) {
  return line.replaceAllMapped(
    RegExp(r'^(AUTH|UNLOCK|ADJ|SETPIN):([^,]+)(,([^,]+))?$'),
    (match) {
      final command = match.group(1)!;
      final suffix = match.group(3);
      if (command == 'AUTH' || command == 'SETPIN') {
        return '$command:****${suffix == null ? '' : ',****'}';
      }
      return '$command:****${suffix ?? ''}';
    },
  );
}
