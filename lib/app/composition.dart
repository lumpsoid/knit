import 'package:knit/app/app_config.dart';
import 'package:knit/app/app_graph.dart';
import 'package:knit/features/app_launch/domain/app_destination.dart';
import 'package:knit/features/app_launch/domain/initialization_repository.dart';
import 'package:knit/features/app_launch/infra/in_memory_initialization_repository.dart';
import 'package:knit/features/app_launch/infra/production_initialization_repository.dart';
import 'package:knit/features/app_launch/infra/profile_destination_resolver.dart';

/// Dependency-graph resolvers (composition.md §2): pure functions of [AppConfig]
/// that pick concrete implementations. They read no globals and do no I/O — the
/// I/O happens inside the resolved object's own methods.

InitializationRepository resolveInitializationRepository(
  AppConfig config,
  AppGraph graph,
) => switch (config.environment) {
  AppEnvironment.prod => ProductionInitializationRepository(graph: graph),
  AppEnvironment.dev => InMemoryInitializationRepository(graph: graph),
};

AppDestinationResolver resolveAppDestinationResolver(
  AppConfig config,
  AppGraph graph,
) => ProfileAppDestinationResolver(graph: graph);
