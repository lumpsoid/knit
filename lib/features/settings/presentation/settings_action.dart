import 'package:knit/features/settings/domain/app_preferences.dart';

/// The data-management actions on the Data subpage (§4 settings). Export and
/// import are implemented (backup bundle); the identity/wipe/reset actions are
/// still placeholders the shell answers with a "coming soon" notice.
enum DataAction {
  exportData,
  importData,
  exportIdentity,
  wipeData,
  resetIdentity,
}

/// Where an export bundle goes once built — chosen by the user in a bottom sheet.
enum BackupDestination { share, saveFile }

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

/// The user tapped a data-management action on the Data subpage (import /
/// identity / wipe / reset). Export goes through [ExportRequested] instead, since
/// it first asks the user where the bundle should go.
class DataActionRequested extends SettingsAction {
  const DataActionRequested(this.action);
  final DataAction action;
}

/// The user chose an export destination in the bottom sheet — build the bundle
/// and deliver it there.
class ExportRequested extends SettingsAction {
  const ExportRequested(this.destination);
  final BackupDestination destination;
}

/// A long data action (export build/deliver, or import restore) finished — clear
/// the busy spinner. Carries no result; success/failure is reported via UiEffect.
class DataActionFinished extends SettingsAction {
  const DataActionFinished();
}
