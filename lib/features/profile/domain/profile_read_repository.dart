import 'package:knit/features/profile/domain/profile_failure.dart';
import 'package:knit/features/profile/domain/profile_view.dart';
import 'package:result_dart/result_dart.dart';

/// Narrow read port for the Profile screen (business_logic.md §5): this device's
/// own identity — nickname (from the signed `profile` record, §7.4.7), plus the
/// derived fingerprint and full public key.
abstract interface class ProfileReadRepository {
  Future<Result<ProfileView, ProfileFailure>> load();
}
