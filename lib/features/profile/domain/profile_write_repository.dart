import 'package:knit/features/profile/domain/profile_failure.dart';
import 'package:knit/features/profile/domain/profile_view.dart';
import 'package:result_dart/result_dart.dart';

/// Narrow write port for the Profile screen (business_logic.md §5). Renaming is
/// one signed local `profile` edit through the §6.8 path; the public key is
/// immutable, so only the nickname changes. Returns the refreshed [ProfileView].
abstract interface class ProfileWriteRepository {
  Future<Result<ProfileView, ProfileFailure>> rename(String nickname);
}
