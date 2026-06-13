import 'package:knit/features/settings/domain/app_preferences.dart';
import 'package:knit/features/settings/domain/settings_failure.dart';
import 'package:knit/features/settings/domain/settings_read_repository.dart';
import 'package:knit/features/settings/domain/settings_write_repository.dart';
import 'package:result_dart/result_dart.dart';

/// In-memory preferences store for dev mode and tests — no platform channel, so
/// it runs anywhere. Holds the last saved [AppPreferences] for the process
/// lifetime; asserts the same contract as the shared_preferences impl.
class InMemorySettingsRepository
    implements SettingsReadRepository, SettingsWriteRepository {
  InMemorySettingsRepository([AppPreferences initial = const AppPreferences()])
      : _preferences = initial;

  AppPreferences _preferences;

  @override
  Future<Result<AppPreferences, SettingsFailure>> load() async =>
      Ok(_preferences);

  @override
  Future<Result<AppPreferences, SettingsFailure>> save(
    AppPreferences preferences,
  ) async {
    _preferences = preferences;
    return Ok(preferences);
  }
}
