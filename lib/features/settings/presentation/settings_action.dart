import 'package:knit/features/settings/domain/app_preferences.dart';

/// The data-management actions on the Data subpage (§4 settings). Each is a
/// placeholder today — the shell answers with a "coming soon" notice — but they
/// flow through the loop so the real implementations slot straight into the
/// shell later, no UI rewiring.
enum DataAction {
  exportData,
  importData,
  exportIdentity,
  wipeData,
  resetIdentity,
}

/// Intents + async-result deliveries for Settings (fcis.md §6.4).
sealed class SettingsAction {
  const SettingsAction();
}

/// The app mounted — load the persisted preferences.
class ViewAttached extends SettingsAction {
  const ViewAttached();
}

/// The persisted preferences were read.
class PreferencesLoaded extends SettingsAction {
  const PreferencesLoaded(this.preferences);
  final AppPreferences preferences;
}

/// Reading the preferences failed — the defaults stay in effect.
class PreferencesLoadFailed extends SettingsAction {
  const PreferencesLoadFailed();
}

/// The user picked a theme mode (applied optimistically, then persisted).
class ThemeModeSelected extends SettingsAction {
  const ThemeModeSelected(this.themeMode);
  final AppThemeMode themeMode;
}

/// The user picked a language (applied optimistically, then persisted).
class LanguageSelected extends SettingsAction {
  const LanguageSelected(this.language);
  final AppLanguage language;
}

/// A preference change was persisted.
class PreferencesSaved extends SettingsAction {
  const PreferencesSaved(this.preferences);
  final AppPreferences preferences;
}

/// Persisting a preference change failed (the choice still holds this session).
class PreferencesSaveFailed extends SettingsAction {
  const PreferencesSaveFailed();
}

/// The user tapped a data-management action on the Data subpage.
class DataActionRequested extends SettingsAction {
  const DataActionRequested(this.action);
  final DataAction action;
}
