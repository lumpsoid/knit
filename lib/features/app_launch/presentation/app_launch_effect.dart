/// Async-work descriptors for App Launch (fcis.md §6.4), run by the shell.
sealed class AppLaunchEffect {
  const AppLaunchEffect();
}

/// Bring the graph up, then resolve + emit the destination.
class InitializeEffect extends AppLaunchEffect {
  const InitializeEffect();
}
