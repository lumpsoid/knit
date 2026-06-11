import 'dart:convert';

import 'package:knit/sync/sync.dart';

/// Wrap a snapshot in a durable [PersistedOp] with a real canonical payload
/// (§7.1), a [FakeSigner]-compatible signature (so it verifies in
/// `SyncStore.applyRemote`), and a sig-keyed op_id (§7.3). The signature is
/// `fakeSignHex(utf8(author), utf8(payload))`, matching the in-memory signer's
/// "secret == utf8(publicKeyHex)" convention.
PersistedOp opOf(Snapshot s, {SyncOrigin origin = SyncOrigin.local}) {
  final payload = CanonicalSerializer.string(s);
  final sig = fakeSignHex(utf8.encode(s.author), utf8.encode(payload));
  final signed = s.copyWith(sig: sig);
  return PersistedOp.fromSnapshot(
    signed,
    opId: OpId.ofSnapshot(signed),
    payload: payload,
    origin: origin,
  );
}

Snapshot collection({
  String id = 'col-1',
  String author = 'aa',
  required int hlcMs,
  int createdAt = 1000,
  bool deleted = false,
  String sig = 'sig',
  String title = 't',
  String? coverAttachmentId,
}) =>
    Snapshot(
      type: EntityType.collection,
      id: id,
      author: author,
      createdBy: author,
      createdAt: createdAt,
      hlc: Hlc(hlcMs, 0),
      deleted: deleted,
      sig: '$sig$hlcMs',
      content: {'title': title, 'cover_attachment_id': coverAttachmentId},
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
  int createdAt = 1000,
  int posMs = 1000,
  String kind = 'text',
  String text = '',
  String? attachmentId,
  String position = 'a0',
  bool deleted = false,
  String sig = 'sig',
}) =>
    Snapshot(
      type: EntityType.card,
      id: id,
      author: 'aa',
      createdBy: 'aa',
      createdAt: createdAt,
      hlc: Hlc(hlcMs, 0),
      deleted: deleted,
      sig: '$sig$id$hlcMs$posMs',
      placement: Hlc(posMs, 0),
      position: position,
      content: {
        'collection_id': collectionId,
        'kind': kind,
        'text': text,
        'attachment_id': attachmentId,
      },
    );
