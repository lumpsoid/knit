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

/// Carry out a data-management action (§4 settings). The placeholder home for
/// export/import/identity/wipe/reset; today the shell turns it into a "coming
/// soon" notice, later into the real flow.
class RunDataActionEffect extends SettingsEffect {
  const RunDataActionEffect(this.action);
  final DataAction action;
}
