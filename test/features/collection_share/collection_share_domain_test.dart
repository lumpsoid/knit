import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:knit/core/files/infra/log_archive.dart';
import 'package:knit/core/ids/id_generator.dart';
import 'package:knit/features/collection_share/domain/domain.dart';
import 'package:knit/features/collection_share/infra/infra.dart';
import 'package:knit/sync/sync.dart';

import '../../sync/storage/op_builders.dart';
import 'share_fixture.dart';

class _SeqIds implements IdGenerator {
  var _n = 0;
  @override
  String newId() => 'new-${_n++}';
}

void main() {
  group('CollectionShareCodec', () {
    const codec = CollectionShareCodec();

    test('round-trips manifest, ops and blobs', () async {
      final sender = await device('mira');
      await seedTrip(sender);
      final bundle = await bundleOf(sender);
      final withBlob = CollectionShareBundle(
        manifest: bundle.manifest,
        ops: bundle.ops,
        blobs: {
          'h-1': Uint8List.fromList([1, 2, 3]),
        },
      );

      final decoded = codec.decode(codec.encode(withBlob));

      expect(decoded.manifest.toJson(), bundle.manifest.toJson());
      expect(decoded.ops.map((o) => o.opId), bundle.ops.map((o) => o.opId));
      expect(
        decoded.ops.map((o) => o.payload),
        bundle.ops.map((o) => o.payload),
      );
      expect(decoded.blobs['h-1'], [1, 2, 3]);
    });

    Uint8List zipWith(Map<String, Object?> manifest, [List<String>? lines]) =>
        LogArchive.encode(
          LogArchiveEntries(
            manifest: manifest,
            opLines: lines ?? const [],
            blobs: const {},
          ),
        );

    test('a newer version is refused as such', () {
      expect(
        () => codec.decode(
          zipWith({'format': kCollectionShareFormat, 'version': 2}),
        ),
        throwsA(isA<NewerShareVersionException>()),
      );
    });

    test('a backup, junk bytes or a broken op line are corrupt', () {
      expect(
        () => codec.decode(zipWith({'format': 'knit-backup', 'version': 2})),
        throwsFormatException,
      );
      expect(
        () => codec.decode(Uint8List.fromList(utf8.encode('nope'))),
        throwsFormatException,
      );
      expect(
        () => codec.decode(
          zipWith({'format': kCollectionShareFormat, 'version': 1}, ['{}']),
        ),
        throwsFormatException,
      );
    });
  });

  group('CollectionShareImportPolicy', () {
    const policy = CollectionShareImportPolicy();
    late SyncStore sender;
    setUp(() async {
      sender = await device('mira');
      await seedTrip(sender);
    });

    ShareRejection? check(
      CollectionShareBundle bundle, {
      Set<String> badSignatures = const {},
      Map<String, String> localCreatedBy = const {},
    }) => policy.check(
      bundle,
      badSignatures: badSignatures,
      localCreatedBy: localCreatedBy,
    );

    test('accepts the sender\'s own share set', () async {
      final bundle = await bundleOf(sender);
      expect(check(bundle), isNull);
      // A re-import over the same creator's rows is fine.
      final owner = bundle.manifest.owner;
      expect(
        check(bundle, localCreatedBy: {'trip': owner, 'c1': owner}),
        isNull,
      );
    });

    test('a bad signature refuses the file', () async {
      final bundle = await bundleOf(sender);
      expect(
        check(bundle, badSignatures: {bundle.ops.last.opId}),
        ShareRejection.badSignature,
      );
    });

    test('an op by someone other than the owner refuses the file', () async {
      final intruder = opOf(
        card(id: 'x', collectionId: 'trip', hlcMs: 1500), // author 'aa'
      );
      final bundle = await bundleOf(
        sender,
        tamper: (ops) => [...ops, intruder],
      );
      expect(check(bundle), ShareRejection.foreignAuthor);
    });

    test('ops outside the collection refuse the file', () async {
      final other = await device('mira');
      await other.create(EntityType.collection, 'else', {
        'title': 'Else',
      }, physicalNowMs: 1000);
      await other.create(
        EntityType.card,
        'stray',
        {'collection_id': 'else', 'kind': 'text', 'text': 's'},
        position: 'a0',
        physicalNowMs: 1000,
      );
      final strays = (await other.shareSet('else')).ops;
      for (final stray in strays.where((o) => o.entityType != 'profile')) {
        final bundle = await bundleOf(sender, tamper: (ops) => [...ops, stray]);
        expect(
          check(bundle),
          ShareRejection.outsideCollection,
          reason: '$stray',
        );
      }

      final noCollection = await bundleOf(
        sender,
        tamper: (ops) => [
          for (final op in ops)
            if (op.entityType != 'collection') op,
        ],
      );
      expect(check(noCollection), ShareRejection.outsideCollection);
    });

    test('the foreign-overwrite attack is refused', () async {
      // Mira crafts a file whose card id is one of Kai's own cards: by LWW
      // her newer op would replace Kai's card. The local created_by differs.
      final bundle = await bundleOf(sender);
      expect(
        check(bundle, localCreatedBy: {'c1': 'kai-pubkey'}),
        ShareRejection.foreignOverwrite,
      );
    });

    test(
      'envelope hints that disagree with the payload are malformed',
      () async {
        final bundle = await bundleOf(
          sender,
          tamper: (ops) => [
            for (final op in ops)
              op.entityId == 'c1'
                  ? PersistedOp.fromDb({...op.toDb(), 'entity_id': 'kai-card'})
                  : op,
          ],
        );
        expect(check(bundle), ShareRejection.malformed);
      },
    );
  });

  test('CollectionOwnership and ArchiveTarget', () {
    expect(CollectionOwnership.of('me', 'me'), CollectionOwnership.own);
    expect(CollectionOwnership.of('mira', 'me').canEdit, isFalse);
    expect(ArchiveTarget.of(CollectionOwnership.own), ArchiveTarget.signed);
    expect(ArchiveTarget.of(CollectionOwnership.imported), ArchiveTarget.local);
  });

  test(
    'ForkPlanner maps ids, rewrites intra-set links, keeps outside ones',
    () {
      final source = ForkSource(
        collection: collection(
          id: 'trip',
          hlcMs: 100,
          coverAttachmentId: 'att',
          archivedAt: 5,
        ),
        cards: [
          card(
            id: 'c1',
            collectionId: 'trip',
            hlcMs: 100,
            position: 'a0',
            settledAt: 7,
          ),
          card(
            id: 'c2',
            collectionId: 'trip',
            hlcMs: 100,
            position: 'a1',
            attachmentId: 'att',
          ),
        ],
        links: [
          link(id: 'l1', sourceId: 'c1', targetId: 'c2', hlcMs: 100),
          link(id: 'l2', sourceId: 'c2', targetId: 'outside', hlcMs: 100),
        ],
        attachments: [
          Snapshot(
            type: EntityType.attachment,
            id: 'att',
            author: 'aa',
            createdBy: 'aa',
            createdAt: 1,
            hlc: const Hlc(100, 0),
            deleted: false,
            sig: 's',
            content: const {'content_hash': 'h', 'kind': 'image'},
          ),
        ],
      );

      final plan = ForkPlanner(ids: _SeqIds()).plan(source);
      final byType = <EntityType, List<ForkEntity>>{};
      for (final e in plan.entities) {
        (byType[e.type] ??= []).add(e);
      }

      final col = byType[EntityType.collection]!.single;
      final att = byType[EntityType.attachment]!.single;
      expect(col.id, plan.collectionId);
      expect(col.content['cover_attachment_id'], att.id);
      expect(col.content['archived_at'], isNull);
      expect(att.content['content_hash'], 'h');

      final cards = byType[EntityType.card]!;
      expect(cards.map((c) => c.position), ['a0', 'a1']);
      expect(
        cards.every((c) => c.content['collection_id'] == plan.collectionId),
        isTrue,
      );
      expect(cards.first.content['settled_at'], 7);
      expect(cards.last.content['attachment_id'], att.id);

      final links = byType[EntityType.link]!;
      expect(links.first.content['source_id'], cards.first.id);
      expect(links.first.content['target_id'], cards.last.id);
      expect(links.last.content['source_id'], cards.last.id);
      expect(links.last.content['target_id'], 'outside');
      final allIds = plan.entities.map((e) => e.id).toSet();
      expect(
        allIds.intersection({'trip', 'c1', 'c2', 'l1', 'l2', 'att'}),
        isEmpty,
      );
      expect(allIds, hasLength(plan.entities.length));
    },
  );
}
