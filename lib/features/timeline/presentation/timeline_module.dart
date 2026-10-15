import 'package:effect_emitter/effect_emitter.dart';
import 'package:fcis_core/fcis_core.dart';
import 'package:logging/logging.dart';
import 'package:knit/core/attachments/domain/attachment_read_repository.dart';
import 'package:knit/core/fcis_flutter/fcis_flutter.dart';
import 'package:knit/features/timeline/domain/timeline_channel.dart';
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
    required AttachmentReadRepository attachmentReadRepository,
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
      attachmentReadRepository: attachmentReadRepository,
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
