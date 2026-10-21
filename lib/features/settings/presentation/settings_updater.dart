import 'package:fcis_core/fcis_core.dart';
import 'package:knit/features/settings/presentation/settings_action.dart';
import 'package:knit/features/settings/presentation/settings_effect.dart';
import 'package:knit/features/settings/presentation/settings_state.dart';

/// Pure reducer for Settings (fcis.md §6.1). Theme/language changes apply
/// optimistically (the app reacts at once) and then persist; a failed save
/// leaves the optimistic state untouched — only persistence was lost.
class SettingsUpdater
    implements Updater<SettingsState, SettingsAction, SettingsEffect> {
  const SettingsUpdater();

  @override
  (SettingsState, List<SettingsEffect>?) update(
    SettingsState state,
    SettingsAction action,
  ) {
    switch (action) {
      case ViewAttached():
        return (state, const [LoadPreferencesEffect()]);
      case PreferencesLoaded(:final preferences):
        return (state.copyWith(preferences: preferences), null);
      case PreferencesLoadFailed():
        return (state, null);
      case ThemeModeSelected(:final themeMode):
        final next = state.preferences.copyWith(themeMode: themeMode);
        return (
          state.copyWith(preferences: next),
          [SavePreferencesEffect(next)],
        );
      case LanguageSelected(:final language):
        final next = state.preferences.copyWith(language: language);
        return (
          state.copyWith(preferences: next),
          [SavePreferencesEffect(next)],
        );
      case KeepPhotoMetadataToggled(:final keep):
        final next = state.preferences.copyWith(keepPhotoMetadata: keep);
        return (
          state.copyWith(preferences: next),
          [SavePreferencesEffect(next)],
        );
      case PreferencesSaved(:final preferences):
        return (state.copyWith(preferences: preferences), null);
      case PreferencesSaveFailed():
        return (state, null);
      case ExportRequested(:final destination, :final passphrase):
        // A long build+deliver — show the spinner until DataActionFinished.
        return (
          state.copyWith(busy: true),
          [RunExportEffect(destination, passphrase)],
        );
      case DataActionRequested(:final action):
        // Every data action touches the store; the spinner holds until the
        // shell reports DataActionFinished.
        return (state.copyWith(busy: true), [RunDataActionEffect(action)]);
      case RestoreAwaitingPassphrase(:final bundle):
        return (state.copyWith(pendingRestore: bundle), null);
      case ReplaceDeviceConfirmed(:final passphrase):
        final bundle = state.pendingRestore;
        if (bundle == null) return (state, null);
        return (
          state.copyWith(busy: true),
          [RunReplaceDeviceEffect(bundle, passphrase)],
        );
      case ReplaceDeviceCancelled():
      case RestoreSettled():
        return (state.copyWith(clearPendingRestore: true), null);
      case ResetIdentityConfirmed():
        return (state.copyWith(busy: true), const [RunResetIdentityEffect()]);
      case DataActionFinished():
        return (state.copyWith(busy: false), null);
    }
  }
}
