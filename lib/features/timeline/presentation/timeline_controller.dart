import 'package:effect_emitter/effect_emitter.dart';
import 'package:fcis_core/fcis_core.dart';
import 'package:flutter/foundation.dart';
import 'package:knit/features/timeline/presentation/timeline_action.dart';
import 'package:knit/features/timeline/presentation/timeline_channel_binder.dart';
import 'package:knit/features/timeline/presentation/timeline_state.dart';
import 'package:knit/features/timeline/presentation/timeline_ui_effect.dart';

/// Thin controller (fcis.md §6.8). Beyond the UI effect seam, it owns the
/// [TimelineChannelBinder] (cross_feature.md §3): the input channel is bound
/// while the view is attached, so events other features emit become Timeline
/// Actions only as long as the screen is alive.
class TimelineController {
  TimelineController({
    required this.stateHolder,
    required EffectEmitter<TimelineUiEffect> effectEmitter,
    required ActionSink<TimelineAction> sink,
    required TimelineChannelBinder channelBinder,
  })  : _effectEmitter = effectEmitter,
        _sink = sink,
        _channelBinder = channelBinder;

  final ValueListenable<TimelineState> stateHolder;
  final EffectEmitter<TimelineUiEffect> _effectEmitter;
  final ActionSink<TimelineAction> _sink;
  final TimelineChannelBinder _channelBinder;

  void onAttach(EffectPusher<TimelineUiEffect> pusher) {
    _effectEmitter.attach(pusher);
    _channelBinder.bind();
  }

  void onDetach() {
    _channelBinder.unbind();
    _effectEmitter.detach();
  }

  void dispatch(TimelineAction action) => _sink.dispatch(action);
}
