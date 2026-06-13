import 'package:effect_emitter/effect_emitter.dart';
import 'package:fcis_core/fcis_core.dart';
import 'package:logging/logging.dart';
import 'package:result_dart/result_dart.dart';
import 'package:knit/features/connections/domain/connections_read_repository.dart';
import 'package:knit/features/connections/domain/connections_write_repository.dart';
import 'package:knit/features/connections/presentation/connections_action.dart';
import 'package:knit/features/connections/presentation/connections_effect.dart';
import 'package:knit/features/connections/presentation/connections_ui_effect.dart';

/// Imperative shell for the Connections view (fcis.md §6.6). Unwraps each
/// repository [Result] at the seam (result.md §9.3) into a success/failure
/// Action; the updater never sees a Result. Clearing a broken link re-reads the
/// focus (via [ReloadRequested]) so the projection — not an optimistic guess —
/// is the source of truth.
class ConnectionsShell extends Shell<ConnectionsEffect, ConnectionsAction> {
  ConnectionsShell({
    required ConnectionsReadRepository readRepository,
    required ConnectionsWriteRepository writeRepository,
    required EffectEmitter<ConnectionsUiEffect> effectEmitter,
    required Logger logger,
  })  : _read = readRepository,
        _write = writeRepository,
        _effectEmitter = effectEmitter,
        _log = logger;

  final ConnectionsReadRepository _read;
  final ConnectionsWriteRepository _write;
  final EffectEmitter<ConnectionsUiEffect> _effectEmitter;
  final Logger _log;

  @override
  Future<void> run(
    ConnectionsEffect effect, {
    required void Function(ConnectionsAction) dispatch,
  }) async {
    switch (effect) {
      case LoadConnectionsEffect(:final kind, :final id):
        final result = await _read.loadConnections(kind, id);
        result.onTap(
          (data) => dispatch(ConnectionsLoaded(data)),
          (failure) {
            _log.severe(
                'Connections load failed', failure.error, failure.stackTrace);
            dispatch(const LoadFailed());
          },
        );

      case ClearLinkEffect(:final linkId):
        final result = await _write.clearLink(linkId);
        result.onTap(
          (_) => dispatch(const ReloadRequested()),
          (failure) {
            _log.severe('Connections clear-link failed', failure.error,
                failure.stackTrace);
            _effectEmitter.push(
              const ConnectionsShowMessageUiEffect(
                ConnectionsMessage.clearFailed,
              ),
            );
            dispatch(const ReloadRequested());
          },
        );
    }
  }
}
