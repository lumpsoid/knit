/// Encryption-at-rest seam for the local secret key (spec §6.5 — "secret
/// encrypted at rest, OS keystore / passphrase").
///
/// Kept abstract so a real OS-keystore impl can drop in later with **no schema
/// change** (`local_identity.secret_key_enc` stays a BLOB either way). The MVP
/// ships [PlaintextSecretBox]; see its warning.
library;

abstract class SecretBox {
  /// Encrypt a secret for storage in `local_identity.secret_key_enc`.
  List<int> seal(List<int> plaintext);

  /// Decrypt a stored secret back to the raw signing key.
  List<int> open(List<int> sealed);
}

/// **MVP stub — NOT encrypted at rest.** An identity transform that keeps the
/// `secret_key_enc` column honest without a platform-channel dependency, so the
/// sync core stays pure-Dart/CI-runnable. Replace with an OS-keystore impl
/// before shipping real keys.
class PlaintextSecretBox implements SecretBox {
  const PlaintextSecretBox();

  @override
  List<int> seal(List<int> plaintext) => plaintext;

  @override
  List<int> open(List<int> sealed) => sealed;
}
