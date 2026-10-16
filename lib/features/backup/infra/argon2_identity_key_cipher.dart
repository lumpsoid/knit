import 'dart:convert';
import 'dart:isolate';
import 'dart:math';

import 'package:cryptography/cryptography.dart' as crypto;
import 'package:cryptography/dart.dart';
import 'package:result_dart/result_dart.dart';
import 'package:knit/features/backup/domain/backup_failure.dart';
import 'package:knit/features/backup/domain/backup_models.dart';
import 'package:knit/features/backup/domain/identity_key_cipher.dart';
import 'package:knit/sync/identity/identity.dart';

/// [IdentityKeyCipher] over `package:cryptography`: the passphrase is stretched
/// with Argon2id ([KdfParams]) into a 256-bit key that seals the secret with
/// XChaCha20-Poly1305, the public key bound as associated data.
///
/// Argon2id is pure Dart and deliberately slow, so it runs on a background
/// isolate to keep the UI responsive. Tests pass tiny [params].
class Argon2IdentityKeyCipher implements IdentityKeyCipher {
  Argon2IdentityKeyCipher({this.params = KdfParams.recommended, Random? random})
    : _random = random ?? Random.secure();

  final KdfParams params;
  final Random _random;

  static const int _saltLength = 16;

  static final crypto.Cipher _aead = crypto.Xchacha20.poly1305Aead();

  @override
  Future<SealedIdentity> seal(Keypair keypair, String passphrase) async {
    final salt = List<int>.generate(_saltLength, (_) => _random.nextInt(256));
    final key = await _deriveKey(passphrase, salt, params);
    final box = await _aead.encrypt(
      keypair.secretKey,
      secretKey: key,
      nonce: _aead.newNonce(),
      aad: utf8.encode(keypair.publicKeyHex),
    );
    return SealedIdentity(
      publicKeyHex: keypair.publicKeyHex,
      kdf: params,
      salt: salt,
      nonce: box.nonce,
      cipherText: box.cipherText,
      mac: box.mac.bytes,
    );
  }

  @override
  Future<Result<Keypair, BackupFailure>> open(
    SealedIdentity sealed,
    String passphrase,
  ) async {
    final key = await _deriveKey(passphrase, sealed.salt, sealed.kdf);
    try {
      final secret = await _aead.decrypt(
        crypto.SecretBox(
          sealed.cipherText,
          nonce: sealed.nonce,
          mac: crypto.Mac(sealed.mac),
        ),
        secretKey: key,
        aad: utf8.encode(sealed.publicKeyHex),
      );
      return Ok(Keypair(publicKeyHex: sealed.publicKeyHex, secretKey: secret));
    } on crypto.SecretBoxAuthenticationError catch (e, st) {
      return Failure(BackupWrongPassphraseFailure(e, st));
    }
  }

  static Future<crypto.SecretKey> _deriveKey(
    String passphrase,
    List<int> salt,
    KdfParams kdf,
  ) async {
    final bytes = await Isolate.run(() async {
      final argon = DartArgon2id(
        memory: kdf.memoryKib,
        iterations: kdf.iterations,
        parallelism: kdf.parallelism,
        hashLength: 32,
      );
      final key = await argon.deriveKeyFromPassword(
        password: passphrase,
        nonce: salt,
      );
      return key.extractBytes();
    });
    return crypto.SecretKey(bytes);
  }
}
