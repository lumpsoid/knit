import 'package:flutter_test/flutter_test.dart';
import 'package:knit/features/timeline/presentation/timeline_action.dart';
import 'package:knit/features/timeline/presentation/timeline_effect.dart';
import 'package:knit/features/timeline/presentation/timeline_state.dart';
import 'package:knit/features/timeline/presentation/timeline_updater.dart';
import 'package:knit/sync/sync.dart';

void main() {
  const updater = TimelineUpdater();

  CollectionSummary summary(String id, {String? cover}) => CollectionSummary(
    collectionId: id,
    title: id,
    coverAttachmentId: cover,
    cardCount: 0,
    lastCard: null,
    lastUpdated: 1,
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
}
