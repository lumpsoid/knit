import 'package:fcis_core/fcis_core.dart';
import 'package:knit/features/app_launch/presentation/app_launch_action.dart';
import 'package:knit/features/app_launch/presentation/app_launch_effect.dart';
import 'package:knit/features/app_launch/presentation/app_launch_state.dart';

/// Pure reducer for App Launch (fcis.md §6.1). Navigation is a shell-pushed
/// UiEffect, so [InitializationSucceeded] is a no-op here.
class AppLaunchUpdater
    implements Updater<AppLaunchState, AppLaunchAction, AppLaunchEffect> {
  const AppLaunchUpdater();

  @override
  (AppLaunchState, List<AppLaunchEffect>?) update(
    AppLaunchState state,
    AppLaunchAction action,
  ) {
    switch (action) {
      case ViewAttached():
      case RetryRequested():
        return (const AppLaunchState(), const [InitializeEffect()]);
      case InitializationSucceeded():
        return (state, null);
      case InitializationFailed(:final message):
        return (
          AppLaunchState(
            phase: AppLaunchPhase.failed,
            errorMessage: message,
          ),
          null,
        );
      case DeactivateFeature():
        return (state, null);
    }
  }
}
