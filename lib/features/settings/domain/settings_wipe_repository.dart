import 'package:result_dart/result_dart.dart';
import 'package:knit/features/settings/domain/settings_failure.dart';

/// Narrow port for the Settings "Wipe data" danger action (§4 Data subpage,
/// business_logic.md §5): delete every collection, card, and link on this
/// device while keeping the device identity (resetting the keypair is a
/// separate action). Returns nothing on success — the data is simply gone.
abstract interface class SettingsWipeRepository {
  Future<Result<void, SettingsFailure>> wipe();
}
