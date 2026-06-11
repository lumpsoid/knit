import 'package:knit/app/app_graph.dart';
import 'package:knit/features/app_launch/domain/initialization_repository.dart';
import 'package:knit/sync/sync.dart';

/// Dev init (composition.md §1): wire the fully in-memory [SyncStore] (no
/// SQLite, no platform channel) and bind it into the [AppGraph]. Runs on any
/// platform. Identity generation is deferred to onboarding
/// (`provisionIdentity: false`), so every fresh run starts at the ceremony.
class InMemoryInitializationRepository implements InitializationRepository {
  InMemoryInitializationRepository({required AppGraph graph}) : _graph = graph;

  final AppGraph _graph;

  @override
  Future<void> initialize() async {
    final store = SyncStore.inMemory();
    await store.open(provisionIdentity: false);
    _graph.bindStore(store);
  }
}
