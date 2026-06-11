# Knit — repo guide for Claude

Knit is a **local-first** Flutter app (mobile + desktop) for capturing info as
**Cards** in chat-style **Collections**, woven together with neutral **Links**.
The source of truth is a local SQLite DB per device; a Go relay (out of scope
here) is an optional dumb router for sync/sharing. Full product + protocol spec:
**`docs/app_spec.md`** — it is the single source of truth; cite its `§` sections.

## Status

The **sync core, persistence, the signed local write path, and the §8.6
read-side derivations are built and tested** (131 sync tests): merge-core + HLC,
the storages, the §7.1 canonical serializer + Ed25519 signing,
`SyncStore.create/edit/delete/reorder`, verify-on-apply, and the broken-link /
links-out / home-timeline derivations.

The **application is built** on the FCIS contract below — four features wired
through abstractions (177 tests total): **App Launch** (init seam + destination
resolver), the **Onboard** identity ceremony (welcome → nickname → explain +
Generate → generating → reveal `nickname#fingerprint`, writing the signed
`profile` record), the **Timeline** (§4.1 home over `homeTimeline()`, with
inline collection create + open), and the **Collection** screen (§4.2 —
chat-style feed, composer, "+"-block link card, per-card actions sheet, reorder
mode, header rename). Two shared primitives back the write path: `newUuidV7`
(`lib/core/ids/`) and `FractionalIndex` (`lib/core/ordering/`, the §8.7 card
position keys). Cross-page data uses the route-args carrier (cross_feature §2).
See `lib/app/` (composition) + `lib/features/`.

**Not yet built:** the §4.4 Connections view (which is also where the §8.6.1
broken-link chip renders — gate 4's visible half), the §4.3 card-edit page
(card edit is inline/text-only today), the sync indicator (§6.6), the rest of
§4, and the relay. The app runs on the **in-memory graph by default**; flip
`main.dart` to `AppConfig.prod` for the persistent sqflite graph (the §9.1
gate-5 persistence check needs it). Current status + next step: **`TASK.md`**.

## Presentation architecture (UI layer)

The UI follows a generalized, app-agnostic **FCIS** (Functional Core /
Imperative Shell) contract built on `package:fcis_core` + `package:result_dart`
(both git deps). The initial features (`app_launch`, `onboard`, `timeline`)
already realize it — copy their shape; new features MUST follow it too. These
docs are the source of truth for the presentation layer — cite their `§`
sections like `app_spec.md`:

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
  dev/tests. `open({ensureSchema, provisionIdentity})` — prod lets the migrator
  own the schema and defers identity to onboarding; `hasIdentity` /
  `provisionIdentity` are the onboarding gate + the explicit "Generate" step.

### `lib/sync/storage/derivations/` — read-time derivations (§8.6, pure)
- `broken_link.dart` (`BrokenLinkResolver`, §8.6.1/2), `home_timeline.dart`
  (`buildHomeTimeline` → `CollectionSummary`/`CardPreview`, §8.6.3). Never
  synced/signed; surfaced via `SyncStore.linkStatus` / `linksOut` / `homeTimeline`.

### `lib/app/` — composition root (composition.md)
- `app_config.dart` — immutable `AppConfig` graph selector (`AppEnvironment`
  prod/dev, §2). `app_graph.dart` — the `AppGraph` cell the init seam populates.
  `composition.dart` — pure `resolve*` functions of `AppConfig`.
  `schema/knit_migrations.dart` — the `package:sql_migrator` v1 baseline for the
  prod sqflite graph.

### `lib/core/ids/` + `lib/core/ordering/` — write-path primitives (shared)
- `ids/` — the `IdGenerator` port (`newId()`) for minting time-ordered TEXT ids
  (§6.1), with `UuidIdGenerator` (the `package:uuid` v7 impl) in the same dir;
  the write repos inject it. A profile is the exception (its id is the pubkey).
- `ordering/fractional_index.dart` — `FractionalIndex.between/keyAfter/keyBefore`,
  the §8.7 lexicographic card position keys (the one intended string ordering),
  pure; the Collection updater computes positions with it.

### `lib/core/` — presentation glue (shared, non-sync)
- `fcis_flutter/` — `ValueListenableStateHolder` (fcis_core `StateHolder` ↔
  `ValueNotifier`, fcis.md §6.8). Logging uses `package:logging` directly — it
  is itself the seam: shells take an **injected** `Logger` (the module defaults
  it to `Logger('knit.<feature>')`, tests pass their own), logging catches as
  `severe`; `main.dart` drains `Logger.root.onRecord` to the console (other
  consumers can subscribe to react).

### `lib/features/<feature>/` — FCIS features (fcis.md §4–6.8)
- `domain/` (ports + models + failures) + `infra/` (impls over `AppGraph.store`)
  + `presentation/` (state · action · effect · ui_effect · updater · shell ·
  loop · controller · module · scope · page). Built: `app_launch`, `onboard`,
  `timeline`, `collection`. Per-feature **narrow** ports return `Result`
  (result.md §9). `collection` adds a `*_route_args.dart` carrier
  (cross_feature §2) the Timeline writes and the Collection page reads.

### `packages/` — extracted local packages (path deps)
- `sql_migrator/` — backend-agnostic sqflite schema migrator (used by the prod
  graph). `effect_emitter/` — the `EffectEmitter` UI side-effect seam
  (cross_feature.md §4).

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
