# Next step — the local write path (canonical serialization + signing)

The sync **read/apply** path persists (merge-core + HLC + `change_log` /
`device_clock` / `projection` storages, wired through `SyncStore`). The missing
piece is the **upstream write path** that turns a local mutation into a signed,
durable op. It is the seam every `applyRemote`/`rebuild` already assumes
(`PersistedOp.payload` + `sig` are taken as given today).

This closes spec **§9.1 gate 1** ("every mutation is one transaction: entity row
+ signed `change_log` op + `device_clock` advance") and unblocks the §9.1 first
vertical slice.

## Build (same domain/infra + abstracted pattern)

1. **Identity** (`lib/sync/identity/` or `lib/core/crypto/`)
   - Ed25519 keypair gen + sign/verify, abstracted behind an interface (real
     impl + a deterministic fake for tests). Pubkey hex = identity; fingerprint
     = first 4 hex of `SHA-256(pubkey)` (§5).
   - `local_identity` storage (secret encrypted at rest) — abstracted, both
     impls (§6.5). Local-only, never synced.

2. **Canonical serializer** (`lib/sync/wire/` — pure, no deps)
   - `Snapshot → canonical UTF-8 bytes` per **§7.1**: sorted keys, no
     whitespace, integers shortest-decimal, `deleted` as int 0/1, hex for
     binary, fixed field set per entity (§7.4), `null` never omitted.
   - Round-trip with `Snapshot.fromPayload`; match the §7.4 worked examples
     **byte-for-byte** (table-driven golden tests).

3. **`op_id` builder** (§7.3) — `"<id>@<hlc_ms>.<hlc_counter>.<sig16>"`,
   `sig16` = first 16 hex of `sig`. (The test helper in `op_builders.dart`
   already mints this shape — promote it to real code.)

4. **Sign + verify on the wire path**
   - Sign: `sig = Ed25519(secret, utf8(canonical(payload)))` (§6.8).
   - Verify on apply: `Ed25519_verify(payload.author, utf8(op.payload), sig)`
     **over received bytes, never re-canonicalized** → fail = quarantine
     `bad_sig` (§8.5 step 2). Add this to `SyncStore.applyRemote` (today it
     trusts the op) + the `quarantine` storage (§6.7/§8.8).

5. **`SyncStore.writeLocal(...)`** — the local mutation, one transaction:
   - Stamp via the device clock onto the **correct slot** (§8.4: edit/delete →
     content `hlc_*`, placement frozen; reorder → `position_*`, content frozen;
     create → both).
   - Preserve incoming `created_by` on edit; set `= author` on create (§6.2).
   - Build canonical payload → sign → `PersistedOp` (`origin='local'`,
     `acked=0`) → in one `UnitOfWork`: upsert projection + append op + save
     clock.

## Acceptance (spec §9.1 gates)

- [ ] Every mutation = one txn: entity row + signed `change_log` op + clock
      advance (gate 1).
- [ ] A reorder of a just-edited card mints a **distinct** `op_id` from the edit
      (gate 2 / §7.3 case 2).
- [ ] Reorder leaves `hlc_*` unchanged, bumps `position_*`, text intact (gate 3).
- [ ] Canonical bytes match the §7.4 examples; verify-over-received-bytes works
      for a real signed op and rejects a tampered one.
- [ ] **Kill & reopen → `rebuild()` projection byte-identical to pre-kill**,
      clock resumes strictly monotone (gate 5 — the pass/fail line, §8.9).

## After this

- §9.1 first vertical slice end-to-end (create → cards → reorder → link → delete
  endpoint → broken-link chip), then the Flutter UI (§4).
- Relay push/pull + `sync_state.cursor` + ack→`acked=1` (§7.5/§9.2), gated on
  the share flow + capability tokens (§10).
