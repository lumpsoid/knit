import 'package:effect_emitter/effect_emitter.dart';
import 'package:fcis_core/fcis_core.dart';
import 'package:logging/logging.dart';
import 'package:knit/core/attachments/domain/attachment_read_repository.dart';
import 'package:knit/core/attachments/presentation/attachment_image_cache.dart';
import 'package:knit/core/fcis_flutter/fcis_flutter.dart';
import 'package:knit/features/collection/domain/card_share_repository.dart';
import 'package:knit/features/collection/domain/link_launcher.dart';
import 'package:knit/features/collection_media/domain/collection_media_read_repository.dart';
import 'package:knit/features/collection_media/presentation/collection_media_action.dart';
import 'package:knit/features/collection_media/presentation/collection_media_controller.dart';
import 'package:knit/features/collection_media/presentation/collection_media_effect.dart';
import 'package:knit/features/collection_media/presentation/collection_media_loop.dart';
import 'package:knit/features/collection_media/presentation/collection_media_shell.dart';
import 'package:knit/features/collection_media/presentation/collection_media_state.dart';
import 'package:knit/features/collection_media/presentation/collection_media_ui_effect.dart';
import 'package:knit/features/collection_media/presentation/collection_media_updater.dart';

/// Composition root for the Collection Media page (fcis.md §6.8): wires
/// stateHolder → effectEmitter → shell → loop → controller. The shell gets the
/// media read port, the shared image cache (thumbnails), the attachment read
/// port (file bytes to share), and the
/// share / link-launch ports the Collection feed uses for the same taps.
class CollectionMediaModule {
  CollectionMediaModule({
    required CollectionMediaReadRepository readRepository,
    required AttachmentReadRepository attachmentReadRepository,
    required AttachmentImageCache imageCache,
    required CardShareRepository shareRepository,
    required LinkLauncher linkLauncher,
    Logger? logger,
  }) {
    final stateHolder = ValueListenableStateHolder<CollectionMediaState>(
      CollectionMediaState(),
    );
    final effectEmitter = EffectEmitter<CollectionMediaUiEffect>();
    final shell = CollectionMediaShell(
      readRepository: readRepository,
      attachmentReadRepository: attachmentReadRepository,
      imageCache: imageCache,
      shareRepository: shareRepository,
      linkLauncher: linkLauncher,
      effectEmitter: effectEmitter,
      logger: logger ?? Logger('knit.collection_media'),
    );
    final loop = CollectionMediaLoop(
      stateHolder: stateHolder,
      updater: const CollectionMediaUpdater(),
      effectRunner:
          ShellEffectRunner<CollectionMediaEffect, CollectionMediaAction>(
            shell: shell,
          ),
    );
    _controller = CollectionMediaController(
      stateHolder: stateHolder,
      effectEmitter: effectEmitter,
      sink: loop,
    );
  }

  late final CollectionMediaController _controller;

  CollectionMediaController get controller => _controller;
}
