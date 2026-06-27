import 'package:effect_emitter/effect_emitter.dart';
import 'package:fcis_core/fcis_core.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:knit/core/fcis_flutter/fcis_flutter.dart';
import 'package:knit/features/connections/domain/connections_read_repository.dart';
import 'package:knit/features/connections/domain/connections_write_repository.dart';
import 'package:knit/features/connections/presentation/connections_action.dart';
import 'package:knit/features/connections/presentation/connections_effect.dart';
import 'package:knit/features/connections/presentation/connections_loop.dart';
import 'package:knit/features/connections/presentation/connections_shell.dart';
import 'package:knit/features/connections/presentation/connections_state.dart';
import 'package:knit/features/connections/presentation/connections_ui_effect.dart';
import 'package:knit/features/connections/presentation/connections_updater.dart';

/// The per-page composition root *and* thin handle for the Connections view
/// (fcis.md §6.8). One controller per page instance (Connections pages stack
/// behind a breadcrumb back-stack and must not share state), so the controller
/// **creates** the page-scoped resources it later disposes: it wires
/// stateHolder → effectEmitter → shell → loop in its constructor, then in
/// [dispose] detaches the effect seam and disposes the state-holder notifier it
/// made — creator and disposer are the same object.
class ConnectionsController {
  ConnectionsController({
    required ConnectionsReadRepository readRepository,
    required ConnectionsWriteRepository writeRepository,
    Logger? logger,
  }) {
    final stateHolder = ValueListenableStateHolder<ConnectionsState>(
      const ConnectionsState(),
    );
    final effectEmitter = EffectEmitter<ConnectionsUiEffect>();
    final shell = ConnectionsShell(
      readRepository: readRepository,
      writeRepository: writeRepository,
      effectEmitter: effectEmitter,
      logger: logger ?? Logger('knit.connections'),
    );
    _stateHolder = stateHolder;
    _effectEmitter = effectEmitter;
    _sink = ConnectionsLoop(
      stateHolder: stateHolder,
      updater: const ConnectionsUpdater(),
      effectRunner: ShellEffectRunner<ConnectionsEffect, ConnectionsAction>(
        shell: shell,
      ),
    );
  }

  late final ValueListenableStateHolder<ConnectionsState> _stateHolder;
  late final EffectEmitter<ConnectionsUiEffect> _effectEmitter;
  late final ActionSink<ConnectionsAction> _sink;

  ValueListenable<ConnectionsState> get stateHolder => _stateHolder;

  void onAttach(EffectPusher<ConnectionsUiEffect> pusher) =>
      _effectEmitter.attach(pusher);

  void onDetach() => _effectEmitter.detach();

  void dispatch(ConnectionsAction action) => _sink.dispatch(action);

  /// Release the page-scoped resources this controller created: detach the
  /// effect seam and dispose the state-holder notifier.
  void dispose() {
    _effectEmitter.detach();
    _stateHolder.dispose();
  }
}
