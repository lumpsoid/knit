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

The **application is built** on the FCIS contract below (new features use the
lighter controller + `ChangeNotifier` pattern instead) — seven features wired
through abstractions (252 tests total): **App Launch** (init seam + destination
resolver), the **Onboard** identity ceremony (welcome → nickname → explain +
Generate → generating → reveal `nickname#fingerprint`, writing the signed
`profile` record), the **Timeline** (§4.1 home over `homeTimeline()`, with
inline collection create + open), the **Collection** screen (§4.2 —
chat-style feed, composer, "+"-block Connection card, per-card actions sheet, reorder
mode, long-press multi-select + move to another collection, header rename),
the **Connections** view (§4.4 — an entity's
links-out + backlinks over `linksOut`/`backlinks`, a breadcrumb back-stack, and
the §8.6.1 broken-link chip with clear), the **Card Edit** page (§4.3 — text +
image + per-card links incl. card→card), and the app-wide **sync indicator**
(§4.8/§6.6 — a calm app-bar marker over `pendingCount()`, shown only in the
Timeline app bar and read once when it mounts; it does not refresh after a
write). Two shared primitives back the write
path: `newUuidV7`
(`lib/core/ids/`) and `FractionalIndex` (`lib/core/ordering/`, the §8.7 card
position keys). Cross-page data uses the route-args carrier (cross_feature §2).
See `lib/app/` (composition) + `lib/features/`.

**Not yet built:** the rest of §4 and the relay. The reactive,
push-on-change refresh for the sync indicator is also deferred to the relay
(cross_feature §1 `ExternalSignalListener`). The app runs on the **in-memory
graph by default**; flip
`main.dart` to `AppConfig.prod` for the persistent sqflite graph (the §9.1
gate-5 persistence check needs it). Current status + next step: **`TASK.md`**.

## Presentation architecture (UI layer)

### New features: lightweight controller pattern (preferred)

New features keep the FCIS *ideas* (pure decisions in the domain, side effects
at the edge, narrow `Result`-returning ports) but **drop the FCIS boilerplate**
(no action / effect / ui_effect / updater / shell / loop / module / scope
files). The goal is testability and ease of writing:

- **Controller = the page's input object.** The page takes its controller via
  its constructor and calls plain methods on it (`submit(query)`, `open(hit)`).
- **State is a separate `ChangeNotifier`** (`<Feature>State`) owned and exposed
  by the controller; the page listens to it. The controller mutates it.
- **Dependencies are injected via the controller's constructor**: narrow ports
  (business_logic.md §5), route-args writers, an injected `Logger`
  (defaulting to `Logger('knit.<feature>')`).
- **Business decisions stay in the domain** (pure functions or classes, for example a
  ranker or policy). The controller orchestrates and doesn't decide.
- **Shared, long-lived application state** gets its own controller with its
  own `ChangeNotifier` state. Other UI controllers take that shared controller
  as a constructor dependency to read its state or call it. This is for meaningful,
  lasting app state only, **not navigation**.
- **Navigation data stays in route-args carriers** (cross_feature §2, for example
  `CollectionRouteArgs`): extend the carrier (add a field) instead of
  modelling navigation as shared state.
- **Tests** drive the controller directly with fake ports and assert on the
  state notifier. No widget pumping is needed for logic. Domain logic gets plain unit
  tests.

`AudioPlaybackController` (`lib/features/audio_playback/presentation/`) is the
closest existing example. The features built so far (listed below) use the full
FCIS shape. Leave them as they are unless asked to migrate them.

### Existing features: FCIS contract

The features built so far follow a generalized, app-agnostic **FCIS** (Functional Core /
Imperative Shell) contract built on `package:fcis_core` + `package:result_dart`
(both git deps): `app_launch`, `onboard`, `timeline`, `collection`,
`connections`, `card_edit`, `sync_status`. Follow it when changing those
features. New features use the lightweight pattern above. These
docs are the source of truth for the FCIS presentation layer. Cite their `§`
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
  **The feature input channel (§3) is the default/main pattern for
  cross-feature concerns here** — when one feature must nudge another to
  act, prefer a feature-owned channel (sealed event family + Emitter /
  Reader / Observer halves, folded into the consumer's Actions by a binder)
  over reaching across boundaries. The Timeline realizes it: `TimelineChannel`
  / `RefreshChannelEvent` (`lib/features/timeline/{domain,infra}/`) lets the
  Collection (and future features) request a home-feed refresh after a write.
  Reach for the access facade (§5) only when a feature must *observe another's
  state*, not merely receive fire-and-forget intent.
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
  `toSnapshot`), `ChangeLogStorage` interface (incl. the entity-scoped
  `readForEntities` / `deleteForEntities`); sqflite + in-memory impls.
- `device_clock/` — the single-row device HLC (§6.7). `DeviceClockSchema`,
  `DeviceClockStorage` (`load`/`save`/`clear` an `Hlc`); both impls.
- `projection/` — the materialized entity tables (§6.3/§6.4). `EnvelopeColumns`
  + the five entity schemas + `ProjectionTables`; `ProjectionStorage`
  (`get`/`getMany`/`upsert`/`readAll`/`feed`/`feedPage` (newest-first keyset
  page)/`backlinks`/`linksOutOf`/`backlinksTo`/
  `liveCardsIn` (batched)/`deleteMany`/`clear`);
  `ProjectionRowMapper`
  (`Snapshot` ↔ typed row); both impls.
- `sync_store.dart` — `SyncStore`: the persistent orchestrator tying all three
  storages to the merge-core through a `UnitOfWork`. `applyRemote` (dedup → skew
  → one-txn: merge + persist projection/log/clock, §8.5), `rebuild` (§8.9),
  `open` (restore clock). `SyncStore.inMemory()` wires the in-memory impls for
  dev/tests. `open({ensureSchema, provisionIdentity})` — prod lets the migrator
  own the schema and defers identity to onboarding; `hasIdentity` /
  `provisionIdentity` are the onboarding gate + the explicit "Generate" step.
  Collection share by file: `shareSet` (a collection's winning signed ops +
  its authors' profiles), `purgeCollection` (an imported collection's rows
  *and* log ops in one txn, so rebuild agrees; refuses an own one) and
  `forkCollection` (a `ForkPlan` as own entities in one txn).
- `share/` — the pure halves of that: `ShareScope` (which entities a
  collection's share covers), `ShareSetSelector` (content + placement winner
  per entity, by the merge comparators), `ShareSet`, `ForkPlan`.

### `lib/sync/storage/derivations/` — read-time derivations (§8.6, pure)
- `broken_link.dart` (`BrokenLinkResolver`, §8.6.1/2), `home_timeline.dart`
  (`buildHomeTimeline` → `CollectionSummary`/`CardPreview`, §8.6.3; a
  preview's `linkTarget` is attached by the Timeline reader, below),
  `collection_hubs.dart` (`buildCollectionHubs` → `CollectionHub`, §8.6.4: the
  live collections linking to each one), `link_pairs.dart` (§6.4 one link per
  pair: `LinkPair`, `isDuplicateLink`, `distinctLinks` keeps the oldest of
  duplicates, `countLinks`, `countBacklinks`). Never synced/signed; surfaced via
  `SyncStore.linkStatus` / `linksOut` / `homeTimeline` / `collectionSummaries`
  (just some home rows, batched) / `collectionHubs`. Every `SyncStore` link read
  (`linksOut`/`backlinks`/`linksOutOf`/`linkCounts`/`backlinkCounts`/hubs)
  goes through
  `distinctLinks`; `SyncStore.createLink` is a no-op on a linked pair and
  `deleteLink` deletes the pair's every duplicate (one txn each).

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
- `files/` — files in and out: the `FileDeliveryPort` (share_plus) /
  `FileSavePort` / `FileSourcePort` (file_picker) over `OutgoingFile`, shared
  by the backup and the collection share, plus `LogArchive`, the signed-log
  zip layout (manifest + `log.jsonl` + `blobs/<hash>`) both codecs use.
- `ownership/` — `CollectionOwnership.of(createdBy, me)` (own vs imported,
  read-only) and `ArchiveTarget` (signed vs local archive). The one place
  keys are compared; controllers, updaters and repositories ask it.

### `lib/features/<feature>/` — features
- `domain/` (ports + models + failures) + `infra/` (impls over `AppGraph.store`)
  + `presentation/`. In new (lightweight) features, `presentation/` holds just
  `<feature>_controller.dart` · `<feature>_state.dart` (ChangeNotifier) ·
  `<feature>_page.dart`. In FCIS features (fcis.md §4–6.8), it holds state · action · effect ·
  ui_effect · updater · shell · loop · controller · module · scope · page.
  FCIS-built: `app_launch`, `onboard`,
  `timeline`, `collection`, `connections`, `card_edit`, `sync_status`.
  Per-feature **narrow** ports return
  `Result` (result.md §9). `collection` adds a `*_route_args.dart` carrier
  (cross_feature §2) the Timeline writes and the Collection page reads;
  `connections` (§4.4) adds a second carrier the Collection page writes (card or
  collection focus) and the Connections page reads, renders links-out +
  backlinks with the §8.6.1 broken-link chip, and keeps an in-state breadcrumb
  back-stack. A collection focus then loads "Mentioned in" (§8.6.5) as a
  second step: the narrow `MentionReadRepository` reads the corpus (like
  Search), the pure `UnlinkedMentionFinder` picks the own cards elsewhere
  naming the title without linking, and Link writes through `CardLinksController`.
  A removable row (`ConnectionItem.removable`: a live link from an own source,
  by `CollectionOwnership`) has a ⋮ → Remove (`RemoveLinkEffect`) → a
  `ConnectionsLinkRemovedUiEffect` snackbar whose Undo re-links the
  `LinkEnds` (`RestoreLinkEffect`).
  `sync_status` (§4.8/§6.6) is a read-only feature with **no page**:
  its view is `SyncStatusIndicator`, an app-bar marker over one app-wide
  `SyncStatusScope` controller reading `pendingCount()`. Only the Timeline app
  bar embeds it today, and it reads the count when it mounts — writes do not
  refresh it. It carries no UiEffect/EffectEmitter (no one-shot effects).
- `collection` page widgets live in `presentation/widgets/` (one concern per
  file, each taking only the fields it renders). `CollectionFeed` owns the
  feed's view state: the animated-list mirror, scroll, older-page paging and
  the focus reveal. The composer is a lightweight sub-controller inside this
  FCIS feature: `CollectionComposerController` + `CollectionComposerState`
  hold the staged attachments, the recording and the inline panel.
  `CollectionController.composer` exposes it. A send reaches the loop as
  `ComposerSubmitted(text, image/file/audio)`.
- Several images on one card (§4.2): a nullable, synced
  `card.more_attachment_ids` (v8 migration) holds an image card's further
  images after `attachment_id`, joined by "," (signed payloads carry strings
  and ints only). `CardSchema.attachmentIdsOf` lists every attachment a card
  points at; share scope, purge, fork and delete-GC all go through it.
  The composer stages several photos (`ImagePickerPort.pickImages`, the camera
  adds one) as `StagedImage`s and sends them as one image card.
  `FeedCard.imageIds` feeds `CardImageGrid` (2 / 3 / 2×2 with "+N") and the
  viewer. Card Edit adds photos (`setCardImages`) and removes any one
  (`RemoveImageRequested`); the media overview (`MediaPhoto`) and slides
  show each image. The relay web snapshot still publishes the first image.
- `collection` composer "Optimize size" (§4.2, opt-in per staged photo): the
  pure `ImageOptimization` rules (`lib/core/attachments/domain/`) and the
  `ImageOptimizerPort`, realized by `PackageImageOptimizer` (pure-Dart
  `package:image` on a background isolate): fit 1600×1200, keep EXIF unless the
  Settings `AppPreferences.keepPhotoMetadata` toggle is off (main wires it in as
  a getter). The composer optimizes when the chip turns on, as a visible phase
  (dimmed thumbnail, "Optimizing photo…", send spinner; chip off cancels), and
  sends the smaller copy.
  Card Edit's **Optimize** (image cards) runs the same port over the stored
  image (`OptimizeImageEffect`) and swaps in the copy as a new attachment.
- `collection` app bar: `CollectionHeaderBar` is the title card, docked. A
  `TitleMorphLink` (`widgets/title_morph.dart`) ties the card's name
  (`TitleMorphSource`) to the bar's slot (`TitleMorphTarget`). The
  `TitleMorphFlight` overlay paints the name flying between them, and
  `TitleMorphReveal` fades in the bar's surface, cover thumbnail and
  Connections button. All of it reads positions at paint time, and the feed's
  header sliver reports every layout through `onHeaderMoved`.
- `collection` multi-select (§4.2): `CollectionState.selectedCardIds` (a
  non-empty set *is* selection mode). Move loads targets through the narrow
  `CardMoveReadRepository`, reads the target's tail, and the updater appends
  the cards after it (feed order) → one `SyncStore.moveCards` transaction
  (content + placement on one stamp, §8.4). `CollectionCardsMovedUiEffect`
  shows the snackbar whose "Open" writes the Collection carrier.
  The picker's "New collection" row grows into the shared
  `showNewCollectionBar` line; sending creates the target
  (`CreateMoveTargetEffect`, `CollectionWriteRepository.createCollection`)
  and moves into it as an empty tail. A title like an existing target
  offers "Move there" instead.
  The actions sheet's **Move to collection…** (`CardMoveRequested`) opens the
  same flow for one card: the picker moves `CollectionState.moveCardIds` (the
  selection, or that card), so it never enters selection mode.
  **Link to…** opens `LinkPickerSheet` with card_links' `LinkSelection`
  (`CollectionState.linkSelection`; per card the `LinkSource` rule, no ✓).
  `SelectionLinkRequested` → `LinkCardsEffect` (the updater keeps only the
  cards `sourcesFor` allows) → `CardLinksController.linkAll` →
  `SyncStore.createLinks` (one transaction; skips linked pairs and repeats)
  → `CollectionCardsLinkedUiEffect` ("Linked N cards", N = links written).
- `collection` Outline (§4.2): the ⋮ sheet's **Outline** lists the emphasized
  cards as headings (the `SlidePlanner` meaning). `OutlineRequested` reads the
  whole feed through the narrow `CollectionOutlineReadRepository`, and the pure
  `CollectionOutline` picks the entries and their one-line labels into
  `CollectionState.outline` (`CollectionOutlineSheet`). A tapped row is
  `OutlineEntryChosen`: it sets `CollectionState.focus` (a `FeedFocus` with a
  serial, which the search-hit entry now sets too) and, for an unloaded card,
  reloads `FeedWindow.through` it. `CollectionFeed` reveals each new focus once
  its card is loaded. Imported collections offer it too.
- Collections as hubs (§3, read-side only, no new field). `collection` feed:
  the pure `LinkTile.targetOf` (`domain/link_tile.dart`) picks a card whose
  whole purpose is linking to a collection or a card (no attachment, one link
  out, text blank or one short label line). `FeedCard.linkTile` is the sealed
  `LinkTile`: `CollectionLinkTile` or `CardLinkTile`. The read repo batches
  `linksOutOf`, then `collectionSummaries` for collection targets and
  `getMany` (cards, their collections, file names) for card targets.
  `CardBubble` draws `CollectionLinkTileView` / `CardLinkTileView` over the
  shared `LinkTileFrame` (image via the image cache). A tap follows
  `LinkTile.openFrom(here)`: `RevealCardHere` dispatches
  `CardRevealRequested`, `OpenLinkedCollection` writes the Collection carrier
  (with `focusCardId` for a card) and pushes. A deleted target gets no tile.
  A tile's `archived` (target collection, or target card's) draws the frame's
  muted "Archived" marker.
  Timeline: the narrow `TimelineHubReadRepository` (`collectionHubs`) fills
  `TimelineState.hubs`; the row's "in:" line is `TimelineHubLine` (two names,
  then "+N"). `CardPreviewLabel` (`lib/core/previews/`) is the shared
  newest-card preview text; its `linkTo` is the one "→ Trips" label (Home
  preview and link chips). `SyncStoreTimelineRepository` attaches a
  Connection card's target to its `CardPreview.linkTarget` (one `linksOutOf`
  read, one `getMany` of the target cards) through the pure
  `TimelineConnectionPreview` (`LinkTile.targetOf` again); a gone target
  keeps the generic label.
- Link chips + backlinks badge (§4.2). The read repo reads `linksOutOf` and
  `SyncStore.backlinkCounts` once for the whole page (the collection's own
  count rides along). `FeedCard.linkChips` is the card's links out as the
  pure sealed `LinkChip` (`domain/link_chip.dart`: `CollectionLinkChip` /
  `CardLinkChip` / `BrokenLinkChip`; `LinkChip.allOf` gives none when a tile
  stands for the link, live targets first). `LinkChipRow` caps them at 2 plus
  "+N". `FeedCard.backlinkCount` feeds the "← N" `CardBacklinksBadge`. The
  page draws both in `CardLinkChips` (wrap + ellipsize, no shadow) and
  follows a tap through `LinkChip.openFrom`; `ShowCardConnections` (broken,
  "+N") opens the card's Connections. Multi-select's `IgnorePointer` makes
  them inert; reorder rows don't draw them.
- Connection card (§4.2/§6.4): the "+" sheet (`AddBlockSheet` → `AddBlock`)
  has no URL link block; a bare http(s) URL sent from any composer becomes a
  link card (`CardKind.forText`). Its **Connection** block opens
  `LinkPickerSheet` with card_links' `NewConnection` pick (a collection, never
  this one, or any card via drilling) → `ConnectionCardRequested(kind, id)` →
  `AddConnectionCardEffect` → `CollectionWriteRepository.addConnectionCard` →
  `SyncStore.createLinkedCard` (text-less `kind=link` card + its `link`, one
  transaction); the shell records a collection target as a link recent. Card
  Edit carries the card kind (`CardEditRouteArgs.initialKind`), and the pure
  `CardTextEdit` lets a Connection card (either target) save a blank label
  (→ `kind=link`, no text) and turns a label into a text card.
  Composer text typed before "+" → Connection rides in the request
  (`composerText`); the pure `ConnectionCardText` makes it the card's label
  (`kind=text`; blank or a bare URL ⇒ none). The shell pushes
  `CollectionComposerTextUsedUiEffect` only after the card is saved, and the
  page then clears the input.
- Settled cards (§3.3): a nullable, synced `card.settled_at` (v5 migration),
  written by `SyncStore.setCardsSettled` on the content clock. The domain's
  `SettleChange` decides settle vs unsettle (all settled → unsettle). The
  Collection offers it in the actions sheet and the selection bar, and Card Edit
  as a toggle. A settled bubble is drawn by `SettledPalette` (`lib/core/settled/`):
  receded toward the page, greyed and faded, no tint, with faint
  `SettledRootsPainter` roots seeded by the card id. There is no
  strikethrough. The Timeline mutes a settled newest card's preview.
- Emphasized cards (§3.3) are settled's opposite: a nullable, synced
  `card.emphasized_at` (v7 migration), written by `SyncStore.setCardsEmphasized`.
  The two marks are exclusive: each write nulls the other in the same op. The
  domain's `EmphasisChange` follows the `SettleChange` rule. Same three entry
  points as settle; the bubble gets a warm-amber frame and a blur-free halo from
  `EmphasizedPalette` (`lib/core/emphasized/`). Feed only: home and search
  ignore it.
- `search` (§3.2/§4.1) is the first **lightweight** feature (controller +
  `SearchState` ChangeNotifier + page). The Timeline app bar opens it; it
  runs on submit. `SearchReadRepository` flattens live collections and cards into
  `SearchDocument`s, and the pure `SearchRanker` ranks them: phrase > all words >
  some words, then title > card text > description/label/file name, then
  word-start, then recency. A tapped hit writes `CollectionRouteArgs` with an
  optional `focusCardId`, which the Collection page scrolls to and highlights.
  Filter chips (type, kind, settled, archived, linked to) are a pure
  `SearchFilter` (`domain/search_filter.dart`) that narrows the documents
  before ranking; a
  chip change re-ranks the documents the controller holds, no reload. The
  Collection ⋮ sheet's "Search in collection" builds the controller with a
  `SearchScope` (`CollectionScope.createSearch`): "In: <title>" chip, only
  that collection's cards, ✕ widens. `SearchDestination` decides a tap: a hit
  in the origin collection pops back with the card id and the page dispatches
  `CardRevealRequested` (the Outline's reveal); any other opens its collection.
  "Linked to…" (tags via links, §4.1): `SearchFilter.linkedTo` holds
  `SearchLinkTarget`s a document must link out to, all of them (AND), over
  `SearchDocument.linksOut` (one batched `SyncStore.linksOutOf` read). With a
  target and no query, `SearchRanker.browse` lists the matches newest first.
  The chip opens the card_links `LinkPickerSheet` with a `LinkFilterPick`
  (chosen targets ✓, a tap toggles). The Collection ⋮ sheet's "Find linked
  cards" opens search pre-filtered to that collection (`createSearch(filter:)`).
- `new_collection` (§4.1) is the shared inline-create line, not a page.
  `showNewCollectionBar` grows the tapped button (the Timeline FAB, or share
  capture's "New collection" row) into a composer-style title line docked
  above the keyboard, over a solid scrim. Sending creates, and back, a tap
  outside or an empty title shrink it back. The pure `SimilarCollectionFinder`
  (search's folding) flags a title like an existing collection, and the line
  then offers that one instead ("Open" / "Save there").
- `collection_share` (lightweight; design `docs/collection_share.md`, spec
  §10.8) sends one collection as a `.knitc` file. Export: Collection ⋮ →
  "Share as file" → `CollectionShareExportSheet` (size, Include media) →
  send or save. Import: Settings → Data → "Import collection", an opened
  `.knitc` (Android VIEW filter) or a shared one (the share-capture gate
  routes it) → `CollectionShareImportController` → the pure
  `CollectionShareImportPolicy` validates the whole file (signatures,
  owner, scope, the foreign-overwrite rule) → preview sheet → every op via
  `applyRemote` → open it. A collection whose `created_by` is someone else's
  is **read-only** everywhere: no composer / reorder / selection / header
  edit (the Collection updater drops writes), a read-only card sheet
  (Connections, Copy, "Link from my card…" = card_links' `LinkFromMine`),
  a "from nickname#fp" Timeline line, a local-only archive flag
  (`LocalArchiveRepository`), excluded from move / share-capture targets,
  no widget quick input. Its ⋮ sheet offers Save a copy
  (`ForkPlanner` → `forkCollection`) and Remove (`purgeCollection` + blob GC)
  through the app-wide `ImportedCollectionController`.
  Sharing an index: the pure `ShareReach` (`lib/sync/storage/share/`) counts
  the live outside links for the sheet's warning, and **Include linked
  collections** (`shareSet(id, includeLinked: true)`) bundles each reached
  *own* collection whole, one level deep (a card target brings its
  collection). The manifest lists them in `included` (version 2; a
  single-collection file stays version 1); the policy validates each one
  against its own owner and scope, and the import opens the primary.
- `share_capture` (§4.7, lightweight, **Android only**) takes text, photos and
  files shared from other apps (`receive_sharing_intent`; `ACTION_SEND` /
  `SEND_MULTIPLE` filters, activity `singleTask`). The app-wide
  `IncomingShareController` holds the pending share. An `IncomingShareGate`
  wraps the Timeline page, which opens `ShareCapturePage` (pick or create a
  collection), and the Onboard page, which drops the share with "Set up Knit
  first". The pure `ShareCapturePlanner` makes one card per item, appended
  after the tail: a bare http(s) URL becomes a link card, other text a text
  card, and a file an image, audio or file card by its mime.
- `collection_details` is the first **shared controller** (lightweight, app-wide,
  no page): `CollectionDetailsController` + `CollectionDetailsState` own every
  collection's header (title, description, cover). The Timeline, Collection and
  Collection Edit read it via their scopes; their shells `remember` what they
  read from the projection and route every header write through it (cover
  writes also GC the replaced attachment).
- Decoded attachment images go through one shared `AttachmentImageCache`
  (`lib/core/attachments/presentation/`): shells `show(owner, ids)` /
  `release(owner)`, pages read `AttachmentImageCacheState` via their scope.
  Shown images are held; released ones stay idle up to a byte budget (LRU).
  Seed just-stored picks with `put` instead of re-reading them.
- `backup` + `settings` Data page (§4.5/§5) — identity and data go together.
  A bundle (`BackupArchiveCodec`, format v2) is the signed log, the blobs, and
  `identity.json`: the keypair sealed under the user's passphrase by
  `IdentityKeyCipher` (`Argon2IdentityKeyCipher`: Argon2id on an isolate, then
  XChaCha20-Poly1305). `BackupImportRepository.plan` asks the pure
  `RestorePolicy`: this identity's own bundle → `merge`, another identity's →
  `replaceDevice` (erase, `SyncStore.adoptIdentity`, replay), and a v1 bundle on
  a fresh device → `missingIdentity`. Settings "Reset identity" (the user types
  their nickname to confirm) and replace both go through `DeviceEraser`
  (`lib/app/`), which runs `SyncStore.resetDevice` and deletes the blobs.
  Onboarding offers "Restore from backup" on its welcome step.
- Archived collections (§3.4): a nullable, synced `collection.archived_at` (v6
  migration), written by `SyncStore.setCollectionArchived` on the content
  clock. `homeTimeline()` keeps archived collections, flagged by
  `CollectionSummary.archived`, so the move, share-capture and widget pickers
  still offer them. The Timeline's `TimelineSections` sets them aside, and
  archiving unpins. Home's `PullRevealList` hides the `TimelineArchiveRow` until
  a pull, and the row opens `TimelineArchivePage`, a view over the Timeline's
  own state. Archive and Unarchive live in the shared long-press sheet
  (`widgets/timeline_collection_actions.dart`).
- `card_links` is the shared owner of card links (§4.4): `CardLinksController`
  + `CardLinksState` + the one `LinkPickerSheet` (lazy two-level picker).
  Collection and Card Edit open the picker and add links through it; Card Edit
  and Connections remove links through it. The `LinkSource` rule (no self-link,
  no link to the card's own collection) lives in its domain. The picker marks
  the source card's linked targets ✓ (`LinkedTargets`, read when
  `LinkPick.linkedFrom` is set — `LinkSource` only) and pops a
  `LinkPickerChoice`: `LinkTargetPicked`, or `LinkTargetUnpicked(linkId)` for a
  ✓ target tapped again (Collection: `UnlinkRequested`; Card Edit:
  `RemoveLinkRequested`).
  Where `LinkPick.offersNewCollection` (all but `LinkFromMine`), the
  collections level has a "New collection" row: `LinkPickerSheet.show` grows
  it into `showNewCollectionBar` ("Link there" for a similar title) and pops
  `LinkToNewCollection(title)`. Made in one transaction with its links:
  `CardLinksController.linkToNewCollection` → `addLinksToNewCollection` →
  `SyncStore.createLinks(newCollection:)` (a card's link, Card Edit,
  multi-select), or `addConnectionCardToNewCollection` →
  `createLinkedCard(newTargetContent:)` (the "+" Connection block).
- `lib/core/recents/` — the pickers' "Recent" rows (§4.2/§4.4): the pure
  `RecentTargets` MRU (5 kept, 3 shown, `among` drops what the picker wouldn't
  offer) per `RecentPurpose` (move / link), behind narrow
  `RecentTargets{Read,Write}Repository` ports (shared_preferences + in-memory),
  device-local like pins, and the shared `RecentTargetsRow` chips. The
  Collection shell records a target after a successful move and
  `CardLinksController.link` after a successful collection link.

- `collection_present` (§4.9, lightweight) presents a collection as slides. The
  Collection app bar's ⋮ sheet (`CollectionMenuSheet`: Present, Reorder) writes
  the `PresentRouteArgs` carrier and pushes `PresentPage` over a
  `PresentController` from `CollectionScope.createPresent()`. The pure
  `SlidePlanner` makes the `SlideDeck`: a title slide, then an image run or an
  emphasized heading opens each slide, settled cards left out.
  `SyncStorePresentReadRepository` reads the whole feed with each card's live
  links. The resume slide is device-local (`shared_preferences`, keyed by
  the slide's first card id). `SlideScroll` turns the vertical `PageView` when long
  notes overscroll. `ScreenAwakePort` (`wakelock_plus`) keeps the screen on.

- `collection_widget` (lightweight, **Android only**) is the home-screen widget
  that opens Knit on one collection. Native side (`android/.../knit/`):
  `CollectionWidgetProvider` draws a title tile from SharedPreferences
  (`CollectionWidgetStore`). `CollectionWidgetConfigureActivity` accepts a
  newly placed widget right away and hands the pick to MainActivity. The
  `knit/collection_widget` method channel (`CollectionWidgetChannel`) carries
  requests in and bindings and tiles out. Dart side: the app-wide
  `CollectionWidgetController` holds the pending request, and a
  `CollectionWidgetGate` handles it. The Timeline's gate opens the collection,
  or the `CollectionWidgetPickerPage` for a widget being set up; the Onboard
  gate refuses setup. While attached, the controller republishes tiles through
  the pure `CollectionWidgetTilePlanner` on every `CollectionDetailsState`
  change and whenever the app is hidden. A deleted collection's widget shows
  "removed" and taps through to the picker.
  A live tile also has a ✎ quick-input button (`QuickInputRequest`): the gate
  opens the collection with `CollectionRouteArgs.quickInput`, so the composer
  autofocuses, a bare URL is sent as a link card (`CardKind.forText`), and the
  first saved card pops the page (`true`) and returns to the home screen.
  Every widget tap first clears the stack back to the Timeline.

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
