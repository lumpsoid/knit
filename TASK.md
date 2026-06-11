# Next step — the §9.1 first vertical slice (local-first, no relay)

The sync core, persistence, **and the signed local write path** are built and
tested (113 sync tests): merge-core + HLC, the `change_log` / `device_clock` /
`projection` / `local_identity` / `quarantine` storages, the §7.1 canonical
serializer + Ed25519 signing, and `SyncStore.create/edit/delete/reorder` +
verify-on-apply.

What's missing is the **slice itself, end-to-end**: the read-side derivations the
UI needs, a composition root that opens a real DB, and the Flutter UI that drives
**create collection → add text cards → reorder a card → add a link → delete a
card that is a link endpoint**. This is the spec **§9.1 local-first gate**;
passing it — gate 5 especially, through the *live* app — is the pass/fail line
before any relay work.

## Build (same domain/infra + abstracted pattern)

1. **Read-side derivations** (§8.6 — pure, both-impl tested like the rest) ✅ **done**
   - **Broken-link chip** (§8.6.1): `BrokenLinkResolver` over `ProjectionStorage`
     that, for a live link (`deleted=0`), checks each endpoint via its `*_type`
     table and flags it broken when the row is missing or `deleted=1`. Closes
     gate 4. Never auto-deletes the link. → `SyncStore.linkStatus`.
   - **Connections** (§4.4): `backlinks` (links where `target_id = id`) exists;
     added the forward **links-out** query (`source_id = id`, live) on
     `ProjectionStorage` (both impls). → `SyncStore.linksOut`.
   - **Home timeline** (§8.6.3): pure `buildHomeTimeline` → `CollectionSummary`
     (`card_count`, `last_card` preview = greatest-`created_at` live card carrying
     `kind`+`text`, and `last_updated`); list sorted `last_updated DESC`. Computed
     on read (no cache table → no invalidation bugs); editing a card does **not**
     resurface its collection (flagged §8.6.3 limitation, MVP-acceptable). →
     `SyncStore.homeTimeline`. Lives in `lib/sync/storage/derivations/`.

2. **Composition root** (`lib/` app entry)
   - Open the per-device SQLite file; build the **sqflite** `SyncStore`
     (`Sqflite*` storages + `SqfliteUnitOfWork` + `Ed25519Signer`) for production
     and `SyncStore.inMemory()` for dev mode (CLAUDE.md). Call `open()` once at
     startup (creates tables, restores the clock, provisions the identity).
   - Expose the store to the widget tree.

3. **Flutter UI** (§4)
   - **Home / Collections timeline** (4.1) — vertical list, latest-updated first,
     **not reorderable**; row = cover/title/last-card preview/count/last-updated;
     inline title→create that opens the new Collection Screen.
   - **Collection screen** (4.2) — chat-style feed (`position ASC, id ASC`, §8.7);
     bottom text composer → `create` card; **"+" add-block** (link · photo-later)
     → standalone card / link finder; tap-card **actions sheet**
     (delete · edit · link · reorder); **reorder mode** (drag → `reorder`, a state
     of this screen); header long-press → cover/title.
   - **Card edit** (4.3) and **Connections view** (4.4: links-out + backlinks,
     breadcrumb back-stack).
   - **Sync indicator** (`pendingCount`, §6.6) and **broken-link chip** rendering
     (§8.6.1 / §4.8).

## Acceptance (spec §9.1 gates — the pass/fail line)

Drive the live flow above (create → cards → reorder → link card→collection + a
"+"-block link card → delete a link endpoint).

- [ ] **Gates 1–3** (one-txn mutation; sig-keyed **distinct** `op_id` for a
      reorder of a just-edited card; reorder freezes `hlc_*`, bumps `position_*`,
      text intact) — already engine-proven by the write-path tests; confirm they
      still hold when driven through the UI.
- [ ] **Gate 4**: deleting a link endpoint renders a **visible broken chip**
      (§8.6.1) — no crash, link not vanished.
- [ ] **Gate 5**: kill & reopen → projection rebuilds from `change_log`
      byte-identical (rows, blended placements, feed order), device clock resumes
      strictly monotone. Engine-proven on sqflite (`write_rebuild_test`); **must
      hold through the real app lifecycle on a real DB file**.

## After this

- **Relay push/pull** (§7.5/§9.2): the `origin='remote'` apply path + verify +
  quarantine already exist; add `sync_state.cursor` (advance past applied **and**
  quarantined ops, §8.8), push order by `seq`, ack→`acked=1`, and the optional
  §8.5-step-3 `hint_mismatch` cross-check. Gated on the share flow + capability
  tokens (§10).
