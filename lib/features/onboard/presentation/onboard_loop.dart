import 'package:fcis_core/fcis_core.dart';
import 'package:knit/features/onboard/presentation/onboard_action.dart';
import 'package:knit/features/onboard/presentation/onboard_effect.dart';
import 'package:knit/features/onboard/presentation/onboard_state.dart';

/// The Onboard FCIS loop (fcis.md §6.8) — super-params only, no logic.
class OnboardLoop extends FcisLoop<OnboardState, OnboardAction, OnboardEffect> {
  OnboardLoop({
    required super.stateHolder,
    required super.updater,
    required super.effectRunner,
  });
}
