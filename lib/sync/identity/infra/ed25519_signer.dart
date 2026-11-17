import 'package:cryptography/cryptography.dart';
import 'package:knit/sync/identity/domain/domain.dart';

/// Real [Signer] over `package:cryptography` — Ed25519 + SHA-256 (spec §5/§6.8).
///
/// [Keypair.secretKey] is the 32-byte Ed25519 seed (what `cryptography` calls
/// the private-key bytes); the keypair is reconstructed from it on each sign.
class Ed25519Signer implements Signer {
  Ed25519Signer({Ed25519? algorithm, Sha256? sha256})
    : _ed = algorithm ?? Ed25519(),
      _sha = sha256 ?? Sha256();

  final Ed25519 _ed;
  final Sha256 _sha;

  @override
  Future<Keypair> generate() async {
    final pair = await _ed.newKeyPair();
    final pub = await pair.extractPublicKey();
    final seed = await pair.extractPrivateKeyBytes();
    return Keypair(publicKeyHex: hexEncode(pub.bytes), secretKey: seed);
  }

  @override
  Future<String> sign(List<int> secretKey, List<int> bytes) async {
    final pair = await _ed.newKeyPairFromSeed(secretKey);
    final signature = await _ed.sign(bytes, keyPair: pair);
    return hexEncode(signature.bytes);
  }

  @override
  Future<bool> verify(
    String publicKeyHex,
    List<int> bytes,
    String sigHex,
  ) async {
    try {
      final publicKey = SimplePublicKey(
        hexDecode(publicKeyHex),
        type: KeyPairType.ed25519,
      );
      return await _ed.verify(
        bytes,
        signature: Signature(hexDecode(sigHex), publicKey: publicKey),
      );
    } on FormatException {
      // Non-hex author or sig — treat as a failed verification, not a crash.
      return false;
    }
  }

  @override
  Future<String> fingerprintOf(String publicKeyHex) async {
    final hash = await _sha.hash(hexDecode(publicKeyHex));
    return hexEncode(hash.bytes).substring(0, 4);
  }
}
