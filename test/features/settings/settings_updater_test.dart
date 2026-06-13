import 'package:flutter_test/flutter_test.dart';
import 'package:knit/features/settings/domain/app_preferences.dart';
import 'package:knit/features/settings/presentation/settings_action.dart';
import 'package:knit/features/settings/presentation/settings_effect.dart';
import 'package:knit/features/settings/presentation/settings_state.dart';
import 'package:knit/features/settings/presentation/settings_updater.dart';

/// Pure reducer coverage for Settings (fcis.md §6.1).
void main() {
  const updater = SettingsUpdater();

  test('ViewAttached requests a preferences read', () {
    final (next, effects) =
        updater.update(const SettingsState(), const ViewAttached());
    expect(next.preferences, const AppPreferences()); // unchanged
    expect(effects, const [LoadPreferencesEffect()]);
  });

  test('PreferencesLoaded overlays the persisted preferences', () {
    const loaded = AppPreferences(
      themeMode: AppThemeMode.dark,
      language: AppLanguage.russian,
    );
    final (next, effects) =
        updater.update(const SettingsState(), const PreferencesLoaded(loaded));
    expect(next.preferences, loaded);
    expect(effects, isNull);
  });

  test('PreferencesLoadFailed keeps the defaults without effects', () {
    final (next, effects) =
        updater.update(const SettingsState(), const PreferencesLoadFailed());
    expect(next.preferences, const AppPreferences());
    expect(effects, isNull);
  });

  test('ThemeModeSelected applies optimistically and persists', () {
    final (next, effects) = updater.update(
      const SettingsState(),
      const ThemeModeSelected(AppThemeMode.light),
    );
    expect(next.preferences.themeMode, AppThemeMode.light);
    expect(next.preferences.language, AppLanguage.system); // untouched
    expect(effects, isNotNull);
    expect(
      (effects!.single as SavePreferencesEffect).preferences,
      next.preferences,
    );
  });

  test('LanguageSelected applies optimistically and persists', () {
    const prior =
        SettingsState(preferences: AppPreferences(themeMode: AppThemeMode.dark));
    final (next, effects) =
        updater.update(prior, const LanguageSelected(AppLanguage.english));
    expect(next.preferences.language, AppLanguage.english);
    expect(next.preferences.themeMode, AppThemeMode.dark); // untouched
    expect(
      (effects!.single as SavePreferencesEffect).preferences,
      next.preferences,
    );
  });

  test('PreferencesSaveFailed leaves the optimistic state intact', () {
    const prior =
        SettingsState(preferences: AppPreferences(themeMode: AppThemeMode.dark));
    final (next, effects) =
        updater.update(prior, const PreferencesSaveFailed());
    expect(next.preferences.themeMode, AppThemeMode.dark);
    expect(effects, isNull);
  });

  test('DataActionRequested routes through to a data-action effect', () {
    final (next, effects) = updater.update(
      const SettingsState(),
      const DataActionRequested(DataAction.exportData),
    );
    expect(next.preferences, const AppPreferences()); // no state change
    expect(
      (effects!.single as RunDataActionEffect).action,
      DataAction.exportData,
    );
  });
}
