import 'package:knit/app/app_graph.dart';
import 'package:knit/features/profile/domain/profile_failure.dart';
import 'package:knit/features/profile/domain/profile_read_repository.dart';
import 'package:knit/features/profile/domain/profile_view.dart';
import 'package:knit/sync/sync.dart';
import 'package:result_dart/result_dart.dart';

/// [ProfileReadRepository] over the graph's [SyncStore]: the device pubkey is
/// the `profile` record id (§7.4.7), so we read it back via [SyncStore.get] for
/// the nickname and derive the fingerprint from the key.
class SyncStoreProfileReadRepository implements ProfileReadRepository {
  SyncStoreProfileReadRepository({required AppGraph graph}) : _graph = graph;

  final AppGraph _graph;

  @override
  Future<Result<ProfileView, ProfileFailure>> load() async {
    try {
      final store = _graph.store;
      final pubkey = await store.authorPubkey();
      final snapshot = await store.get(EntityType.profile, pubkey);
      if (snapshot == null || snapshot.deleted) {
        return const Failure(ProfileLoadFailure('profile record not found'));
      }
      final fingerprint = await store.signer.fingerprintOf(pubkey);
      return Ok(
        ProfileView(
          nickname: (snapshot.content['nickname'] as String?) ?? '',
          publicKeyHex: pubkey,
          fingerprint: fingerprint,
        ),
      );
    } catch (e, st) {
      return Failure(ProfileLoadFailure(e, st));
    }
  }
}
