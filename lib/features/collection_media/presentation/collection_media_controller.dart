import 'package:effect_emitter/effect_emitter.dart';
import 'package:fcis_core/fcis_core.dart';
import 'package:flutter/foundation.dart';
import 'package:knit/features/collection_media/presentation/collection_media_action.dart';
import 'package:knit/features/collection_media/presentation/collection_media_state.dart';
import 'package:knit/features/collection_media/presentation/collection_media_ui_effect.dart';

/// Thin controller for the Collection Media page (fcis.md §6.8).
class CollectionMediaController {
  CollectionMediaController({
    required this.stateHolder,
    required EffectEmitter<CollectionMediaUiEffect> effectEmitter,
    required ActionSink<CollectionMediaAction> sink,
  }) : _effectEmitter = effectEmitter,
       _sink = sink;

  final ValueListenable<CollectionMediaState> stateHolder;
  final EffectEmitter<CollectionMediaUiEffect> _effectEmitter;
  final ActionSink<CollectionMediaAction> _sink;

  void onAttach(EffectPusher<CollectionMediaUiEffect> pusher) =>
      _effectEmitter.attach(pusher);

  void onDetach() => _effectEmitter.detach();

  void dispatch(CollectionMediaAction action) => _sink.dispatch(action);
}
