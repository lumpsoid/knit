import 'package:knit/features/backup/domain/backup_models.dart';
import 'package:knit/features/settings/presentation/settings_action.dart';

/// One-shot UI effects the shell pushes for the Settings views (fcis.md §6.4).
sealed class SettingsUiEffect {
  const SettingsUiEffect();
}

/// Announce that a data-management action isn't implemented yet — the Data page
/// maps the [DataAction] to a localized label and shows a "coming soon" snackbar
/// without the shell touching `BuildContext` or l10n.
class SettingsComingSoonUiEffect extends SettingsUiEffect {
  const SettingsComingSoonUiEffect(this.action);
  final DataAction action;
}

/// The backup bundle was built and delivered to [destination] (shared, or saved
/// to a file). The page localizes the confirmation per destination.
class SettingsBackupExportedUiEffect extends SettingsUiEffect {
  const SettingsBackupExportedUiEffect(this.destination);
  final BackupDestination destination;
}

/// A backup was restored — carries the [ImportSummary] so the page can report
/// the counts (and any quarantined ops / corrupt blobs) honestly.
class SettingsBackupImportedUiEffect extends SettingsUiEffect {
  const SettingsBackupImportedUiEffect(this.summary);
  final ImportSummary summary;
}

/// A backup [action] (export or import) failed — the page maps it to a localized
/// message. The real cause was already logged by the shell.
class SettingsBackupFailedUiEffect extends SettingsUiEffect {
  const SettingsBackupFailedUiEffect(this.action);
  final DataAction action;
}

/// The device's data was wiped — every collection, card, and link is gone. The
/// page confirms the clean slate.
class SettingsDataWipedUiEffect extends SettingsUiEffect {
  const SettingsDataWipedUiEffect();
}

/// Wiping the device's data failed — some content may remain. The page maps it
/// to a localized message; the real cause was already logged by the shell.
class SettingsWipeFailedUiEffect extends SettingsUiEffect {
  const SettingsWipeFailedUiEffect();
}
