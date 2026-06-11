import 'package:knit/core/storage/domain/storage_context.dart';
import 'package:knit/sync/identity/domain/local_identity.dart';

/// Persists the single on-device identity (spec §6.5), abstracted like the other
/// storages. v1 holds exactly one local identity.
abstract class LocalIdentityStorage {
  Future<void> ensureSchema({StorageContext? ctx});

  /// The provisioned identity, or null on a fresh device.
  Future<LocalIdentity?> load({StorageContext? ctx});

  /// Persist the identity (upsert by public key).
  Future<void> save(LocalIdentity identity, {StorageContext? ctx});

  Future<void> clear({StorageContext? ctx});
}
