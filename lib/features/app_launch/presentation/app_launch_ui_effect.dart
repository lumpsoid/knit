import 'package:knit/features/app_launch/domain/app_destination.dart';

/// One-shot UI effects the shell pushes for the splash View (fcis.md §6.4).
sealed class AppLaunchUiEffect {
  const AppLaunchUiEffect();
}

/// Replace the splash with the resolved destination's page.
class AppLaunchNavigateUiEffect extends AppLaunchUiEffect {
  const AppLaunchNavigateUiEffect(this.destination);
  final AppLaunchDestination destination;
}
