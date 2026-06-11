import 'package:effect_emitter/effect_emitter.dart';
import 'package:fcis_core/fcis_core.dart';
import 'package:knit/core/logging/logger.dart';
import 'package:knit/features/app_launch/domain/app_destination.dart';
import 'package:knit/features/app_launch/domain/initialization_repository.dart';
import 'package:knit/features/app_launch/presentation/app_launch_action.dart';
import 'package:knit/features/app_launch/presentation/app_launch_effect.dart';
import 'package:knit/features/app_launch/presentation/app_launch_ui_effect.dart';

/// Imperative shell for App Launch (fcis.md §6.6). Brings the graph up via the
/// injected [InitializationRepository], then asks the [AppDestinationResolver]
/// where to go and pushes a navigate UiEffect. The resolver runs here — after
/// init completes — satisfying composition.md §3's ordering MUST without async
/// work in the View.
class AppLaunchShell extends Shell<AppLaunchEffect, AppLaunchAction> {
  AppLaunchShell({
    required InitializationRepository initialization,
    required AppDestinationResolver destinationResolver,
    required EffectEmitter<AppLaunchUiEffect> effectEmitter,
    required Logger logger,
  })  : _initialization = initialization,
        _destinationResolver = destinationResolver,
        _effectEmitter = effectEmitter,
        _logger = logger;

  final InitializationRepository _initialization;
  final AppDestinationResolver _destinationResolver;
  final EffectEmitter<AppLaunchUiEffect> _effectEmitter;
  final Logger _logger;

  @override
  Future<void> run(
    AppLaunchEffect effect, {
    required void Function(AppLaunchAction) dispatch,
  }) async {
    switch (effect) {
      case InitializeEffect():
        try {
          await _initialization.initialize();
          final destination = await _destinationResolver.resolve();
          dispatch(const InitializationSucceeded());
          _effectEmitter.push(AppLaunchNavigateUiEffect(destination));
        } catch (e, st) {
          _logger.error('App initialization failed', e, st);
          dispatch(InitializationFailed(e.toString()));
        }
    }
  }
}
