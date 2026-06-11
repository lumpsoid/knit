/// The signing seam (spec §5/§6.8) — Ed25519 keygen, sign, and verify, abstracted
/// so the write/apply paths never depend on a concrete crypto library.
///
/// Production wires the real `package:cryptography` impl; dev/tests wire a
/// deterministic fake. Async because `cryptography` is `Future`-based — but it
/// only touches the already-async `SyncStore.writeLocal`/`applyRemote`
/// orchestration, never the synchronous merge-core.
library;

import 'package:knit/sync/identity/domain/keypair.dart';

abstract class Signer {
  /// Mint a fresh identity (§5).
  Future<Keypair> generate();

  /// `sig = Ed25519_sign(secret, bytes)` as lowercase hex (§6.8 / §7.1 r8). The
  /// [bytes] are the canonical payload bytes (`utf8(canonical)`).
  Future<String> sign(List<int> secretKey, List<int> bytes);

  /// `Ed25519_verify(publicKeyHex, bytes, sigHex)` — verify **over the received
  /// bytes**, never re-canonicalized (§7.0/§8.5 step 2). False on any failure.
  Future<bool> verify(String publicKeyHex, List<int> bytes, String sigHex);

  /// Short human fingerprint = first 4 hex chars of `SHA-256(pubkey)` (§5),
  /// e.g. `mira#a4f9` → `a4f9`.
  Future<String> fingerprintOf(String publicKeyHex);
}
