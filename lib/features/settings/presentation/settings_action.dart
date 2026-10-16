import 'package:knit/features/backup/domain/backup_models.dart';
import 'package:knit/features/settings/domain/app_preferences.dart';

/// The data-management actions on the Data subpage (§4 settings). A backup
/// carries the data *and* the passphrase-sealed keypair, since the data is
/// signed by the key; "Reset identity" likewise erases both.
enum DataAction { exportData, importData, wipeData, resetIdentity }

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
/// wipe / reset). Export goes through [ExportRequested] instead, since it first
/// asks for a passphrase and where the bundle should go.
class DataActionRequested extends SettingsAction {
  const DataActionRequested(this.action);
  final DataAction action;
}

/// The user chose a [passphrase] for the keypair and an export destination —
/// build the bundle and deliver it there.
class ExportRequested extends SettingsAction {
  const ExportRequested(this.destination, this.passphrase);
  final BackupDestination destination;
  final String passphrase;
}

/// A picked bundle belongs to another identity: hold it while the user confirms
/// replacing this device and enters the bundle's passphrase.
class RestoreAwaitingPassphrase extends SettingsAction {
  const RestoreAwaitingPassphrase(this.bundle);
  final BackupBundle bundle;
}

/// The user confirmed replacing this device with the held bundle.
class ReplaceDeviceConfirmed extends SettingsAction {
  const ReplaceDeviceConfirmed(this.passphrase);
  final String passphrase;
}

/// The user backed out of replacing this device — drop the held bundle.
class ReplaceDeviceCancelled extends SettingsAction {
  const ReplaceDeviceCancelled();
}

/// The replace finished (restored or failed for good) — drop the held bundle.
class RestoreSettled extends SettingsAction {
  const RestoreSettled();
}

/// The user typed the confirmation word and chose to reset the identity.
class ResetIdentityConfirmed extends SettingsAction {
  const ResetIdentityConfirmed();
}

/// A long data action (export build/deliver, or import restore) finished — clear
/// the busy spinner. Carries no result; success/failure is reported via UiEffect.
class DataActionFinished extends SettingsAction {
  const DataActionFinished();
}
