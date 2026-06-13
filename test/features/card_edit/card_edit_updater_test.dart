import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:knit/features/card_edit/presentation/card_edit_action.dart';
import 'package:knit/features/card_edit/presentation/card_edit_effect.dart';
import 'package:knit/features/card_edit/presentation/card_edit_state.dart';
import 'package:knit/features/card_edit/presentation/card_edit_updater.dart';
import 'package:knit/features/connections/domain/connections_models.dart';

void main() {
  const updater = CardEditUpdater();

  ConnectionItem link(String id, {bool broken = false}) => ConnectionItem(
        linkId: id,
        direction: ConnectionDirection.outgoing,
        otherKind: ConnectedEntityKind.collection,
        otherId: 'col-$id',
        broken: broken,
        label: broken ? null : 'Target $id',
      );

  group('attach', () {
    test('seeds id/text, loads links + targets, no image when none', () {
      final (next, effects) = updater.update(
        const CardEditState(),
        const ViewAttached(
          cardId: 'c1',
          initialText: 'hello',
          initialAttachmentId: null,
        ),
      );
      expect(next.status, CardEditStatus.editing);
      expect(next.cardId, 'c1');
      expect(next.initialText, 'hello');
      expect(next.linksLoading, isTrue);
      expect(next.attachmentId, isNull);
      expect(next.imageBusy, isFalse);
      expect(effects, hasLength(2));
      expect(effects!.whereType<LoadLinksEffect>().single.cardId, 'c1');
      expect(effects.whereType<LoadTargetsEffect>().single.cardId, 'c1');
    });

    test('loads the current image when the card has one', () {
      final (next, effects) = updater.update(
        const CardEditState(),
        const ViewAttached(
          cardId: 'c1',
          initialText: '',
          initialAttachmentId: 'att-1',
        ),
      );
      expect(next.attachmentId, 'att-1');
      expect(next.imageBusy, isTrue);
      expect(effects!.whereType<LoadImageEffect>().single.attachmentId, 'att-1');
    });
  });

  group('save', () {
    CardEditState attached() =>
        const CardEditState(cardId: 'c1', initialText: 'hello');

    test('SaveRequested emits SaveCardEffect and enters saving', () {
      final (next, effects) =
          updater.update(attached(), const SaveRequested('new body'));
      expect(next.status, CardEditStatus.saving);
      final effect = effects!.single as SaveCardEffect;
      expect((effect.cardId, effect.text), ('c1', 'new body'));
    });

    test('surrounding whitespace is trimmed', () {
      final (_, effects) =
          updater.update(attached(), const SaveRequested('  trimmed  '));
      expect((effects!.single as SaveCardEffect).text, 'trimmed');
    });

    test('blank / whitespace-only save is dropped', () {
      final (_, effects) =
          updater.update(attached(), const SaveRequested('   '));
      expect(effects, isNull);
    });

    test('SaveFailed marks the page failed', () {
      final saving = attached().copyWith(status: CardEditStatus.saving);
      final (next, effects) =
          updater.update(saving, const SaveFailed());
      expect(next.status, CardEditStatus.failed);
      expect(effects, isNull);
    });
  });

  group('links', () {
    test('LinksLoaded fills the list and clears the spinner', () {
      const loading = CardEditState(cardId: 'c1', linksLoading: true);
      final (next, effects) =
          updater.update(loading, LinksLoaded([link('l1')]));
      expect(next.links, hasLength(1));
      expect(next.linksLoading, isFalse);
      expect(effects, isNull);
    });

    test('AddLinkRequested emits AddLinkEffect for the chosen target', () {
      const state = CardEditState(cardId: 'c1');
      final (next, effects) = updater.update(
        state,
        const AddLinkRequested(
          targetKind: ConnectedEntityKind.card,
          targetId: 'c2',
        ),
      );
      expect(next.linksLoading, isTrue);
      final effect = effects!.single as AddLinkEffect;
      expect(
        (effect.cardId, effect.targetKind, effect.targetId),
        ('c1', ConnectedEntityKind.card, 'c2'),
      );
    });

    test('RemoveLinkRequested emits RemoveLinkEffect', () {
      const state = CardEditState(cardId: 'c1');
      final (_, effects) =
          updater.update(state, const RemoveLinkRequested('l1'));
      expect((effects!.single as RemoveLinkEffect).linkId, 'l1');
    });

    test('LinksChanged reloads the list', () {
      const state = CardEditState(cardId: 'c1');
      final (next, effects) = updater.update(state, const LinksChanged());
      expect(next.linksLoading, isTrue);
      expect((effects!.single as LoadLinksEffect).cardId, 'c1');
    });
  });

  group('image', () {
    test('PickImageRequested carries the previous attachment for GC', () {
      const state = CardEditState(cardId: 'c1', attachmentId: 'old');
      final (next, effects) =
          updater.update(state, const PickImageRequested());
      expect(next.imageBusy, isTrue);
      expect((effects!.single as PickImageEffect).previousAttachmentId, 'old');
    });

    test('ImageChanged to a new id clears old bytes and loads the new image',
        () {
      final state = CardEditState(
        cardId: 'c1',
        attachmentId: 'old',
        imageBytes: Uint8List.fromList([1, 2, 3]),
      );
      final (next, effects) = updater.update(state, const ImageChanged('new'));
      expect(next.attachmentId, 'new');
      expect(next.imageBytes, isNull);
      expect(next.imageBusy, isTrue);
      expect((effects!.single as LoadImageEffect).attachmentId, 'new');
    });

    test('ImageChanged to null removes the image with no effect', () {
      final state = CardEditState(
        cardId: 'c1',
        attachmentId: 'old',
        imageBytes: Uint8List.fromList([1]),
        imageBusy: true,
      );
      final (next, effects) = updater.update(state, const ImageChanged(null));
      expect(next.attachmentId, isNull);
      expect(next.imageBytes, isNull);
      expect(next.imageBusy, isFalse);
      expect(effects, isNull);
    });

    test('ImageBytesLoaded stores bytes and clears the busy flag', () {
      const state = CardEditState(cardId: 'c1', imageBusy: true);
      final bytes = Uint8List.fromList([9]);
      final (next, _) = updater.update(state, ImageBytesLoaded(bytes));
      expect(next.imageBytes, bytes);
      expect(next.imageBusy, isFalse);
    });

    test('ImageEditEnded just drops the busy flag', () {
      const state = CardEditState(cardId: 'c1', imageBusy: true);
      final (next, effects) = updater.update(state, const ImageEditEnded());
      expect(next.imageBusy, isFalse);
      expect(effects, isNull);
    });
  });
}
