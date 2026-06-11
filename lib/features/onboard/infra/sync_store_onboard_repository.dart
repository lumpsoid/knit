import 'package:knit/app/app_graph.dart';
import 'package:knit/features/onboard/domain/identity_card.dart';
import 'package:knit/features/onboard/domain/onboard_failure.dart';
import 'package:knit/features/onboard/domain/onboard_repository.dart';
import 'package:knit/sync/sync.dart';
import 'package:result_dart/result_dart.dart';

/// [OnboardRepository] over the graph's [SyncStore]: the "Generate" step
/// provisions the device identity (§5/§6.5) and writes the signed `profile`
/// record carrying the chosen nickname (§7.4.7), then reports the fingerprint
/// for the reveal.
class SyncStoreOnboardRepository implements OnboardRepository {
  SyncStoreOnboardRepository({required AppGraph graph}) : _graph = graph;

  final AppGraph _graph;

  @override
  Future<Result<IdentityCard, OnboardFailure>> createIdentity(
    String nickname,
  ) async {
    try {
      final store = _graph.store;
      final pubkey = await store.provisionIdentity();
      await store.create(EntityType.profile, pubkey, {'nickname': nickname});
      final fingerprint = await store.signer.fingerprintOf(pubkey);
      return Ok(
        IdentityCard(
          nickname: nickname,
          publicKeyHex: pubkey,
          fingerprint: fingerprint,
        ),
      );
    } catch (e) {
      return Failure(IdentityCreationFailure(e.toString()));
    }
  }
}
