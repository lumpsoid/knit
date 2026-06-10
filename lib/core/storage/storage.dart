/// Backend-agnostic storage primitives shared across features.
///
/// The [StorageContext] / [UnitOfWork] abstractions keep storage *interfaces*
/// free of any database package, so a feature's storage can be driven by sqflite
/// in production and by an in-memory fake in dev/tests. The sqflite bindings live
/// under `infra/sqflite`.
library;

export 'domain/domain.dart';
export 'infra/infra.dart';
