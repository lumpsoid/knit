# Next step — finish the §9.1 first vertical slice (local-first, no relay)

The sync core, persistence, the signed local write path, and the §8.6 read-side
derivations are built and tested (131 sync tests). The **app shell is now built**
too: App Launch, the Onboard identity ceremony, and the Timeline — three FCIS
features wired through abstractions (146 tests total). What remains for the §9.1
gate is the **Collection screen** (where the create → cards → reorder → link →
delete flow actually happens) and running it on the **persistent sqflite graph**
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
   states, pull-to-refresh. (Collection create + open are "coming soon" stubs.)

## What's left for the §9.1 slice

1. **Collection screen** (§4.2) — chat-style feed (`position ASC, id ASC`, §8.7);
   bottom text composer → `create` card; **"+" add-block** (link · photo-later)
   → standalone card / link finder; tap-card **actions sheet**
   (delete · edit · link · reorder); **reorder mode** (drag → `reorder`, a state
   of this screen); header long-press → cover/title. Inline title→create on the
   Timeline opens it. This is the surface the gate flow runs on.
2. **Card edit** (§4.3), **Connections view** (§4.4: links-out + backlinks,
   breadcrumb back-stack), **broken-link chip** rendering (§4.8 / §8.6.1), and the
   **sync indicator** (`pendingCount`, §6.6).
3. **Run on the persistent sqflite graph** — flip `main.dart` to `AppConfig.prod`
   and wire the desktop/CI DB factory (sqflite needs ffi on desktop), so gate 5
   can be exercised through the real app lifecycle on a real DB file.

## Acceptance (spec §9.1 gates — the pass/fail line)

Drive the live flow (create → cards → reorder → link card→collection + a
"+"-block link card → delete a link endpoint).

- [ ] **Gates 1–3** (one-txn mutation; sig-keyed **distinct** `op_id` for a
      reorder of a just-edited card; reorder freezes `hlc_*`, bumps `position_*`,
      text intact) — engine-proven by the write-path tests; confirm through the UI.
- [ ] **Gate 4**: deleting a link endpoint renders a **visible broken chip**
      (§8.6.1) — no crash, link not vanished. (Resolver done; needs UI rendering.)
- [ ] **Gate 5**: kill & reopen → projection rebuilds from `change_log`
      byte-identical, device clock resumes strictly monotone. Engine-proven on
      sqflite (`write_rebuild_test`); **must hold through the real app lifecycle**
      — requires running on the prod sqflite graph (left, item 3).

## After this

- **Relay push/pull** (§7.5/§9.2): the `origin='remote'` apply path + verify +
  quarantine already exist; add `sync_state.cursor` (advance past applied **and**
  quarantined ops, §8.8), push order by `seq`, ack→`acked=1`, and the optional
  §8.5-step-3 `hint_mismatch` cross-check. Gated on the share flow + capability
  tokens (§10).
