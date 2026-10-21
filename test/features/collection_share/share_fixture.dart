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

/// The bundle [store] would ship for [collectionId], without blobs.
Future<CollectionShareBundle> bundleOf(
  SyncStore store, {
  String collectionId = 'trip',
  List<PersistedOp> Function(List<PersistedOp>)? tamper,
}) async {
  final set = await store.shareSet(collectionId);
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
    ),
    ops: ops,
    blobs: const {},
  );
}

/// An [AppGraph] over [store] and a fresh in-memory blob store.
AppGraph graphOf(SyncStore store) => AppGraph()
  ..bindStore(store)
  ..bindBlobStore(InMemoryAttachmentBlobStore());
