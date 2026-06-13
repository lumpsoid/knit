import 'package:flutter_test/flutter_test.dart';
import 'package:knit/features/profile/domain/profile_view.dart';
import 'package:knit/features/profile/presentation/profile_action.dart';
import 'package:knit/features/profile/presentation/profile_effect.dart';
import 'package:knit/features/profile/presentation/profile_state.dart';
import 'package:knit/features/profile/presentation/profile_updater.dart';

/// Pure reducer coverage for the Profile screen (fcis.md §6.1).
void main() {
  const updater = ProfileUpdater();
  const sample = ProfileView(
    nickname: 'mira',
    publicKeyHex: 'ab12',
    fingerprint: 'a4f9',
  );

  test('ViewAttached requests an identity read', () {
    final (next, effects) =
        updater.update(const ProfileState(), const ViewAttached());
    expect(next.phase, ProfilePhase.loading);
    expect(effects, const [LoadProfileEffect()]);
  });

  test('RefreshRequested keeps the last known profile while loading', () {
    const prior = ProfileState(phase: ProfilePhase.ready, profile: sample);
    final (next, effects) = updater.update(prior, const RefreshRequested());
    expect(next.phase, ProfilePhase.loading);
    expect(next.profile, sample); // reused — no flicker on retry
    expect(effects, const [LoadProfileEffect()]);
  });

  test('ProfileLoaded becomes ready with the identity', () {
    final (next, effects) = updater.update(
      const ProfileState(phase: ProfilePhase.loading),
      const ProfileLoaded(sample),
    );
    expect(next.phase, ProfilePhase.ready);
    expect(next.profile, sample);
    expect(next.isSaving, isFalse);
    expect(effects, isNull);
  });

  test('ProfileLoadFailed marks the screen failed without effects', () {
    final (next, effects) = updater.update(
      const ProfileState(phase: ProfilePhase.loading),
      const ProfileLoadFailed(),
    );
    expect(next.phase, ProfilePhase.failed);
    expect(effects, isNull);
  });

  test('RenameRequested flags saving and emits the write effect', () {
    final (next, effects) = updater.update(
      const ProfileState(phase: ProfilePhase.ready, profile: sample),
      const RenameRequested('nova'),
    );
    expect(next.isSaving, isTrue);
    expect(effects, isNotNull);
    expect(effects!.single, isA<RenameProfileEffect>());
    expect((effects.single as RenameProfileEffect).nickname, 'nova');
  });

  test('RenameSucceeded swaps in the refreshed identity and clears saving', () {
    const renamed = ProfileView(
      nickname: 'nova',
      publicKeyHex: 'ab12',
      fingerprint: 'a4f9',
    );
    final (next, effects) = updater.update(
      const ProfileState(
          phase: ProfilePhase.ready, profile: sample, isSaving: true),
      const RenameSucceeded(renamed),
    );
    expect(next.phase, ProfilePhase.ready);
    expect(next.profile, renamed);
    expect(next.isSaving, isFalse);
    expect(effects, isNull);
  });

  test('RenameFailed clears the saving flag, keeping the prior profile', () {
    final (next, effects) = updater.update(
      const ProfileState(
          phase: ProfilePhase.ready, profile: sample, isSaving: true),
      const RenameFailed(),
    );
    expect(next.isSaving, isFalse);
    expect(next.profile, sample);
    expect(effects, isNull);
  });
}
