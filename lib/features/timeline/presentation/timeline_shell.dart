import 'package:fcis_core/fcis_core.dart';
import 'package:logging/logging.dart';
import 'package:knit/features/timeline/domain/timeline_failure.dart';
import 'package:knit/features/timeline/domain/timeline_read_repository.dart';
import 'package:knit/features/timeline/presentation/timeline_action.dart';
import 'package:knit/features/timeline/presentation/timeline_effect.dart';

/// Imperative shell for Timeline (fcis.md §6.6). Unwraps the read Result at the
/// seam (result.md §9.3) into a success/failure Action.
class TimelineShell extends Shell<TimelineEffect, TimelineAction> {
  TimelineShell({
    required TimelineReadRepository repository,
    required Logger logger,
  })  : _repository = repository,
        _log = logger;

  final TimelineReadRepository _repository;
  final Logger _log;

  @override
  Future<void> run(
    TimelineEffect effect, {
    required void Function(TimelineAction) dispatch,
  }) async {
    switch (effect) {
      case LoadTimelineEffect():
        final result = await _repository.loadTimeline();
        result.onTap(
          (collections) => dispatch(CollectionsLoaded(collections)),
          (failure) {
            _log.severe('Timeline load failed: ${_cause(failure)}');
            dispatch(const TimelineLoadFailed('Could not load your collections.'));
          },
        );
    }
  }

  String _cause(TimelineFailure failure) => switch (failure) {
        TimelineLoadFailure(:final cause) => cause,
      };
}
