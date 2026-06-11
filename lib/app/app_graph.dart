import 'package:knit/sync/sync.dart';

/// The resolved dependency graph (composition.md §2). A mutable cell the
/// `InitializationRepository` populates at launch; features read the live
/// [SyncStore] from it — **only after** initialization completes (the
/// destination resolver guarantees features run post-init).
///
/// Holding the store behind a cell (rather than passing it in at construction)
/// lets the feature Scopes be wired in `main()` before the async graph is up:
/// their repositories capture this graph and read `.store` lazily.
class AppGraph {
  SyncStore? _store;

  /// True once [bindStore] has run (initialization completed).
  bool get isReady => _store != null;

  /// The live store. Throws if read before initialization completes.
  SyncStore get store =>
      _store ??
      (throw StateError(
        'AppGraph is not initialized — InitializationRepository.initialize() '
        'must complete before features read the store.',
      ));

  /// Bind the resolved store. Called once, by the init repository.
  void bindStore(SyncStore store) => _store = store;
}
