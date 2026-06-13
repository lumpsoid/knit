import 'package:knit/features/profile/presentation/profile_controller.dart';

/// Cell for [ProfileController] (fcis.md §4). An app-wide singleton, lazily
/// built the first time the Profile page is opened.
abstract class ProfileScope {
  static ProfileController? _controller;
  static ProfileController Function()? _factory;

  static void setController(ProfileController c) => _controller = c;
  static void setFactory(ProfileController Function() factory) =>
      _factory = factory;
  static void reset() => _controller = null;

  static ProfileController get controller {
    if (_controller != null) return _controller!;
    if (_factory == null) {
      throw StateError(
        'ProfileScope is not initialized.\n'
        'Call ProfileScope.setController() or ProfileScope.setFactory() '
        'before accessing ProfileScope.controller.',
      );
    }
    return _controller = _factory!();
  }
}
