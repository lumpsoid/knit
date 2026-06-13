import 'package:effect_emitter/effect_emitter.dart';
import 'package:fcis_core/fcis_core.dart';
import 'package:logging/logging.dart';
import 'package:knit/features/card_edit/domain/card_edit_failure.dart';
import 'package:knit/features/card_edit/domain/card_edit_write_repository.dart';
import 'package:knit/features/card_edit/presentation/card_edit_action.dart';
import 'package:knit/features/card_edit/presentation/card_edit_effect.dart';
import 'package:knit/features/card_edit/presentation/card_edit_ui_effect.dart';

/// Imperative shell for the Card Edit page (fcis.md §6.6). Unwraps the write
/// [Result] at the seam (result.md §9.3): success pushes the one-shot pop UI
/// effect (the Collection screen resyncs from the projection on return); failure
/// surfaces a message and keeps the page open so the edit isn't lost.
class CardEditShell extends Shell<CardEditEffect, CardEditAction> {
  CardEditShell({
    required CardEditWriteRepository writeRepository,
    required EffectEmitter<CardEditUiEffect> effectEmitter,
    required Logger logger,
  })  : _write = writeRepository,
        _effectEmitter = effectEmitter,
        _log = logger;

  final CardEditWriteRepository _write;
  final EffectEmitter<CardEditUiEffect> _effectEmitter;
  final Logger _log;

  @override
  Future<void> run(
    CardEditEffect effect, {
    required void Function(CardEditAction) dispatch,
  }) async {
    switch (effect) {
      case SaveCardEffect(:final cardId, :final text):
        final result = await _write.editCard(cardId: cardId, text: text);
        result.onTap(
          (_) {
            dispatch(const SaveSucceeded());
            _effectEmitter.push(const CardEditSavedUiEffect());
          },
          (failure) {
            _log.severe('Card edit failed: ${_cause(failure)}');
            _effectEmitter.push(
              const CardEditShowMessageUiEffect(
                "That didn't save. Please try again.",
              ),
            );
            dispatch(const SaveFailed("That didn't save. Please try again."));
          },
        );
    }
  }

  String _cause(CardEditFailure failure) => switch (failure) {
        CardEditWriteFailure(:final cause) => cause,
      };
}
