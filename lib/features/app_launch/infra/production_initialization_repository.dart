import 'package:knit/app/app_graph.dart';
import 'package:knit/app/schema/knit_migrations.dart';
import 'package:knit/core/attachments/domain/legacy_attachment_split_migration.dart';
import 'package:knit/core/attachments/infra/filesystem_attachment_blob_store.dart';
import 'package:knit/core/attachments/infra/sync_store_legacy_attachment_migration_port.dart';
import 'package:knit/core/ids/uuid_id_generator.dart';
import 'package:knit/core/storage/storage.dart';
import 'package:knit/features/app_launch/domain/initialization_repository.dart';
import 'package:knit/sync/sync.dart';
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';
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
  }) : _graph = graph,
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

    // Attachment bytes live on the filesystem out-of-band (spec §6.4/§7.4.8),
    // content-addressed under the app support dir.
    final support = await getApplicationSupportDirectory();
    _graph.bindBlobStore(
      FilesystemAttachmentBlobStore(baseDir: '${support.path}/blobs'),
    );

    await _runDataMigrations(store);
  }

  /// One-time, idempotent data migrations over the signed write path. Best-effort
  /// — a failure is logged and swallowed so it can never brick startup; the data
  /// is left as-is (the per-card GC guard still protects it) and the pass retries
  /// next launch. Gated on identity: a fresh device has no content and cannot
  /// sign until onboarding provisions a key, so there is nothing to migrate.
  Future<void> _runDataMigrations(SyncStore store) async {
    if (!await store.hasIdentity()) return;
    try {
      // Heal pre-`83a99bc` attachment records shared by >1 card so each card
      // owns its own record (the 1 referent : 1 record invariant). No relay yet,
      // so a plain local pass — fresh ids can't collide with another device.
      await LegacyAttachmentSplitMigration(
        SyncStoreLegacyAttachmentMigrationPort(
          graph: _graph,
          ids: const UuidIdGenerator(),
        ),
      ).run();
    } catch (e, st) {
      Logger('knit.app_launch').severe('Data migration failed', e, st);
    }
  }
}
