import 'package:knit/features/settings/domain/app_preferences.dart';
import 'package:knit/features/settings/domain/settings_failure.dart';
import 'package:result_dart/result_dart.dart';

/// Narrow read port for Settings (business_logic.md §5): load this device's UI
/// preferences. A first run with nothing persisted yields the defaults, not a
/// failure.
abstract interface class SettingsReadRepository {
  Future<Result<AppPreferences, SettingsFailure>> load();
}
