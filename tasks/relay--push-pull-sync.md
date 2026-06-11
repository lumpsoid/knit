# Relay push/pull sync — client path (§7.5 / §9.2)

## What's missing

The app is **local-first with no sync** today. The `origin='remote'` apply path,
signature verify, and skew quarantine already exist in the engine — what's
missing is the **client push/pull loop** against a relay. (The Go relay server
itself is out of scope for this repo — it's a dumb router.)

## What to build

- Add `sync_state` (relay, topic, `cursor`, `last_push_at`, `last_pull_at`,
  §6.6) storage following the repo's two-impl convention.
- **Push:** order local ops by `change_log.seq`, `POST .../push`, and on ack set
  `acked = 1` (this is what makes the [sync indicator](sync-indicator--pending-marker.md)
  meaningful).
- **Pull:** `GET .../pull?since={cursor}`, verify `sig` against `author`,
  reject/quarantine bad ops, merge, then advance `sync_state.cursor` **only**
  past ops durably applied **or** quarantined (§8.8). `op_id` makes replays
  idempotent.
- Optional §8.5-step-3 `hint_mismatch` cross-check.

## Blocked on / pairs with

- the share flow + capability tokens (§10) — see [share--publish-flow](share--publish-flow.md)
- drives [sync-indicator--pending-marker](sync-indicator--pending-marker.md)

## References

- spec §7.5 (relay protocol), §9.2 (push/pull, cursor advance), §8.8 (cursor),
  §8.5 (apply path)
- `lib/sync/engine.dart` (`MergeEngine`, `ApplyOutcome`), `lib/sync/storage/`
  (`change_log`, `applyRemote` already verifies + quarantines)
