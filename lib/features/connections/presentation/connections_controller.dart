import 'package:effect_emitter/effect_emitter.dart';
import 'package:fcis_core/fcis_core.dart';
import 'package:flutter/foundation.dart';
import 'package:knit/features/connections/presentation/connections_action.dart';
import 'package:knit/features/connections/presentation/connections_state.dart';
import 'package:knit/features/connections/presentation/connections_ui_effect.dart';

/// Thin controller for the Connections view (fcis.md §6.8).
class ConnectionsController {
  ConnectionsController({
    required this.stateHolder,
    required EffectEmitter<ConnectionsUiEffect> effectEmitter,
    required ActionSink<ConnectionsAction> sink,
  })  : _effectEmitter = effectEmitter,
        _sink = sink;

  final ValueListenable<ConnectionsState> stateHolder;
  final EffectEmitter<ConnectionsUiEffect> _effectEmitter;
  final ActionSink<ConnectionsAction> _sink;

  void onAttach(EffectPusher<ConnectionsUiEffect> pusher) =>
      _effectEmitter.attach(pusher);

  void onDetach() => _effectEmitter.detach();

  void dispatch(ConnectionsAction action) => _sink.dispatch(action);
}
