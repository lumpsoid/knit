import 'package:effect_emitter/effect_emitter.dart';
import 'package:fcis_core/fcis_core.dart';
import 'package:flutter/foundation.dart';
import 'package:knit/features/collection/presentation/collection_action.dart';
import 'package:knit/features/collection/presentation/collection_state.dart';
import 'package:knit/features/collection/presentation/collection_ui_effect.dart';

/// Thin controller for the Collection screen (fcis.md §6.8).
class CollectionController {
  CollectionController({
    required this.stateHolder,
    required EffectEmitter<CollectionUiEffect> effectEmitter,
    required ActionSink<CollectionAction> sink,
  })  : _effectEmitter = effectEmitter,
        _sink = sink;

  final ValueListenable<CollectionState> stateHolder;
  final EffectEmitter<CollectionUiEffect> _effectEmitter;
  final ActionSink<CollectionAction> _sink;

  void onAttach(EffectPusher<CollectionUiEffect> pusher) =>
      _effectEmitter.attach(pusher);

  void onDetach() => _effectEmitter.detach();

  void dispatch(CollectionAction action) => _sink.dispatch(action);
}
