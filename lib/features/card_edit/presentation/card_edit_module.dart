import 'package:effect_emitter/effect_emitter.dart';
import 'package:fcis_core/fcis_core.dart';
import 'package:logging/logging.dart';
import 'package:knit/core/attachments/domain/attachment_read_repository.dart';
import 'package:knit/core/attachments/domain/attachment_write_repository.dart';
import 'package:knit/core/attachments/domain/file_picker_port.dart';
import 'package:knit/core/attachments/domain/image_optimizer_port.dart';
import 'package:knit/core/attachments/domain/image_picker_port.dart';
import 'package:knit/core/attachments/presentation/attachment_image_cache.dart';
import 'package:knit/core/fcis_flutter/fcis_flutter.dart';
import 'package:knit/features/card_edit/domain/card_edit_links_read_repository.dart';
import 'package:knit/features/card_edit/domain/card_edit_timeline_preview_read_repository.dart';
import 'package:knit/features/card_edit/domain/card_edit_write_repository.dart';
import 'package:knit/features/card_edit/presentation/card_edit_action.dart';
import 'package:knit/features/card_edit/presentation/card_edit_controller.dart';
import 'package:knit/features/card_edit/presentation/card_edit_effect.dart';
import 'package:knit/features/card_edit/presentation/card_edit_loop.dart';
import 'package:knit/features/card_edit/presentation/card_edit_shell.dart';
import 'package:knit/features/card_edit/presentation/card_edit_state.dart';
import 'package:knit/features/card_edit/presentation/card_edit_ui_effect.dart';
import 'package:knit/features/card_edit/presentation/card_edit_updater.dart';
import 'package:knit/features/card_links/presentation/card_links_controller.dart';
import 'package:knit/features/timeline/domain/timeline_channel.dart';

/// Composition root for the Card Edit page (fcis.md §6.8): wires
/// stateHolder → effectEmitter → shell → loop → controller. The shell gets the
/// card-edit write + links-read ports, the timeline-preview read port + the
/// Timeline's input channel (refresh after a previewed card's edit), the shared
/// card links (link writes), the shared image cache, and the attachments read +
/// write ports, the pickers and the image optimizer for the attachment section.
class CardEditModule {
  CardEditModule({
    required CardEditWriteRepository writeRepository,
    required CardEditLinksReadRepository linksReadRepository,
    required CardEditTimelinePreviewReadRepository timelinePreviewRepository,
    required TimelineChannelEmitter timelineChannel,
    required CardLinksController cardLinks,
    required AttachmentImageCache imageCache,
    required AttachmentReadRepository attachmentReadRepository,
    required AttachmentWriteRepository attachmentWriteRepository,
    required ImagePickerPort imagePicker,
    required ImageOptimizerPort imageOptimizer,
    required FilePickerPort filePicker,
    Logger? logger,
  }) {
    final stateHolder = ValueListenableStateHolder<CardEditState>(
      const CardEditState(),
    );
    final effectEmitter = EffectEmitter<CardEditUiEffect>();
    final shell = CardEditShell(
      writeRepository: writeRepository,
      linksReadRepository: linksReadRepository,
      timelinePreviewRepository: timelinePreviewRepository,
      timelineChannel: timelineChannel,
      cardLinks: cardLinks,
      imageCache: imageCache,
      attachmentReadRepository: attachmentReadRepository,
      attachmentWriteRepository: attachmentWriteRepository,
      imagePicker: imagePicker,
      imageOptimizer: imageOptimizer,
      filePicker: filePicker,
      effectEmitter: effectEmitter,
      logger: logger ?? Logger('knit.card_edit'),
    );
    final loop = CardEditLoop(
      stateHolder: stateHolder,
      updater: const CardEditUpdater(),
      effectRunner: ShellEffectRunner<CardEditEffect, CardEditAction>(
        shell: shell,
      ),
    );
    _controller = CardEditController(
      stateHolder: stateHolder,
      effectEmitter: effectEmitter,
      sink: loop,
    );
  }

  late final CardEditController _controller;

  CardEditController get controller => _controller;
}
