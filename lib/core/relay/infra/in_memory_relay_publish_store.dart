import 'package:knit/core/relay/domain/relay_publish_store.dart';
import 'package:knit/core/storage/domain/storage_context.dart';

/// In-memory [RelayPublishStore] for dev mode and tests — no SQLite, no platform
/// channel. Asserts the same contract as the sqflite impl.
class InMemoryRelayPublishStore implements RelayPublishStore {
  Uri? _relayUrl;
  final Map<String, CollectionPublication> _byCollection = {};

  @override
  Future<void> ensureSchema({StorageContext? ctx}) async {}

  @override
  Future<Uri?> loadRelayUrl({StorageContext? ctx}) async => _relayUrl;

  @override
  Future<void> saveRelayUrl(Uri url, {StorageContext? ctx}) async =>
      _relayUrl = url;

  @override
  Future<CollectionPublication?> loadPublication(
    String collectionId, {
    StorageContext? ctx,
  }) async => _byCollection[collectionId];

  @override
  Future<void> savePublication(
    CollectionPublication record, {
    StorageContext? ctx,
  }) async => _byCollection[record.collectionId] = record;

  @override
  Future<void> deletePublication(
    String collectionId, {
    StorageContext? ctx,
  }) async => _byCollection.remove(collectionId);
}
