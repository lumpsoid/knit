import 'package:fcis_core/fcis_core.dart';
import 'package:knit/features/collection/presentation/collection_action.dart';
import 'package:knit/features/collection/presentation/collection_effect.dart';
import 'package:knit/features/collection/presentation/collection_state.dart';

/// The Collection FCIS loop (fcis.md §6.8) — super-params only, no logic.
class CollectionLoop
    extends FcisLoop<CollectionState, CollectionAction, CollectionEffect> {
  CollectionLoop({
    required super.stateHolder,
    required super.updater,
    required super.effectRunner,
  });
}
