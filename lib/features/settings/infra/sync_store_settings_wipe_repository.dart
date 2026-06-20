import 'package:result_dart/result_dart.dart';
import 'package:knit/app/app_graph.dart';
import 'package:knit/features/settings/domain/settings_failure.dart';
import 'package:knit/features/settings/domain/settings_wipe_repository.dart';
import 'package:knit/sync/sync.dart';

/// [SettingsWipeRepository] over the graph's [SyncStore] + blob store.
///
/// Two stores hold a device's content: the [SyncStore] (signed log + projection
/// + quarantine) and the out-of-band, content-addressed blob store for
/// attachment bytes. Wiping clears both — the attachment hashes are collected
/// from the projection *before* [SyncStore.wipe] truncates it, then their blobs
/// are deleted. The device identity is intentionally untouched.
class SyncStoreSettingsWipeRepository implements SettingsWipeRepository {
  SyncStoreSettingsWipeRepository({required AppGraph graph}) : _graph = graph;

  final AppGraph _graph;

  @override
  Future<Result<void, SettingsFailure>> wipe() async {
    try {
      final store = _graph.store;

      // Snapshot the attachment blob hashes before the metadata rows are gone.
      final hashes = <String>{};
      for (final attachment in await store.readAll(EntityType.attachment)) {
        final hash =
            attachment.content[AttachmentSchema.colContentHash] as String?;
        if (hash != null && hash.isNotEmpty) hashes.add(hash);
      }

      await store.wipe();

      for (final hash in hashes) {
        await _graph.blobStore.delete(hash);
      }

      return const Ok<void, SettingsFailure>(null);
    } catch (e, st) {
      return Failure(WipeDataFailure(e, st));
    }
  }
}
