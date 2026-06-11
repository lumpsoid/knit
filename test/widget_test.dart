import 'package:flutter_test/flutter_test.dart';
import 'package:knit/app/app_config.dart';
import 'package:knit/app/app_graph.dart';
import 'package:knit/app/composition.dart';
import 'package:knit/features/app_launch/presentation/app_launch_module.dart';
import 'package:knit/features/app_launch/presentation/app_launch_scope.dart';
import 'package:knit/features/onboard/infra/sync_store_onboard_repository.dart';
import 'package:knit/features/onboard/presentation/onboard_module.dart';
import 'package:knit/features/onboard/presentation/onboard_scope.dart';
import 'package:knit/core/ids/uuid_id_generator.dart';
import 'package:knit/features/collection/presentation/collection_route_args.dart';
import 'package:knit/features/timeline/infra/sync_store_timeline_repository.dart';
import 'package:knit/features/timeline/infra/sync_store_timeline_write_repository.dart';
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
      ).controller,
    );
  }

  tearDown(() {
    AppLaunchScope.reset();
    OnboardScope.reset();
    TimelineScope.reset();
  });

  testWidgets('boots through the splash into onboarding on a fresh device',
      (tester) async {
    wire();
    await tester.pumpWidget(const KnitApp());

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
