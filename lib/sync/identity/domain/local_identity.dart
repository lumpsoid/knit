/// The on-device identity row (spec §6.5 `local_identity`) — local-only, never
/// synced, never signed. Holds the public key and the **encrypted** secret key.
library;

class LocalIdentity {
  const LocalIdentity({
    required this.publicKeyHex,
    required this.secretKeyEnc,
    required this.createdAt,
  });

  /// Lowercase-hex public key — the identity (§5).
  final String publicKeyHex;

  /// The secret key sealed by a `SecretBox` (BLOB at rest, §6.5).
  final List<int> secretKeyEnc;

  /// ms wall-clock at provisioning (local metadata only).
  final int createdAt;
}
