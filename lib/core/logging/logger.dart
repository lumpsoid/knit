import 'dart:developer' as developer;

/// Minimal logging seam injected into FCIS shells (fcis.md §6.8: "log catches,
/// never swallow"). Abstracted so shells never depend on a concrete sink.
abstract interface class Logger {
  void info(String message);
  void warning(String message);
  void error(String message, [Object? error, StackTrace? stackTrace]);
}

/// Default [Logger] over `dart:developer` (visible in the Flutter/IDE console).
class DevLogger implements Logger {
  const DevLogger({String name = 'knit'}) : _name = name;

  final String _name;

  @override
  void info(String message) =>
      developer.log(message, name: _name, level: 800);

  @override
  void warning(String message) =>
      developer.log(message, name: _name, level: 900);

  @override
  void error(String message, [Object? error, StackTrace? stackTrace]) =>
      developer.log(message,
          name: _name, level: 1000, error: error, stackTrace: stackTrace);
}
