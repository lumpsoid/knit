# Knit — repo guide for Claude

Knit is a **local-first** Flutter app (mobile + desktop) for capturing info as
**Cards** in chat-style **Collections**, woven together with neutral **Links**.
The source of truth is a local SQLite DB per device; a Go relay (out of scope
here) is an optional dumb router for sync/sharing. Full product + protocol spec:
**`docs/app_spec.md`** — it is the single source of truth; cite its `§` sections.

## Status

The **sync core + persistence layer + the signed local write path are built and
tested** (113 sync tests): merge-core + HLC, the storages, the §7.1 canonical
serializer + Ed25519 signing, `SyncStore.create/edit/delete/reorder`, and
verify-on-apply. The **UI and the relay are not yet built**. The next step — the
§9.1 first vertical slice end-to-end — is in **`TASK.md`**.

## Presentation architecture (UI layer)

The UI is not built yet; when it is, it follows a generalized,
app-agnostic **FCIS** (Functional Core / Imperative Shell) contract built
on `package:fcis_core` + `package:result_dart` (both already git deps).
These docs are the source of truth for the presentation layer — cite their
`§` sections like `app_spec.md`:

- **`docs/architecture/fcis.md`** — the `<Feature>Scope` rule (§4), the
  Controller (§5), and Functional Core / Imperative Shell (§6) incl. the
  canonical `package:fcis_core` realization (§6.8: updater / shell / loop /
  controller / module files).
- **`docs/architecture/result.md`** — the `Result<S, F>` pattern (§9):
  every fallible op returns a `Result`; the shell unwraps it, the updater
  never sees it; per-area sealed failure types.
- **`docs/architecture/composition.md`** — `InitializationRepository` (the
  init seam), the immutable `AppConfig` graph selector, and App Launch:
  `AppLaunchController` drives init, then the post-init
  `AppDestinationResolver` decides navigation.
- **`docs/architecture/cross_feature.md`** — the four cross-feature seams:
  external signals (`ExternalSignalListener`/`Registrar`/`CancellationToken`),
  the route-args carrier (data between pages, decoupled from navigation),
  feature input channels, `EffectEmitter` (the UI side-effect seam,
  renamed from `SideEffector`), and the feature-to-feature access facade
  (§5: outside consumers may only observe a feature's state read-only and
  pass intent via its `ActionSink` — nothing else crosses the boundary).
- **`docs/architecture/widgets.md`** — widget inputs: shared widgets take
  primitives (or a widget-owned view-model), never a feature's domain
  type (§1); every widget/function takes only the data it uses, not whole
  aggregates (§2).
- **`docs/architecture/business_logic.md`** — where business decisions
  live: shells orchestrate, the domain decides. The placement ladder
  (value → entity → policy → use case), make-invalid-states-unrepresentable,
  tell-don't-ask, and the self-check. A business `if` never belongs in a
  shell/controller/repository. Also §5: inject **narrow, single-purpose
  ports** named for what they do (`<Feature>ReadRepository`, …), never one
  fat catch-all `<Feature>Repository` — keeps variants cheap and composable.

These describe a *reusable* contract (generic `<Feature>` / `<app>`
placeholders), so they read the same across apps; they govern UI code, not
the `lib/sync/` core below.

## Conventions

- **Layout:** every feature/module splits into `domain/` (abstractions, models,
  schemas) and `infra/` (implementations), with barrel files (`domain.dart`,
  `infra.dart`, `<name>.dart`) re-exporting each level. Import the barrel.
- **Storage is abstracted:** a storage is an abstract interface in `domain/`
  with **two** impls in `infra/` — a sqflite one for production and an
  **in-memory** one for dev mode and tests (no SQLite, no platform channel).
  Tests assert the same contract against both.
- **Dart style** (see also memory `dart-helper-fn-placement`): tag→enum
  resolvers are `static` methods on the enum (`EntityType.fromTag`); constant
  lookup sets are named `static const` class fields, not inline literals.
- **DB package is `sqflite`** (not Drift). `sqflite_common_ffi` is a dev dep so
  the few real-DB tests run on desktop/CI. Most tests use the in-memory impls.
- **Tests** live under `test/sync/...`; run `flutter test test/sync/`. Keep
  `flutter analyze lib test` clean.
- **HLC is integers compared by a comparator, never string-sorted.** The only
  intentional string ordering is `position` (fractional index) in card feeds.

## Layout

### `lib/core/storage/` — backend-agnostic storage primitives (shared)
- `domain/` — `StorageContext` (+ `NoOpStorageContext`), `UnitOfWork` (+
  `NoOpUnitOfWork`). Interfaces carry no DB type.
- `infra/sqflite/` — `SqliteStorageContext` (wraps a sqflite `DatabaseExecutor`)
  and `SqfliteUnitOfWork` (real transaction — the one-txn crash-safety seam,
  §6.8/§8.5).

### `lib/sync/` — the client-side merge/apply engine + HLC (pure Dart core)
- `hlc.dart` — `Hlc` value type + comparator; `DeviceClock` (`localTick`,
  `observe`); skew guard `exceedsSkew` + `kMaxSkewMs` (§6.1/§8.1–8.3).
- `snapshot.dart` — `Snapshot` (parsed/verified entity op: envelope + separate
  card placement clock + `content` map); `EntityType`; `fromPayload`;
  `withPlacementFrom` does the §7.6 content+placement overlay.
- `merge.dart` — `compareContent` / `comparePlacement` comparators, `merge()`
  (per-entity LWW, delete↔edit resurrect, card blend), and the in-memory
  `Projection` store (`apply`/`replay`/`feed`) (§6.9/§8.5/§8.7/§8.9).
- `engine.dart` — `MergeEngine`: the pure in-memory apply path (skew → clock →
  merge) + `ApplyOutcome` (`applied`/`deduped`/`quarantinedSkew`).
- `sync.dart` — barrel for everything above + the storage layer.

### `lib/sync/storage/` — sync persistence (abstracted: sqflite + in-memory)
- `change_log/` — the durable signed-op log (§6.6). `ChangeLogSchema`,
  `PersistedOp` (row model + `OpKind`/`SyncOrigin` enums, `fromDb`/`toDb`,
  `toSnapshot`), `ChangeLogStorage` interface; sqflite + in-memory impls.
- `device_clock/` — the single-row device HLC (§6.7). `DeviceClockSchema`,
  `DeviceClockStorage` (`load`/`save`/`clear` an `Hlc`); both impls.
- `projection/` — the materialized entity tables (§6.3/§6.4). `EnvelopeColumns`
  + the five entity schemas + `ProjectionTables`; `ProjectionStorage`
  (`get`/`upsert`/`readAll`/`feed`/`backlinks`/`clear`); `ProjectionRowMapper`
  (`Snapshot` ↔ typed row); both impls.
- `sync_store.dart` — `SyncStore`: the persistent orchestrator tying all three
  storages to the merge-core through a `UnitOfWork`. `applyRemote` (dedup → skew
  → one-txn: merge + persist projection/log/clock, §8.5), `rebuild` (§8.9),
  `open` (restore clock). `SyncStore.inMemory()` wires the in-memory impls for
  dev/tests.

## Key invariants (don't break)

- **One transaction per apply:** projection write + `change_log` insert +
  `device_clock` save commit together (§8.5). `SyncStore` does this via
  `UnitOfWork`; never split them.
- **Reorder freezes `hlc_*`, bumps `position_*`** (§8.4); content and placement
  are merged on separate clocks and blended by overlay (§7.6).
- **`created_by` is immutable**, copied forward on every edit, and is **not** a
  merge comparator input (§6.2/§6.9).
- **Verify over received `payload` bytes**, never re-canonicalize (§7.0/§8.5);
  the projection is a cache — verify via `change_log`, not the blended row.
- **Rebuild-from-log is the correctness gate** (§8.9): replay in `seq` order
  through the merge-core → identical projection regardless of arrival order.
