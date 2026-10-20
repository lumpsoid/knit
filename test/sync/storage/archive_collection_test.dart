import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:knit/sync/sync.dart';

import 'op_builders.dart';

/// `SyncStore.setCollectionArchived` (§3.4): archiving is a content write that
/// stamps `archived_at` with the write's own time; the home timeline keeps the
/// collection, flagged, and the flag survives edits and rebuild-from-log.
void main() {
  late SyncStore store;

  setUp(() async {
    store = SyncStore.inMemory();
    await store.open();
    await store.create(EntityType.collection, 'col', {
      'title': 'Trips',
    }, physicalNowMs: 1000);
    await store.create(
      EntityType.card,
      'c1',
      {'collection_id': 'col', 'kind': 'text', 'text': 'Rome'},
      position: 'a0',
      physicalNowMs: 1000,
    );
  });

  test('a new collection is not archived in its signed payload', () async {
    final col = (await store.get(EntityType.collection, 'col'))!;
    expect(col.content['archived_at'], isNull);
    expect(CanonicalSerializer.string(col), contains('"archived_at":null'));
    expect((await store.homeTimeline()).single.archived, isFalse);
  });

  test('archives on the content clock, keeping title and cards', () async {
    final op = await store.setCollectionArchived(
      'col',
      archived: true,
      physicalNowMs: 5000,
    );

    final col = (await store.get(EntityType.collection, 'col'))!;
    expect(col.content['archived_at'], 5000);
    expect(col.content['title'], 'Trips');
    expect(col.hlc, const Hlc(5000, 0));
    expect(op.payload, contains('"archived_at":5000'));
    expect(await store.deviceClock.load(), store.clock.now);

    final summary = (await store.homeTimeline()).single;
    expect(summary.archived, isTrue);
    expect(summary.cardCount, 1);
  });

  test('unarchive clears archived_at', () async {
    await store.setCollectionArchived('col', archived: true);
    await store.setCollectionArchived('col', archived: false);

    final col = (await store.get(EntityType.collection, 'col'))!;
    expect(col.content['archived_at'], isNull);
    expect((await store.homeTimeline()).single.archived, isFalse);
  });

  test('a rename and a new card keep the collection archived', () async {
    await store.setCollectionArchived(
      'col',
      archived: true,
      physicalNowMs: 5000,
    );
    await store.edit(EntityType.collection, 'col', {
      'title': 'Old trips',
    }, physicalNowMs: 6000);
    await store.create(
      EntityType.card,
      'c2',
      {'collection_id': 'col', 'kind': 'text', 'text': 'Oslo'},
      position: 'a1',
      physicalNowMs: 7000,
    );

    final col = (await store.get(EntityType.collection, 'col'))!;
    expect(col.content['archived_at'], 5000);
    expect((await store.homeTimeline()).single.archived, isTrue);
  });

  test('rebuild-from-log reproduces the archived projection (§8.9)', () async {
    await store.setCollectionArchived(
      'col',
      archived: true,
      physicalNowMs: 5000,
    );
    final before = (await store.get(EntityType.collection, 'col'))!;
    await store.rebuild();
    final after = (await store.get(EntityType.collection, 'col'))!;
    expect(after.content['archived_at'], 5000);
    expect(after.sig, before.sig);
  });

  test('a collection from a peer without the field can be archived', () async {
    // An older peer's signed payload: no archived_at in the field set.
    const author = 'bb';
    final payload = CanonicalSerializer.string(
      collection(
        id: 'legacy',
        hlcMs: 2000,
        title: 'old',
      ).copyWith(author: author, createdBy: author),
    ).replaceFirst('"archived_at":null,', '');
    expect(payload, isNot(contains('archived_at')));
    final parsed = jsonDecode(payload) as Map<String, Object?>;
    final sig = fakeSignHex(utf8.encode(author), utf8.encode(payload));
    final legacy = Snapshot.fromPayload(parsed).copyWith(sig: sig);
    final op = PersistedOp.fromSnapshot(
      legacy,
      opId: OpId.ofSnapshot(legacy),
      payload: payload,
      origin: SyncOrigin.remote,
    );
    expect(await store.applyRemote(op, 2000), ApplyOutcome.applied);
    expect(
      (await store.homeTimeline())
          .firstWhere((s) => s.collectionId == 'legacy')
          .archived,
      isFalse,
    );

    await store.setCollectionArchived(
      'legacy',
      archived: true,
      physicalNowMs: 5000,
    );

    final archived = (await store.get(EntityType.collection, 'legacy'))!;
    expect(archived.content['archived_at'], 5000);
    expect(archived.createdBy, author);
  });

  test('archiving a missing collection throws', () async {
    await expectLater(
      store.setCollectionArchived('missing', archived: true),
      throwsStateError,
    );
  });
}
