import 'package:flutter_test/flutter_test.dart';
import 'package:knit/features/collection_media/domain/collection_media_models.dart';
import 'package:knit/features/collection_edit/presentation/collection_edit_action.dart';
import 'package:knit/features/collection_edit/presentation/collection_edit_effect.dart';
import 'package:knit/features/collection_edit/presentation/collection_edit_state.dart';
import 'package:knit/features/collection_edit/presentation/collection_edit_updater.dart';

void main() {
  const updater = CollectionEditUpdater();

  group('attach', () {
    test('loads the media summary and shows no cover without one', () {
      final (next, effects) = updater.update(
        const CollectionEditState(),
        const ViewAttached(collectionId: 'col-1'),
      );
      expect(next.status, CollectionEditStatus.editing);
      expect(next.collectionId, 'col-1');
      expect(next.coverBusy, isFalse);
      expect((effects!.first as ShowCoverEffect).attachmentId, isNull);
      expect((effects.last as LoadMediaSummaryEffect).collectionId, 'col-1');
    });

    test('shows the cover through the image cache when one is set', () {
      final (next, effects) = updater.update(
        const CollectionEditState(),
        const ViewAttached(collectionId: 'col-1', coverAttachmentId: 'att-1'),
      );
      expect(next.coverBusy, isFalse);
      expect((effects!.first as ShowCoverEffect).attachmentId, 'att-1');
      expect(effects.last, isA<LoadMediaSummaryEffect>());
    });

    test('re-attaching drops the previous collection\'s media summary', () {
      final (next, _) = updater.update(
        CollectionEditState(
          collectionId: 'col-0',
          mediaCounts: const MediaCounts(photos: 3),
          mediaPreviewIds: const ['p1'],
          coverBusy: true,
        ),
        const ViewAttached(collectionId: 'col-1'),
      );
      expect(next.coverBusy, isFalse);
      expect(next.mediaCounts, isNull);
      expect(next.mediaPreviewIds, isEmpty);
    });
  });

  group('media summary', () {
    test('reload re-reads the current collection', () {
      final (next, effects) = updater.update(
        const CollectionEditState(collectionId: 'col-1'),
        const MediaSummaryReloadRequested(),
      );
      expect(next.collectionId, 'col-1');
      expect((effects!.single as LoadMediaSummaryEffect).collectionId, 'col-1');
    });

    test('loaded stores the counts and preview ids', () {
      final (next, effects) = updater.update(
        const CollectionEditState(collectionId: 'col-1'),
        const MediaSummaryLoaded(
          counts: MediaCounts(photos: 2, links: 1),
          previewIds: ['p1'],
        ),
      );
      expect(next.mediaCounts!.photos, 2);
      expect(next.mediaCounts!.total, 3);
      expect(next.mediaPreviewIds, ['p1']);
      expect(effects, isNull);
    });
  });

  group('save', () {
    test('a non-blank title saves, trimming title + description', () {
      final (next, effects) = updater.update(
        const CollectionEditState(collectionId: 'col-1'),
        const SaveRequested(title: '  Espresso  ', description: '  notes  '),
      );
      expect(next.status, CollectionEditStatus.saving);
      final effect = effects!.single as SaveDetailsEffect;
      expect(effect.collectionId, 'col-1');
      expect(effect.title, 'Espresso');
      expect(effect.description, 'notes');
    });

    test('a blank/whitespace title is dropped (title is NOT NULL)', () {
      final (next, effects) = updater.update(
        const CollectionEditState(collectionId: 'col-1'),
        const SaveRequested(title: '   '),
      );
      expect(next.status, CollectionEditStatus.editing);
      expect(effects, isNull);
    });

    test('an empty description saves as null, not an empty string', () {
      final (_, effects) = updater.update(
        const CollectionEditState(collectionId: 'col-1'),
        const SaveRequested(title: 'Espresso', description: '   '),
      );
      expect((effects!.single as SaveDetailsEffect).description, isNull);
    });

    test('SaveFailed flips status so the page stays open', () {
      final (next, effects) = updater.update(
        const CollectionEditState(status: CollectionEditStatus.saving),
        const SaveFailed(),
      );
      expect(next.status, CollectionEditStatus.failed);
      expect(effects, isNull);
    });
  });

  group('cover', () {
    test('pick marks busy and emits a pick effect for the collection', () {
      final (next, effects) = updater.update(
        const CollectionEditState(collectionId: 'col-1'),
        const PickCoverRequested(),
      );
      expect(next.coverBusy, isTrue);
      expect((effects!.single as PickCoverEffect).collectionId, 'col-1');
    });

    test('remove marks busy and emits a remove effect', () {
      final (next, effects) = updater.update(
        const CollectionEditState(collectionId: 'col-1'),
        const RemoveCoverRequested(),
      );
      expect(next.coverBusy, isTrue);
      expect((effects!.single as RemoveCoverEffect).collectionId, 'col-1');
    });

    test('CoverEditEnded clears busy', () {
      final (next, effects) = updater.update(
        const CollectionEditState(coverBusy: true),
        const CoverEditEnded(),
      );
      expect(next.coverBusy, isFalse);
      expect(effects, isNull);
    });

    test('DeactivateFeature releases the page\'s images', () {
      final (_, effects) = updater.update(
        const CollectionEditState(collectionId: 'col-1'),
        const DeactivateFeature(),
      );
      expect(effects!.single, isA<ReleaseImagesEffect>());
    });
  });
}
