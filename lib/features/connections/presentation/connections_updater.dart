import 'package:fcis_core/fcis_core.dart';
import 'package:knit/features/connections/domain/connections_models.dart';
import 'package:knit/features/connections/presentation/connections_action.dart';
import 'package:knit/features/connections/presentation/connections_effect.dart';
import 'package:knit/features/connections/presentation/connections_state.dart';

/// Pure reducer for the Connections view (fcis.md §6.1). Owns the §4.4
/// breadcrumb back-stack: a jump pushes the far endpoint as a new crumb, a crumb
/// tap (or a back) truncates the stack, and each move re-loads the focus. The
/// loaded payload refines the current crumb's title to the entity's real label.
/// A collection focus then loads its "Mentioned in" list (§8.6.5) as a second
/// step; a Link takes the row out at once and re-reads, so it reappears as a
/// backlink.
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
            clearMentions: true,
          ),
          [LoadConnectionsEffect(kind: kind, id: id)],
        );

      case ReloadRequested():
        if (state.breadcrumb.isEmpty) return (state, null);
        final focus = state.breadcrumb.last;
        return (state, [LoadConnectionsEffect(kind: focus.kind, id: focus.id)]);

      case ConnectionsLoaded(:final data):
        final isCollection = data.focusKind == ConnectedEntityKind.collection;
        return (
          ConnectionsState(
            status: ConnectionsStatus.ready,
            breadcrumb: _retitleLast(state.breadcrumb, data.focusTitle),
            data: data,
            // A reload of the same focus keeps its rows until the fresh ones.
            mentions: state.data?.focusId == data.focusId
                ? state.mentions
                : null,
          ),
          isCollection
              ? [
                  LoadMentionsEffect(
                    collectionId: data.focusId,
                    title: data.focusTitle,
                  ),
                ]
              : null,
        );

      case MentionsLoaded(:final collectionId, :final mentions):
        if (_focusCollectionId(state) != collectionId) return (state, null);
        return (state.copyWith(mentions: mentions), null);

      case LinkMentionRequested(:final cardId):
        final collectionId = _focusCollectionId(state);
        final mentions = state.mentions;
        if (collectionId == null || mentions == null) return (state, null);
        return (
          state.copyWith(mentions: mentions.without(cardId)),
          [LinkMentionEffect(cardId: cardId, collectionId: collectionId)],
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
            clearMentions: true,
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
      state.copyWith(
        status: ConnectionsStatus.loading,
        breadcrumb: trimmed,
        clearMentions: true,
      ),
      [LoadConnectionsEffect(kind: focus.kind, id: focus.id)],
    );
  }

  /// The focused collection's id, or null when the focus is not a collection.
  static String? _focusCollectionId(ConnectionsState state) {
    if (state.breadcrumb.isEmpty) return null;
    final focus = state.breadcrumb.last;
    return focus.kind == ConnectedEntityKind.collection ? focus.id : null;
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
