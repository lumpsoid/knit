import 'dart:typed_data';

import 'package:knit/core/storage/domain/storage_context.dart';
import 'package:knit/core/storage/infra/sqflite/sqlite_storage_context.dart';
import 'package:knit/sync/identity/domain/domain.dart';
import 'package:sqflite/sqflite.dart';

/// sqflite-backed [LocalIdentityStorage] over the single-identity
/// `local_identity` table (spec §6.5).
class SqfliteLocalIdentityStorage implements LocalIdentityStorage {
  SqfliteLocalIdentityStorage({required Database db}) : _db = db;

  final Database _db;

  DatabaseExecutor _exec(StorageContext? ctx) =>
      ctx is SqliteStorageContext ? ctx.executor : _db;

  @override
  Future<void> ensureSchema({StorageContext? ctx}) =>
      _exec(ctx).execute(LocalIdentitySchema.createTable);

  @override
  Future<LocalIdentity?> load({StorageContext? ctx}) async {
    final rows = await _exec(ctx).query(LocalIdentitySchema.table, limit: 1);
    if (rows.isEmpty) return null;
    final row = rows.first;
    return LocalIdentity(
      publicKeyHex: row[LocalIdentitySchema.colPublicKey]! as String,
      secretKeyEnc: row[LocalIdentitySchema.colSecretKeyEnc]! as List<int>,
      createdAt: row[LocalIdentitySchema.colCreatedAt]! as int,
    );
  }

  @override
  Future<void> save(LocalIdentity identity, {StorageContext? ctx}) async {
    await _exec(ctx).insert(
      LocalIdentitySchema.table,
      {
        LocalIdentitySchema.colPublicKey: identity.publicKeyHex,
        LocalIdentitySchema.colSecretKeyEnc:
            Uint8List.fromList(identity.secretKeyEnc),
        LocalIdentitySchema.colCreatedAt: identity.createdAt,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> clear({StorageContext? ctx}) =>
      _exec(ctx).delete(LocalIdentitySchema.table);
}
