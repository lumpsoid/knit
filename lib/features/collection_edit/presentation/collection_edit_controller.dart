import 'package:effect_emitter/effect_emitter.dart';
import 'package:fcis_core/fcis_core.dart';
import 'package:flutter/foundation.dart';
import 'package:knit/features/collection_edit/presentation/collection_edit_action.dart';
import 'package:knit/features/collection_edit/presentation/collection_edit_state.dart';
import 'package:knit/features/collection_edit/presentation/collection_edit_ui_effect.dart';

/// Thin controller for the Collection Edit page (fcis.md §6.8).
class CollectionEditController {
  CollectionEditController({
    required this.stateHolder,
    required EffectEmitter<CollectionEditUiEffect> effectEmitter,
    required ActionSink<CollectionEditAction> sink,
  }) : _effectEmitter = effectEmitter,
       _sink = sink;

  final ValueListenable<CollectionEditState> stateHolder;
  final EffectEmitter<CollectionEditUiEffect> _effectEmitter;
  final ActionSink<CollectionEditAction> _sink;

  void onAttach(EffectPusher<CollectionEditUiEffect> pusher) =>
      _effectEmitter.attach(pusher);

  void onDetach() => _effectEmitter.detach();

  void dispatch(CollectionEditAction action) => _sink.dispatch(action);
}
