import 'package:effect_emitter/effect_emitter.dart';
import 'package:fcis_core/fcis_core.dart';
import 'package:logging/logging.dart';
import 'package:knit/core/attachments/domain/attachment_read_repository.dart';
import 'package:knit/core/attachments/domain/attachment_write_repository.dart';
import 'package:knit/core/attachments/domain/image_picker_port.dart';
import 'package:knit/core/fcis_flutter/fcis_flutter.dart';
import 'package:knit/features/collection/domain/card_share_repository.dart';
import 'package:knit/features/collection/domain/collection_read_repository.dart';
import 'package:knit/features/collection/domain/collection_write_repository.dart';
import 'package:knit/features/collection/presentation/collection_action.dart';
import 'package:knit/features/collection/presentation/collection_controller.dart';
import 'package:knit/features/collection/presentation/collection_effect.dart';
import 'package:knit/features/collection/presentation/collection_loop.dart';
import 'package:knit/features/collection/presentation/collection_shell.dart';
import 'package:knit/features/collection/presentation/collection_state.dart';
import 'package:knit/features/collection/presentation/collection_ui_effect.dart';
import 'package:knit/features/collection/presentation/collection_updater.dart';
import 'package:knit/features/timeline/domain/timeline_channel.dart';

/// Composition root for the Collection screen (fcis.md §6.8): wires
/// stateHolder → effectEmitter → shell → loop → controller.
class CollectionModule {
  CollectionModule({
    required CollectionReadRepository readRepository,
    required CollectionWriteRepository writeRepository,
    required AttachmentReadRepository attachmentReadRepository,
    required AttachmentWriteRepository attachmentWriteRepository,
    required ImagePickerPort imagePicker,
    required CardShareRepository shareRepository,
    required TimelineChannelEmitter timelineChannel,
    Logger? logger,
  }) {
    final stateHolder = ValueListenableStateHolder<CollectionState>(
      const CollectionState(),
    );
    final effectEmitter = EffectEmitter<CollectionUiEffect>();
    final shell = CollectionShell(
      readRepository: readRepository,
      writeRepository: writeRepository,
      attachmentReadRepository: attachmentReadRepository,
      attachmentWriteRepository: attachmentWriteRepository,
      imagePicker: imagePicker,
      shareRepository: shareRepository,
      effectEmitter: effectEmitter,
      timelineChannel: timelineChannel,
      logger: logger ?? Logger('knit.collection'),
    );
    final loop = CollectionLoop(
      stateHolder: stateHolder,
      updater: const CollectionUpdater(),
      effectRunner: ShellEffectRunner<CollectionEffect, CollectionAction>(
        shell: shell,
      ),
    );
    _controller = CollectionController(
      stateHolder: stateHolder,
      effectEmitter: effectEmitter,
      sink: loop,
    );
  }

  late final CollectionController _controller;

  CollectionController get controller => _controller;
}
