import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:knit/features/collection_edit/presentation/collection_edit_action.dart';
import 'package:knit/features/collection_edit/presentation/collection_edit_effect.dart';
import 'package:knit/features/collection_edit/presentation/collection_edit_state.dart';
import 'package:knit/features/collection_edit/presentation/collection_edit_updater.dart';

void main() {
  const updater = CollectionEditUpdater();

  group('attach', () {
    test('seeds the fields and loads no cover when there is none', () {
      final (next, effects) = updater.update(
        const CollectionEditState(),
        const ViewAttached(
          collectionId: 'col-1',
          initialTitle: 'Espresso',
          initialDescription: 'notes',
          initialCoverAttachmentId: null,
        ),
      );
      expect(next.status, CollectionEditStatus.editing);
      expect(next.collectionId, 'col-1');
      expect(next.initialTitle, 'Espresso');
      expect(next.initialDescription, 'notes');
      expect(next.coverAttachmentId, isNull);
      expect(next.coverBusy, isFalse);
      expect(effects, isNull);
    });

    test('loads the cover bytes when a cover is set', () {
      final (next, effects) = updater.update(
        const CollectionEditState(),
        const ViewAttached(
          collectionId: 'col-1',
          initialTitle: 'Espresso',
          initialCoverAttachmentId: 'att-1',
        ),
      );
      expect(next.coverAttachmentId, 'att-1');
      expect(next.coverBusy, isTrue);
      expect((effects!.single as LoadCoverEffect).attachmentId, 'att-1');
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
    test('pick marks busy and emits a pick effect with the previous id', () {
      final (next, effects) = updater.update(
        const CollectionEditState(
          collectionId: 'col-1',
          coverAttachmentId: 'old',
        ),
        const PickCoverRequested(),
      );
      expect(next.coverBusy, isTrue);
      final effect = effects!.single as PickCoverEffect;
      expect(effect.collectionId, 'col-1');
      expect(effect.previousAttachmentId, 'old');
    });

    test('remove marks busy and emits a remove effect', () {
      final (next, effects) = updater.update(
        const CollectionEditState(
          collectionId: 'col-1',
          coverAttachmentId: 'old',
        ),
        const RemoveCoverRequested(),
      );
      expect(next.coverBusy, isTrue);
      expect(
        (effects!.single as RemoveCoverEffect).previousAttachmentId,
        'old',
      );
    });

    test('CoverResolved sets the new cover + bytes and clears busy', () {
      final bytes = Uint8List.fromList([1, 2, 3]);
      final (next, effects) = updater.update(
        const CollectionEditState(coverBusy: true),
        CoverResolved(attachmentId: 'att-2', bytes: bytes),
      );
      expect(next.coverAttachmentId, 'att-2');
      expect(next.coverBytes, bytes);
      expect(next.coverBusy, isFalse);
      expect(effects, isNull);
    });

    test('CoverResolved with nulls clears the cover (a removal)', () {
      final (next, _) = updater.update(
        const CollectionEditState(
          coverBusy: true,
          coverAttachmentId: 'old',
          coverBytes: null,
        ),
        const CoverResolved(),
      );
      expect(next.coverAttachmentId, isNull);
      expect(next.coverBytes, isNull);
      expect(next.coverBusy, isFalse);
    });

    test('CoverEditEnded just clears busy, leaving the cover unchanged', () {
      final (next, _) = updater.update(
        const CollectionEditState(coverBusy: true, coverAttachmentId: 'keep'),
        const CoverEditEnded(),
      );
      expect(next.coverBusy, isFalse);
      expect(next.coverAttachmentId, 'keep');
    });
  });
}
