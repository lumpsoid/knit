import 'package:fcis_core/fcis_core.dart';
import 'package:knit/features/timeline/presentation/timeline_action.dart';
import 'package:knit/features/timeline/presentation/timeline_effect.dart';
import 'package:knit/features/timeline/presentation/timeline_state.dart';

/// The Timeline FCIS loop (fcis.md §6.8) — super-params only, no logic.
class TimelineLoop
    extends FcisLoop<TimelineState, TimelineAction, TimelineEffect> {
  TimelineLoop({
    required super.stateHolder,
    required super.updater,
    required super.effectRunner,
  });
}
