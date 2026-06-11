import 'package:knit/features/onboard/domain/identity_card.dart';
import 'package:knit/features/onboard/domain/onboard_failure.dart';
import 'package:result_dart/result_dart.dart';

/// Narrow port for the onboarding ceremony (business_logic.md §5). The single
/// fallible op returns a [Result] (result.md §9.3).
abstract interface class OnboardRepository {
  /// Provision the device keypair (spec §5/§6.5) and publish the signed
  /// `profile` record (`id == pubkey`, §7.4.7), returning the new identity for
  /// the reveal step. Idempotent if rerun (resumed onboarding).
  Future<Result<IdentityCard, OnboardFailure>> createIdentity(String nickname);
}
