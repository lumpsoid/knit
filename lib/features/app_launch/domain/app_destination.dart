/// Where App Launch sends the user once the graph is up (composition.md §3).
enum AppLaunchDestination {
  /// First run (no identity, or no profile yet) → the identity ceremony.
  onboarding,

  /// Returning user → the collections timeline (§4.1).
  timeline,
}

/// Decides the post-init destination (composition.md §3). `resolve()` runs
/// **only after** [InitializationRepository.initialize] completes, so the graph
/// it reads is guaranteed to exist.
abstract interface class AppDestinationResolver {
  Future<AppLaunchDestination> resolve();
}
