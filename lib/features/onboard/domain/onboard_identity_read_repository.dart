import 'package:knit/features/onboard/domain/identity_card.dart';
import 'package:knit/features/onboard/domain/onboard_failure.dart';
import 'package:result_dart/result_dart.dart';

/// Narrow port: the identity this device now holds, for the reveal after a
/// restore from backup (business_logic.md §5).
abstract interface class OnboardIdentityReadRepository {
  Future<Result<IdentityCard, OnboardFailure>> current();
}
