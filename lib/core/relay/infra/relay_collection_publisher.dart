import 'package:knit/core/relay/domain/collection_publisher.dart';
import 'package:knit/core/relay/domain/publication_snapshot.dart';
import 'package:knit/core/relay/domain/relay_failure.dart';
import 'package:knit/core/relay/domain/relay_publish_client.dart';
import 'package:knit/core/relay/domain/relay_publish_store.dart';
import 'package:knit/core/relay/infra/snapshot_builder.dart';
import 'package:knit/sync/identity/domain/domain.dart';
import 'package:result_dart/result_dart.dart';

/// [CollectionPublisher] wiring the narrow ports into the publish flow (relay
/// §2.6). This is the imperative orchestrator — it sequences I/O and unwraps
/// each `Result`, but makes no business decisions of its own:
///
///   1. reuse the collection's topic + token, or mint them once (binding the
///      local identity's pubkey as owner);
///   2. build the snapshot + its blobs from the collection read model;
///   3. upload every blob, then publish the snapshot at the chosen visibility;
///   4. persist the returned slug + visibility locally.
class RelayCollectionPublisher implements CollectionPublisher {
  const RelayCollectionPublisher({
    required RelayPublishClient client,
    required RelayPublishStore store,
    required SnapshotBuilder snapshotBuilder,
    required LocalIdentityStorage identity,
  }) : _client = client,
       _store = store,
       _builder = snapshotBuilder,
       _identity = identity;

  final RelayPublishClient _client;
  final RelayPublishStore _store;
  final SnapshotBuilder _builder;
  final LocalIdentityStorage _identity;

  @override
  Future<Result<PublishedRef, RelayFailure>> publish({
    required String collectionId,
    required PublishVisibility visibility,
  }) async {
    try {
      // 1. topic + token — reuse the persisted pair, or mint once.
      final existing = await _store.loadPublication(collectionId);
      final RelayTopic topic;
      if (existing != null) {
        topic = RelayTopic(
          topicId: existing.topicId,
          writeToken: existing.writeToken,
        );
      } else {
        final id = await _identity.load();
        if (id == null) return const Failure(RelayIdentityMissing());
        final created = await _client.createTopic(id.publicKeyHex);
        if (created.isFailure) return Failure(created.error!);
        topic = created.getOrThrow();
        await _store.savePublication(
          CollectionPublication(
            collectionId: collectionId,
            topicId: topic.topicId,
            writeToken: topic.writeToken,
            visibility: visibility,
          ),
        );
      }

      // 2. build snapshot + blobs.
      final built = await _builder.build(collectionId);
      if (built.isFailure) return Failure(built.error!);
      final result = built.getOrThrow();

      // 3. upload blobs, then publish.
      for (final blob in result.blobs) {
        final uploaded = await _client.putBlob(
          topic: topic.topicId,
          writeToken: topic.writeToken,
          hash: blob.hash,
          mime: blob.mime,
          bytes: blob.bytes,
        );
        if (uploaded.isFailure) return Failure(uploaded.error!);
      }

      final published = await _client.putPublication(
        topic: topic.topicId,
        writeToken: topic.writeToken,
        visibility: visibility,
        title: result.snapshot.title,
        snapshot: result.snapshot,
      );
      if (published.isFailure) return Failure(published.error!);
      final ref = published.getOrThrow();

      // 4. persist the public address + toggle.
      await _store.savePublication(
        CollectionPublication(
          collectionId: collectionId,
          topicId: topic.topicId,
          writeToken: topic.writeToken,
          slug: ref.slug,
          visibility: visibility,
          publishedAt: ref.publishedAt,
        ),
      );

      return Ok(ref);
    } catch (e, st) {
      return Failure(RelayUnexpected(e, st));
    }
  }

  @override
  Future<Result<void, RelayFailure>> unpublish(String collectionId) async {
    try {
      final existing = await _store.loadPublication(collectionId);
      if (existing == null) return const Ok<void, RelayFailure>(null);

      final deleted = await _client.deletePublication(
        topic: existing.topicId,
        writeToken: existing.writeToken,
      );
      if (deleted.isFailure) return Failure(deleted.error!);

      // Keep the topic/token (so a re-publish reuses them) but drop the slug.
      await _store.savePublication(
        CollectionPublication(
          collectionId: existing.collectionId,
          topicId: existing.topicId,
          writeToken: existing.writeToken,
          visibility: PublishVisibility.private,
        ),
      );

      return const Ok<void, RelayFailure>(null);
    } catch (e, st) {
      return Failure(RelayUnexpected(e, st));
    }
  }

  @override
  Future<Result<PublishedRef?, RelayFailure>> status(
    String collectionId,
  ) async {
    try {
      final existing = await _store.loadPublication(collectionId);
      if (existing == null) return const Ok<PublishedRef?, RelayFailure>(null);
      return await _client.getPublication(
        topic: existing.topicId,
        writeToken: existing.writeToken,
      );
    } catch (e, st) {
      return Failure(RelayUnexpected(e, st));
    }
  }
}
