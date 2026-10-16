import 'package:result_dart/result_dart.dart';
import 'package:knit/app/app_graph.dart';
import 'package:knit/app/device_eraser.dart';
import 'package:knit/features/settings/domain/settings_failure.dart';
import 'package:knit/features/settings/domain/settings_identity_read_repository.dart';
import 'package:knit/features/settings/domain/settings_identity_reset_repository.dart';
import 'package:knit/sync/sync.dart';

/// [SettingsIdentityReadRepository] over the graph's [SyncStore]: the nickname
/// on this device's signed `profile` record (`id == pubkey`, §7.4.7).
class SyncStoreSettingsIdentityReadRepository
    implements SettingsIdentityReadRepository {
  SyncStoreSettingsIdentityReadRepository({required AppGraph graph})
    : _graph = graph;

  final AppGraph _graph;

  @override
  Future<Result<String, SettingsFailure>> nickname() async {
    try {
      final store = _graph.store;
      final profile = await store.get(
        EntityType.profile,
        await store.authorPubkey(),
      );
      return Ok(profile?.content['nickname'] as String? ?? '');
    } catch (e, st) {
      return Failure(IdentityReadFailure(e, st));
    }
  }
}

/// [SettingsIdentityResetRepository] over the graph's [DeviceEraser]: clears
/// the store, the attachment blobs and the keypair.
class SyncStoreSettingsIdentityResetRepository
    implements SettingsIdentityResetRepository {
  SyncStoreSettingsIdentityResetRepository({required AppGraph graph})
    : _eraser = DeviceEraser(graph: graph);

  final DeviceEraser _eraser;

  @override
  Future<Result<void, SettingsFailure>> reset() async {
    try {
      await _eraser.resetDevice();
      return const Ok<void, SettingsFailure>(null);
    } catch (e, st) {
      return Failure(ResetIdentityFailure(e, st));
    }
  }
}
