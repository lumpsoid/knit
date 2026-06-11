# Settings — Sync/Relay + Profile/Identity subpages (§4.5)

## What's missing

No Settings screen exists. Spec §4.5 calls for two subpages.

## What to build

- **Sync / Relay subpage:** relay ip/domain field + a "Check connectivity"
  button; show last-sync status. These settings live in a **local
  `app_setting(key, value)` table — not synced** (no such table/storage exists
  yet; add it alongside the other storages).
- **Profile / Identity subpage:** set/change **nickname** anytime; view the ID
  (`nickname#fingerprint`); **export / back up** the keypair. The identity
  (Ed25519 keypair, `profile` record) already exists from onboarding — this is
  the surface to view/edit it.

## Notes

- The `app_setting` store should follow the repo's storage convention: an
  abstract interface in `domain/` with **both** a sqflite and an in-memory impl
  (it is local-only, never synced/signed).
- Changing the nickname writes the signed `profile` record (an edit), reusing
  the onboarding write path.

## References

- spec §4.5 (Settings), §5 (Identity: nickname, fingerprint, keypair export),
  §6 (data model — `profile`)
- `lib/features/onboard/` (identity provisioning + profile write to reuse)
