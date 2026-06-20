import 'package:effect_emitter/effect_emitter.dart';
import 'package:fcis_core/fcis_core.dart';
import 'package:flutter/foundation.dart';
import 'package:knit/features/connections/presentation/connections_action.dart';
import 'package:knit/features/connections/presentation/connections_state.dart';
import 'package:knit/features/connections/presentation/connections_ui_effect.dart';

/// Thin controller for the Connections view (fcis.md §6.8). Owned by the page
/// (one controller per page instance), so it tears down the state-holder
/// notifier and detaches the effect seam in [dispose] when the page leaves.
class ConnectionsController {
  ConnectionsController({
    required this.stateHolder,
    required EffectEmitter<ConnectionsUiEffect> effectEmitter,
    required ActionSink<ConnectionsAction> sink,
    required VoidCallback onDispose,
  })  : _effectEmitter = effectEmitter,
        _sink = sink,
        _onDispose = onDispose;

  final ValueListenable<ConnectionsState> stateHolder;
  final EffectEmitter<ConnectionsUiEffect> _effectEmitter;
  final ActionSink<ConnectionsAction> _sink;
  final VoidCallback _onDispose;

  void onAttach(EffectPusher<ConnectionsUiEffect> pusher) =>
      _effectEmitter.attach(pusher);

  void onDetach() => _effectEmitter.detach();

  void dispatch(ConnectionsAction action) => _sink.dispatch(action);

  /// Release the page-owned resources: detach the effect seam and dispose the
  /// state-holder notifier (the [VoidCallback] the module wires to it).
  void dispose() {
    _effectEmitter.detach();
    _onDispose();
  }
}
