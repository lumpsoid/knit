import 'package:effect_emitter/effect_emitter.dart';
import 'package:fcis_core/fcis_core.dart';
import 'package:logging/logging.dart';
import 'package:knit/core/fcis_flutter/fcis_flutter.dart';
import 'package:knit/features/connections/domain/connections_read_repository.dart';
import 'package:knit/features/connections/domain/connections_write_repository.dart';
import 'package:knit/features/connections/presentation/connections_action.dart';
import 'package:knit/features/connections/presentation/connections_controller.dart';
import 'package:knit/features/connections/presentation/connections_effect.dart';
import 'package:knit/features/connections/presentation/connections_loop.dart';
import 'package:knit/features/connections/presentation/connections_shell.dart';
import 'package:knit/features/connections/presentation/connections_state.dart';
import 'package:knit/features/connections/presentation/connections_ui_effect.dart';
import 'package:knit/features/connections/presentation/connections_updater.dart';

/// Composition root for the Connections view (fcis.md §6.8): wires
/// stateHolder → effectEmitter → shell → loop → controller.
class ConnectionsModule {
  ConnectionsModule({
    required ConnectionsReadRepository readRepository,
    required ConnectionsWriteRepository writeRepository,
    Logger? logger,
  }) {
    final stateHolder =
        ValueListenableStateHolder<ConnectionsState>(const ConnectionsState());
    final effectEmitter = EffectEmitter<ConnectionsUiEffect>();
    final shell = ConnectionsShell(
      readRepository: readRepository,
      writeRepository: writeRepository,
      effectEmitter: effectEmitter,
      logger: logger ?? Logger('knit.connections'),
    );
    final loop = ConnectionsLoop(
      stateHolder: stateHolder,
      updater: const ConnectionsUpdater(),
      effectRunner:
          ShellEffectRunner<ConnectionsEffect, ConnectionsAction>(shell: shell),
    );
    _controller = ConnectionsController(
      stateHolder: stateHolder,
      effectEmitter: effectEmitter,
      sink: loop,
    );
  }

  late final ConnectionsController _controller;

  ConnectionsController get controller => _controller;
}
