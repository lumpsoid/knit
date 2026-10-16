import 'package:knit/features/backup/domain/backup_models.dart';
import 'package:knit/features/onboard/domain/identity_card.dart';
import 'package:knit/features/onboard/presentation/onboard_state.dart';

/// Intents + async-result deliveries for Onboard (fcis.md §6.4).
sealed class OnboardAction {
  const OnboardAction();
}

class ViewAttached extends OnboardAction {
  const ViewAttached();
}

class GetStartedTapped extends OnboardAction {
  const GetStartedTapped();
}

class NicknameChanged extends OnboardAction {
  const NicknameChanged(this.value);
  final String value;
}

class NicknameSubmitted extends OnboardAction {
  const NicknameSubmitted();
}

class BackTapped extends OnboardAction {
  const BackTapped();
}

class GenerateIdentityTapped extends OnboardAction {
  const GenerateIdentityTapped();
}

class IdentityCreated extends OnboardAction {
  const IdentityCreated(this.card);
  final IdentityCard card;
}

class IdentityCreationFailed extends OnboardAction {
  const IdentityCreationFailed();
}

class EnterAppTapped extends OnboardAction {
  const EnterAppTapped();
}

class DeactivateFeature extends OnboardAction {
  const DeactivateFeature();
}

/// The user chose "Restore from backup" on the welcome step.
class RestoreTapped extends OnboardAction {
  const RestoreTapped();
}

/// The file picker was dismissed.
class RestorePickCancelled extends OnboardAction {
  const RestorePickCancelled();
}

/// A backup with a keypair was picked — ask for its passphrase.
class RestorePicked extends OnboardAction {
  const RestorePicked(this.bundle);
  final BackupBundle bundle;
}

/// The restore can't go on (unreadable file, no keypair, or it failed).
class RestoreRejected extends OnboardAction {
  const RestoreRejected(this.error);
  final OnboardRestoreError error;
}

class RestorePassphraseSubmitted extends OnboardAction {
  const RestorePassphraseSubmitted(this.passphrase);
  final String passphrase;
}

/// The passphrase didn't open the backup's keypair.
class RestorePassphraseRejected extends OnboardAction {
  const RestorePassphraseRejected();
}

/// The backup was restored; [card] is the identity it brought back.
class IdentityRestored extends OnboardAction {
  const IdentityRestored(this.card);
  final IdentityCard card;
}
