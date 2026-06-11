import 'package:effect_emitter/effect_emitter.dart';
import 'package:fcis_core/fcis_core.dart';
import 'package:flutter/foundation.dart';
import 'package:knit/features/timeline/presentation/timeline_action.dart';
import 'package:knit/features/timeline/presentation/timeline_state.dart';
import 'package:knit/features/timeline/presentation/timeline_ui_effect.dart';

/// Thin controller (fcis.md §6.8).
class TimelineController {
  TimelineController({
    required this.stateHolder,
    required EffectEmitter<TimelineUiEffect> effectEmitter,
    required ActionSink<TimelineAction> sink,
  })  : _effectEmitter = effectEmitter,
        _sink = sink;

  final ValueListenable<TimelineState> stateHolder;
  final EffectEmitter<TimelineUiEffect> _effectEmitter;
  final ActionSink<TimelineAction> _sink;

  void onAttach(EffectPusher<TimelineUiEffect> pusher) =>
      _effectEmitter.attach(pusher);

  void onDetach() => _effectEmitter.detach();

  void dispatch(TimelineAction action) => _sink.dispatch(action);
}
