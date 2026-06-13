import 'package:fcis_core/fcis_core.dart';
import 'package:knit/features/card_edit/presentation/card_edit_action.dart';
import 'package:knit/features/card_edit/presentation/card_edit_effect.dart';
import 'package:knit/features/card_edit/presentation/card_edit_state.dart';

/// Pure reducer for the Card Edit page (fcis.md §6.1). A blank/whitespace-only
/// body is dropped (matching the Collection screen's blank-edit behaviour);
/// otherwise the trimmed body is handed to the shell as a [SaveCardEffect] and
/// the page enters [CardEditStatus.saving].
class CardEditUpdater
    implements Updater<CardEditState, CardEditAction, CardEditEffect> {
  const CardEditUpdater();

  @override
  (CardEditState, List<CardEditEffect>?) update(
    CardEditState state,
    CardEditAction action,
  ) {
    switch (action) {
      case ViewAttached(:final cardId, :final initialText):
        return (
          state.copyWith(
            status: CardEditStatus.editing,
            cardId: cardId,
            initialText: initialText,
          ),
          null,
        );

      case SaveRequested(:final text):
        final body = text.trim();
        if (body.isEmpty) return (state, null);
        return (
          state.copyWith(status: CardEditStatus.saving),
          [SaveCardEffect(state.cardId, body)],
        );

      case SaveSucceeded():
        return (state, null);

      case SaveFailed(:final message):
        return (
          state.copyWith(
            status: CardEditStatus.failed,
            errorMessage: message,
          ),
          null,
        );

      case DeactivateFeature():
        return (state, null);
    }
  }
}
