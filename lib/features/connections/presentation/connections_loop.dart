import 'package:fcis_core/fcis_core.dart';
import 'package:knit/features/connections/presentation/connections_action.dart';
import 'package:knit/features/connections/presentation/connections_effect.dart';
import 'package:knit/features/connections/presentation/connections_state.dart';

/// The Connections FCIS loop (fcis.md §6.8) — super-params only, no logic.
class ConnectionsLoop
    extends FcisLoop<ConnectionsState, ConnectionsAction, ConnectionsEffect> {
  ConnectionsLoop({
    required super.stateHolder,
    required super.updater,
    required super.effectRunner,
  });
}
