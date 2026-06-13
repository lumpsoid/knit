import 'package:knit/features/settings/domain/app_preferences.dart';
import 'package:knit/features/settings/domain/settings_failure.dart';
import 'package:result_dart/result_dart.dart';

/// Narrow write port for Settings (business_logic.md §5): persist the full
/// preference set. Returns the saved [AppPreferences] so the shell can confirm
/// what landed.
abstract interface class SettingsWriteRepository {
  Future<Result<AppPreferences, SettingsFailure>> save(AppPreferences preferences);
}
