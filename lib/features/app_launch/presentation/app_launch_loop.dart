import 'package:fcis_core/fcis_core.dart';
import 'package:knit/features/app_launch/presentation/app_launch_action.dart';
import 'package:knit/features/app_launch/presentation/app_launch_effect.dart';
import 'package:knit/features/app_launch/presentation/app_launch_state.dart';

/// The App Launch FCIS loop (fcis.md §6.8) — super-params only, no logic.
class AppLaunchLoop
    extends FcisLoop<AppLaunchState, AppLaunchAction, AppLaunchEffect> {
  AppLaunchLoop({
    required super.stateHolder,
    required super.updater,
    required super.effectRunner,
  });
}
