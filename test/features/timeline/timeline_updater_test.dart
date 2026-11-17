import 'package:flutter_test/flutter_test.dart';
import 'package:knit/features/timeline/domain/timeline_order.dart';
import 'package:knit/features/timeline/presentation/timeline_action.dart';
import 'package:knit/features/timeline/presentation/timeline_effect.dart';
import 'package:knit/features/timeline/presentation/timeline_state.dart';
import 'package:knit/features/timeline/presentation/timeline_updater.dart';
import 'package:knit/sync/sync.dart';

void main() {
  const updater = TimelineUpdater();

  CollectionSummary summary(
    String id, {
    String? cover,
    bool archived = false,
  }) => CollectionSummary(
    collectionId: id,
    title: id,
    coverAttachmentId: cover,
    cardCount: 0,
    lastCard: null,
    lastUpdated: 1,
    archived: archived,
  );

  test('ViewAttached loads', () {
    final (next, effects) = updater.update(
      const TimelineState(),
      const ViewAttached(),
    );
    expect(next.status, TimelineStatus.loading);
    expect(effects, const [LoadTimelineEffect()]);
  });

  test('CollectionsLoaded becomes ready with the list', () {
    final list = [summary('a'), summary('b')];
    final (next, effects) = updater.update(
      const TimelineState(),
      CollectionsLoaded(list),
    );
    expect(next.status, TimelineStatus.ready);
    expect(next.collections, list);
    expect((effects!.single as ShowCoversEffect).attachmentIds, isEmpty);
  });

  test('CollectionsLoaded keeps the hubs for the "in:" line (§4.1)', () {
    const hubs = {
      'a': [CollectionHub(collectionId: 'b', title: 'House')],
    };
    final (next, _) = updater.update(
      const TimelineState(),
      CollectionsLoaded([summary('a'), summary('b')], hubs: hubs),
    );
    expect(next.hubsOf('a'), hubs['a']);
    expect(next.hubsOf('b'), isEmpty);

    // A reload replaces them: a link removed elsewhere drops its hub.
    final (reloaded, _) = updater.update(
      next,
      CollectionsLoaded([summary('a'), summary('b')]),
    );
    expect(reloaded.hubsOf('a'), isEmpty);
  });

  test('CollectionsLoaded shows the covers through the image cache', () {
    final list = [
      summary('a', cover: 'cov-1'),
      summary('b'),
      summary('c', cover: 'cov-1'), // shares a cover with 'a'
      summary('d', cover: 'cov-2'),
    ];
    final (next, effects) = updater.update(
      const TimelineState(),
      CollectionsLoaded(list),
    );
    expect(next.status, TimelineStatus.ready);
    expect((effects!.single as ShowCoversEffect).attachmentIds.toSet(), {
      'cov-1',
      'cov-2',
    });
  });

  test('DeactivateFeature releases the covers', () {
    final (_, effects) = updater.update(
      const TimelineState(status: TimelineStatus.ready),
      const DeactivateFeature(),
    );
    expect(effects!.single, isA<ReleaseCoversEffect>());
  });

  test('failure marks the feed failed and keeps no effects', () {
    final (next, effects) = updater.update(
      const TimelineState(status: TimelineStatus.loading),
      const TimelineLoadFailed(),
    );
    expect(next.status, TimelineStatus.failed);
    expect(effects, isNull);
  });

  test('DeleteCollectionRequested emits a delete effect', () {
    final ready = TimelineState(
      status: TimelineStatus.ready,
      collections: [summary('a')],
    );
    final (next, effects) = updater.update(
      ready,
      const DeleteCollectionRequested('a'),
    );
    expect(next, same(ready));
    expect(effects, hasLength(1));
    expect(effects!.single, isA<DeleteCollectionEffect>());
    expect((effects.single as DeleteCollectionEffect).collectionId, 'a');
  });

  test('CollectionDeleted reloads the home feed', () {
    final (next, effects) = updater.update(
      TimelineState(status: TimelineStatus.ready, collections: [summary('a')]),
      const CollectionDeleted('a'),
    );
    expect(next.status, TimelineStatus.loading);
    expect(effects, const [LoadTimelineEffect()]);
  });

  test('CollectionCreated reloads the home feed and opens the new one', () {
    final state = TimelineState(
      status: TimelineStatus.ready,
      collections: [summary('a')],
    );
    final (next, effects) = updater.update(state, const CollectionCreated('b'));
    expect(next, state);
    expect(effects, hasLength(2));
    expect(effects![0], isA<LoadTimelineEffect>());
    expect((effects[1] as OpenCollectionEffect).collectionId, 'b');
  });

  test('CollectionDeleteFailed keeps state and emits no effects', () {
    final ready = TimelineState(
      status: TimelineStatus.ready,
      collections: [summary('a')],
    );
    final (next, effects) = updater.update(
      ready,
      const CollectionDeleteFailed(),
    );
    expect(next, same(ready));
    expect(effects, isNull);
  });

  test('CollectionsLoaded carries the pinned ids into state', () {
    final (next, _) = updater.update(
      const TimelineState(),
      CollectionsLoaded([summary('a'), summary('b')], pinnedIds: const {'b'}),
    );
    expect(next.pinnedIds, {'b'});
    expect(next.sections.pinned.single.collectionId, 'b');
    expect(next.sections.others.single.collectionId, 'a');
  });

  test('CollectionsLoaded with null pins keeps the known pins', () {
    final (next, _) = updater.update(
      const TimelineState(pinnedIds: {'a'}),
      CollectionsLoaded([summary('a')]),
    );
    expect(next.pinnedIds, {'a'});
  });

  test('PinToggled emits a SetPinnedEffect for a real change', () {
    final ready = TimelineState(
      status: TimelineStatus.ready,
      collections: [summary('a')],
    );
    final (next, effects) = updater.update(
      ready,
      const PinToggled('a', pinned: true),
    );
    expect(next, same(ready));
    final effect = effects!.single as SetPinnedEffect;
    expect(effect.collectionId, 'a');
    expect(effect.pinned, isTrue);
  });

  test('PinToggled to the current state is a no-op', () {
    final pinned = TimelineState(
      status: TimelineStatus.ready,
      collections: [summary('a')],
      pinnedIds: const {'a'},
    );
    final (next, effects) = updater.update(
      pinned,
      const PinToggled('a', pinned: true),
    );
    expect(next, same(pinned));
    expect(effects, isNull);
  });

  test('PinsChanged replaces the pinned set', () {
    final (next, effects) = updater.update(
      const TimelineState(pinnedIds: {'a'}),
      const PinsChanged({'b'}),
    );
    expect(next.pinnedIds, {'b'});
    expect(effects, isNull);
  });

  test('PinUpdateFailed keeps state and emits no effects', () {
    const ready = TimelineState(pinnedIds: {'a'});
    final (next, effects) = updater.update(ready, const PinUpdateFailed());
    expect(next, same(ready));
    expect(effects, isNull);
  });

  test('CollectionDeleted on a pinned collection also unpins it', () {
    final (_, effects) = updater.update(
      TimelineState(
        status: TimelineStatus.ready,
        collections: [summary('a')],
        pinnedIds: const {'a'},
      ),
      const CollectionDeleted('a'),
    );
    expect(effects, hasLength(2));
    expect(effects!.first, isA<LoadTimelineEffect>());
    final unpin = effects.last as SetPinnedEffect;
    expect(unpin.collectionId, 'a');
    expect(unpin.pinned, isFalse);
  });

  group('archive (§3.4)', () {
    test('ArchiveToggled emits a SetArchivedEffect for a real change', () {
      final (next, effects) = updater.update(
        TimelineState(
          status: TimelineStatus.ready,
          collections: [summary('a')],
        ),
        const ArchiveToggled('a', archived: true),
      );
      expect(next.status, TimelineStatus.ready);
      final archive = effects!.single as SetArchivedEffect;
      expect(archive.collectionId, 'a');
      expect(archive.archived, isTrue);
    });

    test('ArchiveToggled to the current state is a no-op', () {
      final ready = TimelineState(
        status: TimelineStatus.ready,
        collections: [summary('a', archived: true)],
      );
      final (next, effects) = updater.update(
        ready,
        const ArchiveToggled('a', archived: true),
      );
      expect(next, same(ready));
      expect(effects, isNull);
    });

    test('unarchive emits a SetArchivedEffect', () {
      final (_, effects) = updater.update(
        TimelineState(
          status: TimelineStatus.ready,
          collections: [summary('a', archived: true)],
        ),
        const ArchiveToggled('a', archived: false),
      );
      expect((effects!.single as SetArchivedEffect).archived, isFalse);
    });

    test('CollectionArchiveChanged reloads the home feed', () {
      final (next, effects) = updater.update(
        TimelineState(
          status: TimelineStatus.ready,
          collections: [summary('a')],
        ),
        const CollectionArchiveChanged('a', archived: true),
      );
      expect(next.status, TimelineStatus.loading);
      expect(effects, const [LoadTimelineEffect()]);
    });

    test('archiving a pinned collection also unpins it', () {
      final (_, effects) = updater.update(
        TimelineState(
          status: TimelineStatus.ready,
          collections: [summary('a')],
          pinnedIds: const {'a'},
        ),
        const CollectionArchiveChanged('a', archived: true),
      );
      expect(effects, hasLength(2));
      expect(effects!.first, isA<LoadTimelineEffect>());
      final unpin = effects.last as SetPinnedEffect;
      expect(unpin.collectionId, 'a');
      expect(unpin.pinned, isFalse);
    });

    test('unarchiving leaves the pins alone', () {
      final (_, effects) = updater.update(
        TimelineState(
          status: TimelineStatus.ready,
          collections: [summary('a', archived: true)],
          pinnedIds: const {'a'},
        ),
        const CollectionArchiveChanged('a', archived: false),
      );
      expect(effects, const [LoadTimelineEffect()]);
    });

    test('ArchiveUpdateFailed keeps state and emits no effects', () {
      const ready = TimelineState(status: TimelineStatus.ready);
      final (next, effects) = updater.update(
        ready,
        const ArchiveUpdateFailed(),
      );
      expect(next, same(ready));
      expect(effects, isNull);
    });
  });

  group('manual order (§4.1)', () {
    TimelineState abcReady() => TimelineState(
      status: TimelineStatus.ready,
      collections: [summary('a'), summary('b'), summary('c')],
    );
    List<String> idsOf(List<CollectionSummary> list) => [
      for (final c in list) c.collectionId,
    ];

    test('ReorderStarted and ReorderEnded toggle reorder mode', () {
      final (started, startEffects) = updater.update(
        abcReady(),
        const ReorderStarted(),
      );
      expect(started.reordering, isTrue);
      expect(startEffects, isNull);

      final (ended, endEffects) = updater.update(started, const ReorderEnded());
      expect(ended.reordering, isFalse);
      expect(endEffects, isNull);
    });

    test('a drag moves the collection and persists the new order', () {
      final (next, effects) = updater.update(
        abcReady(),
        const CollectionMoved(0, 2),
      );
      expect(next.order.ids, ['b', 'c', 'a']);
      expect(idsOf(next.sections.others), ['b', 'c', 'a']);
      final save = effects!.single as SaveOrderEffect;
      expect(save.order.ids, ['b', 'c', 'a']);
    });

    test('a drag that moves nothing returns the same state', () {
      final ready = abcReady();
      final (next, effects) = updater.update(
        ready,
        const CollectionMoved(1, 1),
      );
      expect(next, same(ready));
      expect(effects, isNull);
    });

    test('reset clears a manual order and persists the empty one', () {
      final (manual, _) = updater.update(
        abcReady(),
        const CollectionMoved(0, 2),
      );
      final (reset, effects) = updater.update(
        manual,
        const OrderResetRequested(),
      );
      expect(reset.order.isManual, isFalse);
      expect(idsOf(reset.sections.others), ['a', 'b', 'c']);
      final save = effects!.single as SaveOrderEffect;
      expect(save.order.isManual, isFalse);
    });

    test('reset with no manual order is a no-op', () {
      final ready = abcReady();
      final (next, effects) = updater.update(
        ready,
        const OrderResetRequested(),
      );
      expect(next, same(ready));
      expect(effects, isNull);
    });

    test('OrderChanged replaces the order without an effect', () {
      final (next, effects) = updater.update(
        abcReady(),
        const OrderChanged(TimelineOrder(['c', 'a', 'b'])),
      );
      expect(next.order.ids, ['c', 'a', 'b']);
      expect(effects, isNull);
    });

    test('OrderUpdateFailed keeps the dragged order', () {
      final (manual, _) = updater.update(
        abcReady(),
        const CollectionMoved(0, 2),
      );
      final (next, effects) = updater.update(manual, const OrderUpdateFailed());
      expect(next, same(manual));
      expect(effects, isNull);
    });

    test('CollectionsLoaded with no order keeps the last known order', () {
      final (manual, _) = updater.update(
        abcReady(),
        const CollectionMoved(0, 2),
      );
      final (reloaded, _) = updater.update(
        manual,
        CollectionsLoaded([summary('a'), summary('b'), summary('c')]),
      );
      expect(reloaded.order.ids, ['b', 'c', 'a']);
      expect(idsOf(reloaded.sections.others), ['b', 'c', 'a']);
    });

    test('CollectionsLoaded with an order replaces the last known one', () {
      final (manual, _) = updater.update(
        abcReady(),
        const CollectionMoved(0, 2),
      );
      final (reordered, _) = updater.update(
        manual,
        CollectionsLoaded([
          summary('a'),
          summary('b'),
          summary('c'),
        ], order: const TimelineOrder(['a', 'b', 'c'])),
      );
      expect(reordered.order.ids, ['a', 'b', 'c']);

      // An empty order is a real value too: it clears the manual order.
      final (cleared, _) = updater.update(
        reordered,
        CollectionsLoaded([
          summary('a'),
          summary('b'),
          summary('c'),
        ], order: const TimelineOrder()),
      );
      expect(cleared.order.isManual, isFalse);
    });

    test('CollectionsLoaded keeps reorder mode across a reload', () {
      final (reordering, _) = updater.update(
        abcReady(),
        const ReorderStarted(),
      );
      final (reloaded, _) = updater.update(
        reordering,
        CollectionsLoaded([summary('a'), summary('b'), summary('c')]),
      );
      expect(reloaded.reordering, isTrue);
    });

    test('DeactivateFeature leaves reorder mode and releases the covers', () {
      final (next, effects) = updater.update(
        const TimelineState(status: TimelineStatus.ready, reordering: true),
        const DeactivateFeature(),
      );
      expect(next.reordering, isFalse);
      expect(effects!.single, isA<ReleaseCoversEffect>());
    });
  });
}
