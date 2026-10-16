# Next step — finish the §9.1 first vertical slice (local-first, no relay)

The sync core, persistence, the signed local write path, and the §8.6 read-side
derivations are built and tested (131 sync tests). The **app is now built**: App
Launch, the Onboard identity ceremony, the Timeline (now with inline collection
create + open), the **Collection screen** (§4.2), and the **Connections view**
(§4.4) — create → cards → edit → reorder → link → delete, and the links-out /
backlinks surface that renders the broken-link chip, the **Card Edit page**
(§4.3 — text + image + per-card links incl. card→card), and the **sync
indicator** (§4.8/§6.6 — the app-bar pending/synced marker) (252 tests total).
What remains for the §9.1 gate is running it on the **persistent sqflite graph**
so gate 5 can be checked through the live app.

## Done

1. **Read-side derivations** (§8.6 — pure, both-impl tested) — broken-link
   resolver (§8.6.1/2), links-out (§4.4), home timeline (§8.6.3). In
   `lib/sync/storage/derivations/`; surfaced via `SyncStore.linkStatus` /
   `linksOut` / `homeTimeline`.
2. **Composition root** (`lib/app/`) — `AppConfig` graph selector, `AppGraph`
   cell, pure resolvers, `sql_migrator` v1 baseline. `SyncStore.open` gained
   `ensureSchema` / `provisionIdentity` flags; `hasIdentity` / `provisionIdentity`
   added. Wired in `main.dart`. **In-memory graph is the default**; prod sqflite
   graph is implemented but not yet the default.
3. **App Launch** feature (composition.md §1–3) — init seam +
   `AppDestinationResolver`; splash → init → route first-run vs returning.
4. **Onboard** feature (§5) — welcome → nickname → explain + Generate →
   generating → reveal; the Generate step provisions the keypair and writes the
   signed `profile` record.
5. **Timeline** feature (§4.1) — home over `homeTimeline()`, empty/loading/error
   states, pull-to-refresh. Inline collection create (FAB → title dialog →
   `create` → open) and tap-to-open now navigate to the Collection screen via
   the route-args carrier (cross_feature §2); gained a narrow write port.
6. **Collection screen** (§4.2) — `lib/features/collection/`. Chat-style feed
   (`position ASC, id ASC`, §8.7); bottom composer → text `create` card;
   **"+" add-block** (link now, photo/audio "coming soon") → standalone link
   card; tap-card **actions sheet** (edit · link · reorder · delete);
   **reorder mode** (drag → `reorder`, a state of this screen); header
   long-press → rename. All card positioning (append + reorder midpoints) is
   computed **purely in the updater** via the new `FractionalIndex` primitive
   (`lib/core/ordering/`), and ids are minted with `newUuidV7`
   (`lib/core/ids/`). The actions-sheet **Edit** now opens the dedicated Card
   Edit page (item 8) rather than the old inline text prompt.
   **Multi-select + move:** long-press a card to select, tap to toggle,
   select-all; "Move to collection" picks another collection and appends the
   cards there (feed order kept) in one `SyncStore.moveCards` transaction,
   then a snackbar offers to open the target.
7. **Connections view** (§4.4) — `lib/features/connections/`. An entity's
   **links-out + linked-from** (backlinks, §8.6.2), each live one tappable to
   jump (pushing an in-state **breadcrumb back-stack**, a crumb tap / hardware
   back pops a hop via `PopScope`), each broken one rendered as the §8.6.1
   **broken-link chip** that offers **clear** (a signed `link` delete) but never
   vanishes. Reached from the Collection app-bar "hub" icon (collection focus)
   and the card-actions sheet (card focus) through a second route-args carrier
   (cross_feature §2). Endpoint liveness is the canonical `SyncStore.linkStatus`
   derivation, never re-implemented. This is the visible half of **gate 4**.
8. **Card Edit page** (§4.3) — `lib/features/card_edit/`. A dedicated page,
   reached from the Collection actions-sheet **Edit**, that edits a card's
   **text** (Save → signed edit, pop, resync), manages its **image** (add /
   replace / remove over the §6.4/§7.4.8 attachments foundation — pick → hash →
   content-addressed blob + signed `attachment` record, flipping the card
   `kind`/`attachment_id`, with ref-counted blob GC on replace/remove), and
   manages its **links** (view/add/remove, full card→card scope via a generic
   target picker that browses collections and drills into cards; the list reuses
   the §4.4 view-models + §8.6.1 broken row). Built on the same FCIS contract as
   `collection`/`connections`; the attachments foundation (subtask 1) is the
   shared `lib/core/attachments/` library.
9. **Sync indicator** (§4.8/§6.6) — `lib/features/sync_status/`. A small, calm
   app-bar marker over `SyncStore.pendingCount()`. Only the Timeline app bar
   embeds `SyncStatusIndicator` today. A single app-wide `SyncStatusScope`
   controller reads the count when the marker mounts; nothing refreshes it
   after a write. Relay-less today (nothing acks, §6.6), so it reads calmly ("saved
   on this device", never an alarm); the reactive push-on-change refresh is
   deferred to the relay via the §1 `ExternalSignalListener` seam. Read-only
   FCIS feature (no UiEffect/EffectEmitter — no one-shot effects).
10. **Profile screen** (§5/§7.4.7) — `lib/features/profile/`. A dedicated page,
    reached from the **account icon** in the Timeline app bar, that shows the
    device identity (avatar + `nickname#fingerprint` handle), lets the user
    **edit the nickname** (the §5 "you can change it anytime" promise — a signed
    `profile` edit over the same id, the device pubkey, then a re-read), and
    surfaces the **full public key** with copy-to-clipboard. Built on the same
    FCIS contract as the other features: narrow read + write ports
    (`ProfileReadRepository` / `ProfileWriteRepository`) over `SyncStore.get` /
    `edit` / `authorPubkey` / `signer.fingerprintOf`; a `ProfileShowMessageUiEffect`
    for the rename-failed snackbar. The public key is immutable across a rename.

## What's left for the §9.1 slice

1. **Run on the persistent sqflite graph** — flip `main.dart` to `AppConfig.prod`
   and wire the desktop/CI DB factory (sqflite needs ffi on desktop), so gate 5
   can be exercised through the real app lifecycle on a real DB file.

## Acceptance (spec §9.1 gates — the pass/fail line)

Drive the live flow (create → cards → reorder → link card→collection + a
"+"-block link card → delete a link endpoint).

- [ ] **Gates 1–3** (one-txn mutation; sig-keyed **distinct** `op_id` for a
      reorder of a just-edited card; reorder freezes `hlc_*`, bumps `position_*`,
      text intact) — engine-proven by the write-path tests; now **drivable
      through the Collection screen** (create → edit → reorder → delete);
      confirm on the prod graph.
- [ ] **Gate 4**: deleting a link endpoint renders a **visible broken chip**
      (§8.6.1) — no crash, link not vanished. Resolver + link write proven end to
      end; the **Connections view** now renders the chip and is driven by
      `connections_repository_test` (delete a card → its backlink shows broken,
      clear removes only the link). Confirm through the live app on the prod
      graph.
- [ ] **Gate 5**: kill & reopen → projection rebuilds from `change_log`
      byte-identical, device clock resumes strictly monotone. Engine-proven on
      sqflite (`write_rebuild_test`); **must hold through the real app lifecycle**
      — requires running on the prod sqflite graph (left, item 2).

## Planned refactors (in this order)

1. ~~**Split `collection_page.dart` into widget files.**~~ **Done.** The
   widgets live in `lib/features/collection/presentation/widgets/`. The audit
   moved the feed's view state (animated-list mirror, scroll, older-page
   paging, focus reveal) into the stateful `CollectionFeed`, which takes its
   inputs through its constructor (no state-holder listeners). The composer's
   send guard, which the page and the updater each had, is now one rule:
   `CollectionState.canSendComposer`. The page still keeps the two composer
   reveal flags (`_showPhotoSources`, `_showAudioBar`) for step 3.
2. **A data-passing pass over the Collection widgets.** Each widget takes only
   the data it uses through its constructor (widgets.md §2). Passing the whole
   `CollectionState` (or another aggregate) into a widget is not allowed.
3. **Only then split `CollectionState`.** The composer and recording state is
   the clearest part to move into its own notifier. Do not start this before
   steps 1 and 2.

## After this

- **Relay push/pull** (§7.5/§9.2): the `origin='remote'` apply path + verify +
  quarantine already exist; add `sync_state.cursor` (advance past applied **and**
  quarantined ops, §8.8), push order by `seq`, ack→`acked=1`, and the optional
  §8.5-step-3 `hint_mismatch` cross-check. Gated on the share flow + capability
  tokens (§10).
