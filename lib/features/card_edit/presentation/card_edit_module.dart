import 'package:effect_emitter/effect_emitter.dart';
import 'package:fcis_core/fcis_core.dart';
import 'package:logging/logging.dart';
import 'package:knit/core/attachments/domain/attachment_read_repository.dart';
import 'package:knit/core/attachments/domain/attachment_write_repository.dart';
import 'package:knit/core/attachments/domain/image_picker_port.dart';
import 'package:knit/core/fcis_flutter/fcis_flutter.dart';
import 'package:knit/features/card_edit/domain/card_edit_links_read_repository.dart';
import 'package:knit/features/card_edit/domain/card_edit_links_write_repository.dart';
import 'package:knit/features/card_edit/domain/card_edit_targets_read_repository.dart';
import 'package:knit/features/card_edit/domain/card_edit_write_repository.dart';
import 'package:knit/features/card_edit/presentation/card_edit_action.dart';
import 'package:knit/features/card_edit/presentation/card_edit_controller.dart';
import 'package:knit/features/card_edit/presentation/card_edit_effect.dart';
import 'package:knit/features/card_edit/presentation/card_edit_loop.dart';
import 'package:knit/features/card_edit/presentation/card_edit_shell.dart';
import 'package:knit/features/card_edit/presentation/card_edit_state.dart';
import 'package:knit/features/card_edit/presentation/card_edit_ui_effect.dart';
import 'package:knit/features/card_edit/presentation/card_edit_updater.dart';

/// Composition root for the Card Edit page (fcis.md §6.8): wires
/// stateHolder → effectEmitter → shell → loop → controller. The shell gets the
/// card-edit write/links/targets ports plus the shared attachments foundation
/// ports (read/write + picker) for the image section.
class CardEditModule {
  CardEditModule({
    required CardEditWriteRepository writeRepository,
    required CardEditLinksReadRepository linksReadRepository,
    required CardEditLinksWriteRepository linksWriteRepository,
    required CardEditTargetsReadRepository targetsReadRepository,
    required AttachmentReadRepository attachmentReadRepository,
    required AttachmentWriteRepository attachmentWriteRepository,
    required ImagePickerPort imagePicker,
    Logger? logger,
  }) {
    final stateHolder =
        ValueListenableStateHolder<CardEditState>(const CardEditState());
    final effectEmitter = EffectEmitter<CardEditUiEffect>();
    final shell = CardEditShell(
      writeRepository: writeRepository,
      linksReadRepository: linksReadRepository,
      linksWriteRepository: linksWriteRepository,
      targetsReadRepository: targetsReadRepository,
      attachmentReadRepository: attachmentReadRepository,
      attachmentWriteRepository: attachmentWriteRepository,
      imagePicker: imagePicker,
      effectEmitter: effectEmitter,
      logger: logger ?? Logger('knit.card_edit'),
    );
    final loop = CardEditLoop(
      stateHolder: stateHolder,
      updater: const CardEditUpdater(),
      effectRunner:
          ShellEffectRunner<CardEditEffect, CardEditAction>(shell: shell),
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
