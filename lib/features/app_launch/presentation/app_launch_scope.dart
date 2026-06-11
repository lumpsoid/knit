import 'package:knit/features/app_launch/presentation/app_launch_controller.dart';

/// Cell for [AppLaunchController] (fcis.md §4). The Scope holds nothing else.
abstract class AppLaunchScope {
  static AppLaunchController? _controller;
  static AppLaunchController Function()? _factory;

  static void setController(AppLaunchController c) => _controller = c;
  static void setFactory(AppLaunchController Function() factory) =>
      _factory = factory;
  static void reset() => _controller = null;

  static AppLaunchController get controller {
    if (_controller != null) return _controller!;
    if (_factory == null) {
      throw StateError(
        'AppLaunchScope is not initialized.\n'
        'Call AppLaunchScope.setController() or AppLaunchScope.setFactory() '
        'before accessing AppLaunchScope.controller.',
      );
    }
    return _controller = _factory!();
  }
}
