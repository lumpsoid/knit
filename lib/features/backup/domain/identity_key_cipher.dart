import 'package:result_dart/result_dart.dart';
import 'package:knit/features/backup/domain/backup_failure.dart';
import 'package:knit/features/backup/domain/backup_models.dart';
import 'package:knit/sync/identity/identity.dart';

/// Seals the device keypair under a user passphrase for the backup bundle, and
/// opens it again on restore. The one place the KDF + cipher live.
abstract interface class IdentityKeyCipher {
  Future<SealedIdentity> seal(Keypair keypair, String passphrase);

  /// The keypair, or [BackupWrongPassphraseFailure] when [passphrase] doesn't
  /// open [sealed].
  Future<Result<Keypair, BackupFailure>> open(
    SealedIdentity sealed,
    String passphrase,
  );
}
