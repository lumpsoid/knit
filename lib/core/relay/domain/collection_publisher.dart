import 'package:knit/core/relay/domain/publication_snapshot.dart';
import 'package:knit/core/relay/domain/relay_failure.dart';
import 'package:knit/core/relay/domain/relay_publish_client.dart';
import 'package:result_dart/result_dart.dart';

/// The one high-level relay-publishing use case (business_logic.md §placement
/// ladder — a use case, not a shell decision): put a collection on the web, or
/// take it back. It orchestrates the narrow ports — provision/reuse the topic,
/// build the snapshot, upload blobs, publish, and persist the result — so a
/// future share sheet's shell calls a single method.
abstract interface class CollectionPublisher {
  /// Publish [collectionId] at [visibility], returning its public web address.
  /// Idempotent across calls: the collection's topic + token are minted once and
  /// reused, so re-publishing just refreshes the snapshot and the toggle.
  Future<Result<PublishedRef, RelayFailure>> publish({
    required String collectionId,
    required PublishVisibility visibility,
  });

  /// Take [collectionId]'s web page offline. A no-op (success) if it was never
  /// published.
  Future<Result<void, RelayFailure>> unpublish(String collectionId);

  /// The collection's current publication state, or `null` if never published.
  Future<Result<PublishedRef?, RelayFailure>> status(String collectionId);
}
