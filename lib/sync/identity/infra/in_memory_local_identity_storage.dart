import 'package:knit/core/storage/domain/storage_context.dart';
import 'package:knit/sync/identity/domain/domain.dart';

/// In-memory [LocalIdentityStorage] for dev mode and tests.
class InMemoryLocalIdentityStorage implements LocalIdentityStorage {
  LocalIdentity? _identity;

  @override
  Future<void> ensureSchema({StorageContext? ctx}) async {}

  @override
  Future<LocalIdentity?> load({StorageContext? ctx}) async => _identity;

  @override
  Future<void> save(LocalIdentity identity, {StorageContext? ctx}) async =>
      _identity = identity;

  @override
  Future<void> clear({StorageContext? ctx}) async => _identity = null;
}
