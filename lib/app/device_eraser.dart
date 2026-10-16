import 'package:knit/app/app_graph.dart';
import 'package:knit/sync/sync.dart';

/// Clears a device's content across **both** stores that hold it: the
/// [SyncStore] (signed log + projection + quarantine, and optionally the
/// keypair) and the out-of-band, content-addressed blob store for attachment
/// bytes. The attachment hashes are collected from the projection *before* the
/// store is truncated, then their blobs are deleted.
///
/// Shared by Settings "Wipe data" (keeps the identity), Settings "Reset
/// identity" and a restore that replaces this device (both drop the keypair).
class DeviceEraser {
  const DeviceEraser({required AppGraph graph}) : _graph = graph;

  final AppGraph _graph;

  /// Delete every collection, card, link and attachment, keeping the keypair
  /// and the signed profile ([SyncStore.wipe]).
  Future<void> wipeData() => _erase(_graph.store.wipe);

  /// Delete everything including the keypair ([SyncStore.resetDevice]) — the
  /// device is back to a fresh install.
  Future<void> resetDevice() => _erase(_graph.store.resetDevice);

  Future<void> _erase(Future<void> Function() clearStore) async {
    final store = _graph.store;
    final hashes = <String>{};
    for (final attachment in await store.readAll(EntityType.attachment)) {
      final hash =
          attachment.content[AttachmentSchema.colContentHash] as String?;
      if (hash != null && hash.isNotEmpty) hashes.add(hash);
    }

    await clearStore();

    for (final hash in hashes) {
      await _graph.blobStore.delete(hash);
    }
  }
}
