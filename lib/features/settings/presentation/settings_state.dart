import 'package:flutter/foundation.dart';
import 'package:knit/features/settings/domain/app_preferences.dart';

/// App-wide settings state (fcis.md §6.1). Just the current [preferences]: the
/// defaults are always valid, so there's no loading/failed gate — the app and
/// the settings pages render off [preferences] from the first frame, and the
/// persisted values overlay them once the async load lands.
@immutable
class SettingsState {
  const SettingsState({this.preferences = const AppPreferences()});

  final AppPreferences preferences;

  SettingsState copyWith({AppPreferences? preferences}) =>
      SettingsState(preferences: preferences ?? this.preferences);
}
