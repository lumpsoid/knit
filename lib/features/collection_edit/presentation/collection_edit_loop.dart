import 'package:fcis_core/fcis_core.dart';
import 'package:knit/features/collection_edit/presentation/collection_edit_action.dart';
import 'package:knit/features/collection_edit/presentation/collection_edit_effect.dart';
import 'package:knit/features/collection_edit/presentation/collection_edit_state.dart';

/// The Collection Edit FCIS loop (fcis.md §6.8) — super-params only, no logic.
class CollectionEditLoop
    extends
        FcisLoop<
          CollectionEditState,
          CollectionEditAction,
          CollectionEditEffect
        > {
  CollectionEditLoop({
    required super.stateHolder,
    required super.updater,
    required super.effectRunner,
  });
}
