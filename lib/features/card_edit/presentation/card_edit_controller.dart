import 'package:effect_emitter/effect_emitter.dart';
import 'package:fcis_core/fcis_core.dart';
import 'package:flutter/foundation.dart';
import 'package:knit/features/card_edit/presentation/card_edit_action.dart';
import 'package:knit/features/card_edit/presentation/card_edit_state.dart';
import 'package:knit/features/card_edit/presentation/card_edit_ui_effect.dart';

/// Thin controller for the Card Edit page (fcis.md §6.8).
class CardEditController {
  CardEditController({
    required this.stateHolder,
    required EffectEmitter<CardEditUiEffect> effectEmitter,
    required ActionSink<CardEditAction> sink,
  })  : _effectEmitter = effectEmitter,
        _sink = sink;

  final ValueListenable<CardEditState> stateHolder;
  final EffectEmitter<CardEditUiEffect> _effectEmitter;
  final ActionSink<CardEditAction> _sink;

  void onAttach(EffectPusher<CardEditUiEffect> pusher) =>
      _effectEmitter.attach(pusher);

  void onDetach() => _effectEmitter.detach();

  void dispatch(CardEditAction action) => _sink.dispatch(action);
}
