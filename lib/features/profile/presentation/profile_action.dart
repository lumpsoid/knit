import 'package:knit/features/profile/domain/profile_view.dart';

/// Intents + async-result deliveries for the Profile screen (fcis.md §6.4).
sealed class ProfileAction {
  const ProfileAction();
}

/// The page mounted — load the device identity.
class ViewAttached extends ProfileAction {
  const ViewAttached();
}

/// Re-read the identity (pull-to-refresh / retry).
class RefreshRequested extends ProfileAction {
  const RefreshRequested();
}

/// The identity was read.
class ProfileLoaded extends ProfileAction {
  const ProfileLoaded(this.profile);
  final ProfileView profile;
}

/// Reading the identity failed.
class ProfileLoadFailed extends ProfileAction {
  const ProfileLoadFailed();
}

/// The user submitted a new nickname.
class RenameRequested extends ProfileAction {
  const RenameRequested(this.nickname);
  final String nickname;
}

/// The rename committed; carries the refreshed identity.
class RenameSucceeded extends ProfileAction {
  const RenameSucceeded(this.profile);
  final ProfileView profile;
}

/// The rename failed (the prior nickname stays).
class RenameFailed extends ProfileAction {
  const RenameFailed();
}

/// The page is leaving — reset transient flags.
class DeactivateFeature extends ProfileAction {
  const DeactivateFeature();
}
