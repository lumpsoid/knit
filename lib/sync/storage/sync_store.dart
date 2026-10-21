import 'dart:convert';

import 'package:knit/core/storage/domain/storage_context.dart';
import 'package:knit/core/storage/domain/unit_of_work.dart';
import 'package:knit/sync/engine.dart';
import 'package:knit/sync/hlc.dart';
import 'package:knit/sync/identity/identity.dart';
import 'package:knit/sync/merge.dart';
import 'package:knit/sync/snapshot.dart';
import 'package:knit/sync/storage/change_log/change_log.dart';
import 'package:knit/sync/storage/derivations/derivations.dart';
import 'package:knit/sync/storage/device_clock/device_clock.dart';
import 'package:knit/sync/storage/projection/projection.dart';
import 'package:knit/sync/storage/quarantine/quarantine.dart';
import 'package:knit/sync/storage/share/share.dart';
import 'package:knit/sync/wire/wire.dart';

/// The persistent apply + write orchestrator — ties the durable
/// [ChangeLogStorage], the materialized [ProjectionStorage], the
/// [DeviceClockStorage], the [LocalIdentityStorage], and the [QuarantineStorage]
/// to the merge-core (spec §8.5 / §8.9) and the upstream write path (§6.8), all
/// through the storage abstractions so the same code runs on sqflite in
/// production and on in-memory fakes in dev/tests.
///
/// Crash-safety (spec §8.5/§6.8): every apply *and* every local write commits the
/// projection write, the change_log insert, and the device-clock save in **one**
/// [UnitOfWork] transaction, so the persisted state is always internally
/// consistent.
class SyncStore {
  SyncStore({
    required this.changeLog,
    required this.projection,
    required this.deviceClock,
    required this.localIdentity,
    required this.quarantine,
    required this.signer,
    UnitOfWork unitOfWork = const NoOpUnitOfWork(),
    SecretBox secretBox = const PlaintextSecretBox(),
    DeviceClock? clock,
    this.maxSkewMs = kMaxSkewMs,
  }) : _unitOfWork = unitOfWork,
       _secretBox = secretBox,
       _clock = clock ?? DeviceClock();

  /// Fully in-memory wiring for dev mode and tests — no SQLite, no transaction,
  /// no real crypto (a deterministic [FakeSigner]).
  factory SyncStore.inMemory({int maxSkewMs = kMaxSkewMs, Signer? signer}) =>
      SyncStore(
        changeLog: InMemoryChangeLogStorage(),
        projection: InMemoryProjectionStorage(),
        deviceClock: InMemoryDeviceClockStorage(),
        localIdentity: InMemoryLocalIdentityStorage(),
        quarantine: InMemoryQuarantineStorage(),
        signer: signer ?? FakeSigner(),
        maxSkewMs: maxSkewMs,
      );

  final ChangeLogStorage changeLog;
  final ProjectionStorage projection;
  final DeviceClockStorage deviceClock;
  final LocalIdentityStorage localIdentity;
  final QuarantineStorage quarantine;
  final Signer signer;
  final UnitOfWork _unitOfWork;
  final SecretBox _secretBox;
  final int maxSkewMs;

  DeviceClock _clock;

  /// The in-memory device HLC (loaded from [deviceClock] by [open]/[rebuild]).
  DeviceClock get clock => _clock;

  /// Cached identity: the public key (= `author`) and the decrypted secret key.
  ({String pubkey, List<int> secret})? _identityCache;

  /// Create tables, restore the persisted device clock, and (by default)
  /// provision the device identity (spec §6.5). Call once at startup.
  ///
  /// [ensureSchema] is skipped when the schema is owned by an external migrator
  /// (the production graph runs `package:sql_migrator` first, §6.4). Set
  /// [provisionIdentity] to `false` to defer keypair generation to an explicit
  /// step — the first-run onboarding "Generate" moment ([provisionIdentity]) —
  /// so a fresh device reports [hasIdentity] `false` until the user opts in.
  Future<void> open({
    bool ensureSchema = true,
    bool provisionIdentity = true,
  }) async {
    if (ensureSchema) {
      await changeLog.ensureSchema();
      await projection.ensureSchema();
      await deviceClock.ensureSchema();
      await localIdentity.ensureSchema();
      await quarantine.ensureSchema();
    }
    final saved = await deviceClock.load();
    if (saved != null) _clock.restore(saved);
    if (provisionIdentity) await _identity();
  }

  // --- Reads (spec §8.6/§8.7) ------------------------------------------------

  Future<Snapshot?> get(EntityType type, String id) => projection.get(type, id);

  /// Every projected row of [type] (including soft-deleted). Used by the
  /// attachment foundation for content-hash dedup and reference-counted blob GC.
  Future<List<Snapshot>> readAll(EntityType type) async =>
      (await projection.readAll())
          .where((s) => s.type == type)
          .toList(growable: false);

  Future<List<Snapshot>> feed(String collectionId) =>
      projection.feed(collectionId);

  /// A newest-first keyset page of a collection's live cards (§8.7) — see
  /// [ProjectionStorage.feedPage].
  Future<List<Snapshot>> feedPage(
    String collectionId, {
    FeedKey? before,
    FeedKey? atOrAfter,
    int? limit,
  }) => projection.feedPage(
    collectionId,
    before: before,
    atOrAfter: atOrAfter,
    limit: limit,
  );

  /// The rows of [type] for [ids], batched (tombstones included).
  Future<List<Snapshot>> getMany(EntityType type, Iterable<String> ids) =>
      projection.getMany(type, ids);

  /// Live link count (links-out + backlinks) per id in [entityIds], batched.
  Future<Map<String, int>> linkCounts(Iterable<String> entityIds) =>
      projection.linkCounts(entityIds);

  Future<List<Snapshot>> backlinks(String targetId) =>
      projection.backlinks(targetId);

  /// Live links originating at [sourceId] — forward connections (spec §4.4).
  Future<List<Snapshot>> linksOut(String sourceId) =>
      projection.linksOut(sourceId);

  /// Endpoint liveness for a live [link] — the broken-link chip (spec §8.6.1).
  /// Never auto-deletes; the UI offers repair/clear.
  Future<LinkEndpointStatus> linkStatus(Snapshot link) =>
      BrokenLinkResolver(projection).resolve(link);

  /// The home timeline — per-collection counters, sorted `last_updated DESC`
  /// (spec §8.6.3). Computed on read from the full projection (no cache table).
  Future<List<CollectionSummary>> homeTimeline() async =>
      buildHomeTimeline(await projection.readAll());

  /// Pending-sync indicator (spec §6.6) — local ops not yet acked.
  Future<int> pendingCount() => changeLog.pendingCount();

  /// This device's public key (= `author`/`created_by` on local writes). Lazily
  /// provisions the identity if [open] has not run.
  Future<String> authorPubkey() async => (await _identity()).pubkey;

  /// Whether this device already has a provisioned identity (spec §6.5). The
  /// onboarding gate: `false` on a fresh device until [provisionIdentity] runs.
  Future<bool> hasIdentity() async =>
      _identityCache != null || (await localIdentity.load()) != null;

  /// Explicitly provision (or load) the device identity, returning its public
  /// key (spec §5/§6.5). The deliberate first-run "Generate" step; idempotent —
  /// returns the existing key if one is already provisioned.
  Future<String> provisionIdentity() async => (await _identity()).pubkey;

  /// The device keypair in the clear — for the backup bundle only, which seals
  /// the secret under a user passphrase before it leaves the store (§5: identity
  /// is backed up by backing up the keypair). Provisions one if [open] has not.
  Future<Keypair> exportKeypair() async {
    final identity = await _identity();
    return Keypair(publicKeyHex: identity.pubkey, secretKey: identity.secret);
  }

  /// Adopt [keypair] as this device's identity, replacing any current one
  /// (restore from a backup, §5). The secret is checked against the public key
  /// first — a probe signed with it must verify under [Keypair.publicKeyHex] —
  /// so a mismatched pair throws [ArgumentError] and leaves the device as it
  /// was. Content is untouched: a caller restoring a whole device runs
  /// [resetDevice] first.
  Future<void> adoptIdentity(Keypair keypair) async {
    final probe = utf8.encode('knit-identity-probe');
    final sig = await signer.sign(keypair.secretKey, probe);
    if (!await signer.verify(keypair.publicKeyHex, probe, sig)) {
      throw ArgumentError('the secret key does not match the public key');
    }
    await localIdentity.clear();
    await localIdentity.save(
      LocalIdentity(
        publicKeyHex: keypair.publicKeyHex,
        secretKeyEnc: _secretBox.seal(keypair.secretKey),
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    _identityCache = (
      pubkey: keypair.publicKeyHex,
      secret: List<int>.unmodifiable(keypair.secretKey),
    );
  }

  // --- Apply remote (spec §8.5) ----------------------------------------------

  /// Apply a verified remote op and persist it atomically — spec §8.5.
  ///
  /// Dedup by `op_id` (step 1) → **verify the signature over the received bytes**
  /// (step 2; fail → quarantine `bad_sig`) → skew guard (step 4; fail →
  /// quarantine `skew`) → in one transaction: read current, advance the clock
  /// (step 5), merge (step 6), write the winner, record the op as `remote/acked`
  /// (step 7), and save the clock. A quarantined op is neither merged nor
  /// recorded in `change_log`, and the device clock is not advanced.
  Future<ApplyOutcome> applyRemote(PersistedOp op, int physicalNowMs) async {
    if (await changeLog.hasOp(op.opId)) return ApplyOutcome.deduped;

    // Step 2: verify over `utf8(op.payload)`, never re-canonicalized. Trust the
    // payload's own author (the envelope `op.author` is only a hint, §7.2).
    final author = _payloadAuthor(op.payload);
    final verified = await signer.verify(
      author,
      utf8.encode(op.payload),
      op.sig,
    );
    if (!verified) {
      await quarantine.add(
        QuarantinedOp(
          opId: op.opId,
          reason: QuarantineReason.badSig,
          rawOp: op.payload,
          seenAt: physicalNowMs,
        ),
      );
      return ApplyOutcome.quarantinedBadSig;
    }

    final snapshot = op.toSnapshot();
    final observed = snapshot.observedClock;
    if (exceedsSkew(observed.ms, physicalNowMs, maxSkewMs: maxSkewMs)) {
      await quarantine.add(
        QuarantinedOp(
          opId: op.opId,
          reason: QuarantineReason.skew,
          rawOp: op.payload,
          seenAt: physicalNowMs,
        ),
      );
      return ApplyOutcome.quarantinedSkew;
    }

    await _unitOfWork.run((ctx) async {
      final current = await projection.get(
        snapshot.type,
        snapshot.id,
        ctx: ctx,
      );
      _clock.observe(observed, physicalNowMs);
      final winner = merge(current, snapshot);
      await projection.upsert(winner, ctx: ctx);
      await changeLog.append(
        op.copyWith(origin: SyncOrigin.remote, acked: true),
        ctx: ctx,
      );
      await deviceClock.save(_clock.now, ctx: ctx);
    });
    return ApplyOutcome.applied;
  }

  // --- Local write path (spec §6.8/§8.4) -------------------------------------

  /// Create a new entity. Cards require a [position] (the initial placement);
  /// `created_by` and `author` are set to this device's key (§6.2). [content]
  /// carries the §7.4 entity fields (missing optional fields default to null).
  Future<PersistedOp> create(
    EntityType type,
    String id,
    Map<String, Object?> content, {
    String? position,
    int? physicalNowMs,
  }) {
    assert(
      (type == EntityType.card) == (position != null),
      'cards need a position; non-cards must not pass one',
    );
    return _writeLocal(
      type: type,
      id: id,
      physicalNowMs: physicalNowMs,
      build: _creation(type, id, content, position),
    );
  }

  /// The [_writeOne] builder of a fresh entity: this device is both `author`
  /// and `created_by` (§6.2), and a card's placement takes the same stamp.
  static Snapshot Function(Hlc stamp, Snapshot? prior, String author) _creation(
    EntityType type,
    String id,
    Map<String, Object?> content,
    String? position,
  ) {
    final filled = _withContentDefaults(type, content);
    return (stamp, prior, author) => Snapshot(
      type: type,
      id: id,
      author: author,
      createdBy: author, // §6.2: creator stamps created_by on create
      createdAt: stamp.ms,
      hlc: stamp,
      deleted: false,
      sig: '',
      placement: type == EntityType.card ? stamp : null,
      position: type == EntityType.card ? position : null,
      content: filled,
    );
  }

  /// Edit an existing entity's content. New content stamp; placement frozen for
  /// cards (§8.4); `created_by` preserved from the prior row (§6.2). [content]
  /// overlays the prior content, so callers pass only changed fields.
  Future<PersistedOp> edit(
    EntityType type,
    String id,
    Map<String, Object?> content, {
    int? physicalNowMs,
  }) {
    return _writeLocal(
      type: type,
      id: id,
      physicalNowMs: physicalNowMs,
      build: (stamp, prior, author) {
        final base = _require(prior, 'edit', type, id);
        return base.copyWith(
          author: author,
          createdBy: base.createdBy, // preserve, never restamp (§6.2)
          hlc: stamp, // new content stamp
          deleted: false,
          sig: '',
          // placement/position frozen (copyWith keeps prior).
          content: {...base.content, ...content},
        );
      },
    );
  }

  /// Soft-delete an entity (`deleted=1`) — a signed snapshot, not an unsigned op
  /// (§7.0). New content stamp; placement unchanged for cards (§8.4).
  Future<PersistedOp> delete(EntityType type, String id, {int? physicalNowMs}) {
    return _writeLocal(
      type: type,
      id: id,
      physicalNowMs: physicalNowMs,
      build: (stamp, prior, author) {
        final base = _require(prior, 'delete', type, id);
        return base.copyWith(
          author: author,
          hlc: stamp, // content-dimension event (§6.9)
          deleted: true,
          sig: '',
        );
      },
    );
  }

  /// Soft-delete cards (§6.1) — a [delete] per card, all committed in **one**
  /// transaction: either every card goes or none does. Placement is left
  /// frozen (§8.4). Returns the ops in [cardIds] order.
  Future<List<PersistedOp>> deleteCards(
    Iterable<String> cardIds, {
    int? physicalNowMs,
  }) async {
    final now = physicalNowMs ?? DateTime.now().millisecondsSinceEpoch;
    final identity = await _identity();
    return _unitOfWork.run((ctx) async {
      final ops = <PersistedOp>[];
      for (final cardId in cardIds) {
        ops.add(
          await _writeOne(
            ctx: ctx,
            identity: identity,
            now: now,
            type: EntityType.card,
            id: cardId,
            build: (stamp, prior, author) {
              final base = _require(prior, 'delete', EntityType.card, cardId);
              return base.copyWith(
                author: author,
                hlc: stamp, // content-dimension event (§6.9)
                deleted: true,
                sig: '',
              );
            },
          ),
        );
      }
      await deviceClock.save(_clock.now, ctx: ctx);
      return ops;
    });
  }

  /// Reorder a card — fresh **placement** stamp, content `hlc_*` left frozen
  /// (§8.4, or a stale drag would clobber a concurrent edit). Distinct `op_id`
  /// from the edit it followed comes from the new `sig` (§7.3 case 2).
  Future<PersistedOp> reorder(
    String cardId,
    String position, {
    int? physicalNowMs,
  }) {
    return _writeLocal(
      type: EntityType.card,
      id: cardId,
      physicalNowMs: physicalNowMs,
      build: (stamp, prior, author) {
        final base = _require(prior, 'reorder', EntityType.card, cardId);
        return base.copyWith(
          author: author,
          // hlc frozen (copyWith keeps prior content stamp).
          sig: '',
          placement: stamp, // new placement stamp
          position: position,
        );
      },
    );
  }

  /// Move cards into [collectionId] (§8.4) — each card in [positions] (card id
  /// → its new position in the target) is one signed op that rewrites
  /// `collection_id` *and* lands a fresh placement, so both clocks take the
  /// same new stamp (like a create). All the ops commit in **one** transaction:
  /// either every card moves or none does. Returns the ops in [positions] order.
  Future<List<PersistedOp>> moveCards(
    String collectionId,
    Map<String, String> positions, {
    int? physicalNowMs,
  }) async {
    final now = physicalNowMs ?? DateTime.now().millisecondsSinceEpoch;
    final identity = await _identity();
    return _unitOfWork.run((ctx) async {
      final ops = <PersistedOp>[];
      for (final MapEntry(key: cardId, value: position) in positions.entries) {
        ops.add(
          await _writeOne(
            ctx: ctx,
            identity: identity,
            now: now,
            type: EntityType.card,
            id: cardId,
            build: (stamp, prior, author) {
              final base = _require(prior, 'move', EntityType.card, cardId);
              return base.copyWith(
                author: author,
                hlc: stamp, // collection_id is content (§8.4)
                deleted: false,
                sig: '',
                placement: stamp, // a fresh slot in the target feed
                position: position,
                content: {...base.content, 'collection_id': collectionId},
              );
            },
          ),
        );
      }
      await deviceClock.save(_clock.now, ctx: ctx);
      return ops;
    });
  }

  /// Settle (or, with [settled] false, unsettle) cards (§3.3) — a content
  /// write per card that sets `settled_at` to the write's own stamp time, or
  /// clears it. Settling also clears `emphasized_at`: a card is live, settled
  /// or emphasized, never both. Placement is left frozen (§8.4). All the ops
  /// commit in **one** transaction. Returns the ops in [cardIds] order.
  Future<List<PersistedOp>> setCardsSettled(
    Iterable<String> cardIds, {
    required bool settled,
    int? physicalNowMs,
  }) => _setCardsMark(
    cardIds,
    field: 'settled_at',
    other: 'emphasized_at',
    on: settled,
    what: 'settle',
    physicalNowMs: physicalNowMs,
  );

  /// Emphasize (or, with [emphasized] false, unemphasize) cards (§3.3) — the
  /// counterpart of [setCardsSettled] on `emphasized_at`. Emphasizing clears
  /// `settled_at`. One transaction; returns the ops in [cardIds] order.
  Future<List<PersistedOp>> setCardsEmphasized(
    Iterable<String> cardIds, {
    required bool emphasized,
    int? physicalNowMs,
  }) => _setCardsMark(
    cardIds,
    field: 'emphasized_at',
    other: 'settled_at',
    on: emphasized,
    what: 'emphasize',
    physicalNowMs: physicalNowMs,
  );

  /// Sets a card mark [field] to the write's stamp time (or clears it), and
  /// clears the exclusive [other] mark when setting it.
  Future<List<PersistedOp>> _setCardsMark(
    Iterable<String> cardIds, {
    required String field,
    required String other,
    required bool on,
    required String what,
    int? physicalNowMs,
  }) async {
    final now = physicalNowMs ?? DateTime.now().millisecondsSinceEpoch;
    final identity = await _identity();
    return _unitOfWork.run((ctx) async {
      final ops = <PersistedOp>[];
      for (final cardId in cardIds) {
        ops.add(
          await _writeOne(
            ctx: ctx,
            identity: identity,
            now: now,
            type: EntityType.card,
            id: cardId,
            build: (stamp, prior, author) {
              final base = _require(prior, what, EntityType.card, cardId);
              return base.copyWith(
                author: author,
                createdBy: base.createdBy, // preserve, never restamp (§6.2)
                hlc: stamp, // the marks are content (§8.4)
                deleted: false,
                sig: '',
                content: {
                  ...base.content,
                  field: on ? stamp.ms : null,
                  if (on) other: null,
                },
              );
            },
          ),
        );
      }
      await deviceClock.save(_clock.now, ctx: ctx);
      return ops;
    });
  }

  /// Archive (or, with [archived] false, unarchive) a collection (§3.4) — a
  /// content write that sets `archived_at` to the write's own stamp time, or
  /// clears it. Its cards are untouched.
  Future<PersistedOp> setCollectionArchived(
    String collectionId, {
    required bool archived,
    int? physicalNowMs,
  }) {
    return _writeLocal(
      type: EntityType.collection,
      id: collectionId,
      physicalNowMs: physicalNowMs,
      build: (stamp, prior, author) {
        final base = _require(
          prior,
          'archive',
          EntityType.collection,
          collectionId,
        );
        return base.copyWith(
          author: author,
          createdBy: base.createdBy, // preserve, never restamp (§6.2)
          hlc: stamp,
          deleted: false,
          sig: '',
          content: {...base.content, 'archived_at': archived ? stamp.ms : null},
        );
      },
    );
  }

  /// The shared one-transaction local write (spec §6.8 steps 1–3): one
  /// [_writeOne] plus the device-clock save, committed together.
  Future<PersistedOp> _writeLocal({
    required EntityType type,
    required String id,
    required Snapshot Function(Hlc stamp, Snapshot? prior, String author) build,
    int? physicalNowMs,
  }) async {
    final now = physicalNowMs ?? DateTime.now().millisecondsSinceEpoch;
    final identity = await _identity();
    return _unitOfWork.run((ctx) async {
      final op = await _writeOne(
        ctx: ctx,
        identity: identity,
        now: now,
        type: type,
        id: id,
        build: build,
      );
      await deviceClock.save(_clock.now, ctx: ctx);
      return op;
    });
  }

  /// One local write inside an open transaction: read prior, mint exactly one
  /// device stamp (§8.2), build → canonical (§7.1) → sign (§6.8) → `op_id`
  /// (§7.3), then upsert projection + append op. The caller saves the clock.
  Future<PersistedOp> _writeOne({
    required StorageContext ctx,
    required ({String pubkey, List<int> secret}) identity,
    required int now,
    required EntityType type,
    required String id,
    required Snapshot Function(Hlc stamp, Snapshot? prior, String author) build,
  }) async {
    final prior = await projection.get(type, id, ctx: ctx);
    final stamp = _clock.localTick(now); // exactly one tick per write (§8.2)
    final built = build(stamp, prior, identity.pubkey);
    // A prior from an older peer's payload may lack a later-added field
    // (e.g. `settled_at`); fill it with null so the field set stays complete.
    final unsigned = built.copyWith(
      content: _withContentDefaults(type, built.content),
    );
    final payload = CanonicalSerializer.string(unsigned);
    final sig = await signer.sign(identity.secret, utf8.encode(payload));
    final snap = unsigned.copyWith(sig: sig);
    final op = PersistedOp.fromSnapshot(
      snap,
      opId: OpId.build(entityId: id, hlc: snap.hlc, sig: sig),
      payload: payload,
      origin: SyncOrigin.local, // acked defaults to false (§6.8 step 2)
    );
    // Materialize through the merge-core, exactly as a rebuild would (§8.9):
    // a reorder keeps the prior content stamp, so the content winner between
    // it and the op it followed is settled by `sig` (§6.9), not by arrival.
    await projection.upsert(merge(prior, snap), ctx: ctx);
    await changeLog.append(op, ctx: ctx);
    return op;
  }

  // --- Collection share by file (docs/collection_share.md) -----------------

  /// The signed ops that share [collectionId] (docs/collection_share.md "The
  /// share set"): per entity of its [ShareScope] the winning op(s), picked by
  /// [ShareSetSelector], plus the winning `profile` op of every author and
  /// creator among them, so nicknames resolve. Ops are verbatim, never
  /// re-signed. Throws [StateError] for an unknown collection.
  Future<ShareSet> shareSet(String collectionId) async {
    final rows = await projection.readAll();
    final collection =
        rows
            .where(
              (s) => s.type == EntityType.collection && s.id == collectionId,
            )
            .firstOrNull ??
        (throw StateError('share of missing collection $collectionId'));
    final scope = ShareScope.of(collectionId, rows);
    const selector = ShareSetSelector();
    final ops = selector.winners(
      await changeLog.readForEntities(scope.entityIds),
    );
    final people = {
      for (final op in ops) ...[
        op.toSnapshot().author,
        op.toSnapshot().createdBy,
      ],
    };
    final profiles = selector
        .winners(await changeLog.readForEntities(people))
        .where((op) => op.entityType == EntityType.profile.name);
    return ShareSet(
      collection: collection,
      liveCardCount: scope.liveCardIds.length,
      ops: [...profiles, ...ops],
      media: {
        for (final s in rows)
          if (s.type == EntityType.attachment &&
              !s.deleted &&
              scope.attachmentIds.contains(s.id))
            if (s.content[AttachmentSchema.colContentHash] case final String h)
              h: (s.content[AttachmentSchema.colSize] as num?)?.toInt(),
      },
    );
  }

  /// Remove an imported collection from this device (docs/collection_share.md
  /// "Remove"): in one transaction, the projection rows of its [ShareScope]
  /// *and* their ops in `change_log` go, so rebuild-from-log (§8.9) stays
  /// identical. Nothing is signed; importing the file again restores it. An
  /// attachment still referenced from outside the collection is kept. Links
  /// from other cards into it survive as broken chips (§8.6.1).
  ///
  /// Returns the content hashes no remaining attachment references; the caller
  /// deletes those blobs. Refuses (throws [StateError]) this device's own
  /// collection — that path is the signed delete. An unknown id is a no-op.
  Future<Set<String>> purgeCollection(String collectionId) async {
    final me = await authorPubkey();
    return _unitOfWork.run((ctx) async {
      final rows = await projection.readAll(ctx: ctx);
      final collection = rows
          .where((s) => s.type == EntityType.collection && s.id == collectionId)
          .firstOrNull;
      if (collection == null) return const <String>{};
      if (collection.createdBy == me) {
        throw StateError('purge of own collection $collectionId');
      }
      final scope = ShareScope.of(collectionId, rows);
      final inScope = scope.entityIds;
      final referencedOutside = {
        for (final s in rows)
          if (!inScope.contains(s.id))
            ?(s.content[CardSchema.colAttachmentId] ??
                    s.content[CollectionSchema.colCoverAttachmentId])
                as String?,
      };
      final attachmentIds = scope.attachmentIds.difference(referencedOutside);
      final purged = <String>{};
      final kept = <String>{};
      for (final s in rows) {
        if (s.type != EntityType.attachment) continue;
        final hash = s.content[AttachmentSchema.colContentHash] as String?;
        if (hash == null) continue;
        (attachmentIds.contains(s.id) ? purged : kept).add(hash);
      }

      await projection.deleteMany(EntityType.collection, [
        collectionId,
      ], ctx: ctx);
      await projection.deleteMany(EntityType.card, scope.cardIds, ctx: ctx);
      await projection.deleteMany(EntityType.link, scope.linkIds, ctx: ctx);
      await projection.deleteMany(
        EntityType.attachment,
        attachmentIds,
        ctx: ctx,
      );
      await changeLog.deleteForEntities({
        collectionId,
        ...scope.cardIds,
        ...scope.linkIds,
        ...attachmentIds,
      }, ctx: ctx);
      return purged.difference(kept);
    });
  }

  /// Write a fork (§10.5 "Save a copy"): every entity of [plan] is created
  /// as this device's own — fresh ids, `created_by`, `created_at` and stamps —
  /// in **one** transaction. Returns the ops in plan order.
  Future<List<PersistedOp>> forkCollection(
    ForkPlan plan, {
    int? physicalNowMs,
  }) async {
    final now = physicalNowMs ?? DateTime.now().millisecondsSinceEpoch;
    final identity = await _identity();
    return _unitOfWork.run((ctx) async {
      final ops = <PersistedOp>[];
      for (final entity in plan.entities) {
        ops.add(
          await _writeOne(
            ctx: ctx,
            identity: identity,
            now: now,
            type: entity.type,
            id: entity.id,
            build: _creation(
              entity.type,
              entity.id,
              entity.content,
              entity.position,
            ),
          ),
        );
      }
      await deviceClock.save(_clock.now, ctx: ctx);
      return ops;
    });
  }

  // --- Rebuild (spec §8.9) ---------------------------------------------------

  /// Rebuild-from-log — spec §8.9. Replay every op in `seq` order through the
  /// merge-core (order-independent by construction, **no re-verify** — the log is
  /// already-verified durable truth), then, in one transaction, truncate and
  /// re-materialize the projection and recover the device clock (step 3) past the
  /// max stamp ever recorded.
  Future<void> rebuild() async {
    final ops = await changeLog.readOrdered();

    final memory = Projection();
    var recovered = _clock.now;
    for (final op in ops) {
      final snapshot = op.toSnapshot();
      memory.apply(snapshot);
      recovered = Hlc.max(recovered, snapshot.observedClock);
    }
    _clock.restore(recovered);

    await _unitOfWork.run((ctx) async {
      await projection.clear(ctx: ctx);
      for (final row in memory.rows) {
        await projection.upsert(row, ctx: ctx);
      }
      await deviceClock.save(_clock.now, ctx: ctx);
    });
  }

  // --- Wipe (Settings §4 danger zone) ---------------------------------------

  /// Delete all content on this device — collections, cards, links, attachments
  /// — while **keeping the device identity**: both the keypair (in
  /// [localIdentity], untouched here) *and* the signed `profile` record (the
  /// nickname#fingerprint, §7.4.7). The profile ops are read out of the log,
  /// then in one transaction (§8.5) the [changeLog], [projection], and
  /// [quarantine] are truncated and only the profile ops are re-appended and
  /// re-materialized — so the user keeps their identity but loses every other
  /// entity. The device clock is left intact (the same author keeps writing).
  /// Discarding the keypair entirely is the separate "reset identity" action.
  /// Attachment blobs are out-of-band, so the caller removes them.
  Future<void> wipe() async {
    final ops = await changeLog.readOrdered();
    final profileOps = ops
        .where((op) => op.toSnapshot().type == EntityType.profile)
        .toList(growable: false);

    // Replay the kept profile ops through the merge-core to recover the current
    // profile row (a nickname edit is a second op over the create, §6.9).
    final memory = Projection();
    for (final op in profileOps) {
      memory.apply(op.toSnapshot());
    }

    await _unitOfWork.run((ctx) async {
      await projection.clear(ctx: ctx);
      await changeLog.clear(ctx: ctx);
      await quarantine.clear(ctx: ctx);
      for (final op in profileOps) {
        await changeLog.append(op, ctx: ctx);
      }
      for (final row in memory.rows) {
        await projection.upsert(row, ctx: ctx);
      }
    });
  }

  /// Return the device to a fresh install: every entity, the signed log, the
  /// quarantine **and the keypair** are gone, so [hasIdentity] reads `false`
  /// and the next step is onboarding (Settings "Reset identity"). Data is
  /// signed by the key, so the two go together. The device clock is kept so
  /// the HLC never runs backwards. Attachment blobs are out-of-band, so the
  /// caller removes them.
  Future<void> resetDevice() async {
    await _unitOfWork.run((ctx) async {
      await projection.clear(ctx: ctx);
      await changeLog.clear(ctx: ctx);
      await quarantine.clear(ctx: ctx);
      await localIdentity.clear(ctx: ctx);
    });
    _identityCache = null;
  }

  // --- Helpers ---------------------------------------------------------------

  /// Load (or, on a fresh device, provision and persist) the device identity
  /// (§6.5). The secret is sealed by the [SecretBox] before storage.
  Future<({String pubkey, List<int> secret})> _identity() async {
    final cached = _identityCache;
    if (cached != null) return cached;

    final existing = await localIdentity.load();
    if (existing != null) {
      return _identityCache = (
        pubkey: existing.publicKeyHex,
        secret: _secretBox.open(existing.secretKeyEnc),
      );
    }

    final keypair = await signer.generate();
    await localIdentity.save(
      LocalIdentity(
        publicKeyHex: keypair.publicKeyHex,
        secretKeyEnc: _secretBox.seal(keypair.secretKey),
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    return _identityCache = (
      pubkey: keypair.publicKeyHex,
      secret: keypair.secretKey,
    );
  }

  static String _payloadAuthor(String payload) =>
      (jsonDecode(payload) as Map<String, Object?>)['author'] as String;

  static Snapshot _require(
    Snapshot? prior,
    String op,
    EntityType type,
    String id,
  ) => prior ?? (throw StateError('$op of missing ${type.name} $id'));

  /// Fill an entity's nullable content fields with explicit nulls so the
  /// canonical field set (§7.4) is complete even when the caller omits them.
  static Map<String, Object?> _withContentDefaults(
    EntityType type,
    Map<String, Object?> content,
  ) {
    final defaults = switch (type) {
      EntityType.collection => const {
        'description': null,
        'cover_attachment_id': null,
        'archived_at': null,
      },
      EntityType.card => const {
        'attachment_id': null,
        'text': null,
        'settled_at': null,
        'emphasized_at': null,
      },
      EntityType.link => const {'label': null},
      EntityType.profile => const {'nickname': null},
      EntityType.attachment => const {
        'kind': null,
        'mime': null,
        'content_hash': null,
        'size': null,
      },
    };
    return {...defaults, ...content};
  }
}
