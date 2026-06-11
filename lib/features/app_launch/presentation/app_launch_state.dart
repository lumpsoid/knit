import 'package:flutter/foundation.dart';

/// Splash phase. The happy path stays [initializing] until navigation replaces
/// the splash; [failed] surfaces a retry.
enum AppLaunchPhase { initializing, failed }

@immutable
class AppLaunchState {
  const AppLaunchState({
    this.phase = AppLaunchPhase.initializing,
    this.errorMessage,
  });

  final AppLaunchPhase phase;
  final String? errorMessage;

  bool get isFailed => phase == AppLaunchPhase.failed;
}
