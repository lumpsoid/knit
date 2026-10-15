import 'package:flutter_test/flutter_test.dart';
import 'package:knit/features/connections/domain/connections_models.dart';
import 'package:knit/features/connections/presentation/connections_action.dart';
import 'package:knit/features/connections/presentation/connections_effect.dart';
import 'package:knit/features/connections/presentation/connections_state.dart';
import 'package:knit/features/connections/presentation/connections_updater.dart';

void main() {
  const updater = ConnectionsUpdater();

  ConnectionItem item(
    String linkId, {
    required ConnectionDirection direction,
    ConnectedEntityKind otherKind = ConnectedEntityKind.collection,
    String otherId = 'other',
    bool broken = false,
    String? label = 'Other',
  }) => ConnectionItem(
    linkId: linkId,
    direction: direction,
    otherKind: otherKind,
    otherId: otherId,
    broken: broken,
    label: label,
  );

  ConnectionsData data({
    String focusId = 'root',
    String focusTitle = 'Root',
    List<ConnectionItem> outgoing = const [],
    List<ConnectionItem> incoming = const [],
  }) => ConnectionsData(
    focusKind: ConnectedEntityKind.collection,
    focusId: focusId,
    focusTitle: focusTitle,
    outgoing: outgoing,
    incoming: incoming,
  );

  test('ViewAttached seeds the root crumb and loads it', () {
    final (next, effects) = updater.update(
      const ConnectionsState(),
      const ViewAttached(
        kind: ConnectedEntityKind.collection,
        id: 'root',
        title: 'Root',
      ),
    );
    expect(next.status, ConnectionsStatus.loading);
    expect(next.breadcrumb.single.id, 'root');
    expect(next.atRoot, isTrue);
    final effect = effects!.single as LoadConnectionsEffect;
    expect(effect.id, 'root');
    expect(effect.kind, ConnectedEntityKind.collection);
  });

  test('ConnectionsLoaded becomes ready and retitles the current crumb', () {
    const seeded = ConnectionsState(
      status: ConnectionsStatus.loading,
      breadcrumb: [
        ConnectionCrumb(
          kind: ConnectedEntityKind.collection,
          id: 'root',
          title: '',
        ),
      ],
    );
    final (next, effects) = updater.update(
      seeded,
      ConnectionsLoaded(data(focusTitle: 'Recipes')),
    );
    expect(next.status, ConnectionsStatus.ready);
    expect(next.breadcrumb.single.title, 'Recipes');
    expect(effects, isNull);
  });

  test('tapping a live connection pushes a crumb and loads the far end', () {
    const seeded = ConnectionsState(
      status: ConnectionsStatus.ready,
      breadcrumb: [
        ConnectionCrumb(
          kind: ConnectedEntityKind.collection,
          id: 'root',
          title: 'Root',
        ),
      ],
    );
    final tapped = item(
      'l1',
      direction: ConnectionDirection.incoming,
      otherKind: ConnectedEntityKind.card,
      otherId: 'card-1',
      label: 'a card',
    );
    final (next, effects) = updater.update(seeded, ConnectionTapped(tapped));

    expect(next.breadcrumb.map((c) => c.id), ['root', 'card-1']);
    expect(next.breadcrumb.last.title, 'a card');
    expect(next.atRoot, isFalse);
    final effect = effects!.single as LoadConnectionsEffect;
    expect(effect.id, 'card-1');
    expect(effect.kind, ConnectedEntityKind.card);
  });

  test('tapping a broken connection is a no-op (no jump, no load)', () {
    const seeded = ConnectionsState(
      status: ConnectionsStatus.ready,
      breadcrumb: [
        ConnectionCrumb(
          kind: ConnectedEntityKind.collection,
          id: 'root',
          title: 'Root',
        ),
      ],
    );
    final (next, effects) = updater.update(
      seeded,
      ConnectionTapped(
        item('l1', direction: ConnectionDirection.outgoing, broken: true),
      ),
    );
    expect(next.breadcrumb, hasLength(1));
    expect(effects, isNull);
  });

  test('CrumbTapped truncates the back-stack and reloads that crumb', () {
    const seeded = ConnectionsState(
      status: ConnectionsStatus.ready,
      breadcrumb: [
        ConnectionCrumb(
          kind: ConnectedEntityKind.collection,
          id: 'a',
          title: 'A',
        ),
        ConnectionCrumb(kind: ConnectedEntityKind.card, id: 'b', title: 'B'),
        ConnectionCrumb(
          kind: ConnectedEntityKind.collection,
          id: 'c',
          title: 'C',
        ),
      ],
    );
    final (next, effects) = updater.update(seeded, const CrumbTapped(0));
    expect(next.breadcrumb.map((c) => c.id), ['a']);
    expect((effects!.single as LoadConnectionsEffect).id, 'a');
  });

  test('tapping the current (last) crumb is a no-op', () {
    const seeded = ConnectionsState(
      status: ConnectionsStatus.ready,
      breadcrumb: [
        ConnectionCrumb(
          kind: ConnectedEntityKind.collection,
          id: 'a',
          title: 'A',
        ),
        ConnectionCrumb(kind: ConnectedEntityKind.card, id: 'b', title: 'B'),
      ],
    );
    final (next, effects) = updater.update(seeded, const CrumbTapped(1));
    expect(next.breadcrumb, hasLength(2));
    expect(effects, isNull);
  });

  test('BackRequested pops one hop; at the root it is a no-op', () {
    const deep = ConnectionsState(
      status: ConnectionsStatus.ready,
      breadcrumb: [
        ConnectionCrumb(
          kind: ConnectedEntityKind.collection,
          id: 'a',
          title: 'A',
        ),
        ConnectionCrumb(kind: ConnectedEntityKind.card, id: 'b', title: 'B'),
      ],
    );
    final (popped, popEffects) = updater.update(deep, const BackRequested());
    expect(popped.breadcrumb.map((c) => c.id), ['a']);
    expect((popEffects!.single as LoadConnectionsEffect).id, 'a');

    final (atRoot, rootEffects) = updater.update(popped, const BackRequested());
    expect(atRoot.breadcrumb, hasLength(1));
    expect(rootEffects, isNull);
  });

  test('ClearLinkRequested emits a clear effect', () {
    final (_, effects) = updater.update(
      const ConnectionsState(),
      const ClearLinkRequested('l1'),
    );
    expect((effects!.single as ClearLinkEffect).linkId, 'l1');
  });
}
