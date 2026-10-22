import 'package:knit/app/app_graph.dart';
import 'package:knit/core/attachments/attachments.dart';
import 'package:knit/features/collection_share/domain/domain.dart';
import 'package:knit/sync/sync.dart';

/// A device for the share tests, with its own fake identity.
Future<SyncStore> device(String seed) async {
  final store = SyncStore.inMemory(signer: FakeSigner(identitySeed: seed));
  await store.open();
  return store;
}

/// Seeds [store] with its profile and a collection `trip` (title "Trip to
/// Kyoto") holding text cards c1, c2, an image card c3 (attachment `att-1`,
/// hash [imageHash]), a deleted card c4 and a link c1→c2.
Future<void> seedTrip(
  SyncStore store, {
  String nickname = 'mira',
  String imageHash = 'h-1',
}) async {
  final me = await store.authorPubkey();
  await store.create(EntityType.profile, me, {
    'nickname': nickname,
  }, physicalNowMs: 1000);
  await store.create(EntityType.attachment, 'att-1', {
    'kind': 'image',
    'mime': 'image/png',
    'content_hash': imageHash,
    'size': 3,
    'name': null,
  }, physicalNowMs: 1000);
  await store.create(EntityType.collection, 'trip', {
    'title': 'Trip to Kyoto',
  }, physicalNowMs: 1000);
  for (final (id, pos) in [
    ('c1', 'a0'),
    ('c2', 'a1'),
    ('c3', 'a2'),
    ('c4', 'a3'),
  ]) {
    await store.create(
      EntityType.card,
      id,
      {
        'collection_id': 'trip',
        'kind': id == 'c3' ? 'image' : 'text',
        'text': id,
        'attachment_id': id == 'c3' ? 'att-1' : null,
      },
      position: pos,
      physicalNowMs: 1000,
    );
  }
  await store.delete(EntityType.card, 'c4', physicalNowMs: 1100);
  await store.create(EntityType.link, 'l1', {
    'source_type': 'card',
    'source_id': 'c1',
    'target_type': 'card',
    'target_id': 'c2',
  }, physicalNowMs: 1000);
}

/// Seeds [store] (after [seedTrip]) with an index of other collections:
/// - `notes` (own) with card n1, which links on to collection `far` (own) —
///   one level deep, so `far` is never bundled
/// - `index` (own): card i1 links to `trip` twice (one pair, §6.4), card i2
///   to card n1 of `notes`, the deleted card i3 to `far`, and the collection
///   itself to [foreignId] (someone else's, when given) and to a missing
///   `gone`.
Future<void> seedIndex(SyncStore store, {String? foreignId}) async {
  for (final id in ['far', 'notes', 'index']) {
    await store.create(EntityType.collection, id, {
      'title': id,
    }, physicalNowMs: 1200);
  }
  for (final (id, collectionId) in [
    ('n1', 'notes'),
    ('i1', 'index'),
    ('i2', 'index'),
    ('i3', 'index'),
  ]) {
    await store.create(
      EntityType.card,
      id,
      {'collection_id': collectionId, 'kind': 'text', 'text': id},
      position: 'a0',
      physicalNowMs: 1200,
    );
  }
  await store.delete(EntityType.card, 'i3', physicalNowMs: 1300);
  for (final (id, sourceType, sourceId, targetType, targetId) in [
    ('ln', 'card', 'n1', 'collection', 'far'),
    ('li1', 'card', 'i1', 'collection', 'trip'),
    ('li1b', 'card', 'i1', 'collection', 'trip'),
    ('li2', 'card', 'i2', 'card', 'n1'),
    ('li3', 'card', 'i3', 'collection', 'far'),
    ('lgone', 'collection', 'index', 'collection', 'gone'),
    if (foreignId != null)
      ('lforeign', 'collection', 'index', 'collection', foreignId),
  ]) {
    await store.create(EntityType.link, id, {
      'source_type': sourceType,
      'source_id': sourceId,
      'target_type': targetType,
      'target_id': targetId,
    }, physicalNowMs: 1200);
  }
}

/// The bundle [store] would ship for [collectionId], without blobs — with
/// the linked collections when [includeLinked].
Future<CollectionShareBundle> bundleOf(
  SyncStore store, {
  String collectionId = 'trip',
  bool includeLinked = false,
  List<PersistedOp> Function(List<PersistedOp>)? tamper,
}) async {
  final set = await store.shareSet(collectionId, includeLinked: includeLinked);
  final ops = tamper == null ? set.ops : tamper(set.ops);
  return CollectionShareBundle(
    manifest: CollectionShareManifest(
      createdAtMs: 2000,
      collectionId: collectionId,
      owner: set.collection.createdBy,
      title: set.collection.content['title']! as String,
      cardCount: set.liveCardCount,
      opCount: ops.length,
      blobCount: 0,
      mediaIncluded: false,
      included: [
        for (final linked in set.included)
          CollectionShareEntry(
            collectionId: linked.collection.id,
            owner: linked.collection.createdBy,
            title: linked.collection.content['title']! as String,
            cardCount: linked.liveCardCount,
          ),
      ],
    ),
    ops: ops,
    blobs: const {},
  );
}

/// An [AppGraph] over [store] and a fresh in-memory blob store.
AppGraph graphOf(SyncStore store) => AppGraph()
  ..bindStore(store)
  ..bindBlobStore(InMemoryAttachmentBlobStore());
