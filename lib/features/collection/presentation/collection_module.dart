import 'package:effect_emitter/effect_emitter.dart';
import 'package:fcis_core/fcis_core.dart';
import 'package:logging/logging.dart';
import 'package:knit/core/fcis_flutter/fcis_flutter.dart';
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

/// Composition root for the Collection screen (fcis.md §6.8): wires
/// stateHolder → effectEmitter → shell → loop → controller.
class CollectionModule {
  CollectionModule({
    required CollectionReadRepository readRepository,
    required CollectionWriteRepository writeRepository,
    Logger? logger,
  }) {
    final stateHolder =
        ValueListenableStateHolder<CollectionState>(const CollectionState());
    final effectEmitter = EffectEmitter<CollectionUiEffect>();
    final shell = CollectionShell(
      readRepository: readRepository,
      writeRepository: writeRepository,
      effectEmitter: effectEmitter,
      logger: logger ?? Logger('knit.collection'),
    );
    final loop = CollectionLoop(
      stateHolder: stateHolder,
      updater: const CollectionUpdater(),
      effectRunner:
          ShellEffectRunner<CollectionEffect, CollectionAction>(shell: shell),
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
