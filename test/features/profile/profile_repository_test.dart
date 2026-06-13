import 'package:flutter_test/flutter_test.dart';
import 'package:knit/app/app_graph.dart';
import 'package:knit/features/onboard/infra/sync_store_onboard_repository.dart';
import 'package:knit/features/profile/domain/profile_view.dart';
import 'package:knit/features/profile/infra/sync_store_profile_read_repository.dart';
import 'package:knit/features/profile/infra/sync_store_profile_write_repository.dart';
import 'package:knit/sync/sync.dart';

/// Drives the Profile read/write ports over a real in-memory [SyncStore]: the
/// device pubkey is the `profile` record id (§7.4.7), so a rename is a signed
/// `profile` edit that the read port reflects on the next load.
void main() {
  late AppGraph graph;
  late SyncStore store;
  late SyncStoreOnboardRepository onboard;
  late SyncStoreProfileReadRepository read;
  late SyncStoreProfileWriteRepository write;

  setUp(() async {
    graph = AppGraph();
    store = SyncStore.inMemory();
    await store.open();
    graph.bindStore(store);
    onboard = SyncStoreOnboardRepository(graph: graph);
    read = SyncStoreProfileReadRepository(graph: graph);
    write = SyncStoreProfileWriteRepository(graph: graph);
  });

  test('load fails before an identity/profile exists', () async {
    final result = await read.load();
    expect(result.isSuccess, isFalse);
  });

  test('load returns the onboarded identity', () async {
    final card = (await onboard.createIdentity('mira')).getOrThrow();

    final ProfileView view = (await read.load()).getOrThrow();
    expect(view.nickname, 'mira');
    expect(view.publicKeyHex, card.publicKeyHex);
    expect(view.fingerprint, card.fingerprint);
    expect(view.handle, 'mira#${card.fingerprint}');
  });

  test('rename publishes a profile edit the read port reflects', () async {
    await onboard.createIdentity('mira');

    final renamed = (await write.rename('nova')).getOrThrow();
    expect(renamed.nickname, 'nova');

    final reloaded = (await read.load()).getOrThrow();
    expect(reloaded.nickname, 'nova');
    // The key — the real identity — is immutable across a rename (§5).
    expect(reloaded.publicKeyHex, renamed.publicKeyHex);
    expect(reloaded.fingerprint, renamed.fingerprint);
  });

  test('rename is one more pending local op (§6.6)', () async {
    await onboard.createIdentity('mira'); // 1 op: the profile create
    await write.rename('nova'); // 2nd op: the profile edit
    expect(await store.pendingCount(), 2);
  });
}
