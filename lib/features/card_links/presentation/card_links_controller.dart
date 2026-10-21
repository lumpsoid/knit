import 'package:logging/logging.dart';
import 'package:knit/core/recents/domain/recent_targets.dart';
import 'package:knit/core/recents/domain/recent_targets_repository.dart';
import 'package:knit/features/card_links/domain/card_links_failure.dart';
import 'package:knit/features/card_links/domain/card_links_models.dart';
import 'package:knit/features/card_links/domain/card_links_write_repository.dart';
import 'package:knit/features/card_links/domain/link_targets_read_repository.dart';
import 'package:knit/features/card_links/presentation/card_links_state.dart';
import 'package:knit/features/connections/domain/connections_models.dart';
import 'package:result_dart/result_dart.dart';

/// The shared, app-wide owner of card links (§4.4): the link picker the
/// Collection screen and the Card Edit page both open, and every link write —
/// adding one (Collection, Card Edit) and removing one (Card Edit, and the
/// Connections view clearing a broken link).
///
/// The picker reads one level at a time into [state]. Each write returns its
/// [Result] so the calling feature can react (resync, message). A link to a
/// collection is remembered for the picker's device-local "Recent" row.
class CardLinksController {
  CardLinksController({
    required LinkTargetsReadRepository readRepository,
    required CardLinksWriteRepository writeRepository,
    required RecentTargetsReadRepository recentsReadRepository,
    required RecentTargetsWriteRepository recentsWriteRepository,
    Logger? logger,
  }) : _read = readRepository,
       _write = writeRepository,
       _recentsRead = recentsReadRepository,
       _recentsWrite = recentsWriteRepository,
       _log = logger ?? Logger('knit.card_links');

  final LinkTargetsReadRepository _read;
  final CardLinksWriteRepository _write;
  final RecentTargetsReadRepository _recentsRead;
  final RecentTargetsWriteRepository _recentsWrite;
  final Logger _log;

  final CardLinksState state = CardLinksState();

  /// Bumped per picker session, so a slow read from an earlier session can't
  /// land in this one.
  int _session = 0;

  /// Open the picker for [source]: start a fresh session and load the
  /// collections level with the recently linked ones. A failed read shows an
  /// empty list; failed recents show no "Recent" row.
  Future<void> openPicker(LinkPick source) async {
    final session = ++_session;
    state.startPicking(source);
    final recents = await _recentsRead.load(RecentPurpose.link);
    final result = await _read.loadCollections();
    if (session != _session) return;
    state.showCollections(
      result.fold((collections) => collections, (failure) {
        _log.severe(
          'Link collections load failed',
          failure.error,
          failure.stackTrace,
        );
        return const [];
      }),
      recents: recents.fold((recents) => recents, (failure) {
        _log.warning('Recent link targets load failed', failure.error);
        return const RecentTargets();
      }),
    );
  }

  /// Drill into [collectionId]: load its cards once per session.
  Future<void> openCollection(String collectionId) async {
    if (state.hasCardsOf(collectionId)) return;
    final session = _session;
    final result = await _read.loadCards(collectionId);
    if (session != _session) return;
    state.showCards(
      collectionId,
      result.fold((cards) => cards, (failure) {
        _log.severe(
          'Link cards load failed',
          failure.error,
          failure.stackTrace,
        );
        return const [];
      }),
    );
  }

  /// Link [sourceCardId] to the [targetKind] entity [targetId]. A collection
  /// linked to is remembered as recent once the link is written.
  Future<Result<String, CardLinksFailure>> link({
    required String sourceCardId,
    required ConnectedEntityKind targetKind,
    required String targetId,
  }) async {
    final result = await _write.addLink(
      sourceCardId: sourceCardId,
      targetKind: targetKind,
      targetId: targetId,
    );
    if (result.isSuccess && targetKind == ConnectedEntityKind.collection) {
      // Non-fatal: the link is written either way.
      (await _recentsWrite.record(RecentPurpose.link, targetId)).onFailure(
        (failure) =>
            _log.warning('Recent link target save failed', failure.error),
      );
    }
    return result;
  }

  /// Remove the link [linkId] (also clears a broken link, §8.6.1).
  Future<Result<String, CardLinksFailure>> unlink(String linkId) =>
      _write.removeLink(linkId);
}
