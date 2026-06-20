import 'package:knit/app/app_graph.dart';
import 'package:knit/features/connections/domain/connections_failure.dart';
import 'package:knit/features/connections/domain/connections_models.dart';
import 'package:knit/features/connections/domain/connections_read_repository.dart';
import 'package:knit/sync/sync.dart';
import 'package:result_dart/result_dart.dart';

/// [ConnectionsReadRepository] over the graph's [SyncStore]: links-out via
/// [SyncStore.linksOut] (§4.4) and backlinks via [SyncStore.backlinks]
/// (§8.6.2). Each far endpoint's liveness is the canonical §8.6.1 derivation —
/// [SyncStore.linkStatus] (the [BrokenLinkResolver]) — so the broken-or-not
/// rule lives in one place, not re-implemented here. The far endpoint's label
/// is read from the projection only when it is live.
class SyncStoreConnectionsReadRepository implements ConnectionsReadRepository {
  SyncStoreConnectionsReadRepository({required AppGraph graph}) : _graph = graph;

  final AppGraph _graph;

  @override
  Future<Result<ConnectionsData, ConnectionsFailure>> loadConnections(
    ConnectedEntityKind kind,
    String id,
  ) async {
    try {
      final store = _graph.store;
      final focus = await store.get(_entityType(kind), id);
      if (focus == null || focus.deleted) {
        return const Failure(ConnectionsLoadFailure('entity not found'));
      }

      final outgoing = <ConnectionItem>[];
      for (final link in await store.linksOut(id)) {
        outgoing.add(
          await _item(
            store,
            link,
            direction: ConnectionDirection.outgoing,
          ),
        );
      }

      final incoming = <ConnectionItem>[];
      for (final link in await store.backlinks(id)) {
        incoming.add(
          await _item(
            store,
            link,
            direction: ConnectionDirection.incoming,
          ),
        );
      }

      return Ok(
        ConnectionsData(
          focusKind: kind,
          focusId: id,
          focusTitle: _label(focus),
          outgoing: outgoing,
          incoming: incoming,
        ),
      );
    } catch (e, st) {
      return Failure(ConnectionsLoadFailure(e, st));
    }
  }

  /// Build one connection. The *far* endpoint is the target for an outgoing link
  /// and the source for a backlink (§8.6.2); its brokenness comes from the
  /// resolver and its label from the projection (only when live).
  Future<ConnectionItem> _item(
    SyncStore store,
    Snapshot link, {
    required ConnectionDirection direction,
  }) async {
    final status = await store.linkStatus(link);
    final outgoing = direction == ConnectionDirection.outgoing;
    final otherKind = ConnectedEntityKind.fromTag(
      link.content[outgoing ? 'target_type' : 'source_type'] as String?,
    );
    final otherId =
        link.content[outgoing ? 'target_id' : 'source_id'] as String;
    final broken = outgoing ? status.targetBroken : status.sourceBroken;

    final other = broken ? null : await store.get(_entityType(otherKind), otherId);
    return ConnectionItem(
      linkId: link.id,
      direction: direction,
      otherKind: otherKind,
      otherId: otherId,
      broken: broken,
      label: other == null ? null : _label(other),
      openCollectionId: other == null ? null : _openCollectionId(otherKind, other),
    );
  }

  /// The collection to open so [other] can be seen inside it (§4.2): a collection
  /// endpoint opens itself; a card endpoint opens the collection that holds it
  /// (its `collection_id`, §6.4). Null for any other/unknown endpoint kind.
  String? _openCollectionId(ConnectedEntityKind kind, Snapshot other) =>
      switch (kind) {
        ConnectedEntityKind.collection => other.id,
        ConnectedEntityKind.card =>
          other.content[CardSchema.colCollectionId] as String?,
        ConnectedEntityKind.unknown => null,
      };

  /// Display label for an endpoint snapshot: a collection's title, or a card's
  /// text preview (falling back to a kind-based summary).
  String _label(Snapshot s) {
    switch (s.type) {
      case EntityType.collection:
        final title = (s.content['title'] as String?)?.trim();
        return title == null || title.isEmpty ? 'Untitled' : title;
      case EntityType.card:
        final text = (s.content['text'] as String?)?.trim();
        if (text != null && text.isNotEmpty) return text;
        return switch (s.content['kind'] as String?) {
          'image' => 'Photo',
          'audio' => 'Audio',
          'link' => 'Link',
          _ => 'Empty note',
        };
      case EntityType.link:
      case EntityType.profile:
      case EntityType.attachment:
        return s.id;
    }
  }

  EntityType _entityType(ConnectedEntityKind kind) => switch (kind) {
        ConnectedEntityKind.collection => EntityType.collection,
        ConnectedEntityKind.card => EntityType.card,
        // An unknown endpoint kind can't be located; the resolver already
        // marked it broken, so the table queried here is never actually read.
        ConnectedEntityKind.unknown => EntityType.collection,
      };
}
