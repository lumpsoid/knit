import 'package:knit/features/settings/presentation/settings_controller.dart';

/// Cell for [SettingsController] (fcis.md §4). An app-wide singleton: the root
/// [KnitApp] resolves it to observe theme/locale, and every settings page shares
/// the same instance.
abstract class SettingsScope {
  static SettingsController? _controller;
  static SettingsController Function()? _factory;

  static void setController(SettingsController c) => _controller = c;
  static void setFactory(SettingsController Function() factory) =>
      _factory = factory;
  static void reset() => _controller = null;

  static SettingsController get controller {
    if (_controller != null) return _controller!;
    if (_factory == null) {
      throw StateError(
        'SettingsScope is not initialized.\n'
        'Call SettingsScope.setController() or SettingsScope.setFactory() '
        'before accessing SettingsScope.controller.',
      );
    }
    return _controller = _factory!();
  }
}
