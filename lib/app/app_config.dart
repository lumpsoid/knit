import 'package:flutter/foundation.dart';

/// Which graph the app runs (composition.md §2). Prod opens a real sqflite DB;
/// dev wires the fully in-memory [SyncStore] (no SQLite, no platform channel).
enum AppEnvironment { prod, dev }

/// Sync backend mode. Only [localOnly] exists for the §9.1 local-first slice;
/// the relay-backed mode arrives with §9.2.
enum BackendMode { localOnly }

/// The build flavor. Selected at compile time by the entry point
/// (`lib/main_<flavor>.dart`) and the matching Android product flavor; it is
/// the single input from which the runtime [AppConfig] is derived. The three
/// flavors install side by side (distinct application ids) so a developer can
/// keep dev / staging / prod builds on one device.
enum Flavor {
  dev,
  staging,
  prod;

  /// The dependency graph this flavor runs (composition.md §2). `dev` iterates
  /// on the in-memory graph (no SQLite, any platform); `staging` and `prod`
  /// persist to the sqflite DB (one file per device, §6.1).
  AppConfig get config => switch (this) {
    Flavor.dev => const AppConfig(
      flavor: Flavor.dev,
      environment: AppEnvironment.dev,
      backend: BackendMode.localOnly,
    ),
    Flavor.staging => const AppConfig(
      flavor: Flavor.staging,
      environment: AppEnvironment.prod,
      backend: BackendMode.localOnly,
    ),
    Flavor.prod => const AppConfig(
      flavor: Flavor.prod,
      environment: AppEnvironment.prod,
      backend: BackendMode.localOnly,
    ),
  };

  /// Short upper-case tag for the in-app flavor banner and diagnostics.
  String get label => switch (this) {
    Flavor.dev => 'DEV',
    Flavor.staging => 'STAGING',
    Flavor.prod => 'PROD',
  };
}

/// The immutable value that selects the dependency graph (composition.md §2).
/// The *only* input to dependency resolution — resolvers are pure functions of
/// it and read no globals.
@immutable
class AppConfig {
  const AppConfig({
    required this.flavor,
    required this.environment,
    required this.backend,
  });

  final Flavor flavor;
  final AppEnvironment environment;
  final BackendMode backend;

  /// True only for the prod flavor — gates the in-app flavor banner.
  bool get isProd => flavor == Flavor.prod;

  /// Persistent sqflite graph (one DB file per device, §6.1) — the prod flavor.
  static const prod = AppConfig(
    flavor: Flavor.prod,
    environment: AppEnvironment.prod,
    backend: BackendMode.localOnly,
  );

  /// Fully in-memory graph — runs on any platform with no SQLite setup. The
  /// dev flavor's graph.
  static const dev = AppConfig(
    flavor: Flavor.dev,
    environment: AppEnvironment.dev,
    backend: BackendMode.localOnly,
  );
}
