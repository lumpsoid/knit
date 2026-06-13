import 'package:effect_emitter/effect_emitter.dart';
import 'package:fcis_core/fcis_core.dart';
import 'package:logging/logging.dart';
import 'package:knit/features/timeline/domain/timeline_failure.dart';
import 'package:knit/features/timeline/domain/timeline_read_repository.dart';
import 'package:knit/features/timeline/domain/timeline_write_repository.dart';
import 'package:knit/features/timeline/presentation/timeline_action.dart';
import 'package:knit/features/timeline/presentation/timeline_effect.dart';
import 'package:knit/features/timeline/presentation/timeline_ui_effect.dart';

/// Imperative shell for Timeline (fcis.md §6.6). Unwraps the read/write Results
/// at the seam (result.md §9.3) into success/failure Actions, and pushes
/// navigation/message UiEffects.
class TimelineShell extends Shell<TimelineEffect, TimelineAction> {
  TimelineShell({
    required TimelineReadRepository readRepository,
    required TimelineWriteRepository writeRepository,
    required EffectEmitter<TimelineUiEffect> effectEmitter,
    required Logger logger,
  })  : _read = readRepository,
        _write = writeRepository,
        _effectEmitter = effectEmitter,
        _log = logger;

  final TimelineReadRepository _read;
  final TimelineWriteRepository _write;
  final EffectEmitter<TimelineUiEffect> _effectEmitter;
  final Logger _log;

  @override
  Future<void> run(
    TimelineEffect effect, {
    required void Function(TimelineAction) dispatch,
  }) async {
    switch (effect) {
      case LoadTimelineEffect():
        final result = await _read.loadTimeline();
        result.onTap(
          (collections) => dispatch(CollectionsLoaded(collections)),
          (failure) {
            _log.severe('Timeline load failed: ${_cause(failure)}');
            dispatch(
              const TimelineLoadFailed('Could not load your collections.'),
            );
          },
        );

      case CreateCollectionEffect(:final title):
        final result = await _write.createCollection(title);
        result.onTap(
          (id) => dispatch(CollectionCreated(id)),
          (failure) {
            _log.severe('Create collection failed: ${_cause(failure)}');
            _effectEmitter.push(
              const TimelineShowMessageUiEffect(
                "Couldn't create the collection. Please try again.",
              ),
            );
            dispatch(const CollectionCreateFailed('create failed'));
          },
        );

      case OpenCollectionEffect(:final collectionId):
        _effectEmitter.push(TimelineOpenCollectionUiEffect(collectionId));

      case DeleteCollectionEffect(:final collectionId):
        final result = await _write.deleteCollection(collectionId);
        result.onTap(
          (id) => dispatch(CollectionDeleted(id)),
          (failure) {
            _log.severe('Delete collection failed: ${_cause(failure)}');
            _effectEmitter.push(
              const TimelineShowMessageUiEffect(
                "Couldn't delete the collection. Please try again.",
              ),
            );
            dispatch(const CollectionDeleteFailed('delete failed'));
          },
        );
    }
  }

  String _cause(TimelineFailure failure) => switch (failure) {
        TimelineLoadFailure(:final cause) => cause,
        TimelineWriteFailure(:final cause) => cause,
      };
}
