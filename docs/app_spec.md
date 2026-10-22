# Knit — Application Spec (consolidated, v1)

> Single source of truth. Folds together: product definition, core model, screens,
> identity, data model, Wire format v1 (with the **sig-keyed `op_id`** as the final form),
> and the **merge/apply/HLC engine**. Self-contained so the next session can start cold.
> **Next step is defined in §10: the share/publish flow + relay capability tokens.**

---

## 1. What Knit is

Knit is a **local-first** app (Flutter, mobile + desktop) for capturing and organizing
information step-by-step and weaving the pieces together with links. It replaces an ad-hoc
workflow of saving notes as posts in Telegram groups: a topic becomes a **Collection**,
each step/point/clip becomes a **Card** in a chat-style feed, and any node can be **linked**
to any other node — turning a simple tree into a navigable graph (a "second brain").

A separate **Go sync/relay server** is only a meeting point for syncing and sharing. It is
out of scope to *implement* here, but its **contract is defined** (§7.5) because the app
must speak to it. The app is fully functional **offline**; the relay is optional.

## 2. Why Knit is

It grew from a real workflow — saving info (e.g. a YouTube short) by making a Telegram group
and posting each step as a message. The mental model is good (topic = container, steps =
feed), but Telegram gets the container wrong: **no search** across/within note-groups, **no
data ownership** (a ban/outage loses everything), **no structure** (no reorder, link, or
organization beyond chronology).

Knit keeps what works (topic-as-container, step-by-step feed) and fixes the rest by being
local-first: the source of truth is a local DB per device, the relay is just a router, data
can be exported. Search, links, and ownership are solved structurally, not bolted on.

## 3. Core model

- Telegram group → **Collection** (a topic notebook).
- A post → **Card** (one step/point/clip, timestamped, in a feed).
- **Link** — one neutral primitive connecting any node to any node. A "node" is a Card *or*
  a Collection. Card↔card, card→collection, collection↔collection are all the same
  `link(source, target)` record.
- **Backlinks** — if A links to B, B automatically shows "linked from A." No reverse link is
  authored; costs no extra UI; makes the web navigable. Derived, never stored.
- **Collections as hubs** — a link to a collection works like a tag, and a collection made
  mostly of links to others works like an index or folder. That is only a way of reading
  links: there is **no hierarchy** in the model (no parent, no nesting, no new field). The UI
  makes it visible read-side: the feed draws such a link as a tile (§4.2) and Home names the
  collections that link to a row (§4.1, derived in §8.6.4). The "+" sheet's Connection block
  makes such a card in one step (§4.2). A Connection card may point at one card instead, as
  a "see also"; it is drawn as a card tile but does not make a hub (§8.6.4 counts
  collection targets only).

### 3.1 Node affordances (the collection-vs-card line)

Both a Collection and a Card are **nodes** and are linkable identically — a user may treat a
collection like a big card; nothing structurally stops that. The **only** difference in
affordance:

- **Collection** = `title` + an optional **description** + an optional **cover image** on
  its header card. **No audio.** Its only media is the cover image (edited from the header
  card). The description is a short free-text blurb about the collection — not feed content.
- **Card** = `kind ∈ {text, image, link, audio, file}`, with body text and one attachment.
  An **image** card may hold **several images** (§4.2): the first is its `attachment_id`,
  the rest follow in order in `more_attachment_ids`.
  **Audio exists only as a card** inside a collection — never on a collection header.
  A **file** card carries an arbitrary attachment (any mime), labelled by the
  attachment's original `name`.

The data model enforces this: `collection` has `title` + optional `description` +
`cover_attachment_id` only; `kind=audio`/`attachment_id` live only on `card`.

### 3.2 Locked model decisions

- **Links are a minimum block, not inline in text.** A link to another collection or to a
  card is created via the "+" add-block menu as a standalone **Connection** card (§4.2); a web link
  is a card of its own, made by sending a bare URL.
- **Typed links (source/part-of/next) dropped** — sugar, hard to present generally. Base is
  one neutral link with an **optional free-text `label`** (the "later if wanted" hook).
  Backlinks stay (not sugar).
- **Search is embedded, not a tab** — a search icon in the home top bar opens a full-screen
  search-as-you-type overlay. The app is shallow; search is a tool, not a place.
- **Tags are links, not a separate concept.** A collection (or a card) linked to from many
  items acts as their tag or category; search's **Linked to…** filter (§4.1) asks for them,
  several tags at once meaning *all* of them.
- **Identity = an on-device cryptographic keypair**, not a server username (see §5).

### 3.3 Settled cards

Knit is not a task manager, but a card can stop being *current* while still being worth
keeping: a finished step, an answered question, a price that changed. Deleting loses the
history, so a card can instead be **settled**.

- A settled card **stays where it is** in the feed, in search and in links. Nothing is
  hidden or reordered. It is only drawn quieter: the bubble recedes toward the page, its
  content fades and loses its colour, and barely visible roots sit behind it. There is no
  tint, so it never competes with live cards. There is **no strikethrough and no checkbox**, so a collection never
  reads as a to-do list.
- **Settle / Unsettle** lives in the card actions sheet, in the multi-select bar (it
  settles every selected card, or unsettles them all once all are settled), and as a toggle
  on Card Edit.
- If a collection's newest card is settled, the home row shows its preview muted.
- Data: one nullable `settled_at` on `card` (ms; null = live), written on the **content**
  clock like any edit (§8.4). It is synced and signed, so other devices and shared copies
  see it. Its value is the settling write's own stamp time.

**Emphasized cards** are the opposite mark: a card that matters more than its neighbours
(a key decision, the one number to remember) can be **emphasized**.

- An emphasized card also **stays where it is**. It is drawn louder: a bright warm-amber
  frame with a faint halo ring around the bubble. Only the Collection feed shows it; home and
  search are unchanged.
- A card is live, settled **or** emphasized, never both: emphasizing a settled card
  unsettles it, and settling an emphasized card clears the emphasis.
- **Emphasize / Unemphasize** sits beside Settle in the actions sheet, the multi-select bar
  (same all-or-nothing rule) and Card Edit.
- An emphasized card also acts as a **heading**: it is an entry in the collection's
  **Outline** (§4.2) and opens a slide in **Present** (§4.9). A settled card is never one.
- Data: one nullable `emphasized_at` on `card` (ms), written exactly like `settled_at`; the
  write that sets one mark nulls the other in the same op.

### 3.4 Archived collections

A collection that is done for now, but worth keeping, can be **archived** instead of
deleted. Archiving takes it off the home timeline without losing anything.

- An archived collection **leaves the home list** (§4.1) and is listed on the **Archive**
  page, reached from a hidden row at the top of Home. Its cards, links and title are
  untouched, and it still opens, edits and accepts new cards as usual.
- It **stays reachable everywhere else**: search, the link picker, Move to collection, share
  capture and the home-screen widget picker still offer it. Search marks its hits (and its
  cards' hits) "Archived".
- New cards do **not** unarchive it, whether added here, captured, moved in or synced.
  Unarchiving is always explicit.
- Archiving a pinned collection also **unpins** it (pins are device-local, §4.1).
- Data: one nullable `archived_at` on `collection` (ms; null = on Home), written on the
  content clock like any edit (§8.4). It is synced and signed, so other devices see it. Its
  value is the archiving write's own stamp time.

## 4. Screens & navigation

### 4.1 Home / Collections Timeline (root)
- Vertical list of **collections**, **sorted latest-updated first (descending)** — recency
  order, like a messenger's chat list. **Not reorderable.**
- Each row shows: cover image (if set), title, last-card preview, card count, last-updated.
  When the newest card is a Connection card (§4.2), the preview names its target: "→ Trips"
  for a collection, "→" and the first line of a card (else its kind, "→ Photo"). If the
  target is gone it falls back to the generic "🔗 Link". The target is resolved on read in
  two batched reads (the newest cards' links out, then the target cards).
- **"in:" line:** under the preview, a small muted line names the collections that link to this
  one (§3, §8.6.4): "in: House · Trips", at most two names, then "+N". A collection counts
  once however many of its links point here, from itself or from its cards; the row's own
  collection and deleted sources never count. Archived and imported collections count like
  any other. No hubs, no line. The Archive page's rows show it too.
- **Inline collection creation:** a button becomes a title/theme input line; on submit it
  opens the new Collection Screen with the card composer ready. ("Title/theme" is one input
  — there is **no** separate theme field.)
- **Search icon** → full-screen search-as-you-type overlay.
- **Search filters:** chips narrow the ranked hits, for one search session only (never
  persisted): result type (all · collections · cards), **Kind** (text · photos · links ·
  files · audio, several at once, none on = every kind), **Settled** (one chip cycling
  any → live only → settled only, §3.3) and **Archived** (archived collections included, on by
  default, §3.4). Collection hits obey only the type and Archived chips, and hide while any
  Kind chip is on. Changing a chip re-filters the last submitted query at once, without a new
  submit.
- **Linked to…** (§3.2 tags): a chip opens the link picker (§4.4) to pick a collection or a
  card; chosen ones show ✓ there and a tap toggles them. Each chosen target shows as a
  removable "→ <title>" chip. A hit must have a live link **out** to **every** target (AND):
  Vegetarian + Quick = what links to both. Each document is judged on its own links — a
  collection passes when it links to them itself; its cards don't inherit that. With a target
  set and an **empty query**, search lists every match, newest first ("everything tagged X");
  with a query, the targets narrow the ranked hits like the other chips. Works in a scoped
  search too. The documents' links come from one batched read with the corpus; changing
  targets re-filters it without a reload.
- **Pinned collections:** long-press a row → actions sheet → **Pin / Unpin**. Pinned
  collections sit in a **"Pinned"** section above a **"Recent"** section; both keep the
  recency order, with no cap on pins. Headers appear only once something is pinned. Pins are a
  **device-local view preference**: not synced, not signed, not part of the §6.4 schema.
  Deleting a collection drops its pin.
- **Archive** (§3.4): the same long-press sheet offers **Archive**, which takes the collection
  off Home. An **Archive** row (with the archived count) hides above the first row: a short
  pull down at the top reveals it and it stays, a longer pull also refreshes, and scrolling it
  out of view hides it again. A mouse wheel scrolled up at the top reveals it on desktop. The
  row exists only while something is archived. If everything is archived, it shows without a
  pull. Tapping it opens the **Archive** page: the archived collections in the same recency
  order, where long-press offers **Unarchive** and Delete.

### 4.2 Collection Screen (a collection's card feed)
- Chat-style feed of **cards**, **chronological ascending by default** (step 1 → 2 → 3,
  oldest at top). Feed order key = `position ASC, id ASC` (§8.7).
- **Bottom composer:** quick text → card. Behaves like a messenger — quick text goes in
  fast. A send that is nothing but one http(s) URL makes a **link card** (`kind=link`, the
  URL as its text) that opens in the browser; pasting a URL can fire an async
  metadata/thumbnail fetch that fills the card a moment later.
- **"+" add-block menu** (bottom sheet: Connection · photo · audio · file). **Connection**
  opens the link picker (§4.4) at its collections level, with its "Recent" row
  (collections only): link a collection directly, or drill into one, this collection
  included, and pick a card in it. Never this collection itself; any card, siblings
  included, since the new card doesn't exist yet. Imported collections and their cards
  are valid targets, and so is a **new collection** (§4.4). Picking one appends a
  **Connection card** at the feed tail: a `kind=link` card with no text plus its one `link`
  to that collection or card, written in one transaction (§6.4 link block), drawn as the
  link tile below; a new collection is created in that same transaction. Text typed in the
  composer becomes the card's label: trimmed, it makes a `kind=text` card (still the tile
  with a caption while short and one line, else a plain card with a link chip), and the
  input clears once the card is saved — a dismissed picker or a failed write leaves it. A
  bare URL is never a label: it stays in the input. A collection target is
  remembered for the Recent row. Photo, audio and file stage an attachment for the
  composer. An imported (read-only) collection has no composer, so no "+".
- **Optimize size** (opt-in): a staged photo shows its size and an *Optimize size* chip.
  On, the photo is scaled to fit 1600×1200 (1200×1600 for a portrait photo) and re-encoded
  (JPEG, or PNG when it has transparency), with its orientation baked in. Its metadata
  (camera, date, location) is kept, unless Settings → *Keep photo metadata* is off (a
  device-local preference, on by default). Optimizing is a visible phase: the thumbnail
  dims under a spinner, the line reads "Optimizing photo… This can take a few seconds",
  and the send button shows a spinner until it's done; turning the chip off cancels it.
  Then the preview shows the saving and the smaller copy is what gets stored. If it would
  not save at least a tenth, the original is kept ("Already small"). GIF and HEIC are left
  as they are. The choice carries over to the next photo on that page; it is device-local
  UI, never synced.
- **Several images on one card:** the composer's gallery pick takes several photos at once,
  and the camera adds one more to those staged. They show as a row of thumbnails, each with
  its own ✕, and one send makes **one image card** holding them all in pick order. Card Edit
  adds more photos to an image card and removes any one of them (§4.3). The bubble lays them
  out as a grid (one wide, two side by side, three as one big and two small, four or more as
  a 2×2 grid with a "+N" on the last tile); a tap opens the full-screen viewer on that image.
- **Link tile:** a card whose whole purpose is linking to another collection or to one card
  is drawn as a tile instead of a plain bubble. Such a card has no attachment and exactly
  one link out, to a collection or a card, and its text is blank or one short line (a label,
  up to 80 characters); a `kind=link` card qualifies only without a URL.
  - A **collection tile** shows that collection's cover (or a folder glyph), title, card count
    and its newest card's one-line preview (muted when settled, like Home). A tap opens that
    collection over this one.
  - A **card tile** shows that card's first image (or a note glyph), a two-line preview of its
    text (else its file name, else its kind: "Photo", "File"…), muted when it is settled, and
    a small "in *Collection*" line. A tap opens its collection over this one, focused on it
    (the search-hit reveal); a card in this same collection is revealed and highlighted in
    place instead.
  Both share one frame (the same translucent ring), told apart by the glyph. The card's text
  shows above the tile unless it just repeats the title (or the card's preview). Card Edit
  (§4.3) gives such a card a label: the label makes it a text card (a bare URL, a link
  card), and an emptied label is allowed and makes it a text-less `kind=link` card again. A
  tap beside the tile still opens the actions sheet. If the target is deleted (for a card,
  or its collection), the card keeps its plain bubble and the "→ unavailable" chip below.
  A tile whose target collection (or the target card's collection) is archived (§3.4)
  shows a small muted **Archived** marker.
- **Link chips:** any other card that links out shows small chips under its bubble, one
  per link: "→ Trips" for a collection, "→" and the first line of a card (else its file
  name or kind). At most 2 show, live targets first; the rest fold into a "+N" chip that
  opens the card's Connections (§4.4). A tap follows the chip like a tile: a collection
  opens, a card in this collection is revealed in place, a card elsewhere opens its
  collection focused on it. A deleted target (or a card whose collection is deleted) shows
  a muted "→ unavailable" chip that opens Connections, where the link can be cleared
  (§8.6.1). A chip to an archived collection, or to a card in one, is muted with an archive
  glyph. Chips wrap and ellipsize to the feed's width. Imported collections show them too;
  in multi-select they are inert, and reorder mode hides them.
- **Backlinks badge:** a card that other cards or collections link *to* shows a small "← N"
  badge after its chips (N = its backlinks, one per pair, §6.4); a tap opens its
  Connections. The badge never counts the card's own links out — those are its chips, or
  its tile — so a card-to-card link reads once at each end: a chip on the source, a badge
  on the target. A Connection card shows its tile and, if linked to, the badge.
  The tiles and chips of a loaded page are read in batches: one links-out read and one
  backlink-count read for every card, then one read of the collection targets, one summary
  read for the tiles' collection targets, and for the card targets one read each of the
  cards, their collections and their file names.
- **Tap a card → actions sheet:** edit · link · copy · share · move to collection ·
  settle/unsettle · emphasize/unemphasize (§3.3) · delete. **Move to collection…** runs the
  multi-select Move below for that one card, without entering selection mode. An imported
  (read-only) collection's sheet doesn't offer it.
- **⋮ menu** in the app bar opens a sheet with **Search in collection**, **Find linked
  cards**, **Present** (§4.9), **Outline** and **Reorder**. **Find linked cards** opens a
  global search (§4.1) with an empty query and a "→ <this collection>" **Linked to…** filter,
  listing at once everything linked to it — the members of a collection used as a tag; more
  targets or a query narrow it there. **Search in collection** opens the same search (§4.1) narrowed
  to this collection: an "In: <title>" chip under the field, only its cards ranked (no
  collection hits), the Kind and Settled chips. The chip's ✕ widens it to everything. A hit in
  this collection goes back to this screen and reveals the card like an Outline entry; a hit
  elsewhere opens its collection as usual. Imported collections offer it too. **Outline** lists every emphasized card of the collection (§3.3), not just
  the loaded pages, in feed order, one line each: the first line of its text, else its file
  name or kind. With none it explains that emphasized cards appear there as headings. A tap
  closes the sheet and scrolls the feed to that card with the search-hit reveal and
  highlight, loading older cards down to it first when needed. It is read-only navigation,
  so imported collections offer it too.
- **Reorder mode** — drag-to-reorder, a *state of this screen*, not a separate screen.
  **Reorder applies only to cards within this collection**; there is no reordering on Home.
- **Multi-select mode** — long-press a card to select it; while selecting, a tap toggles a
  card, the app bar shows the count, and the bottom bar offers *select all*, **Settle /
  Unsettle**, **Emphasize / Unemphasize** (§3.3), **Link to…** and **Move to collection**.
  **Link to…** opens the link picker (§4.4, both levels, its Recent row and "New
  collection") and links every selected card to the one target picked, in **one
  transaction**: a card is never linked to itself (a selected card picked as the target
  links from the others), nor to its own collection, and pairs already linked — or repeated
  — are skipped (§6.4). A mixed selection has no single linked state, so the picker shows
  no ✓. A snackbar says "Linked N cards to …" (or that all were already linked) and the
  mode ends. A collection target joins the link Recent row. Move opens a
  picker of the other live collections (most recently updated first), topped by a **Recent**
  row: up to 3 collections last moved into that the picker offers anyway (never this one, a
  deleted one or an imported one), with no row when there are none. Recents are
  **device-local view state** like pins: not synced, not signed, one list per picker (5
  kept). The selected cards are
  appended to the target's end, keeping their relative feed order, in **one transaction** (all
  or none). The source feed drops them, and a snackbar offers to open the target. Back (or
  "✕") leaves the mode; it is exclusive with reorder mode. A moved card keeps its id, so its
  links and backlinks follow it (§8.4 "Move card").
- **The collection header is a distinct top-most card** in the feed (visually set apart from
  chat cards): cover image (if set), title, and optional description. **Tap it → the
  collection-edit page** to edit title, description, and add/replace/remove the cover image.

### 4.3 Card Edit (from the actions sheet)
Edit text/content; manage that card's images and its links; **Settled** and
**Emphasized** toggles (§3.3). Saving blank text is refused, except on a Connection card
(no attachment, one link out to a collection or a card, §4.2): its text is a label, so it may be
emptied. *Add photos* picks several from the gallery: on an image card
they join its images, after the ones it has; on a text card they make it an image card.
With several images the section shows them as a grid, each with a ✕ that removes just that
one (removing the last leaves a text card); *Remove all* drops them together, and *Replace*
swaps them all for one picked file. An image card also offers **Optimize**: the same rules as
the composer's *Optimize size* (§4.2) swap each image for a smaller copy (a new attachment,
in the same place; the original is dropped; the section shows the same "Optimizing photo…"
phase while it runs), and a snackbar says what it saved — or that the photos can't be made
smaller, leaving them as they are.

### 4.4 Connections view
A card's links-out + linked-from (backlinks), each tappable to jump; breadcrumb back-stack
so deep wandering doesn't lose you. In the feed, a card's broken-link chip, its "+N" link
chip and its "← N" backlinks badge (§4.2) open this view. Can later grow into a graph view (read-side only).
A collection's view adds **Mentioned in** below links-out and backlinks: live cards in other
(own) collections whose text names the collection's title but don't link to it yet (§8.6.5),
newest first, at most 20 with a "+N more". Each row shows the card's text around the mention
and its collection; **Link** writes the card→collection link (a signed link create, so the
row moves into backlinks), and a tap opens the card in its collection, focused. It loads
after the links, so it never holds them up. A card's view has no such section.

The **link picker** (a card's "Make a link", Card Edit) lists the collections — link to one
directly, or drill in to pick a card. A **Recent** row at its top offers up to 3 collections
last linked to, by the same device-local rule as Move's (§4.2), and only those the card may
link to (never its own collection); a tap links to that collection. Targets the card already
links to — collections, cards, Recent chips — show a ✓ ("Linked"); tapping one again removes
that link (the same signed delete as Card Edit's). The "+" Connection block has no source
card yet, so it shows no ✓.

Below the Recent row, a **New collection** row (as in Move's picker) grows into the shared
title line (§4.1); a title like a collection the picker offers suggests **Link there**
instead. Sending creates the collection and links to it in **one transaction**, then
remembers it as recent. It is offered for a card's link, Card Edit, the "+" Connection block
and multi-select Link to…, never for "Link from my card…", whose targets are the user's
cards.

**Managing links.** On the Connections view, each live links-out row has a ⋮ with **Remove**,
and so does each backlink whose source is the user's own card or collection (never an
imported, read-only source; an imported focus's links-out have none). Remove deletes the
link and its duplicates (§6.4), then a snackbar offers **Undo**, which links the same two
ends again; the view re-reads either way. A broken link keeps its chip's **Clear** instead.
Removing a Connection card's only link leaves the card as an empty link card.

### 4.5 Settings
- **Sync / Relay** (subpage): relay ip/domain field + "Check connectivity" button; shows
  last-sync status. Settings live in a local `app_setting(key,value)` table — **not synced**.
- **Profile / Identity** (subpage): set/change nickname anytime; view ID
  (`nickname#fingerprint`).
- **Data** (subpage) — backup, restore and reset (**decided**). Data is signed by the
  keypair, so the two travel together:
  - **Export** writes one bundle: the signed `change_log`, the attachment blobs, and the
    keypair. The secret is sealed under a passphrase the user picks at export time
    (Argon2id → XChaCha20-Poly1305, the pubkey bound as AAD). There is no separate
    "export identity".
  - **Import** of this identity's own bundle (or a pre-keypair v1 bundle) merges by
    replay. A bundle from **another identity replaces the device**: after a confirm and
    the passphrase, the device is erased, adopts the bundle's keypair, and replays the
    log. A wrong passphrase fails before anything is erased.
  - **Onboarding** offers "Restore from backup" next to Generate (the same replace, on
    an empty device).
  - **Reset identity** erases the data *and* the keypair and returns to onboarding. The
    user must type their nickname to confirm, or choose "Back up first".
  - **Wipe data** still erases the content but keeps the keypair and profile.
  - **Import collection** opens a `.knitc` collection file someone shared (§10.8).

### 4.6 Share flow (sheet)
Publish a collection or card to a relay as read-only or shared. **(Designed in §10.)**
Until the relay lands, a collection travels as a file: Collection ⋮ → **Share as file**
(built, §10.8; design in `docs/collection_share.md`).

### 4.7 Share-sheet capture (system entry point)
Opens "pick/create collection" (not an in-app screen).

### 4.8 Interaction notes (locked)
- **Collection image** via header long-press → "add image"; shown on Home.
- **Deleting a card doesn't silently break links** — the link becomes a visible
  broken/orphaned marker to repair or clear; nothing fails quietly (§8.6.1).
- **Links sync as their own records**, merging independently of cards.
- **Don't over-engineer links:** neutral links + backlinks (+ a later graph view) cover ~90%
  of the value. **Transclusion** and heavy **graph filtering** are "later, only if used,"
  pure read-side over `link`, no schema change.
- **Sync indicator:** a small pending/synced marker so offline never feels broken.

### 4.9 Presenting a collection
A collection can be shown to someone else as a sequence of full-screen slides, for
material that reads like a walk-through: a city route with a photo and the history of
each place. **Present** in the Collection screen's ⋮ sheet opens it from the start.

- **Slides are planned from the feed**, read-only:
  - slide 0 is a **title slide**: the cover, title and description;
  - **settled cards are left out** (§3.3);
  - a run of consecutive **images opens a slide**, and the cards after it join that
    slide until the next image; a card with several images (§4.2) puts each of them in
    the slide's carousel;
  - an **emphasized card opens a slide** as its heading. If it directly follows a
    slide's images it heads them instead, and images directly after a lone heading
    join it. This splits a text-only collection into sections;
  - cards before any image or heading form a text slide.
- **Navigation:** slides sit one above the next and are swiped vertically. A slide's
  notes scroll first when they are long; pulling past their end turns the slide.
  Arrow keys, Page Up/Down and Space turn slides too. A tap shows or hides a thin
  overlay with close, the position (`4 / 12`), a progress bar and previous / next.
- **Layout:** a slide's images are pinned at the top (on the left in landscape). Several
  images form a horizontal carousel with dots. Image captions sit under the photo and
  notes sit on their own panel, so text never covers a photo. Tapping a photo opens the
  full-screen viewer with pinch, double-tap zoom and drag-to-pan. A slide without
  images gives its notes the whole page in larger type.
- **Card kinds:** text is shown as body text, and an emphasized card as a heading with a
  warm bar. Audio, link and file cards are inline chips (play, open in the browser,
  name). A card's live links in either direction are **"See also"** chips: a card on
  another slide jumps there, anything else opens Connections (§4.4).
- **Resume:** the slide last shown is remembered **per device** (like pins: not synced,
  not signed), by its first card's id. The title slide then offers "Continue from slide
  N". Returning to the title slide forgets it.
- **While presenting** the system bars are hidden and the screen stays on.

## 5. Identity

- **Identity = an `Ed25519` keypair generated on-device.** The public key (hex) is the real
  identity; the private key never leaves the device.
- **Fingerprint** = first 4 hex chars of `SHA-256(pubkey)` → display `nickname#a4f9`.
- **Nickname** is a free display label; uniqueness comes from the public key. Federated, like
  email — survives switching relays, no registry, no collision logic on the relay.
- Rule of thumb: **key = who you are, nickname = what you're called.**
- A relay *may* later offer an optional friendly-handle registry — a relay feature, not the
  base model.
- **Identity is backed up by backing up the keypair** — same ownership principle as the data.
  The backup bundle carries the keypair, its secret sealed under a passphrase (§4.5). That
  bundle is the one exception to "the private key never leaves the device"; it never leaves
  in the clear.

---

## 6. Data model

### 6.1 Foundations (locked)
- **Store:** SQLite via sqflite. One DB file per device = source of truth.
- **IDs:** `UUIDv7` (or ULID) as TEXT — globally unique with zero coordination, time-sortable
  (doubles as a creation-order fallback).
- **Identity:** `Ed25519`; pubkey (hex) is identity; fingerprint as in §5.
- **Clock:** a **Hybrid Logical Clock (HLC)** per device, used for last-writer-wins during
  merge **and only for merge**. Stored as **two integers** `hlc_ms`, `hlc_counter`, ordered
  by a **comparator**, never by string sorting. Tiebreak after `(ms, counter)` reuses
  existing row fields (`author`, then `sig`), so no node-id is baked in and there is no
  width/rollover ceiling (`int64` ms runs out ~year 292,000,000). The HLC carries **no
  display or ordering duty outside merge**.
- **Deletes:** soft only (`deleted=1` tombstone). Hard deletes resurrect under sync → banned
  for synced rows.

### 6.2 Decisions locked
- **Two provenance fields: `author` + `created_by`.** `author` = signer of *this version*
  (changes every edit; what `sig` verifies against). `created_by` = the original creator's
  pubkey, **set once on create, immutable, copied forward verbatim on every edit**. No
  behavior depends on `created_by` in v1 — it rides along signed so that **bounded
  collaboration** ("mira may edit her own cards but not yours" → `created_by == mira?`) is a
  pure read-side rule later, with **no future wire bump**. Honesty rule: on edit you must
  preserve the incoming `created_by`, never restamp it; since it is inside the signed payload,
  a peer that tampers with it forks a different entity that the next legitimate edit (which
  copies the true `created_by` from the projection) out-ranks. True enforcement is future
  (§10). *(Until then, in a shared-write topic any write-capable peer can still supersede any
  id — see §10's trust note. `created_by` is the field that will fix that; it is not enforced
  yet.)*
- **Delete vs edit = later HLC wins.** Both are rows with an HLC; the higher wins, so a late
  edit can resurrect a deleted row. (Not "delete always wins" — revisit only if it bites.)
- **Collection has no `theme` column.** "Title/theme" in UI notes is one title input line.
- **HLC is integers compared by a comparator — not a sortable string.** The padded
  `"<ms>:<counter>:<authorShort>"` string was dropped: lexicographic sort was the *only*
  thing forcing a rollover ceiling, and nothing in Knit sorts the raw HLC (merge compares in
  code; local push order is `change_log.seq`). Same for the reorder clock: `position_ms` /
  `position_counter`, tiebroken by the `position` value itself. **HLC solves sync and nothing
  else.**
- **Wire format v1 is locked** (§7), including the **sig-keyed `op_id`** (§7.3).

### 6.3 The envelope (every synced row carries these)
```
id           TEXT PRIMARY KEY   -- UUIDv7 (for profile: the pubkey hex)
author       TEXT NOT NULL      -- pubkey (hex) of whoever signed THIS version
created_by   TEXT NOT NULL      -- pubkey (hex) of the ORIGINAL creator; set once, immutable
created_at   INTEGER NOT NULL   -- ms wall-clock, immutable, for display/sort
hlc_ms       INTEGER NOT NULL   -- last-write HLC, physical part (merge only)
hlc_counter  INTEGER NOT NULL   -- last-write HLC, logical part (merge only)
deleted      INTEGER NOT NULL DEFAULT 0
sig          TEXT NOT NULL      -- Ed25519 (hex) over the canonical payload bytes
```
`author` is the signer of the *current* version, so the signature always verifies against it.
`created_by` is set to `author` on create and carried unchanged on every subsequent edit —
it never moves. (Profiles: `created_by == id == author == pubkey`.)

### 6.4 Entity tables
```sql
-- a topic notebook (a node; title + optional description + optional cover image — no audio)
CREATE TABLE collection (
  -- envelope...
  title                TEXT NOT NULL,
  description          TEXT,            -- nullable; short blurb on the header card
  cover_attachment_id  TEXT,            -- nullable; image on the home timeline
  archived_at          INTEGER          -- nullable; when the collection was archived (§3.4)
);

-- one step/point/clip in a feed (a node)
CREATE TABLE card (
  -- envelope...
  collection_id     TEXT NOT NULL,
  kind              TEXT NOT NULL,      -- text | image | link | audio
  text              TEXT,               -- body, or caption for media/link cards
  attachment_id     TEXT,               -- "add image to card" or kind=image/audio
  more_attachment_ids TEXT,             -- nullable; an image card's further images, ids joined by ","
  settled_at        INTEGER,            -- nullable; when the card was settled (§3.3)
  emphasized_at     INTEGER,            -- nullable; when the card was emphasized (§3.3)
  position          TEXT NOT NULL,      -- fractional-index string (compared lexicographically)
  position_ms       INTEGER NOT NULL,   -- SEPARATE reorder clock, physical
  position_counter  INTEGER NOT NULL    -- SEPARATE reorder clock, logical
);

-- the one neutral edge primitive: any node -> any node
CREATE TABLE link (
  -- envelope...
  source_type  TEXT NOT NULL,           -- collection | card
  source_id    TEXT NOT NULL,
  target_type  TEXT NOT NULL,           -- collection | card
  target_id    TEXT NOT NULL,
  label        TEXT                     -- optional free-text (the "later if wanted" label)
);

-- media metadata; bytes live on the filesystem, synced lazily out-of-band
CREATE TABLE attachment (
  -- envelope...
  kind          TEXT NOT NULL,          -- image | audio | file
  mime          TEXT NOT NULL,
  content_hash  TEXT NOT NULL,          -- sha256 (hex) of bytes: dedup + integrity
  size          INTEGER NOT NULL,
  name          TEXT,                   -- original file name; set for kind=file, else null
  local_path    TEXT                    -- device-local, NOT synced, NOT signed
);
```

**Link-cards reconcile cleanly.** A "link block" in the feed is a `card` with `kind='link'`
and no text (the "+" sheet's Connection card, §4.2); the edge lives in `link` with
`source` = that card and `target` = a collection or a card, and the card and its link are
created in one transaction. (A
`kind='link'` card *with* text is a web link: its text is the URL, and it has no edge.) The "link" action on an existing content
card creates a `link` with `source` = that card and **no new card**. Both paths, one edge
table — which is also why deleting a card yields an orphan marker for free (the `link` row
survives pointing at a tombstoned node; detected at read time).

**Backlinks are derived, never stored:** `SELECT * FROM link WHERE target_id=B AND deleted=0`.

**One link per pair.** Two live links with the same source and the same target (`label`
aside) say the same thing, so a local link write is a no-op when the pair is already linked.
Links still have their own ids, so concurrent devices (or older data) can leave duplicates;
every read treats them as one, the oldest standing (earliest `created_at`, then the smaller
id — the same pick on every device): links-out, backlinks, link counts, hubs, Connection-card
tiles, Present. Removing a link deletes every live duplicate of its pair in one transaction,
so it doesn't come back. A read-time rule only (§8.6); no wire change.

**Home-timeline fields** (last-card preview, card count, last-updated) are a **local view**,
not authoritative columns — recomputed locally, never synced/signed (§8.6.3).

### 6.5 Identity & peers
```sql
-- local only; never synced; secret encrypted at rest (OS keystore / passphrase)
CREATE TABLE local_identity (
  public_key      TEXT PRIMARY KEY,
  secret_key_enc  BLOB NOT NULL,
  created_at      INTEGER NOT NULL
);

-- cache of OTHER people's profiles
CREATE TABLE peer (
  public_key   TEXT PRIMARY KEY,
  nickname     TEXT,
  fingerprint  TEXT NOT NULL,
  last_seen    INTEGER
);
```
Your own nickname travels with shared content as a synced, signed **`profile`** record
`{ author=pubkey, nickname }` whose `id` **is** the pubkey. Split is deliberate:
`local_identity` holds keys (private, local); the `profile` record holds the nickname so it
rides along with shared data.

### 6.6 Sync log
```sql
CREATE TABLE change_log (
  seq          INTEGER PRIMARY KEY AUTOINCREMENT,  -- local only, drives push order
  op_id        TEXT UNIQUE NOT NULL,               -- idempotency key (§7.3, sig-keyed)
  entity_type  TEXT NOT NULL,
  entity_id    TEXT NOT NULL,
  op           TEXT NOT NULL,                       -- put | delete (hint; payload.deleted is truth)
  hlc_ms       INTEGER NOT NULL,
  hlc_counter  INTEGER NOT NULL,
  author       TEXT NOT NULL,
  payload      TEXT NOT NULL,                       -- canonical signed snapshot (verbatim bytes)
  sig          TEXT NOT NULL,                       -- == entity sig
  origin       TEXT NOT NULL,                       -- local | remote
  acked        INTEGER NOT NULL DEFAULT 0           -- local op confirmed by relay
);

CREATE TABLE sync_state (
  relay        TEXT NOT NULL,
  topic        TEXT NOT NULL,        -- a shared collection / share_id
  cursor       TEXT,                 -- last relay_seq pulled
  last_push_at INTEGER,
  last_pull_at INTEGER,
  PRIMARY KEY (relay, topic)
);
```
Each op is a **full signed snapshot** of the entity (not a field delta) — simplest thing that
merges correctly, and the op's signature *is* the entity's signature. **Pending indicator** =
`COUNT(*) WHERE origin='local' AND acked=0`.

### 6.7 Local-only tables (never synced, never signed)
```sql
-- single-row device HLC (§8)
CREATE TABLE device_clock (
  id           INTEGER PRIMARY KEY CHECK (id = 0),
  hlc_ms       INTEGER NOT NULL,
  hlc_counter  INTEGER NOT NULL
);

-- ops set aside, not applied (§8.8)
CREATE TABLE quarantine (
  op_id      TEXT PRIMARY KEY,
  relay_seq  INTEGER,
  reason     TEXT NOT NULL,     -- bad_sig | skew | hint_mismatch
  raw_op     TEXT NOT NULL,     -- full received op envelope, verbatim
  seen_at    INTEGER NOT NULL
);

-- local settings (relay URL, MAX_SKEW_MS override, etc.)
CREATE TABLE app_setting ( key TEXT PRIMARY KEY, value TEXT NOT NULL );
```

### 6.8 Signing & the write path
**What gets signed:** a deterministic canonical serialization of the envelope + content
fields, **excluding** `sig` and all local-only fields (`seq`, `acked`, `origin`,
`local_path`). `sig = Ed25519_sign(secret, utf8(canonical))`. Full rules in §7.1.

**Every mutation, in one transaction:**
1. Write/update the entity row (the materialized state the UI reads). On **create**, set
   `created_by = author`; on **edit/delete**, copy `created_by` unchanged from the current
   projection row (never restamp it).
2. Append the signed op to `change_log` (`origin='local'`, `acked=0`).
3. Advance `device_clock` (§8.2) — **in the same transaction** (crash-safety).

Entity tables are a fast projection; `change_log` is the durable thing pushed. Relay = dumb
router: stores opaque signed ops per topic and forwards them; it *can* verify signatures but
never reads content.

**Apply path (pull):** receive ops → verify `sig` against `author` → reject/quarantine bad
ones → merge into entity tables → advance `cursor`. `op_id` makes replays idempotent. Full
procedure in §8.5.

### 6.9 Conflict rules (default, simple)
Clients merge offline, so merge is effectively **client-side** and the relay stays a pure
router.
- **Concurrent edits to one entity:** compare `(hlc_ms, hlc_counter, author, sig)`; higher
  wins. `author` is the meaningful tiebreak; `sig` is the total-order backstop (same keypair
  on two devices: equal author, distinct sig). Per-record LWW. `created_by` is **not** a
  comparator input — the winning snapshot carries it like any other content field, and since
  every honest version copies it unchanged, the winner's `created_by` is the original
  creator's regardless of who won.
- **Reorder vs content edit:** `position` uses its own `position_ms`/`position_counter`,
  compared `(position_ms, position_counter, position)`. So dragging a card never clobbers a
  concurrent text edit and vice-versa. The one place per-field clocking earns its keep.
- **Delete vs edit:** later HLC wins — a late edit can resurrect.
- **Links:** independent records; never conflict with card edits; orphans resolved at read
  time, not merge time.

No CRDT machinery — LWW + tombstones + two targeted per-field clocks. Transclusion and graph
filtering need no schema changes later; they are read-side features over `link`.

---

## 7. Wire format (v1)

The exact bytes a `change_log` row serializes to over the relay, plus the relay's minimal
contract. Goal: the Go relay stays a pure router that, at most, checks a signature.

### 7.0 The key property
Signed bytes are produced once, stored verbatim in `change_log.payload`, and transmitted
verbatim. **Verification is over the received bytes** (specifically `utf8(op.payload)`, the
unescaped JSON-string value — *not* the on-wire escaped envelope, and never re-canonicalized).
Idempotency uses `op_id`, independent of payload bytes.
- Canonicalization only has to be **deterministic per signer**. Byte-identity across Dart and
  Go is **not** required for correctness — only for an optional strict mode and for
  content-hashing, neither on the critical path.
- A delete is **not** an unsigned `op:"delete"`. It is a signed snapshot with `deleted:1`.
  `op` is a routing hint; `payload.deleted` is authoritative.

### 7.1 Canonical serialization rules
JSON object of the entity's envelope + content fields, **excluding** `sig` and local-only
fields (`seq`, `acked`, `origin`, `local_path`).
1. **Encoding** UTF-8, no BOM.
2. **No insignificant whitespace.** Ever.
3. **Object keys sorted** ascending by UTF-8 byte sequence (all Knit keys are lowercase
   ASCII, so byte == code-point == lexicographic order).
4. **Fixed field set per entity** (§7.4). Every field always present. SQL `NULL` → JSON
   `null`, never omitted.
5. **`deleted` is integer** `0`/`1` (matches the column), not a JSON boolean.
6. **Numbers — integers only.** No floats in signed payloads. `created_at, hlc_ms,
   hlc_counter, position_ms, position_counter, size` are non-negative integers; `position`
   is a *string* (fractional index). Emit integers shortest-decimal (no leading zeros, `+`,
   point, or exponent). All fit in 53 bits.
7. **Strings.** UTF-8 emitted directly (non-ASCII not escaped). Escape only what JSON
   requires: `"`→`\"`, `\`→`\\`, control chars U+0000–U+001F as `\b \t \n \f \r` else
   `\u00xx` lowercase. Do **not** escape `/`, `<`, `>`, `&`.
8. **Binary fields → lowercase hex.** Public keys (`author`, `created_by`, profile `id`) and
   `content_hash`. (`sig` is also hex but lives in the op envelope, never signed-over.)

**Dart / Go parity.** Don't trust either stdlib for the signed bytes — write a tiny canonical
encoder on both sides. Dart `jsonEncode` doesn't sort keys and escapes differently; Go
`json.Marshal` of `map[string]any` sorts keys and adds no whitespace **but** HTML-escapes
`<>&` unless you use `json.Encoder` + `SetEscapeHTML(false)`; forbid floats in signed structs.
Because verification is over received bytes, a mismatch here cannot break verification — it
only surfaces under optional strict mode.

### 7.2 The op envelope (signed vs transport)
```json
{
  "v": 1,
  "op": "put",
  "op_id": "<entity_id>@<hlc_ms>.<hlc_counter>.<sig16>",
  "entity_type": "collection | card | link | profile | attachment",
  "entity_id": "<id>",
  "author": "<hex pubkey>",
  "hlc_ms": 1718020800000,
  "hlc_counter": 0,
  "payload": "<canonical JSON text of the entity — the signed bytes>",
  "sig": "<hex Ed25519 over UTF-8(payload)>"
}
```
| field | signed? | role |
|---|---|---|
| `payload` | **yes** | UTF-8 bytes of this string are the *only* thing signed. |
| `sig` | no | `Ed25519_sign(secret, utf8(payload))`, hex. |
| `v` | no | wire/transport version. |
| `op` | no | hint `put`/`delete`. **`payload.deleted` is authoritative.** |
| `op_id` | no | idempotency key (§7.3). |
| `entity_type` | no | routing/index hint. Authoritative type is `payload.t`. |
| `entity_id` | no | index hint. Authoritative id is `payload.id`. |
| `author` | no | routing/index hint. Authoritative is `payload.author`. |
| `hlc_ms`/`hlc_counter` | no | index hint. Authoritative is in `payload`. |

On apply, trust **only** values inside the verified `payload`; treat duplicated envelope
fields as untrusted hints (reject on disagreement, or ignore).

### 7.3 `op_id` — sig-keyed (final v1 form)
```
op_id = "<entity_id>@<hlc_ms>.<hlc_counter>.<sig16>"      sig16 = first 16 hex chars of sig
```
Revised from the earlier `entity_id@hlc_ms.hlc_counter` to close **silent** dedup collisions
(a collided `op_id` is dropped by the relay's dedup and the client's skip-if-seen, so the
loser never reaches the merge comparator and is absent from `change_log`, so it does not even
return on rebuild). `op_id` is **never sorted/compared for order** — it is a pure lookup key,
so adding text gives it no width/ceiling and does not reintroduce the string-clock problem.

Closes three collision classes, all silent data-loss:
1. **Same key, two devices, same ms** → both mint `(T,0)` for one entity → identical
   `entity_id@T.0`. Different content → different `sig` → distinct `op_id`. (This is the case
   the content comparator's `sig` backstop exists for; the old `op_id` discarded one op
   before that backstop could run.)
2. **Reorder reuses the content HLC** (single device, common): a reorder bumps only
   `position_*` and leaves `hlc_*` frozen (§8.4 — required, or it clobbers content), so a
   reorder op carries the prior content `(hlc_ms,hlc_counter)`. Old `op_id` → collision →
   reorder dropped as a phantom resend. `sig16` makes it distinct.
3. Any two distinct writes landing on the same `(entity_id, hlc_ms, hlc_counter)`.

**Idempotency preserved:** a true resend is byte-identical → same `sig` → same `op_id`.
`sig` already exists when the `change_log` row is built, so no extra hashing. **`sig16` = 8
bytes**: distinguishing concurrent writes on one triple needs only to beat a birthday
collision among a handful of devices; false-dedup probability ≈ `2^-64` per same-triple pair,
accepted for v1; widening is a local-only change, no relay impact.

### 7.4 Field sets & worked examples
Keys shown sorted (canonical). Full pubkey written once, then abbreviated `9f86…a08`
(abbreviation display-only; signed bytes contain the full 64-hex key). `sig`/`sig16` are
illustrative (real sigs were truncated when these examples were authored). Common envelope
fields on every synced entity: `author, created_at, created_by, deleted, hlc_counter, hlc_ms,
id` (+ `t`). In these single-author examples `created_by == author`; they diverge only after a
*different* identity edits an entity (then `author` = the editor, `created_by` = the original
creator, unchanged).
Example identity: `mira#a4f9`, pubkey
`9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08`.

**7.4.1 Collection — put** (fields: `archived_at, author, cover_attachment_id, created_at,
created_by, deleted, description, hlc_counter, hlc_ms, id, t, title`). `archived_at` (§3.4)
was added after v1. As with a card's `settled_at` (§7.4.3), a payload from an older peer may
omit it, which reads as null. The examples below show the v1 field set.
```
{"author":"9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08","cover_attachment_id":null,"created_at":1718020800000,"created_by":"9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08","deleted":0,"description":null,"hlc_counter":0,"hlc_ms":1718020800000,"id":"0192f1a2-3b4c-7def-8123-000000000001","t":"collection","title":"Espresso dialing-in"}
```
Full op on the wire (`payload` carried as a JSON **string**; escapes vanish on parse, and
`utf8(parsed_string)` is the signed bytes):
```json
{
  "v": 1,
  "op": "put",
  "op_id": "0192f1a2-3b4c-7def-8123-000000000001@1718020800000.0.d4e5f6a7b8c9d0e1",
  "entity_type": "collection",
  "entity_id": "0192f1a2-3b4c-7def-8123-000000000001",
  "author": "9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08",
  "hlc_ms": 1718020800000,
  "hlc_counter": 0,
  "payload": "{\"author\":\"9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08\",\"cover_attachment_id\":null,\"created_at\":1718020800000,\"created_by\":\"9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08\",\"deleted\":0,\"description\":null,\"hlc_counter\":0,\"hlc_ms\":1718020800000,\"id\":\"0192f1a2-3b4c-7def-8123-000000000001\",\"t\":\"collection\",\"title\":\"Espresso dialing-in\"}",
  "sig": "d4e5f6a7b8c9d0e1……c1"
}
```
(Later examples show `payload` unescaped for readability; on the wire it is the exact escaped
string above.)

**7.4.2 Collection — delete** (`created_at` immutable; HLC bumps; content retained;
`deleted:1` makes it a delete)
```
{"author":"9f86…a08","cover_attachment_id":null,"created_at":1718020800000,"created_by":"9f86…a08","deleted":1,"description":null,"hlc_counter":0,"hlc_ms":1718107200000,"id":"0192f1a2-3b4c-7def-8123-000000000001","t":"collection","title":"Espresso dialing-in"}
```
`op:"delete"`, `op_id:"0192f1a2-3b4c-7def-8123-000000000001@1718107200000.0.<sig16>"`.

**7.4.3 Card — put** (fields: `attachment_id, author, collection_id, created_at, created_by,
deleted, emphasized_at, hlc_counter, hlc_ms, id, kind, more_attachment_ids, position,
position_counter, position_ms, settled_at, t, text`). `settled_at`, `emphasized_at` (§3.3)
and `more_attachment_ids` (§4.2) were added after v1: a payload from an older peer may omit
them,
which reads as null. Verification is over the received bytes (§7.0), so those ops still
verify; the next local write of that card emits the full field set.
```
{"attachment_id":null,"author":"9f86…a08","collection_id":"0192f1a2-3b4c-7def-8123-000000000001","created_at":1718020860000,"created_by":"9f86…a08","deleted":0,"emphasized_at":null,"hlc_counter":0,"hlc_ms":1718020860000,"id":"0192f1a2-3b4c-7def-8123-00000000000a","kind":"text","more_attachment_ids":null,"position":"a0","position_counter":0,"position_ms":1718020860000,"settled_at":null,"t":"card","text":"Grind finer if the shot runs too fast."}
```

**7.4.4 Card — delete** (`position`/`position_ms`/`position_counter` unchanged — a delete is
not a reorder; content HLC bumps)
```
{"attachment_id":null,"author":"9f86…a08","collection_id":"0192f1a2-3b4c-7def-8123-000000000001","created_at":1718020860000,"created_by":"9f86…a08","deleted":1,"emphasized_at":null,"hlc_counter":0,"hlc_ms":1718020980000,"id":"0192f1a2-3b4c-7def-8123-00000000000a","kind":"text","more_attachment_ids":null,"position":"a0","position_counter":0,"position_ms":1718020860000,"settled_at":null,"t":"card","text":"Grind finer if the shot runs too fast."}
```

**7.4.5 Link — put** (fields: `author, created_at, created_by, deleted, hlc_counter, hlc_ms,
id, label, source_id, source_type, t, target_id, target_type`)
```
{"author":"9f86…a08","created_at":1718020920000,"created_by":"9f86…a08","deleted":0,"hlc_counter":0,"hlc_ms":1718020920000,"id":"0192f1a2-3b4c-7def-8123-0000000000lk","label":null,"source_id":"0192f1a2-3b4c-7def-8123-00000000000a","source_type":"card","t":"link","target_id":"0192f1a2-3b4c-7def-8123-000000000002","target_type":"collection"}
```
Backlinks are derived, never an op. Orphans (source/target tombstoned/missing) detected at
read time → broken-link chip, no op involved.

**7.4.6 Link — delete**
```
{"author":"9f86…a08","created_at":1718020920000,"created_by":"9f86…a08","deleted":1,"hlc_counter":0,"hlc_ms":1718021100000,"id":"0192f1a2-3b4c-7def-8123-0000000000lk","label":null,"source_id":"0192f1a2-3b4c-7def-8123-00000000000a","source_type":"card","t":"link","target_id":"0192f1a2-3b4c-7def-8123-000000000002","target_type":"collection"}
```

**7.4.7 Profile — put** (its `id` **is** the pubkey, so `id == author == created_by`; fields:
`author, created_at, created_by, deleted, hlc_counter, hlc_ms, id, nickname, t`)
```
{"author":"9f86…a08","created_at":1718020700000,"created_by":"9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08","deleted":0,"hlc_counter":0,"hlc_ms":1718020700000,"id":"9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08","nickname":"mira","t":"profile"}
```

**7.4.8 Profile — delete** — `deleted:1`, HLC bumps, otherwise identical (rare).

> **Attachment — put.** Signed fields: `author, content_hash, created_at, created_by,
> deleted, hlc_counter, hlc_ms, id, kind, mime, name, size, t`. `name` is the original
> file name for a `kind=file` attachment (so a file card can label it and sharing
> preserves it); it is `null` for `image`/`audio`. `local_path` never in the payload
> (local-only, unsigned). The bytes are not in the op — they transfer out-of-band,
> content-addressed by `content_hash` (§7.7).

### 7.5 Relay contract
Baseline HTTPS + JSON; a WebSocket stream is an optional live-delivery upgrade over polling.
The relay stores **opaque** ops per topic and never parses `payload`.
- **topic** — a shared stream's id (a shared collection's `share_id`). One append-only log of
  ops per topic.
- **relay_seq** — a monotonic integer the relay assigns per topic on accept; distinct from
  the client's local `change_log.seq` (never shared).

**Push** `POST /v1/topics/{topic}/push` with `{ "ops": [ <op>, … ] }`
For each op: if `op_id` already stored → dedup (return existing `seq`); else optionally verify
`sig`, append, assign next `relay_seq`.
```
200 OK
{ "acked": [ { "op_id": "...", "seq": 41 } ], "rejected": [ { "op_id": "...", "reason": "bad_sig" } ] }
```
Client: for each acked `op_id`, set `change_log.acked = 1`.

**Pull** `GET /v1/topics/{topic}/pull?since={seq}&limit=500`
```
200 OK
{ "ops": [ { ...op..., "seq": 42 } ], "next": 42, "more": false }
```
Client: verify + apply (idempotent by `op_id`), then set `sync_state.cursor = next` **only
after** the batch is durably applied locally.

**Ack semantics & idempotency**
- Push ack = relay durably stored the op → client clears it from pending. Pending indicator =
  `COUNT(*) WHERE origin='local' AND acked=0`.
- Pull cursor = highest `relay_seq` durably applied locally; resumable after a crash.
- `op_id` unique → push (dedup) and apply (skip-if-seen) are both safe to retry/replay.

**Auth (minimal):** per-topic capability token (bearer) issued by the share flow; read-only
share = token without push scope. Relay checks the token, never reads `payload`. **Designed in
§10.**

### 7.6 The reorder-vs-content subtlety (resolved)
`card` carries two clocks: content (`hlc_*`) and placement (`position_*`), so a drag never
clobbers a concurrent text edit. The catch: when the content winner and the position winner
are *different* ops, the materialized row blends fields from both and matches **neither** op's
signature. Resolution:
1. `change_log` retains every op with its own valid signature — the verifiable truth.
2. The `card` entity row is a **view**: take the content-winner's snapshot, overlay the
   position-winner's `position`/`position_ms`/`position_counter`. Its `sig` column reflects
   the content-winner; the placement's provenance lives in the position-winner's op in
   `change_log`. *(The projection is a cache; do not verify against it — verify via
   `change_log` payloads.)*
3. The next local write to that card snapshots the *current* (already-merged) state and
   re-signs under that author — the blend heals into one signed snapshot.

Exact for the primary case (one person, one key, many devices). **Alternative if multi-author
ordering ever needs cryptographic provenance:** split placement into its own tiny signed op
(`{card_id, position, position_ms, position_counter}`) — one more wire entity, no other
change. Not adopted.

### 7.7 Deferred (no wire change needed later)
- **Attachment bytes.** Out-of-band, content-addressed by `content_hash` (e.g.
  `GET /v1/blobs/{hash}` / `PUT` with hash verification). The `attachment` op syncs metadata
  only; bytes pulled lazily.
- **Strict canonical mode.** Receiver re-serializes a parsed payload, rejects if it differs
  from received bytes. Off by default.
- **base64 for `sig`.** Chose hex for uniformity; swapping touches only transport encoding.
- **Transclusion / graph filtering.** Pure read-side over `link`; no op changes.
- **`change_log` compaction.** Full snapshots retained forever is correct for rebuild; a
  future "keep latest-winner-per-entity + live tombstones" snapshot is a pure local
  optimization, no wire change.

---

## 8. Merge / apply engine & HLC (client-side)

The connective tissue turning schema + wire into working sync. **Entirely client-side**; the
relay stays a router. Notation: `device clock` = the single per-device HLC; `stamp` = an
`(ms, counter)` pair copied from the device clock onto a row. A `card` carries **two** stamps
(content `hlc_*`, placement `position_*`); every other entity carries one (`hlc_*`).

### 8.1 The device clock
`device_clock` (§6.7) is the single per-device HLC, **local-only, never synced/signed**.
- **Invariant:** the device clock is `>=` (content comparator) every stamp this device has
  ever *produced* or *observed* in a verified op. This is what lets a local write made after
  seeing a remote edit out-rank it.
- **Crash-safety:** the device-clock update commits in the **same transaction** as the op
  that advanced it. Never stamp an op then persist the clock later.

### 8.2 HLC generation & advance
`pt = now_ms()`; `(last_ms, last_counter)` = persisted device clock; comparisons use the
content comparator on `(ms, counter)`.

**Local event (any local write — create, edit, delete, reorder):**
```
if pt > last_ms:  ms = pt;       counter = 0
else:             ms = last_ms;  counter = last_counter + 1
persist device_clock := (ms, counter)
stamp the op with (ms, counter)        -- which stamp slot: §8.4
```

**Receive a remote op (run for every verified, non-quarantined op — win or lose):**
Reduce the op to one observed clock = max (content comparator) over all clock pairs it
carries (for a card, both its content stamp and its placement stamp, since a reorder's
`position_*` can exceed its `hlc_*`):
```
om, oc = max_by_content_comparator( (op.hlc_ms,op.hlc_counter),
                                    (op.position_ms,op.position_counter) )   // 2nd pair cards only
ms = max(last_ms, om, pt)
if   ms == last_ms and ms == om: counter = max(last_counter, oc) + 1
elif ms == last_ms:              counter = last_counter + 1
elif ms == om:                   counter = oc + 1
else:                            counter = 0          // ms == pt strictly greatest
persist device_clock := (ms, counter)                 // same txn as the apply
```
Advancing on *losing* ops too is required: observing a timestamp obligates the clock to move
past it.

### 8.3 Clock-skew guard (`MAX_SKEW_MS`)
Because the HLC only moves **forward** and absorbs the max time it sees, a single op stamped
absurdly in the future (dead RTC, misconfig, malice) would jam the device clock in the future
**permanently** and spread on sync. Guard, **one-directional** (future only — a past
timestamp merely loses LWW and is harmless):
```
if om - pt > MAX_SKEW_MS:  quarantine(op,"skew");  do NOT advance clock;  do NOT apply
```
- **`MAX_SKEW_MS` default = 300000 (5 min)** — slack for honest clock disagreement (seconds,
  rarely a minute or two) while catching gross/future stamps. Override via `app_setting`.
  *(Flagged value, not a derived constant.)*
- Quarantine = §8.8; the **cursor still advances past** a quarantined op.

### 8.4 Which stamp a write lands on
The device clock advances on **every** local event; only the *target stamp* differs:

| Operation | `hlc_*` (content) | `position_*` (placement) |
|---|---|---|
| Create card | new stamp | new stamp (initial placement) |
| Edit card text/image/kind | new stamp | **unchanged** |
| Delete card (`deleted=1`) | new stamp | **unchanged** |
| Settle / unsettle card (`settled_at`, §3.3) | new stamp | **unchanged** |
| Emphasize / unemphasize card (`emphasized_at`, §3.3) | new stamp | **unchanged** |
| Archive / unarchive collection (`archived_at`, §3.4) | new stamp | n/a |
| Reorder card | **unchanged** | new stamp |
| Move card to another collection | new stamp (`collection_id`) | new stamp (target position) |
| Any non-card entity write | new stamp | n/a |

**Reorder must leave `hlc_*` frozen.** If a reorder bumped the content HLC, a drag on device
B (carrying B's stale text snapshot) would out-rank and erase a concurrent edit on device A —
the exact clobber the two-clock split prevents. The frozen `hlc_*` is why a reorder reuses the
prior content HLC, which is why the sig-keyed `op_id` (§7.3 case 2) is required for the
reorder to survive as a distinct op.

**Move rewrites content and placement on one stamp.** `collection_id` is content, so a move
is a content write; the card also needs a fresh slot in the target feed, so the same stamp
lands on `position_*` (like a create). A concurrent content edit made on another device with
the old `collection_id` can win the content LWW and pull the card back to its source
collection — the usual whole-snapshot LWW trade-off, never a lost card.

### 8.5 The apply procedure (one op = one transaction)
Each op's projection write, `change_log` insert, device-clock advance, and cursor bump commit
in **one transaction**, so the durable cursor always equals the seq of the last fully-applied
op. For each op, in order:
1. **Dedup.** `op_id` already in `change_log` → skip; still advance cursor to this `seq`.
2. **Verify.** `Ed25519_verify(hex_decode(payload.author), utf8(op.payload), hex_decode(op.sig))`.
   Fail → `quarantine("bad_sig")`, advance cursor, no clock advance, no apply. (Verify over
   `utf8(op.payload)`, never re-canonicalize.)
3. **Parse** payload; trust **only** payload values; envelope hints that disagree → reject
   (`quarantine("hint_mismatch")`) or ignore.
4. **Skew guard** (§8.3). Violation → `quarantine("skew")`, advance cursor, no clock, no apply.
5. **Advance device clock** (§8.2) from the op's observed clock — always.
6. **Merge into projection** (merge-core, §8.6 / comparators below): keep higher
   `(hlc_ms,hlc_counter,author,sig)` for content; higher `(position_ms,position_counter,
   position)` for placement; materialize by **overlay** (§7.6). Lose both → no projection
   change (5,7,8 still run).
7. **Record.** Insert op into `change_log` with `origin='remote'` (`acked` irrelevant for
   remote; set `1`).
8. **Advance cursor.** `sync_state.cursor := op.seq`, same transaction.

**Crash safety:** cursor moves only with a durably committed apply; resume from last committed
op; re-pulled ops dedup at step 1; a re-observed op may re-advance the clock (monotonic,
harmless).

**Merge comparators (authoritative):**
- **Content:** higher `(hlc_ms, hlc_counter, author, sig)` wins (integer/byte comparator,
  never string-sorted). `author` = meaningful tiebreak; `sig` = total-order backstop.
- **Placement (cards):** higher `(position_ms, position_counter, position)` wins; `position`
  (fractional-index string) is compared **lexicographically by design** — the one intended
  string ordering (the HLC is not).
- **Delete vs edit:** content-dimension event (`deleted` flag), later HLC wins; a late edit
  can resurrect.
- **Links:** independent; orphans resolved at read time (§8.6.1), not merge time.

### 8.6 Read-time derivations (never synced, never signed)
**8.6.1 Broken-link chip.** For a live link (`deleted=0`), resolve each endpoint via its
`*_type` table; if either endpoint row is missing or `deleted=1` → render a broken-link chip
(offer repair/clear); never auto-delete the link.
```sql
SELECT 1 FROM <collection|card> WHERE id=:endpoint_id AND deleted=0;  -- 0 rows => broken
```
**8.6.2 Backlinks.** `SELECT * FROM link WHERE target_id=:id AND deleted=0;` A backlink whose
**source** is tombstoned/missing renders as a broken chip (same rule), not a live linked-from.

**8.6.3 Home timeline (per collection).** A local view, computed on read for MVP (no cache
table → no invalidation bugs):
- `card_count` = `COUNT(*) WHERE collection_id=:c AND deleted=0`
- `last_card` = the live card with the greatest `created_at`; preview = its text or a
  kind-based summary (image/audio/link). *(Most-recently-added, pairing with the sort below —
  not the bottom-of-feed card, which reorder could make an old one.)*
- `last_updated` = `MAX(created_at)` over live cards, else the collection's own `created_at`.

**Home sort:** collections ordered `last_updated DESC` (latest-updated first), **not
reorderable**. *(Adding a card resurfaces its collection; like a messenger chat list.)*

> **Flagged limitation — `last_updated` tracks adds, not edits.** `created_at` is immutable
> and the HLC has no display duty, so there is no wall-clock "modified" time; editing an
> existing card does **not** resurface its collection. MVP-acceptable. The only real fix is a
> display-only `updated_at` envelope field = a **future wire bump**, not a v1 change.

Materializing the home view into a cache table is an optional later optimization; if added,
invalidate on any committed card op (local/remote) for that collection and any collection
update; the cache is local-only, excluded from sync/signing.

**8.6.4 Collection hubs (per collection).** The hubs over collection `C` are the live
collections with a live link to `C`, made from the collection itself or from one of its live
cards; deduped by source collection, excluding `C` itself, sorted by title. Read in one batch
for the whole home list: the backlinks of every row, then their source cards and collections.
```sql
SELECT * FROM link WHERE target_id IN (:ids) AND deleted=0;  -- then resolve each source
```

**8.6.5 Unlinked mentions (per collection).** A live card *mentions* collection `C` when its
text, folded like search (case, accents, `ё`→`е`) with whitespace runs as one space, contains
`C`'s folded title as a whole phrase: a title edge that is a letter or digit may not touch
another letter or digit. A title under 3 folded characters, or a single very common word
(a short fixed list: "the", "notes", "это", …), mentions nothing. Listed are only cards a
link may come from: live, in a live collection other than `C`, owned by this identity (an
imported collection is read-only, docs/collection_share.md), and not already the source of a
live link to `C`. Newest content write first, capped at 20 (the rest counted). Read as
Search reads: every live card, then `C`'s backlinks; the rule is pure and client-local.

### 8.7 Feed order (cards within a collection)
Concurrent inserts into the same gap can mint identical `position` strings on **different**
cards; the placement comparator only orders competing positions *within one card*. The feed
needs a deterministic final key:
```sql
SELECT * FROM card WHERE collection_id=:c AND deleted=0
ORDER BY position ASC, id ASC;   -- position lexicographic (by design); id (UUIDv7) breaks ties
```
This is a **collection-screen** ordering only. Home (collections) uses §8.6.3.

### 8.8 Quarantine
Quarantined ops (§6.7) are **not applied** and do **not** advance the device clock, but the
**cursor still advances past them** (no infinite re-pull). Retained (diagnosable) and surfaced
as a sync warning.
- `skew` ops may **auto-retry** once `pt` is back within bound (clean re-evaluation from step
  4). `bad_sig` and `hint_mismatch` are **terminal**. *(v1 default; policy is a judgment
  call.)*

### 8.9 Rebuild-from-log (the local-first correctness proof)
The entity tables are a disposable projection of `change_log`:
1. Truncate entity tables (`collection, card, link, attachment, profile`); keep
   `change_log, local_identity, device_clock, app_setting`.
2. Replay `change_log` by `seq ASC` through **merge-core only** (§8.5 step 6 — no re-verify,
   no clock advance, no new `change_log` insert, no cursor change).
3. **Recover the device clock** as a safety net: set it `>=` the max of all `(hlc_ms,
   hlc_counter)` *and* all `(position_ms, position_counter)` across `change_log`, so post-
   rebuild local writes stay strictly monotone even if the persisted clock was lost.

Replaying in `seq` order and merging by the comparator yields the identical projection
regardless of arrival order — that property *is* local-first.

---

## 9. Build order

### 9.1 First vertical slice (no relay) — the local-first gate
Flow: create collection → add text cards → reorder a card → add a link (card→collection and a
"+"-block Connection card) → delete a card that is a link endpoint.

Gates (all must hold):
1. Every mutation is one transaction: entity row + signed `change_log` op (`origin='local'`,
   `acked=0`) + `device_clock` advance.
2. `op_id` is sig-keyed and unique per session — a reorder of a just-edited card produces a
   **distinct** `op_id` from that edit (§7.3 case 2).
3. Reorder leaves the card's `hlc_*` unchanged and advances `position_*`; text intact.
4. Deleting a link endpoint turns the link into a visible broken chip (§8.6.1), no crash, no
   vanished link.
5. **Kill and reopen → projection rebuilds from `change_log`** (§8.9), byte-identical to
   pre-kill (rows, blended placements, feed order), device clock resumes strictly monotone.
   This is the pass/fail line.

### 9.2 Then
Wire the relay: push/pull, ack→`acked=1`, cursor, the §8.5 apply path against
`origin='remote'`. The relay work is gated on §10.

---

## 10. Share / publish flow + relay capability tokens (designed; next to build)

This is now **designed** (locked for MVP below); it remains the next thing to *build*, and is
the **only real security surface** in Knit. Multi-author live collaboration is future, but the
data model (`created_by`) and the access model (the grant table) are already shaped so that
future is **additive**, not a rewrite.

### 10.1 Two layers, kept separate
- **The door — transport access (this section).** A per-topic **grant table** on the relay
  decides *who may reach a topic and in which direction* (`read` = pull, `write` = pull+push).
  Tokens are tickets into it. This is enforceable today.
- **The room — per-entity authority (future, needs `created_by`).** *What* a writer may touch
  *within* a topic. Not enforced in v1: once a grant lets you push, the crypto layer only
  checks "sig matches `payload.author`," so any write-holder can author a higher-HLC snapshot
  over **any** id and win LWW. `created_by` (now in the envelope, §6.3) is the field a future
  rule will read ("`created_by == caller?`") to bound this. **v1 honest property: a `read`
  grant is genuinely safe; a `write` grant = full mutual trust over the whole topic.**

### 10.2 The grant table (relay-side; the source of truth for access)
Access is **not** a list packed inside a token, and **not** a single audience payload. It is a
small per-topic table on the relay (which is already stateful — it stores the op log and
assigns `relay_seq`; "dumb router" means *never parses `payload`*, not *stateless*). One row =
one grant:
```
grant (relay-side)
  topic_id    pubkey            scope   revoked   exp
  X           null              read    false     <ms>     ← the open "anyone with link" row
  X           mira#<pubkey>     write   false     <ms>
  X           theo#<pubkey>     read    false     <ms>
```
- **`pubkey = null`** → pure **bearer**: holding a valid token for the topic grants the row's
  scope, no identity proof. This is the MVP "anyone with the link can read" case.
- **`pubkey = <key>`** → **bound**: the caller must prove they hold that key (§10.4) and gets
  *that row's* scope. This is the future "share to specific identities, each with its own
  scope" case — **different keys, different scopes = different rows**, set/changed/revoked one
  at a time without disturbing anyone else.
- Everything you wanted falls out: per-identity scope is per-row; **revoke = flip one
  boolean** (no reissue, no shared-secret churn); and because scope/audience live in the row,
  **the token leaks nothing** about who else is in the collaboration.

### 10.3 The token (the thing you hand out; a minimal pointer)
Opaque, high-entropy, carries **no scope and no audience** — only enough to locate its grant:
```
token  = random_id                        // bearer string, sent as: Authorization: Bearer <token>
         + names its topic + grant
share link / QR bundles:  { relay_url, topic, token }
```
- **Opaque-random chosen for v1** (not owner-signed): revocation is free (delete/flag the
  grant row) precisely because the relay is already stateful.
- One token may map to the `null` row (open link) or to a specific bound row (per-person
  ticket). The future targeted share can mint **one token per invited identity**, each
  pointing at that person's grant row.

#### 10.3.1 Token portability across relays (deferred, with a cheap seam recorded now)
A *share* is a different object from an *identity*. Identity is already relay-independent
(§5, a keypair, survives switching relays). A share is "this collection, at this address,
under these rules" — and an **opaque-random token is intrinsically bound to the relay that
minted it**, because all its meaning lives in that relay's grant row. So today, moving a
topic to another relay kills every link already handed out: you must re-create the topic,
re-insert the grants, re-issue tokens, and recipients' subscriptions must be re-established.

That is **not a problem the MVP has** — a user configures one relay (Settings → Sync/Relay);
there is nothing to be portable *across*. Paying for portability now means building offline
token minting *and* re-introducing relay-side state for revocation (a `jti` blocklist) — the
exact statefulness self-describing tokens exist to remove — to serve a consumer that does not
exist until multi-relay is real. Deferred as premature generality.

**The future upgrade is owner-signed tokens:** the token *encodes* `{topic, scope, exp, jti}`
and is **signed by the owner's identity key**, so any relay that knows `topic → owner pubkey`
validates it by signature alone (no local row), and the *same token* is honored after a topic
moves. Mint offline; revoke via a relay-side `jti` set. The swap touches **only two things** —
how a token is minted (relay row → owner signature) and how the relay validates one (row
lookup → sig check + revocation lookup). The grant table, the bound-handshake (§10.4, which
already proves a key — exactly what owner-signed validation leans on), the wire format, the op
stream, and the client merge engine are all unchanged. It is a clean later swap, triggered by
real multi-relay need (and that need — cross-relay *migration* vs. *mirroring* — has different
answers best designed against a concrete scenario, not in the abstract).

**The seam to record now (cheap, behavior-neutral):** bind **`topic → owner_pubkey` at
topic-creation time**, even in v1. The opaque-random relay doesn't strictly use it, but
recording "topic X was created by pubkey P" from day one gives the owner-signed upgrade the
anchor it requires *already present in historical topics*, instead of being un-introducible
for topics that already exist. One column on the topic record; changes no v1 behavior.
```
topic (relay-side)
  topic_id    owner_pubkey      created_at
  X           9f86…a08          <ms>          ← recorded now; unused by opaque-random, the anchor for owner-signed later
```

### 10.4 Bound-grant handshake (future identities; sign-a-challenge)
For a row with a `pubkey`, possession of the token is not enough — the caller proves the key:
```
1. client → relay:  hello(topic, token)
2. relay  → client: nonce (random, short-lived)
3. client → relay:  sig = Ed25519_sign(secret, nonce) , pubkey
4. relay verifies sig against the grant row's pubkey  → binds the session to that scope
```
The `null` (bearer) row skips steps 2–3. **Same code path; the open link is the degenerate
case where no key is required.** This also means link-sharing **bootstraps the peer graph**:
to later target identities you must know their pubkeys, and the open link / a share-back is
how they enter your `peer` table in the first place.

### 10.5 Subscribe vs. fork (two distinct recipient actions)
Opening a share link is a **live read-only subscription** (the recipient keeps pulling and
sees new cards as the publisher adds them). **Saving a copy** is the separate **fork**:
snapshot into the recipient's own local collection, **new ids**, editable, severed from the
topic. The share-flow UX offers both: *open link → follow (read-only, live)*; *"Save a copy"
button → fork*.

**Fork id-remapping rules:** mint a new `id` for the collection and for every card; rewrite
intra-set link endpoints to the new ids (links pointing outside the forked set become orphans
→ broken-link chips, expected); copy attachment refs (bytes re-fetched by `content_hash`).
The forked entities are **authored by the recipient** — `author = created_by = recipient`,
fresh `created_at`, fresh HLC — because a fork is a genuinely new local creation, not a
continuation of the publisher's entities.

> **Decided:** on fork, `created_at` is **reset to now** — a fork *is* a new local object, so
> the forked collection floats to the top of the recipient's home as "just saved" (consistent
> with the recipient being `author = created_by`). A soft **"forked from `<share_id>`" origin
> marker is kept locally** (local-only, unsigned) — useful for a future "re-subscribe to
> source" affordance, and it never syncs or signs.

### 10.6 The MVP share flow (concrete)
Share flow → pick **expiry** → tap **Share** → spinner = the relay round-trip that **creates
the grant row(s) and mints the token** → you get a link to send. MVP creates exactly one row
(`pubkey=null, scope=read`) + one token. The **future** version inserts the same flow's
identity-picker step: select identities + per-identity scope → creates N bound rows (one per
identity, each scoped) → mints one token per person (or one shared token). **Nothing about the
token format or the relay's check changes between phases — you only add rows to a table that
already exists.**

> **Expiry/revoke honesty (UI copy must say this):** expiry and "stop sharing" cut **future**
> pulls only. Whatever a recipient already pulled is in their local DB — you cannot un-give it.
> "Expire in 7 days" means "no more pulls after this," not "the data evaporates."

### 10.7 Still to define when building
- **Publish set assembly & push** — gather the collection + its live cards + their links +
  referenced attachment metadata, push as the topic's op stream; ongoing local writes to a
  shared collection enqueue to that topic.
- **Attachment bytes over the relay** — wire the deferred content-addressed blob transfer
  (§7.7): `GET/PUT /v1/blobs/{hash}` with hash verification, lazy pull.
- **Relay enforcement boundary** — token/grant check + bound-handshake + per-topic append-only
  log + dedup + `relay_seq`; still never parses or trusts `payload`. Push rejection reasons:
  `bad_token`, `revoked`, `expired`, `no_push_scope`, `bad_challenge`, `bad_sig` (optional).
- **Live delivery (optional)** — the WebSocket upgrade over pull polling; same auth/handshake.

### 10.8 File share (built; the offline transport)
A collection can be sent as a **file** with no relay: `<title>.knitc`
(`application/vnd.knit.collection+zip`), the backup's zip shape with its own format tag.
Full design: **`docs/collection_share.md`**.
- **Payload** — the sender's signed ops **verbatim**, winning ops only: per entity the
  content winner (+ a card's placement winner), tombstones included, plus each author's
  `profile`. Never re-signed. **Include media** (default on) adds the blobs.
- **Linked collections** — the export sheet warns when the collection's live links point
  outside it ("N connections point outside this collection · M can't be included (not
  yours)"). **Include linked collections** (default off) also ships each reached collection
  that is the sender's own, whole and one level deep (a card target brings its collection);
  someone else's stays a broken link. Such a file is manifest version 2 (`included`); a
  single-collection file stays version 1, and an older app refuses version 2 as "from a
  newer Knit".
- **Import** = the §10.5 *subscription*: the whole file is validated first, every
  collection in it alike (signatures, author = that collection's owner, each op within its
  own collection's scope, and no op may target a local id with a different `created_by`),
  then every op goes through `applyRemote` (`remote/acked`) and the primary opens. Same ids, so a newer file
  updates the copy by LWW and an older one changes nothing. Your own file is a mini-restore.
- **Read-only** is derived: `collection.created_by ≠` this device's key. No composer,
  reorder, selection or header edit; Archive is a local-only flag; it is never a move or
  share-capture target, but it can be linked to and presented.
- **Save a copy** = the §10.5 fork (new ids, intra-set links rewritten, attachments keep
  their `content_hash`). The local "forked from" marker is deferred.
- **Remove** = a local purge of the rows *and* their `change_log` ops (so §8.9 rebuild
  agrees) and of unreferenced blobs. Nothing is signed; a re-import restores it.
- When the relay lands it replaces the file as the transport; the read-only model, fork and
  purge stay. A file is a snapshot and cannot be revoked (the §10.6 honesty).

---

## Open calls carried forward (sign-off)
- **`sig16` width** = 8 bytes; residual false-dedup ≈ `2^-64` per same-triple pair — accepted;
  widening is local-only.
- **`MAX_SKEW_MS`** = 5 min — value is a judgment call; revisit with real peer data.
- **Skew-retry policy** — v1: retry `skew` when `pt` back in bound; `bad_sig` /
  `hint_mismatch` terminal.
- **`last_updated` = newest card, not newest edit** — MVP-acceptable; real fix is a display-
  only `updated_at` (future wire bump).
- **Reorder blend** = project + re-attest (§7.6) vs a separate signed placement op — re-attest
  adopted; placement-op is the additive escape hatch if multi-author ordering needs
  cryptographic provenance.
- **Share trust** (§10) — v1: read-only (`read` grant) is safe; write share = full mutual
  trust over the whole topic until per-entity ownership exists.
- **`created_by` reinstated** (§6.2/§6.3) — immutable provenance, carried signed, not enforced
  in v1; it is the field bounded collaboration ("edit only your own") will read later, with no
  wire bump. **Must be preserved (never restamped) on every edit.**
- **Access = relay-side grant table + opaque per-holder tokens** (§10.2–10.3), not an
  audience-list inside the token. `null`-pubkey row = open bearer link (MVP); pubkey rows =
  bound, per-identity scope (future).
- **Token style = opaque-random for v1** (§10.3.1); free revoke via grant row. **Owner-signed
  is the documented upgrade, triggered by real multi-relay need** — a two-point swap (mint +
  validate), nothing else moves. **Seam recorded now:** `topic → owner_pubkey` bound at
  topic-creation (one column, unused by v1, the anchor owner-signed needs in historical data).
- **Fork `created_at` = reset-to-now** (§10.5, **decided**) — a fork is a new local object, so
  it floats to the top of the recipient's home as "just saved"; keep a local-only, unsigned
  "forked from `<share_id>`" origin marker.
