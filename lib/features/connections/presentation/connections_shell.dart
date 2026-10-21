import 'package:effect_emitter/effect_emitter.dart';
import 'package:fcis_core/fcis_core.dart';
import 'package:logging/logging.dart';
import 'package:result_dart/result_dart.dart';
import 'package:knit/features/card_links/presentation/card_links_controller.dart';
import 'package:knit/features/connections/domain/connections_models.dart';
import 'package:knit/features/connections/domain/connections_read_repository.dart';
import 'package:knit/features/connections/domain/mention_read_repository.dart';
import 'package:knit/features/connections/domain/unlinked_mentions.dart';
import 'package:knit/features/connections/presentation/connections_action.dart';
import 'package:knit/features/connections/presentation/connections_effect.dart';
import 'package:knit/features/connections/presentation/connections_ui_effect.dart';

/// Imperative shell for the Connections view (fcis.md §6.6). Unwraps each
/// repository [Result] at the seam (result.md §9.3) into a success/failure
/// Action; the updater never sees a Result. Clearing a broken link goes through
/// the shared card links, then re-reads the focus (via [ReloadRequested]) so the projection — not an optimistic guess —
/// is the source of truth. So does linking an unlinked mention; the mentions
/// themselves are the pure [UnlinkedMentionFinder]'s pick over the read corpus.
class ConnectionsShell extends Shell<ConnectionsEffect, ConnectionsAction> {
  ConnectionsShell({
    required ConnectionsReadRepository readRepository,
    required MentionReadRepository mentionRepository,
    required CardLinksController cardLinks,
    required EffectEmitter<ConnectionsUiEffect> effectEmitter,
    required Logger logger,
  }) : _read = readRepository,
       _mentions = mentionRepository,
       _cardLinks = cardLinks,
       _effectEmitter = effectEmitter,
       _log = logger;

  final ConnectionsReadRepository _read;
  final MentionReadRepository _mentions;
  final CardLinksController _cardLinks;
  final EffectEmitter<ConnectionsUiEffect> _effectEmitter;
  final Logger _log;

  @override
  Future<void> run(
    ConnectionsEffect effect, {
    required void Function(ConnectionsAction) dispatch,
  }) async {
    switch (effect) {
      case LoadConnectionsEffect(:final kind, :final id):
        final result = await _read.loadConnections(kind, id);
        result.onTap((data) => dispatch(ConnectionsLoaded(data)), (failure) {
          _log.severe(
            'Connections load failed',
            failure.error,
            failure.stackTrace,
          );
          dispatch(const LoadFailed());
        });

      case LoadMentionsEffect(:final collectionId, :final title):
        final result = await _mentions.loadMentionCorpus(collectionId);
        result.onTap(
          (corpus) => dispatch(
            MentionsLoaded(
              collectionId: collectionId,
              mentions: UnlinkedMentionFinder.find(
                collectionId: collectionId,
                title: title,
                corpus: corpus,
              ),
            ),
          ),
          // The section is extra: a failed read just leaves it out.
          (failure) => _log.severe(
            'Connections mentions load failed',
            failure.error,
            failure.stackTrace,
          ),
        );

      case LinkMentionEffect(:final cardId, :final collectionId):
        final result = await _cardLinks.link(
          sourceCardId: cardId,
          targetKind: ConnectedEntityKind.collection,
          targetId: collectionId,
        );
        result.onTap((_) => dispatch(const ReloadRequested()), (failure) {
          _log.severe(
            'Connections link-mention failed',
            failure.error,
            failure.stackTrace,
          );
          _effectEmitter.push(
            const ConnectionsShowMessageUiEffect(ConnectionsMessage.linkFailed),
          );
          dispatch(const ReloadRequested());
        });

      case ClearLinkEffect(:final linkId):
        final result = await _cardLinks.unlink(linkId);
        result.onTap((_) => dispatch(const ReloadRequested()), (failure) {
          _log.severe(
            'Connections clear-link failed',
            failure.error,
            failure.stackTrace,
          );
          _effectEmitter.push(
            const ConnectionsShowMessageUiEffect(
              ConnectionsMessage.clearFailed,
            ),
          );
          dispatch(const ReloadRequested());
        });
    }
  }
}
