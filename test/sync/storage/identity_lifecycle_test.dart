import 'package:flutter_test/flutter_test.dart';
import 'package:knit/sync/sync.dart';

void main() {
  group('exportKeypair / adoptIdentity', () {
    test('a keypair exported from one store is adopted by another', () async {
      final signer = Ed25519Signer();
      final src = SyncStore.inMemory(signer: signer);
      await src.open();
      final keypair = await src.exportKeypair();

      final dst = SyncStore.inMemory(signer: signer);
      await dst.open();
      expect(await dst.authorPubkey(), isNot(keypair.publicKeyHex));

      await dst.adoptIdentity(keypair);

      expect(await dst.authorPubkey(), keypair.publicKeyHex);
      expect(
        (await dst.localIdentity.load())!.publicKeyHex,
        keypair.publicKeyHex,
      );
      // Writes are signed with the adopted secret and verify under its key.
      await dst.create(EntityType.collection, 'c1', {'title': 'T'});
      final op = (await dst.changeLog.readOrdered()).single;
      expect(op.toSnapshot().author, keypair.publicKeyHex);
    });

    test('a secret that does not match the public key is refused', () async {
      final signer = Ed25519Signer();
      final a = await signer.generate();
      final b = await signer.generate();
      final store = SyncStore.inMemory(signer: signer);
      await store.open();
      final before = await store.authorPubkey();

      await expectLater(
        store.adoptIdentity(
          Keypair(publicKeyHex: a.publicKeyHex, secretKey: b.secretKey),
        ),
        throwsArgumentError,
      );
      expect(await store.authorPubkey(), before);
    });
  });

  test('resetDevice drops content and the keypair, keeps the clock', () async {
    final store = SyncStore.inMemory();
    await store.open();
    await store.create(EntityType.collection, 'c1', {'title': 'T'});
    final clockBefore = store.clock.now;

    await store.resetDevice();

    expect(await store.hasIdentity(), isFalse);
    expect(await store.readAll(EntityType.collection), isEmpty);
    expect(await store.changeLog.readOrdered(), isEmpty);
    expect(store.clock.now, clockBefore);
  });
}
