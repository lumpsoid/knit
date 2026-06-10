import 'dart:convert';

import 'package:knit/sync/sync.dart';

/// Build the canonical-ish payload map for a snapshot (test stand-in for the
/// real canonical serializer of spec §7.1 — key order/escaping don't matter
/// here, only round-trip fidelity through [PersistedOp.toSnapshot]).
Map<String, Object?> payloadMap(Snapshot s) {
  final m = <String, Object?>{
    't': s.type.name,
    'id': s.id,
    'author': s.author,
    'created_by': s.createdBy,
    'created_at': s.createdAt,
    'hlc_ms': s.hlc.ms,
    'hlc_counter': s.hlc.counter,
    'deleted': s.deleted ? 1 : 0,
    ...s.content,
  };
  if (s.isCard) {
    m['position'] = s.position;
    m['position_ms'] = s.placement!.ms;
    m['position_counter'] = s.placement!.counter;
  }
  return m;
}

/// Wrap a snapshot in a durable [PersistedOp] with a sig-keyed op_id (spec §7.3).
PersistedOp opOf(Snapshot s, {SyncOrigin origin = SyncOrigin.local}) {
  final sig16 = s.sig.length >= 16 ? s.sig.substring(0, 16) : s.sig;
  return PersistedOp.fromSnapshot(
    s,
    opId: '${s.id}@${s.hlc.ms}.${s.hlc.counter}.$sig16',
    payload: jsonEncode(payloadMap(s)),
    origin: origin,
  );
}

Snapshot collection({
  String id = 'col-1',
  String author = 'aa',
  required int hlcMs,
  bool deleted = false,
  String sig = 'sig',
  String title = 't',
}) =>
    Snapshot(
      type: EntityType.collection,
      id: id,
      author: author,
      createdBy: author,
      createdAt: 1000,
      hlc: Hlc(hlcMs, 0),
      deleted: deleted,
      sig: '$sig$hlcMs',
      content: {'title': title, 'cover_attachment_id': null},
    );

Snapshot link({
  String id = 'link-1',
  String sourceId = 'card-1',
  String targetId = 'col-1',
  required int hlcMs,
  bool deleted = false,
  String? label,
  String sig = 'sig',
}) =>
    Snapshot(
      type: EntityType.link,
      id: id,
      author: 'aa',
      createdBy: 'aa',
      createdAt: 1000,
      hlc: Hlc(hlcMs, 0),
      deleted: deleted,
      sig: '$sig$hlcMs',
      content: {
        'source_type': 'card',
        'source_id': sourceId,
        'target_type': 'collection',
        'target_id': targetId,
        'label': label,
      },
    );

Snapshot profile({
  String id = 'pk-mira',
  required int hlcMs,
  String nickname = 'mira',
  bool deleted = false,
  String sig = 'sig',
}) =>
    Snapshot(
      type: EntityType.profile,
      id: id,
      author: id,
      createdBy: id,
      createdAt: 1000,
      hlc: Hlc(hlcMs, 0),
      deleted: deleted,
      sig: '$sig$hlcMs',
      content: {'nickname': nickname},
    );

Snapshot card({
  String id = 'card-1',
  String collectionId = 'col-1',
  required int hlcMs,
  int posMs = 1000,
  String text = '',
  String position = 'a0',
  bool deleted = false,
  String sig = 'sig',
}) =>
    Snapshot(
      type: EntityType.card,
      id: id,
      author: 'aa',
      createdBy: 'aa',
      createdAt: 1000,
      hlc: Hlc(hlcMs, 0),
      deleted: deleted,
      sig: '$sig$id$hlcMs$posMs',
      placement: Hlc(posMs, 0),
      position: position,
      content: {'collection_id': collectionId, 'kind': 'text', 'text': text},
    );
