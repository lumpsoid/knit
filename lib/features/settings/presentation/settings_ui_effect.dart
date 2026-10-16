import 'package:knit/features/backup/domain/backup_models.dart';
import 'package:knit/features/settings/domain/identity_reset_confirmation.dart';
import 'package:knit/features/settings/presentation/settings_action.dart';

/// One-shot UI effects the shell pushes for the Settings views (fcis.md §6.4).
sealed class SettingsUiEffect {
  const SettingsUiEffect();
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

/// A picked bundle belongs to another identity — ask the user to confirm
/// replacing this device and to enter the bundle's passphrase. [createdAtMs]
/// dates the bundle; [wrongPassphrase] is set when re-asking after a miss.
class SettingsConfirmReplaceUiEffect extends SettingsUiEffect {
  const SettingsConfirmReplaceUiEffect({
    required this.createdAtMs,
    this.wrongPassphrase = false,
  });
  final int createdAtMs;
  final bool wrongPassphrase;
}

/// This device was replaced by a bundle from another identity.
class SettingsDeviceReplacedUiEffect extends SettingsUiEffect {
  const SettingsDeviceReplacedUiEffect(this.summary);
  final ImportSummary summary;
}

/// Ask the user to confirm "Reset identity" by typing [confirmation]'s word.
class SettingsConfirmResetUiEffect extends SettingsUiEffect {
  const SettingsConfirmResetUiEffect(this.confirmation);
  final IdentityResetConfirmation confirmation;
}

/// The data and keypair are gone — the page leaves for onboarding.
class SettingsIdentityResetUiEffect extends SettingsUiEffect {
  const SettingsIdentityResetUiEffect();
}

/// Resetting the identity (or reading it for the confirmation) failed.
class SettingsResetFailedUiEffect extends SettingsUiEffect {
  const SettingsResetFailedUiEffect();
}
