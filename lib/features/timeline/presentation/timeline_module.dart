import 'package:effect_emitter/effect_emitter.dart';
import 'package:fcis_core/fcis_core.dart';
import 'package:logging/logging.dart';
import 'package:knit/core/attachments/presentation/attachment_image_cache.dart';
import 'package:knit/core/fcis_flutter/fcis_flutter.dart';
import 'package:knit/features/collection_details/presentation/collection_details_controller.dart';
import 'package:knit/features/timeline/domain/timeline_channel.dart';
import 'package:knit/features/collection_share/domain/local_archive_repository.dart';
import 'package:knit/features/timeline/domain/timeline_hub_read_repository.dart';
import 'package:knit/features/timeline/domain/timeline_order_repository.dart';
import 'package:knit/features/timeline/domain/timeline_owner_read_repository.dart';
import 'package:knit/features/timeline/domain/timeline_pin_repository.dart';
import 'package:knit/features/timeline/domain/timeline_read_repository.dart';
import 'package:knit/features/timeline/domain/timeline_write_repository.dart';
import 'package:knit/features/timeline/presentation/timeline_action.dart';
import 'package:knit/features/timeline/presentation/timeline_channel_binder.dart';
import 'package:knit/features/timeline/presentation/timeline_controller.dart';
import 'package:knit/features/timeline/presentation/timeline_effect.dart';
import 'package:knit/features/timeline/presentation/timeline_loop.dart';
import 'package:knit/features/timeline/presentation/timeline_shell.dart';
import 'package:knit/features/timeline/presentation/timeline_state.dart';
import 'package:knit/features/timeline/presentation/timeline_ui_effect.dart';
import 'package:knit/features/timeline/presentation/timeline_updater.dart';

/// Composition root for Timeline (fcis.md §6.8).
class TimelineModule {
  TimelineModule({
    required TimelineReadRepository readRepository,
    required TimelineWriteRepository writeRepository,
    required TimelinePinReadRepository pinReadRepository,
    required TimelinePinWriteRepository pinWriteRepository,
    required TimelineOrderReadRepository orderReadRepository,
    required TimelineOrderWriteRepository orderWriteRepository,
    required TimelineOwnerReadRepository ownerReadRepository,
    required TimelineHubReadRepository hubReadRepository,
    required LocalArchiveReadRepository localArchiveReadRepository,
    required LocalArchiveWriteRepository localArchiveWriteRepository,
    required AttachmentImageCache imageCache,
    required CollectionDetailsController collectionDetails,
    required TimelineChannelReader channelReader,
    Logger? logger,
  }) {
    final stateHolder = ValueListenableStateHolder<TimelineState>(
      const TimelineState(),
    );
    final effectEmitter = EffectEmitter<TimelineUiEffect>();
    final shell = TimelineShell(
      readRepository: readRepository,
      writeRepository: writeRepository,
      pinReadRepository: pinReadRepository,
      pinWriteRepository: pinWriteRepository,
      orderReadRepository: orderReadRepository,
      orderWriteRepository: orderWriteRepository,
      ownerReadRepository: ownerReadRepository,
      hubReadRepository: hubReadRepository,
      localArchiveReadRepository: localArchiveReadRepository,
      localArchiveWriteRepository: localArchiveWriteRepository,
      imageCache: imageCache,
      collectionDetails: collectionDetails,
      effectEmitter: effectEmitter,
      logger: logger ?? Logger('knit.timeline'),
    );
    final loop = TimelineLoop(
      stateHolder: stateHolder,
      updater: const TimelineUpdater(),
      effectRunner: ShellEffectRunner<TimelineEffect, TimelineAction>(
        shell: shell,
      ),
    );
    _controller = TimelineController(
      stateHolder: stateHolder,
      effectEmitter: effectEmitter,
      sink: loop,
      channelBinder: TimelineChannelBinder(reader: channelReader, sink: loop),
    );
  }

  late final TimelineController _controller;

  TimelineController get controller => _controller;
}
