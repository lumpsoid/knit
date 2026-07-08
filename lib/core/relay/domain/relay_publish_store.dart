import 'package:knit/core/relay/domain/publication_snapshot.dart';
import 'package:knit/core/storage/domain/storage_context.dart';

/// The device-local record of a collection's relay publication (relay §2.6).
/// Local-only, never synced: [topicId] + [writeToken] address the collection on
/// the relay; [slug] is its public web address once published (null before the
/// first publish). [visibility] is the last-set public/private toggle.
class CollectionPublication {
  const CollectionPublication({
    required this.collectionId,
    required this.topicId,
    required this.writeToken,
    this.slug,
    required this.visibility,
    this.publishedAt,
  });

  final String collectionId;
  final String topicId;
  final String writeToken;
  final String? slug;
  final PublishVisibility visibility;
  final int? publishedAt;

  CollectionPublication copyWith({
    String? slug,
    PublishVisibility? visibility,
    int? publishedAt,
  }) => CollectionPublication(
    collectionId: collectionId,
    topicId: topicId,
    writeToken: writeToken,
    slug: slug ?? this.slug,
    visibility: visibility ?? this.visibility,
    publishedAt: publishedAt ?? this.publishedAt,
  );
}

/// Device-local persistence for relay publishing — never synced, never signed
/// (modeled on `LocalIdentityStorage`, spec §6.5). Holds the relay base URL and,
/// per collection, its topic/token/slug/visibility.
///
/// Plain futures rather than `Result` (like the other on-device storages); the
/// infra caller wraps failures into a `RelayFailure` at the seam. An abstract
/// port with a sqflite impl (prod) and an in-memory impl (dev/tests), asserted
/// against the same contract.
abstract interface class RelayPublishStore {
  Future<void> ensureSchema({StorageContext? ctx});

  /// The configured relay base URL, or null on a fresh device.
  Future<Uri?> loadRelayUrl({StorageContext? ctx});

  Future<void> saveRelayUrl(Uri url, {StorageContext? ctx});

  /// The publication record for [collectionId], or null if never published.
  Future<CollectionPublication?> loadPublication(
    String collectionId, {
    StorageContext? ctx,
  });

  /// Upsert the record by collection id.
  Future<void> savePublication(
    CollectionPublication record, {
    StorageContext? ctx,
  });

  Future<void> deletePublication(String collectionId, {StorageContext? ctx});
}
