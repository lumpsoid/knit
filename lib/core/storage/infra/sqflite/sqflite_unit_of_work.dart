import 'package:knit/core/storage/domain/storage_context.dart';
import 'package:knit/core/storage/domain/unit_of_work.dart';
import 'package:knit/core/storage/infra/sqflite/sqlite_storage_context.dart';
import 'package:sqflite/sqflite.dart';

/// A [UnitOfWork] backed by a sqflite [Database]. Opens a real transaction and
/// hands the work a [SqliteStorageContext] wrapping the transaction executor, so
/// every storage call inside [run] commits or rolls back atomically.
///
/// This is the seam the spec leans on for crash-safety (§6.8 / §8.5): the entity
/// projection write, the `change_log` insert, and the `device_clock` advance must
/// all commit in one transaction.
class SqfliteUnitOfWork implements UnitOfWork {
  const SqfliteUnitOfWork(this._db);

  final Database _db;

  @override
  Future<T> run<T>(Future<T> Function(StorageContext ctx) work) {
    return _db.transaction((txn) => work(SqliteStorageContext(txn)));
  }
}
