/// Why a backup passphrase was not accepted.
enum PassphraseIssue { tooShort, mismatch }

/// The rule for the passphrase that seals the keypair in a backup bundle: at
/// least [minLength] characters, typed twice the same.
class BackupPassphrasePolicy {
  const BackupPassphrasePolicy();

  static const int minLength = 8;

  /// The first problem with [passphrase] / [confirmation], or null if it's ok.
  PassphraseIssue? check(String passphrase, String confirmation) {
    if (passphrase.length < minLength) return PassphraseIssue.tooShort;
    if (passphrase != confirmation) return PassphraseIssue.mismatch;
    return null;
  }
}
