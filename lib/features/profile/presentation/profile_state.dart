import 'package:flutter/foundation.dart';
import 'package:knit/features/profile/domain/profile_view.dart';

/// Lifecycle of the Profile screen's identity read (fcis.md §6.1).
enum ProfilePhase { loading, ready, failed }

@immutable
class ProfileState {
  const ProfileState({
    this.phase = ProfilePhase.loading,
    this.profile,
    this.isSaving = false,
  });

  final ProfilePhase phase;

  /// The loaded identity (null until the first read lands).
  final ProfileView? profile;

  /// A rename is in flight — the View disables the edit affordance.
  final bool isSaving;

  ProfileState copyWith({
    ProfilePhase? phase,
    ProfileView? profile,
    bool? isSaving,
  }) => ProfileState(
    phase: phase ?? this.phase,
    profile: profile ?? this.profile,
    isSaving: isSaving ?? this.isSaving,
  );
}
