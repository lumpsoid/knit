import 'package:effect_emitter/effect_emitter.dart';
import 'package:fcis_core/fcis_core.dart';
import 'package:logging/logging.dart';
import 'package:result_dart/result_dart.dart';
import 'package:knit/features/collection/domain/collection_failure.dart';
import 'package:knit/features/collection/domain/collection_read_repository.dart';
import 'package:knit/features/collection/domain/collection_write_repository.dart';
import 'package:knit/features/collection/presentation/collection_action.dart';
import 'package:knit/features/collection/presentation/collection_effect.dart';
import 'package:knit/features/collection/presentation/collection_ui_effect.dart';

/// Imperative shell for the Collection screen (fcis.md §6.6). Unwraps each
/// repository [Result] at the seam (result.md §9.3) into a success/failure
/// Action; the updater never sees a Result. Every successful write re-reads the
/// feed (via [ReloadRequested]) so the projection — not the optimistic local
/// list — is the source of truth; a failed write surfaces a message and still
/// resyncs.
class CollectionShell extends Shell<CollectionEffect, CollectionAction> {
  CollectionShell({
    required CollectionReadRepository readRepository,
    required CollectionWriteRepository writeRepository,
    required EffectEmitter<CollectionUiEffect> effectEmitter,
    required Logger logger,
  })  : _read = readRepository,
        _write = writeRepository,
        _effectEmitter = effectEmitter,
        _log = logger;

  final CollectionReadRepository _read;
  final CollectionWriteRepository _write;
  final EffectEmitter<CollectionUiEffect> _effectEmitter;
  final Logger _log;

  @override
  Future<void> run(
    CollectionEffect effect, {
    required void Function(CollectionAction) dispatch,
  }) async {
    switch (effect) {
      case LoadCollectionEffect(:final collectionId):
        final result = await _read.loadCollection(collectionId);
        result.onTap(
          (data) => dispatch(CollectionLoaded(data)),
          (failure) {
            _log.severe('Collection load failed: ${_cause(failure)}');
            dispatch(const LoadFailed('Could not load this collection.'));
          },
        );

      case AddCardEffect(:final collectionId, :final kind, :final position, :final text):
        await _runWrite(
          () => _write.addCard(
            collectionId: collectionId,
            kind: kind,
            position: position,
            text: text,
          ),
          'add card',
          dispatch,
        );

      case DeleteCardEffect(:final cardId):
        await _runWrite(
          () => _write.deleteCard(cardId),
          'delete card',
          dispatch,
        );

      case ReorderCardEffect(:final cardId, :final position):
        await _runWrite(
          () => _write.reorderCard(cardId, position),
          'reorder card',
          dispatch,
        );

      case LinkEffect(:final cardId, :final targetCollectionId):
        await _runWrite(
          () => _write.linkCardToCollection(
            cardId: cardId,
            collectionId: targetCollectionId,
          ),
          'create link',
          dispatch,
        );

      case EditTitleEffect(:final collectionId, :final title):
        await _runWrite(
          () => _write.editTitle(collectionId, title),
          'rename collection',
          dispatch,
        );
    }
  }

  /// Run a write, then resync from the projection. On failure, surface a
  /// message and still resync (drops any optimistic local change).
  Future<void> _runWrite(
    Future<Result<String, CollectionFailure>> Function() op,
    String label,
    void Function(CollectionAction) dispatch,
  ) async {
    final result = await op();
    result.onTap(
      (_) => dispatch(const ReloadRequested()),
      (failure) {
        _log.severe('Collection $label failed: ${_cause(failure)}');
        _effectEmitter.push(
          const CollectionShowMessageUiEffect(
            "That didn't save. Please try again.",
          ),
        );
        dispatch(const ReloadRequested());
      },
    );
  }

  String _cause(CollectionFailure failure) => switch (failure) {
        CollectionLoadFailure(:final cause) => cause,
        CollectionWriteFailure(:final cause) => cause,
      };
}
