/// Per-feature failure family for Settings (result.md §9.3). Carries the
/// original [error] (and [stackTrace] when caught) so the shell logs the real
/// cause, not a re-typed summary.
sealed class SettingsFailure {
  const SettingsFailure(this.error, [this.stackTrace]);

  final Object error;
  final StackTrace? stackTrace;
}

/// Reading the persisted preferences failed.
class PreferencesLoadFailure extends SettingsFailure {
  const PreferencesLoadFailure(super.error, [super.stackTrace]);
}

/// Persisting a preference change failed (the in-memory choice still stands for
/// this session; only persistence was lost).
class PreferencesSaveFailure extends SettingsFailure {
  const PreferencesSaveFailure(super.error, [super.stackTrace]);
}
