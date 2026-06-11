import 'package:flutter/foundation.dart';

/// Which graph the app runs (composition.md §2). Prod opens a real sqflite DB;
/// dev wires the fully in-memory [SyncStore] (no SQLite, no platform channel).
enum AppEnvironment { prod, dev }

/// Sync backend mode. Only [localOnly] exists for the §9.1 local-first slice;
/// the relay-backed mode arrives with §9.2.
enum BackendMode { localOnly }

/// The immutable value that selects the dependency graph (composition.md §2).
/// The *only* input to dependency resolution — resolvers are pure functions of
/// it and read no globals.
@immutable
class AppConfig {
  const AppConfig({required this.environment, required this.backend});

  final AppEnvironment environment;
  final BackendMode backend;

  /// Persistent sqflite graph (one DB file per device, §6.1).
  static const prod =
      AppConfig(environment: AppEnvironment.prod, backend: BackendMode.localOnly);

  /// Fully in-memory graph — runs on any platform with no SQLite setup.
  static const dev =
      AppConfig(environment: AppEnvironment.dev, backend: BackendMode.localOnly);
}
