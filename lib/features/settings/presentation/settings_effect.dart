import 'package:knit/features/settings/domain/app_preferences.dart';
import 'package:knit/features/settings/presentation/settings_action.dart';

/// Async-work descriptors for Settings (fcis.md §6.4).
sealed class SettingsEffect {
  const SettingsEffect();
}

/// Read the persisted preferences (theme + language).
class LoadPreferencesEffect extends SettingsEffect {
  const LoadPreferencesEffect();
}

/// Persist the current preference set.
class SavePreferencesEffect extends SettingsEffect {
  const SavePreferencesEffect(this.preferences);
  final AppPreferences preferences;
}

/// Carry out a data-management action (§4 settings): import runs the restore
/// flow; identity/wipe/reset are still "coming soon".
class RunDataActionEffect extends SettingsEffect {
  const RunDataActionEffect(this.action);
  final DataAction action;
}

/// Build the backup bundle and deliver it to [destination] (share sheet or a
/// user-chosen file).
class RunExportEffect extends SettingsEffect {
  const RunExportEffect(this.destination);
  final BackupDestination destination;
}
