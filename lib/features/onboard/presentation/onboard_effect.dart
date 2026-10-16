import 'package:knit/features/backup/domain/backup_models.dart';

/// Async-work descriptors for Onboard (fcis.md §6.4).
sealed class OnboardEffect {
  const OnboardEffect();
}

/// Provision the identity + publish the profile for [nickname].
class CreateIdentityEffect extends OnboardEffect {
  const CreateIdentityEffect(this.nickname);
  final String nickname;
}

/// Leave onboarding for the timeline (shell pushes the navigate UiEffect).
class EnterAppEffect extends OnboardEffect {
  const EnterAppEffect();
}

/// Open the file picker for a backup and plan its restore.
class PickBackupEffect extends OnboardEffect {
  const PickBackupEffect();
}

/// Unseal [bundle]'s keypair with [passphrase], adopt it, replay the data.
class RestoreBackupEffect extends OnboardEffect {
  const RestoreBackupEffect(this.bundle, this.passphrase);
  final BackupBundle bundle;
  final String passphrase;
}
