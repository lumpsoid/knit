import 'package:effect_emitter/effect_emitter.dart';
import 'package:fcis_core/fcis_core.dart';
import 'package:flutter/foundation.dart';
import 'package:knit/features/app_launch/presentation/app_launch_action.dart';
import 'package:knit/features/app_launch/presentation/app_launch_state.dart';
import 'package:knit/features/app_launch/presentation/app_launch_ui_effect.dart';

/// Thin controller (fcis.md §6.8). Holds the public [stateHolder] for the View
/// to bind, attaches/detaches the [EffectEmitter], and delegates [dispatch] to
/// the loop's [ActionSink].
class AppLaunchController {
  AppLaunchController({
    required this.stateHolder,
    required EffectEmitter<AppLaunchUiEffect> effectEmitter,
    required ActionSink<AppLaunchAction> sink,
  })  : _effectEmitter = effectEmitter,
        _sink = sink;

  /// Read-only state for `ValueListenableBuilder`.
  final ValueListenable<AppLaunchState> stateHolder;
  final EffectEmitter<AppLaunchUiEffect> _effectEmitter;
  final ActionSink<AppLaunchAction> _sink;

  void onAttach(EffectPusher<AppLaunchUiEffect> pusher) =>
      _effectEmitter.attach(pusher);

  void onDetach() => _effectEmitter.detach();

  void dispatch(AppLaunchAction action) => _sink.dispatch(action);
}
