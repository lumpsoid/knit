import 'package:effect_emitter/effect_emitter.dart';
import 'package:fcis_core/fcis_core.dart';
import 'package:logging/logging.dart';
import 'package:knit/features/onboard/domain/onboard_repository.dart';
import 'package:knit/features/onboard/presentation/onboard_action.dart';
import 'package:knit/features/onboard/presentation/onboard_effect.dart';
import 'package:knit/features/onboard/presentation/onboard_ui_effect.dart';

/// Imperative shell for Onboard (fcis.md §6.6). Unwraps the [OnboardRepository]
/// Result at the seam (result.md §9.3) — dispatching a success or failure
/// Action, never propagating the Result into the updater — and pushes the
/// enter-app UiEffect.
class OnboardShell extends Shell<OnboardEffect, OnboardAction> {
  OnboardShell({
    required OnboardRepository repository,
    required EffectEmitter<OnboardUiEffect> effectEmitter,
    required Logger logger,
  })  : _repository = repository,
        _effectEmitter = effectEmitter,
        _log = logger;

  final OnboardRepository _repository;
  final EffectEmitter<OnboardUiEffect> _effectEmitter;
  final Logger _log;

  @override
  Future<void> run(
    OnboardEffect effect, {
    required void Function(OnboardAction) dispatch,
  }) async {
    switch (effect) {
      case CreateIdentityEffect(:final nickname):
        final result = await _repository.createIdentity(nickname);
        result.onTap(
          (card) => dispatch(IdentityCreated(card)),
          (failure) {
            _log.severe(
                'Identity creation failed', failure.error, failure.stackTrace);
            dispatch(const IdentityCreationFailed());
          },
        );
      case EnterAppEffect():
        _effectEmitter.push(const OnboardEnterAppUiEffect());
    }
  }
}
