import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:knit/app/app_config.dart';
import 'package:knit/app/app_graph.dart';
import 'package:knit/app/composition.dart';
import 'package:knit/core/attachments/attachments.dart';
import 'package:knit/core/ids/uuid_id_generator.dart';
import 'package:knit/features/app_launch/presentation/app_launch_module.dart';
import 'package:knit/features/app_launch/presentation/app_launch_page.dart';
import 'package:knit/features/app_launch/presentation/app_launch_scope.dart';
import 'package:knit/features/card_edit/infra/sync_store_card_edit_links_read_repository.dart';
import 'package:knit/features/card_edit/infra/sync_store_card_edit_links_write_repository.dart';
import 'package:knit/features/card_edit/infra/sync_store_card_edit_targets_read_repository.dart';
import 'package:knit/features/card_edit/infra/sync_store_card_edit_write_repository.dart';
import 'package:knit/features/card_edit/presentation/card_edit_module.dart';
import 'package:knit/features/card_edit/presentation/card_edit_route_args.dart';
import 'package:knit/features/card_edit/presentation/card_edit_scope.dart';
import 'package:knit/features/collection/infra/sync_store_collection_read_repository.dart';
import 'package:knit/features/collection/infra/sync_store_collection_write_repository.dart';
import 'package:knit/features/collection/presentation/collection_module.dart';
import 'package:knit/features/collection/presentation/collection_route_args.dart';
import 'package:knit/features/collection/presentation/collection_scope.dart';
import 'package:knit/features/connections/infra/sync_store_connections_read_repository.dart';
import 'package:knit/features/connections/infra/sync_store_connections_write_repository.dart';
import 'package:knit/features/connections/presentation/connections_module.dart';
import 'package:knit/features/connections/presentation/connections_route_args.dart';
import 'package:knit/features/connections/presentation/connections_scope.dart';
import 'package:knit/features/onboard/infra/sync_store_onboard_repository.dart';
import 'package:knit/features/onboard/presentation/onboard_module.dart';
import 'package:knit/features/onboard/presentation/onboard_scope.dart';
import 'package:knit/features/sync_status/infra/sync_store_sync_status_read_repository.dart';
import 'package:knit/features/sync_status/presentation/sync_status_module.dart';
import 'package:knit/features/sync_status/presentation/sync_status_scope.dart';
import 'package:knit/features/timeline/infra/sync_store_timeline_repository.dart';
import 'package:knit/features/timeline/infra/sync_store_timeline_write_repository.dart';
import 'package:knit/features/timeline/presentation/timeline_module.dart';
import 'package:knit/features/timeline/presentation/timeline_scope.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Composition routes the single package:logging stream: every layer logs to
  // a named Logger; here we drain Logger.root.onRecord into the Flutter/IDE
  // console (via dart:developer). Other consumers can subscribe to react.
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    developer.log(
      record.message,
      name: record.loggerName,
      level: record.level.value,
      time: record.time,
      error: record.error,
      stackTrace: record.stackTrace,
    );
  });

  // composition.md §2 — the immutable graph selector. Dev (in-memory) by
  // default so the app runs on any platform with no SQLite setup; switch to
  // [AppConfig.prod] for the persistent sqflite graph (one DB file per device).
  const config = AppConfig.dev;
  final graph = AppGraph();

  // App Launch hosts the only eagerly-built controller: it drives init, then
  // resolves where to go (composition.md §3).
  AppLaunchScope.setController(
    AppLaunchModule(
      initialization: resolveInitializationRepository(config, graph),
      destinationResolver: resolveAppDestinationResolver(config, graph),
    ).controller,
  );

  // Downstream features (fcis.md §6.8 wiring): the Scope factories capture the
  // graph and read its store lazily — only ever after init completes, which the
  // destination resolver guarantees.
  OnboardScope.setFactory(
    () => OnboardModule(
      repository: SyncStoreOnboardRepository(graph: graph),
    ).controller,
  );

  // The app-wide sync marker (§4.8/§6.6): a single lazy controller every
  // content page's app bar shares via SyncStatusScope.
  SyncStatusScope.setFactory(
    () => SyncStatusModule(
      readRepository: SyncStoreSyncStatusReadRepository(graph: graph),
    ).controller,
  );

  // The route-args carrier (cross_feature.md §2): Timeline writes the target
  // collection, the Collection page reads it on entry.
  final routeArgs = InMemoryCollectionRouteArgsStore();
  TimelineScope.setRouteArgsWriter(routeArgs);
  CollectionScope.setRouteArgs(routeArgs);

  // A second carrier for the Connections view (§4.4): the Collection page writes
  // the focused card/collection, the Connections page reads it on entry.
  final connectionsRouteArgs = InMemoryConnectionsRouteArgsStore();
  CollectionScope.setConnectionsRouteArgsWriter(connectionsRouteArgs);
  ConnectionsScope.setRouteArgs(connectionsRouteArgs);

  // A third carrier for the Card Edit page (§4.3): the Collection page writes the
  // card to edit, the Card Edit page reads it on entry.
  final cardEditRouteArgs = InMemoryCardEditRouteArgsStore();
  CollectionScope.setCardEditRouteArgsWriter(cardEditRouteArgs);
  CardEditScope.setRouteArgs(cardEditRouteArgs);

  // Id minting behind the IdGenerator port (spec §6.1).
  const ids = UuidIdGenerator();

  TimelineScope.setFactory(
    () => TimelineModule(
      readRepository: SyncStoreTimelineRepository(graph: graph),
      writeRepository:
          SyncStoreTimelineWriteRepository(graph: graph, ids: ids),
    ).controller,
  );
  CollectionScope.setFactory(
    () => CollectionModule(
      readRepository: SyncStoreCollectionReadRepository(graph: graph),
      writeRepository:
          SyncStoreCollectionWriteRepository(graph: graph, ids: ids),
      attachmentReadRepository:
          SyncStoreAttachmentReadRepository(graph: graph),
    ).controller,
  );
  ConnectionsScope.setFactory(
    () => ConnectionsModule(
      readRepository: SyncStoreConnectionsReadRepository(graph: graph),
      writeRepository: SyncStoreConnectionsWriteRepository(graph: graph),
    ).controller,
  );
  CardEditScope.setFactory(
    () => CardEditModule(
      writeRepository: SyncStoreCardEditWriteRepository(graph: graph),
      linksReadRepository:
          SyncStoreCardEditLinksReadRepository(graph: graph),
      linksWriteRepository:
          SyncStoreCardEditLinksWriteRepository(graph: graph, ids: ids),
      targetsReadRepository:
          SyncStoreCardEditTargetsReadRepository(graph: graph),
      attachmentReadRepository:
          SyncStoreAttachmentReadRepository(graph: graph),
      attachmentWriteRepository:
          SyncStoreAttachmentWriteRepository(graph: graph, ids: ids),
      imagePicker: ImagePickerAdapter(),
    ).controller,
  );

  runApp(const KnitApp());
}

class KnitApp extends StatelessWidget {
  const KnitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Knit',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF5B6CFF)),
        useMaterial3: true,
      ),
      home: const AppLaunchPage(),
    );
  }
}
