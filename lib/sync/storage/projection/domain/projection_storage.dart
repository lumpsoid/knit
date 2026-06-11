import 'package:knit/core/storage/domain/storage_context.dart';
import 'package:knit/sync/snapshot.dart';

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

  /// Live links pointing at [targetId] — the backlink query (spec §8.6.2).
  /// Endpoint liveness (the broken-link chip, §8.6.1) is resolved by the caller.
  Future<List<Snapshot>> backlinks(String targetId, {StorageContext? ctx});

  /// Live links originating at [sourceId] — the forward links-out query
  /// (spec §4.4). Mirror of [backlinks]; endpoint liveness (§8.6.1) is resolved
  /// by the caller.
  Future<List<Snapshot>> linksOut(String sourceId, {StorageContext? ctx});

  /// Truncate every entity table (rebuild step 1, spec §8.9).
  Future<void> clear({StorageContext? ctx});
}
