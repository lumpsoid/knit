import 'package:knit/core/storage/domain/storage_context.dart';

/// Runs a unit of work atomically, handing the [work] callback a
/// [StorageContext] bound to the ambient transaction. Every storage call made
/// with that context commits or rolls back together.
///
/// Backend-agnostic: the sqflite implementation opens a real transaction; the
/// [NoOpUnitOfWork] just runs the work with a [NoOpStorageContext] for dev/tests
/// over in-memory storages.
abstract class UnitOfWork {
  Future<T> run<T>(Future<T> Function(StorageContext ctx) work);
}

/// A pass-through unit of work — no real transaction. Pairs with in-memory
/// storages in dev mode and tests, where atomicity is not being exercised.
class NoOpUnitOfWork implements UnitOfWork {
  const NoOpUnitOfWork();

  @override
  Future<T> run<T>(Future<T> Function(StorageContext ctx) work) =>
      work(const NoOpStorageContext());
}
