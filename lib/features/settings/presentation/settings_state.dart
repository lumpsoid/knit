import 'package:flutter/foundation.dart';
import 'package:knit/features/backup/domain/backup_models.dart';
import 'package:knit/features/settings/domain/app_preferences.dart';

/// App-wide settings state (fcis.md §6.1). [preferences] always has valid
/// defaults, so there's no loading/failed gate — the app and the settings pages
/// render off it from the first frame, and the persisted values overlay them
/// once the async load lands. [busy] is true while a long data action (building
/// or restoring a backup) runs, so the Data page can show a blocking spinner.
/// [pendingRestore] holds a picked bundle from another identity while the user
/// confirms replacing this device.
@immutable
class SettingsState {
  const SettingsState({
    this.preferences = const AppPreferences(),
    this.busy = false,
    this.pendingRestore,
  });

  final AppPreferences preferences;
  final bool busy;
  final BackupBundle? pendingRestore;

  SettingsState copyWith({
    AppPreferences? preferences,
    bool? busy,
    BackupBundle? pendingRestore,
    bool clearPendingRestore = false,
  }) => SettingsState(
    preferences: preferences ?? this.preferences,
    busy: busy ?? this.busy,
    pendingRestore: clearPendingRestore
        ? null
        : pendingRestore ?? this.pendingRestore,
  );
}
