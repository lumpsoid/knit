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
/// adding one (Collection, Card Edit, Connections' Undo) and removing one
/// (Card Edit, the picker's ✓ toggle, and the Connections view's Remove and
/// broken-link clear).
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
  /// collections level with the recently linked ones, and the targets the
  /// source card already links to (the ✓ marks). A failed read shows an
  /// empty list; failed recents show no "Recent" row, failed links no ✓.
  Future<void> openPicker(LinkPick source) async {
    final session = ++_session;
    state.startPicking(source);
    final recents = await _recentsRead.load(RecentPurpose.link);
    final linkedFrom = source.linkedFrom;
    final linked = linkedFrom == null
        ? const LinkedTargets()
        : (await _read.loadLinkedTargets(linkedFrom)).fold((linked) => linked, (
            failure,
          ) {
            _log.warning('Linked targets load failed', failure.error);
            return const LinkedTargets();
          });
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
      linked: linked,
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

  /// Link the [sourceKind] entity [sourceId] — a card unless an Undo restores
  /// a collection's link — to the [targetKind] entity [targetId]; a pair
  /// already linked stays as it is (§6.4). A collection linked to is
  /// remembered as recent once the link is written.
  Future<Result<String, CardLinksFailure>> link({
    ConnectedEntityKind sourceKind = ConnectedEntityKind.card,
    required String sourceId,
    required ConnectedEntityKind targetKind,
    required String targetId,
  }) async {
    final result = await _write.addLink(
      sourceKind: sourceKind,
      sourceId: sourceId,
      targetKind: targetKind,
      targetId: targetId,
    );
    if (result.isSuccess && targetKind == ConnectedEntityKind.collection) {
      await _recordRecent(targetId);
    }
    return result;
  }

  /// Link every card of [sourceIds] to the [targetKind] entity [targetId] in
  /// one write — multi-select "Link to…" (§4.2). Pairs already linked are
  /// skipped (§6.4); the result counts the links written. A collection linked
  /// to is remembered as recent.
  Future<Result<LinksAdded, CardLinksFailure>> linkAll({
    required List<String> sourceIds,
    required ConnectedEntityKind targetKind,
    required String targetId,
  }) async {
    final result = await _write.addLinks(
      sourceIds: sourceIds,
      targetKind: targetKind,
      targetId: targetId,
    );
    if (result.isSuccess && targetKind == ConnectedEntityKind.collection) {
      await _recordRecent(targetId);
    }
    return result;
  }

  /// Create a collection titled [title] and link every card of [sourceIds]
  /// to it in one write — the picker's "New collection" (§4.4). The new
  /// collection is remembered as recent.
  Future<Result<LinksAdded, CardLinksFailure>> linkToNewCollection({
    required List<String> sourceIds,
    required String title,
  }) async {
    final result = await _write.addLinksToNewCollection(
      sourceIds: sourceIds,
      title: title,
    );
    final added = result.value;
    if (added != null) await _recordRecent(added.targetId);
    return result;
  }

  /// Remove the link [linkId] and its pair's duplicates (§6.4) — Card Edit, a
  /// ✓ target tapped in the picker, the Connections view's Remove, and
  /// clearing a broken link (§8.6.1).
  Future<Result<String, CardLinksFailure>> unlink(String linkId) =>
      _write.removeLink(linkId);

  /// Remember [collectionId] as recently linked to. Non-fatal: the link is
  /// written either way.
  Future<void> _recordRecent(String collectionId) async {
    (await _recentsWrite.record(RecentPurpose.link, collectionId)).onFailure(
      (failure) =>
          _log.warning('Recent link target save failed', failure.error),
    );
  }
}
