import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:knit/core/attachments/domain/attachment_failure.dart';
import 'package:knit/core/attachments/domain/attachment_models.dart';
import 'package:knit/core/attachments/domain/attachment_read_repository.dart';
import 'package:knit/core/relay/relay.dart';
import 'package:knit/features/collection/domain/collection_failure.dart';
import 'package:knit/features/collection/domain/collection_models.dart';
import 'package:knit/features/collection/domain/collection_read_repository.dart';
import 'package:knit/sync/identity/domain/domain.dart';
import 'package:knit/sync/identity/infra/in_memory_local_identity_storage.dart';
import 'package:result_dart/result_dart.dart';

/// The orchestrator sequences the whole publish flow (relay §2.6). We drive it
/// against a fake client (no network) + the in-memory store, and assert the
/// sequence: mint-once topic, blob upload, publish, and local persistence.
void main() {
  late _FakeClient client;
  late InMemoryRelayPublishStore store;
  late InMemoryLocalIdentityStorage identity;
  late RelayCollectionPublisher publisher;

  final photo = Uint8List.fromList([1, 2, 3]);

  setUp(() async {
    client = _FakeClient();
    store = InMemoryRelayPublishStore();
    identity = InMemoryLocalIdentityStorage();
    await identity.save(
      const LocalIdentity(
        publicKeyHex: 'owner-pub',
        secretKeyEnc: [0],
        createdAt: 0,
      ),
    );

    final collectionRead = _FakeCollectionRead(
      const CollectionData(
        collectionId: 'c1',
        title: 'Trip',
        description: null,
        coverAttachmentId: 'photo',
        cards: [
          FeedCard(
            id: 'k1',
            kind: CardKind.image,
            position: 'a',
            attachmentId: 'photo',
          ),
        ],
      ),
    );
    final attachmentRead = _FakeAttachmentRead({
      'photo': AttachmentBytes(bytes: photo, mime: 'image/jpeg'),
    });

    publisher = RelayCollectionPublisher(
      client: client,
      store: store,
      snapshotBuilder: SnapshotBuilder(
        collectionRead: collectionRead,
        attachmentRead: attachmentRead,
      ),
      identity: identity,
    );
  });

  test(
    'first publish mints a topic, uploads blobs, publishes, and persists',
    () async {
      final result = await publisher.publish(
        collectionId: 'c1',
        visibility: PublishVisibility.public,
      );

      final ref = result.getOrThrow();
      expect(ref.slug, 'slug-1');
      expect(ref.url, 'https://relay.test/c/slug-1');

      // topic minted once, bound to the local identity.
      expect(client.createTopicCalls, ['owner-pub']);
      // the referenced photo was uploaded before publishing.
      expect(client.uploadedHashes, hasLength(1));
      expect(client.putPublicationCalls, 1);
      expect(client.lastVisibility, PublishVisibility.public);

      // persisted locally: topic/token + slug + visibility.
      final saved = (await store.loadPublication('c1'))!;
      expect(saved.topicId, 'topic-1');
      expect(saved.writeToken, 'wtok-1');
      expect(saved.slug, 'slug-1');
      expect(saved.visibility, PublishVisibility.public);
    },
  );

  test('re-publishing reuses the stored topic, minting no new one', () async {
    await publisher.publish(
      collectionId: 'c1',
      visibility: PublishVisibility.public,
    );
    await publisher.publish(
      collectionId: 'c1',
      visibility: PublishVisibility.private,
    );

    expect(client.createTopicCalls, ['owner-pub']); // only once
    expect(client.putPublicationCalls, 2);
    expect(client.lastVisibility, PublishVisibility.private);
    expect(
      (await store.loadPublication('c1'))!.visibility,
      PublishVisibility.private,
    );
  });

  test('publish fails cleanly when no identity is provisioned', () async {
    await identity.clear();

    final result = await publisher.publish(
      collectionId: 'c1',
      visibility: PublishVisibility.public,
    );

    expect(result.isFailure, isTrue);
    expect(result.error, isA<RelayIdentityMissing>());
    expect(client.createTopicCalls, isEmpty);
  });

  test('unpublish deletes on the relay and clears the local slug', () async {
    await publisher.publish(
      collectionId: 'c1',
      visibility: PublishVisibility.public,
    );

    final result = await publisher.unpublish('c1');
    expect(result.isSuccess, isTrue);
    expect(client.deleteCalls, 1);

    final saved = (await store.loadPublication('c1'))!;
    expect(saved.slug, isNull); // topic kept, slug dropped
    expect(saved.topicId, 'topic-1');
  });

  test('a blob upload failure aborts before publishing', () async {
    client.failBlob = true;

    final result = await publisher.publish(
      collectionId: 'c1',
      visibility: PublishVisibility.public,
    );

    expect(result.isFailure, isTrue);
    expect(client.putPublicationCalls, 0);
  });
}

class _FakeClient implements RelayPublishClient {
  final List<String> createTopicCalls = [];
  final List<String> uploadedHashes = [];
  int putPublicationCalls = 0;
  int deleteCalls = 0;
  PublishVisibility? lastVisibility;
  bool failBlob = false;

  int _topicSeq = 0;
  int _slugSeq = 0;

  @override
  Future<Result<RelayTopic, RelayFailure>> createTopic(
    String ownerPubkey,
  ) async {
    createTopicCalls.add(ownerPubkey);
    _topicSeq++;
    return Ok(
      RelayTopic(topicId: 'topic-$_topicSeq', writeToken: 'wtok-$_topicSeq'),
    );
  }

  @override
  Future<Result<void, RelayFailure>> putBlob({
    required String topic,
    required String writeToken,
    required String hash,
    required String mime,
    required Uint8List bytes,
  }) async {
    if (failBlob) {
      return const Failure(
        RelayResponseFailure(
          statusCode: 400,
          code: 'hash_mismatch',
          error: 'x',
        ),
      );
    }
    uploadedHashes.add(hash);
    return const Ok(null);
  }

  @override
  Future<Result<PublishedRef, RelayFailure>> putPublication({
    required String topic,
    required String writeToken,
    required PublishVisibility visibility,
    String? title,
    required PublicationSnapshot snapshot,
  }) async {
    putPublicationCalls++;
    lastVisibility = visibility;
    _slugSeq++;
    return Ok(
      PublishedRef(
        slug: 'slug-$_slugSeq',
        url: 'https://relay.test/c/slug-$_slugSeq',
        visibility: visibility,
        revoked: false,
        publishedAt: 1000 + _slugSeq,
      ),
    );
  }

  @override
  Future<Result<PublishedRef?, RelayFailure>> getPublication({
    required String topic,
    required String writeToken,
  }) async => const Ok(null);

  @override
  Future<Result<void, RelayFailure>> deletePublication({
    required String topic,
    required String writeToken,
  }) async {
    deleteCalls++;
    return const Ok(null);
  }
}

class _FakeCollectionRead implements CollectionReadRepository {
  _FakeCollectionRead(this._data);
  final CollectionData _data;

  @override
  Future<Result<CollectionData, CollectionFailure>> loadCollection(
    String id, {
    FeedWindow window = const FeedWindow.all(),
  }) async => Ok(_data);

  @override
  Future<Result<FeedPage, CollectionFailure>> loadOlderCards(
    String collectionId, {
    required FeedCursor before,
    required int limit,
  }) => throw UnimplementedError();

  @override
  Future<Result<List<LinkOption>, CollectionFailure>> loadLinkCollections() =>
      throw UnimplementedError();

  @override
  Future<Result<List<LinkOption>, CollectionFailure>> loadCollectionCards(
    String c,
  ) => throw UnimplementedError();

  @override
  Future<Result<bool, CollectionFailure>> isAttachmentReferenced(String a) =>
      throw UnimplementedError();
}

class _FakeAttachmentRead implements AttachmentReadRepository {
  _FakeAttachmentRead(this._byId);
  final Map<String, AttachmentBytes> _byId;

  @override
  Future<Result<AttachmentBytes, AttachmentFailure>> bytesOf(
    String attachmentId,
  ) async {
    final a = _byId[attachmentId];
    if (a == null) return Failure(AttachmentNotFound(attachmentId));
    return Ok(a);
  }
}
