import 'dart:convert';

import 'package:knit/sync/snapshot.dart';
import 'package:knit/sync/storage/change_log/domain/change_log_schema.dart';

/// Routing hint on a `change_log` row — spec §6.6/§7.2. `payload.deleted` is
/// authoritative; this is only a relay/index hint.
enum OpKind {
  put,
  delete;

  static OpKind fromDb(String str) => switch (str) {
        'delete' => OpKind.delete,
        _ => OpKind.put,
      };

  String toDb() => switch (this) {
        OpKind.put => 'put',
        OpKind.delete => 'delete',
      };

  /// Derive the hint from a snapshot's tombstone flag.
  static OpKind ofSnapshot(Snapshot s) => s.deleted ? OpKind.delete : OpKind.put;
}

/// Where a `change_log` op came from — spec §6.6.
enum SyncOrigin {
  local,
  remote;

  static SyncOrigin fromDb(String str) => switch (str) {
        'remote' => SyncOrigin.remote,
        _ => SyncOrigin.local,
      };

  String toDb() => switch (this) {
        SyncOrigin.local => 'local',
        SyncOrigin.remote => 'remote',
      };
}

/// A `change_log` row (spec §6.6) — the durable, signed op. Holds the canonical
/// [payload] verbatim plus the envelope hints; [toSnapshot] parses the payload
/// back into a [Snapshot] for the merge-core.
class PersistedOp {
  const PersistedOp({
    required this.opId,
    required this.entityType,
    required this.entityId,
    required this.op,
    required this.hlcMs,
    required this.hlcCounter,
    required this.author,
    required this.payload,
    required this.sig,
    required this.origin,
    this.seq,
    this.acked = false,
  });

  factory PersistedOp.fromDb(Map<String, Object?> row) => PersistedOp(
        seq: row[ChangeLogSchema.colSeq] as int?,
        opId: row[ChangeLogSchema.colOpId]! as String,
        entityType: row[ChangeLogSchema.colEntityType]! as String,
        entityId: row[ChangeLogSchema.colEntityId]! as String,
        op: OpKind.fromDb(row[ChangeLogSchema.colOp]! as String),
        hlcMs: row[ChangeLogSchema.colHlcMs]! as int,
        hlcCounter: row[ChangeLogSchema.colHlcCounter]! as int,
        author: row[ChangeLogSchema.colAuthor]! as String,
        payload: row[ChangeLogSchema.colPayload]! as String,
        sig: row[ChangeLogSchema.colSig]! as String,
        origin: SyncOrigin.fromDb(row[ChangeLogSchema.colOrigin]! as String),
        acked: (row[ChangeLogSchema.colAcked]! as int) == 1,
      );

  /// Build the durable op for a [snapshot] whose canonical signed [payload] has
  /// already been produced (canonical serialization + signing is the upstream
  /// write-path concern, spec §6.8/§7.1 — out of scope for this storage layer).
  factory PersistedOp.fromSnapshot(
    Snapshot snapshot, {
    required String opId,
    required String payload,
    required SyncOrigin origin,
    bool acked = false,
  }) =>
      PersistedOp(
        opId: opId,
        entityType: snapshot.type.name,
        entityId: snapshot.id,
        op: OpKind.ofSnapshot(snapshot),
        hlcMs: snapshot.hlc.ms,
        hlcCounter: snapshot.hlc.counter,
        author: snapshot.author,
        payload: payload,
        sig: snapshot.sig,
        origin: origin,
        acked: acked,
      );

  /// Local-only autoincrement; null until persisted (the DB assigns it).
  final int? seq;
  final String opId;
  final String entityType;
  final String entityId;
  final OpKind op;
  final int hlcMs;
  final int hlcCounter;
  final String author;
  final String payload;
  final String sig;
  final SyncOrigin origin;
  final bool acked;

  PersistedOp copyWith({SyncOrigin? origin, bool? acked, int? seq}) =>
      PersistedOp(
        seq: seq ?? this.seq,
        opId: opId,
        entityType: entityType,
        entityId: entityId,
        op: op,
        hlcMs: hlcMs,
        hlcCounter: hlcCounter,
        author: author,
        payload: payload,
        sig: sig,
        origin: origin ?? this.origin,
        acked: acked ?? this.acked,
      );

  /// Row for insert. Omits [seq] so the DB assigns the autoincrement value.
  Map<String, Object?> toDb() => {
        ChangeLogSchema.colOpId: opId,
        ChangeLogSchema.colEntityType: entityType,
        ChangeLogSchema.colEntityId: entityId,
        ChangeLogSchema.colOp: op.toDb(),
        ChangeLogSchema.colHlcMs: hlcMs,
        ChangeLogSchema.colHlcCounter: hlcCounter,
        ChangeLogSchema.colAuthor: author,
        ChangeLogSchema.colPayload: payload,
        ChangeLogSchema.colSig: sig,
        ChangeLogSchema.colOrigin: origin.toDb(),
        ChangeLogSchema.colAcked: acked ? 1 : 0,
      };

  /// Parse the canonical [payload] back into a verified [Snapshot] for the
  /// merge-core. The `sig` lives in the op envelope, not the signed payload
  /// (spec §7.2), so it is injected before parsing.
  Snapshot toSnapshot() {
    final map = jsonDecode(payload) as Map<String, Object?>;
    map[ChangeLogSchema.colSig] = sig;
    return Snapshot.fromPayload(map);
  }

  @override
  String toString() =>
      'PersistedOp(${op.toDb()} $entityType $entityId @$hlcMs.$hlcCounter '
      '${origin.toDb()}${acked ? ' acked' : ''})';
}
