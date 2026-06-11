/// Route-args carrier for the Connections view (cross_feature.md §2). An origin
/// screen (the Collection page) writes the focused entity *before* navigating;
/// the Connections page reads it on entry and dispatches [ViewAttached].
/// Navigation itself carries no payload — the carrier is the payload — so
/// neither feature couples to the navigation system for its input.
library;

import 'package:knit/features/connections/domain/connections_models.dart';

/// Read side — what the Connections page consumes on entry.
abstract interface class ConnectionsRouteArgs {
  /// The kind of the entity to focus on entry.
  ConnectedEntityKind get entityKind;

  /// The id of the entity to focus. Empty before any origin has written one.
  String get entityId;

  /// A display title to seed the root breadcrumb (refined once loaded).
  String get entityTitle;
}

/// Write side — what an origin screen (Collection) sets before navigating.
abstract interface class ConnectionsRouteArgsWriter {
  void open({
    required ConnectedEntityKind kind,
    required String id,
    required String title,
  });
}

/// The store implements both halves.
abstract interface class ConnectionsRouteArgsStore
    implements ConnectionsRouteArgs, ConnectionsRouteArgsWriter {}

/// Plain in-memory carrier — a single most-recent target. The destination reads
/// it synchronously on entry, so no persistence is needed.
class InMemoryConnectionsRouteArgsStore implements ConnectionsRouteArgsStore {
  ConnectedEntityKind _entityKind = ConnectedEntityKind.collection;
  String _entityId = '';
  String _entityTitle = '';

  @override
  ConnectedEntityKind get entityKind => _entityKind;

  @override
  String get entityId => _entityId;

  @override
  String get entityTitle => _entityTitle;

  @override
  void open({
    required ConnectedEntityKind kind,
    required String id,
    required String title,
  }) {
    _entityKind = kind;
    _entityId = id;
    _entityTitle = title;
  }
}
