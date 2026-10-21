import 'package:flutter_test/flutter_test.dart';
import 'package:knit/features/backup/domain/backup_models.dart';
import 'package:knit/features/settings/domain/app_preferences.dart';
import 'package:knit/features/settings/presentation/settings_action.dart';
import 'package:knit/features/settings/presentation/settings_effect.dart';
import 'package:knit/features/settings/presentation/settings_state.dart';
import 'package:knit/features/settings/presentation/settings_updater.dart';

/// Pure reducer coverage for Settings (fcis.md §6.1).
void main() {
  const updater = SettingsUpdater();

  test('ViewAttached requests a preferences read', () {
    final (next, effects) = updater.update(
      const SettingsState(),
      const ViewAttached(),
    );
    expect(next.preferences, const AppPreferences()); // unchanged
    expect(effects, const [LoadPreferencesEffect()]);
  });

  test('PreferencesLoaded overlays the persisted preferences', () {
    const loaded = AppPreferences(
      themeMode: AppThemeMode.dark,
      language: AppLanguage.russian,
    );
    final (next, effects) = updater.update(
      const SettingsState(),
      const PreferencesLoaded(loaded),
    );
    expect(next.preferences, loaded);
    expect(effects, isNull);
  });

  test('PreferencesLoadFailed keeps the defaults without effects', () {
    final (next, effects) = updater.update(
      const SettingsState(),
      const PreferencesLoadFailed(),
    );
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
    const prior = SettingsState(
      preferences: AppPreferences(themeMode: AppThemeMode.dark),
    );
    final (next, effects) = updater.update(
      prior,
      const LanguageSelected(AppLanguage.english),
    );
    expect(next.preferences.language, AppLanguage.english);
    expect(next.preferences.themeMode, AppThemeMode.dark); // untouched
    expect(
      (effects!.single as SavePreferencesEffect).preferences,
      next.preferences,
    );
  });

  test('KeepPhotoMetadataToggled applies at once and persists', () {
    const prior = SettingsState(
      preferences: AppPreferences(themeMode: AppThemeMode.dark),
    );
    expect(prior.preferences.keepPhotoMetadata, isTrue); // on by default
    final (next, effects) = updater.update(
      prior,
      const KeepPhotoMetadataToggled(false),
    );
    expect(next.preferences.keepPhotoMetadata, isFalse);
    expect(next.preferences.themeMode, AppThemeMode.dark); // untouched
    expect(
      (effects!.single as SavePreferencesEffect).preferences,
      next.preferences,
    );
  });

  test('PreferencesSaveFailed leaves the optimistic state intact', () {
    const prior = SettingsState(
      preferences: AppPreferences(themeMode: AppThemeMode.dark),
    );
    final (next, effects) = updater.update(
      prior,
      const PreferencesSaveFailed(),
    );
    expect(next.preferences.themeMode, AppThemeMode.dark);
    expect(effects, isNull);
  });

  test('DataActionRequested(import) sets busy and runs the data action', () {
    final (next, effects) = updater.update(
      const SettingsState(),
      const DataActionRequested(DataAction.importData),
    );
    expect(next.busy, isTrue);
    expect(
      (effects!.single as RunDataActionEffect).action,
      DataAction.importData,
    );
  });

  test(
    'ExportRequested sets busy and runs the export with its destination',
    () {
      final (next, effects) = updater.update(
        const SettingsState(),
        const ExportRequested(BackupDestination.saveFile, 'passphrase'),
      );
      expect(next.busy, isTrue);
      final effect = effects!.single as RunExportEffect;
      expect(effect.destination, BackupDestination.saveFile);
      expect(effect.passphrase, 'passphrase');
    },
  );

  group('replacing the device', () {
    const bundle = BackupBundle(
      author: 'aaaa',
      createdAtMs: 0,
      identity: null,
      opLines: [],
      blobs: {},
    );

    test('a held bundle runs the replace on confirm', () {
      final (held, _) = updater.update(
        const SettingsState(),
        const RestoreAwaitingPassphrase(bundle),
      );
      expect(held.pendingRestore, same(bundle));

      final (next, effects) = updater.update(
        held,
        const ReplaceDeviceConfirmed('pass'),
      );
      expect(next.busy, isTrue);
      final effect = effects!.single as RunReplaceDeviceEffect;
      expect(effect.bundle, same(bundle));
      expect(effect.passphrase, 'pass');
    });

    test('confirm without a held bundle does nothing', () {
      final (next, effects) = updater.update(
        const SettingsState(),
        const ReplaceDeviceConfirmed('pass'),
      );
      expect(next.busy, isFalse);
      expect(effects, isNull);
    });

    test('cancel and settle drop the held bundle', () {
      const held = SettingsState(pendingRestore: bundle);
      for (final action in const [ReplaceDeviceCancelled(), RestoreSettled()]) {
        final (next, _) = updater.update(held, action);
        expect(next.pendingRestore, isNull);
      }
    });
  });

  test('ResetIdentityConfirmed sets busy and runs the reset', () {
    final (next, effects) = updater.update(
      const SettingsState(),
      const ResetIdentityConfirmed(),
    );
    expect(next.busy, isTrue);
    expect(effects!.single, isA<RunResetIdentityEffect>());
  });

  test('DataActionFinished clears busy', () {
    final (next, effects) = updater.update(
      const SettingsState(busy: true),
      const DataActionFinished(),
    );
    expect(next.busy, isFalse);
    expect(effects, isNull);
  });
}
