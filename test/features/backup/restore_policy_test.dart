import 'package:flutter_test/flutter_test.dart';
import 'package:knit/features/backup/domain/backup_models.dart';
import 'package:knit/features/backup/domain/backup_passphrase.dart';
import 'package:knit/features/backup/domain/restore_policy.dart';

void main() {
  const policy = RestorePolicy();
  const sealed = SealedIdentity(
    publicKeyHex: 'aaaa',
    kdf: KdfParams.recommended,
    salt: [1],
    nonce: [2],
    cipherText: [3],
    mac: [4],
  );

  BackupBundle bundle({SealedIdentity? identity}) => BackupBundle(
    author: 'aaaa',
    createdAtMs: 0,
    identity: identity,
    opLines: const [],
    blobs: const {},
  );

  group('RestorePolicy', () {
    test('this identity\'s own bundle merges', () {
      expect(
        policy.decide(
          deviceAuthor: 'aaaa',
          bundle: bundle(identity: sealed),
        ),
        RestoreKind.merge,
      );
    });

    test('another identity\'s bundle replaces the device', () {
      expect(
        policy.decide(
          deviceAuthor: 'bbbb',
          bundle: bundle(identity: sealed),
        ),
        RestoreKind.replaceDevice,
      );
    });

    test('a fresh device restores a bundle with a keypair', () {
      expect(
        policy.decide(deviceAuthor: null, bundle: bundle(identity: sealed)),
        RestoreKind.replaceDevice,
      );
    });

    test('a v1 bundle merges onto an existing identity', () {
      expect(
        policy.decide(deviceAuthor: 'bbbb', bundle: bundle()),
        RestoreKind.merge,
      );
    });

    test('a v1 bundle cannot set up a fresh device', () {
      expect(
        policy.decide(deviceAuthor: null, bundle: bundle()),
        RestoreKind.missingIdentity,
      );
    });
  });

  group('BackupPassphrasePolicy', () {
    const passphrase = BackupPassphrasePolicy();

    test('rejects a short passphrase', () {
      expect(passphrase.check('short', 'short'), PassphraseIssue.tooShort);
    });

    test('rejects a mismatched confirmation', () {
      expect(
        passphrase.check('long enough', 'long enougH'),
        PassphraseIssue.mismatch,
      );
    });

    test('accepts a long, confirmed passphrase', () {
      expect(passphrase.check('long enough', 'long enough'), isNull);
    });
  });
}
