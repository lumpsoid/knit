import 'package:fcis_core/fcis_core.dart';
import 'package:knit/features/connections/domain/connections_models.dart';
import 'package:knit/features/connections/presentation/connections_action.dart';
import 'package:knit/features/connections/presentation/connections_effect.dart';
import 'package:knit/features/connections/presentation/connections_state.dart';

/// Pure reducer for the Connections view (fcis.md §6.1). Owns the §4.4
/// breadcrumb back-stack: a jump pushes the far endpoint as a new crumb, a crumb
/// tap (or a back) truncates the stack, and each move re-loads the focus. The
/// loaded payload refines the current crumb's title to the entity's real label.
class ConnectionsUpdater
    implements Updater<ConnectionsState, ConnectionsAction, ConnectionsEffect> {
  const ConnectionsUpdater();

  @override
  (ConnectionsState, List<ConnectionsEffect>?) update(
    ConnectionsState state,
    ConnectionsAction action,
  ) {
    switch (action) {
      case ViewAttached(:final kind, :final id, :final title):
        final crumb = ConnectionCrumb(kind: kind, id: id, title: title);
        return (
          state.copyWith(
            status: ConnectionsStatus.loading,
            breadcrumb: [crumb],
          ),
          [LoadConnectionsEffect(kind: kind, id: id)],
        );

      case ReloadRequested():
        if (state.breadcrumb.isEmpty) return (state, null);
        final focus = state.breadcrumb.last;
        return (state, [LoadConnectionsEffect(kind: focus.kind, id: focus.id)]);

      case ConnectionsLoaded(:final data):
        return (
          ConnectionsState(
            status: ConnectionsStatus.ready,
            breadcrumb: _retitleLast(state.breadcrumb, data.focusTitle),
            data: data,
          ),
          null,
        );

      case LoadFailed():
        return (state.copyWith(status: ConnectionsStatus.failed), null);

      case ConnectionTapped(:final item):
        if (item.broken) return (state, null);
        final crumb = ConnectionCrumb(
          kind: item.otherKind,
          id: item.otherId,
          title: item.label ?? '',
        );
        return (
          state.copyWith(
            status: ConnectionsStatus.loading,
            breadcrumb: [...state.breadcrumb, crumb],
          ),
          [LoadConnectionsEffect(kind: item.otherKind, id: item.otherId)],
        );

      case CrumbTapped(:final index):
        return _jumpToCrumb(state, index);

      case BackRequested():
        if (state.atRoot) return (state, null);
        return _jumpToCrumb(state, state.breadcrumb.length - 2);

      case ClearLinkRequested(:final linkId):
        return (state, [ClearLinkEffect(linkId)]);

      case DeactivateFeature():
        return (state, null);
    }
  }

  /// Truncate the back-stack to [index] (inclusive) and re-load that focus.
  /// A no-op when [index] already points at the current focus.
  (ConnectionsState, List<ConnectionsEffect>?) _jumpToCrumb(
    ConnectionsState state,
    int index,
  ) {
    if (index < 0 || index >= state.breadcrumb.length - 1) return (state, null);
    final trimmed = state.breadcrumb.sublist(0, index + 1);
    final focus = trimmed.last;
    return (
      state.copyWith(status: ConnectionsStatus.loading, breadcrumb: trimmed),
      [LoadConnectionsEffect(kind: focus.kind, id: focus.id)],
    );
  }

  /// Replace the last crumb's title with the entity's real label once loaded
  /// (the jump seeded it from the connection's preview, which can be stale).
  static List<ConnectionCrumb> _retitleLast(
    List<ConnectionCrumb> crumbs,
    String title,
  ) {
    if (crumbs.isEmpty || title.trim().isEmpty) return crumbs;
    final last = crumbs.last;
    return [
      ...crumbs.sublist(0, crumbs.length - 1),
      ConnectionCrumb(kind: last.kind, id: last.id, title: title),
    ];
  }
}
