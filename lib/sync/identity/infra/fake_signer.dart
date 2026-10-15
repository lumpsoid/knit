import 'dart:convert';
import 'dart:typed_data';

import 'package:knit/sync/identity/domain/domain.dart';

/// A **deterministic, non-cryptographic** [Signer] for dev mode and tests — no
/// real keys, no platform channels, fully synchronous under the hood.
///
/// Convention: the "secret key" of a fake identity is `utf8(publicKeyHex)`, so a
/// signature is `fakeSignHex(utf8(author), message)` and verification recomputes
/// the same MAC. That makes hand-crafted test ops (signed by author alone)
/// verifiable without owning a secret, while preserving the real signer's
/// contract: same payload → same sig → same `op_id` (idempotency, §7.3); flip a
/// byte → different sig (tamper rejected).
class FakeSigner implements Signer {
  FakeSigner({this.identitySeed = 'fake'});

  /// Distinguishes identities when a test simulates multiple devices.
  final String identitySeed;

  @override
  Future<Keypair> generate() async {
    final publicKeyHex = fakeSignHex(utf8.encode(identitySeed), const []);
    return Keypair(
      publicKeyHex: publicKeyHex,
      secretKey: utf8.encode(publicKeyHex),
    );
  }

  @override
  Future<String> sign(List<int> secretKey, List<int> bytes) async =>
      fakeSignHex(secretKey, bytes);

  @override
  Future<bool> verify(
    String publicKeyHex,
    List<int> bytes,
    String sigHex,
  ) async => fakeSignHex(utf8.encode(publicKeyHex), bytes) == sigHex;

  @override
  Future<String> fingerprintOf(String publicKeyHex) async =>
      fakeSignHex(utf8.encode(publicKeyHex), const []).substring(0, 4);
}

/// Deterministic 32-byte keyed digest as lowercase hex (an FNV-1a expansion).
/// Shared with test op-builders so hand-crafted ops verify under [FakeSigner].
/// NOT cryptographically secure — fakes only.
String fakeSignHex(List<int> key, List<int> message) {
  final out = Uint8List(32);
  for (var i = 0; i < out.length; i++) {
    var h = (0x811c9dc5 ^ (i * 0x01000193)) & 0xffffffff;
    for (final b in key) {
      h = ((h ^ b) * 0x01000193) & 0xffffffff;
    }
    h = ((h ^ 0x5f) * 0x01000193) & 0xffffffff; // key/message separator
    for (final b in message) {
      h = ((h ^ b) * 0x01000193) & 0xffffffff;
    }
    out[i] = ((h >> 24) ^ (h >> 16) ^ (h >> 8) ^ h) & 0xff;
  }
  return hexEncode(out);
}
