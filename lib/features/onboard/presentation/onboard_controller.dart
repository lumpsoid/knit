import 'package:effect_emitter/effect_emitter.dart';
import 'package:fcis_core/fcis_core.dart';
import 'package:flutter/foundation.dart';
import 'package:knit/features/onboard/presentation/onboard_action.dart';
import 'package:knit/features/onboard/presentation/onboard_state.dart';
import 'package:knit/features/onboard/presentation/onboard_ui_effect.dart';

/// Thin controller (fcis.md §6.8). Public [stateHolder] for the View; attaches
/// the [EffectEmitter]; delegates [dispatch] to the loop.
class OnboardController {
  OnboardController({
    required this.stateHolder,
    required EffectEmitter<OnboardUiEffect> effectEmitter,
    required ActionSink<OnboardAction> sink,
  })  : _effectEmitter = effectEmitter,
        _sink = sink;

  final ValueListenable<OnboardState> stateHolder;
  final EffectEmitter<OnboardUiEffect> _effectEmitter;
  final ActionSink<OnboardAction> _sink;

  void onAttach(EffectPusher<OnboardUiEffect> pusher) =>
      _effectEmitter.attach(pusher);

  void onDetach() => _effectEmitter.detach();

  void dispatch(OnboardAction action) => _sink.dispatch(action);
}
