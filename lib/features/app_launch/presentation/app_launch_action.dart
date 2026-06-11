/// Intents and async-result deliveries for App Launch (fcis.md §6.4).
sealed class AppLaunchAction {
  const AppLaunchAction();
}

/// View lifecycle (fcis.md §6.8) — kicks off initialization.
class ViewAttached extends AppLaunchAction {
  const ViewAttached();
}

/// The init+resolve cycle finished; the shell has pushed the navigate effect.
class InitializationSucceeded extends AppLaunchAction {
  const InitializationSucceeded();
}

/// Initialization threw; surface a retry.
class InitializationFailed extends AppLaunchAction {
  const InitializationFailed(this.message);
  final String message;
}

/// Retry after a failed init.
class RetryRequested extends AppLaunchAction {
  const RetryRequested();
}

/// View lifecycle (fcis.md §6.8) — no-op teardown signal.
class DeactivateFeature extends AppLaunchAction {
  const DeactivateFeature();
}
