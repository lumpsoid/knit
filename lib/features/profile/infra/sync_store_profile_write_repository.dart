import 'package:knit/app/app_graph.dart';
import 'package:knit/features/profile/domain/profile_failure.dart';
import 'package:knit/features/profile/domain/profile_view.dart';
import 'package:knit/features/profile/domain/profile_write_repository.dart';
import 'package:knit/sync/sync.dart';
import 'package:result_dart/result_dart.dart';

/// [ProfileWriteRepository] over the graph's [SyncStore] §6.8 write path. A
/// rename is one signed `profile` edit (content stamp bumps; `created_by`
/// preserved, §6.2). The projection is updated in the same transaction (§8.5),
/// so we re-read the refreshed view from the committed row.
class SyncStoreProfileWriteRepository implements ProfileWriteRepository {
  SyncStoreProfileWriteRepository({required AppGraph graph}) : _graph = graph;

  final AppGraph _graph;

  @override
  Future<Result<ProfileView, ProfileFailure>> rename(String nickname) async {
    try {
      final store = _graph.store;
      final pubkey = await store.authorPubkey();
      await store.edit(EntityType.profile, pubkey, {'nickname': nickname});
      final fingerprint = await store.signer.fingerprintOf(pubkey);
      return Ok(
        ProfileView(
          nickname: nickname,
          publicKeyHex: pubkey,
          fingerprint: fingerprint,
        ),
      );
    } catch (e, st) {
      return Failure(ProfileRenameFailure(e, st));
    }
  }
}
