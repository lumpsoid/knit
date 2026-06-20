import 'package:flutter/foundation.dart';
import 'package:knit/features/settings/domain/app_preferences.dart';

/// App-wide settings state (fcis.md §6.1). [preferences] always has valid
/// defaults, so there's no loading/failed gate — the app and the settings pages
/// render off it from the first frame, and the persisted values overlay them
/// once the async load lands. [busy] is true while a long data action (building
/// or restoring a backup) runs, so the Data page can show a blocking spinner.
@immutable
class SettingsState {
  const SettingsState({
    this.preferences = const AppPreferences(),
    this.busy = false,
  });

  final AppPreferences preferences;
  final bool busy;

  SettingsState copyWith({AppPreferences? preferences, bool? busy}) =>
      SettingsState(
        preferences: preferences ?? this.preferences,
        busy: busy ?? this.busy,
      );
}
