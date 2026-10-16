import 'package:effect_emitter/effect_emitter.dart';
import 'package:fcis_core/fcis_core.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:knit/core/attachments/domain/attachment_read_repository.dart';
import 'package:knit/core/attachments/domain/attachment_write_repository.dart';
import 'package:knit/core/attachments/domain/audio_recorder_port.dart';
import 'package:knit/core/attachments/domain/file_picker_port.dart';
import 'package:knit/core/attachments/domain/image_picker_port.dart';
import 'package:knit/core/fcis_flutter/fcis_flutter.dart';
import 'package:knit/features/collection/domain/card_share_repository.dart';
import 'package:knit/features/collection/domain/collection_read_repository.dart';
import 'package:knit/features/collection/domain/collection_write_repository.dart';
import 'package:knit/features/collection/domain/link_launcher.dart';
import 'package:knit/features/collection_details/presentation/collection_details_controller.dart';
import 'package:knit/features/collection/presentation/collection_action.dart';
import 'package:knit/features/collection/presentation/collection_effect.dart';
import 'package:knit/features/collection/presentation/collection_loop.dart';
import 'package:knit/features/collection/presentation/collection_shell.dart';
import 'package:knit/features/collection/presentation/collection_state.dart';
import 'package:knit/features/collection/presentation/collection_ui_effect.dart';
import 'package:knit/features/collection/presentation/collection_updater.dart';
import 'package:knit/features/timeline/domain/timeline_channel.dart';

/// The per-page composition root *and* thin handle for the Collection screen
/// (fcis.md §6.8). One controller per page instance (Collection pages stack —
/// e.g. pushed from Connections — and must not share state), so the controller
/// **creates** the page-scoped resources it later disposes: it wires
/// stateHolder → effectEmitter → shell → loop in its constructor, then in
/// [dispose] detaches the effect seam and disposes the state-holder notifier it
/// made. (The app-scoped features keep a separate module because their wiring
/// outlives any page; here creator and disposer are the same object.)
class CollectionController {
  CollectionController({
    required CollectionReadRepository readRepository,
    required CollectionWriteRepository writeRepository,
    required AttachmentReadRepository attachmentReadRepository,
    required AttachmentWriteRepository attachmentWriteRepository,
    required ImagePickerPort imagePicker,
    required AudioRecorderPort audioRecorder,
    required FilePickerPort filePicker,
    required CardShareRepository shareRepository,
    required LinkLauncher linkLauncher,
    required CollectionDetailsController collectionDetails,
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
      audioRecorder: audioRecorder,
      filePicker: filePicker,
      shareRepository: shareRepository,
      linkLauncher: linkLauncher,
      collectionDetails: collectionDetails,
      effectEmitter: effectEmitter,
      timelineChannel: timelineChannel,
      logger: logger ?? Logger('knit.collection'),
    );
    _stateHolder = stateHolder;
    _effectEmitter = effectEmitter;
    _sink = CollectionLoop(
      stateHolder: stateHolder,
      updater: const CollectionUpdater(),
      effectRunner: ShellEffectRunner<CollectionEffect, CollectionAction>(
        shell: shell,
      ),
    );
  }

  late final ValueListenableStateHolder<CollectionState> _stateHolder;
  late final EffectEmitter<CollectionUiEffect> _effectEmitter;
  late final ActionSink<CollectionAction> _sink;

  ValueListenable<CollectionState> get stateHolder => _stateHolder;

  void onAttach(EffectPusher<CollectionUiEffect> pusher) =>
      _effectEmitter.attach(pusher);

  void onDetach() => _effectEmitter.detach();

  void dispatch(CollectionAction action) => _sink.dispatch(action);

  /// Release the page-scoped resources this controller created: detach the
  /// effect seam and dispose the state-holder notifier.
  void dispose() {
    _effectEmitter.detach();
    _stateHolder.dispose();
  }
}
