# Sync indicator — pending/synced marker (§4.8 / §6.6)

## What's missing

There is no **sync indicator** in the UI — "a small pending/synced marker so
offline never feels broken" (§4.8). The data is already available:
`SyncStore.pendingCount()` returns the count of local ops not yet acked by a
relay (`change_log.acked = 0`, §6.6).

## What to build

- A small, app-wide marker (app bar / status area) showing pending vs synced
  state, driven by `pendingCount()`.
- Until the relay sync path exists, every local op is "pending" (nothing acks
  them) — so the indicator should read sensibly in a relay-less, local-first
  app (e.g. "saved locally" rather than alarming the user).
- Revisit once relay push/pull lands so `acked` actually advances.

## References

- spec §4.8 (sync indicator note), §6.6 (`change_log.acked`, push order by `seq`)
- `SyncStore.pendingCount()` — `lib/sync/storage/sync_store.dart`
- pairs with [relay--push-pull-sync](relay--push-pull-sync.md) (what sets `acked`)
