import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:knit/features/card_edit/presentation/card_edit_action.dart';
import 'package:knit/features/card_edit/presentation/card_edit_effect.dart';
import 'package:knit/features/card_edit/presentation/card_edit_state.dart';
import 'package:knit/features/card_edit/presentation/card_edit_updater.dart';
import 'package:knit/features/collection/domain/collection_models.dart';
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
    test('seeds id/text, loads links + targets, no attachment when none', () {
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
      expect(next.attachmentBusy, isFalse);
      expect(effects, hasLength(2));
      expect(effects!.whereType<LoadLinksEffect>().single.cardId, 'c1');
      expect(effects.whereType<LoadTargetsEffect>().single.cardId, 'c1');
    });

    test('loads the bytes for an image attachment', () {
      final (next, effects) = updater.update(
        const CardEditState(),
        const ViewAttached(
          cardId: 'c1',
          initialText: '',
          initialAttachmentId: 'att-1',
          initialAttachmentKind: CardKind.image,
        ),
      );
      expect(next.attachmentId, 'att-1');
      expect(next.attachmentKind, CardKind.image);
      expect(next.attachmentBusy, isTrue);
      expect(effects!.whereType<LoadImageEffect>().single.attachmentId, 'att-1');
    });

    test('renders an audio/file attachment from metadata without a load', () {
      final (next, effects) = updater.update(
        const CardEditState(),
        const ViewAttached(
          cardId: 'c1',
          initialText: '',
          initialAttachmentId: 'att-2',
          initialAttachmentKind: CardKind.file,
          initialFileName: 'report.pdf',
          initialFileSize: 2048,
        ),
      );
      expect(next.attachmentId, 'att-2');
      expect(next.attachmentKind, CardKind.file);
      expect(next.attachmentName, 'report.pdf');
      expect(next.attachmentSize, 2048);
      expect(next.attachmentBusy, isFalse); // no bytes to fetch
      expect(effects!.whereType<LoadImageEffect>(), isEmpty);
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

  group('attachment', () {
    test('PickImageRequested carries the previous attachment for GC', () {
      const state = CardEditState(cardId: 'c1', attachmentId: 'old');
      final (next, effects) =
          updater.update(state, const PickImageRequested());
      expect(next.attachmentBusy, isTrue);
      expect((effects!.single as PickImageEffect).previousAttachmentId, 'old');
    });

    test('PickFileRequested carries the previous attachment for GC', () {
      const state = CardEditState(cardId: 'c1', attachmentId: 'old');
      final (next, effects) = updater.update(state, const PickFileRequested());
      expect(next.attachmentBusy, isTrue);
      expect((effects!.single as PickFileEffect).previousAttachmentId, 'old');
    });

    test('RemoveAttachmentRequested carries the previous attachment for GC', () {
      const state = CardEditState(cardId: 'c1', attachmentId: 'old');
      final (next, effects) =
          updater.update(state, const RemoveAttachmentRequested());
      expect(next.attachmentBusy, isTrue);
      expect(
        (effects!.single as RemoveAttachmentEffect).previousAttachmentId,
        'old',
      );
    });

    test('AttachmentResolved with an image fills bytes and clears busy', () {
      const state = CardEditState(cardId: 'c1', attachmentBusy: true);
      final bytes = Uint8List.fromList([9]);
      final (next, effects) = updater.update(
        state,
        AttachmentResolved(
          attachmentId: 'new',
          kind: CardKind.image,
          bytes: bytes,
        ),
      );
      expect(next.attachmentId, 'new');
      expect(next.attachmentKind, CardKind.image);
      expect(next.imageBytes, bytes);
      expect(next.attachmentBusy, isFalse);
      expect(effects, isNull);
    });

    test('AttachmentResolved with a file fills name/size, no bytes', () {
      const state = CardEditState(cardId: 'c1', attachmentBusy: true);
      final (next, _) = updater.update(
        state,
        const AttachmentResolved(
          attachmentId: 'new',
          kind: CardKind.file,
          name: 'a.zip',
          size: 10,
        ),
      );
      expect(next.attachmentKind, CardKind.file);
      expect(next.attachmentName, 'a.zip');
      expect(next.attachmentSize, 10);
      expect(next.imageBytes, isNull);
      expect(next.attachmentBusy, isFalse);
    });

    test('AttachmentResolved to null removes the attachment', () {
      final state = CardEditState(
        cardId: 'c1',
        attachmentId: 'old',
        attachmentKind: CardKind.image,
        imageBytes: Uint8List.fromList([1]),
        attachmentBusy: true,
      );
      final (next, effects) =
          updater.update(state, const AttachmentResolved(attachmentId: null));
      expect(next.attachmentId, isNull);
      expect(next.attachmentKind, isNull);
      expect(next.imageBytes, isNull);
      expect(next.attachmentBusy, isFalse);
      expect(effects, isNull);
    });

    test('AttachmentEditEnded just drops the busy flag', () {
      const state = CardEditState(cardId: 'c1', attachmentBusy: true);
      final (next, effects) =
          updater.update(state, const AttachmentEditEnded());
      expect(next.attachmentBusy, isFalse);
      expect(effects, isNull);
    });
  });
}
