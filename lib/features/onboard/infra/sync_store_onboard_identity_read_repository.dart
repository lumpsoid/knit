import 'package:knit/app/app_graph.dart';
import 'package:knit/features/onboard/domain/identity_card.dart';
import 'package:knit/features/onboard/domain/onboard_failure.dart';
import 'package:knit/features/onboard/domain/onboard_identity_read_repository.dart';
import 'package:knit/sync/sync.dart';
import 'package:result_dart/result_dart.dart';

/// [OnboardIdentityReadRepository] over the graph's [SyncStore]: the device
/// public key, the nickname on its signed `profile` record (§7.4.7), and the
/// fingerprint (§5).
class SyncStoreOnboardIdentityReadRepository
    implements OnboardIdentityReadRepository {
  SyncStoreOnboardIdentityReadRepository({required AppGraph graph})
    : _graph = graph;

  final AppGraph _graph;

  @override
  Future<Result<IdentityCard, OnboardFailure>> current() async {
    try {
      final store = _graph.store;
      final pubkey = await store.authorPubkey();
      final profile = await store.get(EntityType.profile, pubkey);
      return Ok(
        IdentityCard(
          nickname: profile?.content['nickname'] as String? ?? '',
          publicKeyHex: pubkey,
          fingerprint: await store.signer.fingerprintOf(pubkey),
        ),
      );
    } catch (e, st) {
      return Failure(IdentityReadFailure(e, st));
    }
  }
}
