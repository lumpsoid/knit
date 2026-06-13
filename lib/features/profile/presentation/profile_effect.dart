/// Async-work descriptors for the Profile screen (fcis.md §6.4).
sealed class ProfileEffect {
  const ProfileEffect();
}

/// Read the device identity — nickname + fingerprint + public key (§7.4.7).
class LoadProfileEffect extends ProfileEffect {
  const LoadProfileEffect();
}

/// Publish a signed `profile` edit changing the nickname (§6.8).
class RenameProfileEffect extends ProfileEffect {
  const RenameProfileEffect(this.nickname);
  final String nickname;
}
