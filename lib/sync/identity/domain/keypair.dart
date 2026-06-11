/// An Ed25519 keypair (spec §5) — the on-device cryptographic identity.
///
/// [publicKeyHex] (lowercase hex) *is* the identity, and rides the wire as
/// `author` / `created_by` / profile `id`. [secretKey] is the raw signing key
/// (for the real impl, the 32-byte Ed25519 seed); it is local-only, stored
/// encrypted at rest (§6.5), and never leaves the device.
library;

class Keypair {
  const Keypair({required this.publicKeyHex, required this.secretKey});

  final String publicKeyHex;
  final List<int> secretKey;
}
