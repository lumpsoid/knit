import 'package:flutter_test/flutter_test.dart';
import 'package:knit/features/app_launch/presentation/app_launch_action.dart';
import 'package:knit/features/app_launch/presentation/app_launch_effect.dart';
import 'package:knit/features/app_launch/presentation/app_launch_state.dart';
import 'package:knit/features/app_launch/presentation/app_launch_updater.dart';

void main() {
  const updater = AppLaunchUpdater();

  test('ViewAttached requests initialization', () {
    final (next, effects) =
        updater.update(const AppLaunchState(), const ViewAttached());
    expect(next.phase, AppLaunchPhase.initializing);
    expect(effects, const [InitializeEffect()]);
  });

  test('Retry re-requests initialization from a clean state', () {
    const failed = AppLaunchState(
        phase: AppLaunchPhase.failed, errorMessage: 'boom');
    final (next, effects) = updater.update(failed, const RetryRequested());
    expect(next.phase, AppLaunchPhase.initializing);
    expect(next.errorMessage, isNull);
    expect(effects, const [InitializeEffect()]);
  });

  test('failure surfaces a retryable error', () {
    final (next, effects) = updater.update(
      const AppLaunchState(),
      const InitializationFailed('disk full'),
    );
    expect(next.isFailed, isTrue);
    expect(next.errorMessage, 'disk full');
    expect(effects, isNull);
  });

  test('success is a no-op (navigation is a shell UiEffect)', () {
    final (next, effects) = updater.update(
      const AppLaunchState(),
      const InitializationSucceeded(),
    );
    expect(next.phase, AppLaunchPhase.initializing);
    expect(effects, isNull);
  });
}
