import 'package:knit/features/backup/domain/backup_models.dart';
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

/// Carry out a data-management action (§4 settings): import picks and plans a
/// restore, wipe erases the data, reset asks for the confirmation word.
class RunDataActionEffect extends SettingsEffect {
  const RunDataActionEffect(this.action);
  final DataAction action;
}

/// Build the backup bundle (keypair sealed under [passphrase]) and deliver it
/// to [destination] (share sheet or a user-chosen file).
class RunExportEffect extends SettingsEffect {
  const RunExportEffect(this.destination, this.passphrase);
  final BackupDestination destination;
  final String passphrase;
}

/// Erase this device and restore [bundle] onto it, its keypair unsealed with
/// [passphrase].
class RunReplaceDeviceEffect extends SettingsEffect {
  const RunReplaceDeviceEffect(this.bundle, this.passphrase);
  final BackupBundle bundle;
  final String passphrase;
}

/// Erase the data and the keypair — the device goes back to onboarding.
class RunResetIdentityEffect extends SettingsEffect {
  const RunResetIdentityEffect();
}
