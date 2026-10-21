import 'package:flutter_test/flutter_test.dart';
import 'package:knit/features/settings/domain/app_preferences.dart';
import 'package:knit/features/settings/infra/in_memory_settings_repository.dart';

/// Contract coverage for the in-memory preferences store. The
/// shared_preferences impl asserts the same shape on a real device; here we use
/// the in-memory one so no platform channel is needed.
void main() {
  test('a fresh store loads the defaults, not a failure', () async {
    final repo = InMemorySettingsRepository();
    final result = await repo.load();
    expect(result.isSuccess, isTrue);
    expect(result.getOrThrow(), const AppPreferences());
  });

  test('save round-trips through load', () async {
    final repo = InMemorySettingsRepository();
    const prefs = AppPreferences(
      themeMode: AppThemeMode.dark,
      language: AppLanguage.russian,
      keepPhotoMetadata: false,
    );

    final saved = await repo.save(prefs);
    expect(saved.getOrThrow(), prefs);

    final loaded = await repo.load();
    expect(loaded.getOrThrow(), prefs);
  });

  test('a later save overwrites the earlier one', () async {
    final repo = InMemorySettingsRepository(
      const AppPreferences(themeMode: AppThemeMode.light),
    );
    await repo.save(const AppPreferences(themeMode: AppThemeMode.dark));
    final loaded = await repo.load();
    expect(loaded.getOrThrow().themeMode, AppThemeMode.dark);
  });

  group('AppThemeMode.fromName', () {
    test('parses known names and falls back to system', () {
      expect(AppThemeMode.fromName('dark'), AppThemeMode.dark);
      expect(AppThemeMode.fromName(null), AppThemeMode.system);
      expect(AppThemeMode.fromName('nonsense'), AppThemeMode.system);
    });
  });

  group('AppLanguage.fromName', () {
    test('parses known names and falls back to system', () {
      expect(AppLanguage.fromName('russian'), AppLanguage.russian);
      expect(AppLanguage.fromName(null), AppLanguage.system);
      expect(AppLanguage.fromName('nonsense'), AppLanguage.system);
    });
  });
}
