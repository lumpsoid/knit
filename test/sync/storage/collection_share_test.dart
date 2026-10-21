import 'package:flutter_test/flutter_test.dart';
import 'package:knit/core/storage/infra/sqflite/sqflite_unit_of_work.dart';
import 'package:knit/sync/sync.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'op_builders.dart';

/// Collection share by file (docs/collection_share.md): `SyncStore.shareSet`
/// picks the winning signed ops of one collection, a second device applies
/// them verbatim, `purgeCollection` removes them again (log included, so
/// rebuild-from-log agrees), and `forkCollection` writes an own copy in one
/// transaction. Run against both storage impls.
void main() {
  sqfliteFfiInit();

  SyncStore inMemory(String seed) =>
      SyncStore.inMemory(signer: FakeSigner(identitySeed: seed));

  Future<SyncStore> sqflite(String seed) async {
    final db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    addTearDown(db.close);
    return SyncStore(
      changeLog: SqfliteChangeLogStorage(db: db),
      projection: SqfliteProjectionStorage(db: db),
      deviceClock: SqfliteDeviceClockStorage(db: db),
      localIdentity: SqfliteLocalIdentityStorage(db: db),
      quarantine: SqfliteQuarantineStorage(db: db),
      signer: FakeSigner(identitySeed: seed),
      unitOfWork: SqfliteUnitOfWork(db),
    );
  }

  /// Sender content: collection `trip` (cover `att-cover`) with cards c1
  /// (edited, then reordered), c2 (image `att-1`), c3 (deleted), a link
  /// c1→c2, a link c2→`elsewhere` (outside the set), and an unrelated
  /// collection `other` with its own card.
  Future<void> seed(SyncStore s) async {
    final me = await s.authorPubkey();
    await s.create(EntityType.profile, me, {
      'nickname': 'mira',
    }, physicalNowMs: 1000);
    for (final (id, hash) in [('att-cover', 'h-cover'), ('att-1', 'h-1')]) {
      await s.create(EntityType.attachment, id, {
        'kind': 'image',
        'mime': 'image/png',
        'content_hash': hash,
        'size': 10,
        'name': null,
      }, physicalNowMs: 1000);
    }
    await s.create(EntityType.collection, 'trip', {
      'title': 'Trip',
      'cover_attachment_id': 'att-cover',
    }, physicalNowMs: 1000);
    await s.create(EntityType.collection, 'other', {
      'title': 'Other',
    }, physicalNowMs: 1000);
    Future<void> card(String id, String pos, {String? attachment}) => s.create(
      EntityType.card,
      id,
      {
        'collection_id': id == 'o1' ? 'other' : 'trip',
        'kind': attachment == null ? 'text' : 'image',
        'text': id,
        'attachment_id': attachment,
      },
      position: pos,
      physicalNowMs: 1000,
    );
    await card('c1', 'a0');
    await card('c2', 'a1', attachment: 'att-1');
    await card('c3', 'a2');
    await card('o1', 'a0');
    await s.edit(EntityType.card, 'c1', {'text': 'c1 v2'}, physicalNowMs: 1100);
    await s.reorder('c1', 'a3', physicalNowMs: 1200);
    await s.delete(EntityType.card, 'c3', physicalNowMs: 1300);
    for (final (id, source, target) in [
      ('l1', 'c1', 'c2'),
      ('l2', 'c2', 'elsewhere'),
      ('l3', 'o1', 'other'),
    ]) {
      await s.create(EntityType.link, id, {
        'source_type': 'card',
        'source_id': source,
        'target_type': 'card',
        'target_id': target,
      }, physicalNowMs: 1000);
    }
  }

  Future<Map<String, Snapshot>> rowsOf(SyncStore s) async => {
    for (final r in await s.projection.readAll()) r.id: r,
  };

  for (final (name, open) in <(String, Future<SyncStore> Function(String))>[
    ('in memory', (seed) async => inMemory(seed)),
    ('sqflite', sqflite),
  ]) {
    group(name, () {
      late SyncStore sender;
      late SyncStore recipient;
      setUp(() async {
        sender = await open('mira');
        recipient = await open('kai');
        await sender.open();
        await recipient.open();
        await seed(sender);
      });

      /// Applies the share on [target]; the sender's profile stays behind
      /// after a purge, so a re-import dedups it.
      Future<void> sendTo(SyncStore target) async {
        for (final op in (await sender.shareSet('trip')).ops) {
          expect(
            await target.applyRemote(op, 5000),
            isNot(
              anyOf(
                ApplyOutcome.quarantinedBadSig,
                ApplyOutcome.quarantinedSkew,
              ),
            ),
            reason: '$op',
          );
        }
      }

      test('shareSet ships the winners of the set and its authors', () async {
        final set = await sender.shareSet('trip');
        final me = await sender.authorPubkey();

        expect(set.collection.id, 'trip');
        expect(set.liveCardCount, 2);
        expect(set.media, {'h-cover': 10, 'h-1': 10});
        // c1: the edit is the content winner, the reorder the placement one.
        expect(
          set.ops.map((o) => o.entityId),
          unorderedEquals([
            me,
            'att-cover',
            'att-1',
            'trip',
            'c1',
            'c1',
            'c2',
            'c3',
            'l1',
            'l2',
          ]),
        );
        expect(
          set.ops.where((o) => o.entityId == 'c3').single.op,
          OpKind.delete,
        );
      });

      test('the recipient materializes the sender\'s rows', () async {
        await sendTo(recipient);
        final sent = await rowsOf(sender);
        final got = await rowsOf(recipient);
        for (final id in ['trip', 'c1', 'c2', 'c3', 'l1', 'l2', 'att-1']) {
          expect(got[id]!.sig, sent[id]!.sig, reason: id);
          expect(got[id]!.position, sent[id]!.position, reason: id);
          expect(got[id]!.deleted, sent[id]!.deleted, reason: id);
        }
        expect(got.containsKey('other'), isFalse);
        expect(got.containsKey('o1'), isFalse);
        expect(await recipient.pendingCount(), 0);
      });

      test('purge removes the set from projection and log', () async {
        await sendTo(recipient);
        await recipient.create(EntityType.collection, 'mine', {
          'title': 'Mine',
        }, physicalNowMs: 6000);
        await recipient.create(
          EntityType.card,
          'm1',
          {'collection_id': 'mine', 'kind': 'text', 'text': 'm1'},
          position: 'a0',
          physicalNowMs: 6000,
        );
        // The recipient's own link into the set survives as a broken chip.
        await recipient.create(EntityType.link, 'mine-link', {
          'source_type': 'card',
          'source_id': 'm1',
          'target_type': 'card',
          'target_id': 'c2',
        }, physicalNowMs: 6000);

        final orphans = await recipient.purgeCollection('trip');

        expect(orphans, {'h-cover', 'h-1'});
        final rows = await rowsOf(recipient);
        expect(rows.keys.toSet(), {
          await sender.authorPubkey(), // profiles are kept
          'mine',
          'm1',
          'mine-link',
        });
        final log = await recipient.changeLog.readOrdered();
        expect(log.map((o) => o.entityId).toSet(), rows.keys.toSet());

        await recipient.rebuild();
        expect((await rowsOf(recipient)).keys.toSet(), rows.keys.toSet());
        final link = (await recipient.get(EntityType.link, 'mine-link'))!;
        expect((await recipient.linkStatus(link)).isBroken, isTrue);
      });

      test('purge refuses an own collection; unknown is a no-op', () async {
        await expectLater(sender.purgeCollection('trip'), throwsStateError);
        expect(await recipient.purgeCollection('nope'), isEmpty);
      });

      test('a re-import after purge restores the collection', () async {
        await sendTo(recipient);
        await recipient.purgeCollection('trip');
        await sendTo(recipient);
        expect((await recipient.feed('trip')).map((c) => c.id), ['c2', 'c1']);
      });

      test('forkCollection writes own entities in one go', () async {
        await sendTo(recipient);
        final me = await recipient.authorPubkey();
        final ops = await recipient.forkCollection(
          const ForkPlan(
            collectionId: 'fork',
            entities: [
              ForkEntity(
                type: EntityType.collection,
                id: 'fork',
                content: {'title': 'Trip'},
              ),
              ForkEntity(
                type: EntityType.card,
                id: 'f1',
                content: {
                  'collection_id': 'fork',
                  'kind': 'text',
                  'text': 'c1 v2',
                },
                position: 'a3',
              ),
            ],
          ),
          physicalNowMs: 7000,
        );

        expect(ops, hasLength(2));
        final f1 = (await recipient.get(EntityType.card, 'f1'))!;
        expect(f1.createdBy, me);
        expect(f1.author, me);
        expect(f1.position, 'a3');
        expect(f1.content['settled_at'], isNull);
        expect(
          (await recipient.get(EntityType.collection, 'fork'))!.createdBy,
          me,
        );
        expect(await recipient.pendingCount(), 2);
        // The source stays.
        expect(await recipient.get(EntityType.collection, 'trip'), isNotNull);
      });
    });
  }

  test('ShareSetSelector keeps one content + one placement winner', () {
    final edit = opOf(card(hlcMs: 200, posMs: 100, text: 'v2'));
    final create = opOf(card(hlcMs: 100, posMs: 100, text: 'v1'));
    final reorder = opOf(
      card(hlcMs: 100, posMs: 300, text: 'v1', position: 'b0'),
    );
    final picks = const ShareSetSelector().winners([create, edit, reorder]);
    expect(picks, [edit, reorder]);

    final only = const ShareSetSelector().winners([create, edit]);
    expect(only, [edit], reason: 'the edit kept the create\'s placement');
  });
}
