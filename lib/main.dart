import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:knit/app/app_config.dart';
import 'package:knit/app/app_graph.dart';
import 'package:knit/app/composition.dart';
import 'package:knit/core/ids/uuid_id_generator.dart';
import 'package:knit/features/app_launch/presentation/app_launch_module.dart';
import 'package:knit/features/app_launch/presentation/app_launch_page.dart';
import 'package:knit/features/app_launch/presentation/app_launch_scope.dart';
import 'package:knit/features/collection/infra/sync_store_collection_read_repository.dart';
import 'package:knit/features/collection/infra/sync_store_collection_write_repository.dart';
import 'package:knit/features/collection/presentation/collection_module.dart';
import 'package:knit/features/collection/presentation/collection_route_args.dart';
import 'package:knit/features/collection/presentation/collection_scope.dart';
import 'package:knit/features/onboard/infra/sync_store_onboard_repository.dart';
import 'package:knit/features/onboard/presentation/onboard_module.dart';
import 'package:knit/features/onboard/presentation/onboard_scope.dart';
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

  // The route-args carrier (cross_feature.md §2): Timeline writes the target
  // collection, the Collection page reads it on entry.
  final routeArgs = InMemoryCollectionRouteArgsStore();
  TimelineScope.setRouteArgsWriter(routeArgs);
  CollectionScope.setRouteArgs(routeArgs);

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
