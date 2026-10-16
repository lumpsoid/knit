import 'package:result_dart/result_dart.dart';
import 'package:knit/features/settings/domain/settings_failure.dart';

/// Narrow port for the Settings "Reset identity" danger action: erase every
/// collection, card, link and attachment **and the keypair**, returning the
/// device to a fresh install (the data is signed by the key, so they go
/// together). Onboarding follows.
abstract interface class SettingsIdentityResetRepository {
  Future<Result<void, SettingsFailure>> reset();
}
