import 'package:knit/app/app_graph.dart';
import 'package:knit/app/schema/knit_migrations.dart';
import 'package:knit/core/storage/storage.dart';
import 'package:knit/features/app_launch/domain/initialization_repository.dart';
import 'package:knit/sync/sync.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sql_migrator/sql_migrator.dart';

/// Production init (composition.md §1): open the per-device sqflite DB, run the
/// `package:sql_migrator` schema migrations, build the sqflite [SyncStore], and
/// bind it into the [AppGraph]. Schema is owned by the migrator (so
/// `open(ensureSchema: false)`); identity generation is deferred to the
/// onboarding "Generate" step (`provisionIdentity: false`).
class ProductionInitializationRepository implements InitializationRepository {
  ProductionInitializationRepository({
    required AppGraph graph,
    String databaseName = 'knit.db',
  })  : _graph = graph,
        _databaseName = databaseName;

  final AppGraph _graph;
  final String _databaseName;

  @override
  Future<void> initialize() async {
    final dir = await getDatabasesPath();
    final db = await openDatabase('$dir/$_databaseName');

    await Migrator(
      executor: SqfliteExecutor(db),
      migrations: knitMigrations(),
      logger: const NoOpMigrationLogger(),
    ).migrate();

    final store = SyncStore(
      changeLog: SqfliteChangeLogStorage(db: db),
      projection: SqfliteProjectionStorage(db: db),
      deviceClock: SqfliteDeviceClockStorage(db: db),
      localIdentity: SqfliteLocalIdentityStorage(db: db),
      quarantine: SqfliteQuarantineStorage(db: db),
      signer: Ed25519Signer(),
      unitOfWork: SqfliteUnitOfWork(db),
    );
    await store.open(ensureSchema: false, provisionIdentity: false);
    _graph.bindStore(store);
  }
}
