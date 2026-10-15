import 'package:fcis_core/fcis_core.dart';
import 'package:knit/features/collection_media/presentation/collection_media_action.dart';
import 'package:knit/features/collection_media/presentation/collection_media_effect.dart';
import 'package:knit/features/collection_media/presentation/collection_media_state.dart';

/// The Collection Media FCIS loop (fcis.md §6.8) — super-params only, no logic.
class CollectionMediaLoop
    extends
        FcisLoop<
          CollectionMediaState,
          CollectionMediaAction,
          CollectionMediaEffect
        > {
  CollectionMediaLoop({
    required super.stateHolder,
    required super.updater,
    required super.effectRunner,
  });
}
