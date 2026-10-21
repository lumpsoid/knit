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
    test('seeds id/text, loads links, no attachment when none', () {
      final (next, effects) = updater.update(
        const CardEditState(),
        const ViewAttached(
          cardId: 'c1',
          collectionId: 'col-1',
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
      expect(effects, hasLength(3));
      expect(effects!.whereType<LoadLinksEffect>().single.cardId, 'c1');
      final preview = effects.whereType<LoadTimelinePreviewEffect>().single;
      expect((preview.cardId, preview.collectionId), ('c1', 'col-1'));
      expect(
        effects.whereType<ShowImageEffect>().single.attachmentIds,
        isEmpty,
      );
    });

    test('shows an image attachment through the image cache', () {
      final (next, effects) = updater.update(
        const CardEditState(),
        const ViewAttached(
          cardId: 'c1',
          collectionId: 'col-1',
          initialText: '',
          initialAttachmentId: 'att-1',
          initialAttachmentKind: CardKind.image,
        ),
      );
      expect(next.attachmentId, 'att-1');
      expect(next.attachmentKind, CardKind.image);
      expect(next.attachmentBusy, isFalse);
      expect(effects!.whereType<ShowImageEffect>().single.attachmentIds, [
        'att-1',
      ]);
    });

    test('renders an audio/file attachment from metadata without a load', () {
      final (next, effects) = updater.update(
        const CardEditState(),
        const ViewAttached(
          cardId: 'c1',
          collectionId: 'col-1',
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
      expect(next.attachmentBusy, isFalse); // no image to show
      expect(
        effects!.whereType<ShowImageEffect>().single.attachmentIds,
        isEmpty,
      );
    });
  });

  group('save', () {
    CardEditState attached() =>
        const CardEditState(cardId: 'c1', initialText: 'hello');

    test('SaveRequested emits SaveCardEffect and enters saving', () {
      final (next, effects) = updater.update(
        attached(),
        const SaveRequested('new body'),
      );
      expect(next.status, CardEditStatus.saving);
      final effect = effects!.single as SaveCardEffect;
      expect((effect.cardId, effect.text), ('c1', 'new body'));
    });

    test('surrounding whitespace is trimmed', () {
      final (_, effects) = updater.update(
        attached(),
        const SaveRequested('  trimmed  '),
      );
      expect((effects!.single as SaveCardEffect).text, 'trimmed');
    });

    test('blank / whitespace-only save is dropped', () {
      final (_, effects) = updater.update(
        attached(),
        const SaveRequested('   '),
      );
      expect(effects, isNull);
    });

    test('SaveFailed marks the page failed', () {
      final saving = attached().copyWith(status: CardEditStatus.saving);
      final (next, effects) = updater.update(saving, const SaveFailed());
      expect(next.status, CardEditStatus.failed);
      expect(effects, isNull);
    });
  });

  group('links', () {
    test('LinksLoaded fills the list and clears the spinner', () {
      const loading = CardEditState(cardId: 'c1', linksLoading: true);
      final (next, effects) = updater.update(
        loading,
        LinksLoaded([link('l1')]),
      );
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
      final (_, effects) = updater.update(
        state,
        const RemoveLinkRequested('l1'),
      );
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
    test('PickImageRequested on a file card replaces the file', () {
      const state = CardEditState(
        cardId: 'c1',
        attachmentId: 'old',
        attachmentKind: CardKind.file,
      );
      final (next, effects) = updater.update(state, const PickImageRequested());
      expect(next.attachmentBusy, isTrue);
      final effect = effects!.single as PickImageEffect;
      expect(effect.replacedAttachmentId, 'old');
      expect(effect.keptImageIds, isEmpty);
    });

    test('PickImageRequested on an image card keeps its images', () {
      const state = CardEditState(
        cardId: 'c1',
        attachmentId: 'a1',
        moreAttachmentIds: ['a2'],
        attachmentKind: CardKind.image,
      );
      final (_, effects) = updater.update(state, const PickImageRequested());
      final effect = effects!.single as PickImageEffect;
      expect(effect.keptImageIds, ['a1', 'a2']);
      expect(effect.replacedAttachmentId, isNull);
    });

    test('RemoveImageRequested drops one image, keeping the order', () {
      const state = CardEditState(
        cardId: 'c1',
        attachmentId: 'a1',
        moreAttachmentIds: ['a2', 'a3'],
        attachmentKind: CardKind.image,
      );
      final (next, effects) = updater.update(
        state,
        const RemoveImageRequested('a2'),
      );
      expect(next.attachmentBusy, isTrue);
      final effect = effects!.single as RemoveImageEffect;
      expect(effect.remainingIds, ['a1', 'a3']);
      expect(effect.removedId, 'a2');
    });

    test('RemoveImageRequested for an image the card lacks is a no-op', () {
      const state = CardEditState(
        cardId: 'c1',
        attachmentId: 'a1',
        attachmentKind: CardKind.image,
      );
      final (next, effects) = updater.update(
        state,
        const RemoveImageRequested('zz'),
      );
      expect(next, same(state));
      expect(effects, isNull);
    });

    test('PickFileRequested carries every previous attachment for GC', () {
      const state = CardEditState(
        cardId: 'c1',
        attachmentId: 'old',
        moreAttachmentIds: ['old-2'],
        attachmentKind: CardKind.image,
      );
      final (next, effects) = updater.update(state, const PickFileRequested());
      expect(next.attachmentBusy, isTrue);
      expect((effects!.single as PickFileEffect).previousAttachmentIds, [
        'old',
        'old-2',
      ]);
    });

    test(
      'RemoveAttachmentRequested carries the previous attachment for GC',
      () {
        const state = CardEditState(cardId: 'c1', attachmentId: 'old');
        final (next, effects) = updater.update(
          state,
          const RemoveAttachmentRequested(),
        );
        expect(next.attachmentBusy, isTrue);
        expect(
          (effects!.single as RemoveAttachmentEffect).previousAttachmentIds,
          ['old'],
        );
      },
    );

    test('AttachmentResolved with an image shows it and clears busy', () {
      const state = CardEditState(cardId: 'c1', attachmentBusy: true);
      final (next, effects) = updater.update(
        state,
        const AttachmentResolved(attachmentId: 'new', kind: CardKind.image),
      );
      expect(next.attachmentId, 'new');
      expect(next.attachmentKind, CardKind.image);
      expect(next.attachmentBusy, isFalse);
      expect(effects!.whereType<ShowImageEffect>().single.attachmentIds, [
        'new',
      ]);
    });

    test('AttachmentResolved with several images shows them all', () {
      const state = CardEditState(cardId: 'c1', attachmentBusy: true);
      final (next, effects) = updater.update(
        state,
        const AttachmentResolved(
          attachmentId: 'a1',
          moreAttachmentIds: ['a2'],
          kind: CardKind.image,
        ),
      );
      expect(next.imageIds, ['a1', 'a2']);
      expect(effects!.whereType<ShowImageEffect>().single.attachmentIds, [
        'a1',
        'a2',
      ]);
    });

    test('AttachmentResolved with a file fills name/size, no image', () {
      const state = CardEditState(cardId: 'c1', attachmentBusy: true);
      final (next, effects) = updater.update(
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
      expect(next.attachmentBusy, isFalse);
      expect(
        effects!.whereType<ShowImageEffect>().single.attachmentIds,
        isEmpty,
      );
    });

    test('AttachmentResolved to null removes the attachment', () {
      const state = CardEditState(
        cardId: 'c1',
        attachmentId: 'old',
        attachmentKind: CardKind.image,
        attachmentBusy: true,
      );
      final (next, effects) = updater.update(
        state,
        const AttachmentResolved(attachmentId: null),
      );
      expect(next.attachmentId, isNull);
      expect(next.attachmentKind, isNull);
      expect(next.attachmentBusy, isFalse);
      expect(
        effects!.whereType<ShowImageEffect>().single.attachmentIds,
        isEmpty,
      );
    });

    test('AttachmentEditEnded just drops the busy flag', () {
      const state = CardEditState(cardId: 'c1', attachmentBusy: true);
      final (next, effects) = updater.update(
        state,
        const AttachmentEditEnded(),
      );
      expect(next.attachmentBusy, isFalse);
      expect(effects, isNull);
    });
  });

  group('timeline refresh', () {
    const preview = CardEditState(cardId: 'c1');
    final notPreview = preview.copyWith(isTimelinePreview: false);

    test('assumes the card is the preview until the read resolves', () {
      expect(preview.isTimelinePreview, isTrue);
    });

    test('TimelinePreviewResolved records the answer', () {
      final (next, effects) = updater.update(
        preview,
        const TimelinePreviewResolved(false),
      );
      expect(next.isTimelinePreview, isFalse);
      expect(effects, isNull);
    });

    test('a saved edit of the preview card refreshes the Timeline', () {
      final (_, effects) = updater.update(preview, const SaveSucceeded());
      expect(effects!.single, isA<RefreshTimelineEffect>());
    });

    test('a saved edit of any other card does not', () {
      final (_, effects) = updater.update(notPreview, const SaveSucceeded());
      expect(effects, isNull);
    });

    test('an attachment change on the preview card refreshes the Timeline', () {
      final (_, effects) = updater.update(
        preview,
        const AttachmentResolved(attachmentId: 'a', kind: CardKind.image),
      );
      expect(effects!.whereType<RefreshTimelineEffect>(), hasLength(1));
    });

    test('an attachment change on any other card does not', () {
      final (_, effects) = updater.update(
        notPreview,
        const AttachmentResolved(attachmentId: null),
      );
      expect(effects!.whereType<RefreshTimelineEffect>(), isEmpty);
    });

    test('link edits never refresh the Timeline', () {
      final (_, effects) = updater.update(preview, const LinksChanged());
      expect(effects!.whereType<RefreshTimelineEffect>(), isEmpty);
    });
  });

  test('DeactivateFeature releases the shown image', () {
    final (_, effects) = updater.update(
      const CardEditState(cardId: 'c1'),
      const DeactivateFeature(),
    );
    expect(effects!.single, isA<ReleaseImageEffect>());
  });

  group('settled (§3.3)', () {
    test('ViewAttached seeds the toggle from the carrier', () {
      final (next, _) = updater.update(
        const CardEditState(),
        const ViewAttached(
          cardId: 'c1',
          collectionId: 'col-1',
          initialText: '',
          initialAttachmentId: null,
          initialSettled: true,
        ),
      );
      expect(next.settled, isTrue);
      expect(next.settledBusy, isFalse);
    });

    test('flipping the toggle writes and marks busy', () {
      final (next, effects) = updater.update(
        const CardEditState(cardId: 'c1'),
        const SettledToggled(true),
      );
      expect(next.settledBusy, isTrue);
      expect(next.settled, isFalse, reason: 'flips once the write lands');
      final effect = effects!.single as SetSettledEffect;
      expect(effect.cardId, 'c1');
      expect(effect.settled, isTrue);
    });

    test('a toggle to the current value or while busy is a no-op', () {
      final (_, same) = updater.update(
        const CardEditState(cardId: 'c1', settled: true),
        const SettledToggled(true),
      );
      expect(same, isNull);
      final (_, busy) = updater.update(
        const CardEditState(cardId: 'c1', settledBusy: true),
        const SettledToggled(true),
      );
      expect(busy, isNull);
    });

    test('a resolved write flips it and refreshes a previewed Timeline', () {
      final (next, effects) = updater.update(
        const CardEditState(cardId: 'c1', settledBusy: true),
        const SettledResolved(true),
      );
      expect(next.settled, isTrue);
      expect(next.settledBusy, isFalse);
      expect(effects!.single, isA<RefreshTimelineEffect>());

      final (_, quiet) = updater.update(
        const CardEditState(
          cardId: 'c1',
          settledBusy: true,
          isTimelinePreview: false,
        ),
        const SettledResolved(true),
      );
      expect(quiet, isNull);
    });

    test('a failed write leaves the toggle where it was', () {
      final (next, effects) = updater.update(
        const CardEditState(cardId: 'c1', settledBusy: true),
        const SettledEditFailed(),
      );
      expect(next.settled, isFalse);
      expect(next.settledBusy, isFalse);
      expect(effects, isNull);
    });
  });

  group('emphasized (§3.3)', () {
    test('ViewAttached seeds the toggle from the carrier', () {
      final (next, _) = updater.update(
        const CardEditState(),
        const ViewAttached(
          cardId: 'c1',
          collectionId: 'col-1',
          initialText: '',
          initialAttachmentId: null,
          initialEmphasized: true,
        ),
      );
      expect(next.emphasized, isTrue);
      expect(next.emphasizedBusy, isFalse);
    });

    test('flipping the toggle writes and marks busy', () {
      final (next, effects) = updater.update(
        const CardEditState(cardId: 'c1'),
        const EmphasizedToggled(true),
      );
      expect(next.emphasizedBusy, isTrue);
      expect(next.emphasized, isFalse, reason: 'flips once the write lands');
      final effect = effects!.single as SetEmphasizedEffect;
      expect(effect.cardId, 'c1');
      expect(effect.emphasized, isTrue);
    });

    test('either toggle waits while a settle or emphasis write runs', () {
      final (_, a) = updater.update(
        const CardEditState(cardId: 'c1', settledBusy: true),
        const EmphasizedToggled(true),
      );
      final (_, b) = updater.update(
        const CardEditState(cardId: 'c1', emphasizedBusy: true),
        const SettledToggled(true),
      );
      expect(a, isNull);
      expect(b, isNull);
    });

    test('emphasizing a settled card unsettles it and refreshes home', () {
      final (next, effects) = updater.update(
        const CardEditState(cardId: 'c1', settled: true, emphasizedBusy: true),
        const EmphasizedResolved(true),
      );
      expect(next.emphasized, isTrue);
      expect(next.settled, isFalse);
      expect(effects!.single, isA<RefreshTimelineEffect>());
    });

    test('emphasizing a live card leaves home alone', () {
      final (next, effects) = updater.update(
        const CardEditState(cardId: 'c1', emphasizedBusy: true),
        const EmphasizedResolved(true),
      );
      expect(next.emphasized, isTrue);
      expect(next.emphasizedBusy, isFalse);
      expect(effects, isNull);
    });

    test('settling an emphasized card clears the emphasis', () {
      final (next, _) = updater.update(
        const CardEditState(cardId: 'c1', emphasized: true, settledBusy: true),
        const SettledResolved(true),
      );
      expect(next.settled, isTrue);
      expect(next.emphasized, isFalse);
    });

    test('a failed write drops busy and keeps the toggle', () {
      final (next, effects) = updater.update(
        const CardEditState(cardId: 'c1', emphasizedBusy: true),
        const EmphasizedEditFailed(),
      );
      expect(next.emphasizedBusy, isFalse);
      expect(next.emphasized, isFalse);
      expect(effects, isNull);
    });
  });

  group('optimize image', () {
    const withImage = CardEditState(
      cardId: 'c1',
      attachmentId: 'a1',
      attachmentKind: CardKind.image,
    );

    test('goes busy and swaps the image for a smaller copy', () {
      final (next, effects) = updater.update(
        withImage,
        const OptimizeImageRequested(),
      );
      expect(next.attachmentBusy, isTrue);
      expect(next.optimizingImage, isTrue);
      final effect = effects!.single as OptimizeImageEffect;
      expect(effect.cardId, 'c1');
      expect(effect.attachmentIds, ['a1']);
    });

    test('the phase ends however the edit ends', () {
      final busy = withImage.copyWith(
        attachmentBusy: true,
        optimizingImage: true,
      );
      final (ended, _) = updater.update(busy, const AttachmentEditEnded());
      expect(ended.optimizingImage, isFalse);
      final (resolved, _) = updater.update(
        busy,
        const AttachmentResolved(attachmentId: 'a2', kind: CardKind.image),
      );
      expect(resolved.optimizingImage, isFalse);
    });

    test('ignored for a non-image attachment or mid-edit', () {
      for (final state in [
        withImage.copyWith(attachmentKind: CardKind.file),
        withImage.copyWith(attachmentId: null),
        withImage.copyWith(attachmentBusy: true),
      ]) {
        final (next, effects) = updater.update(
          state,
          const OptimizeImageRequested(),
        );
        expect(next, same(state));
        expect(effects, isNull);
      }
    });
  });
}
