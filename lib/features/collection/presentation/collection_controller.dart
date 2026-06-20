import 'package:effect_emitter/effect_emitter.dart';
import 'package:fcis_core/fcis_core.dart';
import 'package:flutter/foundation.dart';
import 'package:knit/features/collection/presentation/collection_action.dart';
import 'package:knit/features/collection/presentation/collection_state.dart';
import 'package:knit/features/collection/presentation/collection_ui_effect.dart';

/// Thin controller for the Collection screen (fcis.md §6.8). Owned by the page
/// (one controller per page instance), so it tears down the state-holder
/// notifier and detaches the effect seam in [dispose] when the page leaves.
class CollectionController {
  CollectionController({
    required this.stateHolder,
    required EffectEmitter<CollectionUiEffect> effectEmitter,
    required ActionSink<CollectionAction> sink,
    required VoidCallback onDispose,
  }) : _effectEmitter = effectEmitter,
       _sink = sink,
       _onDispose = onDispose;

  final ValueListenable<CollectionState> stateHolder;
  final EffectEmitter<CollectionUiEffect> _effectEmitter;
  final ActionSink<CollectionAction> _sink;
  final VoidCallback _onDispose;

  void onAttach(EffectPusher<CollectionUiEffect> pusher) =>
      _effectEmitter.attach(pusher);

  void onDetach() => _effectEmitter.detach();

  void dispatch(CollectionAction action) => _sink.dispatch(action);

  /// Release the page-owned resources: detach the effect seam and dispose the
  /// state-holder notifier (the [VoidCallback] the module wires to it).
  void dispose() {
    _effectEmitter.detach();
    _onDispose();
  }
}
