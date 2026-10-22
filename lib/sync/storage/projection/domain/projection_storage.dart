import 'package:knit/core/storage/domain/storage_context.dart';
import 'package:knit/sync/snapshot.dart';

/// A card's §8.7 feed sort key — `position`, then `id` breaking ties. Used as a
/// keyset cursor by [ProjectionStorage.feedPage].
typedef FeedKey = ({String position, String id});

/// The materialized entity projection (spec §6.4/§6.8), abstracted over the
/// backend. Merge writes the winning [Snapshot] via [upsert]; the UI reads it
/// back. Production uses sqflite tables; dev/tests use the in-memory impl.
///
/// This stores the *result* of a merge — comparison/LWW lives in the merge-core
/// (`merge()`), which reads the current row via [get] and writes the winner via
/// [upsert]. Read-time derivations ([feed], [backlinks]) are never synced/signed
/// (spec §8.6/§8.7).
abstract class ProjectionStorage {
  /// Create all entity tables if needed (sqflite); a no-op for in-memory.
  Future<void> ensureSchema({StorageContext? ctx});

  /// The current row for an entity, or null if absent.
  Future<Snapshot?> get(EntityType type, String id, {StorageContext? ctx});

  /// Write the winning snapshot into its table (replace by id).
  Future<void> upsert(Snapshot snapshot, {StorageContext? ctx});

  /// Every row across all entity tables (tombstones included) — used to
  /// materialize from / compare against a rebuild (spec §8.9).
  Future<List<Snapshot>> readAll({StorageContext? ctx});

  /// Live cards in a collection, in feed order — spec §8.7
  /// (`position ASC, id ASC`, `deleted=0`).
  Future<List<Snapshot>> feed(String collectionId, {StorageContext? ctx});

  /// A keyset page of live cards in a collection, **newest first** (reverse
  /// §8.7 order: `position DESC, id DESC`) — so a chat-style feed can load its
  /// tail without reading the whole collection. [before] keeps only cards
  /// strictly older than that key; [atOrAfter] only cards at or newer than it;
  /// [limit] caps the row count (null ⇒ unbounded).
  Future<List<Snapshot>> feedPage(
    String collectionId, {
    FeedKey? before,
    FeedKey? atOrAfter,
    int? limit,
    StorageContext? ctx,
  });

  /// The rows of [type] whose id is in [ids] (tombstones included), in no
  /// particular order; missing ids are simply absent. One batched read instead
  /// of a [get] per id.
  Future<List<Snapshot>> getMany(
    EntityType type,
    Iterable<String> ids, {
    StorageContext? ctx,
  });

  /// Delete the rows of [type] whose id is in [ids] — the local purge of an
  /// imported collection. Missing ids are ignored.
  Future<void> deleteMany(
    EntityType type,
    Iterable<String> ids, {
    StorageContext? ctx,
  });

  /// Live links pointing at [targetId] — the backlink query (spec §8.6.2).
  /// Endpoint liveness (the broken-link chip, §8.6.1) is resolved by the caller.
  Future<List<Snapshot>> backlinks(String targetId, {StorageContext? ctx});

  /// Live links originating at [sourceId] — the forward links-out query
  /// (spec §4.4). Mirror of [backlinks]; endpoint liveness (§8.6.1) is resolved
  /// by the caller.
  Future<List<Snapshot>> linksOut(String sourceId, {StorageContext? ctx});

  /// Live links originating at any of [sourceIds] — [linksOut] batched, in no
  /// particular order.
  Future<List<Snapshot>> linksOutOf(
    Iterable<String> sourceIds, {
    StorageContext? ctx,
  });

  /// Live links pointing at any of [targetIds] — [backlinks] batched, in no
  /// particular order.
  Future<List<Snapshot>> backlinksTo(
    Iterable<String> targetIds, {
    StorageContext? ctx,
  });

  /// The live cards of every collection in [collectionIds], in no particular
  /// order — one batched read for per-collection counters (§8.6.3).
  Future<List<Snapshot>> liveCardsIn(
    Iterable<String> collectionIds, {
    StorageContext? ctx,
  });

  /// Truncate every entity table (rebuild step 1, spec §8.9).
  Future<void> clear({StorageContext? ctx});
}
