import 'package:knit/features/settings/domain/app_preferences.dart';
import 'package:knit/features/settings/domain/settings_failure.dart';
import 'package:knit/features/settings/domain/settings_read_repository.dart';
import 'package:knit/features/settings/domain/settings_write_repository.dart';
import 'package:result_dart/result_dart.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The production preferences store, over `shared_preferences` — the device's
/// local UI config, kept out of the synced SQLite/change-log store. One class
/// satisfies both narrow ports (read + write) since it's a single key/value
/// backing.
class SharedPreferencesSettingsRepository
    implements SettingsReadRepository, SettingsWriteRepository {
  const SharedPreferencesSettingsRepository();

  static const _themeKey = 'settings.themeMode';
  static const _languageKey = 'settings.language';

  @override
  Future<Result<AppPreferences, SettingsFailure>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return Ok(
        AppPreferences(
          themeMode: AppThemeMode.fromName(prefs.getString(_themeKey)),
          language: AppLanguage.fromName(prefs.getString(_languageKey)),
        ),
      );
    } catch (e, st) {
      return Failure(PreferencesLoadFailure(e, st));
    }
  }

  @override
  Future<Result<AppPreferences, SettingsFailure>> save(
    AppPreferences preferences,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeKey, preferences.themeMode.name);
      await prefs.setString(_languageKey, preferences.language.name);
      return Ok(preferences);
    } catch (e, st) {
      return Failure(PreferencesSaveFailure(e, st));
    }
  }
}
