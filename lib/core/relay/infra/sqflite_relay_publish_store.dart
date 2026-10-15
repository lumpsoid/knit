import 'package:knit/core/relay/domain/publication_snapshot.dart';
import 'package:knit/core/relay/domain/relay_publish_schema.dart';
import 'package:knit/core/relay/domain/relay_publish_store.dart';
import 'package:knit/core/storage/domain/storage_context.dart';
import 'package:knit/core/storage/infra/sqflite/sqlite_storage_context.dart';
import 'package:sqflite/sqflite.dart';

/// sqflite-backed [RelayPublishStore] over the device-local `relay_setting` and
/// `relay_publication` tables — never synced, never signed (like
/// `SqfliteLocalIdentityStorage`).
class SqfliteRelayPublishStore implements RelayPublishStore {
  SqfliteRelayPublishStore({required Database db}) : _db = db;

  final Database _db;

  DatabaseExecutor _exec(StorageContext? ctx) =>
      ctx is SqliteStorageContext ? ctx.executor : _db;

  @override
  Future<void> ensureSchema({StorageContext? ctx}) async {
    final exec = _exec(ctx);
    await exec.execute(RelayPublishSchema.createSettingTable);
    await exec.execute(RelayPublishSchema.createPublicationTable);
  }

  @override
  Future<Uri?> loadRelayUrl({StorageContext? ctx}) async {
    final rows = await _exec(ctx).query(
      RelayPublishSchema.settingTable,
      where: '${RelayPublishSchema.colSettingKey} = ?',
      whereArgs: [RelayPublishSchema.relayUrlKey],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final value = rows.first[RelayPublishSchema.colSettingValue] as String?;
    return value == null ? null : Uri.tryParse(value);
  }

  @override
  Future<void> saveRelayUrl(Uri url, {StorageContext? ctx}) async {
    await _exec(ctx).insert(RelayPublishSchema.settingTable, {
      RelayPublishSchema.colSettingKey: RelayPublishSchema.relayUrlKey,
      RelayPublishSchema.colSettingValue: url.toString(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<CollectionPublication?> loadPublication(
    String collectionId, {
    StorageContext? ctx,
  }) async {
    final rows = await _exec(ctx).query(
      RelayPublishSchema.publicationTable,
      where: '${RelayPublishSchema.colCollectionId} = ?',
      whereArgs: [collectionId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _fromRow(rows.first);
  }

  @override
  Future<void> savePublication(
    CollectionPublication record, {
    StorageContext? ctx,
  }) async {
    await _exec(ctx).insert(RelayPublishSchema.publicationTable, {
      RelayPublishSchema.colCollectionId: record.collectionId,
      RelayPublishSchema.colTopicId: record.topicId,
      RelayPublishSchema.colWriteToken: record.writeToken,
      RelayPublishSchema.colSlug: record.slug,
      RelayPublishSchema.colVisibility: record.visibility.tag,
      RelayPublishSchema.colPublishedAt: record.publishedAt,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> deletePublication(
    String collectionId, {
    StorageContext? ctx,
  }) async {
    await _exec(ctx).delete(
      RelayPublishSchema.publicationTable,
      where: '${RelayPublishSchema.colCollectionId} = ?',
      whereArgs: [collectionId],
    );
  }

  CollectionPublication _fromRow(Map<String, Object?> row) =>
      CollectionPublication(
        collectionId: row[RelayPublishSchema.colCollectionId]! as String,
        topicId: row[RelayPublishSchema.colTopicId]! as String,
        writeToken: row[RelayPublishSchema.colWriteToken]! as String,
        slug: row[RelayPublishSchema.colSlug] as String?,
        visibility: PublishVisibility.fromTag(
          row[RelayPublishSchema.colVisibility] as String?,
        ),
        publishedAt: row[RelayPublishSchema.colPublishedAt] as int?,
      );
}
