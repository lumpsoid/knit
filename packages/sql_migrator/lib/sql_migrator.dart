/// A backend-agnostic SQLite schema migrator: ordered up/down migrations,
/// checksum tamper-detection, an advisory lock, and a pluggable
/// [MigrationExecutor] (sqflite, or the in-memory fake for tests).
library;

export 'src/domain/domain.dart';
export 'src/infra/infra.dart';
