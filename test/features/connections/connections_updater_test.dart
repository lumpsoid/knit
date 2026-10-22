import 'package:flutter_test/flutter_test.dart';
import 'package:knit/features/connections/domain/connections_models.dart';
import 'package:knit/features/connections/domain/unlinked_mentions.dart';
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
    bool ownSource = false,
  }) => ConnectionItem(
    linkId: linkId,
    direction: direction,
    otherKind: otherKind,
    otherId: otherId,
    broken: broken,
    label: label,
    ownSource: ownSource,
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
    // A collection focus then looks for its unlinked mentions (§8.6.5).
    final mentions = effects!.single as LoadMentionsEffect;
    expect(mentions.collectionId, 'root');
    expect(mentions.title, 'Recipes');
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

  group('Remove + Undo (§4.4)', () {
    test('a removable link out is removed; Undo re-links focus → far end', () {
      final out = item(
        'l1',
        direction: ConnectionDirection.outgoing,
        otherKind: ConnectedEntityKind.card,
        otherId: 'c9',
        ownSource: true,
      );
      final state = ConnectionsState(
        status: ConnectionsStatus.ready,
        data: data(outgoing: [out]),
      );
      final (next, effects) = updater.update(state, RemoveLinkRequested(out));
      expect(next, same(state));
      final effect = effects!.single as RemoveLinkEffect;
      expect(effect.linkId, 'l1');
      expect(
        effect.ends,
        const LinkEnds(
          sourceKind: ConnectedEntityKind.collection,
          sourceId: 'root',
          targetKind: ConnectedEntityKind.card,
          targetId: 'c9',
        ),
      );

      final (_, undo) = updater.update(
        state,
        UndoRemoveLinkRequested(effect.ends),
      );
      expect((undo!.single as RestoreLinkEffect).ends, effect.ends);
    });

    test('a backlink from an own card: its source is the far end', () {
      final back = item(
        'l2',
        direction: ConnectionDirection.incoming,
        otherKind: ConnectedEntityKind.card,
        otherId: 'mine',
        ownSource: true,
      );
      final (_, effects) = updater.update(
        ConnectionsState(data: data(incoming: [back])),
        RemoveLinkRequested(back),
      );
      expect(
        (effects!.single as RemoveLinkEffect).ends,
        const LinkEnds(
          sourceKind: ConnectedEntityKind.card,
          sourceId: 'mine',
          targetKind: ConnectedEntityKind.collection,
          targetId: 'root',
        ),
      );
    });

    test('an imported source, or a broken link, is not removable', () {
      final foreign = item('l3', direction: ConnectionDirection.incoming);
      final broken = item(
        'l4',
        direction: ConnectionDirection.outgoing,
        broken: true,
        ownSource: true,
      );
      expect(foreign.removable, isFalse);
      expect(broken.removable, isFalse);
      final state = ConnectionsState(
        data: data(outgoing: [broken], incoming: [foreign]),
      );
      for (final row in [foreign, broken]) {
        final (next, effects) = updater.update(state, RemoveLinkRequested(row));
        expect(next, same(state));
        expect(effects, isNull);
      }
    });
  });

  group('Mentioned in (§8.6.5)', () {
    const rootCrumb = ConnectionCrumb(
      kind: ConnectedEntityKind.collection,
      id: 'root',
      title: 'Root',
    );
    const mentions = UnlinkedMentions(
      items: [
        UnlinkedMention(
          cardId: 'm1',
          collectionId: 'c1',
          collectionTitle: 'C1',
          preview: 'about root',
        ),
        UnlinkedMention(
          cardId: 'm2',
          collectionId: 'c2',
          collectionTitle: 'C2',
          preview: 'root again',
        ),
      ],
      more: 4,
    );
    final ready = ConnectionsState(
      status: ConnectionsStatus.ready,
      breadcrumb: const [rootCrumb],
      data: data(),
      mentions: mentions,
    );

    test('a card focus loads no mentions', () {
      final (_, effects) = updater.update(
        const ConnectionsState(),
        const ConnectionsLoaded(
          ConnectionsData(
            focusKind: ConnectedEntityKind.card,
            focusId: 'card',
            focusTitle: 'A card',
            outgoing: [],
            incoming: [],
          ),
        ),
      );
      expect(effects, isNull);
    });

    test('MentionsLoaded lands only on the collection still in focus', () {
      final seeded = ready.copyWith(clearMentions: true);
      final (next, _) = updater.update(
        seeded,
        const MentionsLoaded(collectionId: 'root', mentions: mentions),
      );
      expect(next.mentions!.items, hasLength(2));
      expect(next.mentions!.more, 4);

      final (stale, _) = updater.update(
        seeded,
        const MentionsLoaded(collectionId: 'elsewhere', mentions: mentions),
      );
      expect(stale.mentions, isNull);
    });

    test('a reload of the same focus keeps the rows until fresh ones', () {
      final (next, _) = updater.update(ready, ConnectionsLoaded(data()));
      expect(next.mentions, same(mentions));
      final (moved, _) = updater.update(
        ready,
        ConnectionsLoaded(data(focusId: 'other')),
      );
      expect(moved.mentions, isNull);
    });

    test('jumping away drops the rows', () {
      final (next, _) = updater.update(
        ready,
        ConnectionTapped(
          item('l1', direction: ConnectionDirection.outgoing, otherId: 'x'),
        ),
      );
      expect(next.mentions, isNull);
    });

    test('mentions alone keep the page from the empty view', () {
      expect(ready.isEmpty, isFalse);
      expect(ready.copyWith(clearMentions: true).isEmpty, isTrue);
    });

    test('Link takes the row out and links it to the focus', () {
      final (next, effects) = updater.update(
        ready,
        const LinkMentionRequested('m1'),
      );
      expect(next.mentions!.items.map((m) => m.cardId), ['m2']);
      expect(next.mentions!.more, 4);
      final link = effects!.single as LinkMentionEffect;
      expect(link.cardId, 'm1');
      expect(link.collectionId, 'root');
    });
  });
}
