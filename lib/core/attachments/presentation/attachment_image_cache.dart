import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:knit/core/attachments/domain/attachment_read_repository.dart';
import 'package:knit/core/attachments/presentation/attachment_image_cache_state.dart';

/// The shared, app-wide decoded-image cache: one copy of each attachment image
/// for every page (Timeline covers, the Collection feed, Collection Edit, the
/// Media overview, Card Edit), so an image two pages show is read and held
/// once.
///
/// Each page tells the cache which images it [show]s, under an owner token of
/// its own. Those images load once and stay held while any owner shows them.
/// Images no owner shows any more are kept as idle up to [idleBudgetBytes],
/// least recently shown evicted first, so returning to a page is instant
/// without letting memory grow with everything ever opened.
class AttachmentImageCache {
  AttachmentImageCache({
    required AttachmentReadRepository attachmentReadRepository,
    this.idleBudgetBytes = 32 * 1024 * 1024,
    Logger? logger,
  }) : _read = attachmentReadRepository,
       _log = logger ?? Logger('knit.attachments.images');

  final AttachmentReadRepository _read;
  final Logger _log;

  /// How many bytes of no-longer-shown images to keep for a quick return.
  final int idleBudgetBytes;

  final AttachmentImageCacheState state = AttachmentImageCacheState();

  final Map<Object, Set<String>> _shownBy = {};
  final Map<String, Future<void>> _inFlight = {};

  /// Idle (shown by no owner) cached ids → their size, least recently shown
  /// first.
  final LinkedHashMap<String, int> _idle = LinkedHashMap();
  int _idleBytes = 0;

  /// [owner] now shows exactly [attachmentIds] — replacing what it showed
  /// before. Loads any not yet held (retrying ones found missing earlier, in
  /// case the blob has since arrived). The returned future completes once
  /// those loads have settled.
  Future<void> show(Object owner, Iterable<String> attachmentIds) {
    final ids = attachmentIds.toSet();
    final previous = _shownBy[owner] ?? const <String>{};
    if (ids.isEmpty) {
      _shownBy.remove(owner);
    } else {
      _shownBy[owner] = ids;
    }
    for (final id in ids) {
      _markShown(id);
    }
    for (final id in previous.difference(ids)) {
      _markIdleIfUnshown(id);
    }
    _enforceBudget();
    return Future.wait([
      for (final id in ids)
        if (!state.contains(id)) _load(id),
    ]);
  }

  /// [owner] shows nothing any more (its page left).
  void release(Object owner) => unawaited(show(owner, const []));

  /// Record bytes the caller already holds for [attachmentId] — a just-stored
  /// pick — so showing it needs no re-read.
  void put(String attachmentId, Uint8List bytes) {
    state.put(attachmentId, bytes);
    _markIdleIfUnshown(attachmentId);
    _enforceBudget();
  }

  Future<void> _load(String id) => _inFlight[id] ??= _read
      .bytesOf(id)
      .then((result) {
        result.fold((bytes) => state.put(id, bytes.bytes), (failure) {
          _log.warning('Attachment image bytes missing for $id');
          state.markMissing(id);
        });
        // The owner may have moved on while the read was in flight.
        _markIdleIfUnshown(id);
        _enforceBudget();
      })
      // A block body: `remove` returns this very future, and whenComplete
      // would wait on whatever its callback returns.
      .whenComplete(() {
        _inFlight.remove(id);
      });

  bool _isShown(String id) => _shownBy.values.any((ids) => ids.contains(id));

  void _markShown(String id) {
    final size = _idle.remove(id);
    if (size != null) _idleBytes -= size;
  }

  void _markIdleIfUnshown(String id) {
    final bytes = state.of(id);
    if (bytes == null || _isShown(id)) return;
    final previous = _idle.remove(id);
    if (previous != null) _idleBytes -= previous;
    _idle[id] = bytes.length;
    _idleBytes += bytes.length;
  }

  void _enforceBudget() {
    if (_idleBytes <= idleBudgetBytes) return;
    final evicted = <String>[];
    while (_idleBytes > idleBudgetBytes && _idle.isNotEmpty) {
      final id = _idle.keys.first;
      _idleBytes -= _idle.remove(id)!;
      evicted.add(id);
    }
    state.evict(evicted);
  }
}
