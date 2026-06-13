import 'package:flutter_test/flutter_test.dart';
import 'package:knit/features/timeline/presentation/timeline_action.dart';
import 'package:knit/features/timeline/presentation/timeline_effect.dart';
import 'package:knit/features/timeline/presentation/timeline_state.dart';
import 'package:knit/features/timeline/presentation/timeline_updater.dart';
import 'package:knit/sync/sync.dart';

void main() {
  const updater = TimelineUpdater();

  CollectionSummary summary(String id) => CollectionSummary(
        collectionId: id,
        title: id,
        coverAttachmentId: null,
        cardCount: 0,
        lastCard: null,
        lastUpdated: 1,
      );

  test('ViewAttached loads', () {
    final (next, effects) =
        updater.update(const TimelineState(), const ViewAttached());
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
    expect(effects, isNull);
  });

  test('failure surfaces an error and keeps no effects', () {
    final (next, effects) = updater.update(
      const TimelineState(status: TimelineStatus.loading),
      const TimelineLoadFailed('nope'),
    );
    expect(next.status, TimelineStatus.failed);
    expect(next.errorMessage, 'nope');
    expect(effects, isNull);
  });

  test('DeleteCollectionRequested emits a delete effect', () {
    final ready = TimelineState(
      status: TimelineStatus.ready,
      collections: [summary('a')],
    );
    final (next, effects) =
        updater.update(ready, const DeleteCollectionRequested('a'));
    expect(next, same(ready));
    expect(effects, hasLength(1));
    expect(effects!.single, isA<DeleteCollectionEffect>());
    expect((effects.single as DeleteCollectionEffect).collectionId, 'a');
  });

  test('CollectionDeleted reloads the home feed', () {
    final (next, effects) = updater.update(
      TimelineState(
        status: TimelineStatus.ready,
        collections: [summary('a')],
      ),
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
    final (next, effects) =
        updater.update(ready, const CollectionDeleteFailed('delete failed'));
    expect(next, same(ready));
    expect(effects, isNull);
  });
}
