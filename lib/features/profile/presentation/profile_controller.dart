import 'package:effect_emitter/effect_emitter.dart';
import 'package:fcis_core/fcis_core.dart';
import 'package:flutter/foundation.dart';
import 'package:knit/features/profile/presentation/profile_action.dart';
import 'package:knit/features/profile/presentation/profile_state.dart';
import 'package:knit/features/profile/presentation/profile_ui_effect.dart';

/// Thin controller (fcis.md §6.8). Public [stateHolder] for the View; attaches
/// the [EffectEmitter] for one-shot messages; delegates [dispatch] to the loop.
class ProfileController {
  ProfileController({
    required this.stateHolder,
    required EffectEmitter<ProfileUiEffect> effectEmitter,
    required ActionSink<ProfileAction> sink,
  }) : _effectEmitter = effectEmitter,
       _sink = sink;

  final ValueListenable<ProfileState> stateHolder;
  final EffectEmitter<ProfileUiEffect> _effectEmitter;
  final ActionSink<ProfileAction> _sink;

  void onAttach(EffectPusher<ProfileUiEffect> pusher) =>
      _effectEmitter.attach(pusher);

  void onDetach() => _effectEmitter.detach();

  void dispatch(ProfileAction action) => _sink.dispatch(action);
}
