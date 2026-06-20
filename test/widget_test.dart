import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:knit/app/app_config.dart';
import 'package:knit/app/app_graph.dart';
import 'package:knit/app/composition.dart';
import 'package:knit/features/app_launch/presentation/app_launch_module.dart';
import 'package:knit/features/app_launch/presentation/app_launch_scope.dart';
import 'package:knit/features/backup/infra/in_memory_backup_ports.dart';
import 'package:knit/features/backup/infra/sync_store_backup_export_repository.dart';
import 'package:knit/features/backup/infra/sync_store_backup_import_repository.dart';
import 'package:knit/features/onboard/infra/sync_store_onboard_repository.dart';
import 'package:knit/features/onboard/presentation/onboard_module.dart';
import 'package:knit/features/onboard/presentation/onboard_scope.dart';
import 'package:knit/core/attachments/infra/sync_store_attachment_read_repository.dart';
import 'package:knit/core/ids/uuid_id_generator.dart';
import 'package:knit/features/collection/presentation/collection_route_args.dart';
import 'package:knit/features/settings/infra/shared_preferences_settings_repository.dart';
import 'package:knit/features/settings/presentation/settings_module.dart';
import 'package:knit/features/settings/presentation/settings_scope.dart';
import 'package:knit/features/timeline/infra/sync_store_timeline_repository.dart';
import 'package:knit/features/timeline/infra/sync_store_timeline_write_repository.dart';
import 'package:knit/features/timeline/infra/timeline_channel_notifier.dart';
import 'package:knit/features/timeline/presentation/timeline_module.dart';
import 'package:knit/features/timeline/presentation/timeline_scope.dart';
import 'package:knit/main.dart';

void main() {
  /// Wire the global Scopes against a fresh in-memory graph, mirroring main().
  void wire() {
    final graph = AppGraph();
    AppLaunchScope.setController(
      AppLaunchModule(
        initialization:
            resolveInitializationRepository(AppConfig.dev, graph),
        destinationResolver:
            resolveAppDestinationResolver(AppConfig.dev, graph),
      ).controller,
    );
    OnboardScope.setFactory(
      () => OnboardModule(repository: SyncStoreOnboardRepository(graph: graph))
          .controller,
    );
    TimelineScope.setRouteArgsWriter(InMemoryCollectionRouteArgsStore());
    TimelineScope.setFactory(
      () => TimelineModule(
        readRepository: SyncStoreTimelineRepository(graph: graph),
        writeRepository: SyncStoreTimelineWriteRepository(
          graph: graph,
          ids: const UuidIdGenerator(),
        ),
        attachmentReadRepository:
            SyncStoreAttachmentReadRepository(graph: graph),
        channelReader: TimelineChannelNotifier(),
      ).controller,
    );
    // KnitApp observes SettingsScope for theme/locale on boot; the backup ports
    // are lazy (never touched during onboarding) so in-memory doubles suffice.
    const settingsRepository = SharedPreferencesSettingsRepository();
    SettingsScope.setFactory(
      () => SettingsModule(
        readRepository: settingsRepository,
        writeRepository: settingsRepository,
        backupExportRepository: SyncStoreBackupExportRepository(graph: graph),
        backupImportRepository: SyncStoreBackupImportRepository(graph: graph),
        backupDeliveryPort: RecordingBackupDeliveryPort(),
        backupSavePort: RecordingBackupSavePort(),
        backupSourcePort: StubBackupSourcePort(),
      ).controller,
    );
  }

  tearDown(() {
    AppLaunchScope.reset();
    OnboardScope.reset();
    TimelineScope.reset();
    SettingsScope.reset();
  });

  testWidgets('boots through the splash into onboarding on a fresh device',
      (tester) async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    wire();
    await tester.pumpWidget(const KnitApp(config: AppConfig.dev));

    // The splash shows first.
    expect(find.text('Knit'), findsOneWidget);

    // Init → destination resolve → navigation are microtask/animation driven;
    // pump in bounded steps until the onboarding welcome lands.
    for (var i = 0;
        i < 40 && find.text('Get started').evaluate().isEmpty;
        i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.text('Welcome to Knit'), findsOneWidget);
    expect(find.text('Get started'), findsOneWidget);
  });
}
