import 'package:result_dart/result_dart.dart';
import 'package:knit/features/settings/domain/settings_failure.dart';

/// Narrow port for the Settings "Reset identity" confirmation: this device's
/// nickname (empty when it has none).
abstract interface class SettingsIdentityReadRepository {
  Future<Result<String, SettingsFailure>> nickname();
}
