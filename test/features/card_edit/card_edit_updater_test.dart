import 'package:flutter_test/flutter_test.dart';
import 'package:knit/features/card_edit/presentation/card_edit_action.dart';
import 'package:knit/features/card_edit/presentation/card_edit_effect.dart';
import 'package:knit/features/card_edit/presentation/card_edit_state.dart';
import 'package:knit/features/card_edit/presentation/card_edit_updater.dart';

void main() {
  const updater = CardEditUpdater();

  test('ViewAttached seeds the card id and initial text, no effect', () {
    final (next, effects) = updater.update(
      const CardEditState(),
      const ViewAttached(cardId: 'c1', initialText: 'hello'),
    );
    expect(next.status, CardEditStatus.editing);
    expect(next.cardId, 'c1');
    expect(next.initialText, 'hello');
    expect(effects, isNull);
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

    test('SaveFailed records the message and fails', () {
      final saving = attached().copyWith(status: CardEditStatus.saving);
      final (next, effects) =
          updater.update(saving, const SaveFailed('nope'));
      expect(next.status, CardEditStatus.failed);
      expect(next.errorMessage, 'nope');
      expect(effects, isNull);
    });
  });
}
