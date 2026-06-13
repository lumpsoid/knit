import 'package:fcis_core/fcis_core.dart';
import 'package:knit/features/card_edit/presentation/card_edit_action.dart';
import 'package:knit/features/card_edit/presentation/card_edit_effect.dart';
import 'package:knit/features/card_edit/presentation/card_edit_state.dart';

/// The Card Edit FCIS loop (fcis.md §6.8) — super-params only, no logic.
class CardEditLoop
    extends FcisLoop<CardEditState, CardEditAction, CardEditEffect> {
  CardEditLoop({
    required super.stateHolder,
    required super.updater,
    required super.effectRunner,
  });
}
