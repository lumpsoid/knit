import 'package:effect_emitter/effect_emitter.dart';
import 'package:fcis_core/fcis_core.dart';
import 'package:logging/logging.dart';
import 'package:knit/core/attachments/domain/attachment_read_repository.dart';
import 'package:knit/core/attachments/domain/attachment_write_repository.dart';
import 'package:knit/core/attachments/domain/image_picker_port.dart';
import 'package:knit/core/fcis_flutter/fcis_flutter.dart';
import 'package:knit/features/collection_edit/domain/collection_edit_write_repository.dart';
import 'package:knit/features/collection_edit/presentation/collection_edit_action.dart';
import 'package:knit/features/collection_edit/presentation/collection_edit_controller.dart';
import 'package:knit/features/collection_edit/presentation/collection_edit_effect.dart';
import 'package:knit/features/collection_edit/presentation/collection_edit_loop.dart';
import 'package:knit/features/collection_edit/presentation/collection_edit_shell.dart';
import 'package:knit/features/collection_edit/presentation/collection_edit_state.dart';
import 'package:knit/features/collection_edit/presentation/collection_edit_ui_effect.dart';
import 'package:knit/features/collection_edit/presentation/collection_edit_updater.dart';

/// Composition root for the Collection Edit page (fcis.md §6.8): wires
/// stateHolder → effectEmitter → shell → loop → controller. The shell gets the
/// collection-edit write port plus the shared attachments foundation ports
/// (read/write + picker) for the cover-image section.
class CollectionEditModule {
  CollectionEditModule({
    required CollectionEditWriteRepository writeRepository,
    required AttachmentReadRepository attachmentReadRepository,
    required AttachmentWriteRepository attachmentWriteRepository,
    required ImagePickerPort imagePicker,
    Logger? logger,
  }) {
    final stateHolder = ValueListenableStateHolder<CollectionEditState>(
      const CollectionEditState(),
    );
    final effectEmitter = EffectEmitter<CollectionEditUiEffect>();
    final shell = CollectionEditShell(
      writeRepository: writeRepository,
      attachmentReadRepository: attachmentReadRepository,
      attachmentWriteRepository: attachmentWriteRepository,
      imagePicker: imagePicker,
      effectEmitter: effectEmitter,
      logger: logger ?? Logger('knit.collection_edit'),
    );
    final loop = CollectionEditLoop(
      stateHolder: stateHolder,
      updater: const CollectionEditUpdater(),
      effectRunner:
          ShellEffectRunner<CollectionEditEffect, CollectionEditAction>(
            shell: shell,
          ),
    );
    _controller = CollectionEditController(
      stateHolder: stateHolder,
      effectEmitter: effectEmitter,
      sink: loop,
    );
  }

  late final CollectionEditController _controller;

  CollectionEditController get controller => _controller;
}
