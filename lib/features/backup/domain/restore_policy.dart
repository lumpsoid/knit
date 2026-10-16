import 'package:knit/features/backup/domain/backup_models.dart';

/// Decides how a backup bundle restores onto this device. Data is signed by the
/// keypair, so a bundle from another identity replaces the device (keypair and
/// all) rather than mixing two owners' records; a bundle from this identity
/// merges into what is already here.
class RestorePolicy {
  const RestorePolicy();

  /// [deviceAuthor] is this device's public key, or null before onboarding.
  RestoreKind decide({
    required String? deviceAuthor,
    required BackupBundle bundle,
  }) {
    if (deviceAuthor != null && deviceAuthor == bundle.author) {
      return RestoreKind.merge;
    }
    if (bundle.identity != null) return RestoreKind.replaceDevice;
    // A v1 bundle carries no keypair: it can still merge onto an existing
    // identity (its records keep their author), but can't create one.
    return deviceAuthor == null
        ? RestoreKind.missingIdentity
        : RestoreKind.merge;
  }
}
