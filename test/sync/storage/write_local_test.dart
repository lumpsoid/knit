import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:knit/sync/sync.dart';

import 'op_builders.dart';

/// The §9.1 local-first gates for the write path. In-memory store + FakeSigner.
void main() {
  Future<SyncStore> openStore() async {
    final store = SyncStore.inMemory();
    await store.open();
    return store;
  }

  group('gate 1 — one transaction: entity row + signed op + clock advance', () {
    test('create persists projection + change_log(local,!acked) + device clock',
        () async {
      final store = await openStore();
      final op = await store.create(
        EntityType.collection,
        'col-1',
        {'title': 'Espresso'},
        physicalNowMs: 1000,
      );

      // Entity row.
      final row = await store.get(EntityType.collection, 'col-1');
      expect(row!.content['title'], 'Espresso');
      expect(row.deleted, isFalse);

      // Signed change_log op.
      final logged = (await store.changeLog.readOrdered()).single;
      expect(logged.opId, op.opId);
      expect(logged.origin, SyncOrigin.local);
      expect(logged.acked, isFalse);
      expect(logged.sig, isNotEmpty);
      expect(await store.pendingCount(), 1);

      // Device clock advanced and persisted in lock-step.
      expect(store.clock.now, const Hlc(1000, 0));
      expect(await store.deviceClock.load(), store.clock.now);
    });

    test('created_by = author on create; both are this device (§6.2)', () async {
      final store = await openStore();
      final me = await store.authorPubkey();
      await store.create(EntityType.collection, 'c', {'title': 't'});
      final row = await store.get(EntityType.collection, 'c');
      expect(row!.author, me);
      expect(row.createdBy, me);
    });
  });

  group('gate 3 — reorder freezes hlc_*, bumps position_*, text intact (§8.4)', () {
    test('a reorder of a card leaves content untouched', () async {
      final store = await openStore();
      await store.create(
        EntityType.card,
        'card-1',
        {'collection_id': 'col-1', 'kind': 'text', 'text': 'grind finer'},
        position: 'a0',
        physicalNowMs: 1000,
      );
      final created = (await store.get(EntityType.card, 'card-1'))!;
      expect(created.hlc, const Hlc(1000, 0));
      expect(created.placement, const Hlc(1000, 0));

      await store.reorder('card-1', 'a5', physicalNowMs: 1000);
      final moved = (await store.get(EntityType.card, 'card-1'))!;

      expect(moved.hlc, const Hlc(1000, 0), reason: 'content hlc frozen');
      expect(moved.placement, const Hlc(1000, 1), reason: 'placement bumped');
      expect(moved.position, 'a5');
      expect(moved.content['text'], 'grind finer', reason: 'text intact');
    });
  });

  group('gate 2 — distinct op_id for a reorder of a just-edited card (§7.3)', () {
    test('edit then reorder produce two different op_ids', () async {
      final store = await openStore();
      await store.create(
        EntityType.card,
        'card-1',
        {'collection_id': 'col-1', 'kind': 'text', 'text': 'a'},
        position: 'a0',
        physicalNowMs: 1000,
      );
      final editOp = await store.edit(
        EntityType.card,
        'card-1',
        {'text': 'b'},
        physicalNowMs: 1000,
      );
      final reorderOp = await store.reorder('card-1', 'a5', physicalNowMs: 1000);

      expect(editOp.opId, isNot(reorderOp.opId));
      // The reorder reused the edit's frozen content hlc, so distinctness comes
      // from the differing sig16 (§7.3 case 2), not the hlc.
      final moved = (await store.get(EntityType.card, 'card-1'))!;
      expect(moved.hlc, const Hlc(1000, 1), reason: 'reorder froze the edit hlc');
    });
  });

  group('§6.2 — created_by preserved on edit, never restamped', () {
    test('a local edit of a peer-created entity keeps the original created_by',
        () async {
      final store = await openStore();
      final me = await store.authorPubkey();

      // Seed a collection authored by a different identity ('aa').
      await store.applyRemote(opOf(collection(hlcMs: 100, title: 'theirs')), 100);
      final seeded = (await store.get(EntityType.collection, 'col-1'))!;
      expect(seeded.createdBy, 'aa');
      expect(seeded.createdBy, isNot(me));

      // Locally edit it.
      await store.edit(EntityType.collection, 'col-1', {'title': 'mine'},
          physicalNowMs: 200);
      final edited = (await store.get(EntityType.collection, 'col-1'))!;

      expect(edited.content['title'], 'mine');
      expect(edited.author, me, reason: 'editor signs as author');
      expect(edited.createdBy, 'aa', reason: 'created_by preserved (§6.2)');
    });
  });

  group('canonical + sign + verify over the stored bytes', () {
    test('the stored op verifies; a flipped byte does not', () async {
      final store = await openStore();
      final op = await store.create(EntityType.collection, 'c', {'title': 't'});

      final author =
          (jsonDecode(op.payload) as Map<String, Object?>)['author'] as String;
      expect(
        await store.signer.verify(author, utf8.encode(op.payload), op.sig),
        isTrue,
      );

      final tampered = op.payload.replaceFirst('"t"', '"X"');
      expect(
        await store.signer.verify(author, utf8.encode(tampered), op.sig),
        isFalse,
      );
    });
  });
}
