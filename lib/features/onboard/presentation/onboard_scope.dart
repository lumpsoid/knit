import 'package:knit/features/onboard/presentation/onboard_controller.dart';

/// Cell for [OnboardController] (fcis.md §4). The Scope holds nothing else.
abstract class OnboardScope {
  static OnboardController? _controller;
  static OnboardController Function()? _factory;

  static void setController(OnboardController c) => _controller = c;
  static void setFactory(OnboardController Function() factory) =>
      _factory = factory;
  static void reset() => _controller = null;

  static OnboardController get controller {
    if (_controller != null) return _controller!;
    if (_factory == null) {
      throw StateError(
        'OnboardScope is not initialized.\n'
        'Call OnboardScope.setController() or OnboardScope.setFactory() '
        'before accessing OnboardScope.controller.',
      );
    }
    return _controller = _factory!();
  }
}
