import 'package:effect_emitter/effect_emitter.dart';
import 'package:fcis_core/fcis_core.dart';
import 'package:logging/logging.dart';
import 'package:knit/core/fcis_flutter/fcis_flutter.dart';
import 'package:knit/features/onboard/domain/onboard_repository.dart';
import 'package:knit/features/onboard/presentation/onboard_action.dart';
import 'package:knit/features/onboard/presentation/onboard_controller.dart';
import 'package:knit/features/onboard/presentation/onboard_effect.dart';
import 'package:knit/features/onboard/presentation/onboard_loop.dart';
import 'package:knit/features/onboard/presentation/onboard_shell.dart';
import 'package:knit/features/onboard/presentation/onboard_state.dart';
import 'package:knit/features/onboard/presentation/onboard_ui_effect.dart';
import 'package:knit/features/onboard/presentation/onboard_updater.dart';

/// Composition root for Onboard (fcis.md §6.8).
class OnboardModule {
  OnboardModule({
    required OnboardRepository repository,
    Logger? logger,
  }) {
    final stateHolder =
        ValueListenableStateHolder<OnboardState>(const OnboardState());
    final effectEmitter = EffectEmitter<OnboardUiEffect>();
    final shell = OnboardShell(
      repository: repository,
      effectEmitter: effectEmitter,
      logger: logger ?? Logger('knit.onboard'),
    );
    final loop = OnboardLoop(
      stateHolder: stateHolder,
      updater: const OnboardUpdater(),
      effectRunner:
          ShellEffectRunner<OnboardEffect, OnboardAction>(shell: shell),
    );
    _controller = OnboardController(
      stateHolder: stateHolder,
      effectEmitter: effectEmitter,
      sink: loop,
    );
  }

  late final OnboardController _controller;

  OnboardController get controller => _controller;
}
