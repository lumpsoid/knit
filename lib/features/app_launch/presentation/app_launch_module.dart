import 'package:effect_emitter/effect_emitter.dart';
import 'package:fcis_core/fcis_core.dart';
import 'package:logging/logging.dart';
import 'package:knit/core/fcis_flutter/fcis_flutter.dart';
import 'package:knit/features/app_launch/domain/app_destination.dart';
import 'package:knit/features/app_launch/domain/initialization_repository.dart';
import 'package:knit/features/app_launch/presentation/app_launch_action.dart';
import 'package:knit/features/app_launch/presentation/app_launch_controller.dart';
import 'package:knit/features/app_launch/presentation/app_launch_effect.dart';
import 'package:knit/features/app_launch/presentation/app_launch_loop.dart';
import 'package:knit/features/app_launch/presentation/app_launch_shell.dart';
import 'package:knit/features/app_launch/presentation/app_launch_state.dart';
import 'package:knit/features/app_launch/presentation/app_launch_ui_effect.dart';
import 'package:knit/features/app_launch/presentation/app_launch_updater.dart';

/// Composition root for the App Launch feature (fcis.md §6.8): wires
/// stateHolder → effectEmitter → shell → loop(sink) → controller from the
/// injected init + destination-resolver deps; exposes `.controller`.
class AppLaunchModule {
  AppLaunchModule({
    required InitializationRepository initialization,
    required AppDestinationResolver destinationResolver,
    Logger? logger,
  }) {
    final stateHolder = ValueListenableStateHolder<AppLaunchState>(
      const AppLaunchState(),
    );
    final effectEmitter = EffectEmitter<AppLaunchUiEffect>();
    final shell = AppLaunchShell(
      initialization: initialization,
      destinationResolver: destinationResolver,
      effectEmitter: effectEmitter,
      logger: logger ?? Logger('knit.app_launch'),
    );
    final loop = AppLaunchLoop(
      stateHolder: stateHolder,
      updater: const AppLaunchUpdater(),
      effectRunner: ShellEffectRunner<AppLaunchEffect, AppLaunchAction>(
        shell: shell,
      ),
    );
    _controller = AppLaunchController(
      stateHolder: stateHolder,
      effectEmitter: effectEmitter,
      sink: loop,
    );
  }

  late final AppLaunchController _controller;

  AppLaunchController get controller => _controller;
}
