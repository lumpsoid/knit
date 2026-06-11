import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:knit/sync/sync.dart';

void main() {
  final message = utf8.encode('the signed canonical bytes');

  group('Ed25519Signer (real crypto)', () {
    final signer = Ed25519Signer();

    test('generate → sign → verify round-trips true', () async {
      final kp = await signer.generate();
      final sig = await signer.sign(kp.secretKey, message);
      expect(await signer.verify(kp.publicKeyHex, message, sig), isTrue);
    });

    test('sig is lowercase hex', () async {
      final kp = await signer.generate();
      final sig = await signer.sign(kp.secretKey, message);
      expect(sig, matches(RegExp(r'^[0-9a-f]+$')));
    });

    test('tampered message fails verification', () async {
      final kp = await signer.generate();
      final sig = await signer.sign(kp.secretKey, message);
      final tampered = utf8.encode('the signed canonical byteX');
      expect(await signer.verify(kp.publicKeyHex, tampered, sig), isFalse);
    });

    test('wrong key fails verification', () async {
      final a = await signer.generate();
      final b = await signer.generate();
      final sig = await signer.sign(a.secretKey, message);
      expect(await signer.verify(b.publicKeyHex, message, sig), isFalse);
    });

    test('non-hex author or sig is a clean false, not a crash', () async {
      expect(await signer.verify('not-hex!', message, 'also-not-hex'), isFalse);
    });

    test('fingerprint = first 4 hex of SHA-256(pubkey) (§5)', () async {
      final kp = await signer.generate();
      final fp = await signer.fingerprintOf(kp.publicKeyHex);
      expect(fp, matches(RegExp(r'^[0-9a-f]{4}$')));
    });
  });

  group('FakeSigner (deterministic)', () {
    test('generate → sign → verify round-trips true', () async {
      final signer = FakeSigner();
      final kp = await signer.generate();
      final sig = await signer.sign(kp.secretKey, message);
      expect(await signer.verify(kp.publicKeyHex, message, sig), isTrue);
    });

    test('same payload → same sig (idempotency §7.3); tampered → different', () async {
      final signer = FakeSigner();
      final kp = await signer.generate();
      final a = await signer.sign(kp.secretKey, message);
      final b = await signer.sign(kp.secretKey, message);
      expect(a, b);
      final c = await signer.sign(kp.secretKey, utf8.encode('different'));
      expect(c, isNot(a));
    });

    test('verifies a signature made from author alone (the op-builder convention)',
        () async {
      // sig = fakeSignHex(utf8(author), message); verify recomputes the same.
      const author = 'aa';
      final sig = fakeSignHex(utf8.encode(author), message);
      expect(await FakeSigner().verify(author, message, sig), isTrue);
      expect(await FakeSigner().verify(author, utf8.encode('x'), sig), isFalse);
    });

    test('distinct seeds yield distinct identities', () async {
      final a = await FakeSigner(identitySeed: 'dev-a').generate();
      final b = await FakeSigner(identitySeed: 'dev-b').generate();
      expect(a.publicKeyHex, isNot(b.publicKeyHex));
    });
  });
}
