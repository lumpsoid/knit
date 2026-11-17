import 'package:flutter_test/flutter_test.dart';
import 'package:knit/app/app_graph.dart';
import 'package:knit/core/ownership/collection_ownership.dart';
import 'package:knit/features/card_links/domain/card_links_models.dart';
import 'package:knit/features/card_links/infra/sync_store_link_targets_read_repository.dart';
import 'package:knit/features/card_links/presentation/card_links_state.dart';
import 'package:knit/features/collection/domain/collection_models.dart';
import 'package:knit/features/collection/infra/sync_store_card_move_read_repository.dart';
import 'package:knit/features/collection/infra/sync_store_collection_read_repository.dart';
import 'package:knit/features/collection/presentation/collection_action.dart';
import 'package:knit/features/collection/presentation/collection_effect.dart';
import 'package:knit/features/collection/presentation/collection_state.dart';
import 'package:knit/features/collection/presentation/collection_updater.dart';
import 'package:knit/features/collection_share/infra/infra.dart';
import 'package:knit/features/collection_widget/domain/collection_widget_models.dart';
import 'package:knit/features/collection_widget/domain/collection_widget_tile_planner.dart';
import 'package:knit/features/collection_widget/infra/sync_store_collection_widget_read_repository.dart';
import 'package:knit/features/connections/domain/connections_models.dart';
import 'package:knit/features/share_capture/infra/sync_store_share_capture_read_repository.dart';
import 'package:knit/features/timeline/domain/timeline_order.dart';
import 'package:knit/features/timeline/domain/timeline_sections.dart';
import 'package:knit/features/timeline/infra/sync_store_timeline_owner_repository.dart';
import 'package:knit/features/timeline/presentation/timeline_action.dart';
import 'package:knit/features/timeline/presentation/timeline_effect.dart';
import 'package:knit/features/timeline/presentation/timeline_state.dart';
import 'package:knit/features/timeline/presentation/timeline_updater.dart';
import 'package:knit/sync/sync.dart';

import 'share_fixture.dart';

/// Read-only across features (docs/collection_share.md "Read-only"): a
/// collection created by another identity is imported, and every surface
/// asks [CollectionOwnership] what it may do with it.
void main() {
  late SyncStore recipient;
  late AppGraph graph;

  /// Kai imports Mira's `trip` and owns `mine`.
  setUp(() async {
    final sender = await device('mira');
    await seedTrip(sender);
    recipient = await device('kai');
    graph = graphOf(recipient);
    for (final op in (await sender.shareSet('trip')).ops) {
      await recipient.applyRemote(op, 5000);
    }
    await recipient.create(EntityType.collection, 'mine', {'title': 'Mine'});
    await recipient.create(EntityType.card, 'm1', {
      'collection_id': 'mine',
      'kind': 'text',
      'text': 'm1',
    }, position: 'a0');
  });

  group('Collection', () {
    test('the read model says imported, with the creator\'s handle', () async {
      final read = SyncStoreCollectionReadRepository(graph: graph);
      final trip = (await read.loadCollection('trip')).getOrThrow();
      expect(trip.ownership, CollectionOwnership.imported);
      expect(trip.ownerHandle, startsWith('mira#'));
      final mine = (await read.loadCollection('mine')).getOrThrow();
      expect(mine.ownership, CollectionOwnership.own);
      expect(mine.ownerHandle, isNull);
    });

    const updater = CollectionUpdater();
    const cards = [
      FeedCard(id: 'c1', kind: CardKind.text, position: 'a0', text: 'c1'),
      FeedCard(id: 'c2', kind: CardKind.text, position: 'a1', text: 'c2'),
    ];
    final imported = updater
        .update(
          const CollectionState(collectionId: 'trip'),
          const CollectionLoaded(
            CollectionData(
              collectionId: 'trip',
              title: 'Trip',
              description: null,
              coverAttachmentId: null,
              cards: cards,
              ownership: CollectionOwnership.imported,
              ownerHandle: 'mira#9f86',
            ),
          ),
        )
        .$1;

    test('an imported collection cannot be edited or reordered', () {
      expect(imported.canEdit, isFalse);
      expect(imported.canReorder, isFalse);
      expect(imported.ownerHandle, 'mira#9f86');
    });

    test('every write to it is dropped', () {
      for (final action in <CollectionAction>[
        const ComposerSubmitted('hi'),
        const CardDeleteRequested('c1'),
        const CollectionDeleteRequested(),
        const CardSettleToggled('c1'),
        const CardEmphasisToggled('c1'),
        const StartReorder(),
        const CardSelectionToggled('c1'),
      ]) {
        final (next, effects) = updater.update(imported, action);
        expect(effects, isNull, reason: '$action');
        expect(next.reordering || next.selecting, isFalse, reason: '$action');
      }
    });

    test('a link from the user\'s own card into it still goes out', () {
      final (_, effects) = updater.update(
        imported,
        const LinkRequested(
          cardId: 'm1',
          targetKind: ConnectedEntityKind.card,
          targetId: 'c1',
        ),
      );
      expect(effects!.single, isA<LinkEffect>());
    });

    test('move targets exclude the imported collection', () async {
      final targets = (await SyncStoreCardMoveReadRepository(
        graph: graph,
      ).loadMoveTargets()).getOrThrow();
      expect(targets.map((t) => t.collectionId), ['mine']);
    });
  });

  test('share capture offers only own collections', () async {
    final targets = (await SyncStoreShareCaptureReadRepository(
      graph: graph,
    ).loadTargets()).getOrThrow();
    expect(targets.map((t) => t.collectionId), ['mine']);
  });

  group('Link picker', () {
    test(
      'collections carry ownership; links into imported are offered',
      () async {
        final collections = (await SyncStoreLinkTargetsReadRepository(
          graph: graph,
        ).loadCollections()).getOrThrow();
        final own = {for (final c in collections) c.id: c.own};
        expect(own, {'trip': false, 'mine': true});
      },
    );

    test('"Link from my card…" lists own collections and their cards', () {
      const pick = LinkFromMine(targetCardId: 'c1');
      final state = CardLinksState()
        ..startPicking(pick)
        ..showCollections(const [
          LinkTarget(
            kind: ConnectedEntityKind.collection,
            id: 'trip',
            label: 'Trip',
            own: false,
          ),
          LinkTarget(
            kind: ConnectedEntityKind.collection,
            id: 'mine',
            label: 'Mine',
          ),
        ]);
      expect(state.collections!.map((c) => c.id), ['mine']);
      expect(state.canLinkToCollection('mine'), isFalse);
      expect(pick.canLinkToCard('m1'), isTrue);
      expect(pick.canLinkToCard('c1'), isFalse);
    });
  });

  group('Timeline', () {
    test('imported collections get their creator\'s handle', () async {
      final owners = (await SyncStoreTimelineOwnerRepository(
        graph: graph,
      ).loadImportedOwners(await recipient.homeTimeline())).getOrThrow();
      expect(owners.keys, ['trip']);
      expect(owners['trip'], startsWith('mira#'));
    });

    const summaries = [
      CollectionSummary(
        collectionId: 'trip',
        title: 'Trip',
        coverAttachmentId: null,
        cardCount: 2,
        lastCard: null,
        lastUpdated: 2,
      ),
      CollectionSummary(
        collectionId: 'mine',
        title: 'Mine',
        coverAttachmentId: null,
        cardCount: 1,
        lastCard: null,
        lastUpdated: 1,
      ),
    ];
    const updater = TimelineUpdater();
    final loaded = updater
        .update(
          const TimelineState(),
          const CollectionsLoaded(
            summaries,
            importedOwners: {'trip': 'mira#9f86'},
            localArchivedIds: {},
          ),
        )
        .$1;

    test('archiving an imported collection is local, an own one signed', () {
      final (_, local) = updater.update(
        loaded,
        const ArchiveToggled('trip', archived: true),
      );
      expect(local!.single, isA<SetLocalArchivedEffect>());
      final (_, signed) = updater.update(
        loaded,
        const ArchiveToggled('mine', archived: true),
      );
      expect(signed!.single, isA<SetArchivedEffect>());
    });

    test('a locally archived collection moves to the Archive', () {
      final sections = TimelineSections.split(
        summaries,
        const {'trip'},
        localArchivedIds: const {'trip'},
        order: const TimelineOrder(),
      );
      expect(sections.archived.map((c) => c.collectionId), ['trip']);
      expect(sections.pinned, isEmpty);
      final archived = loaded.copyWith(localArchivedIds: {'trip'});
      expect(archived.isArchived('trip'), isTrue);
      expect(
        updater
            .update(archived, const ArchiveToggled('trip', archived: true))
            .$2,
        isNull,
      );
    });

    test('the local archive store round-trips', () async {
      final store = InMemoryLocalArchiveRepository();
      expect((await store.setArchived('trip', archived: true)).getOrThrow(), {
        'trip',
      });
      expect((await store.loadArchived()).getOrThrow(), {'trip'});
      await store.setArchived('trip', archived: false);
      expect((await store.loadArchived()).getOrThrow(), isEmpty);
    });
  });

  group('Home-screen widget', () {
    test('an imported collection\'s tile has no quick input', () async {
      final read = SyncStoreCollectionWidgetReadRepository(graph: graph);
      final readOnly = (await read.readOnlyIds({'trip', 'mine'})).getOrThrow();
      expect(readOnly, {'trip'});

      final tiles = const CollectionWidgetTilePlanner().plan(
        const [
          CollectionWidgetBinding(widgetId: 1, collectionId: 'trip'),
          CollectionWidgetBinding(widgetId: 2, collectionId: 'mine'),
        ],
        const {'trip': 'Trip', 'mine': 'Mine'},
        readOnlyIds: readOnly,
      );
      expect(tiles, const [
        CollectionWidgetTile.live(
          widgetId: 1,
          title: 'Trip',
          quickInput: false,
        ),
        CollectionWidgetTile.live(widgetId: 2, title: 'Mine'),
      ]);
    });
  });
}
